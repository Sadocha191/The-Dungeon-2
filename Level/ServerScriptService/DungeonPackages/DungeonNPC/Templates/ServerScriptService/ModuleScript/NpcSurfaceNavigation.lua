local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local NpcSurfaceNavigation = {}

local DEFAULT_NORMAL = Vector3.yAxis
local DEFAULT_LOOK = Vector3.new(0, 0, -1)
local EPSILON = 1e-4

local crawlParams = RaycastParams.new()
crawlParams.FilterType = Enum.RaycastFilterType.Exclude
crawlParams.IgnoreWater = false
crawlParams.RespectCanCollide = false

local crawlExclusions = {}

local metrics = {
	raycastCount = 0,
	acquireAttempts = 0,
	acquireFailures = 0,
	innerCornerTransitions = 0,
	outerCornerTransitions = 0,
	adhesionFailures = 0,
}

local function safeUnit(value: Vector3, fallback: Vector3): Vector3
	if value.Magnitude > EPSILON then
		return value.Unit
	end
	return fallback
end

local function projectOnPlane(value: Vector3, normal: Vector3): Vector3
	return value - normal * value:Dot(normal)
end

local function findTaggedAncestor(instance: Instance, tag: string): boolean
	local current: Instance? = instance
	while current and current ~= Workspace do
		if CollectionService:HasTag(current, tag) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isCrawlable(npc: any, instance: Instance, normal: Vector3): boolean
	if findTaggedAncestor(instance, "NpcCrawlable") or findTaggedAncestor(instance, "NpcWalkable") then
		return true
	end
	if instance:IsA("Terrain") then
		local minFloorDot = math.clamp(
			tonumber(npc.navigationProfile.TerrainFloorNormalMinDot) or 0.65,
			0,
			1
		)
		return normal:Dot(Vector3.yAxis) >= minFloorDot
	end
	return npc.navigationProfile.AllowUntaggedCrawlable == true
end

local function castCrawlable(npc: any, origin: Vector3, direction: Vector3): RaycastResult?
	if direction.Magnitude <= EPSILON then
		return nil
	end
	metrics.raycastCount += 1
	local result = Workspace:Raycast(origin, direction, crawlParams)
	if result and isCrawlable(npc, result.Instance, result.Normal) then
		return result
	end
	return nil
end

local function getSurfaceOffset(npc: any): number
	local attribute = npc.model:GetAttribute("NpcSurfaceOffset")
	if typeof(attribute) == "number" then
		return math.max(0.1, attribute)
	end
	return math.max(0.1, tonumber(npc.navigationProfile.SurfaceOffset) or 1.25)
end

local function getState(npc: any): {[string]: any}
	local state = npc.navigation
	if state and state.kind == "SurfaceCrawler" then
		return state
	end

	state = {
		kind = "SurfaceCrawler",
		surfaceNormal = typeof(npc.surfaceNormal) == "Vector3" and safeUnit(npc.surfaceNormal, DEFAULT_NORMAL) or DEFAULT_NORMAL,
		surfaceInstance = nil,
		surfacePoint = nil,
		pendingPosition = nil,
		pendingNormal = nil,
		lastDirection = safeUnit(projectOnPlane(npc.look or DEFAULT_LOOK, DEFAULT_NORMAL), DEFAULT_LOOK),
		lastStatus = "Initializing",
		lastTransition = nil,
	}
	npc.navigation = state
	return state
end

local function acquireSurface(npc: any, state: {[string]: any}): boolean
	metrics.acquireAttempts += 1
	local profile = npc.navigationProfile
	local distance = math.max(2, tonumber(profile.AcquireDistance) or 10)
	local look = safeUnit(npc.look or DEFAULT_LOOK, DEFAULT_LOOK)
	local right = safeUnit(look:Cross(Vector3.yAxis), Vector3.xAxis)
	local directions = {
		-Vector3.yAxis,
		Vector3.yAxis,
		look,
		-look,
		right,
		-right,
	}

	local bestResult = nil
	for _, direction in ipairs(directions) do
		local result = castCrawlable(npc, npc.position, direction * distance)
		if result and (not bestResult or result.Distance < bestResult.Distance) then
			bestResult = result
		end
	end

	if not bestResult then
		metrics.acquireFailures += 1
		state.lastStatus = "Unreachable"
		return false
	end

	local normal = safeUnit(bestResult.Normal, DEFAULT_NORMAL)
	local offset = getSurfaceOffset(npc)
	local snapped = bestResult.Position + normal * offset
	state.surfaceNormal = normal
	state.surfaceInstance = bestResult.Instance
	state.surfacePoint = bestResult.Position
	state.pendingPosition = snapped
	state.pendingNormal = normal
	state.lastStatus = "Acquired"
	npc.surfaceNormal = normal
	return true
