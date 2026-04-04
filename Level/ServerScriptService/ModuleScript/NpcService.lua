local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local WorldBounds = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("WorldBounds"))

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript")
local NpcShared = require(moduleFolder:WaitForChild("NpcShared"))
local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
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
	aiLockUntil: number,
	aiLookTarget: Vector3?,
	groundOffset: number,
	lastGroundAt: number,
	lastGroundXZ: Vector3,
	orbitSign: number,
	orbitRadius: number,
	deathCallbacks: {((any, {[string]: any}) -> ())},
}

local NpcService = {}

local nextNpcId = 0
local npcById: {[string]: NpcRecord} = {}
local npcByModel: {[Model]: NpcRecord} = {}
local tombstones = {}
local NPC_FORMATION_LANE_ORDER = { 0, -1, 1, -2, 2, -3, 3 }
local NPC_FORMATION_LANE_COUNT = #NPC_FORMATION_LANE_ORDER
local NPC_FORMATION_LANE_SPACING = 1.85
local NPC_FORMATION_RING_SPACING = 0.95
local NPC_FORMATION_JITTER_SCALE = 0.22
local NPC_FORMATION_COLLAPSE_BUFFER = 2.75
local NPC_FORMATION_BLEND_DISTANCE = 7.5

local function enemiesFolder(): Instance?
	return workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Mobs")
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

local function buildTerrainRaycastIgnore(model: Model): { Instance }
	local ignore = { model }
	local enemyRoot = enemiesFolder()
	if enemyRoot then
		table.insert(ignore, enemyRoot)
	end
	local drops = workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignore, drops)
	end
	local chests = workspace:FindFirstChild("Chests")
	if chests then
		table.insert(ignore, chests)
	end
	local shrines = workspace:FindFirstChild("Shrines")
	if shrines then
		table.insert(ignore, shrines)
	end
	local statues = workspace:FindFirstChild("Statues")
	if statues then
		table.insert(ignore, statues)
	end
	local spellVfx = workspace:FindFirstChild("SpellVFX")
	if spellVfx then
		table.insert(ignore, spellVfx)
	end
	local portal = workspace:FindFirstChild("RunPortal")
	if portal then
		table.insert(ignore, portal)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	return ignore
end

local function sampleGroundY(model: Model, pos: Vector3): number?
	local originY = math.max(96, pos.Y + 24)
	local result = WorldBounds.RaycastTerrainAtXZ(pos.X, pos.Z, {
		originY = originY,
		distance = originY + 128,
		ignoreWater = true,
		raycastIgnoreInstances = buildTerrainRaycastIgnore(model),
	})
	if result then
		return result.Position.Y
	end
	return nil
end

local function computeGroundOffset(model: Model, root: BasePart): number
	local lowestY = math.huge
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local partBottom = descendant.Position.Y - (descendant.Size.Y * 0.5)
			if partBottom < lowestY then
				lowestY = partBottom
			end
		end
	end

	if lowestY == math.huge then
		return math.max(0, root.Size.Y * 0.5)
	end

	return math.max(0, root.Position.Y - lowestY)
end

local function clampMagnitude(v: Vector3, maxMagnitude: number): Vector3
	local magnitude = v.Magnitude
	if magnitude <= maxMagnitude or magnitude <= 1e-6 then
		return v
	end
	return v.Unit * maxMagnitude
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatMagnitude(a: Vector3, b: Vector3): number
	local d = a - b
	return math.sqrt((d.X * d.X) + (d.Z * d.Z))
end

local function safeUnit(v: Vector3, fallback: Vector3?): Vector3
	if v.Magnitude <= 1e-6 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return v.Unit
end

local function rotateFlat(v: Vector3, angle: number): Vector3
	local cosAngle = math.cos(angle)
	local sinAngle = math.sin(angle)
	return Vector3.new(
		(v.X * cosAngle) - (v.Z * sinAngle),
		0,
		(v.X * sinAngle) + (v.Z * cosAngle)
	)
end

local function isBlockingObstacle(inst: Instance?): boolean
	return inst
		and inst:IsA("BasePart")
		and inst.CanCollide
		and inst.Transparency < 0.98
