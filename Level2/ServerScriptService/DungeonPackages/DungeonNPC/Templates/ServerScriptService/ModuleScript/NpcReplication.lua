local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript")
local NpcShared = require(moduleFolder:WaitForChild("NpcShared"))
local MobConfig = require(script.Parent:WaitForChild("MobConfig"))

local NpcReplication = {}

local DEFAULT_LOOK = Vector3.new(0, 0, -1)
local MOTION_RECORDS_PER_PACKET = 14
local MOB_CONFIGS = MobConfig.Mobs or {}
local reliableStateById = {}
local motionDueByPlayer = {}
local cachedPrewarmPlan = nil
local metricsStartedAt = os.clock()
local metrics = {
	reliablePackets = 0,
	reliableRecords = 0,
	motionPackets = 0,
	motionRecords = 0,
}

local function unitDirection(value: any, fallback: Vector3?): Vector3
	if typeof(value) == "Vector3" and value.Magnitude > 1e-4 then
		return value.Unit
	end
	return fallback or DEFAULT_LOOK
end

local function getConfiguredFacingYaw(npc: any): number?
	local model = npc.model
	local modelYaw = model and model:GetAttribute("NpcFacingYawDegrees")
	if typeof(modelYaw) == "number" and math.abs(modelYaw) > 1e-4 then
		return modelYaw
	end
	local config = MOB_CONFIGS[tostring(npc.mobType or "")]
	return config and tonumber(config.facingYawDegrees) or nil
end

local function animationDescriptor(mobType: string)
	local config = MOB_CONFIGS[mobType] or {}
	return {
		idle = config.idleAnimationId,
		run = config.runAnimationId,
		attack = config.attackAnimationId,
		death = config.deathAnimationId,
	}
end

local function visualDescriptor(npc: any)
	local model = npc.model
	return {
		type = tostring(npc.mobType or "Enemy"),
		rank = tostring(npc.enemyRank or "Normal"),
		displayName = npc.displayName or (model and model:GetAttribute("DisplayName")) or npc.mobType,
		isElite = npc.isElite == true,
		isMiniBoss = npc.isMiniBoss == true,
		isBoss = npc.isBoss == true,
		visualScale = model and model:GetAttribute("NpcVisualScale") or 1,
		facingYawDegrees = getConfiguredFacingYaw(npc),
		animationIds = animationDescriptor(tostring(npc.mobType or "")),
	}
end

local function buildReliable(npc: any, includeVisual: boolean)
	local item = {
		id = npc.id,
		type = npc.mobType,
		rank = npc.enemyRank,
		displayName = npc.displayName or npc.mobType,
		isElite = npc.isElite == true,
		isMiniBoss = npc.isMiniBoss == true,
		isBoss = npc.isBoss == true,
		speed = npc.baseSpeed,
		state = npc.state,
		hp = npc.health,
		maxHp = npc.maxHealth,
		dead = npc.dead,
		despawned = false,
		movementMode = npc.movementMode,
		movementProfile = npc.movementProfile,
		movementSystem = npc.movementSystem,
		movementBehavior = npc.movementBehavior,
		combatBehavior = npc.combatBehavior,
	}
	if includeVisual then
		item.spawn = true
		item.visual = visualDescriptor(npc)
	end
	return item
end

local function reliableSignature(npc: any): string
	return table.concat({
		tostring(npc.state), tostring(npc.health), tostring(npc.maxHealth),
		npc.dead and "1" or "0",
	}, "|")
end

local function buildMotion(npc: any)
	return {
		npc.id,
		npc.position,
		unitDirection(npc.look),
		npc.velocity,
		typeof(npc.surfaceNormal) == "Vector3" and unitDirection(npc.surfaceNormal, Vector3.yAxis) or false,
		typeof(npc.spawnSurfacePosition) == "Vector3" and npc.spawnSurfacePosition or false,
		typeof(npc.spawnSurfacePosition) == "Vector3" and npc.spawnEmergeDepth or false,
	}
end

