local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NpcLifecycle = require(script.Parent:WaitForChild("NpcLifecycle"))
local NpcMelee = require(script.Parent:WaitForChild("NpcMelee"))
local NpcMovement = require(script.Parent:WaitForChild("NpcMovement"))

local DiveAttackBehavior = {}

local CONFIG = {
	WindupDuration = 0.55,
	DiveSpeed = 34,
	MaxDiveDuration = 1.20,
	MaxDiveDistance = 46,
	TriggerRange = 44,
	MinimumStartDistance = 7,
	HitRadius = 3.4,
	PredictionTime = 0.28,
	MaxPredictionDistance = 8,
	RecoveryHeight = 11,
	RecoverySpeed = 20,
	RecoveryDuration = 0.85,
	Cooldown = 2.35,
	InitialCooldownMin = 0.65,
	InitialCooldownMax = 1.35,
	GroundProbeHeight = 24,
	GroundProbeDistance = 180,
	ObstacleBackoff = 0.5,
}

local metrics = {
	windups = 0,
	dives = 0,
	hits = 0,
	misses = 0,
	obstacleAborts = 0,
	recoveries = 0,
}

local function numberAttribute(model: Model, name: string, fallback: number): number
	local value = model:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function getConfig(npc: any)
	return {
		windupDuration = math.max(0.1, numberAttribute(npc.model, "DiveWindupDuration", CONFIG.WindupDuration)),
		diveSpeed = math.max(1, numberAttribute(npc.model, "DiveSpeed", CONFIG.DiveSpeed)),
		maxDiveDuration = math.max(0.2, numberAttribute(npc.model, "DiveMaxDuration", CONFIG.MaxDiveDuration)),
		maxDiveDistance = math.max(6, numberAttribute(npc.model, "DiveMaxDistance", CONFIG.MaxDiveDistance)),
		triggerRange = math.max(6, numberAttribute(npc.model, "DiveTriggerRange", CONFIG.TriggerRange)),
		minimumStartDistance = math.max(0, numberAttribute(npc.model, "DiveMinimumStartDistance", CONFIG.MinimumStartDistance)),
		hitRadius = math.max(0.5, numberAttribute(npc.model, "DiveHitRadius", CONFIG.HitRadius)),
		predictionTime = math.max(0, numberAttribute(npc.model, "DivePredictionTime", CONFIG.PredictionTime)),
		maxPredictionDistance = math.max(0, numberAttribute(npc.model, "DiveMaxPredictionDistance", CONFIG.MaxPredictionDistance)),
		recoveryHeight = math.max(3, numberAttribute(npc.model, "DiveRecoveryHeight", CONFIG.RecoveryHeight)),
		recoverySpeed = math.max(1, numberAttribute(npc.model, "DiveRecoverySpeed", CONFIG.RecoverySpeed)),
		recoveryDuration = math.max(0.2, numberAttribute(npc.model, "DiveRecoveryDuration", CONFIG.RecoveryDuration)),
		cooldown = math.max(0.2, numberAttribute(npc.model, "DiveCooldown", CONFIG.Cooldown)),
	}
end

local function getState(npc: any, now: number): {[string]: any}
	local state = npc.combatBehaviorState
	if state and state.kind == "DiveAttack" then
		return state
	end

	local initialDelay = CONFIG.InitialCooldownMin
		+ (math.random() * (CONFIG.InitialCooldownMax - CONFIG.InitialCooldownMin))
	state = {
		kind = "DiveAttack",
		config = getConfig(npc),
		phase = "Cooldown",
		readyAt = now + initialDelay,
		phaseStartedAt = now,
		phaseEndsAt = now + initialDelay,
		targetPlayer = nil,
		hoverAnchor = nil,
		diveTarget = nil,
		diveDirection = nil,
		diveEndsAt = 0,
		hitApplied = false,
		recoveryTarget = nil,
		raycastParams = nil,
	}
	npc.combatBehaviorState = state
	return state
end

