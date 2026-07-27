local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NpcLifecycle = require(script.Parent:WaitForChild("NpcLifecycle"))
local NpcMelee = require(script.Parent:WaitForChild("NpcMelee"))
local NpcMovement = require(script.Parent:WaitForChild("NpcMovement"))

local LeapExplodeBehavior = {}
local NPC_OCCLUSION_BUCKET_COUNT = 48
local NPC_OCCLUSION_CANDIDATES_PER_BUCKET = 8
local TWO_PI = math.pi * 2

-- NpcService loads this behavior while it is initializing, so resolve the public
-- damage API only when a detonation actually happens.
local npcService = nil
local npcServiceWarningShown = false

local function getNpcService()
	if npcService then
		return npcService
	end

	local module = script.Parent:FindFirstChild("NpcService")
	if not module or not module:IsA("ModuleScript") then
		if not npcServiceWarningShown then
			npcServiceWarningShown = true
			warn("[LeapExplodeBehavior] NpcService ModuleScript is required for NPC blast damage")
		end
		return nil
	end

	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		npcService = result
		return npcService
	end

	if not npcServiceWarningShown then
		npcServiceWarningShown = true
		warn("[LeapExplodeBehavior] Failed to resolve NpcService for NPC blast damage:", result)
	end
	return nil
end

local metrics = {
	armed = 0,
	leaps = 0,
	detonations = 0,
	damageHits = 0,
	npcDamageHits = 0,
	npcOcclusionTests = 0,
	lineOfSightRaycasts = 0,
	legacyVisualFallbacks = 0,
}

local function numberAttribute(model: Model, name: string, fallback: number): number
	local value = model:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function flatUnit(delta: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude > 1e-4 then
		return flat.Unit
	end
	return fallback
end

local function getState(npc: any): {[string]: any}
	local state = npc.combatBehaviorState
	if state and state.kind == "LeapExplode" then
		return state
	end
	state = {
		kind = "LeapExplode",
		phase = "Chase",
		leapStartedAt = 0,
		leapEndsAt = 0,
		leapStart = nil,
		leapTarget = nil,
		lastTargetPosition = nil,
		detonated = false,
	}
	npc.combatBehaviorState = state
	return state
end

local function resolveLeapTarget(npc: any, targetPosition: Vector3): Vector3
	local origin = npc.position
	local direction = targetPosition - origin
	if direction.Magnitude <= 1e-4 then
		return targetPosition
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc.model }
	params.IgnoreWater = false
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(origin, direction, params)
	if hit and not hit.Instance:IsDescendantOf(npc.model) then
		local backoff = math.min(1.5, direction.Magnitude * 0.15)
		return hit.Position - direction.Unit * backoff
	end
	return targetPosition
end

local function hasLineOfSight(
	npc: any,
	targetModel: Model,
	targetPosition: Vector3,
	origin: Vector3,
	ignoreInstances: {Instance}?
): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreInstances or { npc.model }
	params.IgnoreWater = false
	local direction = targetPosition - origin
	if direction.Magnitude <= 1e-4 then
		return true
	end
	metrics.lineOfSightRaycasts += 1
	local hit = Workspace:Raycast(origin, direction, params)
	return hit == nil or hit.Instance:IsDescendantOf(targetModel)
end

local function getExplosionStats(npc: any): (number, number)
	local radius = math.max(1, numberAttribute(npc.model, "LeapExplodeRadius", 10))
	local damage = math.max(0, math.floor(numberAttribute(
		npc.model,
		"LeapExplodeDamage",
		math.max(npc.damage, npc.damage * 1.75)
	)))
	return radius, damage
end

