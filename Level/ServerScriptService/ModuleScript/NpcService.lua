local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript")
local NpcShared = require(moduleFolder:WaitForChild("NpcShared"))
local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
assert(serverModuleFolder, "[NpcService] Server ModuleScript folder is required")
local npcRegistryModule = serverModuleFolder:FindFirstChild("NpcRegistry")
assert(npcRegistryModule and npcRegistryModule:IsA("ModuleScript"), "[NpcService] NpcRegistry ModuleScript is required")
local NpcRegistry = require(npcRegistryModule)
local npcLifecycleModule = serverModuleFolder:FindFirstChild("NpcLifecycle")
assert(npcLifecycleModule and npcLifecycleModule:IsA("ModuleScript"), "[NpcService] NpcLifecycle ModuleScript is required")
local NpcLifecycle = require(npcLifecycleModule)
local npcReplicationModule = serverModuleFolder:FindFirstChild("NpcReplication")
assert(npcReplicationModule and npcReplicationModule:IsA("ModuleScript"), "[NpcService] NpcReplication ModuleScript is required")
local NpcReplication = require(npcReplicationModule)
local npcMovementModule = serverModuleFolder:FindFirstChild("NpcMovement")
assert(npcMovementModule and npcMovementModule:IsA("ModuleScript"), "[NpcService] NpcMovement ModuleScript is required")
local NpcMovement = require(npcMovementModule)
local NpcNavigationConfig = require(serverModuleFolder:WaitForChild("NpcNavigationConfig"))
local NpcGroundNavigation = require(serverModuleFolder:WaitForChild("NpcGroundNavigation"))
local NpcFlightNavigation = require(serverModuleFolder:WaitForChild("NpcFlightNavigation"))
local NpcNavigationDebug = require(serverModuleFolder:WaitForChild("NpcNavigationDebug"))
local NpcMovementSystemController = require(serverModuleFolder:WaitForChild("NpcMovementSystemController"))
local NpcCombatBehaviorService = require(serverModuleFolder:WaitForChild("NpcCombatBehaviorService"))
local npcTargetingModule = serverModuleFolder:FindFirstChild("NpcTargeting")
assert(npcTargetingModule and npcTargetingModule:IsA("ModuleScript"), "[NpcService] NpcTargeting ModuleScript is required")
local NpcTargeting = require(npcTargetingModule)
local npcMeleeModule = serverModuleFolder:FindFirstChild("NpcMelee")
assert(npcMeleeModule and npcMeleeModule:IsA("ModuleScript"), "[NpcService] NpcMelee ModuleScript is required")
local NpcMelee = require(npcMeleeModule)
local MissionProgress = nil
if serverModuleFolder then
	pcall(function()
		MissionProgress = require(serverModuleFolder:WaitForChild("MissionProgress"))
	end)
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name: string): RemoteEvent
	local ev = remotes:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then
		return ev
	end
	if ev then
		ev:Destroy()
	end

	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remotes
	return ev
end

local batchEvent = ensureRemoteEvent(NpcShared.RemoteName)
local syncRequestEvent = ensureRemoteEvent(NpcShared.SyncRequestRemoteName)
local damageIndicatorEvent = ensureRemoteEvent("DamageIndicatorEvent")

local pauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not pauseState then
	pauseState = Instance.new("BoolValue")
	pauseState.Name = "PauseState"
	pauseState.Value = false
	pauseState.Parent = ReplicatedStorage
end

local ATTR = NpcShared.Attributes
local STATE = NpcShared.States

type NpcConfig = {
	mobType: string?,
	maxHealth: number?,
	speed: number?,
	attackRange: number?,
	attackCooldown: number?,
	damage: number?,
	isElite: boolean?,
	isBoss: boolean?,
	isRanged: boolean?,
	movementProfile: string?,
	movementMode: string?,
	movementSystem: string?,
	movementBehavior: string?,
	combatBehavior: string?,
	canFly: boolean?,
	groundOffset: number?,
	despawnDelay: number?,
	attackWindup: number?,
	onDeath: ((any, {[string]: any}) -> ())?,
}

type ActiveCountFilter = {
	includeNormal: boolean?,
	includeElite: boolean?,
	includeBoss: boolean?,
}

type AlivePlayerInfo = {
	player: Player,
	hrp: BasePart,
	humanoid: Humanoid,
}

type NpcEngagementSlot = {
	lane: number,
	depth: number,
	approachDir: Vector3,
}