local function fireMotionPackets(motionEvent, player: Player, serverTime: number, items, full: boolean?)
	for first = 1, #items, MOTION_RECORDS_PER_PACKET do
		local chunk = {}
		for index = first, math.min(#items, first + MOTION_RECORDS_PER_PACKET - 1) do
			table.insert(chunk, items[index])
		end
		motionEvent:FireClient(player, {
			protocol = NpcShared.ProtocolVersion,
			serverTime = serverTime,
			full = full == true,
			items = chunk,
		})
		metrics.motionPackets += 1
	end
	metrics.motionRecords += #items
end

local function addPlanEntry(plan, rank: string, mobType: string, count: number)
	if count <= 0 then
		return
	end
	table.insert(plan, {
		rank = rank,
		type = mobType,
		count = count,
		isElite = rank == "Elite",
		isMiniBoss = rank == "MiniBoss",
		isBoss = rank == "Boss",
		facingYawDegrees = MOB_CONFIGS[mobType] and MOB_CONFIGS[mobType].facingYawDegrees,
		animationIds = animationDescriptor(mobType),
	})
end

local function buildPrewarmPlan()
	if cachedPrewarmPlan then
		return cachedPrewarmPlan
	end
	local normalTypes = {}
	local seen = {}
	local maximumPoolWeight = {}
	local levelFolder = ServerStorage:FindFirstChild("DungeonLevel")
	local configModule = levelFolder and levelFolder:FindFirstChild("LevelConfig")
	local ok, levelConfig = pcall(function()
		return configModule and require(configModule)
	end)
	if ok and typeof(levelConfig) == "table" then
		for _, band in ipairs(levelConfig.Enemies and levelConfig.Enemies.Pools or {}) do
			for _, entry in ipairs(band.entries or {}) do
				local mobType = tostring(entry[1])
				maximumPoolWeight[mobType] = math.max(maximumPoolWeight[mobType] or 0, tonumber(entry[2]) or 0)
				if not seen[mobType] then
					seen[mobType] = true
					table.insert(normalTypes, mobType)
				end
			end
		end
	end
	if #normalTypes == 0 then
		for mobType in pairs(MOB_CONFIGS) do
			table.insert(normalTypes, mobType)
		end
		table.sort(normalTypes)
	end

	local plan = {}
	local normalCapacity = math.max(1, NpcShared.PoolTargetCapacity - 8)
	local totalWeight = 0
	for _, mobType in ipairs(normalTypes) do
		totalWeight += math.sqrt(math.max(1, maximumPoolWeight[mobType] or 1))
	end
	local remaining = normalCapacity
	for index, mobType in ipairs(normalTypes) do
		local typesLeft = #normalTypes - index
		local count = index == #normalTypes and remaining
			or math.max(1, math.floor(normalCapacity * math.sqrt(math.max(1, maximumPoolWeight[mobType] or 1)) / totalWeight + 0.5))
		count = math.min(count, math.max(1, remaining - typesLeft))
		addPlanEntry(plan, "Normal", mobType, count)
		remaining -= count
	end
	addPlanEntry(plan, "Elite", "Grzyb", 3)
	addPlanEntry(plan, "MiniBoss", "Ent", 2)
	addPlanEntry(plan, "MiniBoss", "Golem", 1)
	addPlanEntry(plan, "Boss", "Golem", 2)
	cachedPrewarmPlan = plan
	return plan
end

function NpcReplication.SendFullToPlayer(reliableEvent, motionEvent, player: Player, requestId: number?, npcPairs: () -> ())
	if not player or player.Parent ~= Players then
		return
	end
	local reliableItems = {}
	local motionItems = {}
	for _, npc in npcPairs() do
		table.insert(reliableItems, buildReliable(npc, true))
		table.insert(motionItems, buildMotion(npc))
	end
	local serverTime = workspace:GetServerTimeNow()
	reliableEvent:FireClient(player, {
		protocol = NpcShared.ProtocolVersion,
		serverTime = serverTime,
		full = true,
		requestId = requestId,
		prewarmPlan = buildPrewarmPlan(),
		items = reliableItems,
	})
	fireMotionPackets(motionEvent, player, serverTime, motionItems, true)
	metrics.reliablePackets += 1
	metrics.reliableRecords += #reliableItems
end

function NpcReplication.BroadcastReliable(reliableEvent, npcPairs: () -> (), tombstones: () -> (), clearTombstones: () -> ())
	debug.profilebegin("NpcReplication.Reliable")
	local items = {}
	local activeIds = {}
	for _, npc in npcPairs() do
		activeIds[npc.id] = true
		local signature = reliableSignature(npc)
		local previous = reliableStateById[npc.id]
		if signature ~= previous then
			table.insert(items, buildReliable(npc, previous == nil))
			reliableStateById[npc.id] = signature
		end
	end
	for _, tombstone in tombstones() do
		table.insert(items, tombstone)
		reliableStateById[tombstone.id] = nil
	end
	clearTombstones()
	for npcId in pairs(reliableStateById) do
		if not activeIds[npcId] then
			reliableStateById[npcId] = nil
		end
	end
	if #items > 0 then
		reliableEvent:FireAllClients({
			protocol = NpcShared.ProtocolVersion,
			serverTime = workspace:GetServerTimeNow(),
			items = items,
		})
		metrics.reliablePackets += 1
		metrics.reliableRecords += #items
	end
	debug.profileend()
end

local function getPlayerPosition(player: Player): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root.Position or nil
end

function NpcReplication.BroadcastMotion(motionEvent, npcPairs: () -> ())
	debug.profilebegin("NpcReplication.Motion")
	local now = workspace:GetServerTimeNow()
	for _, player in ipairs(Players:GetPlayers()) do
		local origin = getPlayerPosition(player)
		local dueById = motionDueByPlayer[player]
		if not dueById then
			dueById = {}
			motionDueByPlayer[player] = dueById
		end
		local items = {}
		local activeIds = {}
		for _, npc in npcPairs() do
			activeIds[npc.id] = true
			local distance = origin and (npc.position - origin).Magnitude or 0
			local important = npc.isBoss == true or npc.isMiniBoss == true or distance <= NpcShared.PresentationLod.CriticalDistance
			local hz = important and NpcShared.MotionLod.ImportantHz
				or (distance <= NpcShared.MotionLod.NearDistance and NpcShared.MotionLod.NearHz)
				or (distance <= NpcShared.MotionLod.MidDistance and NpcShared.MotionLod.MidHz)
				or NpcShared.MotionLod.FarHz
			if now >= (dueById[npc.id] or 0) then
				dueById[npc.id] = now + 1 / hz
				table.insert(items, buildMotion(npc))
			end
		end
		for npcId in pairs(dueById) do
			if not activeIds[npcId] then
				dueById[npcId] = nil
			end
		end
		if #items > 0 then
			fireMotionPackets(motionEvent, player, now, items, false)
		end
	end
	debug.profileend()
end

function NpcReplication.RemovePlayer(player: Player)
	motionDueByPlayer[player] = nil
end

function NpcReplication.GetMetrics()
	local elapsed = math.max(0.001, os.clock() - metricsStartedAt)
	local reliableTrackedIds = 0
	for _ in pairs(reliableStateById) do
		reliableTrackedIds += 1
	end
	local motionPlayers = 0
	local motionTrackedIds = 0
	for _, dueById in pairs(motionDueByPlayer) do
		motionPlayers += 1
		for _ in pairs(dueById) do
			motionTrackedIds += 1
		end
	end
	return {
		reliablePackets = metrics.reliablePackets,
		reliableRecords = metrics.reliableRecords,
		reliablePacketsPerSecond = metrics.reliablePackets / elapsed,
		motionPackets = metrics.motionPackets,
		motionRecords = metrics.motionRecords,
		motionPacketsPerSecond = metrics.motionPackets / elapsed,
		motionRecordsPerSecond = metrics.motionRecords / elapsed,
		reliableTrackedIds = reliableTrackedIds,
		motionPlayers = motionPlayers,
		motionTrackedIds = motionTrackedIds,
	}
end

return NpcReplication
