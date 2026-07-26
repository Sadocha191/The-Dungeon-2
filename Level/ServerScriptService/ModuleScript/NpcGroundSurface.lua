local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(moduleFolder, "[NpcGroundSurface] Server ModuleScript folder is required")
local Config = require(moduleFolder:WaitForChild("NpcNavigationConfig"))
local WorldBounds = require(moduleFolder:WaitForChild("WorldBounds"))

local NpcGroundSurface = {}

local corridorParams = RaycastParams.new()
corridorParams.FilterType = Enum.RaycastFilterType.Exclude
corridorParams.IgnoreWater = false
corridorParams.RespectCanCollide = true

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false
groundParams.RespectCanCollide = true

local sharedIgnore = {}
local groundIgnore = {}
local surfaceCache = {}

local metrics = {
	raycastCount = 0,
	blockcastCount = 0,
	traversalBlockcastCount = 0,
	traversalValidationFailures = 0,
	surfaceCacheHits = 0,
	falseSlopeObstacleHits = 0,
	groundProbeMisses = 0,
}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function slopeDegrees(normal: Vector3): number
	return math.deg(math.acos(math.clamp(normal:Dot(Vector3.yAxis), -1, 1)))
end

local function makeSurfaceSample(hit: RaycastResult, queryPosition: Vector3, expectedY: number)
	return {
		position = hit.Position,
		normal = hit.Normal,
		material = hit.Material,
		instance = hit.Instance,
		queryPosition = queryPosition,
		expectedY = expectedY,
		slopeDegrees = slopeDegrees(hit.Normal),
	}
end

local function forbiddenModifierLabel(instance: Instance, profile): string?
	local current = instance
	while current and current ~= workspace do
		local modifier = current:FindFirstChildWhichIsA("PathfindingModifier")
		if modifier and (profile.Costs[modifier.Label] or 0) >= 1000 then
			return modifier.Label
		end
		current = current.Parent
	end
	return nil
end

function NpcGroundSurface.GetFailureReason(sample, profile): string?
	if sample.material == Enum.Material.Water and (profile.Costs.Water or 0) >= 1000 then
		return "water_forbidden"
	end
	if forbiddenModifierLabel(sample.instance, profile) then
		return "surface_forbidden"
	end
	if sample.slopeDegrees > profile.MaxSlopeDegrees then
		return "slope_too_steep"
	end
	return nil
end

local function probeSurface(pos: Vector3, expectedSurfaceY: number, profile)
	local rise = profile.MaxStepUp + 2.5
	local origin = Vector3.new(pos.X, expectedSurfaceY + rise, pos.Z)
	local remaining = rise + profile.MaxDrop + 3
	local advance = Config.Scheduler.GroundProbeAdvance

	for _ = 1, Config.Scheduler.MaxGroundProbeHits do
		metrics.raycastCount += 1
		local hit = workspace:Raycast(origin, Vector3.new(0, -remaining, 0), groundParams)
		if not hit then
			break
		end
		if WorldBounds.IsGroundSurface(hit.Instance) then
			return makeSurfaceSample(hit, Vector3.new(pos.X, expectedSurfaceY, pos.Z), expectedSurfaceY)
		end
		local travelled = math.max(advance, origin.Y - hit.Position.Y + advance)
		remaining -= travelled
		if remaining <= 0 then
			break
		end
		origin = Vector3.new(pos.X, hit.Position.Y - advance, pos.Z)
	end

	metrics.groundProbeMisses += 1
	return nil
end

function NpcGroundSurface.SamplePrecise(pos: Vector3, expectedSurfaceY: number, profile)
	return probeSurface(pos, expectedSurfaceY, profile)
end

local function surfaceKey(pos: Vector3, expectedY: number, profile): string
	local resolution = Config.Scheduler.SurfaceCacheResolution
	local yResolution = Config.Scheduler.SurfaceCacheExpectedYResolution
	return string.format(
		"%s:%d:%d:%d",
		profile.Name,
		math.floor((pos.X / resolution) + 0.5),
		math.floor((expectedY / yResolution) + 0.5),
		math.floor((pos.Z / resolution) + 0.5)
	)
end

