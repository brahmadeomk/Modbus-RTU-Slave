-- Builds weapon Tools and hands them out / takes them away.
-- Players only hold weapons while a match is running.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("RivalsShared")
local WeaponConfig = require(shared:WaitForChild("WeaponConfig"))

local Loadout = {}

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

local function clearContainer(container)
	if not container then
		return
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("WeaponName") then
			child:Destroy()
		end
	end
end

function Loadout.clear(player)
	clearContainer(player:FindFirstChild("Backpack"))
	clearContainer(player.Character)
end

function Loadout.give(player)
	Loadout.clear(player)
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (backpack and humanoid and humanoid.Health > 0) then
		return
	end
	local firstTool
	for _, entry in sortedWeapons do
		local tool = buildTool(entry.key, entry.cfg)
		tool.Parent = backpack
		firstTool = firstTool or tool
	end
	task.delay(0.15, function()
		if firstTool and firstTool.Parent == backpack and humanoid.Health > 0 then
			humanoid:EquipTool(firstTool)
		end
	end)
end

return Loadout