local function getAliveTargetInfo(player: Player?): any?
	if not player or player.Parent ~= Players or player:GetAttribute("RunEnded") == true then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp or not hrp:IsA("BasePart") then
		return nil
	end
	return {
		player = player,
		humanoid = humanoid,
		hrp = hrp,
	}
end

local function buildWorldRaycastParams(npc: any): RaycastParams
	local ignore = { npc.model }
	local enemies = Workspace:FindFirstChild("Enemies") or Workspace:FindFirstChild("Mobs")
	if enemies then
		table.insert(ignore, enemies)
	end
	local drops = Workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignore, drops)
	end
	local spellVfx = Workspace:FindFirstChild("SpellVFX")
	if spellVfx then
		table.insert(ignore, spellVfx)
	end
	local abilityVfx = Workspace:FindFirstChild("EnemyAbilityVFX")
	if abilityVfx then
		table.insert(ignore, abilityVfx)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	params.RespectCanCollide = true
	return params
end

local function hasClearPath(params: RaycastParams, fromPosition: Vector3, toPosition: Vector3): boolean
	local direction = toPosition - fromPosition
	if direction.Magnitude <= 1e-4 then
		return true
	end
	return Workspace:Raycast(fromPosition, direction, params) == nil
end

local function getGroundY(params: RaycastParams, position: Vector3): number?
	local origin = position + Vector3.new(0, CONFIG.GroundProbeHeight, 0)
	local direction = Vector3.new(0, -CONFIG.GroundProbeDistance, 0)
	local hit = Workspace:Raycast(origin, direction, params)
	return hit and hit.Position.Y or nil
end

local function distancePointToSegment(point: Vector3, startPosition: Vector3, endPosition: Vector3): number
	local segment = endPosition - startPosition
	local denominator = segment:Dot(segment)
	if denominator <= 1e-4 then
		return (point - startPosition).Magnitude
	end
	local alpha = math.clamp((point - startPosition):Dot(segment) / denominator, 0, 1)
	return (point - (startPosition + segment * alpha)).Magnitude
end

local function setLook(npc: any, targetPosition: Vector3)
	local delta = targetPosition - npc.position
	if delta.Magnitude > 1e-4 then
		npc.look = delta.Unit
	end
end

local function moveNpc(npc: any, nextPosition: Vector3, dt: number)
	local previous = npc.position
	npc.position = nextPosition
	npc.velocity = dt > 1e-4 and (nextPosition - previous) / dt or Vector3.zero
	if npc.velocity.Magnitude > 0.05 then
		npc.look = npc.velocity.Unit
	end
	NpcMovement.MoveModelToRoot(npc)
end

local function enterCooldown(npc: any, state: {[string]: any}, now: number, cooldown: number)
	state.phase = "Cooldown"
	state.phaseStartedAt = now
	state.phaseEndsAt = now + cooldown
	state.readyAt = state.phaseEndsAt
	state.targetPlayer = nil
	state.hoverAnchor = nil
	state.diveTarget = nil
	state.diveDirection = nil
	state.diveEndsAt = 0
	state.hitApplied = false
	state.recoveryTarget = nil
	state.raycastParams = nil
	npc.velocity = Vector3.zero
	NpcLifecycle.SetState(npc, "Idle")
end

local function beginRecovery(npc: any, state: {[string]: any}, now: number, cfg, wasMiss: boolean)
	local raycastParams = state.raycastParams or buildWorldRaycastParams(npc)
	state.raycastParams = raycastParams
	local groundY = getGroundY(raycastParams, npc.position)
	local minimumRecoveryY = groundY and (groundY + cfg.recoveryHeight) or (npc.position.Y + cfg.recoveryHeight)
	local recoveryY = math.max(npc.position.Y + 3, minimumRecoveryY)
	state.phase = "Recovery"
	state.phaseStartedAt = now
	state.phaseEndsAt = now + cfg.recoveryDuration
	state.recoveryTarget = Vector3.new(npc.position.X, recoveryY, npc.position.Z)
	state.diveDirection = nil
	npc.velocity = Vector3.zero
	NpcLifecycle.SetState(npc, "Chasing")
	metrics.recoveries += 1
	if wasMiss then
		metrics.misses += 1
	end
