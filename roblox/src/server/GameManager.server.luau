-- Match flow: everyone waits in the lobby during intermission, gets
-- teleported to their team's arena pads (and armed) when the match starts,
-- respawns back into the arena mid-match, and returns to the lobby when the
-- match ends. Also owns teams, kill credit, heal-on-kill, and the killfeed.
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RivalsShared")
local Remotes = require(shared:WaitForChild("Remotes"))
local Loadout = require(script.Parent:WaitForChild("Loadout"))

local killFeed = Remotes.get("KillFeed")
local roundState = Remotes.get("RoundState")

local INTERMISSION_TIME = 15
local ROUND_TIME = 300
local KILL_TARGET = 40
local KILL_HEAL = 35
local KILL_CREDIT_WINDOW = 6 -- seconds after last damage that a death still counts
local SPAWN_PROTECTION = 3

local function ensureTeam(name, brickColor)
	local team = Teams:FindFirstChild(name)
	if not team then
		team = Instance.new("Team")
		team.Name = name
		team.TeamColor = brickColor
		team.Parent = Teams
	end
	team.AutoAssignable = true
	return team
end
ensureTeam("Red", BrickColor.new("Bright red"))
ensureTeam("Blue", BrickColor.new("Bright blue"))

local scores = { Red = 0, Blue = 0 }
local phaseEndsAt = 0
local matchActive = false

local function broadcast(stateName, winner)
	roundState:FireAllClients({
		red = scores.Red,
		blue = scores.Blue,
		timeLeft = math.max(0, math.floor(phaseEndsAt - os.clock())),
		state = stateName,
		winner = winner,
		target = KILL_TARGET,
	})
end

-- Arena placement ---------------------------------------------------------
local function pickSpawnPad(teamName)
	local mapFolder = workspace:FindFirstChild("RivalsMap")
	local folder = mapFolder
		and mapFolder:FindFirstChild(teamName == "Blue" and "BlueSpawns" or "RedSpawns")
	local pads = folder and folder:GetChildren()
	if pads and #pads > 0 then
		return pads[math.random(#pads)]
	end
	return nil
end

local function sendToArena(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid and humanoid.Health > 0) then
		return
	end
	local pad = pickSpawnPad(player.Team and player.Team.Name or "Red")
	if pad then
		local pos = pad.Position + Vector3.new(0, 4, 0)
		character:PivotTo(CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)))
	end
	humanoid.Health = humanoid.MaxHealth
	Loadout.give(player)

	local ff = Instance.new("ForceField")
	ff.Parent = character
	task.delay(SPAWN_PROTECTION, function()
		if ff.Parent then
			ff:Destroy()
		end
	end)
end

-- Kill credit -------------------------------------------------------------
local function bumpStat(player, statName)
	local stats = player:FindFirstChild("leaderstats")
	local stat = stats and stats:FindFirstChild(statName)
	if stat then
		stat.Value += 1
	end
end

local function onDied(player, humanoid)
	bumpStat(player, "Deaths")

	local killerId = humanoid:GetAttribute("LastDamagerUserId")
	local damageTime = humanoid:GetAttribute("LastDamageTime")
	local weapon = humanoid:GetAttribute("LastDamagerWeapon")
	local headshot = humanoid:GetAttribute("LastDamageHeadshot") == true

	local killer
	if killerId and damageTime and os.clock() - damageTime <= KILL_CREDIT_WINDOW then
		killer = Players:GetPlayerByUserId(killerId)
	end

	if killer and killer ~= player then
		bumpStat(killer, "Kills")
		local teamName = killer.Team and killer.Team.Name
		if matchActive and teamName and scores[teamName] then
			scores[teamName] += 1
		end
		-- Rivals-style: kills top you back up
		local killerHumanoid = killer.Character and killer.Character:FindFirstChildOfClass("Humanoid")
		if killerHumanoid and killerHumanoid.Health > 0 then
			killerHumanoid.Health = math.min(killerHumanoid.MaxHealth, killerHumanoid.Health + KILL_HEAL)
		end
		killFeed:FireAllClients(killer.Name, player.Name, weapon or "?", headshot)
	else
		killFeed:FireAllClients(nil, player.Name, nil, false)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Once(function()
			onDied(player, humanoid)
		end)
		-- Mid-match spawns (joiners and respawns) go straight into the arena
		if matchActive then
			task.defer(sendToArena, player)
		end
	end)
end)

-- Match loop ---------------------------------------------------------------
task.spawn(function()
	while true do
		-- Intermission: everyone hangs out in the lobby, unarmed
		matchActive = false
		phaseEndsAt = os.clock() + INTERMISSION_TIME
		while os.clock() < phaseEndsAt do
			broadcast("intermission")
			task.wait(1)
		end

		-- Match start: reset scores, drop everyone onto their team pads
		scores.Red, scores.Blue = 0, 0
		matchActive = true
		phaseEndsAt = os.clock() + ROUND_TIME
		for _, player in Players:GetPlayers() do
			sendToArena(player)
		end
		while os.clock() < phaseEndsAt and scores.Red < KILL_TARGET and scores.Blue < KILL_TARGET do
			broadcast("playing")
			task.wait(1)
		end

		-- Match over: announce, then send everyone back to the lobby
		matchActive = false
		local winner
		if scores.Red == scores.Blue then
			winner = "Draw"
		else
			winner = scores.Red > scores.Blue and "Red" or "Blue"
		end
		phaseEndsAt = os.clock() + 8
		for _ = 1, 8 do
			broadcast("over", winner)
			task.wait(1)
		end
		for _, player in Players:GetPlayers() do
			Loadout.clear(player)
			player:LoadCharacter()
		end
	end
end)