end

local function buildObstacleRaycastIgnore(model: Model): { Instance }
	local ignore = { model }
	local enemyRoot = enemiesFolder()
	if enemyRoot then
		table.insert(ignore, enemyRoot)
	end
	local drops = workspace:FindFirstChild("Drops")
	if drops then
		table.insert(ignore, drops)
	end
	local spellVfx = workspace:FindFirstChild("SpellVFX")
	if spellVfx then
		table.insert(ignore, spellVfx)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	local terrain = WorldBounds.GetTerrain()
	if terrain then
		table.insert(ignore, terrain)
	end
	return ignore
end

local function raycastObstacle(origin: Vector3, direction: Vector3, ignoreInstances: { Instance }?): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local ignore = {}
	for _, inst in ipairs(ignoreInstances or {}) do
		if typeof(inst) == "Instance" then
			table.insert(ignore, inst)
		end
	end

	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			return nil
		end
		if isBlockingObstacle(hit.Instance) then
			return hit
		end
		table.insert(ignore, hit.Instance)
	end

	return nil
end

local function getAlivePlayers(): {AlivePlayerInfo}
	local result = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("RunEnded") ~= true then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
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
	for _, npc in pairs(npcById) do
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
	local model = npc.model
	local state = npc.state
	local isDead = npc.dead
	local isAttacking = state == STATE.Attacking

	setAttributeIfChanged(model, ATTR.State, state)
	setAttributeIfChanged(model, ATTR.LegacyState, state)
	setAttributeIfChanged(model, ATTR.AiState, state)
	setAttributeIfChanged(model, ATTR.Dead, isDead)
	setAttributeIfChanged(model, ATTR.LegacyDead, isDead)
	setAttributeIfChanged(model, ATTR.LegacyAttacking, isAttacking)
	setAttributeIfChanged(model, ATTR.Alive, not isDead)
	setAttributeIfChanged(model, ATTR.Direction, npc.look)
	setAttributeIfChanged(model, ATTR.Velocity, npc.velocity)
end

local function writeHealthAttributes(npc: NpcRecord)
	local model = npc.model
	setAttributeIfChanged(model, ATTR.Health, npc.health)
	setAttributeIfChanged(model, ATTR.LegacyHealth, npc.health)
	setAttributeIfChanged(model, ATTR.MaxHealth, npc.maxHealth)
	setAttributeIfChanged(model, ATTR.LegacyMaxHealth, npc.maxHealth)
end

local function setState(npc: NpcRecord, newState: string)
	if npc.state == newState then
		return
	end
	
	npc.state = newState
	writeStateAttributes(npc)
end

local function resolveNpc(target: any): NpcRecord?
	if typeof(target) ~= "Instance" then
		return nil
	end

	if target:IsA("Model") then
		return npcByModel[target]
	end

	local model = target:FindFirstAncestorOfClass("Model")
	if model then
		return npcByModel[model]
	end

	return nil
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

