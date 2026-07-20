-- Client side of combat: shoulder-locked camera while a weapon is out,
-- crosshair, firing input, tracers, hitmarkers, and reload requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local shared = ReplicatedStorage:WaitForChild("RivalsShared")
local Remotes = require(shared:WaitForChild("Remotes"))
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))

local fireRemote = Remotes.get("FireWeapon")
local reloadRemote = Remotes.get("Reload")
local hitConfirm = Remotes.get("HitConfirm")

local rng = Random.new()

local character, humanoid, rootPart
local equippedTool, equippedName
local firing = false
local lastShot = 0

-- Crosshair --------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RivalsCrosshair"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local BASE_GAP = 6
local crossSpread = BASE_GAP
local crossFrames = {}
for i = 1, 4 do
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = gui
	crossFrames[i] = f
end

local function layoutCrosshair()
	local o = math.floor(crossSpread)
	crossFrames[1].Size = UDim2.fromOffset(2, 8)
	crossFrames[1].Position = UDim2.new(0.5, 0, 0.5, -o - 4)
	crossFrames[2].Size = UDim2.fromOffset(2, 8)
	crossFrames[2].Position = UDim2.new(0.5, 0, 0.5, o + 4)
	crossFrames[3].Size = UDim2.fromOffset(8, 2)
	crossFrames[3].Position = UDim2.new(0.5, -o - 4, 0.5, 0)
	crossFrames[4].Size = UDim2.fromOffset(8, 2)
	crossFrames[4].Position = UDim2.new(0.5, o + 4, 0.5, 0)
end
layoutCrosshair()

local function showDamage(amount, headshot)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, rng:NextInteger(20, 45), 0.5, rng:NextInteger(-40, -15))
	label.Size = UDim2.fromOffset(80, 24)
	label.Font = Enum.Font.GothamBold
	label.TextSize = headshot and 24 or 18
	label.TextColor3 = headshot and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 220, 120)
	label.TextStrokeTransparency = 0.4
	label.Text = tostring(math.floor(amount + 0.5))
	label.Parent = gui
	TweenService:Create(label, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position + UDim2.fromOffset(0, -30),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(label, 0.7)
end

hitConfirm.OnClientEvent:Connect(function(damage, headshot)
	showDamage(damage, headshot)
	crossSpread = math.min(crossSpread + 4, 30)
end)

-- Shoulder-lock aiming ----------------------------------------------------
RunService:BindToRenderStep("RivalsAimLock", Enum.RenderPriority.Camera.Value + 1, function()
	local aiming = equippedTool ~= nil and humanoid ~= nil and humanoid.Health > 0 and rootPart ~= nil
	gui.Enabled = aiming
	if aiming then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
		humanoid.CameraOffset = Vector3.new(1.6, 0.4, 0)
		humanoid.AutoRotate = false
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.001 then
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flat)
		end
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
			humanoid.AutoRotate = true
		end
	end
end)

-- Firing ------------------------------------------------------------------
local function withSpread(dir, degrees)
	if degrees <= 0 then
		return dir
	end
	local cf = CFrame.new(Vector3.zero, dir)
	local pitch = math.rad(rng:NextNumber(-degrees, degrees))
	local yaw = math.rad(rng:NextNumber(-degrees, degrees))
	return (cf * CFrame.Angles(pitch, yaw, 0)).LookVector
end

local function tracer(origin, dir, dist)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 220, 120)
	p.Size = Vector3.new(0.08, 0.08, dist)
	p.CFrame = CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace
	Debris:AddItem(p, 0.06)
end

local function tryFire()
	local tool, name = equippedTool, equippedName
	if not (tool and name and character and humanoid and humanoid.Health > 0) then
		return
	end
	local cfg = WeaponConfig[name]
	if not cfg then
		return
	end
	local now = os.clock()
	if now - lastShot < 1 / cfg.fireRate then
		return
	end
	if tool:GetAttribute("Reloading") then
		return
	end
	local ammo = tool:GetAttribute("Ammo") or 0
	if ammo <= 0 then
		reloadRemote:FireServer(name)
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	lastShot = now

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Aim through the crosshair: find what the camera is looking at, then
	-- shoot from the head toward that point.
	local camPos = camera.CFrame.Position
	local camResult = workspace:Raycast(camPos, camera.CFrame.LookVector * cfg.range, params)
	local aimPoint = camResult and camResult.Position or (camPos + camera.CFrame.LookVector * cfg.range)

	local origin = head.Position
	local baseDir = aimPoint - origin
	if baseDir.Magnitude < 0.1 then
		return
	end
	baseDir = baseDir.Unit

	local dirs = {}
	for i = 1, cfg.pellets do
		dirs[i] = withSpread(baseDir, cfg.spread)
	end
	fireRemote:FireServer(name, origin, dirs)

	for _, dir in dirs do
		local result = workspace:Raycast(origin, dir * cfg.range, params)
		local dist = result and (result.Position - origin).Magnitude or cfg.range
		tracer(origin, dir, dist)
	end
	crossSpread = math.min(crossSpread + 6, 30)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = true
		tryFire()
	elseif input.KeyCode == Enum.KeyCode.R then
		if equippedName then
			reloadRemote:FireServer(equippedName)
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = false
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if firing and equippedName then
		local cfg = WeaponConfig[equippedName]
		if cfg and cfg.auto then
			tryFire()
		end
	end
	crossSpread += (BASE_GAP - crossSpread) * math.min(dt * 8, 1)
	layoutCrosshair()
end)

-- Character / tool tracking ----------------------------------------------
local function watchCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")
	equippedTool, equippedName = nil, nil
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponName") then
			equippedTool = child
			equippedName = child:GetAttribute("WeaponName")
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child == equippedTool then
			equippedTool, equippedName = nil, nil
		end
	end)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end
