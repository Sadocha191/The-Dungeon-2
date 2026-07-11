local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(moduleFolder, "[NpcFlightNavigation] Server ModuleScript folder is required")
local Config = require(moduleFolder:WaitForChild("NpcNavigationConfig"))
local WorldBounds = require(moduleFolder:WaitForChild("WorldBounds"))

local NpcFlightNavigation = {}

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = false
castParams.RespectCanCollide = true

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false

local sharedIgnore = {}
local graphDirty = true
local lastGraphBuildAt = 0
local airNodes = {}
local airEdges = {}
local graphRouteCache = {}
local connections = {}

local metrics = {
	spherecastCount = 0,
	groundRaycastCount = 0,
	graphBuilds = 0,
	graphRouteRequests = 0,
	graphRouteCacheHits = 0,
	directFlights = 0,
	blockedFlights = 0,
}

local function positionOf(inst: Instance): Vector3?
	if inst:IsA("Attachment") then
		return inst.WorldPosition
	end
	if inst:IsA("BasePart") then
		return inst.Position
	end
	if inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function pointInsidePart(point: Vector3, part: BasePart, radius: number): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5 + Vector3.new(radius, radius, radius)
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function pointInsideZone(point: Vector3, zone: Instance, radius: number): boolean
	if zone:IsA("BasePart") then
		return pointInsidePart(point, zone, radius)
	end
	for _, descendant in ipairs(zone:GetDescendants()) do
		if descendant:IsA("BasePart") and pointInsidePart(point, descendant, radius) then
			return true
		end
	end
	return false
end

local function pointInNoFlyZone(point: Vector3, radius: number): boolean
	for _, zone in ipairs(CollectionService:GetTagged("NpcNoFlyZone")) do
		if zone:IsDescendantOf(workspace) and pointInsideZone(point, zone, radius) then
			return true
		end
	end
	return false
end

local function segmentIntersectsNoFly(origin: Vector3, destination: Vector3, radius: number): boolean
	local delta = destination - origin
	local samples = math.clamp(math.ceil(delta.Magnitude / math.max(5, radius * 2)), 1, 14)
	for index = 0, samples do
		if pointInNoFlyZone(origin + delta * (index / samples), radius) then
			return true
		end
	end
	return false
end

local function spherecastBlocked(origin: Vector3, destination: Vector3, radius: number): boolean
	local direction = destination - origin
	if direction.Magnitude <= 0.05 then
		return pointInNoFlyZone(destination, radius)
	end
	if segmentIntersectsNoFly(origin, destination, radius) then
		return true
	end
	metrics.spherecastCount += 1
	return workspace:Spherecast(origin, radius, direction, castParams) ~= nil
end

local function nodeId(inst: Instance): string
	return inst:GetFullName()
end

local function addEdge(fromIndex: number, toIndex: number, distance: number)
	local edges = airEdges[fromIndex]
	if not edges then
		edges = {}
		airEdges[fromIndex] = edges
	end
	table.insert(edges, { to = toIndex, cost = distance })
end

local function rebuildGraph(now: number)
	graphDirty = false
	lastGraphBuildAt = now
	table.clear(airNodes)
	table.clear(airEdges)
	table.clear(graphRouteCache)

	for _, inst in ipairs(CollectionService:GetTagged("NpcAirNode")) do
		local pos = positionOf(inst)
		if pos and inst:IsDescendantOf(workspace) and not pointInNoFlyZone(pos, 1) then
			table.insert(airNodes, { instance = inst, position = pos, id = nodeId(inst) })
		end
	end

	local maxDistance = Config.Scheduler.AirGraphConnectionDistance
	for first = 1, #airNodes do
		for second = first + 1, #airNodes do
			local a = airNodes[first].position
			local b = airNodes[second].position
			local distance = (b - a).Magnitude
			if distance <= maxDistance and not spherecastBlocked(a, b, 1.5) then
				addEdge(first, second, distance)
				addEdge(second, first, distance)
			end
		end
	end
	metrics.graphBuilds += 1
end

local function nearestVisibleNode(position: Vector3, radius: number): number?
	local bestIndex = nil
	local bestDistance = math.huge
	for index, node in ipairs(airNodes) do
		local distance = (node.position - position).Magnitude
		if distance < bestDistance
			and distance <= Config.Scheduler.AirGraphConnectionDistance * 1.5
			and not spherecastBlocked(position, node.position, radius) then
			bestDistance = distance
			bestIndex = index
		end
	end
	return bestIndex
