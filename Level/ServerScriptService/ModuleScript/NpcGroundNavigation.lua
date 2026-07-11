local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(moduleFolder, "[NpcGroundNavigation] Server ModuleScript folder is required")
local Config = require(moduleFolder:WaitForChild("NpcNavigationConfig"))
local WorldBounds = require(moduleFolder:WaitForChild("WorldBounds"))

local NpcGroundNavigation = {}

local corridorParams = RaycastParams.new()
corridorParams.FilterType = Enum.RaycastFilterType.Exclude
corridorParams.IgnoreWater = false
corridorParams.RespectCanCollide = true

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false

local sharedIgnore = {}
local groundIgnore = {}
local surfaceCache = {}
local pathCache = {}
local requestQueue = {}
local queuedNpc = setmetatable({}, { __mode = "k" })
local activePaths = 0
local pathTokens = Config.Scheduler.MaxPathStartsPerSecond
local lastTokenAt = os.clock()
local lastCacheCleanupAt = os.clock()

local metrics = {
	raycastCount = 0,
	blockcastCount = 0,
	surfaceCacheHits = 0,
	pathRequests = 0,
	pathStarts = 0,
	pathSuccesses = 0,
	pathFailures = 0,
	pathCacheHits = 0,
	stalePathResults = 0,
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function safeUnit(v: Vector3, fallback: Vector3?): Vector3
	if v.Magnitude <= 1e-5 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return v.Unit
end

local function sectorKey(pos: Vector3): string
	local size = Config.Scheduler.PathSectorSize
	return string.format("%d:%d:%d", math.floor(pos.X / size), math.floor(pos.Y / 8), math.floor(pos.Z / size))
end

local function pathKey(profile, startPos: Vector3, goalPos: Vector3): string
	return profile.Name .. ":" .. sectorKey(startPos) .. ">" .. sectorKey(goalPos)
end

local function slopeDegrees(normal: Vector3): number
	return math.deg(math.acos(math.clamp(normal:Dot(Vector3.yAxis), -1, 1)))
end

local function surfaceAllowed(hit: RaycastResult, profile): boolean
	if not WorldBounds.IsGroundSurface(hit.Instance) then
		return false
	end
	if hit.Material == Enum.Material.Water and (profile.Costs.Water or 0) >= 1000 then
		return false
	end
	local current = hit.Instance
	while current and current ~= workspace do
		local modifier = current:FindFirstChildWhichIsA("PathfindingModifier")
		if modifier and (profile.Costs[modifier.Label] or 0) >= 1000 then
			return false
		end
		current = current.Parent
	end
	return slopeDegrees(hit.Normal) <= profile.MaxSlopeDegrees
end

local function surfaceKey(pos: Vector3, expectedY: number, profile): string
	local cell = math.max(2.5, profile.AgentRadius * 1.5)
	return string.format(
		"%s:%d:%d:%d",
		profile.Name,
		math.floor(pos.X / cell),
		math.floor(expectedY / 5),
		math.floor(pos.Z / cell)
	)
end

local function sampleSurface(pos: Vector3, expectedSurfaceY: number, profile, now: number): RaycastResult?
	local key = surfaceKey(pos, expectedSurfaceY, profile)
	local cached = surfaceCache[key]
	if cached and cached.expiresAt >= now then
		metrics.surfaceCacheHits += 1
		return cached.hit ~= false and cached.hit or nil
	end

	local rise = profile.MaxStepUp + 2.5
	local origin = Vector3.new(pos.X, expectedSurfaceY + rise, pos.Z)
	local distance = rise + profile.MaxDrop + 3
	metrics.raycastCount += 1
	local hit = workspace:Raycast(origin, Vector3.new(0, -distance, 0), groundParams)
	if hit and not surfaceAllowed(hit, profile) then
		hit = nil
	end
	surfaceCache[key] = {
		expiresAt = now + Config.Scheduler.SurfaceCacheTtl,
		hit = hit or false,
	}
	return hit
end

local function bodyCenter(npc, profile): Vector3
	local surfaceY = npc.position.Y - npc.groundOffset
	return Vector3.new(npc.position.X, surfaceY + (profile.AgentHeight * 0.5) + 0.15, npc.position.Z)
end

local function corridorBlocked(npc, direction: Vector3, profile): boolean
	if direction.Magnitude <= 0.05 then
		return false
	end
	metrics.blockcastCount += 1
	local maximumProbe = math.max(18, profile.AgentRadius * 5)
	if direction.Magnitude > maximumProbe then
		direction = direction.Unit * maximumProbe
	end
	local size = Vector3.new(profile.AgentRadius * 2, math.max(2, profile.AgentHeight - 0.5), profile.AgentRadius * 2)
	local hit = workspace:Blockcast(CFrame.new(bodyCenter(npc, profile)), size, direction, corridorParams)
	return hit ~= nil
end

local function continuityClear(npc, destination: Vector3, profile, now: number): boolean
	local delta = flat(destination - npc.position)
	local distance = delta.Magnitude
	if distance <= 0.05 then
		return true
	end

	local samples = math.clamp(math.ceil(distance / math.max(4, profile.AgentRadius * 2)), 2, 10)
	local previousY = npc.position.Y - npc.groundOffset
	local destinationSurfaceY = destination.Y - npc.groundOffset
	for index = 1, samples do
		local alpha = index / samples
		local point = npc.position + delta * alpha
		local expectedY = previousY + ((destinationSurfaceY - previousY) * alpha)
		local hit = sampleSurface(point, expectedY, profile, now)
		if not hit then
			return false
		end
		local verticalDelta = hit.Position.Y - previousY
		if verticalDelta > profile.MaxStepUp + 0.05 or verticalDelta < -profile.MaxDrop - 0.05 then
			return false
		end
		previousY = hit.Position.Y
	end
	return true
end

local function canTraverse(npc, destination: Vector3, profile, now: number): boolean
	local delta = destination - npc.position
	local flatDelta = flat(delta)
	local probeDestination = destination
	if flatDelta.Magnitude > profile.DirectProbeDistance then
		local alpha = profile.DirectProbeDistance / flatDelta.Magnitude
		probeDestination = npc.position + flatDelta.Unit * profile.DirectProbeDistance + Vector3.new(0, delta.Y * alpha, 0)
	end
	local direction = flat(probeDestination - npc.position)
	if corridorBlocked(npc, direction, profile) then
		return false
	end
	return continuityClear(npc, probeDestination, profile, now)
end

local function getNavigation(npc)
	local nav = npc.navigation
	if nav and nav.mode == "Ground" then
		return nav
	end
	local profile = npc.navigationProfile
	local numericId = tonumber(npc.id) or 0
	nav = {
		mode = "Ground",
		generation = 0,
		waypoints = nil,
		waypointIndex = 1,
		nextDirectCheckAt = os.clock() + ((numericId % 12) / 12) * profile.DirectCheckInterval,
		directClear = nil,
		directSector = nil,
		nextRepathAt = 0,
		pathExpiresAt = 0,
		lastProgressAt = os.clock(),
		lastProgressPosition = npc.position,
		unreachableSince = nil,
		lastRepathReason = "initial",
		status = "Direct",
		debugGroundProbe = nil,
	}
	npc.navigation = nav
	return nav
end

local function transitionAllowed(waypoint, profile): boolean
	local label = waypoint.Label
	if label == "Jump" or waypoint.Action == Enum.PathWaypointAction.Jump then
		return profile.CanJump == true
	end
	if label == "Climb" then
		return profile.CanClimb == true
	end
	if label == "Drop" then
		return profile.CanDrop == true
	end
	return true
end

local function copyWaypoints(path): {any}?
	local result = {}
	for _, waypoint in ipairs(path:GetWaypoints()) do
		table.insert(result, {
			Position = waypoint.Position,
			Action = waypoint.Action,
			Label = waypoint.Label,
		})
	end
	if #result < 2 then
		return nil
	end
	return result
end

local function applyPathResult(request, waypoints, reason: string)
	local npc = request.npc
	local nav = npc.navigation
	if npc.dead or not npc.model.Parent or not nav or nav.generation ~= request.generation then
		metrics.stalePathResults += 1
		return
	end
	if waypoints then
		nav.waypoints = waypoints
		nav.waypointIndex = math.min(2, #waypoints)
		nav.pathExpiresAt = os.clock() + request.profile.PathRefreshSeconds
		nav.status = "Path"
		nav.unreachableSince = nil
		npc.unreachableSince = nil
		if not request.cached then
			metrics.pathSuccesses += 1
		end
	else
		nav.waypoints = nil
		nav.status = "Unreachable"
		nav.unreachableSince = nav.unreachableSince or os.clock()
		npc.unreachableSince = nav.unreachableSince
		nav.lastRepathReason = reason
		if not request.cached then
			metrics.pathFailures += 1
		end
	end
end

local function queuePath(npc, goalPosition: Vector3, profile, now: number, reason: string)
	local nav = getNavigation(npc)
	if queuedNpc[npc] or now < nav.nextRepathAt then
		return
	end

	local startSurface = npc.position - Vector3.new(0, npc.groundOffset, 0)
	local expectedGoalY = goalPosition.Y - npc.groundOffset
	local goalHit = sampleSurface(goalPosition, expectedGoalY, profile, now)
	if not goalHit then
		nav.unreachableSince = nav.unreachableSince or now
		npc.unreachableSince = nav.unreachableSince
		nav.status = "Unreachable"
		nav.lastRepathReason = "missing_goal_surface"
		return
	end

	local goalSurface = goalHit.Position
	local cacheKey = pathKey(profile, startSurface, goalSurface)
	local cached = pathCache[cacheKey]
	if cached and cached.expiresAt >= now then
		metrics.pathCacheHits += 1
		nav.generation += 1
		applyPathResult({ npc = npc, generation = nav.generation, profile = profile, cached = true }, cached.waypoints, "cache")
		return
	end
	if #requestQueue >= Config.Scheduler.MaxPendingPaths then
		nav.status = "PathQueueFull"
		nav.unreachableSince = nav.unreachableSince or now
		npc.unreachableSince = nav.unreachableSince
		nav.lastRepathReason = "path_queue_full"
		return
	end

	nav.generation += 1
	nav.nextRepathAt = now + profile.RepathCooldown
	nav.lastRepathReason = reason
	queuedNpc[npc] = true
	metrics.pathRequests += 1
	table.insert(requestQueue, {
		npc = npc,
		generation = nav.generation,
		profile = profile,
		startPosition = startSurface,
		goalPosition = goalSurface,
		cacheKey = cacheKey,
	})
end

local function startPathRequest(request)
	activePaths += 1
	metrics.pathStarts += 1
	task.spawn(function()
		local profile = request.profile
		local path = PathfindingService:CreatePath({
			AgentRadius = profile.AgentRadius,
			AgentHeight = profile.AgentHeight,
			AgentCanJump = profile.AgentCanJump,
			AgentCanClimb = profile.AgentCanClimb,
			WaypointSpacing = profile.WaypointSpacing,
			Costs = profile.Costs,
		})
		local ok = pcall(function()
			path:ComputeAsync(request.startPosition, request.goalPosition)
		end)
		local waypoints = nil
		local failureReason = "compute_failed"
		if ok and path.Status == Enum.PathStatus.Success then
			waypoints = copyWaypoints(path)
			if waypoints then
				for _, waypoint in ipairs(waypoints) do
					if not transitionAllowed(waypoint, profile) then
						waypoints = nil
						failureReason = "transition_not_allowed"
						break
					end
				end
			end
		else
			failureReason = tostring(path.Status)
		end
		if waypoints then
			pathCache[request.cacheKey] = {
				waypoints = waypoints,
				expiresAt = os.clock() + Config.Scheduler.PathCacheTtl,
			}
		end
		applyPathResult(request, waypoints, failureReason)
		queuedNpc[request.npc] = nil
		activePaths -= 1
	end)
end

local function constrainStep(npc, candidate: Vector3, profile, now: number, expectedY: number?): Vector3?
	local currentSurfaceY = npc.position.Y - npc.groundOffset
	local hit = sampleSurface(candidate, expectedY or currentSurfaceY, profile, now)
	local nav = getNavigation(npc)
	nav.debugGroundProbe = hit and hit.Position or nil
	if not hit then
		return nil
	end
	local deltaY = hit.Position.Y - currentSurfaceY
	if deltaY > profile.MaxStepUp + 0.05 or deltaY < -profile.MaxDrop - 0.05 then
		return nil
	end
	return Vector3.new(candidate.X, hit.Position.Y + npc.groundOffset, candidate.Z)
end

local function markProgress(npc, nav, nextPosition: Vector3, profile, now: number)
	if flat(nextPosition - nav.lastProgressPosition).Magnitude >= profile.StuckDistance then
		nav.lastProgressPosition = nextPosition
		nav.lastProgressAt = now
		nav.unreachableSince = nil
		npc.unreachableSince = nil
	end
end

function NpcGroundNavigation.BeginTick(alivePlayers: {any})
	table.clear(sharedIgnore)
	table.clear(groundIgnore)
	for _, name in ipairs({ "Enemies", "Mobs", "Drops", "SpellVFX" }) do
		local inst = workspace:FindFirstChild(name)
		if inst then
			table.insert(sharedIgnore, inst)
			table.insert(groundIgnore, inst)
		end
	end
	for _, name in ipairs({ "Chests", "Shrines", "Statues" }) do
		local inst = workspace:FindFirstChild(name)
		if inst then
			table.insert(groundIgnore, inst)
		end
	end
	for _, info in ipairs(alivePlayers) do
		local character = info.player.Character
		if character then
			table.insert(sharedIgnore, character)
			table.insert(groundIgnore, character)
		end
	end
	corridorParams.FilterDescendantsInstances = sharedIgnore
	groundParams.FilterDescendantsInstances = groundIgnore
end

function NpcGroundNavigation.BuildSpatialGrid(npcPairs: () -> ()): {[string]: {any}}
	local grid = {}
	local cellSize = Config.Scheduler.SpatialCellSize
	for _, npc in npcPairs() do
		if not npc.dead and npc.movementMode == "Ground" then
			local key = math.floor(npc.position.X / cellSize) .. ":" .. math.floor(npc.position.Z / cellSize)
			local bucket = grid[key]
			if not bucket then
				bucket = {}
				grid[key] = bucket
			end
			table.insert(bucket, npc)
		end
	end
	return grid
end

function NpcGroundNavigation.GetSeparation(npc, grid): Vector3
	local cellSize = Config.Scheduler.SpatialCellSize
	local cx = math.floor(npc.position.X / cellSize)
	local cz = math.floor(npc.position.Z / cellSize)
	local radius = npc.navigationProfile.AgentRadius
	local separation = Vector3.zero
	local neighborCount = 0
	for x = cx - 1, cx + 1 do
		for z = cz - 1, cz + 1 do
			for _, other in ipairs(grid[x .. ":" .. z] or {}) do
				if other ~= npc then
					local delta = flat(npc.position - other.position)
					local desired = radius + other.navigationProfile.AgentRadius
					local distance = delta.Magnitude
					if distance > 0.01 and distance < desired then
						separation += delta.Unit * ((desired - distance) / desired)
						neighborCount += 1
					end
				end
			end
		end
	end
	if neighborCount <= 0 then
		return Vector3.zero
	end
	return separation / neighborCount
end

function NpcGroundNavigation.Step(
	npc,
	goalPosition: Vector3,
	desiredPosition: Vector3,
	speed: number,
	dt: number,
	now: number,
	separation: Vector3?
): (Vector3, string)
	local profile = npc.navigationProfile
	local nav = getNavigation(npc)
	local goalSector = sectorKey(goalPosition)
	if nav.goalSector and nav.goalSector ~= goalSector then
		nav.waypoints = nil
		nav.generation += 1
		nav.lastRepathReason = "goal_sector_changed"
	end
	nav.goalSector = goalSector

	if nav.waypoints and now >= nav.pathExpiresAt then
		nav.waypoints = nil
		queuePath(npc, goalPosition, profile, now, "path_expired")
	end

	local moveTarget = desiredPosition
	local specialTransition = false
	if nav.waypoints then
		local waypoint = nav.waypoints[nav.waypointIndex]
		if waypoint then
			moveTarget = waypoint.Position + Vector3.new(0, npc.groundOffset, 0)
			specialTransition = waypoint.Label == "Jump"
				or waypoint.Label == "Climb"
				or waypoint.Label == "Drop"
				or waypoint.Action == Enum.PathWaypointAction.Jump
			if (moveTarget - npc.position).Magnitude <= math.max(1.5, profile.AgentRadius * 0.7) then
				nav.waypointIndex += 1
				waypoint = nav.waypoints[nav.waypointIndex]
				if waypoint then
					moveTarget = waypoint.Position + Vector3.new(0, npc.groundOffset, 0)
				else
					nav.waypoints = nil
					moveTarget = desiredPosition
				end
			end
		else
			nav.waypoints = nil
		end
	end

	if not nav.waypoints then
		local desiredSector = sectorKey(desiredPosition)
		local directSectorChanged = nav.directSector ~= nil and nav.directSector ~= desiredSector
		if now >= nav.nextDirectCheckAt or directSectorChanged then
			nav.directClear = canTraverse(npc, desiredPosition, profile, now)
			nav.directSector = desiredSector
			local targetDistance = flat(goalPosition - npc.position).Magnitude
			local lodMultiplier = targetDistance >= 160 and 2.5 or (targetDistance >= 80 and 1.5 or 1)
			nav.nextDirectCheckAt = now + profile.DirectCheckInterval * lodMultiplier
		elseif nav.directClear == nil then
			nav.status = "CheckingDirect"
			return Vector3.zero, nav.status
		end
		if not nav.directClear then
			queuePath(npc, goalPosition, profile, now, "direct_blocked")
			nav.status = nav.waypoints and "Path" or "WaitingPath"
			if not nav.unreachableSince and now - nav.lastProgressAt >= profile.StuckSeconds then
				nav.unreachableSince = now
				npc.unreachableSince = now
			end
			return Vector3.zero, nav.status
		end
		nav.status = "Direct"
	end

	local toTarget = specialTransition and (moveTarget - npc.position) or flat(moveTarget - npc.position)
	if toTarget.Magnitude <= 0.05 or speed <= 0 then
		return Vector3.zero, nav.status
	end

	local step = safeUnit(toTarget) * math.min(toTarget.Magnitude, speed * dt)
	if not specialTransition and separation and separation.Magnitude > 0.01 then
		step += safeUnit(separation) * math.min(speed * dt * 0.3, separation.Magnitude)
	end
	local candidate = npc.position + step
	local constrained = nil
	if specialTransition then
		constrained = candidate
	else
		local expectedY = nav.waypoints and (moveTarget.Y - npc.groundOffset) or nil
		constrained = constrainStep(npc, candidate, profile, now, expectedY)
	end

	if not constrained or corridorBlocked(npc, flat(constrained - npc.position), profile) then
		queuePath(npc, goalPosition, profile, now, "step_blocked")
		if nav.waypoints then
			nav.waypoints = nil
		end
		nav.status = "WaitingPath"
		return Vector3.zero, nav.status
	end

	markProgress(npc, nav, constrained, profile, now)
	if now - nav.lastProgressAt >= profile.StuckSeconds then
		queuePath(npc, goalPosition, profile, now, "stuck")
	end
	return constrained - npc.position, nav.status
end

function NpcGroundNavigation.ConstrainPosition(npc, candidate: Vector3, now: number): Vector3
	return constrainStep(npc, candidate, npc.navigationProfile, now) or npc.position
end

function NpcGroundNavigation.StepScheduler(now: number)
	if now - lastCacheCleanupAt >= 2 then
		lastCacheCleanupAt = now
		for key, cached in pairs(surfaceCache) do
			if cached.expiresAt < now then
				surfaceCache[key] = nil
			end
		end
		for key, cached in pairs(pathCache) do
			if cached.expiresAt < now then
				pathCache[key] = nil
			end
		end
	end
	local elapsed = math.max(0, now - lastTokenAt)
	lastTokenAt = now
	pathTokens = math.min(
		Config.Scheduler.MaxPathStartsPerSecond,
		pathTokens + elapsed * Config.Scheduler.MaxPathStartsPerSecond
	)
	while activePaths < Config.Scheduler.MaxConcurrentPaths and pathTokens >= 1 and #requestQueue > 0 do
		local request = table.remove(requestQueue, 1)
		if request.npc.dead
			or not request.npc.model.Parent
			or not request.npc.navigation
			or request.npc.navigation.generation ~= request.generation then
			queuedNpc[request.npc] = nil
		else
			pathTokens -= 1
			startPathRequest(request)
		end
	end
end

function NpcGroundNavigation.Invalidate(npc, reason: string?)
	local nav = npc.navigation
	if nav then
		nav.generation += 1
		nav.waypoints = nil
		nav.nextDirectCheckAt = 0
		nav.lastRepathReason = reason or "invalidated"
	end
	queuedNpc[npc] = nil
end

function NpcGroundNavigation.Cleanup(npc)
	NpcGroundNavigation.Invalidate(npc, "cleanup")
	npc.navigation = nil
	npc.unreachableSince = nil
end

function NpcGroundNavigation.GetMetrics(): {[string]: any}
	local result = table.clone(metrics)
	result.pendingPaths = #requestQueue
	result.activePaths = activePaths
	result.pathCacheEntries = 0
	for _ in pairs(pathCache) do
		result.pathCacheEntries += 1
	end
	return result
end

function NpcGroundNavigation.GetDebug(npc): {[string]: any}?
	local nav = npc.navigation
	if not nav or nav.mode ~= "Ground" then
		return nil
	end
	return {
		profile = npc.movementProfile,
		target = npc.targetPlayer and npc.targetPlayer.Name or nil,
		targetPosition = npc.targetPlayer
			and npc.targetPlayer.Character
			and npc.targetPlayer.Character:FindFirstChild("HumanoidRootPart")
			and npc.targetPlayer.Character.HumanoidRootPart.Position
			or nil,
		status = nav.status,
		waypoints = nav.waypoints,
		waypointIndex = nav.waypointIndex,
		lastRepathReason = nav.lastRepathReason,
		unreachable = nav.unreachableSince ~= nil,
		groundProbe = nav.debugGroundProbe,
	}
end

return NpcGroundNavigation
