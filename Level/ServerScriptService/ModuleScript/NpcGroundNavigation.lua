local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(moduleFolder, "[NpcGroundNavigation] Server ModuleScript folder is required")
local Config = require(moduleFolder:WaitForChild("NpcNavigationConfig"))
local NpcGroundSurface = require(moduleFolder:WaitForChild("NpcGroundSurface"))

local NpcGroundNavigation = {}

local pathCache = {}
local requestQueue = {}
local queuedNpc = setmetatable({}, { __mode = "k" })
local activePaths = 0
local pathTokens = Config.Scheduler.MaxPathStartsPerSecond
local lastTokenAt = os.clock()
local lastCacheCleanupAt = os.clock()

local metrics = {
	directChecks = 0,
	directCheckFailures = 0,
	stepValidationFailures = 0,
	waitingPathTicks = 0,
	stalledMovementTicks = 0,
	pathRequests = 0,
	pathStarts = 0,
	pathSuccesses = 0,
	pathFailures = 0,
	pathCacheHits = 0,
	stalePathResults = 0,
	stateTransitions = 0,
	traversalStarts = 0,
	traversalCompletions = 0,
	traversalFailures = 0,
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

local function horizontalSectorKey(pos: Vector3): string
	local size = Config.Scheduler.PathSectorSize
	return string.format("%d:%d", math.floor(pos.X / size), math.floor(pos.Z / size))
end

local function setStatus(nav, status: string)
	if nav.status ~= status then
		nav.status = status
		metrics.stateTransitions += 1
	end
end

local function surfaceIdentity(sample): string
	local resolution = Config.Scheduler.PathLayerResolution
	local instanceKey = sample.instance == workspace.Terrain and "Terrain" or sample.instance:GetFullName()
	return string.format("%s@%d", instanceKey, math.floor((sample.position.Y / resolution) + 0.5))
end

local function pathKey(profile, startSample, goalSample): string
	return profile.Name
		.. ":"
		.. horizontalSectorKey(startSample.position)
		.. ":"
		.. surfaceIdentity(startSample)
		.. ">"
		.. horizontalSectorKey(goalSample.position)
		.. ":"
		.. surfaceIdentity(goalSample)
end

local function getNavigation(npc)
	local nav = npc.navigation
	if nav and nav.mode == "Ground" then
		return nav
	end
	local now = os.clock()
	nav = {
		mode = "Ground",
		generation = 0,
		waypoints = nil,
		waypointIndex = 1,
		nextDirectCheckAt = 0,
		directClear = nil,
		directSector = nil,
		directFailureCount = 0,
		stepFailureCount = 0,
		blockedSince = nil,
		pathPending = false,
		pendingGeneration = nil,
		lastSafeSurfaceY = npc.position.Y - npc.groundOffset,
		lastSafePosition = npc.position,
		lastMoveReason = "initial",
		lastDirectCheck = nil,
		lastStepCheck = nil,
		zeroMoveTicksWithTarget = 0,
		consecutiveZeroMoveTicks = 0,
		goalLayerId = 0,
		goalSurfaceSample = nil,
		goalSurfacePosition = nil,
		nextGoalLayerCheckAt = 0,
		nextRepathAt = 0,
		nextTraversalAt = 0,
		traversal = nil,
		pathExpiresAt = 0,
		lastProgressAt = now,
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
	return #result >= 2 and result or nil
end

local function clearPendingForRequest(nav, request)
	if nav and nav.pendingGeneration == request.generation then
		nav.pathPending = false
		nav.pendingGeneration = nil
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
		nav.waypoints = waypoints
		nav.waypointIndex = math.min(2, #waypoints)
		nav.pathExpiresAt = os.clock() + request.profile.PathRefreshSeconds
		setStatus(nav, "Path")
		nav.unreachableSince = nil
		npc.unreachableSince = nil
		if not request.cached then
			metrics.pathSuccesses += 1
		end
	else
		nav.waypoints = nil
		setStatus(nav, "Unreachable")
		nav.unreachableSince = nav.unreachableSince or os.clock()
		npc.unreachableSince = nav.unreachableSince
		nav.lastRepathReason = reason
		if not request.cached then
			metrics.pathFailures += 1
		end
	end
end

local function updateGoalLayer(nav, goalPosition: Vector3, sample, profile): boolean
	local changed = false
	if nav.goalSurfaceSample and nav.goalSurfacePosition then
		local distance = flat(goalPosition - nav.goalSurfacePosition).Magnitude
		local allowedDelta = math.tan(math.rad(profile.MaxSlopeDegrees)) * distance
			+ Config.Scheduler.SurfaceLayerTolerance
		if math.abs(sample.position.Y - nav.goalSurfaceSample.position.Y) > allowedDelta then
			nav.goalLayerId += 1
			changed = true
		end
	end
	nav.goalSurfaceSample = sample
	nav.goalSurfacePosition = goalPosition
	return changed
end

local function invalidateRoute(npc, nav, reason: string)
	nav.generation += 1
	nav.waypoints = nil
	nav.pathPending = false
	nav.pendingGeneration = nil
	nav.nextDirectCheckAt = 0
	nav.lastRepathReason = reason
	queuedNpc[npc] = nil
end

local function queuePath(npc, goalPosition: Vector3, profile, now: number, reason: string): boolean
	local nav = getNavigation(npc)
	if nav.pathPending or queuedNpc[npc] or now < nav.nextRepathAt then
		return false
	end

	local currentSurfaceY = npc.position.Y - npc.groundOffset
	local startSample = NpcGroundSurface.SamplePrecise(npc.position, currentSurfaceY, profile)
	local goalSample = NpcGroundSurface.SamplePrecise(goalPosition, goalPosition.Y - npc.groundOffset, profile)
	if not startSample or not goalSample or NpcGroundSurface.GetFailureReason(goalSample, profile) then
		nav.unreachableSince = nav.unreachableSince or now
		npc.unreachableSince = nav.unreachableSince
		setStatus(nav, "Unreachable")
		nav.lastRepathReason = not goalSample and "missing_goal_surface" or "invalid_goal_surface"
		return false
	end
	updateGoalLayer(nav, goalPosition, goalSample, profile)

	local cacheKey = pathKey(profile, startSample, goalSample)
	local cached = pathCache[cacheKey]
	if cached and cached.expiresAt >= now then
		metrics.pathCacheHits += 1
		nav.generation += 1
		nav.pathGoalPosition = goalPosition
		nav.pathGoalLayerId = nav.goalLayerId
		applyPathResult({ npc = npc, generation = nav.generation, profile = profile, cached = true }, cached.waypoints, "cache")
		return true
	end
	if #requestQueue >= Config.Scheduler.MaxPendingPaths then
		setStatus(nav, "PathQueueFull")
		nav.unreachableSince = nav.unreachableSince or now
		npc.unreachableSince = nav.unreachableSince
		nav.lastRepathReason = "path_queue_full"
		return false
	end

	nav.generation += 1
	nav.nextRepathAt = now + profile.RepathCooldown
	nav.lastRepathReason = reason
	nav.pathPending = true
	nav.pendingGeneration = nav.generation
	nav.pathGoalPosition = goalPosition
	nav.pathGoalLayerId = nav.goalLayerId
	metrics.pathRequests += 1
	local request = {
		npc = npc,
		generation = nav.generation,
		profile = profile,
		startPosition = startSample.position,
		goalPosition = goalSample.position,
		cacheKey = cacheKey,
	}
	queuedNpc[npc] = request
	table.insert(requestQueue, request)
	return true
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
	if nav.status == "WaitingPath" then
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
	return waypoint
		and (waypoint.Label == "Jump" or waypoint.Action == Enum.PathWaypointAction.Jump)
		or false
end

local function partTopY(part: BasePart): number
	local half = part.Size * 0.5
	local cframe = part.CFrame
	local verticalExtent = math.abs(cframe.RightVector.Y) * half.X
		+ math.abs(cframe.UpVector.Y) * half.Y
		+ math.abs(cframe.LookVector.Y) * half.Z
	return part.Position.Y + verticalExtent
end

local function projectedHalfExtent(part: BasePart, direction: Vector3): number
	local horizontal = flat(direction)
	if horizontal.Magnitude <= 0.01 then
		return 0
	end
	local unit = horizontal.Unit
	local half = part.Size * 0.5
	return math.abs(flat(part.CFrame.RightVector):Dot(unit)) * half.X
		+ math.abs(flat(part.CFrame.UpVector):Dot(unit)) * half.Y
		+ math.abs(flat(part.CFrame.LookVector):Dot(unit)) * half.Z
end

local function traversalFallbackTarget(npc, nav, moveTarget: Vector3, stepResult, profile): Vector3?
	local reason = stepResult and stepResult.reason
	local allowed = reason == "body_obstacle" or reason == "step_too_high"
	if not allowed then
		return nil
	end

	local direction = flat(moveTarget - npc.position)
	if direction.Magnitude <= 0.05 then
		return nil
	end
	direction = direction.Unit
	local maxDistance = math.max(0, tonumber(profile.TraversalMaxDistance) or 0)
	if maxDistance <= 0 then
		return nil
	end

	local minimumDistance = math.max(profile.AgentRadius * 1.5, profile.DirectSampleSpacing * 1.75)
	local distance = minimumDistance
	local hit = stepResult and stepResult.hit
	local obstacle = hit and hit.Instance
	if obstacle and obstacle:IsA("BasePart") then
		local startSurfaceY = nav.lastSafeSurfaceY or (npc.position.Y - npc.groundOffset)
		if partTopY(obstacle) - startSurfaceY > (profile.TraversalMaxObstacleTop or 0) + 0.05 then
			return nil
		end
		local centerDistance = flat(obstacle.Position - npc.position):Dot(direction)
		local farEdgeDistance = centerDistance + projectedHalfExtent(obstacle, direction)
		local requiredDistance = farEdgeDistance + profile.AgentRadius + 0.5
		if requiredDistance > maxDistance + 0.05 then
			return nil
		end
		distance = math.max(distance, requiredDistance)
	end

	distance = math.max(distance, math.max(1, profile.AgentRadius * 1.1))
	return npc.position + direction * distance
end

local function tryStartTraversal(
	npc,
	nav,
	targetPosition: Vector3,
	profile,
	now: number,
	source: string,
	hit: RaycastResult?
): boolean
	if not profile.TraversalKind then
		return false
	end
	if source ~= "path_jump" and now < (nav.nextTraversalAt or 0) then
		return false
	end
	if hit and hit.Instance and hit.Instance:IsA("BasePart") then
		local startSurfaceY = nav.lastSafeSurfaceY or (npc.position.Y - npc.groundOffset)
		if partTopY(hit.Instance) - startSurfaceY > (profile.TraversalMaxObstacleTop or 0) + 0.05 then
			metrics.traversalFailures += 1
			return false
		end
	end

	local result = NpcGroundSurface.ValidateTraversal(npc, targetPosition, profile, {
		maxDistance = profile.TraversalMaxDistance,
		maxRise = profile.TraversalMaxRise,
		maxDrop = profile.TraversalMaxDrop,
		arcHeight = profile.TraversalArcHeight,
	})
	nav.lastStepCheck = result
	local endSample = result.surfaceSamples and result.surfaceSamples[2] or nil
	nav.debugGroundProbe = endSample and endSample.position or nil
	if not result.clear or not result.position then
		metrics.traversalFailures += 1
		return false
	end

	if source ~= "path_jump" then
		nav.waypoints = nil
	end
	local duration = math.max(0.1, tonumber(profile.TraversalDuration) or 0.4)
	nav.traversal = {
		kind = profile.TraversalKind,
		source = source,
		startPosition = npc.position,
		landingPosition = result.position,
		startedAt = now,
		endsAt = now + duration,
		duration = duration,
		arcHeight = math.max(0, tonumber(profile.TraversalArcHeight) or 0),
		stepPosition = npc.position,
		complete = false,
	}
	nav.nextTraversalAt = now + math.max(0, tonumber(profile.TraversalCooldown) or 0)
	nav.blockedSince = nil
	nav.stepFailureCount = 0
	metrics.traversalStarts += 1
	setStatus(nav, profile.TraversalKind == "Stride" and "Striding" or "Hopping")
	return true
end

local function stepTraversal(npc, nav, now: number, dt: number): (Vector3, string)
	local traversal = nav.traversal
	if not traversal then
		return finishStep(nav, Vector3.zero, "missing_traversal", 0)
	end
	local sampleTime = math.min(traversal.endsAt, now + math.max(0, dt))
	local alpha = math.clamp((sampleTime - traversal.startedAt) / traversal.duration, 0, 1)
	local basePosition = traversal.startPosition:Lerp(traversal.landingPosition, alpha)
	local arcOffset = math.sin(math.pi * alpha) * traversal.arcHeight
	local nextPosition = basePosition + Vector3.yAxis * arcOffset
	traversal.stepPosition = nextPosition
	traversal.complete = alpha >= 1
	local expectedDistance = (nextPosition - npc.position).Magnitude
	return finishStep(
		nav,
		nextPosition - npc.position,
		string.lower(traversal.kind) .. ":" .. traversal.source,
		expectedDistance
	)
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
	local goalHorizontalSector = horizontalSectorKey(goalPosition)
	local goalMoved = nav.pathGoalPosition
		and flat(goalPosition - nav.pathGoalPosition).Magnitude >= profile.PathGoalMoveDistance
	if now >= nav.nextGoalLayerCheckAt or nav.goalHorizontalSector ~= goalHorizontalSector then
		nav.nextGoalLayerCheckAt = now + profile.DirectCheckInterval
		local goalSample = NpcGroundSurface.SampleCached(goalPosition, goalPosition.Y - npc.groundOffset, profile, now)
		if goalSample then
			local layerChanged = updateGoalLayer(nav, goalPosition, goalSample, profile)
			if layerChanged and (nav.waypoints or nav.pathPending) then
				invalidateRoute(npc, nav, "goal_layer_changed")
			end
		end
	end
	if goalMoved and (nav.waypoints or nav.pathPending) then
		invalidateRoute(npc, nav, "goal_moved")
	end
	nav.goalHorizontalSector = goalHorizontalSector

	if nav.waypoints and now >= nav.pathExpiresAt then
		nav.waypoints = nil
		queuePath(npc, goalPosition, profile, now, "path_expired")
	end

	local moveTarget = desiredPosition
	local specialTransition = false
	local jumpTransition = false
	if nav.waypoints then
		local waypoint = nav.waypoints[nav.waypointIndex]
		if waypoint then
			moveTarget = waypoint.Position + Vector3.new(0, npc.groundOffset, 0)
			local transitionWaypoint = nav.waypoints[math.max(1, nav.waypointIndex - 1)]
			if (moveTarget - npc.position).Magnitude <= math.max(1.5, profile.AgentRadius * 0.7) then
				transitionWaypoint = waypoint
				nav.waypointIndex += 1
				waypoint = nav.waypoints[nav.waypointIndex]
				if waypoint then
					moveTarget = waypoint.Position + Vector3.new(0, npc.groundOffset, 0)
				else
					nav.waypoints = nil
					moveTarget = desiredPosition
					transitionWaypoint = nil
				end
			end
			jumpTransition = isJumpWaypoint(transitionWaypoint)
			specialTransition = transitionWaypoint
				and (transitionWaypoint.Label == "Climb" or transitionWaypoint.Label == "Drop")
				or false
		else
			nav.waypoints = nil
		end
	end

	if not nav.waypoints then
		local desiredSector = horizontalSectorKey(desiredPosition)
		local directSectorChanged = nav.directSector ~= nil and nav.directSector ~= desiredSector
		if now >= nav.nextDirectCheckAt or directSectorChanged then
			metrics.directChecks += 1
			local directResult = NpcGroundSurface.CanTraverse(npc, desiredPosition, profile, now)
			if not directResult.clear then
				metrics.directCheckFailures += 1
			end
			nav.lastDirectCheck = directResult
			nav.directClear = directResult.clear
			nav.directSector = desiredSector
			local targetDistance = flat(goalPosition - npc.position).Magnitude
			local lodMultiplier = targetDistance >= 160 and 2.5 or (targetDistance >= 80 and 1.5 or 1)
			nav.nextDirectCheckAt = now + profile.DirectCheckInterval * lodMultiplier
			if directResult.clear then
				nav.directFailureCount = 0
				nav.blockedSince = nil
				if not nav.pathPending then
					setStatus(nav, "Direct")
				end
			else
				nav.directFailureCount += 1
				nav.blockedSince = nav.blockedSince or now
				if nav.directFailureCount >= profile.DirectFailureThreshold then
					queuePath(npc, goalPosition, profile, now, "direct_blocked:" .. directResult.reason)
				end
			end
		end
		if nav.pathPending then
			setStatus(nav, "WaitingPath")
		elseif nav.directClear == false then
			setStatus(nav, "DirectSuspect")
		else
			setStatus(nav, "Direct")
		end
	end

	if jumpTransition then
		if tryStartTraversal(npc, nav, moveTarget, profile, now, "path_jump", nil) then
			return stepTraversal(npc, nav, now, dt)
		end
		invalidateRoute(npc, nav, "jump_transition_blocked")
		queuePath(npc, goalPosition, profile, now, "jump_transition_blocked")
		setStatus(nav, nav.pathPending and "WaitingPath" or "Blocked")
		return finishStep(nav, Vector3.zero, "jump_transition_blocked", 0)
	end

	local toTarget = specialTransition and (moveTarget - npc.position) or flat(moveTarget - npc.position)
	if toTarget.Magnitude <= 0.05 or speed <= 0 then
		return finishStep(nav, Vector3.zero, "no_move_requested", 0)
	end

	local expectedDistance = math.min(toTarget.Magnitude, speed * dt)
	local step = safeUnit(toTarget) * expectedDistance
	if not specialTransition and separation and separation.Magnitude > 0.01 then
		step += safeUnit(separation) * math.min(speed * dt * 0.3, separation.Magnitude)
	end
	local candidate = npc.position + step
	local stepResult
	if specialTransition then
		stepResult = {
			clear = true,
			reason = "special_transition",
			position = candidate,
			surfaceSamples = {},
		}
	else
		local expectedY = nav.waypoints and (moveTarget.Y - npc.groundOffset) or nil
		stepResult = NpcGroundSurface.ValidateStep(npc, candidate, profile, expectedY)
	end
	nav.lastStepCheck = stepResult
	local endSample = stepResult.surfaceSamples and stepResult.surfaceSamples[2] or nil
	nav.debugGroundProbe = endSample and endSample.position or nil

	if not stepResult.clear or not stepResult.position then
		local traversalTarget = traversalFallbackTarget(npc, nav, moveTarget, stepResult, profile)
		if traversalTarget
			and tryStartTraversal(npc, nav, traversalTarget, profile, now, "local_obstacle", stepResult.hit) then
			return stepTraversal(npc, nav, now, dt)
		end
		metrics.stepValidationFailures += 1
		nav.stepFailureCount += 1
		nav.blockedSince = nav.blockedSince or now
		queuePath(npc, goalPosition, profile, now, "step_blocked:" .. stepResult.reason)
		if nav.waypoints and nav.stepFailureCount >= profile.StepFailureThreshold then
			nav.waypoints = nil
		end
		setStatus(nav, nav.pathPending and "WaitingPath" or "Blocked")
		return finishStep(nav, Vector3.zero, stepResult.reason, expectedDistance)
	end

	local constrained = stepResult.position
	nav.stepFailureCount = 0
	nav.blockedSince = nil
	nav.lastSafeSurfaceY = constrained.Y - npc.groundOffset
	nav.lastSafePosition = constrained
	markProgress(npc, nav, constrained, profile, now)
	if now - nav.lastProgressAt >= profile.StuckSeconds then
		queuePath(npc, goalPosition, profile, now, "stuck")
		if nav.pathPending then
			setStatus(nav, "WaitingPath")
		end
	end
	local moveReason = nav.status == "WaitingPath" and "waiting_path_safe_step"
		or (nav.waypoints and "waypoint_safe" or "direct_safe")
	return finishStep(nav, constrained - npc.position, moveReason, expectedDistance)
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
			nav.blockedSince = nil
			nav.stepFailureCount = 0
			markProgress(npc, nav, position, npc.navigationProfile, now)
			metrics.traversalCompletions += 1
			nav.lastMoveReason = string.lower(traversal.kind) .. "_complete"
			setStatus(nav, nav.waypoints and "Path" or "Direct")
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
	return result.clear and result.position or npc.position
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
			queuedNpc[request.npc] = nil
			clearPendingForRequest(nav, request)
		else
			pathTokens -= 1
			startPathRequest(request)
		end
	end
end

function NpcGroundNavigation.Invalidate(npc, reason: string?)
	local nav = npc.navigation
	if nav then
		invalidateRoute(npc, nav, reason or "invalidated")
	end
end

function NpcGroundNavigation.Cleanup(npc)
	NpcGroundNavigation.Invalidate(npc, "cleanup")
	if npc.navigation then
		npc.navigation.traversal = nil
	end
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
	if not nav or nav.mode ~= "Ground" then
		return nil
	end
	local stepCheck = nav.lastStepCheck
	local endSample = stepCheck and stepCheck.surfaceSamples and stepCheck.surfaceSamples[2] or nil
	return {
		profile = npc.movementProfile,
		target = npc.targetPlayer and npc.targetPlayer.Name or nil,
		targetPosition = npc.targetPlayer
			and npc.targetPlayer.Character
			and npc.targetPlayer.Character:FindFirstChild("HumanoidRootPart")
			and npc.targetPlayer.Character.HumanoidRootPart.Position
			or nil,
		status = nav.status,
		lastMoveReason = nav.lastMoveReason,
		directCheck = nav.lastDirectCheck,
		stepCheck = nav.lastStepCheck,
		bodyHit = hitName(stepCheck) or hitName(nav.lastDirectCheck),
		surfaceNormal = endSample and endSample.normal or nil,
		slopeDegrees = stepCheck and stepCheck.slopeDegrees or nil,
		startSurfaceY = stepCheck and stepCheck.startSurfaceY or nil,
		endSurfaceY = stepCheck and stepCheck.endSurfaceY or nil,
		deltaY = stepCheck and stepCheck.deltaY or nil,
		directFailureCount = nav.directFailureCount,
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
			source = nav.traversal.source,
			landingPosition = nav.traversal.landingPosition,
			complete = nav.traversal.complete,
		} or nil,
	}
end

return NpcGroundNavigation