type NpcRecord = {
	id: string,
	model: Model,
	root: BasePart,
	mobType: string,
	maxHealth: number,
	health: number,
	baseSpeed: number,
	attackRange: number,
	attackCooldown: number,
	damage: number,
	isElite: boolean,
	isBoss: boolean,
	isRanged: boolean,
	movementSystem: string,
	movementBehavior: string,
	combatBehavior: string?,
	movementProfile: string,
	movementMode: string,
	navigationProfile: {[string]: any},
	navigation: {[string]: any}?,
	surfaceNormal: Vector3?,
	combatBehaviorState: {[string]: any}?,
	unreachableSince: number?,
	retargetBlockedPlayer: Player?,
	retargetBlockedUntil: number?,
	lineOfSightTarget: Player?,
	nextLineOfSightAt: number?,
	hasLineOfSight: boolean?,
	despawnDelay: number,
	attackWindup: number,
	state: string,
	dead: boolean,
	spawnTime: number,
	attackUntil: number,
	nextAttackAt: number,
	targetPlayer: Player?,
	nextTargetScanAt: number,
	position: Vector3,
	look: Vector3,
	velocity: Vector3,
	impulse: Vector3,
	damageTakenMult: number,
	damageTakenEnd: number,
	slowPct: number,
	slowEnd: number,
	freezeEnd: number,
	spawnSurfacePosition: Vector3?,
	spawnUndergroundPosition: Vector3?,
	spawnHoldUntil: number,
	spawnEmergeEnd: number,
	spawnEmergeDepth: number,
	aiLockUntil: number,
	aiLookTarget: Vector3?,
	groundOffset: number,
	lastGroundAt: number,
	lastGroundXZ: Vector3,
	orbitSign: number,
	orbitRadius: number,
	targetGroundY: number?,
	runtimeAttrsCleared: boolean,
	deathCallbacks: {((any, {[string]: any}) -> ())},
}

local NpcService = {}

local NORMAL_DESPAWN_DISTANCE = 100
local NPC_FORMATION_MOVEMENT_CONFIG = NpcTargeting.FormationMovementConfig
local flat = NpcMovement.Flat
local safeUnit = NpcMovement.SafeUnit
local repairDetachedVisualParts = NpcMovement.RepairDetachedVisualParts
local computeGroundOffset = NpcMovement.ComputeGroundOffset
local beginSpawnEmergence = NpcMovement.BeginSpawnEmergence
local moveNpcModelToRoot = NpcMovement.MoveModelToRoot
local applyPlayerDamage = NpcMelee.ApplyPlayerDamage
local canApplyMeleeDamage = NpcMelee.CanApplyDamage
local clearRuntimeAttributes = NpcLifecycle.ClearRuntimeAttributes
local writeStateAttributes = NpcLifecycle.WriteStateAttributes
local writeHealthAttributes = NpcLifecycle.WriteHealthAttributes
local setState = NpcLifecycle.SetState
local lifecycleUnregisterNpc = NpcLifecycle.Unregister
local lifecycleKillNpc = NpcLifecycle.Kill
local lifecycleDespawnNpcRecord = NpcLifecycle.Despawn
local getCurrentSpeed = NpcLifecycle.GetCurrentSpeed

local function cleanupNavigation(npc: NpcRecord)
	NpcMovementSystemController.Cleanup(npc)
	NpcCombatBehaviorService.Cleanup(npc)
end

local function unregisterNpc(npc: NpcRecord, addTombstone: boolean?)
	cleanupNavigation(npc)
	lifecycleUnregisterNpc(npc, addTombstone)
end

local function killNpc(npc: NpcRecord, context: {[string]: any})
	cleanupNavigation(npc)
	lifecycleKillNpc(npc, context)
end

local function despawnNpcRecord(npc: NpcRecord)
	cleanupNavigation(npc)
	lifecycleDespawnNpcRecord(npc)
end

local function setAttributeIfChanged(inst: Instance, name: string, value: any)
	if inst:GetAttribute(name) ~= value then
		inst:SetAttribute(name, value)
	end
end

local function resolveRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local primary = model.PrimaryPart
	if primary and primary:IsA("BasePart") then
		return primary
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function ensureAnimationController(model: Model)
	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = model
	end

	if not controller:FindFirstChildOfClass("Animator") then
		local animator = Instance.new("Animator")
		animator.Parent = controller
	end
end

local function stripLegacyNpcScripts(model: Model)
	local animationsFolder = model:FindFirstChild("Animations")
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			if string.lower(descendant.Name) == "animate" then
				if not animationsFolder then
					animationsFolder = Instance.new("Folder")
					animationsFolder.Name = "Animations"
					animationsFolder.Parent = model
				end
				for _, child in ipairs(descendant:GetChildren()) do
					child.Parent = animationsFolder
				end
			end
			descendant:Destroy()
		end
	end
