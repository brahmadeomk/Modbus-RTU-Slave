-- Spawning: fast base movement and leaderstats. Weapons are handed out by
-- GameManager when a match starts — fresh spawns land in the lobby unarmed.
local Players = game:GetService("Players")

Players.RespawnTime = 2.5

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = 24
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 55
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

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
