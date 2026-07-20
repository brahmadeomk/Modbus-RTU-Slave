-- Server-authoritative combat: validates every shot (rate, ammo, origin,
-- team) and applies damage. Clients only ever *request* a shot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RivalsShared")
local Remotes = require(shared:WaitForChild("Remotes"))
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))

local fireRemote = Remotes.get("FireWeapon")
local reloadRemote = Remotes.get("Reload")
local hitConfirm = Remotes.get("HitConfirm")

local MAX_ORIGIN_DRIFT = 12 -- studs the claimed muzzle may differ from the head
local RATE_TOLERANCE = 0.7 -- fraction of the fire interval we accept, for latency

-- state[player][weaponName] = { ammo, lastShot, reloading }
local state = {}

local function weaponState(player, weaponName, cfg)
	local perPlayer = state[player]
	if not perPlayer then
		perPlayer = {}
		state[player] = perPlayer
	end
	local ws = perPlayer[weaponName]
	if not ws then
		ws = { ammo = cfg.magSize, lastShot = 0, reloading = false }
		perPlayer[weaponName] = ws
	end
	return ws
end

local function findTool(player, weaponName)
	local function scan(container)
		if not container then
			return nil
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("WeaponName") == weaponName then
				return child
			end
		end
		return nil
	end
	return scan(player.Character) or scan(player:FindFirstChild("Backpack"))
end

local function syncTool(player, weaponName, ws)
	local tool = findTool(player, weaponName)
	if tool then
		tool:SetAttribute("Ammo", ws.ammo)
		tool:SetAttribute("Reloading", ws.reloading)
	end
end

fireRemote.OnServerEvent:Connect(function(player, weaponName, origin, dirs)
	if type(weaponName) ~= "string" or typeof(origin) ~= "Vector3" or type(dirs) ~= "table" then
		return
	end
	local cfg = WeaponConfig[weaponName]
	if not cfg then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not (humanoid and humanoid.Health > 0 and head) then
		return
	end
	if (origin - head.Position).Magnitude > MAX_ORIGIN_DRIFT then
		return
	end

	local ws = weaponState(player, weaponName, cfg)
	local now = os.clock()
	if ws.reloading or ws.ammo <= 0 then
		return
	end
	if now - ws.lastShot < (1 / cfg.fireRate) * RATE_TOLERANCE then
		return
	end
	ws.lastShot = now
	ws.ammo -= 1
	syncTool(player, weaponName, ws)

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local totalDamage = 0
	local anyHeadshot = false
	local pelletCount = math.min(#dirs, cfg.pellets)
	for i = 1, pelletCount do
		local dir = dirs[i]
		if typeof(dir) == "Vector3" and dir.Magnitude > 0 then
			local result = workspace:Raycast(origin, dir.Unit * cfg.range, params)
			if result then
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				local victimHumanoid = model and model:FindFirstChildOfClass("Humanoid")
				if victimHumanoid and victimHumanoid.Health > 0 then
					local victimPlayer = Players:GetPlayerFromCharacter(model)
					local friendly = victimPlayer
						and victimPlayer.Team ~= nil
						and victimPlayer.Team == player.Team
					if not friendly then
						local isHead = result.Instance.Name == "Head"
						local damage = cfg.damage * (isHead and cfg.headshot or 1)
						victimHumanoid:SetAttribute("LastDamagerUserId", player.UserId)
						victimHumanoid:SetAttribute("LastDamagerWeapon", cfg.displayName)
						victimHumanoid:SetAttribute("LastDamageHeadshot", isHead)
						victimHumanoid:SetAttribute("LastDamageTime", os.clock())
						victimHumanoid:TakeDamage(damage)
						totalDamage += damage
						anyHeadshot = anyHeadshot or isHead
					end
				end
			end
		end
	end

	if totalDamage > 0 then
		hitConfirm:FireClient(player, totalDamage, anyHeadshot)
	end
end)

reloadRemote.OnServerEvent:Connect(function(player, weaponName)
	if type(weaponName) ~= "string" then
		return
	end
	local cfg = WeaponConfig[weaponName]
	if not cfg then
		return
	end
	local ws = weaponState(player, weaponName, cfg)
	if ws.reloading or ws.ammo >= cfg.magSize then
		return
	end
	ws.reloading = true
	syncTool(player, weaponName, ws)
	task.delay(cfg.reloadTime, function()
		if state[player] and state[player][weaponName] == ws then
			ws.reloading = false
			ws.ammo = cfg.magSize
			syncTool(player, weaponName, ws)
		end
	end)
end)

local function resetPlayer(player)
	state[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		resetPlayer(player) -- fresh mags every spawn
	end)
end)
Players.PlayerRemoving:Connect(resetPlayer)
