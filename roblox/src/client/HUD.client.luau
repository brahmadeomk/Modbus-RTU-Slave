-- HUD: health bar, ammo counter, team scores + round timer, killfeed,
-- and the round-over banner.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local shared = ReplicatedStorage:WaitForChild("RivalsShared")
local Remotes = require(shared:WaitForChild("Remotes"))

local killFeed = Remotes.get("KillFeed")
local roundState = Remotes.get("RoundState")

local RED = Color3.fromRGB(255, 75, 75)
local BLUE = Color3.fromRGB(85, 140, 255)
local WHITE = Color3.fromRGB(240, 240, 240)

local gui = Instance.new("ScreenGui")
gui.Name = "RivalsHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = props.bg and 0.35 or 1
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BorderSizePixel = 0
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = props.color or WHITE
	l.TextSize = props.textSize or 18
	l.TextStrokeTransparency = 0.5
	l.Text = props.text or ""
	l.Size = props.size
	l.Position = props.position
	l.AnchorPoint = props.anchor or Vector2.new(0, 0)
	l.TextXAlignment = props.xAlign or Enum.TextXAlignment.Center
	l.Parent = props.parent or gui
	return l
end

-- Health bar (bottom left) ------------------------------------------------
local healthBack = Instance.new("Frame")
healthBack.Size = UDim2.fromOffset(260, 24)
healthBack.Position = UDim2.new(0, 24, 1, -56)
healthBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
healthBack.BackgroundTransparency = 0.25
healthBack.BorderSizePixel = 0
healthBack.Parent = gui
Instance.new("UICorner", healthBack).CornerRadius = UDim.new(0, 6)

local healthFill = Instance.new("Frame")
healthFill.Size = UDim2.new(1, 0, 1, 0)
healthFill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
healthFill.BorderSizePixel = 0
healthFill.Parent = healthBack
Instance.new("UICorner", healthFill).CornerRadius = UDim.new(0, 6)

local healthText = label({
	parent = healthBack,
	size = UDim2.new(1, 0, 1, 0),
	position = UDim2.new(0, 0, 0, 0),
	text = "100",
	textSize = 16,
})

local function updateHealth(humanoid)
	local frac = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
	healthFill.Size = UDim2.new(frac, 0, 1, 0)
	healthFill.BackgroundColor3 = Color3.fromHSV(0.33 * frac, 0.8, 0.9)
	healthText.Text = tostring(math.floor(humanoid.Health + 0.5))
end

-- Ammo (bottom right) -----------------------------------------------------
local ammoLabel = label({
	size = UDim2.fromOffset(220, 40),
	position = UDim2.new(1, -244, 1, -72),
	text = "",
	textSize = 30,
	xAlign = Enum.TextXAlignment.Right,
})

local equippedTool
local ammoConnections = {}

local function clearAmmoConnections()
	for _, c in ammoConnections do
		c:Disconnect()
	end
	table.clear(ammoConnections)
end

local function updateAmmo()
	if not equippedTool then
		ammoLabel.Text = ""
		return
	end
	if equippedTool:GetAttribute("Reloading") then
		ammoLabel.Text = "RELOADING…"
	else
		ammoLabel.Text = tostring(equippedTool:GetAttribute("Ammo") or 0)
	end
end

local function setEquipped(tool)
	clearAmmoConnections()
	equippedTool = tool
	if tool then
		table.insert(ammoConnections, tool:GetAttributeChangedSignal("Ammo"):Connect(updateAmmo))
		table.insert(ammoConnections, tool:GetAttributeChangedSignal("Reloading"):Connect(updateAmmo))
	end
	updateAmmo()
end