end

local function updateSpawnEmergence(npc: NpcRecord, now: number, dt: number): boolean
	local surfacePosition = npc.spawnSurfacePosition
	if typeof(surfacePosition) ~= "Vector3" then
		return false
	end

	local undergroundPosition = npc.spawnUndergroundPosition or surfacePosition
	local nextPosition = undergroundPosition
	local holdUntil = tonumber(npc.spawnHoldUntil) or now
	local emergeEnd = tonumber(npc.spawnEmergeEnd) or holdUntil

	if now >= emergeEnd then
		nextPosition = surfacePosition
		npc.spawnSurfacePosition = nil
		npc.spawnUndergroundPosition = nil
		npc.spawnHoldUntil = 0
		npc.spawnEmergeEnd = 0
		npc.spawnEmergeDepth = 0
		npc.targetGroundY = surfacePosition.Y
		npc.lastGroundAt = 0
		setState(npc, STATE.Idle)
	else
		if now >= holdUntil then
			local duration = math.max(0.05, emergeEnd - holdUntil)
			local alpha = math.clamp((now - holdUntil) / duration, 0, 1)
			local eased = 1 - ((1 - alpha) * (1 - alpha) * (1 - alpha))
			nextPosition = undergroundPosition:Lerp(surfacePosition, eased)
		end
		setState(npc, STATE.Spawn)
	end

	npc.position = nextPosition
	npc.velocity = Vector3.zero
	npc.impulse = Vector3.zero
	npc.attackUntil = 0
	npc.nextAttackAt = math.max(npc.nextAttackAt, now + 0.15)

	moveNpcModelToRoot(npc)
	writeStateAttributes(npc)
	return true
end

local function resolveNpc(target: any): NpcRecord?
	return NpcRegistry.Resolve(target)
end

local function matchesActiveCountFilter(npc: NpcRecord, filter: ActiveCountFilter?): boolean
	if not filter then
		return true
	end

	local includeNormal = filter.includeNormal
	local includeElite = filter.includeElite
	local includeBoss = filter.includeBoss
	if includeNormal == nil and includeElite == nil and includeBoss == nil then
		return true
	end

	if npc.isBoss then
		return includeBoss == true
	end
	if npc.isElite then
		return includeElite == true
	end
	return includeNormal == true
end

local function fireDamageIndicator(sourcePlayer: Player?, npc: NpcRecord, amount: number, crit: boolean?)
	if not sourcePlayer or sourcePlayer.Parent ~= Players then
		return
	end

	damageIndicatorEvent:FireClient(sourcePlayer, {
		pos = npc.position + Vector3.new(0, 2, 0),
		amount = math.max(1, math.floor(amount + 0.5)),
		crit = crit == true,
	})
end

local function shouldDistanceDespawn(npc: NpcRecord, alivePlayers: {AlivePlayerInfo}): boolean
	return NpcTargeting.ShouldDistanceDespawn(npc, alivePlayers, NORMAL_DESPAWN_DISTANCE)
end

