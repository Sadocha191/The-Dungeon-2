local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedModuleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript")
local NpcShared = require(sharedModuleFolder:WaitForChild("NpcShared"))

local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(serverModuleFolder, "[NpcLifecycle] Server ModuleScript folder is required")
local npcRegistryModule = serverModuleFolder:FindFirstChild("NpcRegistry")
assert(npcRegistryModule and npcRegistryModule:IsA("ModuleScript"), "[NpcLifecycle] NpcRegistry ModuleScript is required")
local NpcRegistry = require(npcRegistryModule)
local npcMovementModule = serverModuleFolder:FindFirstChild("NpcMovement")
assert(npcMovementModule and npcMovementModule:IsA("ModuleScript"), "[NpcLifecycle] NpcMovement ModuleScript is required")
local NpcMovement = require(npcMovementModule)

local NpcLifecycle = {}

local ATTR = NpcShared.Attributes
local STATE = NpcShared.States

local RUNTIME_ATTRIBUTE_NAMES = {
	ATTR.State,
	ATTR.LegacyState,
	ATTR.AiState,
	ATTR.Dead,
	ATTR.LegacyDead,
	ATTR.LegacyAttacking,
	ATTR.Alive,
	ATTR.Direction,
	ATTR.Velocity,
	ATTR.Health,
	ATTR.LegacyHealth,
	ATTR.MaxHealth,
	ATTR.LegacyMaxHealth,
}

function NpcLifecycle.ClearRuntimeAttributes(model: Model)
	for _, name in ipairs(RUNTIME_ATTRIBUTE_NAMES) do
		if model:GetAttribute(name) ~= nil then
			model:SetAttribute(name, nil)
		end
	end
end

function NpcLifecycle.EnsureRuntimeAttributesCleared(npc: any)
	if npc.runtimeAttrsCleared then
		return
	end
	NpcLifecycle.ClearRuntimeAttributes(npc.model)
	npc.runtimeAttrsCleared = true
end

function NpcLifecycle.WriteStateAttributes(npc: any)
	NpcLifecycle.EnsureRuntimeAttributesCleared(npc)
end

function NpcLifecycle.WriteHealthAttributes(npc: any)
	NpcLifecycle.EnsureRuntimeAttributesCleared(npc)
end

function NpcLifecycle.SetState(npc: any, newState: string)
	if npc.state == newState then
		return
	end

	npc.state = newState
	NpcLifecycle.WriteStateAttributes(npc)
end

local function queueTombstone(npc: any, despawned: boolean)
	NpcRegistry.QueueTombstone({
		id = npc.id,
		model = npc.model,
		type = npc.mobType,
		pos = npc.position,
		dir = npc.look,
		vel = npc.velocity,
		speed = 0,
		state = despawned and STATE.Despawned or npc.state,
		hp = npc.health,
		maxHp = npc.maxHealth,
		dead = npc.dead,
		despawned = despawned,
	})
end

function NpcLifecycle.Unregister(npc: any, despawned: boolean?): boolean
	if not NpcRegistry.Contains(npc) then
		return false
	end

	NpcRegistry.Remove(npc)
	queueTombstone(npc, despawned == true)
	return true
end

function NpcLifecycle.DestroyNow(npc: any, despawned: boolean)
	NpcLifecycle.Unregister(npc, despawned)
	if npc.model.Parent then
		npc.model:Destroy()
	end
end

function NpcLifecycle.Kill(npc: any, context: {[string]: any}?)
	if npc.dead then
		return
	end

	local deathContext = {}
	if context then
		for key, value in pairs(context) do
			deathContext[key] = value
		end
	end

	npc.dead = true
	npc.health = 0
	npc.velocity = Vector3.zero
	npc.impulse = Vector3.zero
	npc.attackUntil = 0
	NpcLifecycle.SetState(npc, STATE.Dead)
	NpcLifecycle.WriteHealthAttributes(npc)
	deathContext.position = npc.position
	deathContext.model = npc.model
	deathContext.npcId = npc.id

	for _, callback in ipairs(npc.deathCallbacks) do
		pcall(callback, npc, deathContext)
	end

	NpcLifecycle.DestroyNow(npc, true)
