-- Spawning: fast base movement, leaderstats, and the weapon loadout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RivalsShared")
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))

Players.RespawnTime = 2.5

local sortedWeapons = {}
for key, cfg in WeaponConfig do
	table.insert(sortedWeapons, { key = key, cfg = cfg })
end
table.sort(sortedWeapons, function(a, b)
	return a.cfg.slot < b.cfg.slot
end)

local function buildTool(key, cfg)
	local tool = Instance.new("Tool")
	tool.Name = cfg.displayName
	tool.CanBeDropped = false
	tool.ToolTip = cfg.displayName
	tool:SetAttribute("WeaponName", key)
	tool:SetAttribute("Ammo", cfg.magSize)
	tool:SetAttribute("Reloading", false)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 2.2)
	handle.Color = Color3.fromRGB(40, 40, 45)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	return tool
end

local function onCharacterAdded(player, character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = 24
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 55

	local backpack = player:WaitForChild("Backpack")
	local firstTool
	for _, entry in sortedWeapons do
		local tool = buildTool(entry.key, entry.cfg)
		tool.Parent = backpack
		firstTool = firstTool or tool
	end

	task.delay(0.2, function()
		if firstTool and firstTool.Parent == backpack and humanoid.Health > 0 then
			humanoid:EquipTool(firstTool)
		end
	end)
end

local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = stats
	local deaths = Instance.new("IntValue")
	deaths.Name = "Deaths"
	deaths.Parent = stats
	stats.Parent = player

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