local function updateNpc(
	npc: NpcRecord,
	dt: number,
	alivePlayers: {AlivePlayerInfo},
	now: number,
	engagementSlots: {[string]: NpcEngagementSlot},
	spatialGrid: {[string]: {any}}
)
	if npc.dead then
		return
	end
	if not npc.model.Parent or not npc.root.Parent then
		unregisterNpc(npc, true)
		return
	end

	if updateSpawnEmergence(npc, now, dt) then
		return
	end

	if pauseState.Value then
		npc.velocity = Vector3.zero
		npc.impulse = Vector3.zero
		npc.attackUntil = 0
		npc.nextAttackAt = math.max(npc.nextAttackAt, now + 0.1)
		NpcCombatBehaviorService.Pause(npc, dt)
		setState(npc, STATE.Idle)
		writeStateAttributes(npc)
		return
	end

	if shouldDistanceDespawn(npc, alivePlayers) then
		despawnNpcRecord(npc)
		return
	end

	if now < npc.aiLockUntil then
		npc.velocity = Vector3.zero
		if npc.aiLookTarget then
			local lookDelta = npc.aiLookTarget - npc.position
			npc.look = safeUnit(
				NpcMovementSystemController.Uses3DTargeting(npc) and lookDelta or flat(lookDelta),
				npc.look
			)
		end
		setState(npc, STATE.Attacking)
		writeStateAttributes(npc)
		return
	end
	npc.aiLookTarget = nil

	local targetInfo = NpcTargeting.FindNearestTarget(npc, alivePlayers, now)
	if NpcCombatBehaviorService.Step(npc, targetInfo, dt, now, {
		kill = function(context)
			killNpc(npc, context)
		end,
	}) then
		if not npc.dead then
			writeStateAttributes(npc)
		end
		return
	end

	if not targetInfo then
		npc.velocity = Vector3.zero
		setState(npc, STATE.Idle)
		writeStateAttributes(npc)
		return
	end

	local targetPos = targetInfo.hrp.Position
	local toTarget3D = targetPos - npc.position
	local uses3DMovement = NpcMovementSystemController.Uses3DTargeting(npc)
	local toTarget = uses3DMovement and toTarget3D or flat(toTarget3D)
	local dist = toTarget.Magnitude
	local fullDistance = toTarget3D.Magnitude
	local stopDistance = npc.isRanged
		and math.max(3, npc.attackRange * 0.72)
		or math.max(1.25, npc.attackRange - 0.2)
	local formationWeight = NpcTargeting.ComputeFormationWeight(dist, stopDistance)
	local baseMove = Vector3.zero
	local canAttack = fullDistance <= npc.attackRange and canApplyMeleeDamage(npc, targetInfo)

	if npc.attackUntil > now then
		npc.velocity = Vector3.zero
		npc.look = safeUnit(toTarget, npc.look)
		setState(npc, STATE.Attacking)
	elseif canAttack then
		npc.look = safeUnit(toTarget, npc.look)
		npc.velocity = Vector3.zero
		if now >= npc.nextAttackAt then
			npc.nextAttackAt = now + npc.attackCooldown
			npc.attackUntil = now + npc.attackWindup
			setState(npc, STATE.Attacking)
			applyPlayerDamage(targetInfo.player, npc.damage, npc.model)
		else
			setState(npc, STATE.Idle)
		end
	else
		local desiredPos = NpcMovement.ComputeOrbitTarget(
			npc,
			targetPos,
			stopDistance,
			engagementSlots[npc.id],
			formationWeight,
			NPC_FORMATION_MOVEMENT_CONFIG
		)
		local desiredMove = flat(desiredPos - npc.position)
		if formationWeight < 0.995 then
			local directMove = flat(targetPos - npc.position)
			if directMove.Magnitude > 0.05 then
				desiredMove = desiredMove:Lerp(directMove, 1 - formationWeight)
			end
		end
		local speed = getCurrentSpeed(npc, now)
		if speed > 0 and (desiredMove.Magnitude > 0.05 or uses3DMovement) then
			local navigationStatus = "Idle"
			baseMove, navigationStatus = NpcMovementSystemController.Step(
				npc,
				targetPos,
				desiredPos,
				speed,
				dt,
				now,
				spatialGrid
			)
			if baseMove.Magnitude > 0.05 then
				npc.look = safeUnit(baseMove, safeUnit(toTarget, npc.look))
				setState(npc, STATE.Chasing)
			else
				npc.look = safeUnit(toTarget, npc.look)
				setState(npc, navigationStatus == "Unreachable" and STATE.Idle or STATE.Chasing)
			end
		else
			npc.look = safeUnit(toTarget, npc.look)
			setState(npc, STATE.Idle)
		end
	end


	local impulseMove = NpcMovementSystemController.ProjectImpulse(npc, npc.impulse) * dt
	local nextPos = npc.position + baseMove + impulseMove
	nextPos = NpcMovementSystemController.ConstrainPosition(npc, nextPos, now)

	local newVelocity = Vector3.zero
	if dt > 1e-4 then
		newVelocity = Vector3.new(
			(nextPos.X - npc.position.X) / dt,
			(nextPos.Y - npc.position.Y) / dt,
			(nextPos.Z - npc.position.Z) / dt
		)
	end

	npc.position = nextPos
	npc.velocity = newVelocity
	npc.impulse *= math.max(0, 1 - (dt * 7))
	if npc.impulse.Magnitude < 0.15 then
		npc.impulse = Vector3.zero
	end

	writeStateAttributes(npc)
end

local function sendBatchToPlayer(player: Player, fullSnapshot: boolean?, requestId: number?)
	NpcReplication.SendBatchToPlayer(batchEvent, player, fullSnapshot, requestId, NpcRegistry.Pairs)
end

local function broadcastBatch()
	NpcReplication.BroadcastBatch(batchEvent, NpcRegistry.Pairs, NpcRegistry.Tombstones, NpcRegistry.ClearTombstones)
end

function NpcService.GetRoot(target: any): BasePart?
	local npc = resolveNpc(target)
	return npc and npc.root or nil
end

function NpcService.GetPosition(target: any): Vector3?
	local npc = resolveNpc(target)
	return npc and npc.position or nil
end

