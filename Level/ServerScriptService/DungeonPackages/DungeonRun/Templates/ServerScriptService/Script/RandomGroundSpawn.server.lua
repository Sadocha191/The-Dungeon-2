-- RandomGroundSpawn.server.lua
-- Spawns the player at a random point on dry Terrain only.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBounds = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("WorldBounds"))

local TRY_POINTS = 180
local SAFE_Y_OFFSET = 6
local CLEARANCE_RADIUS = 4
local CLEARANCE_HEIGHT = 10

local function collectSpawnPoints()
	local root = Workspace:FindFirstChild("PlayerSpawns") or Workspace:FindFirstChild("Spawns") or Workspace:FindFirstChild("SpawnPoints")
	local points = {}

	local function collect(folder)
		for _, descendant in ipairs(folder:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(points, descendant)
			end
		end
	end

	if root and root:IsA("Folder") then
		collect(root)
	end

	local playerSpawns = Workspace:FindFirstChild("PlayerSpawns")
	if playerSpawns then
		local nested = playerSpawns:FindFirstChild("Spawns") or playerSpawns:FindFirstChild("SpawnPoints")
		if nested and nested:IsA("Folder") then
			collect(nested)
		end
	end

	return points
end

local function collectSpawnLocations()
	local spawns = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("SpawnLocation") then
			table.insert(spawns, descendant)
		end
	end
	return spawns
end

local function buildRaycastIgnore()
	local ignore = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		table.insert(ignore, enemies)
	end
	local drops = Workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignore, drops)
	end
	return ignore
end

local function buildOverlapIgnore(character)
	local ignore = buildRaycastIgnore()
	if character then
		table.insert(ignore, character)
	end
	return ignore
end

local function isDrySpawnSurface(_pos: Vector3, hit: RaycastResult): boolean
	return hit.Material ~= Enum.Material.Water
end

local function resolveTerrainSpawn(pos: Vector3, character: Model)
	return WorldBounds.FindNearbyTerrainPoint(pos, {
		heightOffset = SAFE_Y_OFFSET,
		raycastIgnoreInstances = buildRaycastIgnore(),
		overlapIgnoreInstances = buildOverlapIgnore(character),
		clearanceRadius = CLEARANCE_RADIUS,
		clearanceHeight = CLEARANCE_HEIGHT,
		samplesPerRing = 10,
		searchRadii = { 0, 6, 12, 18 },
		maxSlopeDeg = 35,
		isValid = isDrySpawnSurface,
	})
end

local function pickRandomGroundPoint(character: Model)
	return WorldBounds.FindRandomTerrainPoint({
		pad = 18,
		tries = TRY_POINTS,
		heightOffset = SAFE_Y_OFFSET,
		raycastIgnoreInstances = buildRaycastIgnore(),
		overlapIgnoreInstances = buildOverlapIgnore(character),
		clearanceRadius = CLEARANCE_RADIUS,
		clearanceHeight = CLEARANCE_HEIGHT,
		maxSlopeDeg = 35,
		fallbackMin = Vector2.new(-180, -180),
		fallbackMax = Vector2.new(180, 180),
		isValid = isDrySpawnSurface,
	})
end

local function setCharacterCFrame(character, worldPos)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	character:PivotTo(CFrame.new(worldPos))
end

local function pickRandomResolvedPosition(parts, character)
	local remaining = table.clone(parts)
	while #remaining > 0 do
		local index = math.random(1, #remaining)
		local candidate = table.remove(remaining, index)
		local grounded = resolveTerrainSpawn(candidate.Position, character)
		if grounded then
			return grounded
		end
	end
	return nil
end

local function spawnCharacterRandomly(_player, character)
	local points = collectSpawnPoints()
	local pointPos = pickRandomResolvedPosition(points, character)
	if pointPos then
		setCharacterCFrame(character, pointPos)
		return
	end

	local spawns = collectSpawnLocations()
	local spawnPos = pickRandomResolvedPosition(spawns, character)
	if spawnPos then
		setCharacterCFrame(character, spawnPos)
		return
	end

	local pos = pickRandomGroundPoint(character)
	if pos then
		setCharacterCFrame(character, pos)
		return
	end

	warn("[RandomGroundSpawn] Failed to find random dry Terrain point")
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		spawnCharacterRandomly(player, character)
	end)
end)
