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
local npcMovementModule = serverModuleFolder:FindFirstChild("NpcMovement")
assert(npcMovementModule and npcMovementModule:IsA("ModuleScript"), "[NpcService] NpcMovement ModuleScript is required")
local NpcMovement = require(npcMovementModule)
local damageServiceModule = serverModuleFolder:FindFirstChild("DamageService")
assert(damageServiceModule and damageServiceModule:IsA("ModuleScript"), "[NpcService] DamageService ModuleScript is required for player damage")
local DamageService = require(damageServiceModule)
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

local NPC_FORMATION_LANE_ORDER = { 0, -1, 1, -2, 2, -3, 3 }
local NPC_FORMATION_LANE_COUNT = #NPC_FORMATION_LANE_ORDER
local NPC_FORMATION_LANE_SPACING = 1.85
local NPC_FORMATION_RING_SPACING = 0.95
local NPC_FORMATION_JITTER_SCALE = 0.22
local NPC_FORMATION_COLLAPSE_BUFFER = 2.75
local NPC_FORMATION_BLEND_DISTANCE = 7.5
local TARGET_PRIORITY_ELITE_DISTANCE_BONUS = 12
local TARGET_PRIORITY_BOSS_DISTANCE_BONUS = 24
local NORMAL_DESPAWN_DISTANCE = 100
local ENEMY_MELEE_MAX_VERTICAL_DELTA = 5
local ENEMY_MELEE_MAX_HIT_HEIGHT_ABOVE_ENEMY = 4.5
local ENEMY_MELEE_USE_3D_DISTANCE = true
local ENEMY_MELEE_DEBUG = false
local NPC_FORMATION_MOVEMENT_CONFIG = {
	laneSpacing = NPC_FORMATION_LANE_SPACING,
	ringSpacing = NPC_FORMATION_RING_SPACING,
	jitterScale = NPC_FORMATION_JITTER_SCALE,
}
local clampMagnitude = NpcMovement.ClampMagnitude
local flat = NpcMovement.Flat
local flatMagnitude = NpcMovement.FlatMagnitude
local nearestAlivePlayerFlatDistance = NpcMovement.NearestAlivePlayerFlatDistance
local safeUnit = NpcMovement.SafeUnit
local repairDetachedVisualParts = NpcMovement.RepairDetachedVisualParts
local computeGroundOffset = NpcMovement.ComputeGroundOffset
local beginSpawnEmergence = NpcMovement.BeginSpawnEmergence
local moveNpcModelToRoot = NpcMovement.MoveModelToRoot
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

local function setAttributeIfChanged(inst: Instance, name: string, value: any)
	if inst:GetAttribute(name) ~= value then
		inst:SetAttribute(name, value)
	end
end

local function clearRuntimeAttributes(model: Model)
	for _, name in ipairs(RUNTIME_ATTRIBUTE_NAMES) do
		if model:GetAttribute(name) ~= nil then
			model:SetAttribute(name, nil)
		end
	end
end

local function ensureRuntimeAttributesCleared(npc: NpcRecord)
	if npc.runtimeAttrsCleared then
		return
	end
	clearRuntimeAttributes(npc.model)
	npc.runtimeAttrsCleared = true
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

local function getAlivePlayers(): {AlivePlayerInfo}
	local result = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("RunEnded") ~= true then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hrp:IsA("BasePart") and hum.Health > 0 then
				table.insert(result, {
					player = plr,
					hrp = hrp,
					humanoid = hum,
				})
			end
		end
	end
	return result
end