end

local function beginWindup(npc: any, state: {[string]: any}, targetInfo: any, now: number, cfg)
	state.phase = "Windup"
	state.phaseStartedAt = now
	state.phaseEndsAt = now + cfg.windupDuration
	state.targetPlayer = targetInfo.player
	state.hoverAnchor = npc.position
	state.hitApplied = false
	state.raycastParams = buildWorldRaycastParams(npc)
	npc.velocity = Vector3.zero
	npc.impulse = Vector3.zero
	setLook(npc, targetInfo.hrp.Position)
	NpcLifecycle.SetState(npc, "Attacking")
	metrics.windups += 1
end

local function beginDive(npc: any, state: {[string]: any}, targetInfo: any, now: number, cfg): boolean
	local targetVelocity = targetInfo.hrp.AssemblyLinearVelocity
	local prediction = Vector3.new(targetVelocity.X, 0, targetVelocity.Z) * cfg.predictionTime
	if prediction.Magnitude > cfg.maxPredictionDistance and prediction.Magnitude > 1e-4 then
		prediction = prediction.Unit * cfg.maxPredictionDistance
	end

	local targetPosition = targetInfo.hrp.Position + prediction + Vector3.new(0, 0.5, 0)
	local delta = targetPosition - npc.position
	if delta.Magnitude <= 1e-4 then
		return false
	end
	if delta.Magnitude > cfg.maxDiveDistance then
		targetPosition = npc.position + (delta.Unit * cfg.maxDiveDistance)
		delta = targetPosition - npc.position
	end

	state.phase = "Dive"
	state.phaseStartedAt = now
	state.phaseEndsAt = now + cfg.maxDiveDuration
	state.diveEndsAt = state.phaseEndsAt
	state.diveTarget = targetPosition
	state.diveDirection = delta.Unit
	state.hitApplied = false
	npc.velocity = Vector3.zero
	npc.impulse = Vector3.zero
	NpcLifecycle.SetState(npc, "Attacking")
	metrics.dives += 1
	return true
end

local function stepWindup(npc: any, state: {[string]: any}, dt: number, now: number, cfg): boolean
	local targetInfo = getAliveTargetInfo(state.targetPlayer)
	if not targetInfo then
		enterCooldown(npc, state, now, cfg.cooldown)
		return true
	end

	local anchor = state.hoverAnchor or npc.position
	moveNpc(npc, anchor, dt)
	setLook(npc, targetInfo.hrp.Position)
	NpcLifecycle.SetState(npc, "Attacking")

	if now >= state.phaseEndsAt and not beginDive(npc, state, targetInfo, now, cfg) then
		beginRecovery(npc, state, now, cfg, true)
	end
	return true
end

local function stepDive(npc: any, state: {[string]: any}, dt: number, now: number, cfg): boolean
	local targetInfo = getAliveTargetInfo(state.targetPlayer)
	if not targetInfo then
		beginRecovery(npc, state, now, cfg, true)
		return true
	end

	local direction = state.diveDirection
	local targetPosition = state.diveTarget
	if typeof(direction) ~= "Vector3" or typeof(targetPosition) ~= "Vector3" then
		beginRecovery(npc, state, now, cfg, true)
		return true
	end

	local previous = npc.position
	local remaining = (targetPosition - previous):Dot(direction)
	if remaining <= 0.05 or now >= state.diveEndsAt then
		beginRecovery(npc, state, now, cfg, not state.hitApplied)
		return true
	end

	local travelDistance = math.min(cfg.diveSpeed * math.max(0, dt), remaining)
	local nextPosition = previous + (direction * travelDistance)
	local raycastParams = state.raycastParams or buildWorldRaycastParams(npc)
	state.raycastParams = raycastParams
	local obstacleHit = Workspace:Raycast(previous, nextPosition - previous, raycastParams)
	if obstacleHit then
		nextPosition = obstacleHit.Position - (direction * CONFIG.ObstacleBackoff)
		moveNpc(npc, nextPosition, dt)
		metrics.obstacleAborts += 1
		beginRecovery(npc, state, now, cfg, not state.hitApplied)
		return true
	end

	moveNpc(npc, nextPosition, dt)
	NpcLifecycle.SetState(npc, "Attacking")

	if not state.hitApplied
		and distancePointToSegment(targetInfo.hrp.Position, previous, nextPosition) <= cfg.hitRadius
		and hasClearPath(raycastParams, previous, targetInfo.hrp.Position)
	then
		state.hitApplied = true
		NpcMelee.ApplyPlayerDamage(targetInfo.player, npc.damage, npc.model)
		metrics.hits += 1
		beginRecovery(npc, state, now, cfg, false)
		return true
	end

	if travelDistance >= remaining - 0.05 then
		beginRecovery(npc, state, now, cfg, not state.hitApplied)
	end
	return true
