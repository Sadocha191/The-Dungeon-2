local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(serverModuleFolder, "[NpcMovement] Server ModuleScript folder is required")
local worldBoundsModule = serverModuleFolder:FindFirstChild("WorldBounds")
assert(worldBoundsModule and worldBoundsModule:IsA("ModuleScript"), "[NpcMovement] WorldBounds ModuleScript is required")
local WorldBounds = require(worldBoundsModule)

local NpcMovement = {}

local SPAWN_EMERGE_HOLD_DURATION = 0.35
local SPAWN_EMERGE_RISE_DURATION = 0.85
local SPAWN_EMERGE_MIN_DEPTH = 5.75
local SPAWN_EMERGE_MAX_DEPTH = 16
local SPAWN_EMERGE_EXTRA_DEPTH = 2.75
local DETACHED_VISUAL_REPAIR_MIN_FLAT_DISTANCE = 64

local function enemiesFolder(): Instance?
	return workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Mobs")
end

local function buildTerrainRaycastIgnore(model: Model): { Instance }
	local ignore = { model }
	local enemyRoot = enemiesFolder()
	if enemyRoot then
		table.insert(ignore, enemyRoot)
	end
	local drops = workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignore, drops)
	end
	local chests = workspace:FindFirstChild("Chests")
	if chests then
		table.insert(ignore, chests)
	end
	local shrines = workspace:FindFirstChild("Shrines")
	if shrines then
		table.insert(ignore, shrines)
	end
	local statues = workspace:FindFirstChild("Statues")
	if statues then
		table.insert(ignore, statues)
	end
	local spellVfx = workspace:FindFirstChild("SpellVFX")
	if spellVfx then
		table.insert(ignore, spellVfx)
	end
	local portal = workspace:FindFirstChild("RunPortal")
	if portal then
		table.insert(ignore, portal)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	return ignore
end

local function sampleGroundY(model: Model, pos: Vector3): number?
	local originY = math.max(96, pos.Y + 24)
	local result = WorldBounds.RaycastTerrainAtXZ(pos.X, pos.Z, {
		originY = originY,
		distance = originY + 128,
		ignoreWater = true,
		raycastIgnoreInstances = buildTerrainRaycastIgnore(model),
	})
	if result then
		return result.Position.Y
	end
	return nil
end

local function partYExtents(part: BasePart): (number, number)
	local half = part.Size * 0.5
	local minY = math.huge
	local maxY = -math.huge
	for _, x in ipairs({ -half.X, half.X }) do
		for _, y in ipairs({ -half.Y, half.Y }) do
			for _, z in ipairs({ -half.Z, half.Z }) do
				local world = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
				minY = math.min(minY, world.Y)
				maxY = math.max(maxY, world.Y)
			end
		end
	end
	return minY, maxY
end

local function isVisualGroundingPart(part: BasePart): boolean
	return part.Transparency < 0.95
end

local function modelYExtents(model: Model, visualOnly: boolean): (number?, number?)
	local lowestY = math.huge
	local highestY = -math.huge
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and (not visualOnly or isVisualGroundingPart(descendant)) then
			local partMinY, partMaxY = partYExtents(descendant)
			lowestY = math.min(lowestY, partMinY)
			highestY = math.max(highestY, partMaxY)
		end
	end

	if lowestY == math.huge then
		return nil, nil
	end

	return lowestY, highestY
end

local function visualPartCenter(model: Model): (Vector3?, number)
	local sum = Vector3.zero
	local count = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and isVisualGroundingPart(descendant) then
			sum += descendant.Position
			count += 1
		end
	end
	if count <= 0 then
		return nil, 0
	end
	return sum / count, count
end

local function translateModel(model: Model, delta: Vector3)
	if delta.Magnitude <= 1e-5 then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CFrame += delta
		end
	end
end

local function isBlockingObstacle(inst: Instance?): boolean
	return inst
		and inst:IsA("BasePart")
		and inst.CanCollide
		and inst.Transparency < 0.98
end

local function buildObstacleRaycastIgnore(model: Model): { Instance }
	local ignore = { model }
	local enemyRoot = enemiesFolder()
	if enemyRoot then
		table.insert(ignore, enemyRoot)
	end
	local drops = workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignore, drops)
	end
	local spellVfx = workspace:FindFirstChild("SpellVFX")
	if spellVfx then
		table.insert(ignore, spellVfx)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	local terrain = WorldBounds.GetTerrain()
	if terrain then
		table.insert(ignore, terrain)
	end
	return ignore
end