local function damagePlayers(npc: any, origin: Vector3, radius: number, damage: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 and player:GetAttribute("RunEnded") ~= true then
			if (root.Position - origin).Magnitude <= radius and hasLineOfSight(npc, character, root.Position, origin) then
				NpcMelee.ApplyPlayerDamage(player, damage, npc.model)
				metrics.damageHits += 1
			end
		end
	end
end

local function normalizedHorizontalAngle(delta: Vector3): number
	local angle = math.atan2(delta.Z, delta.X)
	return angle < 0 and angle + TWO_PI or angle
end

local function angularDistance(first: number, second: number): number
	local delta = math.abs(first - second)
	return math.min(delta, TWO_PI - delta)
end

local function angleBucketIndex(angle: number): number
	return math.clamp(
		math.floor((angle / TWO_PI) * NPC_OCCLUSION_BUCKET_COUNT) + 1,
		1,
		NPC_OCCLUSION_BUCKET_COUNT
	)
end

local function addNpcBodyToOcclusionBuckets(origin: Vector3, target, buckets)
	local delta = target.position - origin
	local horizontalDistance = Vector2.new(delta.X, delta.Z).Magnitude
	local angularRadius = horizontalDistance <= target.bodyRadius
		and math.pi
		or math.asin(math.clamp(target.bodyRadius / horizontalDistance, 0, 1))
	local centerAngle = normalizedHorizontalAngle(delta)
	local bucketWidth = TWO_PI / NPC_OCCLUSION_BUCKET_COUNT

	for index = 1, NPC_OCCLUSION_BUCKET_COUNT do
		local bucket = buckets[index]
		if #bucket < NPC_OCCLUSION_CANDIDATES_PER_BUCKET then
			local bucketCenter = (index - 0.5) * bucketWidth
			if angularDistance(centerAngle, bucketCenter) <= angularRadius + bucketWidth * 0.5 then
				table.insert(bucket, target)
			end
		end
	end
end

local function isOccludedByNpcBody(origin: Vector3, target, candidates): boolean
	local segment = target.position - origin
	local segmentLengthSq = segment:Dot(segment)
	if segmentLengthSq <= 1e-4 then
		return false
	end

	for _, blocker in ipairs(candidates) do
		metrics.npcOcclusionTests += 1
		local alpha = (blocker.position - origin):Dot(segment) / segmentLengthSq
		if alpha > 0 and alpha < 1 then
			local closestPoint = origin + segment * alpha
			if (blocker.position - closestPoint).Magnitude <= blocker.bodyRadius then
				return true
			end
		end
	end
	return false
end

local function damageNpcs(npc: any, origin: Vector3, radius: number, damage: number)
	local service = getNpcService()
	if not service then
		return
	end

	local lineOfSightIgnore = { npc.model }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(lineOfSightIgnore, player.Character)
		end
	end

	local targets = {}
	for _, targetModel in ipairs(service.GetEnemiesInRadius(origin, radius)) do
		if targetModel ~= npc.model then
			local targetPosition = service.GetPosition(targetModel)
			local targetRoot = service.GetRoot(targetModel)
			if targetPosition and targetRoot then
				table.insert(targets, {
					model = targetModel,
					position = targetPosition,
					distanceSq = (targetPosition - origin):Dot(targetPosition - origin),
					bodyRadius = math.max(0.75, targetRoot.Size.Magnitude * 0.5),
				})
			end
		end
	end

	table.sort(targets, function(first, second)
		return first.distanceSq < second.distanceSq
	end)
	local occlusionBuckets = table.create(NPC_OCCLUSION_BUCKET_COUNT)
	for index = 1, NPC_OCCLUSION_BUCKET_COUNT do
		occlusionBuckets[index] = {}
	end

	for _, target in ipairs(targets) do
		local targetAngle = normalizedHorizontalAngle(target.position - origin)
		local candidates = occlusionBuckets[angleBucketIndex(targetAngle)]
		if not isOccludedByNpcBody(origin, target, candidates)
			and hasLineOfSight(
				npc,
				target.model,
				target.position,
				origin,
				lineOfSightIgnore
			)
		then
			local dealt = service.ApplyDamage(target.model, damage, {
				cause = "LeapExplode",
				sourceModel = npc.model,
				showFloating = false,
				suppressRewards = true,
			})
			if dealt > 0 then
				metrics.npcDamageHits += 1
			end
		end
		addNpcBodyToOcclusionBuckets(origin, target, occlusionBuckets)
	end
end

local function hasAuthoredExplosionPresenter(): boolean
	local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
		or ReplicatedStorage:FindFirstChild("ModuleScript")
	return moduleFolder ~= nil and moduleFolder:FindFirstChild("VfxTemplatePlayer") ~= nil
end

local function createLegacyExplosionFallback(origin: Vector3)
	local explosion = Instance.new("Explosion")
	explosion.Name = "NpcLeapExplodeFallback"
	explosion.Position = origin
	explosion.BlastRadius = 0
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace
	Debris:AddItem(explosion, 1)
	metrics.legacyVisualFallbacks += 1
end

local function beginLeap(npc: any, state: {[string]: any}, targetPosition: Vector3, dt: number, now: number)
	local leapDuration = math.max(0.12, numberAttribute(npc.model, "LeapExplodeLeapTime", 0.5))
	local firstStep = math.clamp(math.max(0, tonumber(dt) or 0), 0, leapDuration * 0.5)
	state.phase = "Leap"
	state.leapStartedAt = now - firstStep
	state.leapEndsAt = state.leapStartedAt + leapDuration
	state.leapStart = npc.position
	state.leapTarget = resolveLeapTarget(npc, targetPosition)
	npc.look = flatUnit(targetPosition - npc.position, npc.look)
	metrics.armed += 1
	metrics.leaps += 1
end

local function detonate(npc: any, state: {[string]: any}, callbacks: {[string]: any}?)
	if state.detonated then
		return
	end
	state.detonated = true
	state.phase = "Detonate"
	metrics.detonations += 1
	local origin = npc.position
	local radius, damage = getExplosionStats(npc)
	damagePlayers(npc, origin, radius, damage)
	damageNpcs(npc, origin, radius, damage)
	if not hasAuthoredExplosionPresenter() then
		createLegacyExplosionFallback(origin)
	end
	if callbacks and type(callbacks.kill) == "function" then
		callbacks.kill({
			cause = "LeapExplode",
			position = origin,
			suppressRewards = true,
		})
	else
		NpcLifecycle.Kill(npc, {
			cause = "LeapExplode",
			position = origin,
			suppressRewards = true,
		})
	end
	state.phase = "Dead"
end

function LeapExplodeBehavior.Step(
	npc: any,
	targetInfo: any?,
	dt: number,
	now: number,
	callbacks: {[string]: any}?
): boolean
	local state = getState(npc)
	local liveTargetPosition = nil
	if targetInfo and targetInfo.hrp and targetInfo.hrp.Parent then
		liveTargetPosition = targetInfo.hrp.Position
		state.lastTargetPosition = liveTargetPosition
	end
	local triggerRange = math.max(1, numberAttribute(npc.model, "LeapExplodeTriggerRange", 16))

	if state.phase == "Chase" then
		if not liveTargetPosition or (liveTargetPosition - npc.position).Magnitude > triggerRange then
			return false
		end
		beginLeap(npc, state, liveTargetPosition, dt, now)
	end

	if npc.freezeEnd > now then
		state.leapStartedAt += dt
		state.leapEndsAt += dt
		npc.velocity = Vector3.zero
		NpcLifecycle.SetState(npc, "Attacking")
		return true
	end

	if state.phase == "Leap" then
		local startPosition = state.leapStart or npc.position
		local endPosition = state.leapTarget or state.lastTargetPosition or npc.position
		local duration = math.max(0.01, state.leapEndsAt - state.leapStartedAt)
		local alpha = math.clamp((now - state.leapStartedAt) / duration, 0, 1)
		local arcHeight = math.max(0, numberAttribute(npc.model, "LeapExplodeArcHeight", 8))
		local previous = npc.position
		local position = startPosition:Lerp(endPosition, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * arcHeight, 0)
		npc.position = position
		npc.velocity = dt > 1e-4 and (position - previous) / dt or Vector3.zero
		npc.look = flatUnit(endPosition - position, npc.look)
		NpcLifecycle.SetState(npc, "Attacking")
		NpcMovement.MoveModelToRoot(npc)
		if alpha >= 1 then
			detonate(npc, state, callbacks)
		end
		return true
	end

	return false
end

function LeapExplodeBehavior.Pause(npc: any, dt: number)
	local state = npc.combatBehaviorState
	if not state or state.kind ~= "LeapExplode" or state.phase == "Chase" then
		return
	end
	local pausedFor = math.max(0, tonumber(dt) or 0)
	state.leapStartedAt += pausedFor
	state.leapEndsAt += pausedFor
end

function LeapExplodeBehavior.Cleanup(npc: any)
	npc.combatBehaviorState = nil
end

function LeapExplodeBehavior.GetMetrics(): {[string]: number}
	return table.clone(metrics)
end

return LeapExplodeBehavior