function NpcGroundSurface.SampleCached(pos: Vector3, expectedSurfaceY: number, profile, now: number)
	local key = surfaceKey(pos, expectedSurfaceY, profile)
	local cached = surfaceCache[key]
	if cached
		and cached.expiresAt >= now
		and flat(cached.queryPosition - pos).Magnitude <= Config.Scheduler.SurfaceCacheMaxPositionDelta
		and math.abs(cached.expectedY - expectedSurfaceY) <= Config.Scheduler.SurfaceCacheMaxExpectedYDelta then
		metrics.surfaceCacheHits += 1
		return cached.sample ~= false and cached.sample or nil
	end

	local sample = probeSurface(pos, expectedSurfaceY, profile)
	surfaceCache[key] = {
		expiresAt = now + Config.Scheduler.SurfaceCacheTtl,
		queryPosition = pos,
		expectedY = expectedSurfaceY,
		sample = sample or false,
	}
	return sample
end

local function bodyCenter(sample, profile, lift: number?): Vector3
	return Vector3.new(
		sample.position.X,
		sample.position.Y + (profile.AgentHeight * 0.5) + (lift or 0),
		sample.position.Z
	)
end

local function isLegalFloorContact(hit: RaycastResult, startSample, endSample, profile, supportedTopY: number?): boolean
	if not WorldBounds.IsGroundSurface(hit.Instance) then
		return false
	end
	supportedTopY = (supportedTopY or math.max(startSample.position.Y, endSample.position.Y))
		+ profile.GroundSkin
		+ Config.Scheduler.SurfaceLayerTolerance
		+ profile.AgentRadius
			* math.tan(math.rad(math.max(startSample.slopeDegrees, endSample.slopeDegrees)))
	if hit.Instance == workspace.Terrain and hit.Position.Y <= supportedTopY then
		-- Voxel Terrain can expose a vertical face between two legal, continuous
		-- surface samples. It is floor contact, not a wall; the raised retry below
		-- still checks the remaining body corridor for a real obstacle.
		return true
	end
	if slopeDegrees(hit.Normal) > profile.MaxSlopeDegrees + 1 then
		return false
	end
	local horizontalDelta = flat(endSample.position - startSample.position)
	local alpha = 0
	if horizontalDelta.Magnitude > 0.01 then
		alpha = math.clamp(
			flat(hit.Position - startSample.position):Dot(horizontalDelta) / (horizontalDelta.Magnitude ^ 2),
			0,
			1
		)
	end
	local expectedSurfaceY = startSample.position.Y + ((endSample.position.Y - startSample.position.Y) * alpha)
	local footprintRise = profile.AgentRadius
		* math.tan(math.rad(math.max(startSample.slopeDegrees, endSample.slopeDegrees)))
	local tolerance = profile.GroundSkin + footprintRise + Config.Scheduler.SurfaceLayerTolerance
	return hit.Position.Y <= expectedSurfaceY + tolerance
end

local function castBodySegment(startSample, endSample, profile, supportedTopY: number?): RaycastResult?
	local startCenter = bodyCenter(startSample, profile)
	local direction = bodyCenter(endSample, profile) - startCenter
	if direction.Magnitude <= 0.05 then
		return nil
	end

	local skin = profile.GroundSkin
	local size = Vector3.new(
		math.max(0.5, (profile.AgentRadius * 2) - (skin * 2)),
		math.max(1, profile.AgentHeight - (skin * 2)),
		math.max(0.5, (profile.AgentRadius * 2) - (skin * 2))
	)
	metrics.blockcastCount += 1
	local hit = workspace:Blockcast(CFrame.new(startCenter), size, direction, corridorParams)
	if not hit or not isLegalFloorContact(hit, startSample, endSample, profile, supportedTopY) then
		return hit
	end

	metrics.falseSlopeObstacleHits += 1
	local connectionSlope = math.deg(math.atan2(
		math.abs(endSample.position.Y - startSample.position.Y),
		math.max(0.01, flat(endSample.position - startSample.position).Magnitude)
	))
	local lift = skin
		+ profile.AgentRadius
			* math.tan(math.rad(math.max(connectionSlope, startSample.slopeDegrees, endSample.slopeDegrees)))
		+ Config.Scheduler.SurfaceLayerTolerance
	metrics.blockcastCount += 1
	local retryHit = workspace:Blockcast(CFrame.new(startCenter + Vector3.yAxis * lift), size, direction, corridorParams)
	if retryHit and isLegalFloorContact(retryHit, startSample, endSample, profile, supportedTopY) then
		metrics.falseSlopeObstacleHits += 1
		return nil
	end
	return retryHit
end