end

local function snapAlongNormal(npc: any, candidate: Vector3, normal: Vector3): (Vector3?, Vector3?, RaycastResult?)
	local profile = npc.navigationProfile
	local offset = getSurfaceOffset(npc)
	local probeLift = math.max(0.1, tonumber(profile.AdhesionProbeLift) or 0.75)
	local probeDistance = offset + math.max(1, tonumber(profile.AdhesionDistance) or 4.5) + probeLift
	local result = castCrawlable(npc, candidate + normal * probeLift, -normal * probeDistance)
	if not result then
		return nil, nil, nil
	end
	local nextNormal = safeUnit(result.Normal, normal)
	return result.Position + nextNormal * offset, nextNormal, result
end

local function tryInnerCorner(
	npc: any,
	position: Vector3,
	direction: Vector3,
	stepDistance: number,
	currentNormal: Vector3
): (Vector3?, Vector3?, RaycastResult?)
	local profile = npc.navigationProfile
	local probeDistance = stepDistance + math.max(0.5, tonumber(profile.ForwardTransitionProbe) or 1.75)
	local result = castCrawlable(npc, position, direction * probeDistance)
	if not result then
		return nil, nil, nil
	end

	local nextNormal = safeUnit(result.Normal, currentNormal)
	if math.abs(nextNormal:Dot(currentNormal)) > 0.985 then
		return nil, nil, nil
	end

	metrics.innerCornerTransitions += 1
	local offset = getSurfaceOffset(npc)
	return result.Position + nextNormal * offset, nextNormal, result
end

local function tryOuterCorner(
	npc: any,
	candidate: Vector3,
	direction: Vector3,
	currentNormal: Vector3
): (Vector3?, Vector3?, RaycastResult?)
	local profile = npc.navigationProfile
	local offset = getSurfaceOffset(npc)
	local edgeProbe = math.max(0.5, tonumber(profile.EdgeTransitionProbe) or 2.5)
	local origins = {
		candidate + currentNormal * (offset + edgeProbe * 0.25),
		candidate + direction * (edgeProbe * 0.5) - currentNormal * (offset + edgeProbe * 0.5),
	}
	local directions = {
		safeUnit(-direction - currentNormal * 0.35, -direction) * (offset + edgeProbe * 2.5),
		-direction * (offset + edgeProbe * 2.5),
	}

	for _, origin in ipairs(origins) do
		for _, probeDirection in ipairs(directions) do
			local result = castCrawlable(npc, origin, probeDirection)
			if result then
				local nextNormal = safeUnit(result.Normal, currentNormal)
				local isAdjacent = (result.Position - candidate).Magnitude <= offset + edgeProbe * 3
				local facesTravelDirection = nextNormal:Dot(direction) >= 0.2
				if isAdjacent
					and facesTravelDirection
					and math.abs(nextNormal:Dot(currentNormal)) < 0.985 then
					metrics.outerCornerTransitions += 1
					return result.Position + nextNormal * offset, nextNormal, result
				end
			end
		end
	end
	return nil, nil, nil
end

local function commitSurface(
	npc: any,
	state: {[string]: any},
	position: Vector3,
	normal: Vector3,
	result: RaycastResult?,
	status: string,
	transition: string?
)
	state.pendingPosition = position
	state.pendingNormal = normal
	state.surfaceNormal = normal
	state.surfaceInstance = result and result.Instance or state.surfaceInstance
	state.surfacePoint = result and result.Position or state.surfacePoint
	state.lastStatus = status
	state.lastTransition = transition
	npc.surfaceNormal = normal
end

function NpcSurfaceNavigation.BeginTick(alivePlayers: {any})
	table.clear(crawlExclusions)
	for _, folderName in ipairs({ "Enemies", "Mobs", "Drops", "SpellVFX" }) do
		local instance = Workspace:FindFirstChild(folderName)
		if instance then
			table.insert(crawlExclusions, instance)
		end
	end
	for _, info in ipairs(alivePlayers) do
		local character = info.player and info.player.Character
		if character then
			table.insert(crawlExclusions, character)
		end
	end
	crawlParams.FilterDescendantsInstances = crawlExclusions
end

