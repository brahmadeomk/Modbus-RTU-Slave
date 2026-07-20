-- Builds a symmetric PvP arena at runtime so the game works in any place,
-- including an empty baseplate. Red spawns at -X, Blue at +X.
local Lighting = game:GetService("Lighting")

local ARENA = 260
local WALL_HEIGHT = 40

local map = Instance.new("Folder")
map.Name = "RivalsMap"

local function newPart(props)
	local p = Instance.new(props.wedge and "WedgePart" or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = props.size
	p.CFrame = props.cframe or CFrame.new(props.position)
	p.Color = props.color or Color3.fromRGB(99, 95, 98)
	p.Material = props.material or Enum.Material.SmoothPlastic
	p.Name = props.name or "MapPart"
	p.Parent = map
	return p
end

-- Floor and perimeter walls
newPart({
	name = "Floor",
	size = Vector3.new(ARENA, 1, ARENA),
	position = Vector3.new(0, 0.5, 0),
	color = Color3.fromRGB(46, 46, 50),
	material = Enum.Material.Slate,
})
newPart({
	name = "CenterStripe",
	size = Vector3.new(2, 0.1, ARENA),
	position = Vector3.new(0, 1.06, 0),
	color = Color3.fromRGB(255, 255, 255),
	material = Enum.Material.Neon,
})
for _, def in {
	{ Vector3.new(ARENA, WALL_HEIGHT, 2), Vector3.new(0, WALL_HEIGHT / 2, ARENA / 2) },
	{ Vector3.new(ARENA, WALL_HEIGHT, 2), Vector3.new(0, WALL_HEIGHT / 2, -ARENA / 2) },
	{ Vector3.new(2, WALL_HEIGHT, ARENA), Vector3.new(ARENA / 2, WALL_HEIGHT / 2, 0) },
	{ Vector3.new(2, WALL_HEIGHT, ARENA), Vector3.new(-ARENA / 2, WALL_HEIGHT / 2, 0) },
} do
	newPart({
		name = "Wall",
		size = def[1],
		position = def[2],
		color = Color3.fromRGB(30, 30, 34),
		material = Enum.Material.Metal,
	})
end

-- Mirrored cover blocks so neither side has an advantage
local rng = Random.new(7)
for _ = 1, 16 do
	local sx = rng:NextNumber(4, 10)
	local sy = rng:NextNumber(4, 9)
	local sz = rng:NextNumber(4, 10)
	local x = rng:NextNumber(18, 110)
	local z = rng:NextNumber(-115, 115)
	local shade = rng:NextInteger(60, 90)
	for _, side in { -1, 1 } do
		newPart({
			name = "Cover",
			size = Vector3.new(sx, sy, sz),
			position = Vector3.new(x * side, 1 + sy / 2, z),
			color = Color3.fromRGB(shade, shade, shade + 8),
			material = Enum.Material.Concrete,
		})
	end
end

-- Center platform with four sloped ramps for high-ground fights
newPart({
	name = "CenterPlatform",
	size = Vector3.new(30, 1, 30),
	position = Vector3.new(0, 12.5, 0),
	color = Color3.fromRGB(70, 70, 78),
	material = Enum.Material.Metal,
})
for _, dir in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
	local bottom = dir * 42 + Vector3.new(0, 1, 0)
	local top = dir * 15 + Vector3.new(0, 12.5, 0)
	local mid = (bottom + top) / 2
	local length = (top - bottom).Magnitude
	newPart({
		name = "Ramp",
		size = Vector3.new(10, 1, length + 2),
		cframe = CFrame.lookAt(mid, top),
		color = Color3.fromRGB(70, 70, 78),
		material = Enum.Material.Metal,
	})
end

-- Jump pads: step on one, get launched
for _, pos in {
	Vector3.new(55, 1.25, 55),
	Vector3.new(55, 1.25, -55),
	Vector3.new(-55, 1.25, 55),
	Vector3.new(-55, 1.25, -55),
} do
	local pad = newPart({
		name = "JumpPad",
		size = Vector3.new(6, 0.5, 6),
		position = pos,
		color = Color3.fromRGB(80, 255, 120),
		material = Enum.Material.Neon,
	})
	local ready = {}
	pad.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if root and (not ready[root] or os.clock() - ready[root] > 0.5) then
			ready[root] = os.clock()
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, 90, v.Z)
		end
	end)
end

-- Team spawns at opposite ends
local function spawnPad(x, z, teamColor)
	local s = Instance.new("SpawnLocation")
	s.Size = Vector3.new(6, 1, 6)
	s.Position = Vector3.new(x, 1.5, z)
	s.Anchored = true
	s.Neutral = false
	s.TeamColor = teamColor
	s.Duration = 4
	s.Color = teamColor.Color
	s.Material = Enum.Material.Neon
	s.Transparency = 0.4
	local decal = s:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	s.Parent = map
end
for i = -2, 2 do
	spawnPad(-118, i * 22, BrickColor.new("Bright red"))
	spawnPad(118, i * 22, BrickColor.new("Bright blue"))
end

-- Remove any pre-existing neutral spawns so players always spawn on team pads
for _, child in workspace:GetChildren() do
	if child:IsA("SpawnLocation") then
		child:Destroy()
	end
end

map.Parent = workspace

Lighting.ClockTime = 14.5
Lighting.Brightness = 2.5