local function checkSurfaceContinuity(startSample, endSample, profile, supportedTopY: number?)
	local surfaceReason = NpcGroundSurface.GetFailureReason(endSample, profile)
	if surfaceReason then
		return false, surfaceReason, nil
	end
	local deltaY = endSample.position.Y - startSample.position.Y
	if deltaY > profile.MaxStepUp + 0.05 then
		return false, "step_too_high", nil
	end
	if deltaY < -profile.MaxDrop - 0.05 then
		return false, "drop_too_far", nil
	end
	local horizontalDistance = flat(endSample.position - startSample.position).Magnitude
	local connectionSlope = math.deg(math.atan2(math.abs(deltaY), math.max(0.01, horizontalDistance)))
	if connectionSlope > profile.MaxSlopeDegrees + 0.5 then
		return false, "slope_too_steep", nil
	end
	local hit = castBodySegment(startSample, endSample, profile, supportedTopY)
	if hit then
		return false, "body_obstacle", hit
	end
	return true, "clear", nil
end

local function failedResult(reason: string, samples, index: number?, hit: RaycastResult?)
	local startSample = samples and samples[1] or nil
	local endSample = samples and samples[index or 2] or samples and samples[2] or nil
	local previous = samples and samples[math.max(1, (index or 2) - 1)] or nil
	return {
		clear = false,
		reason = reason,
		hit = hit,
		surfaceSamples = samples or {},
		failedSampleIndex = index,
		startSurfaceY = startSample and startSample.position.Y or nil,
		endSurfaceY = endSample and endSample.position.Y or nil,
		deltaY = previous and endSample and endSample.position.Y - previous.position.Y or nil,
		slopeDegrees = endSample and endSample.slopeDegrees or nil,
	}
end