end

local function reconstruct(cameFrom, current: number): {number}
	local result = { current }
	while cameFrom[current] do
		current = cameFrom[current]
		table.insert(result, 1, current)
	end
	return result
end

local function findGraphRoute(startIndex: number, goalIndex: number, now: number): {Vector3}?
	local key = airNodes[startIndex].id .. ">" .. airNodes[goalIndex].id
	local cached = graphRouteCache[key]
	if cached and cached.expiresAt >= now then
		metrics.graphRouteCacheHits += 1
		return cached.positions
	end
	metrics.graphRouteRequests += 1

	local open = { startIndex }
	local openSet = { [startIndex] = true }
	local cameFrom = {}
	local gScore = { [startIndex] = 0 }
	local fScore = { [startIndex] = (airNodes[startIndex].position - airNodes[goalIndex].position).Magnitude }

	while #open > 0 do
		local bestListIndex = 1
		for index = 2, #open do
			if (fScore[open[index]] or math.huge) < (fScore[open[bestListIndex]] or math.huge) then
				bestListIndex = index
			end
		end
		local current = table.remove(open, bestListIndex)
		openSet[current] = nil
		if current == goalIndex then
			local indexes = reconstruct(cameFrom, current)
			local positions = {}
			for _, routeIndex in ipairs(indexes) do
				table.insert(positions, airNodes[routeIndex].position)
			end
			graphRouteCache[key] = {
				positions = positions,
				expiresAt = now + Config.Scheduler.AirGraphCacheTtl,
			}
			return positions
		end

		for _, edge in ipairs(airEdges[current] or {}) do
			local tentative = (gScore[current] or math.huge) + edge.cost
			if tentative < (gScore[edge.to] or math.huge) then
				cameFrom[edge.to] = current
				gScore[edge.to] = tentative
				fScore[edge.to] = tentative + (airNodes[edge.to].position - airNodes[goalIndex].position).Magnitude
				if not openSet[edge.to] then
					openSet[edge.to] = true
					table.insert(open, edge.to)
				end
			end
		end
	end
	return nil
end

local function graphRoute(origin: Vector3, destination: Vector3, radius: number, now: number): {Vector3}?
	if #airNodes == 0 then
		return nil
	end
	local startIndex = nearestVisibleNode(origin, radius)
	local goalIndex = nearestVisibleNode(destination, radius)
	if not startIndex or not goalIndex then
		return nil
	end
	local route = findGraphRoute(startIndex, goalIndex, now)
	if not route then
		return nil
	end
	local result = table.clone(route)
	table.insert(result, destination)
	return result
end

local function getNavigation(npc)
	local nav = npc.navigation
	if nav and nav.mode == "Flying" then
		return nav
	end
	nav = {
		mode = "Flying",
		route = nil,
		routeIndex = 1,
		nextDirectCheckAt = 0,
		directClear = false,
		nextRetryAt = 0,
		unreachableSince = nil,
		status = "Direct",
		lastRepathReason = "initial",
		preferredTargetY = nil,
	}
	npc.navigation = nav
	return nav
end

local function sampleGroundY(position: Vector3, profile): number?
	metrics.groundRaycastCount += 1
	local originY = math.min(profile.MaximumAltitude, position.Y + math.max(32, profile.PreferredAltitude * 2))
	local hit = workspace:Raycast(
		Vector3.new(position.X, originY, position.Z),
		Vector3.new(0, -(originY - profile.MinimumAltitude + 32), 0),
		groundParams
	)
	return hit and hit.Position.Y or nil
end

local function clampToBounds(position: Vector3, profile): Vector3
	local minXZ, maxXZ = WorldBounds.GetXZ(profile.CollisionRadius + 1)
	return Vector3.new(
		math.clamp(position.X, minXZ.X, maxXZ.X),
		math.clamp(position.Y, profile.MinimumAltitude, profile.MaximumAltitude),
		math.clamp(position.Z, minXZ.Y, maxXZ.Y)
	)
end