-- Scoreboard + timer (top center) -----------------------------------------
local scoreFrame = Instance.new("Frame")
scoreFrame.Size = UDim2.fromOffset(300, 36)
scoreFrame.Position = UDim2.new(0.5, 0, 0, 8)
scoreFrame.AnchorPoint = Vector2.new(0.5, 0)
scoreFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
scoreFrame.BackgroundTransparency = 0.35
scoreFrame.BorderSizePixel = 0
scoreFrame.Parent = gui
Instance.new("UICorner", scoreFrame).CornerRadius = UDim.new(0, 8)

local redScore = label({
	parent = scoreFrame,
	size = UDim2.new(0.3, 0, 1, 0),
	position = UDim2.new(0, 0, 0, 0),
	text = "0",
	color = RED,
	textSize = 24,
})
local timerLabel = label({
	parent = scoreFrame,
	size = UDim2.new(0.4, 0, 1, 0),
	position = UDim2.new(0.3, 0, 0, 0),
	text = "5:00",
	textSize = 20,
})
local blueScore = label({
	parent = scoreFrame,
	size = UDim2.new(0.3, 0, 1, 0),
	position = UDim2.new(0.7, 0, 0, 0),
	text = "0",
	color = BLUE,
	textSize = 24,
})

local banner = label({
	size = UDim2.fromOffset(500, 60),
	position = UDim2.new(0.5, 0, 0.35, 0),
	anchor = Vector2.new(0.5, 0.5),
	text = "",
	textSize = 44,
})
banner.Visible = false

roundState.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	redScore.Text = tostring(data.red or 0)
	blueScore.Text = tostring(data.blue or 0)
	timerLabel.Text = string.format("%d:%02d", (data.timeLeft or 0) // 60, (data.timeLeft or 0) % 60)
	if data.state == "over" then
		banner.Visible = true
		if data.winner == "Draw" then
			banner.Text = "DRAW"
			banner.TextColor3 = WHITE
		else
			banner.Text = string.upper(tostring(data.winner)) .. " WINS"
			banner.TextColor3 = data.winner == "Red" and RED or BLUE
		end
	else
		banner.Visible = false
	end
end)

-- Killfeed (top right) ----------------------------------------------------
local feedFrame = Instance.new("Frame")
feedFrame.Size = UDim2.fromOffset(320, 200)
feedFrame.Position = UDim2.new(1, -12, 0, 12)
feedFrame.AnchorPoint = Vector2.new(1, 0)
feedFrame.BackgroundTransparency = 1
feedFrame.Parent = gui

local feedLayout = Instance.new("UIListLayout")
feedLayout.Padding = UDim.new(0, 4)
feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Parent = feedFrame

local feedOrder = 0
killFeed.OnClientEvent:Connect(function(killerName, victimName, weapon, headshot)
	feedOrder += 1
	local text
	if killerName then
		text = string.format("%s %s %s  [%s]", killerName, headshot and "⌖" or "➤", victimName, weapon or "?")
	else
		text = string.format("%s died", victimName)
	end
	local row = label({
		parent = feedFrame,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.new(0, 0, 0, 0),
		text = text,
		textSize = 15,
		bg = true,
		xAlign = Enum.TextXAlignment.Right,
	})
	row.LayoutOrder = feedOrder
	if killerName == player.Name then
		row.TextColor3 = Color3.fromRGB(255, 220, 120)
	end

	-- keep the feed short
	local rows = {}
	for _, child in feedFrame:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(rows, child)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #rows - 6 do
		rows[i]:Destroy()
	end

	task.delay(5, function()
		if row.Parent then
			TweenService:Create(row, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.delay(0.4, function()
				row:Destroy()
			end)
		end
	end)
end)

-- Character wiring ---------------------------------------------------------
local function watchCharacter(char)
	local humanoid = char:WaitForChild("Humanoid")
	updateHealth(humanoid)
	humanoid.HealthChanged:Connect(function()
		updateHealth(humanoid)
	end)
	setEquipped(nil)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("WeaponName") then
			setEquipped(child)
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child == equippedTool then
			setEquipped(nil)
		end
	end)
end

player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end
