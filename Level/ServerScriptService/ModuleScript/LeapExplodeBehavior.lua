local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NpcLifecycle = require(script.Parent:WaitForChild("NpcLifecycle"))
local NpcMelee = require(script.Parent:WaitForChild("NpcMelee"))
local NpcMovement = require(script.Parent:WaitForChild("NpcMovement"))

local LeapExplodeBehavior = {}

local metrics = {
	armed = 0,
	leaps = 0,
	detonations = 0,
	damageHits = 0,
	lineOfSightRaycasts = 0,
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
		phaseEndsAt = 0,
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

local function hasLineOfSight(npc: any, character: Model, root: BasePart, origin: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npc.model }
	params.IgnoreWater = false
	metrics.lineOfSightRaycasts += 1
	local hit = Workspace:Raycast(origin, root.Position - origin, params)
	return hit == nil or hit.Instance:IsDescendantOf(character)
end

local function damagePlayers(npc: any, origin: Vector3)
	local radius = math.max(1, numberAttribute(npc.model, "LeapExplodeRadius", 10))
	local damage = math.max(0, math.floor(numberAttribute(npc.model, "LeapExplodeDamage", math.max(npc.damage, npc.damage * 1.75))))
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 and player:GetAttribute("RunEnded") ~= true then
			if (root.Position - origin).Magnitude <= radius and hasLineOfSight(npc, character, root, origin) then
				NpcMelee.ApplyPlayerDamage(player, damage, npc.model)
				metrics.damageHits += 1
			end
		end
	end
end

local function createExplosionVisual(origin: Vector3)
	local explosion = Instance.new("Explosion")
	explosion.Name = "NpcLeapExplode"
	explosion.Position = origin
	explosion.BlastRadius = 0
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = Workspace
end

local function detonate(npc: any, state: {[string]: any}, callbacks: {[string]: any}?)
	if state.detonated then
		return
	end
	state.detonated = true
	metrics.detonations += 1
	local origin = npc.position
	damagePlayers(npc, origin)
	createExplosionVisual(origin)
	if callbacks and type(callbacks.kill) == "function" then
		callbacks.kill({ cause = "LeapExplode", position = origin })
	else
		NpcLifecycle.Kill(npc, { cause = "LeapExplode", position = origin })
	end
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
	local targetPosition = liveTargetPosition or state.leapTarget or state.lastTargetPosition
	local triggerRange = math.max(1, numberAttribute(npc.model, "LeapExplodeTriggerRange", 16))

	if state.phase == "Chase" then
		if not liveTargetPosition or (liveTargetPosition - npc.position).Magnitude > triggerRange then
			return false
		end
		state.phase = "Arm"
		state.phaseEndsAt = now + math.max(0.05, numberAttribute(npc.model, "LeapExplodeArmTime", 0.45))
		metrics.armed += 1
	end

	if npc.freezeEnd > now then
		state.phaseEndsAt += dt
		state.leapStartedAt += dt
		state.leapEndsAt += dt
		npc.velocity = Vector3.zero
		NpcLifecycle.SetState(npc, "Attacking")
		return true
	end

	if state.phase == "Arm" then
		npc.velocity = Vector3.zero
		if targetPosition then
			npc.look = flatUnit(targetPosition - npc.position, npc.look)
		end
		NpcLifecycle.SetState(npc, "Attacking")
		if now >= state.phaseEndsAt then
			local leapDuration = math.max(0.12, numberAttribute(npc.model, "LeapExplodeLeapTime", 0.5))
			state.phase = "Leap"
			state.leapStartedAt = now
			state.leapEndsAt = now + leapDuration
			state.leapStart = npc.position
			state.leapTarget = resolveLeapTarget(npc, targetPosition or npc.position)
			metrics.leaps += 1
		end
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
	state.phaseEndsAt += pausedFor
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