local function chooseFallback(origin: Vector3, destination: Vector3, profile): Vector3?
	local rise = math.max(profile.ObstacleProbeDistance, profile.MinimumGroundClearance)
	for _, offset in ipairs({
		Vector3.new(0, rise, 0),
		Vector3.new(0, -rise * 0.5, 0),
		Vector3.new(rise, rise * 0.5, 0),
		Vector3.new(-rise, rise * 0.5, 0),
		Vector3.new(0, rise * 0.5, rise),
		Vector3.new(0, rise * 0.5, -rise),
	}) do
		local candidate = clampToBounds(origin + offset, profile)
		if not spherecastBlocked(origin, candidate, profile.CollisionRadius)
			and not spherecastBlocked(candidate, destination, profile.CollisionRadius) then
			return candidate
		end
	end
	return nil
end

function NpcFlightNavigation.BeginTick(alivePlayers: {any})
	table.clear(sharedIgnore)
	for _, name in ipairs({ "Enemies", "Mobs", "Drops", "SpellVFX" }) do
		local inst = workspace:FindFirstChild(name)
		if inst then
			table.insert(sharedIgnore, inst)
		end
	end
	for _, info in ipairs(alivePlayers) do
		local character = info.player.Character
		if character then
			table.insert(sharedIgnore, character)
		end
	end
	for _, node in ipairs(CollectionService:GetTagged("NpcAirNode")) do
		table.insert(sharedIgnore, node)
	end
	castParams.FilterDescendantsInstances = sharedIgnore
	groundParams.FilterDescendantsInstances = sharedIgnore
	local now = os.clock()
	if graphDirty and now - lastGraphBuildAt >= 0.2 then
		rebuildGraph(now)
	end
end

function NpcFlightNavigation.Step(
	npc,
	goalPosition: Vector3,
	speed: number,
	dt: number,
	now: number
): (Vector3, string)
	local profile = npc.navigationProfile
	local nav = getNavigation(npc)

	if now >= nav.nextDirectCheckAt then
		local groundY = sampleGroundY(goalPosition, profile)
		nav.preferredTargetY = groundY and math.max(goalPosition.Y, groundY + profile.PreferredAltitude) or goalPosition.Y
		local flightGoal = clampToBounds(Vector3.new(goalPosition.X, nav.preferredTargetY, goalPosition.Z), profile)
		nav.directClear = not spherecastBlocked(npc.position, flightGoal, profile.CollisionRadius)
		nav.nextDirectCheckAt = now + profile.DirectCheckInterval
		if nav.directClear then
			nav.route = nil
			nav.status = "Direct"
			nav.unreachableSince = nil
			npc.unreachableSince = nil
			metrics.directFlights += 1
		elseif now >= nav.nextRetryAt then
			metrics.blockedFlights += 1
			nav.nextRetryAt = now + profile.RetryCooldown
			nav.route = profile.UseAirNodes and graphRoute(npc.position, flightGoal, profile.CollisionRadius, now) or nil
			nav.routeIndex = 1
			if nav.route then
				nav.status = "AirGraph"
				nav.lastRepathReason = "direct_blocked"
			else
				local fallback = chooseFallback(npc.position, flightGoal, profile)
				if fallback then
					nav.route = { fallback, flightGoal }
					nav.routeIndex = 1
					nav.status = "Avoidance"
					nav.lastRepathReason = "safe_altitude_detour"
				else
					nav.status = "Unreachable"
					nav.unreachableSince = nav.unreachableSince or now
					npc.unreachableSince = nav.unreachableSince
					nav.lastRepathReason = "no_safe_air_route"
				end
			end
		end
	end

	local destination = clampToBounds(
		Vector3.new(goalPosition.X, nav.preferredTargetY or goalPosition.Y, goalPosition.Z),
		profile
	)
	if nav.route then
		destination = nav.route[nav.routeIndex] or destination
		if (destination - npc.position).Magnitude <= math.max(2, profile.CollisionRadius) then
			nav.routeIndex += 1
			destination = nav.route[nav.routeIndex] or destination
			if nav.routeIndex > #nav.route then
				nav.route = nil
			end
		end
	elseif not nav.directClear then
		return Vector3.zero, nav.status
	end

	local groundY = sampleGroundY(npc.position, profile)
	if groundY and npc.position.Y < groundY + profile.MinimumGroundClearance then
		destination = Vector3.new(destination.X, math.max(destination.Y, groundY + profile.MinimumGroundClearance), destination.Z)
	end
	local desired = destination - npc.position
	if desired.Magnitude <= 0.05 or speed <= 0 then
		return Vector3.zero, nav.status
	end

	local desiredDir = desired.Unit
	local currentDir = npc.look.Magnitude > 0.05 and npc.look.Unit or desiredDir
	local steeredDir = currentDir:Lerp(desiredDir, math.clamp(profile.TurnSpeed * dt, 0, 1))
	if steeredDir.Magnitude <= 0.05 then
		steeredDir = desiredDir
	else
		steeredDir = steeredDir.Unit
	end
	local step = steeredDir * math.min(desired.Magnitude, speed * dt)
	step = Vector3.new(
		step.X,
		math.clamp(step.Y, -profile.DescendSpeed * dt, profile.AscendSpeed * dt),
		step.Z
	)
	local candidate = clampToBounds(npc.position + step, profile)
	if spherecastBlocked(npc.position, candidate, profile.CollisionRadius) then
		nav.directClear = false
		nav.nextDirectCheckAt = 0
		nav.status = "Blocked"
		return Vector3.zero, nav.status
	end
	if pointInNoFlyZone(candidate, profile.CollisionRadius) then
		nav.status = "NoFlyZone"
		return Vector3.zero, nav.status
	end
	nav.unreachableSince = nil
	npc.unreachableSince = nil
	return candidate - npc.position, nav.status