function NpcSurfaceNavigation.Step(
	npc: any,
	targetPosition: Vector3,
	speed: number,
	dt: number,
	_now: number
): (Vector3, string)
	local state = getState(npc)
	if not state.surfaceInstance and not acquireSurface(npc, state) then
		return Vector3.zero, "Unreachable"
	end

	local normal = safeUnit(state.surfaceNormal, DEFAULT_NORMAL)
	local targetDelta = targetPosition - npc.position
	local direction = projectOnPlane(targetDelta, normal)
	if direction.Magnitude <= EPSILON then
		direction = projectOnPlane(state.lastDirection or npc.look or DEFAULT_LOOK, normal)
	end
	if direction.Magnitude <= EPSILON then
		state.lastStatus = "Idle"
		return Vector3.zero, "Idle"
	end
	direction = direction.Unit
	state.lastDirection = direction
	npc.look = direction

	local stepDistance = math.max(0, speed) * math.max(0, dt)
	if stepDistance <= EPSILON then
		state.lastStatus = "Idle"
		return Vector3.zero, "Idle"
	end

	local cornerPosition, cornerNormal, cornerResult = tryInnerCorner(npc, npc.position, direction, stepDistance, normal)
	if cornerPosition and cornerNormal then
		commitSurface(npc, state, cornerPosition, cornerNormal, cornerResult, "Moving", "InnerCorner")
		return cornerPosition - npc.position, "Moving"
	end

	local candidate = npc.position + direction * stepDistance
	local snappedPosition, snappedNormal, snappedResult = snapAlongNormal(npc, candidate, normal)
	if snappedPosition and snappedNormal then
		commitSurface(npc, state, snappedPosition, snappedNormal, snappedResult, "Moving", nil)
		return snappedPosition - npc.position, "Moving"
	end

	local edgePosition, edgeNormal, edgeResult = tryOuterCorner(npc, candidate, direction, normal)
	if edgePosition and edgeNormal then
		commitSurface(npc, state, edgePosition, edgeNormal, edgeResult, "Moving", "OuterCorner")
		return edgePosition - npc.position, "Moving"
	end

	metrics.adhesionFailures += 1
	state.pendingPosition = npc.position
	state.pendingNormal = normal
	state.lastStatus = "Unreachable"
	return Vector3.zero, "Unreachable"
end

function NpcSurfaceNavigation.ConstrainPosition(npc: any, nextPosition: Vector3, _now: number): Vector3
	local state = getState(npc)
	local normal = safeUnit(state.pendingNormal or state.surfaceNormal or DEFAULT_NORMAL, DEFAULT_NORMAL)
	local pending = state.pendingPosition or npc.position
	local externalDelta = nextPosition - pending
	local tangentExternal = projectOnPlane(externalDelta, normal)
	local candidate = pending + tangentExternal

	if tangentExternal.Magnitude > EPSILON then
		local snappedPosition, snappedNormal, snappedResult = snapAlongNormal(npc, candidate, normal)
		if snappedPosition and snappedNormal then
			commitSurface(npc, state, snappedPosition, snappedNormal, snappedResult, state.lastStatus or "Moving", nil)
			pending = snappedPosition
			normal = snappedNormal
		end
	end

	state.pendingPosition = nil
	state.pendingNormal = nil
	state.surfaceNormal = normal
	npc.surfaceNormal = normal
	return pending
end

function NpcSurfaceNavigation.ProjectImpulse(npc: any, impulse: Vector3): Vector3
	local state = getState(npc)
	local normal = safeUnit(state.surfaceNormal or DEFAULT_NORMAL, DEFAULT_NORMAL)
	return projectOnPlane(impulse, normal)
end

function NpcSurfaceNavigation.Cleanup(npc: any)
	if npc.navigation and npc.navigation.kind == "SurfaceCrawler" then
		npc.navigation = nil
	end
	npc.surfaceNormal = nil
end

function NpcSurfaceNavigation.Invalidate(npc: any, reason: string?)
	local state = getState(npc)
	state.surfaceInstance = nil
	state.surfacePoint = nil
	state.pendingPosition = nil
	state.pendingNormal = nil
	state.lastStatus = "Invalidated"
	state.lastTransition = reason
end

function NpcSurfaceNavigation.GetDebug(npc: any): {[string]: any}
	local state = getState(npc)
	return {
		kind = state.kind,
		status = state.lastStatus,
		transition = state.lastTransition,
		surfaceNormal = state.surfaceNormal,
		surfacePoint = state.surfacePoint,
		surfaceInstance = state.surfaceInstance,
		metrics = NpcSurfaceNavigation.GetMetrics(),
	}
end

function NpcSurfaceNavigation.GetMetrics(): {[string]: number}
	return table.clone(metrics)
end

return NpcSurfaceNavigation
