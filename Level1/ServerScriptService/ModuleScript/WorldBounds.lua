local Workspace = game:GetService("Workspace")

local WorldBounds = {}

local DEFAULT_MIN = Vector2.new(-180, -180)
local DEFAULT_MAX = Vector2.new(180, 180)

local function mergeBounds(bounds, minX, maxX, minZ, maxZ)
	if minX == nil or maxX == nil or minZ == nil or maxZ == nil then
		return bounds
	end

	if not bounds then
		return {
			minX = minX,
			maxX = maxX,
			minZ = minZ,
			maxZ = maxZ,
		}
	end

	bounds.minX = math.min(bounds.minX, minX)
	bounds.maxX = math.max(bounds.maxX, maxX)
	bounds.minZ = math.min(bounds.minZ, minZ)
	bounds.maxZ = math.max(bounds.maxZ, maxZ)
	return bounds
end

local function partExtents(part)
	if not part or not part:IsA("BasePart") then
		return nil
	end

	local halfX = part.Size.X * 0.5
	local halfZ = part.Size.Z * 0.5
	return part.Position.X - halfX, part.Position.X + halfX, part.Position.Z - halfZ, part.Position.Z + halfZ
end

local function terrainExtents()
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return nil
	end

	local okSize, size = pcall(function()
		return terrain.Size
	end)
	if not okSize or typeof(size) ~= "Vector3" or size.X <= 0 or size.Z <= 0 then
		return nil
	end

	local okPos, pos = pcall(function()
		return terrain.Position
	end)
	if not okPos or typeof(pos) ~= "Vector3" then
		pos = Vector3.zero
	end

	local halfX = size.X * 0.5
	local halfZ = size.Z * 0.5
	return pos.X - halfX, pos.X + halfX, pos.Z - halfZ, pos.Z + halfZ
end

local function mapExtents()
	local bounds = nil
	local count = 0

	local function consider(inst)
		if not inst:IsA("BasePart") then
			return
		end
		if not inst.CanCollide then
			return
		end
		if inst.Size.Magnitude <= 6 then
			return
		end

		count += 1
		bounds = mergeBounds(bounds, partExtents(inst))
	end

	local map = Workspace:FindFirstChild("Map")
	if map then
		for _, descendant in ipairs(map:GetDescendants()) do
			consider(descendant)
		end
	else
		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if count >= 1000 then
				break
			end
			consider(descendant)
		end
	end

	return bounds
end

function WorldBounds.GetXZ(pad: number?, fallbackMin: Vector2?, fallbackMax: Vector2?)
	local bounds = nil
	bounds = mergeBounds(bounds, terrainExtents())

	local mapBounds = mapExtents()
	if mapBounds then
		bounds = mergeBounds(bounds, mapBounds.minX, mapBounds.maxX, mapBounds.minZ, mapBounds.maxZ)
	end

	if not bounds then
		return fallbackMin or DEFAULT_MIN, fallbackMax or DEFAULT_MAX
	end

	local width = bounds.maxX - bounds.minX
	local depth = bounds.maxZ - bounds.minZ
	if width <= 0 or depth <= 0 then
		return fallbackMin or DEFAULT_MIN, fallbackMax or DEFAULT_MAX
	end

	local safePad = math.max(0, tonumber(pad) or 0)
	safePad = math.min(safePad, width * 0.25, depth * 0.25)

	return Vector2.new(bounds.minX + safePad, bounds.minZ + safePad), Vector2.new(bounds.maxX - safePad, bounds.maxZ - safePad)
end

return WorldBounds