end

local function stepRecovery(npc: any, state: {[string]: any}, dt: number, now: number, cfg): boolean
	local targetPosition = state.recoveryTarget
	if typeof(targetPosition) ~= "Vector3" then
		enterCooldown(npc, state, now, cfg.cooldown)
		return true
	end

	local delta = targetPosition - npc.position
	if delta.Magnitude <= 0.75 or now >= state.phaseEndsAt then
		moveNpc(npc, targetPosition, dt)
		enterCooldown(npc, state, now, cfg.cooldown)
		return true
	end

	local stepDistance = math.min(cfg.recoverySpeed * math.max(0, dt), delta.Magnitude)
	moveNpc(npc, npc.position + (delta.Unit * stepDistance), dt)
	NpcLifecycle.SetState(npc, "Chasing")
	return true
end

function DiveAttackBehavior.Step(
	npc: any,
	targetInfo: any?,
	dt: number,
	now: number,
	_callbacks: {[string]: any}?
): boolean
	local state = getState(npc, now)
	local cfg = state.config or getConfig(npc)
	state.config = cfg

	if npc.freezeEnd > now then
		local frozenFor = math.max(0, tonumber(dt) or 0)
		state.phaseStartedAt += frozenFor
		state.phaseEndsAt += frozenFor
		state.readyAt += frozenFor
		if state.diveEndsAt > 0 then
			state.diveEndsAt += frozenFor
		end
		npc.velocity = Vector3.zero
		NpcLifecycle.SetState(npc, state.phase == "Cooldown" and "Idle" or "Attacking")
		return state.phase ~= "Cooldown"
	end

	if state.phase == "Cooldown" then
		if now < state.readyAt then
			return false
		end
		state.phase = "Hover"
	end

	if state.phase == "Hover" then
		if not targetInfo or not targetInfo.hrp or not targetInfo.hrp.Parent then
			return false
		end
		local distance = (targetInfo.hrp.Position - npc.position).Magnitude
		if distance > cfg.triggerRange or distance < cfg.minimumStartDistance then
			return false
		end
		beginWindup(npc, state, targetInfo, now, cfg)
		return true
	end

	if state.phase == "Windup" then
		return stepWindup(npc, state, dt, now, cfg)
	end
	if state.phase == "Dive" then
		return stepDive(npc, state, dt, now, cfg)
	end
	if state.phase == "Recovery" then
		return stepRecovery(npc, state, dt, now, cfg)
	end

	enterCooldown(npc, state, now, cfg.cooldown)
	return false
end

function DiveAttackBehavior.Pause(npc: any, dt: number)
	local state = npc.combatBehaviorState
	if not state or state.kind ~= "DiveAttack" then
		return
	end
	local pausedFor = math.max(0, tonumber(dt) or 0)
	state.phaseStartedAt += pausedFor
	state.phaseEndsAt += pausedFor
	state.readyAt += pausedFor
	if state.diveEndsAt > 0 then
		state.diveEndsAt += pausedFor
	end
	npc.velocity = Vector3.zero
end

function DiveAttackBehavior.Cleanup(npc: any)
	npc.combatBehaviorState = nil
end

function DiveAttackBehavior.GetMetrics(): {[string]: number}
	return table.clone(metrics)
end

return DiveAttackBehavior