function NpcService.IsAlive(target: any): boolean
	local npc = resolveNpc(target)
	return npc ~= nil and npc.dead == false
end

function NpcService.GetHealth(target: any): (number, number)
	local npc = resolveNpc(target)
	if not npc then
		return 0, 0
	end
	return npc.health, npc.maxHealth
end

function NpcService.GetLivingModels(): {Model}
	local result = {}
	for _, npc in NpcRegistry.Pairs() do
		if NpcTargeting.IsTargetable(npc) then
			table.insert(result, npc.model)
		end
	end
	return result
end

function NpcService.GetActiveCount(filter: ActiveCountFilter?): number
	local count = 0
	for _, npc in NpcRegistry.Pairs() do
		if not npc.dead and npc.model.Parent and matchesActiveCountFilter(npc, filter) then
			count += 1
		end
	end
	return count
end

function NpcService.DespawnOldestFarNormal(minDistance: number): Model?
	local threshold = math.max(0, tonumber(minDistance) or 0)
	local alivePlayers = NpcTargeting.GetAlivePlayers()
	if #alivePlayers == 0 then
		return nil
	end

	local bestNpc = nil
	for _, npc in NpcRegistry.Pairs() do
		if not npc.dead and npc.model.Parent and not npc.isElite and npc.model:GetAttribute("IsBoss") ~= true then
			local nearestDist = math.huge
			for _, info in ipairs(alivePlayers) do
				nearestDist = math.min(nearestDist, NpcMovement.FlatMagnitude(info.hrp.Position, npc.position))
			end
			if nearestDist >= threshold then
				if not bestNpc or npc.spawnTime < bestNpc.spawnTime then
					bestNpc = npc
				end
			end
		end
	end

	if not bestNpc then
		return nil
	end

	local model = bestNpc.model
	NpcService.Despawn(model)
	return model
end

function NpcService.GetNearestEnemy(fromPos: Vector3, maxRange: number): (Model?, number)
	local searchRange = maxRange or math.huge
	local bestModel = nil
	local bestDist = searchRange
	local bestEffectiveDist = math.huge
	local bestPriority = -math.huge
	for _, npc in NpcRegistry.Pairs() do
		if NpcTargeting.IsTargetable(npc) then
			local dist = (npc.position - fromPos).Magnitude
			if dist <= searchRange then
				local effectiveDist, actualDist, priority = NpcTargeting.ComputeTargetingMetrics(npc, fromPos)
				if effectiveDist < bestEffectiveDist
					or (math.abs(effectiveDist - bestEffectiveDist) <= 1e-4 and priority > bestPriority)
					or (math.abs(effectiveDist - bestEffectiveDist) <= 1e-4 and priority == bestPriority and actualDist < bestDist)
				then
					bestEffectiveDist = effectiveDist
					bestDist = actualDist
					bestPriority = priority
					bestModel = npc.model
				end
			end
		end
	end
	return bestModel, bestDist
end

