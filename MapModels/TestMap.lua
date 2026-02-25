-- TestMap.lua
-- Simple test map definition for Rojo/ServerStorage

local TestMap = Instance.new("Model")
TestMap.Name = "TestMap"

-- Create a simple track (oval with 4 checkpoints and 4 spawns)
local function createPart(name, size, cframe, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.BrickColor = BrickColor.new(color or "Medium stone grey")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = TestMap
	return part
end

-- Track base
createPart("TrackBase", Vector3.new(60, 1, 120), CFrame.new(0, 0, 0), "Medium stone grey")

-- Checkpoints
for i, pos in ipairs({
	Vector3.new(0, 1, -50),
	Vector3.new(30, 1, 0),
	Vector3.new(0, 1, 50),
	Vector3.new(-30, 1, 0),
}) do
	local cp = Instance.new("Part")
	cp.Name = "Checkpoint" .. i
	cp.Size = Vector3.new(10, 1, 10)
	cp.CFrame = CFrame.new(pos)
	cp.Anchored = true
	cp.BrickColor = BrickColor.new("Bright yellow")
	cp.Transparency = 0.5
	cp.Parent = TestMap
end

-- Spawns
for i, pos in ipairs({
	Vector3.new(-6, 2, -55),
	Vector3.new(-2, 2, -55),
	Vector3.new(2, 2, -55),
	Vector3.new(6, 2, -55),
}) do
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn" .. i
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = CFrame.new(pos)
	spawn.Anchored = true
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.Parent = TestMap
end

return TestMap