local function raycastObstacle(origin: Vector3, direction: Vector3, ignoreInstances: { Instance }?): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local ignore = {}
	for _, inst in ipairs(ignoreInstances or {}) do
		if typeof(inst) == "Instance" then
			table.insert(ignore, inst)
		end
	end

	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			return nil
		end
		if isBlockingObstacle(hit.Instance) then
			return hit
		end
		table.insert(ignore, hit.Instance)
	end

	return nil
end

function NpcMovement.ClampMagnitude(v: Vector3, maxMagnitude: number): Vector3
	local magnitude = v.Magnitude
	if magnitude <= maxMagnitude or magnitude <= 1e-6 then
		return v
	end
	return v.Unit * maxMagnitude
end

function NpcMovement.Flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function NpcMovement.FlatMagnitude(a: Vector3, b: Vector3): number
	local d = a - b
	return math.sqrt((d.X * d.X) + (d.Z * d.Z))
end

function NpcMovement.NearestAlivePlayerFlatDistance(pos: Vector3, alivePlayers: {any}): number
	local nearest = math.huge
	for _, info in ipairs(alivePlayers) do
		nearest = math.min(nearest, NpcMovement.FlatMagnitude(info.hrp.Position, pos))
	end
	return nearest
end

function NpcMovement.SafeUnit(v: Vector3, fallback: Vector3?): Vector3
	if v.Magnitude <= 1e-6 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return v.Unit
end

function NpcMovement.RepairDetachedVisualParts(model: Model, root: BasePart)
	local center, count = visualPartCenter(model)
	if not center or count <= 0 then
		return
	end

	local flatDelta = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	if flatDelta.Magnitude < DETACHED_VISUAL_REPAIR_MIN_FLAT_DISTANCE then
		return
	end

	local delta = root.Position - center
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= root then
			descendant.CFrame += delta
		end
	end
end

function NpcMovement.ComputeGroundOffset(model: Model, root: BasePart): number
	local explicitOffset = model:GetAttribute("NpcGroundOffset")
	if typeof(explicitOffset) == "number" then
		return explicitOffset
	end

	local lowestY = modelYExtents(model, true) or modelYExtents(model, false)
	if not lowestY then
		return math.max(0, root.Size.Y * 0.5)
	end
	return root.Position.Y - lowestY
end

function NpcMovement.ComputeModelHeight(model: Model, root: BasePart): number
	local lowestY, highestY = modelYExtents(model, true)
	if not lowestY or not highestY then
		lowestY, highestY = modelYExtents(model, false)
	end
	if lowestY and highestY and highestY > lowestY then
		return highestY - lowestY
	end
	return math.max(1, root.Size.Y)
end

function NpcMovement.ResolveSpawnEmergeDepth(model: Model, root: BasePart, groundOffset: number): number
	local explicitDepth = model:GetAttribute("SpawnEmergeDepth")
	if typeof(explicitDepth) == "number" and explicitDepth > 0 then
		return math.clamp(explicitDepth, 0, SPAWN_EMERGE_MAX_DEPTH)
	end

	local modelHeight = NpcMovement.ComputeModelHeight(model, root)
	local defaultDepth = math.max(
		SPAWN_EMERGE_MIN_DEPTH,
		groundOffset + SPAWN_EMERGE_EXTRA_DEPTH,
		modelHeight * 0.65
	)
	return math.clamp(defaultDepth, SPAWN_EMERGE_MIN_DEPTH, SPAWN_EMERGE_MAX_DEPTH)
end

function NpcMovement.BeginSpawnEmergence(model: Model, root: BasePart, groundOffset: number, now: number)
	if model:GetAttribute("DisableSpawnEmerge") == true
		or model:GetAttribute("IgnoreGroundSnap") == true
		or model:GetAttribute("CanFly") == true then
		return root.Position, nil, 0, 0, 0
	end

	local holdDuration = math.max(0, tonumber(model:GetAttribute("SpawnEmergeHoldDuration")) or SPAWN_EMERGE_HOLD_DURATION)
	local riseDuration = math.max(0.05, tonumber(model:GetAttribute("SpawnEmergeRiseDuration")) or SPAWN_EMERGE_RISE_DURATION)
	local depth = NpcMovement.ResolveSpawnEmergeDepth(model, root, groundOffset)
	local surfacePosition = root.Position
	local undergroundPosition = surfacePosition - Vector3.new(0, depth, 0)

	translateModel(model, undergroundPosition - surfacePosition)

	return undergroundPosition, surfacePosition, now + holdDuration, now + holdDuration + riseDuration, depth
end