end

function NpcLifecycle.ApplyDamage(npc: any, amount: number, context: {[string]: any}?): number
	if npc.dead then
		return 0
	end

	local dealt = tonumber(amount) or 0
	if npc.damageTakenEnd > os.clock() then
		dealt *= npc.damageTakenMult
	elseif npc.damageTakenEnd ~= 0 then
		npc.damageTakenEnd = 0
		npc.damageTakenMult = 1
	end
	dealt = math.floor(dealt)
	if dealt <= 0 then
		return 0
	end

	npc.health = math.max(0, npc.health - dealt)
	NpcLifecycle.WriteHealthAttributes(npc)
	if npc.health <= 0 then
		NpcLifecycle.Kill(npc, context or {})
	end
	return dealt
end

function NpcLifecycle.Despawn(npc: any)
	if not npc.dead then
		npc.dead = true
		npc.health = 0
		npc.velocity = Vector3.zero
		npc.impulse = Vector3.zero
		npc.attackUntil = 0
		NpcLifecycle.SetState(npc, STATE.Despawned)
		NpcLifecycle.WriteHealthAttributes(npc)
	end

	NpcLifecycle.DestroyNow(npc, true)
end

function NpcLifecycle.GetCurrentSpeed(npc: any, now: number): number
	if npc.freezeEnd > now then
		return 0
	end
	if npc.slowEnd > now and npc.slowPct > 0 then
		return math.max(0, npc.baseSpeed * (1 - npc.slowPct))
	end
	if npc.slowEnd ~= 0 then
		npc.slowEnd = 0
		npc.slowPct = 0
	end
	return npc.baseSpeed
end

function NpcLifecycle.GetControlResistance(npc: any)
	if npc.isBoss then
		return {
			slowPct = 0.55,
			slowDuration = 0.45,
			freezeDuration = 0.22,
			impulse = 0.20,
		}
	end
	if npc.isElite then
		return {
			slowPct = 0.78,
			slowDuration = 0.72,
			freezeDuration = 0.45,
			impulse = 0.48,
		}
	end
	return {
		slowPct = 1,
		slowDuration = 1,
		freezeDuration = 1,
		impulse = 1,
	}
end

function NpcLifecycle.ApplySlow(npc: any, slowPct: number, duration: number)
	local resist = NpcLifecycle.GetControlResistance(npc)
	local now = os.clock()
	npc.slowPct = math.max(npc.slowPct, math.clamp((tonumber(slowPct) or 0) * resist.slowPct, 0, 0.95))
	npc.slowEnd = math.max(npc.slowEnd, now + math.max(0.05, (tonumber(duration) or 0) * resist.slowDuration))
end

function NpcLifecycle.ApplyFreeze(npc: any, duration: number)
	local resist = NpcLifecycle.GetControlResistance(npc)
	local now = os.clock()
	npc.freezeEnd = math.max(npc.freezeEnd, now + math.max(0.08, (tonumber(duration) or 0) * resist.freezeDuration))
end

function NpcLifecycle.AddImpulse(npc: any, impulse: Vector3)
	local flatImpulse = NpcMovement.Flat(impulse)
	if flatImpulse.Magnitude <= 1e-4 then
		return
	end

	local resist = NpcLifecycle.GetControlResistance(npc)
	npc.impulse = NpcMovement.ClampMagnitude(npc.impulse + (flatImpulse * resist.impulse), 90)
end

function NpcLifecycle.SetIncomingDamageModifier(npc: any, multiplier: number, duration: number)
	npc.damageTakenMult = math.clamp(tonumber(multiplier) or 1, 0.10, 3)
	npc.damageTakenEnd = os.clock() + math.max(0.1, tonumber(duration) or 0)
end

function NpcLifecycle.LockForAbility(npc: any, duration: number, faceTarget: Vector3?)
	npc.aiLockUntil = math.max(npc.aiLockUntil, os.clock() + math.max(0.05, tonumber(duration) or 0))
	npc.aiLookTarget = typeof(faceTarget) == "Vector3" and faceTarget or npc.aiLookTarget
end

return NpcLifecycle
