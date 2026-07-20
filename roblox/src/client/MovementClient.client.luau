-- Fast movement kit: double jump (Space in mid-air) and dash (Q).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local DASH_SPEED = 80
local DASH_COOLDOWN = 2
local MAX_AIR_JUMPS = 1

local humanoid, rootPart
local airJumpsUsed = 0
local lastAirJump = 0
local lastDash = 0

local function watchCharacter(char)
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	airJumpsUsed = 0
	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Landed then
			airJumpsUsed = 0
		end
	end)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end

UserInputService.JumpRequest:Connect(function()
	if not (humanoid and humanoid.Health > 0) then
		return
	end
	local now = os.clock()
	if now - lastAirJump < 0.25 then
		return
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall and airJumpsUsed < MAX_AIR_JUMPS then
		lastAirJump = now
		airJumpsUsed += 1
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.Q then
		return
	end
	if not (humanoid and humanoid.Health > 0 and rootPart) then
		return
	end
	local now = os.clock()
	if now - lastDash < DASH_COOLDOWN then
		return
	end
	local dir = humanoid.MoveDirection
	if dir.Magnitude < 0.1 then
		local look = camera.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
	end
	if dir.Magnitude < 0.01 then
		return
	end
	lastDash = now
	dir = dir.Unit
	local v = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(dir.X * DASH_SPEED, math.max(v.Y, 12), dir.Z * DASH_SPEED)
end)
