local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local WorldBounds = {}

local DEFAULT_MIN = Vector2.new(-180, -180)
local DEFAULT_MAX = Vector2.new(180, 180)
local DEFAULT_RANDOM_TRIES = 40
local DEFAULT_RAY_ORIGIN_Y = 420
local DEFAULT_RAY_DISTANCE = 900
local DEFAULT_NEARBY_RADII = { 0, 4, 8, 12 }
local GROUND_SURFACE_TAGS = { "Terrain", "NpcWalkable" }

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

local function getTerrain()
	return Workspace:FindFirstChildOfClass("Terrain")
end

local function hasGroundTag(inst): boolean
	local current = inst
	while current and current ~= Workspace do
		for _, tagName in ipairs(GROUND_SURFACE_TAGS) do
			if CollectionService:HasTag(current, tagName) then
				return true
			end
		end
		current = current.Parent
	end
	return false
end

local function forEachTaggedGroundPart(visitor)
	local seen = {}
	for _, tagName in ipairs(GROUND_SURFACE_TAGS) do
		for _, inst in ipairs(CollectionService:GetTagged(tagName)) do
			if inst:IsA("BasePart") then
				if not seen[inst] then
					seen[inst] = true
					visitor(inst)
				end
			else
				for _, descendant in ipairs(inst:GetDescendants()) do
					if descendant:IsA("BasePart") and not seen[descendant] then
						seen[descendant] = true
						visitor(descendant)
					end
				end
			end
		end
	end
end

local function taggedGroundExtents()
	local bounds = nil
	forEachTaggedGroundPart(function(part)
		bounds = mergeBounds(bounds, partExtents(part))
	end)
	return bounds
end

local function isGroundSurface(inst): boolean
	return (inst and inst == getTerrain()) or hasGroundTag(inst)
end

local function terrainExtents()
	local terrain = getTerrain()
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

local function buildInstanceList(values)
	local list = {}
	if type(values) ~= "table" then
		return list
	end

	for _, inst in ipairs(values) do
		if typeof(inst) == "Instance" then
			table.insert(list, inst)
		end
	end

	return list
end

local function buildRaycastParams(ignoreInstances, ignoreWater)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = buildInstanceList(ignoreInstances)
	params.IgnoreWater = ignoreWater == true
	return params
end

local function buildOverlapParams(ignoreInstances)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = buildInstanceList(ignoreInstances)
	return params
end

local function isBlockingPart(inst)
	return inst
		and inst:IsA("BasePart")
		and inst.CanCollide
		and inst.Transparency < 0.98
end

local function slopeDeg(normal: Vector3): number
	local dot = math.clamp(normal:Dot(Vector3.new(0, 1, 0)), -1, 1)
	return math.deg(math.acos(dot))
end

function WorldBounds.GetTerrain()
	return getTerrain()
end

function WorldBounds.IsGroundSurface(inst: Instance?): boolean
	return isGroundSurface(inst)
end

function WorldBounds.GetXZ(pad: number?, fallbackMin: Vector2?, fallbackMax: Vector2?)
	local bounds = nil
	bounds = mergeBounds(bounds, terrainExtents())
	bounds = mergeBounds(bounds, taggedGroundExtents())

	if not bounds then
		local mapBounds = mapExtents()
		if mapBounds then
			bounds = mergeBounds(bounds, mapBounds.minX, mapBounds.maxX, mapBounds.minZ, mapBounds.maxZ)
		end
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

function WorldBounds.RaycastTerrain(origin: Vector3, direction: Vector3, ignoreInstances: { Instance }?, ignoreWater: boolean?)
	local ignore = buildInstanceList(ignoreInstances)
	for _ = 1, 8 do
		local hit = Workspace:Raycast(origin, direction, buildRaycastParams(ignore, ignoreWater))
		if not hit then
			return nil
		end
		if isGroundSurface(hit.Instance) then
			return hit
		end
		table.insert(ignore, hit.Instance)
	end

	return nil
end

function WorldBounds.RaycastTerrainAtXZ(x: number, z: number, options)
	options = options or {}

	local originY = tonumber(options.originY) or DEFAULT_RAY_ORIGIN_Y
	local distance = math.max(0, tonumber(options.distance) or DEFAULT_RAY_DISTANCE)
	if distance <= 0 then
		return nil
	end

	local origin = Vector3.new(x, originY, z)
	return WorldBounds.RaycastTerrain(origin, Vector3.new(0, -distance, 0), options.raycastIgnoreInstances, options.ignoreWater)