function NpcService.GetEnemiesInRadius(fromPos: Vector3, radius: number): {Model}
	local hits = {}
	for _, npc in NpcRegistry.Pairs() do
		if NpcTargeting.IsTargetable(npc) then
			local dist = (npc.position - fromPos).Magnitude
			if dist <= radius then
				local effectiveDist, actualDist, priority = NpcTargeting.ComputeTargetingMetrics(npc, fromPos)
				table.insert(hits, {
					model = npc.model,
					effectiveDist = effectiveDist,
					actualDist = actualDist,
					priority = priority,
				})
			end
		end
	end

	table.sort(hits, function(a, b)
		if math.abs(a.effectiveDist - b.effectiveDist) > 1e-4 then
			return a.effectiveDist < b.effectiveDist
		end
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		if math.abs(a.actualDist - b.actualDist) > 1e-4 then
			return a.actualDist < b.actualDist
		end
		return tostring(a.model) < tostring(b.model)
	end)

	local models = {}
	for _, hit in ipairs(hits) do
		models[#models + 1] = hit.model
	end
	return models
end

function NpcService.GetTargetingMetrics(fromPos: Vector3, target: any): (number?, number?, number?)
	if typeof(fromPos) ~= "Vector3" then
		return nil, nil, nil
	end

	local npc = resolveNpc(target)
	if not npc or not NpcTargeting.IsTargetable(npc) then
		return nil, nil, nil
	end

	return NpcTargeting.ComputeTargetingMetrics(npc, fromPos)
end

function NpcService.ApplySlow(target: any, slowPct: number, duration: number)
	local npc = resolveNpc(target)
	if not npc or npc.dead then
		return
	end

	NpcLifecycle.ApplySlow(npc, slowPct, duration)
end

function NpcService.ApplyFreeze(target: any, duration: number)
	local npc = resolveNpc(target)
	if not npc or npc.dead then
		return
	end

	NpcLifecycle.ApplyFreeze(npc, duration)
end

function NpcService.AddImpulse(target: any, impulse: Vector3)
	local npc = resolveNpc(target)
	if not npc or npc.dead or typeof(impulse) ~= "Vector3" then
		return
	end

	NpcLifecycle.AddImpulse(npc, impulse)
end

function NpcService.BindDeath(target: any, callback: (any, {[string]: any}) -> ())
	local npc = resolveNpc(target)
	if not npc then
		return
	end

	table.insert(npc.deathCallbacks, callback)
end

function NpcService.ApplyDamage(target: any, amount: number, meta: {[string]: any}?): number
	local npc = resolveNpc(target)
	if not npc or npc.dead then
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
	writeHealthAttributes(npc)

	local sourcePlayer = meta and meta.player
	if not (meta and meta.showFloating == false) then
		fireDamageIndicator(sourcePlayer, npc, dealt, meta and meta.crit)
	end
	if MissionProgress and sourcePlayer and sourcePlayer.Parent == Players and sourcePlayer:GetAttribute("RunEnded") ~= true then
		pcall(function()
			MissionProgress.OnDamage(sourcePlayer, dealt, meta and meta.crit == true)
		end)
	end

	if npc.health <= 0 then
		killNpc(npc, meta or {})
	end

	return dealt
end

function NpcService.Register(model: Model, config: NpcConfig?): string?
	local existingNpc = NpcRegistry.GetByModel(model)
	if existingNpc then
		return existingNpc.id
	end

	local root = resolveRoot(model)
	if not root then
		warn("[NpcService] Missing root part for NPC:", model:GetFullName())
		return nil
	end

	stripLegacyNpcScripts(model)
	ensureAnimationController(model)

	if model.PrimaryPart ~= root then
		model.PrimaryPart = root
	end

	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	repairDetachedVisualParts(model, root)

	local npcId = NpcRegistry.NextId()
	local mobType = tostring((config and config.mobType) or model.Name)
	local maxHealth = math.max(1, math.floor(tonumber(config and config.maxHealth) or 1))
	local speed = math.max(0, tonumber(config and config.speed) or 0)
	local movementProfile, navigationProfile = NpcNavigationConfig.Resolve(model, config)
	local movementMode = navigationProfile.Mode
	local movementSystem = navigationProfile.MovementSystem or "Legacy"
	local movementBehavior = navigationProfile.MovementBehavior or "GroundWalker"
	local combatBehavior = navigationProfile.CombatBehavior
	setAttributeIfChanged(model, "MovementProfile", movementProfile)
	setAttributeIfChanged(model, "MovementMode", movementMode)
	setAttributeIfChanged(model, "MovementSystem", movementSystem)
	setAttributeIfChanged(model, "MovementBehavior", movementBehavior)
	setAttributeIfChanged(model, "CombatBehavior", combatBehavior)
	setAttributeIfChanged(model, "CanFly", movementMode == "Flying")
	if config and typeof(config.groundOffset) == "number" then
		setAttributeIfChanged(model, "NpcGroundOffset", config.groundOffset)
	end
	local groundOffset = computeGroundOffset(model, root)
	local now = os.clock()
	local initialPosition, spawnSurfacePosition, spawnHoldUntil, spawnEmergeEnd, spawnEmergeDepth =
		beginSpawnEmergence(model, root, groundOffset, now)

	local npc: NpcRecord = {
		id = npcId,
		model = model,
		root = root,
		mobType = mobType,
		maxHealth = maxHealth,
		health = maxHealth,
		baseSpeed = speed,
		attackRange = math.max(0, tonumber(config and config.attackRange) or 0),
		attackCooldown = math.max(0.1, tonumber(config and config.attackCooldown) or 1),
		damage = math.max(0, math.floor(tonumber(config and config.damage) or 0)),
		isElite = config and config.isElite == true or false,
		isBoss = config and config.isBoss == true or false,
		isRanged = config and config.isRanged == true or false,
		movementSystem = movementSystem,
		movementBehavior = movementBehavior,
		combatBehavior = combatBehavior,
		movementProfile = movementProfile,
		movementMode = movementMode,
		navigationProfile = navigationProfile,
		navigation = nil,
		surfaceNormal = movementMode == "Surface" and Vector3.yAxis or nil,
		combatBehaviorState = nil,
		unreachableSince = nil,
		retargetBlockedPlayer = nil,
		retargetBlockedUntil = nil,
		lineOfSightTarget = nil,
		nextLineOfSightAt = 0,
		hasLineOfSight = false,
		despawnDelay = math.max(0.1, tonumber(config and config.despawnDelay) or 3),
		attackWindup = math.max(0.15, tonumber(config and config.attackWindup) or 0.35),
		state = STATE.Spawn,
		dead = false,
		spawnTime = now,
		attackUntil = 0,
		nextAttackAt = 0,
		targetPlayer = nil,
		nextTargetScanAt = 0,
		position = initialPosition,
		look = Vector3.new(0, 0, -1),
		velocity = Vector3.zero,
		impulse = Vector3.zero,
		damageTakenMult = 1,
		damageTakenEnd = 0,
		slowPct = 0,
		slowEnd = 0,
		freezeEnd = 0,
		spawnSurfacePosition = spawnSurfacePosition,
		spawnUndergroundPosition = spawnSurfacePosition and initialPosition or nil,
		spawnHoldUntil = spawnHoldUntil,
		spawnEmergeEnd = spawnEmergeEnd,
		spawnEmergeDepth = spawnEmergeDepth,
		aiLockUntil = 0,
		aiLookTarget = nil,
		groundOffset = groundOffset,
		lastGroundAt = 0,
		lastGroundXZ = Vector3.new(initialPosition.X, 0, initialPosition.Z),
		orbitSign = math.random() < 0.5 and -1 or 1,
		orbitRadius = 0.8 + math.random() * 1.35,
		targetGroundY = nil,
		runtimeAttrsCleared = false,
		deathCallbacks = {},
	}

	if config and config.onDeath then
		table.insert(npc.deathCallbacks, config.onDeath)
	end

	NpcRegistry.Add(npc)

	setAttributeIfChanged(model, ATTR.Id, npc.id)
	setAttributeIfChanged(model, ATTR.Type, mobType)
	setAttributeIfChanged(model, ATTR.MobType, mobType)
	setAttributeIfChanged(model, ATTR.Speed, npc.baseSpeed)
	setAttributeIfChanged(model, ATTR.IsElite, npc.isElite)
	setAttributeIfChanged(model, ATTR.IsBoss, npc.isBoss)
	setAttributeIfChanged(model, ATTR.IsRanged, npc.isRanged)
	setAttributeIfChanged(model, "MovementProfile", npc.movementProfile)
	setAttributeIfChanged(model, "MovementMode", npc.movementMode)
	setAttributeIfChanged(model, "MovementSystem", npc.movementSystem)
	setAttributeIfChanged(model, "MovementBehavior", npc.movementBehavior)
	setAttributeIfChanged(model, "CombatBehavior", npc.combatBehavior)
	setAttributeIfChanged(model, "CanFly", npc.movementMode == "Flying")
	setAttributeIfChanged(model, ATTR.Damage, npc.damage)
	setAttributeIfChanged(model, ATTR.AttackRange, npc.attackRange)
	setAttributeIfChanged(model, ATTR.AttackCooldown, npc.attackCooldown)
	clearRuntimeAttributes(model)

	writeHealthAttributes(npc)
	writeStateAttributes(npc)
	return npc.id
end

function NpcService.SetIncomingDamageModifier(target: any, multiplier: number, duration: number)
	local npc = resolveNpc(target)
	if not npc or npc.dead then
		return
	end

	NpcLifecycle.SetIncomingDamageModifier(npc, multiplier, duration)
end

function NpcService.LockForAbility(target: any, duration: number, faceTarget: Vector3?)
	local npc = resolveNpc(target)
	if not npc or npc.dead then
		return
	end

	NpcLifecycle.LockForAbility(npc, duration, faceTarget)
end

function NpcService.SetPosition(target: any, pos: Vector3, lookDir: Vector3?)
	local npc = resolveNpc(target)
	if not npc or npc.dead or typeof(pos) ~= "Vector3" then
		return
	end

	npc.position = pos
	if typeof(lookDir) == "Vector3" and lookDir.Magnitude > 1e-4 then
		npc.look = lookDir.Unit
	end
	npc.velocity = Vector3.zero
	NpcMovementSystemController.Invalidate(npc, "external_set_position")
	moveNpcModelToRoot(npc)
	writeStateAttributes(npc)
end

local navigationStartedAt = os.clock()
local movementTickCount = 0
local movementTickTotal = 0
local movementTickMax = 0

function NpcService.GetNavigationMetrics(): {[string]: any}
	local ground = NpcGroundNavigation.GetMetrics()
	local flight = NpcFlightNavigation.GetMetrics()
	local movementSystems = NpcMovementSystemController.GetMetrics()
	local combat = NpcMelee.GetMetrics()
	local combatBehaviors = NpcCombatBehaviorService.GetMetrics()
	local elapsed = math.max(0.001, os.clock() - navigationStartedAt)
	local castCount = ground.raycastCount
		+ ground.blockcastCount
		+ flight.spherecastCount
		+ flight.groundRaycastCount
		+ (movementSystems.surface.raycastCount or 0)
		+ combat.lineOfSightRaycasts
	return {
		movementHz = NpcNavigationConfig.Scheduler.MovementHz,
		targetingHz = NpcNavigationConfig.Scheduler.TargetingHz,
		formationHz = NpcNavigationConfig.Scheduler.FormationHz,
		movementTickCount = movementTickCount,
		averageMovementTickMs = movementTickCount > 0 and (movementTickTotal / movementTickCount) * 1000 or 0,
		maximumMovementTickMs = movementTickMax * 1000,
		raycastCount = castCount,
		raycastsPerSecond = castCount / elapsed,
		ground = ground,
		flight = flight,
		movementSystems = movementSystems,
		combat = combat,
		combatBehaviors = combatBehaviors,
	}
end

function NpcService.GetNavigationDebug(target: any): {[string]: any}?
	if not RunService:IsStudio() then
		return nil
	end
	local npc = resolveNpc(target)
	if not npc then
		return nil
	end
	local result = NpcMovementSystemController.GetDebug(npc)
	if result then
		result.metrics = NpcService.GetNavigationMetrics()
	end
	return result
end

function NpcService.SetNavigationDebugEnabled(enabled: boolean, npcId: string?): boolean
	return NpcNavigationDebug.SetEnabled(enabled, npcId)
end

function NpcService.Despawn(target: any)
	local npc = resolveNpc(target)
	if not npc then
		return
	end

	despawnNpcRecord(npc)
end

syncRequestEvent.OnServerEvent:Connect(function(player: Player, requestId: number?)
	sendBatchToPlayer(player, true, tonumber(requestId))
end)

local batchAccumulator = 0
local movementAccumulator = 1 / NpcNavigationConfig.Scheduler.MovementHz
local targetingAccumulator = 1 / NpcNavigationConfig.Scheduler.TargetingHz
local formationAccumulator = 1 / NpcNavigationConfig.Scheduler.FormationHz
local cachedAlivePlayers = {}
local cachedEngagementSlots = {}

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	targetingAccumulator += dt
	formationAccumulator += dt
	movementAccumulator += dt
	batchAccumulator += dt

	local targetingInterval = 1 / NpcNavigationConfig.Scheduler.TargetingHz
	if targetingAccumulator >= targetingInterval then
		targetingAccumulator %= targetingInterval
		cachedAlivePlayers = NpcTargeting.GetAlivePlayers()
		NpcTargeting.RefreshTargets(NpcRegistry.Pairs, cachedAlivePlayers, now)
	end

	local formationInterval = 1 / NpcNavigationConfig.Scheduler.FormationHz
	if formationAccumulator >= formationInterval then
		formationAccumulator %= formationInterval
		cachedEngagementSlots = NpcTargeting.BuildEngagementSlots(cachedAlivePlayers, NpcRegistry.Pairs)
		if NpcNavigationDebug.IsEnabled() then
			NpcNavigationDebug.Render(NpcRegistry.Pairs, function(npc)
				return NpcMovementSystemController.GetDebug(npc)
			end, NpcService.GetNavigationMetrics())
		end
	end

	local movementInterval = 1 / NpcNavigationConfig.Scheduler.MovementHz
	if movementAccumulator >= movementInterval then
		local movementDt = math.min(movementAccumulator, movementInterval * 2)
		movementAccumulator %= movementInterval
		NpcMovementSystemController.BeginTick(cachedAlivePlayers)
		NpcMovementSystemController.StepScheduler(now)
		local spatialGrid = NpcMovementSystemController.BuildSpatialGrid(NpcRegistry.Pairs)
		local tickStartedAt = os.clock()
		for _, npc in NpcRegistry.Pairs() do
			updateNpc(npc, movementDt, cachedAlivePlayers, now, cachedEngagementSlots, spatialGrid)
		end
		NpcMovementSystemController.StepScheduler(os.clock())
		local tickDuration = os.clock() - tickStartedAt
		movementTickCount += 1
		movementTickTotal += tickDuration
		movementTickMax = math.max(movementTickMax, tickDuration)
	end

	if batchAccumulator >= NpcShared.BatchRate then
		batchAccumulator %= NpcShared.BatchRate
		broadcastBatch()
	end
end)

return NpcService