function NpcMovement.MoveModelToRoot(npc: any)
	translateModel(npc.model, npc.position - npc.root.Position)
end

function NpcMovement.GroundAdjustedPosition(npc: any, pos: Vector3, now: number, dt: number): Vector3
	local targetY = npc.position.Y
	if now - npc.lastGroundAt >= 0.12 or NpcMovement.FlatMagnitude(pos, npc.lastGroundXZ) >= 4 then
		local groundY = sampleGroundY(npc.model, pos)
		if groundY ~= nil then
			npc.lastGroundAt = now
			npc.lastGroundXZ = Vector3.new(pos.X, 0, pos.Z)
			npc.targetGroundY = groundY + npc.groundOffset
		end
	end
	if npc.targetGroundY ~= nil then
		targetY = npc.position.Y + (npc.targetGroundY - npc.position.Y) * math.min(1, dt * 18)
	end
	return Vector3.new(pos.X, targetY, pos.Z)
end

function NpcMovement.ComputeOrbitTarget(
	npc: any,
	targetPos: Vector3,
	stopDistance: number,
	slot: any?,
	formationWeight: number?,
	config: {[string]: number}
): Vector3
	local weight = math.clamp(tonumber(formationWeight) or 1, 0, 1)
	local toNpc = NpcMovement.Flat(npc.position - targetPos)
	local baseDir = slot and slot.approachDir or NpcMovement.SafeUnit(toNpc, npc.look)
	local tangent = Vector3.new(-baseDir.Z, 0, baseDir.X)
	local lane = slot and slot.lane or 0
	local depth = slot and slot.depth or 0
	local laneOffset = tangent * (lane * config.laneSpacing * weight)
	local depthOffset = baseDir * (depth * config.ringSpacing * weight)
	local jitterOffset = tangent * (npc.orbitSign * npc.orbitRadius * config.jitterScale * weight)
	return targetPos + (baseDir * stopDistance * weight) + depthOffset + laneOffset + jitterOffset
end

function NpcMovement.SteerAroundObstacles(npc: any, desiredMove: Vector3, targetPos: Vector3): Vector3
	local flatMove = NpcMovement.Flat(desiredMove)
	if flatMove.Magnitude <= 0.05 then
		return desiredMove
	end

	local desiredDir = NpcMovement.SafeUnit(flatMove, npc.look)
	local probeDistance = math.max(3.5, flatMove.Magnitude + 2.5)
	local probeOrigin = npc.position + Vector3.new(0, math.max(2.5, npc.groundOffset * 0.65), 0)
	local ignore = buildObstacleRaycastIgnore(npc.model)
	local forwardHit = raycastObstacle(probeOrigin, desiredDir * probeDistance, ignore)
	if not forwardHit then
		return desiredMove
	end

	local toTarget = NpcMovement.SafeUnit(NpcMovement.Flat(targetPos - npc.position), desiredDir)
	local bestDir = nil
	local bestScore = -math.huge
	for _, angle in ipairs({ math.rad(35), -math.rad(35), math.rad(70), -math.rad(70), math.rad(105), -math.rad(105) }) do
		local candidateDir = NpcMovement.SafeUnit(NpcMovement.RotateFlat(desiredDir, angle), desiredDir)
		if not raycastObstacle(probeOrigin, candidateDir * probeDistance, ignore) then
			local score = (candidateDir:Dot(toTarget) * 1.2) + candidateDir:Dot(desiredDir)
			if score > bestScore then
				bestScore = score
				bestDir = candidateDir
			end
		end
	end

	if bestDir then
		return bestDir * flatMove.Magnitude
	end

	local obstacleNormal = NpcMovement.Flat(forwardHit.Normal)
	if obstacleNormal.Magnitude > 0.05 then
		local normalDir = obstacleNormal.Unit
		local slideDir = NpcMovement.Flat(desiredDir - (normalDir * desiredDir:Dot(normalDir)))
		if slideDir.Magnitude > 0.05 then
			slideDir = NpcMovement.SafeUnit(slideDir, desiredDir)
			if not raycastObstacle(probeOrigin, slideDir * probeDistance, ignore) then
				return slideDir * flatMove.Magnitude
			end
		end
	end

	return Vector3.zero
end

function NpcMovement.RotateFlat(v: Vector3, angle: number): Vector3
	local cosAngle = math.cos(angle)
	local sinAngle = math.sin(angle)
	return Vector3.new(
		(v.X * cosAngle) - (v.Z * sinAngle),
		0,
		(v.X * sinAngle) + (v.Z * cosAngle)
	)
end

return NpcMovement
