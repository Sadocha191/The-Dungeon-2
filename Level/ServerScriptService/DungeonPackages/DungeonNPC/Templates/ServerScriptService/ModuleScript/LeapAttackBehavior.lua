local NpcLifecycle = require(script.Parent:WaitForChild("NpcLifecycle"))
local NpcMelee = require(script.Parent:WaitForChild("NpcMelee"))
local NpcMovement = require(script.Parent:WaitForChild("NpcMovement"))

local LeapAttackBehavior = {}

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
	if state and state.kind == "LeapAttack" then
		return state
	end
	state = {
		kind = "LeapAttack",
		phase = "Chase",
		leapStartedAt = 0,
		leapEndsAt = 0,
		leapStart = nil,
		leapTarget = nil,
		targetPlayer = nil,
		lastLeapAt = -math.huge,
		hitApplied = false,
	}
	npc.combatBehaviorState = state
	return state
end

local function beginLeap(npc: any, state: {[string]: any}, targetInfo: any, dt: number, now: number)
	local targetPosition = targetInfo.hrp.Position
	local duration = math.max(0.18, numberAttribute(npc.model, "LeapAttackTime", 0.4))
	local firstStep = math.clamp(math.max(0, tonumber(dt) or 0), 0, duration * 0.5)
	state.phase = "Leap"
	state.leapStartedAt = now - firstStep
	state.leapEndsAt = state.leapStartedAt + duration
	state.leapStart = npc.position
	state.leapTarget = targetPosition
	state.targetPlayer = targetInfo.player
	state.hitApplied = false
	npc.look = flatUnit(targetPosition - npc.position, npc.look)
end

local function finishLeap(npc: any, state: {[string]: any}, now: number)
	if not state.hitApplied then
		local player = state.targetPlayer
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hitRadius = math.max(1, numberAttribute(npc.model, "LeapAttackHitRadius", 3))
		if humanoid and humanoid.Health > 0 and root and (root.Position - npc.position).Magnitude <= hitRadius then
			local damageMultiplier = math.max(0, numberAttribute(npc.model, "LeapAttackDamageMultiplier", 1.1))
			NpcMelee.ApplyPlayerDamage(player, math.max(1, math.floor(npc.damage * damageMultiplier + 0.5)), npc.model)
		end
		state.hitApplied = true
	end
	state.phase = "Chase"
	state.lastLeapAt = now
	state.leapStart = nil
	state.leapTarget = nil
	state.targetPlayer = nil
	npc.velocity = Vector3.zero
end

function LeapAttackBehavior.Step(npc: any, targetInfo: any?, dt: number, now: number): boolean
	local state = getState(npc)
	local triggerRange = math.max(npc.attackRange or 3, numberAttribute(npc.model, "LeapAttackTriggerRange", 12))
	local cooldown = math.max(0.2, numberAttribute(npc.model, "LeapAttackCooldown", 2.4))

	if state.phase == "Chase" then
		if not targetInfo or not targetInfo.hrp or not targetInfo.hrp.Parent then
			return false
		end
		local distance = (targetInfo.hrp.Position - npc.position).Magnitude
		if distance > triggerRange or distance <= (npc.attackRange or 3) or (now - state.lastLeapAt) < cooldown then
			return false
		end
		beginLeap(npc, state, targetInfo, dt, now)
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
		local endPosition = state.leapTarget or npc.position
		local duration = math.max(0.01, state.leapEndsAt - state.leapStartedAt)
		local alpha = math.clamp((now - state.leapStartedAt) / duration, 0, 1)
		local arcHeight = math.max(0, numberAttribute(npc.model, "LeapAttackArcHeight", 5.5))
		local previous = npc.position
		local position = startPosition:Lerp(endPosition, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * arcHeight, 0)
		npc.position = position
		npc.velocity = dt > 1e-4 and (position - previous) / dt or Vector3.zero
		npc.look = flatUnit(endPosition - position, npc.look)
		NpcLifecycle.SetState(npc, "Attacking")
		NpcMovement.MoveModelToRoot(npc)
		if alpha >= 1 then
			finishLeap(npc, state, now)
		end
		return true
	end

	return false
end

function LeapAttackBehavior.Pause(npc: any, dt: number)
	local state = npc.combatBehaviorState
	if not state or state.kind ~= "LeapAttack" or state.phase ~= "Leap" then
		return
	end
	local pausedFor = math.max(0, tonumber(dt) or 0)
	state.leapStartedAt += pausedFor
	state.leapEndsAt += pausedFor
end

function LeapAttackBehavior.Cleanup(npc: any)
	npc.combatBehaviorState = nil
end

return LeapAttackBehavior