local function queueTombstone(npc: NpcRecord, despawned: boolean)
	table.insert(tombstones, {
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
	if npcById[npc.id] ~= npc then
		return
	end

	npcById[npc.id] = nil
	npcByModel[npc.model] = nil
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

local function applyPlayerDamage(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	if _G.ApplyDamageToPlayer then
		_G.ApplyDamageToPlayer(player, amount)
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum:TakeDamage(amount)
	end
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

local function groundAdjustedPosition(npc: NpcRecord, pos: Vector3, now: number): Vector3
	if now - npc.lastGroundAt >= 0.12 or flatMagnitude(pos, npc.lastGroundXZ) >= 4 then
		local groundY = sampleGroundY(npc.model, pos)
		if groundY ~= nil then
			npc.lastGroundAt = now
			npc.lastGroundXZ = Vector3.new(pos.X, 0, pos.Z)
			return Vector3.new(pos.X, groundY + npc.groundOffset, pos.Z)
		end
	end
	return Vector3.new(pos.X, npc.position.Y, pos.Z)
end

local function computeFormationWeight(dist: number, stopDistance: number): number
	local collapseDistance = stopDistance + NPC_FORMATION_COLLAPSE_BUFFER
	if dist <= collapseDistance then
		return 0
	end
	return math.clamp((dist - collapseDistance) / NPC_FORMATION_BLEND_DISTANCE, 0, 1)
end

local function computeOrbitTarget(
	npc: NpcRecord,
	targetPos: Vector3,
	stopDistance: number,
	slot: NpcEngagementSlot?,
	formationWeight: number?
): Vector3
	local weight = math.clamp(tonumber(formationWeight) or 1, 0, 1)
	local toNpc = flat(npc.position - targetPos)
	local baseDir = slot and slot.approachDir or safeUnit(toNpc, npc.look)
	local tangent = Vector3.new(-baseDir.Z, 0, baseDir.X)
	local lane = slot and slot.lane or 0
	local depth = slot and slot.depth or 0
	local laneOffset = tangent * (lane * NPC_FORMATION_LANE_SPACING * weight)
	local depthOffset = baseDir * (depth * NPC_FORMATION_RING_SPACING * weight)
	local jitterOffset = tangent * (npc.orbitSign * npc.orbitRadius * NPC_FORMATION_JITTER_SCALE * weight)
	return targetPos + (baseDir * stopDistance * weight) + depthOffset + laneOffset + jitterOffset
end

local function steerAroundObstacles(npc: NpcRecord, desiredMove: Vector3, targetPos: Vector3): Vector3
	local flatMove = flat(desiredMove)
	if flatMove.Magnitude <= 0.05 then
		return desiredMove
	end

	local desiredDir = safeUnit(flatMove, npc.look)
	local probeDistance = math.max(3.5, flatMove.Magnitude + 2.5)
	local probeOrigin = npc.position + Vector3.new(0, math.max(2.5, npc.groundOffset * 0.65), 0)
	local ignore = buildObstacleRaycastIgnore(npc.model)
	local forwardHit = raycastObstacle(probeOrigin, desiredDir * probeDistance, ignore)
	if not forwardHit then
		return desiredMove
	end

	local toTarget = safeUnit(flat(targetPos - npc.position), desiredDir)
	local bestDir = nil
	local bestScore = -math.huge
	for _, angle in ipairs({ math.rad(35), -math.rad(35), math.rad(70), -math.rad(70), math.rad(105), -math.rad(105) }) do
		local candidateDir = safeUnit(rotateFlat(desiredDir, angle), desiredDir)
		if not raycastObstacle(probeOrigin, candidateDir * probeDistance, ignore) then
			local score = (candidateDir:Dot(toTarget) * 1.2) + candidateDir:Dot(desiredDir)
			if score > bestScore then
				bestScore = score
				bestDir = candidateDir
			end
		end
	end

	if bestDir then
		return bestDir * flatMove.Magnitude
	end

	local obstacleNormal = flat(forwardHit.Normal)
	if obstacleNormal.Magnitude > 0.05 then
		local normalDir = obstacleNormal.Unit
		local slideDir = flat(desiredDir - (normalDir * desiredDir:Dot(normalDir)))
		if slideDir.Magnitude > 0.05 then
			slideDir = safeUnit(slideDir, desiredDir)
			if not raycastObstacle(probeOrigin, slideDir * probeDistance, ignore) then
				return slideDir * flatMove.Magnitude
			end
		end
	end

	return Vector3.zero
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

	if pauseState.Value then
		npc.velocity = Vector3.zero
		npc.impulse = Vector3.zero
		npc.attackUntil = 0
		npc.nextAttackAt = math.max(npc.nextAttackAt, now + 0.1)
		setState(npc, STATE.Idle)
		writeStateAttributes(npc)
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
			applyPlayerDamage(targetInfo.player, npc.damage)
		else
			setState(npc, STATE.Idle)
		end
	else
		local desiredPos = computeOrbitTarget(npc, targetPos, stopDistance, engagementSlots[npc.id], formationWeight)
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
			baseMove = steerAroundObstacles(npc, baseMove, targetPos)
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
	nextPos = groundAdjustedPosition(npc, nextPos, now)

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
	return {
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
end

local function collectBatchItems(includeTombstones: boolean?)
	local items = {}
	for _, npc in pairs(npcById) do
		table.insert(items, buildSnapshot(npc))
	end
	if includeTombstones == true then
		for _, tombstone in ipairs(tombstones) do
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
	table.clear(tombstones)

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
	for _, npc in pairs(npcById) do
		if not npc.dead and npc.model.Parent then
			table.insert(result, npc.model)
		end
	end
	return result
end

function NpcService.GetActiveCount(filter: ActiveCountFilter?): number
	local count = 0
	for _, npc in pairs(npcById) do
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
	for _, npc in pairs(npcById) do
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
	local bestModel = nil
	local bestDist = maxRange or math.huge
	for _, npc in pairs(npcById) do
		if not npc.dead and npc.model.Parent then
			local dist = (npc.position - fromPos).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestModel = npc.model
			end
		end
	end
	return bestModel, bestDist
end

function NpcService.GetEnemiesInRadius(fromPos: Vector3, radius: number): {Model}
	local hits = {}
	for _, npc in pairs(npcById) do
		if not npc.dead and npc.model.Parent and (npc.position - fromPos).Magnitude <= radius then
			table.insert(hits, npc.model)
		end
	end
	return hits
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
	pcall(function()
		npc.model:PivotTo(CFrame.lookAt(npc.position, npc.position + npc.look))
	end)
	writeStateAttributes(npc)
end

function NpcService.Register(model: Model, config: NpcConfig?): string?
	if npcByModel[model] then
		return npcByModel[model].id
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

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	nextNpcId += 1
	local npcId = tostring(nextNpcId)
	local mobType = tostring((config and config.mobType) or model.Name)
	local maxHealth = math.max(1, math.floor(tonumber(config and config.maxHealth) or 1))
	local speed = math.max(0, tonumber(config and config.speed) or 0)
	local groundOffset = computeGroundOffset(model, root)

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
		spawnTime = os.clock(),
		attackUntil = 0,
		nextAttackAt = 0,
		targetPlayer = nil,
		nextTargetScanAt = 0,
		position = root.Position,
		look = Vector3.new(0, 0, -1),
		velocity = Vector3.zero,
		impulse = Vector3.zero,
		damageTakenMult = 1,
		damageTakenEnd = 0,
		slowPct = 0,
		slowEnd = 0,
		freezeEnd = 0,
		aiLockUntil = 0,
		aiLookTarget = nil,
		groundOffset = groundOffset,
		lastGroundAt = 0,
		lastGroundXZ = Vector3.new(root.Position.X, 0, root.Position.Z),
		orbitSign = math.random() < 0.5 and -1 or 1,
		orbitRadius = 0.8 + math.random() * 1.35,
		deathCallbacks = {},
	}

	if config and config.onDeath then
		table.insert(npc.deathCallbacks, config.onDeath)
	end

	npcById[npcId] = npc
	npcByModel[model] = npc

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

	writeHealthAttributes(npc)
	writeStateAttributes(npc)
	return npc.id
end

function NpcService.Despawn(target: any)
	local npc = resolveNpc(target)
	if not npc then
		return
	end

	if not npc.dead then
		npc.dead = true
		npc.health = 0
		writeHealthAttributes(npc)
		setState(npc, STATE.Despawned)
	end

	destroyNpcNow(npc, true)
end

syncRequestEvent.OnServerEvent:Connect(function(player: Player, requestId: number?)
	sendBatchToPlayer(player, true, tonumber(requestId))
end)

local batchAccumulator = 0

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	local alivePlayers = getAlivePlayers()
	local engagementSlots = buildEngagementSlots(alivePlayers)

	for _, npc in pairs(npcById) do
		updateNpc(npc, dt, alivePlayers, now, engagementSlots)
	end

	batchAccumulator += dt
	if batchAccumulator >= NpcShared.BatchRate then
		batchAccumulator = 0
		broadcastBatch()
	end
end)

return NpcService


