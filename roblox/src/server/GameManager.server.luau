-- Teams, kill credit, heal-on-kill, killfeed, and the round loop
-- (team deathmatch: first team to the kill target, or highest when time runs out).
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RivalsShared")
local Remotes = require(shared:WaitForChild("Remotes"))

local killFeed = Remotes.get("KillFeed")
local roundState = Remotes.get("RoundState")

local ROUND_TIME = 300
local KILL_TARGET = 40
local KILL_HEAL = 35
local KILL_CREDIT_WINDOW = 6 -- seconds after last damage that a death still counts

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
local roundEndsAt = 0
local roundOver = false

local function broadcast(stateName, winner)
	roundState:FireAllClients({
		red = scores.Red,
		blue = scores.Blue,
		timeLeft = math.max(0, math.floor(roundEndsAt - os.clock())),
		state = stateName,
		winner = winner,
		target = KILL_TARGET,
	})
end

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
		if not roundOver and teamName and scores[teamName] then
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
	end)
end)

task.spawn(function()
	while true do
		scores.Red, scores.Blue = 0, 0
		roundOver = false
		roundEndsAt = os.clock() + ROUND_TIME
		while os.clock() < roundEndsAt and scores.Red < KILL_TARGET and scores.Blue < KILL_TARGET do
			broadcast("playing")
			task.wait(1)
		end
		roundOver = true
		local winner
		if scores.Red == scores.Blue then
			winner = "Draw"
		else
			winner = scores.Red > scores.Blue and "Red" or "Blue"
		end
		for _ = 1, 8 do
			broadcast("over", winner)
			task.wait(1)
		end
		for _, player in Players:GetPlayers() do
			player:LoadCharacter()
		end
	end
end)