local function buildEngagementSlots(alivePlayers: {AlivePlayerInfo}): {[string]: NpcEngagementSlot}
	local slots = {}
	if #alivePlayers == 0 then
		return slots
	end

	local groups = {}
	for _, npc in NpcRegistry.Pairs() do
		if not npc.dead and npc.model.Parent then
			local bestInfo = nil
			local bestDist = math.huge
			for _, info in ipairs(alivePlayers) do
				local dist = flatMagnitude(info.hrp.Position, npc.position)
				if dist < bestDist then
					bestDist = dist
					bestInfo = info
				end
			end

			if bestInfo then
				local key = tostring(bestInfo.player.UserId)
				local bucket = groups[key]
				if not bucket then
					bucket = {
						npcs = {},
						playerPos = bestInfo.hrp.Position,
					}
					groups[key] = bucket
				else
					bucket.playerPos = bestInfo.hrp.Position
				end
				bucket.npcs[#bucket.npcs + 1] = npc
			end
		end
	end

	for _, group in pairs(groups) do
		local playerPos = group.playerPos
		local centroid = Vector3.zero
		for _, npc in ipairs(group.npcs) do
			centroid += npc.position
		end
		if #group.npcs > 0 then
			centroid /= #group.npcs
		else
			centroid = playerPos
		end
		local approachDir = safeUnit(flat(centroid - playerPos), Vector3.new(0, 0, -1))
		table.sort(group.npcs, function(a, b)
			local distA = flatMagnitude(playerPos, a.position)
			local distB = flatMagnitude(playerPos, b.position)
			if math.abs(distA - distB) > 0.1 then
				return distA < distB
			end
			return a.spawnTime < b.spawnTime
		end)

		for index, npc in ipairs(group.npcs) do
			local slotIndex = index - 1
			slots[npc.id] = {
				lane = NPC_FORMATION_LANE_ORDER[(slotIndex % NPC_FORMATION_LANE_COUNT) + 1] or 0,
				depth = math.floor(slotIndex / NPC_FORMATION_LANE_COUNT),
				approachDir = approachDir,
			}
		end
	end

	return slots
end

local function writeStateAttributes(npc: NpcRecord)
	ensureRuntimeAttributesCleared(npc)
end

local function writeHealthAttributes(npc: NpcRecord)
	ensureRuntimeAttributesCleared(npc)
end

local function setState(npc: NpcRecord, newState: string)
	if npc.state == newState then
		return
	end

	npc.state = newState
	writeStateAttributes(npc)
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

local function isNpcTargetable(npc: NpcRecord): boolean
	return not npc.dead and npc.model.Parent ~= nil and typeof(npc.spawnSurfacePosition) ~= "Vector3"
end

local function getTargetPriority(npc: NpcRecord): number
	if npc.isBoss then
		return 3
	end
	if npc.isElite then
		return 2
	end
	return 1
end

local function getTargetPriorityDistanceBonus(npc: NpcRecord): number
	if npc.isBoss then
		return TARGET_PRIORITY_BOSS_DISTANCE_BONUS
	end
	if npc.isElite then
		return TARGET_PRIORITY_ELITE_DISTANCE_BONUS
	end
	return 0
end

local function computeTargetingMetrics(npc: NpcRecord, fromPos: Vector3): (number, number, number)
	local actualDistance = (npc.position - fromPos).Magnitude
	local effectiveDistance = math.max(0, actualDistance - getTargetPriorityDistanceBonus(npc))
	return effectiveDistance, actualDistance, getTargetPriority(npc)
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

local function queueTombstone(npc: NpcRecord, despawned: boolean)
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

local function unregisterNpc(npc: NpcRecord, despawned: boolean?)
	if not NpcRegistry.Contains(npc) then
		return
	end

	NpcRegistry.Remove(npc)
	queueTombstone(npc, despawned == true)
end

local function destroyNpcNow(npc: NpcRecord, despawned: boolean)
	unregisterNpc(npc, despawned)
	if npc.model.Parent then
		npc.model:Destroy()
	end
end

local function killNpc(npc: NpcRecord, context: {[string]: any}?)
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
	setState(npc, STATE.Dead)
	writeHealthAttributes(npc)
	deathContext.position = npc.position
	deathContext.model = npc.model
	deathContext.npcId = npc.id

	for _, callback in ipairs(npc.deathCallbacks) do
		pcall(callback, npc, deathContext)
	end

	destroyNpcNow(npc, true)
end

local function despawnNpcRecord(npc: NpcRecord)
	if not npc.dead then
		npc.dead = true
		npc.health = 0
		npc.velocity = Vector3.zero
		npc.impulse = Vector3.zero
		npc.attackUntil = 0
		setState(npc, STATE.Despawned)
		writeHealthAttributes(npc)
	end

	destroyNpcNow(npc, true)
end

local function shouldDistanceDespawn(npc: NpcRecord, alivePlayers: {AlivePlayerInfo}): boolean
	if npc.isElite or npc.isBoss or #alivePlayers == 0 then
		return false
	end
	return nearestAlivePlayerFlatDistance(npc.position, alivePlayers) > NORMAL_DESPAWN_DISTANCE
end

local function applyPlayerDamage(player: Player, amount: number, sourceModel: Model?)
	if amount <= 0 then
		return
	end

	DamageService.Apply(player, amount, {
		source = sourceModel,
		sourceType = "npc",
		damageType = "contact",
		attacker = sourceModel,
	})
end

local function getNpcBooleanAttribute(model: Model, attributeName: string, fallback: boolean): boolean
	local value = model:GetAttribute(attributeName)
	if typeof(value) == "boolean" then
		return value
	end
	return fallback
end

local function getNpcNumberAttribute(model: Model, attributeName: string, fallback: number): number
	local value = model:GetAttribute(attributeName)
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function debugMeleeSkip(npc: NpcRecord, targetInfo: AlivePlayerInfo, reason: string, detail: string)
	if ENEMY_MELEE_DEBUG ~= true then
		return
	end

	print(string.format(
		"[NpcService] Skip melee hit %s -> %s: %s (%s)",
		npc.model.Name,
		targetInfo.player.Name,
		reason,
		detail
		))
end

local function canApplyMeleeDamage(npc: NpcRecord, targetInfo: AlivePlayerInfo): boolean
	if npc.isRanged then
		return true
	end

	local targetRoot = targetInfo.hrp
	local npcRoot = npc.root
	if not targetRoot.Parent then
		debugMeleeSkip(npc, targetInfo, "missing_target_root", "HumanoidRootPart is no longer parented")
		return false
	end
	if not npcRoot.Parent then
		debugMeleeSkip(npc, targetInfo, "missing_npc_root", "NPC root is no longer parented")
		return false
	end

	local targetPos = targetRoot.Position
	local npcPos = npc.position
	local verticalDelta = targetPos.Y - npcPos.Y
	local verticalDeltaAbs = math.abs(verticalDelta)
	local maxVerticalDelta = math.max(0, getNpcNumberAttribute(npc.model, "EnemyMeleeMaxVerticalDelta", ENEMY_MELEE_MAX_VERTICAL_DELTA))
	local maxHitHeightAboveEnemy = math.max(0, getNpcNumberAttribute(npc.model, "EnemyMeleeMaxHitHeightAboveEnemy", ENEMY_MELEE_MAX_HIT_HEIGHT_ABOVE_ENEMY))
	local ignoreVerticalValidation = getNpcBooleanAttribute(npc.model, "EnemyMeleeIgnoreVerticalValidation", false)

	if not ignoreVerticalValidation and verticalDelta > maxHitHeightAboveEnemy then
		debugMeleeSkip(npc, targetInfo, "target_above_enemy", string.format("verticalDelta=%.2f limit=%.2f", verticalDelta, maxHitHeightAboveEnemy))
		return false
	end

	if not ignoreVerticalValidation and verticalDeltaAbs > maxVerticalDelta then
		debugMeleeSkip(npc, targetInfo, "vertical_delta", string.format("absDelta=%.2f limit=%.2f", verticalDeltaAbs, maxVerticalDelta))
		return false
	end

	if getNpcBooleanAttribute(npc.model, "EnemyMeleeUse3DDistance", ENEMY_MELEE_USE_3D_DISTANCE) then
		local max3DDistance = math.sqrt((npc.attackRange * npc.attackRange) + (maxVerticalDelta * maxVerticalDelta))
		local fullDistance = (targetPos - npcPos).Magnitude
		if fullDistance > max3DDistance then
			debugMeleeSkip(npc, targetInfo, "3d_distance", string.format("distance=%.2f limit=%.2f", fullDistance, max3DDistance))
			return false
		end
	end

	return true
end

local function findNearestTarget(npc: NpcRecord, alivePlayers: {AlivePlayerInfo}, now: number): AlivePlayerInfo?
	local targetPlayer = npc.targetPlayer
	if targetPlayer then
		for _, info in ipairs(alivePlayers) do
			if info.player == targetPlayer then
				return info
			end
		end
	end

	if now < npc.nextTargetScanAt then
		return nil
	end
	npc.nextTargetScanAt = now + 0.35

	local bestInfo = nil
	local bestDist = math.huge
	for _, info in ipairs(alivePlayers) do
		local dist = flatMagnitude(info.hrp.Position, npc.position)
		if dist < bestDist then
			bestDist = dist
			bestInfo = info
		end
	end

	npc.targetPlayer = bestInfo and bestInfo.player or nil
	return bestInfo
end

local function getCurrentSpeed(npc: NpcRecord, now: number): number
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

local function getControlResistance(npc: NpcRecord)
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

local function computeFormationWeight(dist: number, stopDistance: number): number
	local collapseDistance = stopDistance + NPC_FORMATION_COLLAPSE_BUFFER
	if dist <= collapseDistance then
		return 0
	end
	return math.clamp((dist - collapseDistance) / NPC_FORMATION_BLEND_DISTANCE, 0, 1)
end

local function updateNpc(
	npc: NpcRecord,
	dt: number,
	alivePlayers: {AlivePlayerInfo},
	now: number,
	engagementSlots: {[string]: NpcEngagementSlot}
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
			npc.look = safeUnit(flat(npc.aiLookTarget - npc.position), npc.look)
		end
		setState(npc, STATE.Attacking)
		writeStateAttributes(npc)
		return
	end
	npc.aiLookTarget = nil

	local targetInfo = findNearestTarget(npc, alivePlayers, now)
	if not targetInfo then
		npc.velocity = Vector3.zero
		setState(npc, STATE.Idle)
		writeStateAttributes(npc)
		return
	end

	local targetPos = targetInfo.hrp.Position
	local toTarget = flat(targetPos - npc.position)
	local dist = toTarget.Magnitude
	local stopDistance = math.max(1.25, npc.attackRange - 0.2)
	local formationWeight = computeFormationWeight(dist, stopDistance)
	local baseMove = Vector3.zero

	if npc.attackUntil > now then
		npc.velocity = Vector3.zero
		npc.look = safeUnit(toTarget, npc.look)
		setState(npc, STATE.Attacking)
	elseif dist <= npc.attackRange then
		npc.look = safeUnit(toTarget, npc.look)
		npc.velocity = Vector3.zero
		if now >= npc.nextAttackAt then
			npc.nextAttackAt = now + npc.attackCooldown
			npc.attackUntil = now + npc.attackWindup
			setState(npc, STATE.Attacking)
			if canApplyMeleeDamage(npc, targetInfo) then
				applyPlayerDamage(targetInfo.player, npc.damage, npc.model)
			end
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
		if speed > 0 and desiredMove.Magnitude > 0.05 then
			baseMove = clampMagnitude(desiredMove, speed * dt)
			baseMove = NpcMovement.SteerAroundObstacles(npc, baseMove, targetPos)
			if baseMove.Magnitude > 0.05 then
				npc.look = safeUnit(baseMove, safeUnit(toTarget, npc.look))
				setState(npc, STATE.Chasing)
			else
				npc.look = safeUnit(toTarget, npc.look)
				setState(npc, STATE.Idle)
			end
		else
			npc.look = safeUnit(toTarget, npc.look)
			setState(npc, STATE.Idle)
		end
	end


	local impulseMove = flat(npc.impulse) * dt
	local nextPos = npc.position + baseMove + impulseMove
	nextPos = NpcMovement.GroundAdjustedPosition(npc, nextPos, now, dt)

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

local function buildSnapshot(npc: NpcRecord)
	local snapshot = {
		id = npc.id,
		model = npc.model,
		type = npc.mobType,
		pos = npc.position,
		dir = npc.look,
		vel = npc.velocity,
		speed = npc.baseSpeed,
		state = npc.state,
		hp = npc.health,
		maxHp = npc.maxHealth,
		dead = npc.dead,
		despawned = false,
	}
	if typeof(npc.spawnSurfacePosition) == "Vector3" then
		snapshot.spawnSurfacePos = npc.spawnSurfacePosition
		snapshot.spawnEmergeDepth = npc.spawnEmergeDepth
	end
	return snapshot
end

local function collectBatchItems(includeTombstones: boolean?)
	local items = {}
	for _, npc in NpcRegistry.Pairs() do
		table.insert(items, buildSnapshot(npc))
	end
	if includeTombstones == true then
		for _, tombstone in NpcRegistry.Tombstones() do
			table.insert(items, tombstone)
		end
	end
	return items
end

local function sendBatchToPlayer(player: Player, fullSnapshot: boolean?, requestId: number?)
	if not player or player.Parent ~= Players then
		return
	end

	local items = collectBatchItems(false)
	batchEvent:FireClient(player, {
		serverTime = workspace:GetServerTimeNow(),
		full = fullSnapshot == true,
		requestId = requestId,
		items = items,
	})
end

local function broadcastBatch()
	local items = collectBatchItems(true)
	NpcRegistry.ClearTombstones()

	if #items == 0 then
		return
	end

	batchEvent:FireAllClients({
		serverTime = workspace:GetServerTimeNow(),
		items = items,
	})
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
		if isNpcTargetable(npc) then
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
	local alivePlayers = getAlivePlayers()
	if #alivePlayers == 0 then
		return nil
	end

	local bestNpc = nil
	for _, npc in NpcRegistry.Pairs() do
		if not npc.dead and npc.model.Parent and not npc.isElite and npc.model:GetAttribute("IsBoss") ~= true then
			local nearestDist = math.huge
			for _, info in ipairs(alivePlayers) do
				nearestDist = math.min(nearestDist, flatMagnitude(info.hrp.Position, npc.position))
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
		if isNpcTargetable(npc) then
			local dist = (npc.position - fromPos).Magnitude
			if dist <= searchRange then
				local effectiveDist, actualDist, priority = computeTargetingMetrics(npc, fromPos)
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
		if isNpcTargetable(npc) then
			local dist = (npc.position - fromPos).Magnitude
			if dist <= radius then
				local effectiveDist, actualDist, priority = computeTargetingMetrics(npc, fromPos)
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
	if not npc or not isNpcTargetable(npc) then
		return nil, nil, nil
	end

	return computeTargetingMetrics(npc, fromPos)
end

function NpcService.ApplySlow(target: any, slowPct: number, duration: number)
	local npc = resolveNpc(target)
	if not npc or npc.dead then
		return
	end

	local resist = getControlResistance(npc)
	local now = os.clock()
	npc.slowPct = math.max(npc.slowPct, math.clamp((tonumber(slowPct) or 0) * resist.slowPct, 0, 0.95))
	npc.slowEnd = math.max(npc.slowEnd, now + math.max(0.05, (tonumber(duration) or 0) * resist.slowDuration))
end

function NpcService.ApplyFreeze(target: any, duration: number)
	local npc = resolveNpc(target)
	if not npc or npc.dead then
		return
	end

	local resist = getControlResistance(npc)
	local now = os.clock()
	npc.freezeEnd = math.max(npc.freezeEnd, now + math.max(0.08, (tonumber(duration) or 0) * resist.freezeDuration))
end

function NpcService.AddImpulse(target: any, impulse: Vector3)
	local npc = resolveNpc(target)
	if not npc or npc.dead or typeof(impulse) ~= "Vector3" then
		return
	end

	local flatImpulse = flat(impulse)
	if flatImpulse.Magnitude <= 1e-4 then
		return
	end

	local resist = getControlResistance(npc)
	npc.impulse = clampMagnitude(npc.impulse + (flatImpulse * resist.impulse), 90)
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

	npc.damageTakenMult = math.clamp(tonumber(multiplier) or 1, 0.10, 3)
	npc.damageTakenEnd = os.clock() + math.max(0.1, tonumber(duration) or 0)
end

function NpcService.LockForAbility(target: any, duration: number, faceTarget: Vector3?)
	local npc = resolveNpc(target)
	if not npc or npc.dead then
		return
	end

	npc.aiLockUntil = math.max(npc.aiLockUntil, os.clock() + math.max(0.05, tonumber(duration) or 0))
	npc.aiLookTarget = typeof(faceTarget) == "Vector3" and faceTarget or npc.aiLookTarget
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
	moveNpcModelToRoot(npc)
	writeStateAttributes(npc)
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

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local alivePlayers = getAlivePlayers()
	local engagementSlots = buildEngagementSlots(alivePlayers)

	for _, npc in NpcRegistry.Pairs() do
		updateNpc(npc, dt, alivePlayers, now, engagementSlots)
	end

	batchAccumulator += dt
	if batchAccumulator >= NpcShared.BatchRate then
		batchAccumulator = 0
		broadcastBatch()
	end
end)

return NpcService