function NpcGroundSurface.CanTraverse(npc, destination: Vector3, profile, now: number)
	local currentSurfaceY = npc.position.Y - npc.groundOffset
	local startSample = NpcGroundSurface.SamplePrecise(npc.position, currentSurfaceY, profile)
	if not startSample then
		return failedResult("missing_surface", {}, 1)
	end
	local startReason = NpcGroundSurface.GetFailureReason(startSample, profile)
	if startReason then
		return failedResult(startReason, { startSample }, 1)
	end

	local delta = destination - npc.position
	local horizontalDelta = flat(delta)
	local probeDistance = math.min(horizontalDelta.Magnitude, profile.DirectProbeDistance)
	local samples = { startSample }
	if probeDistance <= 0.05 then
		return {
			clear = true,
			reason = "clear",
			surfaceSamples = samples,
			startSurfaceY = startSample.position.Y,
			endSurfaceY = startSample.position.Y,
			deltaY = 0,
			slopeDegrees = startSample.slopeDegrees,
		}
	end

	local count = math.max(1, math.ceil(probeDistance / profile.DirectSampleSpacing))
	local destinationSurfaceY = destination.Y - npc.groundOffset
	for index = 1, count do
		local alpha = index / count
		local horizontalPosition = npc.position + horizontalDelta.Unit * (probeDistance * alpha)
		local expectedY = startSample.position.Y + ((destinationSurfaceY - startSample.position.Y) * alpha)
		local sample = NpcGroundSurface.SampleCached(horizontalPosition, expectedY, profile, now)
		if not sample then
			return failedResult("missing_surface", samples, index + 1)
		end
		table.insert(samples, sample)
		local reason = NpcGroundSurface.GetFailureReason(sample, profile)
		if reason then
			return failedResult(reason, samples, index + 1)
		end
	end

	-- Sample the whole route before casting so each body segment can use the
	-- already-validated surface immediately in front of its footprint.
	for index = 2, #samples do
		local previous = samples[index - 1]
		local sample = samples[index]
		local supportSample = samples[math.min(#samples, index + 1)]
		local supportedTopY = math.max(previous.position.Y, sample.position.Y, supportSample.position.Y)
		local clear, reason, hit = checkSurfaceContinuity(previous, sample, profile, supportedTopY)
		if not clear then
			return failedResult(reason, samples, index, hit)
		end
	end
	local previous = samples[#samples]

	return {
		clear = true,
		reason = "clear",
		surfaceSamples = samples,
		startSurfaceY = startSample.position.Y,
		endSurfaceY = previous.position.Y,
		deltaY = previous.position.Y - startSample.position.Y,
		slopeDegrees = previous.slopeDegrees,
	}
end

local function widthLayerClear(centerSample, edgeSample, profile): boolean
	local distance = flat(edgeSample.position - centerSample.position).Magnitude
	local allowedDelta = math.tan(math.rad(profile.MaxSlopeDegrees)) * distance
		+ Config.Scheduler.SurfaceLayerTolerance
	return math.abs(edgeSample.position.Y - centerSample.position.Y) <= allowedDelta
end

function NpcGroundSurface.ValidateStep(npc, candidate: Vector3, profile, expectedY: number?)
	local currentSurfaceY = npc.position.Y - npc.groundOffset
	local startSample = NpcGroundSurface.SamplePrecise(npc.position, currentSurfaceY, profile)
	if not startSample then
		return failedResult("missing_surface", {}, 1)
	end
	local startReason = NpcGroundSurface.GetFailureReason(startSample, profile)
	if startReason then
		return failedResult(startReason, { startSample }, 1)
	end

	local direction = flat(candidate - npc.position)
	if direction.Magnitude <= 0.05 then
		return {
			clear = true,
			reason = "clear",
			position = npc.position,
			surfaceSamples = { startSample },
			startSurfaceY = startSample.position.Y,
			endSurfaceY = startSample.position.Y,
			deltaY = 0,
			slopeDegrees = startSample.slopeDegrees,
		}
	end

	local centerSample = NpcGroundSurface.SamplePrecise(candidate, expectedY or currentSurfaceY, profile)
	local samples = { startSample }
	if not centerSample then
		return failedResult("missing_surface", samples, 2)
	end
	table.insert(samples, centerSample)
	local centerReason = NpcGroundSurface.GetFailureReason(centerSample, profile)
	if centerReason then
		return failedResult(centerReason, samples, 2)
	end

	local moveDirection = direction.Unit
	local right = Vector3.new(-moveDirection.Z, 0, moveDirection.X)
	local probes = {
		candidate + moveDirection * math.max(0.5, profile.AgentRadius * profile.FrontProbeScale),
		candidate + right * profile.AgentRadius * profile.WidthProbeScale,
		candidate - right * profile.AgentRadius * profile.WidthProbeScale,
	}
	for _, probePosition in ipairs(probes) do
		local sample = NpcGroundSurface.SamplePrecise(probePosition, centerSample.position.Y, profile)
		if not sample then
			return failedResult("missing_surface", samples, #samples + 1)
		end
		table.insert(samples, sample)
		local reason = NpcGroundSurface.GetFailureReason(sample, profile)
		if reason then
			return failedResult(reason, samples, #samples)
		end
		if not widthLayerClear(centerSample, sample, profile) then
			return failedResult("surface_layer_mismatch", samples, #samples)
		end
	end

	local supportedTopY = centerSample.position.Y
	for index = 3, #samples do
		supportedTopY = math.max(supportedTopY, samples[index].position.Y)
	end
	local clear, reason, hit = checkSurfaceContinuity(startSample, centerSample, profile, supportedTopY)
	if not clear then
		return failedResult(reason, samples, 2, hit)
	end
	return {
		clear = true,
		reason = "clear",
		position = Vector3.new(candidate.X, centerSample.position.Y + npc.groundOffset, candidate.Z),
		surfaceSamples = samples,
		startSurfaceY = startSample.position.Y,
		endSurfaceY = centerSample.position.Y,
		deltaY = centerSample.position.Y - startSample.position.Y,
		slopeDegrees = centerSample.slopeDegrees,
	}
end


local function traversalCast(startCenter: Vector3, endCenter: Vector3, size: Vector3): RaycastResult?
	local direction = endCenter - startCenter
	if direction.Magnitude <= 0.05 then
		return nil
	end
	metrics.blockcastCount += 1
	metrics.traversalBlockcastCount += 1
	return workspace:Blockcast(CFrame.new(startCenter), size, direction, corridorParams)
end

function NpcGroundSurface.ValidateTraversal(npc, landingCandidate: Vector3, profile, options)
	options = options or {}
	local maxDistance = math.max(0, tonumber(options.maxDistance) or profile.TraversalMaxDistance or 0)
	local maxRise = math.max(0, tonumber(options.maxRise) or profile.TraversalMaxRise or profile.MaxStepUp)
	local maxDrop = math.max(0, tonumber(options.maxDrop) or profile.TraversalMaxDrop or profile.MaxDrop)
	local arcHeight = math.max(0, tonumber(options.arcHeight) or profile.TraversalArcHeight or 0)
	local horizontal = flat(landingCandidate - npc.position)
	if horizontal.Magnitude <= 0.05 then
		metrics.traversalValidationFailures += 1
		return failedResult("traversal_too_short", {}, 1)
	end
	if maxDistance <= 0 or horizontal.Magnitude > maxDistance + 0.05 then
		metrics.traversalValidationFailures += 1
		return failedResult("traversal_too_far", {}, 1)
	end

	local currentSurfaceY = npc.position.Y - npc.groundOffset
	local startSample = NpcGroundSurface.SamplePrecise(npc.position, currentSurfaceY, profile)
	if not startSample then
		metrics.traversalValidationFailures += 1
		return failedResult("missing_surface", {}, 1)
	end
	local startReason = NpcGroundSurface.GetFailureReason(startSample, profile)
	if startReason then
		metrics.traversalValidationFailures += 1
		return failedResult(startReason, { startSample }, 1)
	end

	local expectedLandingY = landingCandidate.Y - npc.groundOffset
	local centerSample = NpcGroundSurface.SamplePrecise(landingCandidate, expectedLandingY, profile)
	local samples = { startSample }
	if not centerSample then
		metrics.traversalValidationFailures += 1
		return failedResult("missing_landing_surface", samples, 2)
	end
	table.insert(samples, centerSample)
	local centerReason = NpcGroundSurface.GetFailureReason(centerSample, profile)
	if centerReason then
		metrics.traversalValidationFailures += 1
		return failedResult(centerReason, samples, 2)
	end

	local moveDirection = horizontal.Unit
	local right = Vector3.new(-moveDirection.Z, 0, moveDirection.X)
	local probes = {
		landingCandidate + moveDirection * math.max(0.5, profile.AgentRadius * profile.FrontProbeScale),
		landingCandidate + right * profile.AgentRadius * profile.WidthProbeScale,
		landingCandidate - right * profile.AgentRadius * profile.WidthProbeScale,
	}
	for _, probePosition in ipairs(probes) do
		local sample = NpcGroundSurface.SamplePrecise(probePosition, centerSample.position.Y, profile)
		if not sample then
			metrics.traversalValidationFailures += 1
			return failedResult("missing_landing_surface", samples, #samples + 1)
		end
		table.insert(samples, sample)
		local reason = NpcGroundSurface.GetFailureReason(sample, profile)
		if reason then
			metrics.traversalValidationFailures += 1
			return failedResult(reason, samples, #samples)
		end
		if not widthLayerClear(centerSample, sample, profile) then
			metrics.traversalValidationFailures += 1
			return failedResult("landing_layer_mismatch", samples, #samples)
		end
	end

	local deltaY = centerSample.position.Y - startSample.position.Y
	if deltaY > maxRise + 0.05 then
		metrics.traversalValidationFailures += 1
		return failedResult("traversal_rise_too_high", samples, 2)
	end
	if deltaY < -maxDrop - 0.05 then
		metrics.traversalValidationFailures += 1
		return failedResult("traversal_drop_too_far", samples, 2)
	end

	local skin = profile.GroundSkin
	local size = Vector3.new(
		math.max(0.5, (profile.AgentRadius * 2) - (skin * 2)),
		math.max(1, profile.AgentHeight - (skin * 2)),
		math.max(0.5, (profile.AgentRadius * 2) - (skin * 2))
	)
	local startCenter = bodyCenter(startSample, profile)
	local clearanceSurfaceY = math.max(startSample.position.Y, centerSample.position.Y) + arcHeight
	local clearanceCenterY = clearanceSurfaceY + (profile.AgentHeight * 0.5)
	local liftedStart = Vector3.new(startCenter.X, clearanceCenterY, startCenter.Z)
	local liftedEnd = Vector3.new(centerSample.position.X, clearanceCenterY, centerSample.position.Z)
	local endCenter = bodyCenter(centerSample, profile)
	local hit = traversalCast(startCenter, liftedStart, size)
	if not hit then
		hit = traversalCast(liftedStart, liftedEnd, size)
	end
	if not hit then
		hit = traversalCast(liftedEnd, endCenter, size)
	end
	if hit then
		metrics.traversalValidationFailures += 1
		return failedResult("traversal_blocked", samples, 2, hit)
	end

	return {
		clear = true,
		reason = "traversal_clear",
		position = Vector3.new(landingCandidate.X, centerSample.position.Y + npc.groundOffset, landingCandidate.Z),
		surfaceSamples = samples,
		startSurfaceY = startSample.position.Y,
		endSurfaceY = centerSample.position.Y,
		deltaY = deltaY,
		slopeDegrees = centerSample.slopeDegrees,
	}
end

function NpcGroundSurface.BeginTick(alivePlayers: {any})
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

function NpcGroundSurface.CleanupCache(now: number)
	for key, cached in pairs(surfaceCache) do
		if cached.expiresAt < now then
			surfaceCache[key] = nil
		end
	end
end

function NpcGroundSurface.GetMetrics(): {[string]: number}
	return table.clone(metrics)
end

return NpcGroundSurface