end

function WorldBounds.IsAreaClear(pos: Vector3, radius: number, height: number?, ignoreInstances: { Instance }?)
	if typeof(pos) ~= "Vector3" then
		return false
	end

	local safeRadius = math.max(0, tonumber(radius) or 0)
	if safeRadius <= 0 then
		return true
	end

	local safeHeight = math.max(4, tonumber(height) or 8)
	local box = Vector3.new(safeRadius * 2, safeHeight, safeRadius * 2)
	local center = pos + Vector3.new(0, safeHeight * 0.5, 0)
	local hits = Workspace:GetPartBoundsInBox(CFrame.new(center), box, buildOverlapParams(ignoreInstances))

	for _, hit in ipairs(hits) do
		if isBlockingPart(hit) and not isGroundSurface(hit) then
			return false, hit
		end
	end

	return true
end

local function pointMatchesRules(pos: Vector3, hit, options)
	local maxSlope = tonumber(options.maxSlopeDeg)
	if maxSlope and slopeDeg(hit.Normal) > maxSlope then
		return false
	end

	local radius = tonumber(options.clearanceRadius)
	if radius and radius > 0 then
		local clear = WorldBounds.IsAreaClear(pos, radius, options.clearanceHeight, options.overlapIgnoreInstances)
		if clear ~= true then
			return false
		end
	end

	local validator = options.isValid
	if type(validator) == "function" then
		return validator(pos, hit) == true
	end

	return true
end

function WorldBounds.FindRandomTerrainPoint(options)
	options = options or {}

	local boundsMin = options.boundsMin
	local boundsMax = options.boundsMax
	if typeof(boundsMin) ~= "Vector2" or typeof(boundsMax) ~= "Vector2" then
		boundsMin, boundsMax = WorldBounds.GetXZ(options.pad, options.fallbackMin, options.fallbackMax)
	end
	if typeof(boundsMin) ~= "Vector2" or typeof(boundsMax) ~= "Vector2" then
		return nil
	end

	local tries = math.max(1, math.floor(tonumber(options.tries) or DEFAULT_RANDOM_TRIES))
	local heightOffset = tonumber(options.heightOffset) or 0

	for _ = 1, tries do
		local x = boundsMin.X + math.random() * (boundsMax.X - boundsMin.X)
		local z = boundsMin.Y + math.random() * (boundsMax.Y - boundsMin.Y)
		local hit = WorldBounds.RaycastTerrainAtXZ(x, z, options)
		if hit then
			local pos = hit.Position + Vector3.new(0, heightOffset, 0)
			if pointMatchesRules(pos, hit, options) then
				return pos, hit
			end
		end
	end

	return nil
end

function WorldBounds.FindNearbyTerrainPoint(center: Vector3, options)
	options = options or {}
	if typeof(center) ~= "Vector3" then
		return nil
	end

	local radii = options.searchRadii
	if type(radii) ~= "table" or #radii == 0 then
		radii = DEFAULT_NEARBY_RADII
	end

	local samplesPerRing = math.max(1, math.floor(tonumber(options.samplesPerRing) or 8))
	local heightOffset = tonumber(options.heightOffset) or 0
	local distance = tonumber(options.distance) or DEFAULT_RAY_DISTANCE

	for _, ringRadius in ipairs(radii) do
		local radius = math.max(0, tonumber(ringRadius) or 0)
		local sampleCount = radius <= 0 and 1 or samplesPerRing
		local angleOffset = math.random() * math.pi * 2

		for sampleIndex = 1, sampleCount do
			local angle = sampleCount == 1 and 0 or angleOffset + (((sampleIndex - 1) / sampleCount) * math.pi * 2)
			local x = center.X + math.cos(angle) * radius
			local z = center.Z + math.sin(angle) * radius

			local castOptions = table.clone(options)
			castOptions.originY = math.max(tonumber(options.originY) or DEFAULT_RAY_ORIGIN_Y, center.Y + 64)
			castOptions.distance = math.max(distance, castOptions.originY + 64)

			local hit = WorldBounds.RaycastTerrainAtXZ(x, z, castOptions)
			if hit then
				local pos = hit.Position + Vector3.new(0, heightOffset, 0)
				if pointMatchesRules(pos, hit, options) then
					return pos, hit
				end
			end
		end
	end

	return nil
end

return WorldBounds
