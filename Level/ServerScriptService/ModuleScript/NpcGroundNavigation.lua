local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(moduleFolder, "[NpcGroundNavigation] Server ModuleScript folder is required")

local Config = require(moduleFolder:WaitForChild("NpcNavigationConfig"))
local NpcGroundSurface = require(moduleFolder:WaitForChild("NpcGroundSurface"))

local NpcGroundNavigation = {}

-- PathfindingService owns every ground route. The shared scheduler below only
-- limits ComputeAsync pressure and advances the server-authoritative kinematic
-- records along native PathWaypoints. This intentionally preserves the current
-- batched replication architecture instead of creating one Humanoid/connection
-- loop per enemy.
local pathCache = {}
local requestQueue = {}
local queuedNpc = setmetatable({}, { __mode = "k" })
local nativeCostsByProfile = {}
local activePaths = 0
local pathTokens = Config.Scheduler.MaxPathStartsPerSecond
local lastTokenAt = os.clock()
local lastCacheCleanupAt = os.clock()

local metrics = {
	pathRequests = 0,
	pathStarts = 0,
	pathSuccesses = 0,
	pathFailures = 0,
	pathCacheHits = 0,
	pathCacheEvictions = 0,
	pathQueueFull = 0,
	stalePathResults = 0,
	nativePathTicks = 0,
	nativeFallbackTicks = 0,
	waitingPathTicks = 0,
	blockedStepTicks = 0,
	stalledMovementTicks = 0,
	stuckRepaths = 0,
	waypointsReached = 0,
	stateTransitions = 0,
	traversalStarts = 0,
	traversalCompletions = 0,
	traversalFailures = 0,

	-- Kept for existing metrics consumers. Route planning no longer performs
	-- custom long-range direct probes or custom local obstacle traversal.
	directChecks = 0,
	directCheckFailures = 0,
	stepValidationFailures = 0,
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

local function setStatus(nav, status: string)
	if nav.status ~= status then
		nav.status = status
		metrics.stateTransitions += 1
	end
end

local function getNativeCosts(profile): {[string]: number}
	local cached = nativeCostsByProfile[profile.Name]
	if cached then
		return cached
	end

	local nativeCosts = {}
	for label, cost in pairs(profile.Costs or {}) do
		-- Existing profiles use 1000 as their project-level blocking sentinel.
		-- Roblox PathfindingService uses math.huge for a truly non-traversable label.
		nativeCosts[label] = cost >= 1000 and math.huge or cost
	end
	nativeCostsByProfile[profile.Name] = nativeCosts
	return nativeCosts
end

local function sectorCoordinate(value: number, size: number): number
	return math.floor(value / size)
end

local function pathPointKey(position: Vector3): string
	local sectorSize = Config.Scheduler.PathSectorSize
	local layerResolution = Config.Scheduler.PathLayerResolution
	return string.format(
		"%d:%d:%d",
		sectorCoordinate(position.X, sectorSize),
		sectorCoordinate(position.Z, sectorSize),
		math.floor((position.Y / layerResolution) + 0.5)
	)
end

local function pathKey(profile, startPosition: Vector3, goalPosition: Vector3): string
	return profile.Name .. ":" .. pathPointKey(startPosition) .. ">" .. pathPointKey(goalPosition)
end

local function waypointReachDistance(profile): number
	return math.max(1.25, math.min(4, profile.AgentRadius * 0.75))
end

local function getNavigation(npc)
	local nav = npc.navigation
	if nav and nav.mode == "GroundNative" then
		return nav
	end

	local now = os.clock()
	nav = {
		mode = "GroundNative",
		generation = 0,
		status = "NativePathPending",
		waypoints = nil,
		waypointIndex = 1,
		pathPending = false,
		pendingGeneration = nil,
		pathGoalPosition = nil,
		pathExpiresAt = 0,
		pathCacheKey = nil,
		nextRepathAt = 0,
		lastRepathReason = "initial",
		unreachableSince = nil,
		blockedSince = nil,
		stepFailureCount = 0,
		lastStepCheck = nil,
		lastMoveReason = "initial",
		lastProgressAt = now,
		lastProgressPosition = npc.position,
		lastSafePosition = npc.position,
		lastSafeSurfaceY = npc.position.Y - npc.groundOffset,
		zeroMoveTicksWithTarget = 0,
		consecutiveZeroMoveTicks = 0,
		debugGroundProbe = nil,
		traversal = nil,
	}
	npc.navigation = nav
	return nav
end

local function transitionAllowed(waypoint, profile): boolean
	local label = waypoint.Label
	if waypoint.Action == Enum.PathWaypointAction.Jump or label == "Jump" then
		return profile.AgentCanJump == true
	end
	if label == "Climb" then
		return profile.AgentCanClimb == true
	end
	if label == "Drop" then
		return profile.CanDrop == true
	end
	return true
end

local function copyWaypoints(path): {any}?
	local copied = {}
	for _, waypoint in ipairs(path:GetWaypoints()) do
		table.insert(copied, {
			Position = waypoint.Position,
			Action = waypoint.Action,
			Label = waypoint.Label,
		})
	end
	return #copied >= 2 and copied or nil
end

local function chooseStartingWaypoint(npc, waypoints: {any}): number
	local bestIndex = math.min(2, #waypoints)
	local bestDistance = math.huge
	for index = 2, math.min(#waypoints, 6) do
		local rootTarget = waypoints[index].Position + Vector3.new(0, npc.groundOffset, 0)
		local distance = (rootTarget - npc.position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestIndex = index
		end
	end
	return bestIndex
end

local function clearPendingForRequest(nav, request)
	if nav and nav.pendingGeneration == request.generation then
		nav.pathPending = false
		nav.pendingGeneration = nil
	end
end

local function clearQueuedRequest(request)
	if queuedNpc[request.npc] == request then
		queuedNpc[request.npc] = nil
	end
end

local function applyPathResult(request, waypoints, reason: string)
	local npc = request.npc
	local nav = npc.navigation
	if npc.dead or not npc.model.Parent or not nav or nav.generation ~= request.generation then
		metrics.stalePathResults += 1
		clearPendingForRequest(nav, request)
		return
	end

	clearPendingForRequest(nav, request)
	if waypoints then
		local acceptedAt = os.clock()
		nav.waypoints = waypoints
		nav.waypointIndex = chooseStartingWaypoint(npc, waypoints)
		nav.pathGoalPosition = request.requestedGoalPosition
		nav.pathExpiresAt = acceptedAt + request.profile.PathRefreshSeconds
		nav.pathCacheKey = request.cacheKey
		nav.stepFailureCount = 0
		nav.blockedSince = nil
		nav.lastProgressAt = acceptedAt
		nav.lastProgressPosition = npc.position
		nav.lastRepathReason = request.cached and "cache_hit" or "computed"
		nav.unreachableSince = nil
		npc.unreachableSince = nil
		setStatus(nav, "NativePath")
		if not request.cached then
			metrics.pathSuccesses += 1
		end
		return
	end

	nav.waypoints = nil
	nav.pathCacheKey = nil
	nav.lastRepathReason = reason
	nav.unreachableSince = nav.unreachableSince or os.clock()
	npc.unreachableSince = nav.unreachableSince
	setStatus(nav, "Unreachable")
	if not request.cached then
		metrics.pathFailures += 1
	end
end

local function invalidateRoute(npc, nav, reason: string)
	nav.generation += 1
	nav.waypoints = nil
	nav.waypointIndex = 1
	nav.pathPending = false
	nav.pendingGeneration = nil
	nav.pathCacheKey = nil
	nav.pathExpiresAt = 0
	nav.lastRepathReason = reason
	queuedNpc[npc] = nil
end

local function evictActiveRouteCache(nav)
	if not nav.pathCacheKey then
		return
	end
	if pathCache[nav.pathCacheKey] then
		pathCache[nav.pathCacheKey] = nil
		metrics.pathCacheEvictions += 1
	end
	nav.pathCacheKey = nil
end

local function queuePath(npc, goalPosition: Vector3, profile, now: number, reason: string): boolean
	local nav = getNavigation(npc)
	if nav.pathPending or queuedNpc[npc] or now < nav.nextRepathAt then
		return false
	end

	local currentSurfaceY = nav.lastSafeSurfaceY or (npc.position.Y - npc.groundOffset)
	local startSample = NpcGroundSurface.SamplePrecise(npc.position, currentSurfaceY, profile)
	local goalSample = NpcGroundSurface.SamplePrecise(goalPosition, goalPosition.Y - npc.groundOffset, profile)
	local startReason = startSample and NpcGroundSurface.GetFailureReason(startSample, profile) or nil
	local goalReason = goalSample and NpcGroundSurface.GetFailureReason(goalSample, profile) or nil
	if not startSample or startReason or not goalSample or goalReason then
		nav.unreachableSince = nav.unreachableSince or now
		npc.unreachableSince = nav.unreachableSince
		if not startSample then
			nav.lastRepathReason = "missing_start_surface"
		elseif startReason then
			nav.lastRepathReason = startReason
		elseif not goalSample then
			nav.lastRepathReason = "missing_goal_surface"
		else
			nav.lastRepathReason = goalReason or "invalid_goal_surface"
		end
		setStatus(nav, "Unreachable")
		return false
	end

	local cacheKey = pathKey(profile, startSample.position, goalSample.position)
	local cached = pathCache[cacheKey]
	if cached and cached.expiresAt >= now then
		metrics.pathCacheHits += 1
		nav.generation += 1
		nav.pathGoalPosition = goalPosition
		applyPathResult({
			npc = npc,
			generation = nav.generation,
			profile = profile,
			cacheKey = cacheKey,
			requestedGoalPosition = goalPosition,
			cached = true,
		}, cached.waypoints, "cache")
		return true
	end

	if #requestQueue >= Config.Scheduler.MaxPendingPaths then
		metrics.pathQueueFull += 1
		nav.unreachableSince = nav.unreachableSince or now
		npc.unreachableSince = nav.unreachableSince
		nav.lastRepathReason = "path_queue_full"
		setStatus(nav, "PathQueueFull")
		return false
	end

	nav.generation += 1
	nav.pathPending = true
	nav.pendingGeneration = nav.generation
	nav.pathGoalPosition = goalPosition
	nav.nextRepathAt = now + profile.RepathCooldown
	nav.lastRepathReason = reason
	setStatus(nav, "NativePathPending")
	metrics.pathRequests += 1

	local request = {
		npc = npc,
		generation = nav.generation,
		profile = profile,
		startPosition = startSample.position,
		goalPosition = goalSample.position,
		requestedGoalPosition = goalPosition,
		cacheKey = cacheKey,
		cached = false,
	}
	queuedNpc[npc] = request
	table.insert(requestQueue, request)
	return true
end

local function startPathRequest(request)
	activePaths += 1
	metrics.pathStarts += 1

	task.spawn(function()
		local ok, waypointsOrError, failureReason = xpcall(function()
			local profile = request.profile
			local path = PathfindingService:CreatePath({
				AgentRadius = profile.AgentRadius,
				AgentHeight = profile.AgentHeight,
				AgentCanJump = profile.AgentCanJump,
				AgentCanClimb = profile.AgentCanClimb,
				WaypointSpacing = profile.WaypointSpacing,
				Costs = getNativeCosts(profile),
			})

			path:ComputeAsync(request.startPosition, request.goalPosition)
			if path.Status ~= Enum.PathStatus.Success then
				return nil, tostring(path.Status)
			end

			local waypoints = copyWaypoints(path)
			if not waypoints then
				return nil, "empty_waypoints"
			end
			for _, waypoint in ipairs(waypoints) do
				if not transitionAllowed(waypoint, profile) then
					return nil, "transition_not_allowed"
				end
			end
			return waypoints, "success"
		end, debug.traceback)

		local waypoints = waypointsOrError
		if not ok then
			failureReason = tostring(waypointsOrError)
			waypoints = nil
		end

		if waypoints then
			pathCache[request.cacheKey] = {
				waypoints = waypoints,
				expiresAt = os.clock() + Config.Scheduler.PathCacheTtl,
			}
		end

		local applyOk, applyError = pcall(applyPathResult, request, waypoints, failureReason or "compute_failed")
		if not applyOk then
			warn("[NpcGroundNavigation] Failed to apply native path result:", applyError)
		end
		clearQueuedRequest(request)
		activePaths = math.max(0, activePaths - 1)
	end)
end

local function markProgress(npc, nav, nextPosition: Vector3, profile, now: number)
	if flat(nextPosition - nav.lastProgressPosition).Magnitude >= profile.StuckDistance then
		nav.lastProgressPosition = nextPosition
		nav.lastProgressAt = now
		nav.unreachableSince = nil
		npc.unreachableSince = nil
	end
end

local function finishStep(nav, move: Vector3, reason: string, expectedDistance: number): (Vector3, string)
	nav.lastMoveReason = reason
	if nav.status == "NativePathPending" then
		metrics.waitingPathTicks += 1
	end
	if expectedDistance > 0.05 and move.Magnitude < expectedDistance * 0.1 then
		metrics.stalledMovementTicks += 1
		nav.zeroMoveTicksWithTarget += 1
		nav.consecutiveZeroMoveTicks += 1
	else
		nav.consecutiveZeroMoveTicks = 0
	end
	return move, nav.status
end

local function isJumpWaypoint(waypoint): boolean
	return waypoint ~= nil
		and (waypoint.Action == Enum.PathWaypointAction.Jump or waypoint.Label == "Jump")
end

local function finishRoute(nav)
	nav.waypoints = nil
	nav.waypointIndex = 1
	nav.pathCacheKey = nil
	nav.pathExpiresAt = 0
	setStatus(nav, "PathComplete")
end

local function advanceReachedWaypoints(npc, nav, profile)
	local reachDistance = waypointReachDistance(profile)
	while nav.waypoints do
		local waypoint = nav.waypoints[nav.waypointIndex]
		if not waypoint then
			finishRoute(nav)
			return
		end
		if isJumpWaypoint(waypoint) then
			return
		end

		local target = waypoint.Position + Vector3.new(0, npc.groundOffset, 0)
		if (target - npc.position).Magnitude > reachDistance * 1.25 then
			return
		end

		nav.waypointIndex += 1
		metrics.waypointsReached += 1
		if nav.waypointIndex > #nav.waypoints then
			finishRoute(nav)
			return
		end
	end
end

local function startNativeJump(npc, nav, waypoint, profile, now: number, speed: number): boolean
	if not profile.AgentCanJump then
		metrics.traversalFailures += 1
		return false
	end

	local landingSample = NpcGroundSurface.SamplePrecise(
		waypoint.Position,
		waypoint.Position.Y,
		profile
	)
	if not landingSample or NpcGroundSurface.GetFailureReason(landingSample, profile) then
		metrics.traversalFailures += 1
		return false
	end

	local landingPosition = landingSample.position + Vector3.new(0, npc.groundOffset, 0)
	local horizontalDistance = flat(landingPosition - npc.position).Magnitude
	local maxJumpDistance = math.max(
		profile.WaypointSpacing * 1.75,
		tonumber(profile.TraversalMaxDistance) or 0
	)
	if horizontalDistance > maxJumpDistance + 0.05 then
		metrics.traversalFailures += 1
		return false
	end

	local duration = math.clamp(horizontalDistance / math.max(1, speed), 0.25, profile.TraversalDuration or 0.5)
	local arcHeight = math.max(2, tonumber(profile.TraversalArcHeight) or 3)

	nav.traversal = {
		kind = "NativeJump",
		startPosition = npc.position,
		landingPosition = landingPosition,
		startedAt = now,
		endsAt = now + duration,
		duration = duration,
		arcHeight = arcHeight,
		stepPosition = npc.position,
		complete = false,
		waypointIndex = nav.waypointIndex,
	}
	metrics.traversalStarts += 1
	setStatus(nav, "NativeJump")
	return true
end

local function stepTraversal(npc, nav, now: number, dt: number): (Vector3, string)
	local traversal = nav.traversal
	if not traversal then
		return finishStep(nav, Vector3.zero, "missing_native_jump", 0)
	end

	local sampleTime = math.min(traversal.endsAt, now + math.max(0, dt))
	local complete = sampleTime >= traversal.endsAt - 1e-4
	local alpha = complete and 1 or math.clamp((sampleTime - traversal.startedAt) / traversal.duration, 0, 1)
	local basePosition = traversal.startPosition:Lerp(traversal.landingPosition, alpha)
	local arcOffset = math.sin(math.pi * alpha) * traversal.arcHeight
	local nextPosition = basePosition + Vector3.yAxis * arcOffset
	traversal.stepPosition = nextPosition
	traversal.complete = complete

	return finishStep(
		nav,
		nextPosition - npc.position,
		"native_jump",
		(nextPosition - npc.position).Magnitude
	)
end

local function moveToward(
	npc,
	nav,
	moveTarget: Vector3,
	speed: number,
	dt: number,
	now: number,
	separation: Vector3?,
	expectedSurfaceY: number?,
	reason: string
): (Vector3, string)
	local toTarget = flat(moveTarget - npc.position)
	if toTarget.Magnitude <= 0.05 or speed <= 0 then
		return finishStep(nav, Vector3.zero, "no_move_requested", 0)
	end

	local expectedDistance = math.min(toTarget.Magnitude, speed * dt)
	local step = safeUnit(toTarget) * expectedDistance
	if separation and separation.Magnitude > 0.01 then
		local separationWeight = nav.waypoints and 0.18 or 0.28
		step += safeUnit(separation) * math.min(speed * dt * separationWeight, separation.Magnitude)
	end

	local candidate = npc.position + step
	local stepResult = NpcGroundSurface.ValidateStep(npc, candidate, npc.navigationProfile, expectedSurfaceY)
	nav.lastStepCheck = stepResult
	local endSample = stepResult.surfaceSamples and stepResult.surfaceSamples[2] or nil
	nav.debugGroundProbe = endSample and endSample.position or nil

	if not stepResult.clear or not stepResult.position then
		metrics.stepValidationFailures += 1
		metrics.blockedStepTicks += 1
		nav.stepFailureCount += 1
		nav.blockedSince = nav.blockedSince or now
		return finishStep(nav, Vector3.zero, stepResult.reason or "blocked", expectedDistance)
	end

	local constrained = stepResult.position
	nav.stepFailureCount = 0
	nav.blockedSince = nil
	nav.lastSafeSurfaceY = constrained.Y - npc.groundOffset
	nav.lastSafePosition = constrained
	markProgress(npc, nav, constrained, npc.navigationProfile, now)
	return finishStep(nav, constrained - npc.position, reason, expectedDistance)
end

function NpcGroundNavigation.IsTraversing(npc): boolean
	local nav = npc.navigation
	return nav ~= nil and nav.mode == "GroundNative" and nav.traversal ~= nil
end

function NpcGroundNavigation.StepTraversal(npc, now: number, dt: number): (Vector3, string)
	return stepTraversal(npc, getNavigation(npc), now, dt)
end

function NpcGroundNavigation.BeginTick(alivePlayers: {any})
	NpcGroundSurface.BeginTick(alivePlayers)
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

	return neighborCount > 0 and separation / neighborCount or Vector3.zero
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
	if nav.traversal then
		return stepTraversal(npc, nav, now, dt)
	end

	local routeGoal = desiredPosition
	local goalMoved = nav.pathGoalPosition
		and flat(routeGoal - nav.pathGoalPosition).Magnitude >= profile.PathGoalMoveDistance
	if goalMoved and (nav.waypoints or nav.pathPending) then
		invalidateRoute(npc, nav, "goal_moved")
	end

	if nav.waypoints and now >= nav.pathExpiresAt then
		invalidateRoute(npc, nav, "path_expired")
	end

	if not nav.waypoints and not nav.pathPending then
		queuePath(npc, routeGoal, profile, now, nav.lastRepathReason or "path_required")
	end

	advanceReachedWaypoints(npc, nav, profile)
	if nav.waypoints then
		local waypoint = nav.waypoints[nav.waypointIndex]
		if waypoint then
			if isJumpWaypoint(waypoint) then
				if startNativeJump(npc, nav, waypoint, profile, now, speed) then
					return stepTraversal(npc, nav, now, dt)
				end
				evictActiveRouteCache(nav)
				invalidateRoute(npc, nav, "native_jump_invalid")
				queuePath(npc, routeGoal, profile, now, "native_jump_invalid")
				setStatus(nav, nav.pathPending and "NativePathPending" or "Blocked")
				return finishStep(nav, Vector3.zero, "native_jump_invalid", 0)
			end

			metrics.nativePathTicks += 1
			setStatus(nav, "NativePath")
			local moveTarget = waypoint.Position + Vector3.new(0, npc.groundOffset, 0)
			local move, status = moveToward(
				npc,
				nav,
				moveTarget,
				speed,
				dt,
				now,
				separation,
				waypoint.Position.Y,
				"native_waypoint"
			)
			if move.Magnitude <= 0.01 and nav.stepFailureCount > 0 then
				evictActiveRouteCache(nav)
				invalidateRoute(npc, nav, "native_waypoint_blocked")
				queuePath(npc, routeGoal, profile, now, "native_waypoint_blocked")
				setStatus(nav, nav.pathPending and "NativePathPending" or "Blocked")
				return move, nav.status
			end
			if now - nav.lastProgressAt >= profile.StuckSeconds then
				metrics.stuckRepaths += 1
				evictActiveRouteCache(nav)
				invalidateRoute(npc, nav, "stuck")
				queuePath(npc, routeGoal, profile, now, "stuck")
				return move, nav.status
			end
			return move, status
		end
	end

	-- Native path computation is throttled globally. A queued agent is allowed to
	-- take only a locally validated straight step while it waits; it never performs
	-- custom obstacle steering or invents its own route.
	metrics.nativeFallbackTicks += 1
	if nav.pathPending then
		setStatus(nav, "NativePathPending")
	elseif nav.status ~= "Unreachable" and nav.status ~= "PathQueueFull" then
		setStatus(nav, "NativeFallback")
	end

	local fallbackMove, fallbackStatus = moveToward(
		npc,
		nav,
		routeGoal,
		speed,
		dt,
		now,
		separation,
		nil,
		"native_path_wait_fallback"
	)
	if fallbackMove.Magnitude <= 0.01 and nav.stepFailureCount > 0 and not nav.pathPending then
		queuePath(npc, routeGoal, profile, now, "fallback_blocked")
	end
	return fallbackMove, fallbackStatus
end

function NpcGroundNavigation.ConstrainPosition(npc, candidate: Vector3, now: number): Vector3
	local nav = getNavigation(npc)
	local traversal = nav.traversal
	if traversal then
		local position = traversal.stepPosition or candidate
		if traversal.complete then
			position = traversal.landingPosition
			nav.traversal = nil
			nav.lastSafeSurfaceY = position.Y - npc.groundOffset
			nav.lastSafePosition = position
			nav.lastProgressPosition = position
			nav.lastProgressAt = now
			nav.blockedSince = nil
			nav.stepFailureCount = 0
			nav.waypointIndex = math.max(nav.waypointIndex + 1, (traversal.waypointIndex or 0) + 1)
			metrics.waypointsReached += 1
			metrics.traversalCompletions += 1
			if nav.waypoints and nav.waypointIndex > #nav.waypoints then
				finishRoute(nav)
			else
				setStatus(nav, nav.waypoints and "NativePath" or "NativePathPending")
			end
		end
		return position
	end

	if nav.lastSafePosition and (candidate - nav.lastSafePosition).Magnitude <= 0.01 then
		return candidate
	end
	if flat(candidate - npc.position).Magnitude <= 0.05 then
		return npc.position
	end

	local result = NpcGroundSurface.ValidateStep(npc, candidate, npc.navigationProfile)
	if result.clear and result.position then
		nav.lastSafePosition = result.position
		nav.lastSafeSurfaceY = result.position.Y - npc.groundOffset
		return result.position
	end
	return npc.position
end

function NpcGroundNavigation.StepScheduler(now: number)
	if now - lastCacheCleanupAt >= 2 then
		lastCacheCleanupAt = now
		NpcGroundSurface.CleanupCache(now)
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
		local nav = request.npc.navigation
		if request.npc.dead or not request.npc.model.Parent or not nav or nav.generation ~= request.generation then
			clearQueuedRequest(request)
			clearPendingForRequest(nav, request)
		else
			pathTokens -= 1
			startPathRequest(request)
		end
	end
end

function NpcGroundNavigation.SetPaused(npc, paused: boolean, now: number)
	local nav = npc.navigation
	local traversal = nav and nav.traversal
	if not traversal then
		return
	end
	if paused then
		traversal.pausedAt = traversal.pausedAt or now
		return
	end
	if not traversal.pausedAt then
		return
	end

	local pausedDuration = math.max(0, now - traversal.pausedAt)
	traversal.startedAt += pausedDuration
	traversal.endsAt += pausedDuration
	traversal.pausedAt = nil
end

function NpcGroundNavigation.Invalidate(npc, reason: string?)
	local nav = npc.navigation
	if nav and nav.mode == "GroundNative" then
		nav.traversal = nil
		invalidateRoute(npc, nav, reason or "invalidated")
	end
end

function NpcGroundNavigation.Cleanup(npc)
	NpcGroundNavigation.Invalidate(npc, "cleanup")
	npc.navigation = nil
	npc.unreachableSince = nil
end

function NpcGroundNavigation.GetMetrics(): {[string]: any}
	local result = table.clone(metrics)
	for key, value in pairs(NpcGroundSurface.GetMetrics()) do
		result[key] = value
	end
	result.pendingPaths = #requestQueue
	result.activePaths = activePaths
	result.pathCacheEntries = 0
	for _ in pairs(pathCache) do
		result.pathCacheEntries += 1
	end
	return result
end

local function hitName(result): string?
	local hit = result and result.hit
	return hit and hit.Instance and hit.Instance:GetFullName() or nil
end

function NpcGroundNavigation.GetDebug(npc): {[string]: any}?
	local nav = npc.navigation
	if not nav or nav.mode ~= "GroundNative" then
		return nil
	end

	local stepCheck = nav.lastStepCheck
	local endSample = stepCheck and stepCheck.surfaceSamples and stepCheck.surfaceSamples[2] or nil
	return {
		profile = npc.movementProfile,
		backend = "PathfindingService",
		target = npc.targetPlayer and npc.targetPlayer.Name or nil,
		targetPosition = nav.pathGoalPosition,
		status = nav.status,
		lastMoveReason = nav.lastMoveReason,
		directCheck = nil,
		stepCheck = nav.lastStepCheck,
		bodyHit = hitName(stepCheck),
		surfaceNormal = endSample and endSample.normal or nil,
		slopeDegrees = stepCheck and stepCheck.slopeDegrees or nil,
		startSurfaceY = stepCheck and stepCheck.startSurfaceY or nil,
		endSurfaceY = stepCheck and stepCheck.endSurfaceY or nil,
		deltaY = stepCheck and stepCheck.deltaY or nil,
		directFailureCount = 0,
		stepFailureCount = nav.stepFailureCount,
		blockedSince = nav.blockedSince,
		pathPending = nav.pathPending,
		generation = nav.generation,
		waypoints = nav.waypoints,
		waypointIndex = nav.waypointIndex,
		lastRepathReason = nav.lastRepathReason,
		unreachable = nav.unreachableSince ~= nil,
		groundProbe = nav.debugGroundProbe,
		zeroMoveTicksWithTarget = nav.zeroMoveTicksWithTarget,
		consecutiveZeroMoveTicks = nav.consecutiveZeroMoveTicks,
		traversal = nav.traversal and {
			kind = nav.traversal.kind,
			landingPosition = nav.traversal.landingPosition,
			complete = nav.traversal.complete,
			paused = nav.traversal.pausedAt ~= nil,
		} or nil,
	}
end

return NpcGroundNavigation