end

function NpcFlightNavigation.ClampPosition(npc, candidate: Vector3): Vector3
	local profile = npc.navigationProfile
	local clamped = clampToBounds(candidate, profile)
	if pointInNoFlyZone(clamped, profile.CollisionRadius)
		or spherecastBlocked(npc.position, clamped, profile.CollisionRadius) then
		return npc.position
	end
	return clamped
end

function NpcFlightNavigation.Invalidate(npc, reason: string?)
	local nav = npc.navigation
	if nav then
		nav.route = nil
		nav.nextDirectCheckAt = 0
		nav.lastRepathReason = reason or "invalidated"
	end
end

function NpcFlightNavigation.Cleanup(npc)
	NpcFlightNavigation.Invalidate(npc, "cleanup")
	npc.navigation = nil
	npc.unreachableSince = nil
end

function NpcFlightNavigation.GetMetrics(): {[string]: any}
	local result = table.clone(metrics)
	result.airNodeCount = #airNodes
	local edgeCount = 0
	for _, edges in pairs(airEdges) do
		edgeCount += #edges
	end
	result.airEdgeCount = math.floor(edgeCount / 2)
	return result
end

function NpcFlightNavigation.GetDebug(npc): {[string]: any}?
	local nav = npc.navigation
	if not nav or nav.mode ~= "Flying" then
		return nil
	end
	local nodes = {}
	for _, node in ipairs(airNodes) do
		table.insert(nodes, node.position)
	end
	local airConnections = {}
	for fromIndex, edges in pairs(airEdges) do
		for _, edge in ipairs(edges) do
			if edge.to > fromIndex then
				table.insert(airConnections, {
					airNodes[fromIndex].position,
					airNodes[edge.to].position,
				})
			end
		end
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
		waypoints = nav.route,
		waypointIndex = nav.routeIndex,
		lastRepathReason = nav.lastRepathReason,
		unreachable = nav.unreachableSince ~= nil,
		airNodes = nodes,
		airConnections = airConnections,
	}
end

local function markGraphDirty()
	graphDirty = true
end

table.insert(connections, CollectionService:GetInstanceAddedSignal("NpcAirNode"):Connect(markGraphDirty))
table.insert(connections, CollectionService:GetInstanceRemovedSignal("NpcAirNode"):Connect(markGraphDirty))
table.insert(connections, CollectionService:GetInstanceAddedSignal("NpcNoFlyZone"):Connect(markGraphDirty))
table.insert(connections, CollectionService:GetInstanceRemovedSignal("NpcNoFlyZone"):Connect(markGraphDirty))

function NpcFlightNavigation.Destroy()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(airNodes)
	table.clear(airEdges)
	table.clear(graphRouteCache)
end

return NpcFlightNavigation
