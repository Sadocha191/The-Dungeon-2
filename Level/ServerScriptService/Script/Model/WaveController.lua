-- WaveController.server.lua (Level1)
-- Reworked: time-based horde spawning (VS / Mega Bonk style)
-- No waves. Difficulty ramps with elapsed run time.
-- Elites spawn on a recurring timer during the run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

-- Collision groups (prevent mob stacking/climbing on players and weapons)
local GROUP_PLAYERS = "Players"
local GROUP_MOBS = "Mobs"

local function ensureCollisionGroup(name: string)
	pcall(function() PhysicsService:RegisterCollisionGroup(name) end)
end

ensureCollisionGroup(GROUP_PLAYERS)
ensureCollisionGroup(GROUP_MOBS)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(GROUP_PLAYERS, GROUP_MOBS, false)
	PhysicsService:CollisionGroupSetCollidable(GROUP_MOBS, GROUP_MOBS, true) -- mobs can still bump each other if desired
end)

local function applyCollision(model: Instance, groupName: string, noCollide: boolean?)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.CollisionGroup = groupName
			if noCollide then
				inst.CanCollide = false
				inst.CanTouch = false
				inst.CanQuery = false
			end
		end
	end
	model.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") then
			inst.CollisionGroup = groupName
			if noCollide then
				inst.CanCollide = false
				inst.CanTouch = false
				inst.CanQuery = false
			end
		end
	end)
end

-- apply to player characters (so mobs/weapons never become "obstacles")
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		applyCollision(char, GROUP_PLAYERS, false)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			hrp.CanCollide = false
		end
	end)
end)

local ServerScriptService = game:GetService("ServerScriptService")

local serverModuleFolder = ServerScriptService:FindFirstChild("ModuleScript")
assert(serverModuleFolder and serverModuleFolder:IsA("Folder"), "[WaveController] ServerScriptService.ModuleScript folder is required")
local function requireServerModule(name: string)
	local module = serverModuleFolder:FindFirstChild(name)
	assert(module and module:IsA("ModuleScript"), "[WaveController] " .. name .. " ModuleScript is required")
	return require(module)
end
local AbilityExecutor = requireServerModule("AbilityExecutor")
local EncounterScheduler = requireServerModule("EncounterScheduler")
local RunPortalController = requireServerModule("RunPortalController")
local NpcService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("NpcService"))
local PlayerData = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PlayerData"))
local PickupToastService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PickupToastService"))
local RunSpawnConfig = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("RunSpawnConfig"))
local WorldBounds = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("WorldBounds"))
local CraftingConfig = require((ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript") or ReplicatedStorage:WaitForChild("ModuleScripts", 5) or ReplicatedStorage:WaitForChild("ModuleScript", 5)):WaitForChild("CraftingConfig"))

local MissionProgress = nil
pcall(function()
	MissionProgress = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("MissionProgress"))
end)

-- Shared pause flag (used by upgrade UI in single)
local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
local RunStarted = ReplicatedStorage:FindFirstChild("RunStarted")
if not RunStarted then
	RunStarted = Instance.new("BoolValue")
	RunStarted.Name = "RunStarted"
	RunStarted.Value = false
	RunStarted.Parent = ReplicatedStorage
end
if not PauseState then
    PauseState = Instance.new("BoolValue")
    PauseState.Name = "PauseState"
    PauseState.Value = false
    PauseState.Parent = ReplicatedStorage
end

-- Remotes layout (your project): ReplicatedStorage/Remotes/*
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "Remotes"
	RemotesFolder.Parent = ReplicatedStorage
end

-- Primary event (preferred)
local WaveStatusEvent = RemotesFolder:FindFirstChild("WaveStatusEvent")
if not WaveStatusEvent then
	WaveStatusEvent = Instance.new("RemoteEvent")
	WaveStatusEvent.Name = "WaveStatusEvent"
	WaveStatusEvent.Parent = RemotesFolder
end

local function broadcast(payload)
	for _, plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

-- Enemy templates
local EnemiesRoot = ReplicatedStorage:WaitForChild("Enemies")
local NormalFolder = EnemiesRoot:WaitForChild("Normal")
local EliteFolder = EnemiesRoot:WaitForChild("Elite")

local ENEMIES_FOLDER = workspace:FindFirstChild("Enemies")
if not ENEMIES_FOLDER then
    ENEMIES_FOLDER = Instance.new("Folder")
    ENEMIES_FOLDER.Name = "Enemies"
    ENEMIES_FOLDER.Parent = workspace
end

-- Collision group for mobs (no mob-mob collision)
local MOBS_GROUP = "Mobs"
pcall(function() PhysicsService:RegisterCollisionGroup(MOBS_GROUP) end)
PhysicsService:CollisionGroupSetCollidable(MOBS_GROUP, MOBS_GROUP, false)

-- Collision group for players (lets us disable player<->corpse collision without breaking ground collision)
local PLAYERS_GROUP = "Players"
pcall(function() PhysicsService:RegisterCollisionGroup(PLAYERS_GROUP) end)

-- Collision group for corpses (collides with world, not with players)
local CORPSES_GROUP = "Corpses"
pcall(function() PhysicsService:RegisterCollisionGroup(CORPSES_GROUP) end)

-- Rules:
-- - Mobs don't collide with each other
-- - Corpses don't collide with players
-- - Corpses don't collide with mobs (prevents corpse piles blocking mobs)
pcall(function()
    PhysicsService:CollisionGroupSetCollidable(MOBS_GROUP, PLAYERS_GROUP, false)
    PhysicsService:CollisionGroupSetCollidable(CORPSES_GROUP, PLAYERS_GROUP, false)
    PhysicsService:CollisionGroupSetCollidable(CORPSES_GROUP, MOBS_GROUP, false)
    PhysicsService:CollisionGroupSetCollidable(CORPSES_GROUP, CORPSES_GROUP, false)
end)

-- Assign all character parts to PLAYERS_GROUP
local function setPlayerGroup(char: Model)
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CollisionGroup = PLAYERS_GROUP
        end
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        pcall(function() setPlayerGroup(char) end)
    end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr.Character then
        pcall(function() setPlayerGroup(plr.Character) end)
    end
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        pcall(function() setPlayerGroup(char) end)
    end)
end

local function setMobGroup(model: Model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CollisionGroup = MOBS_GROUP
            -- hard prevent "climbing/stacking" on player by removing physical collision for mobs
            d.CanCollide = false
            d.CanTouch = false
            d.CanQuery = false
        end
    end

    -- also handle parts added after spawn (accessories / hitboxes / etc.)
    model.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") then
            inst.CollisionGroup = MOBS_GROUP
            inst.CanCollide = false
            inst.CanTouch = false
            inst.CanQuery = false
        end
    end)
end


-- Roblox-friendly spawn ring around nearest alive player
local SPAWN_RING_MIN = 60
local SPAWN_RING_MAX = 90
local SPAWN_RAY_START_Y = 200
local GROUND_RAY_DIST = 600
local MAX_SPAWN_TRIES = 25
local MAX_GROUND_SLOPE_DEG = 35
WorldBounds.SpawnGroundClearance = 0.05

local function anyPlayersAlive(): boolean
    for _, plr in ipairs(Players:GetPlayers()) do
        local c = plr.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 and plr:GetAttribute("RunEnded") ~= true then
            return true
        end
    end
    return false
end

local function getAliveHRPs(): {BasePart}
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local c = plr.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if h and hrp and h.Health > 0 and plr:GetAttribute("RunEnded") ~= true then
            table.insert(list, hrp)
        end
    end
    return list
end

local function buildSpawnRaycastIgnore(extraIgnore: {Instance}?)
	local blacklist = {
		ENEMIES_FOLDER,
		workspace:FindFirstChild("Drops"),
		workspace:FindFirstChild("Chests"),
		workspace:FindFirstChild("Shrines"),
		workspace:FindFirstChild("Statues"),
		workspace:FindFirstChild("RunPortal"),
		workspace:FindFirstChild("SpellVFX"),
		workspace:FindFirstChild("EnemyAbilityVFX"),
	}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(blacklist, plr.Character)
		end
	end
	if type(extraIgnore) == "table" then
		for _, inst in ipairs(extraIgnore) do
			if inst then
				table.insert(blacklist, inst)
			end
		end
	end
	return blacklist
end

local function buildSpawnOverlapIgnore(extraIgnore: {Instance}?)
	local ignore = {
		workspace:FindFirstChild("Drops"),
	}
	if type(extraIgnore) == "table" then
		for _, inst in ipairs(extraIgnore) do
			if inst then
				table.insert(ignore, inst)
			end
		end
	end
	return ignore
end

local function raycastGround(pos: Vector3, extraIgnore: {Instance}?)
	return WorldBounds.RaycastTerrainAtXZ(pos.X, pos.Z, {
		originY = SPAWN_RAY_START_Y,
		distance = GROUND_RAY_DIST,
		ignoreWater = true,
		raycastIgnoreInstances = buildSpawnRaycastIgnore(extraIgnore),
	})
end

local function slopeDeg(normal: Vector3): number
    local up = Vector3.new(0, 1, 0)
    local dot = math.clamp(normal:Dot(up), -1, 1)
    return math.deg(math.acos(dot))
end

function WorldBounds.CFrameRotationOnly(cframe: CFrame): CFrame
	return cframe - cframe.Position
end

function WorldBounds.BuildMobGrounding(mob: Model?, spawnConfig)
	local grounding = {
		groundSnapDisabled = false,
		flightAltitude = 0,
		root = nil,
		rootLocalCFrame = nil,
		rootGroundOffset = 0,
	}

	if not mob then
		return grounding
	end

	local configuredFlight = type(spawnConfig) == "table"
		and (spawnConfig.canFly == true
			or spawnConfig.movementMode == "Flying"
			or spawnConfig.movementProfile == "Flying")
	grounding.groundSnapDisabled = mob:GetAttribute("IgnoreGroundSnap") == true
		or mob:GetAttribute("CanFly") == true
		or configuredFlight
	if configuredFlight or mob:GetAttribute("CanFly") == true then
		grounding.flightAltitude = math.max(0, tonumber(type(spawnConfig) == "table" and spawnConfig.preferredFlightAltitude) or 14)
	end
	if grounding.groundSnapDisabled then
		return grounding
	end

	local foundRoot = mob:FindFirstChild("HumanoidRootPart")
	if foundRoot and foundRoot:IsA("BasePart") then
		grounding.root = foundRoot
	elseif mob.PrimaryPart and mob.PrimaryPart:IsA("BasePart") then
		grounding.root = mob.PrimaryPart
	else
		grounding.root = mob:FindFirstChildWhichIsA("BasePart", true)
	end

	if grounding.root then
		if mob.PrimaryPart ~= grounding.root then
			mob.PrimaryPart = grounding.root
		end
		grounding.rootLocalCFrame = mob:GetPivot():ToObjectSpace(grounding.root.CFrame)

		local ok, boundsCFrame, boundsSize = pcall(function()
			return mob:GetBoundingBox()
		end)
		if ok and typeof(boundsCFrame) == "CFrame" and typeof(boundsSize) == "Vector3" and boundsSize.Y > 0 then
			local lowestY = boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
			grounding.rootGroundOffset = grounding.root.Position.Y - lowestY
		else
			grounding.rootGroundOffset = math.max(0, grounding.root.Size.Y * 0.5)
		end
	else
		warn("[WaveController] Missing root while grounding spawn:", mob.Name)
	end

	return grounding
end

function WorldBounds.CFrameFromGround(surfacePos: Vector3, grounding, rotation: CFrame?): CFrame
	local rootRotation = rotation or CFrame.identity
	if not grounding or not grounding.root or not grounding.rootLocalCFrame or grounding.groundSnapDisabled then
		return CFrame.new(surfacePos + Vector3.new(0, WorldBounds.SpawnGroundClearance + (grounding and grounding.flightAltitude or 0), 0)) * rootRotation
	end

	local targetRootPos = Vector3.new(
		surfacePos.X,
		surfacePos.Y + grounding.rootGroundOffset + WorldBounds.SpawnGroundClearance,
		surfacePos.Z
	)
	return CFrame.new(targetRootPos) * rootRotation * grounding.rootLocalCFrame:Inverse()
end

-- Spawn bounds: prefer Map from Spawnable, fallback to any Map part in workspace.
-- This prevents "spawn only in a quarter" when ring samples outside the arena.
local _boundsCache = nil
local _boundsCacheT = 0
local BOUNDS_REFRESH_SEC = 2

local function computeSpawnBounds()
	local pMin, pMax = WorldBounds.GetXZ(6, Vector2.new(-200, -200), Vector2.new(200, 200))
	return {
		minX = pMin.X,
		maxX = pMax.X,
		minZ = pMin.Y,
		maxZ = pMax.Y,
	}
end

local function getSpawnBounds()
    local now = os.clock()
    if (not _boundsCache) or (now - _boundsCacheT) > BOUNDS_REFRESH_SEC then
        _boundsCache = computeSpawnBounds()
        _boundsCacheT = now
    end
    return _boundsCache
end

local function inBounds(bounds, x, z, margin)
    margin = margin or 0
    return x >= (bounds.minX + margin) and x <= (bounds.maxX - margin) and z >= (bounds.minZ + margin) and z <= (bounds.maxZ - margin)
end

local function pickSpawnCFrame(anchorPos: Vector3?, mob: Model?, spawnConfig): CFrame?
    local anchor = anchorPos
    if not anchor then
        local hrps = getAliveHRPs()
        if #hrps == 0 then return nil end
        anchor = hrps[math.random(1, #hrps)].Position
    end

    -- We intentionally do NOT use SpawnPoints here (raycast-based spawning only).

	local bounds = getSpawnBounds()
	local BOUNDS_MARGIN = 6
	local extraIgnore = mob and { mob } or nil
	local grounding = WorldBounds.BuildMobGrounding(mob, spawnConfig)

	local function fallbackGroundPoint(): Vector3?
		local point = WorldBounds.FindNearbyTerrainPoint(anchor, {
			searchRadii = { 0, 8, 16, 28, 40 },
			samplesPerRing = 10,
			heightOffset = 0,
			raycastIgnoreInstances = buildSpawnRaycastIgnore(extraIgnore),
			overlapIgnoreInstances = buildSpawnOverlapIgnore(extraIgnore),
			clearanceRadius = 3.5,
			clearanceHeight = 7,
			maxSlopeDeg = MAX_GROUND_SLOPE_DEG,
		})
		if point then
			return point
		end

		local randomPoint = WorldBounds.FindRandomTerrainPoint({
			pad = 6,
			tries = MAX_SPAWN_TRIES,
			heightOffset = 0,
			raycastIgnoreInstances = buildSpawnRaycastIgnore(extraIgnore),
			overlapIgnoreInstances = buildSpawnOverlapIgnore(extraIgnore),
			clearanceRadius = 3.5,
			clearanceHeight = 7,
			maxSlopeDeg = MAX_GROUND_SLOPE_DEG,
			fallbackMin = Vector2.new(-200, -200),
			fallbackMax = Vector2.new(200, 200),
		})
		return randomPoint
	end

    for _ = 1, MAX_SPAWN_TRIES do
        local ang = math.random() * math.pi * 2
        local r = SPAWN_RING_MIN + math.random() * (SPAWN_RING_MAX - SPAWN_RING_MIN)
        local x = anchor.X + math.cos(ang) * r
        local z = anchor.Z + math.sin(ang) * r

        -- Clamp into Map bounds so we don't waste tries outside the playable area.
        if bounds and not inBounds(bounds, x, z, BOUNDS_MARGIN) then
            x = math.clamp(x, bounds.minX + BOUNDS_MARGIN, bounds.maxX - BOUNDS_MARGIN)
            z = math.clamp(z, bounds.minZ + BOUNDS_MARGIN, bounds.maxZ - BOUNDS_MARGIN)
        end

		local hit = raycastGround(Vector3.new(x, 0, z), extraIgnore)
		if hit and hit.Position and slopeDeg(hit.Normal) <= MAX_GROUND_SLOPE_DEG then
			local spawnPos = hit.Position + Vector3.new(0, 0.05, 0)
			local clear = WorldBounds.IsAreaClear(spawnPos, 3.5, 7, buildSpawnOverlapIgnore(extraIgnore))
			if clear == true then
				return WorldBounds.CFrameFromGround(hit.Position, grounding)
			end
		end
	end

    -- Fallback: random point inside Map bounds.
    if bounds then
        for _ = 1, MAX_SPAWN_TRIES do
			local x = (bounds.minX + BOUNDS_MARGIN) + math.random() * ((bounds.maxX - BOUNDS_MARGIN) - (bounds.minX + BOUNDS_MARGIN))
			local z = (bounds.minZ + BOUNDS_MARGIN) + math.random() * ((bounds.maxZ - BOUNDS_MARGIN) - (bounds.minZ + BOUNDS_MARGIN))
			local hit = raycastGround(Vector3.new(x, 0, z), extraIgnore)
			if hit and hit.Position and slopeDeg(hit.Normal) <= MAX_GROUND_SLOPE_DEG then
				local spawnPos = hit.Position + Vector3.new(0, 0.05, 0)
				local clear = WorldBounds.IsAreaClear(spawnPos, 3.5, 7, buildSpawnOverlapIgnore(extraIgnore))
				if clear == true then
					return WorldBounds.CFrameFromGround(hit.Position, grounding)
				end
			end
		end
	end

	local fallbackPoint = fallbackGroundPoint()
	return fallbackPoint and WorldBounds.CFrameFromGround(fallbackPoint, grounding) or nil
end

-- Enemy config lives in ServerScriptService.ModuleScript.MobConfig.
local ENEMY_CONFIGS = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("MobConfig")).Mobs

local RUN_TIME_LIMIT = 15 * 60 -- 15:00 (portal/boss threshold)
local ENEMY_HP_MULTIPLIER = 2 / 3 -- start slime dies in 2 hits from Knight's Oath; the rest scales from the same baseline
local BOSS_BASE_HP = math.floor(1600 * ENEMY_HP_MULTIPLIER)
local BOSS_HP_MULT_EARLY = 22
local BOSS_HP_MULT_LATE = 6
local BOSS_LEVEL_TARGET = 10
local ELITE_SOUL_DROP_MIN = 18
local ELITE_SOUL_DROP_MAX = 28
local BOSS_SOUL_DROP_MIN = 45
local BOSS_SOUL_DROP_MAX = 65
local RUN_COIN_DROP_MULTIPLIER = 3
local RUN_SOUL_DROP_MULTIPLIER = 3
local ELITE_INTERVAL_SECONDS = 5 * 60
local BOSS_REINFORCEMENT_INTERVAL = 10
local SWARM_EVENT_TIMES = { 240, 720 } -- 4:00, 12:00
local SWARM_DURATION = 60
local materialRng = Random.new()
local MAX_LIVING_ENEMIES = math.max(1, math.floor(tonumber(RunSpawnConfig.MAX_LIVING_ENEMIES) or 100))
local NORMAL_SOUL_DROP_CONFIG = RunSpawnConfig.NORMAL_SOUL_DROP or {}
local LEVEL_SPAWN_BANDS = RunSpawnConfig.LEVEL_SPAWN_BANDS or {}
local OVERTIME_SPAWN_CONFIG = RunSpawnConfig.OVERTIME or {}
local SWARM_SPAWN_CONFIG = RunSpawnConfig.SWARM or {}
local IMPORTANT_ENCOUNTER_SPAWN_CONFIG = RunSpawnConfig.IMPORTANT_ENCOUNTER or {}
local spawnLimitConfig = {
	swarmTargetMaxAlive = math.max(0, math.floor(tonumber(SWARM_SPAWN_CONFIG.targetMaxAlive) or 0)),
	swarmMaxLivingEnemies = math.max(
		MAX_LIVING_ENEMIES,
		math.floor(tonumber(SWARM_SPAWN_CONFIG.maxLivingEnemies) or MAX_LIVING_ENEMIES)
	),
	postEliteCatchupDuration = math.max(
		0.1,
		tonumber((RunSpawnConfig.POST_ELITE_SPAWN or {}).catchupDuration) or 10
	),
	postEliteMaxPerTick = math.max(
		1,
		math.floor(tonumber((RunSpawnConfig.POST_ELITE_SPAWN or {}).maxPerTick) or 4)
	),
}
local NORMAL_ENEMY_COUNT_FILTER = {
	includeNormal = true,
	includeElite = false,
	includeBoss = false,
}
local ELITE_ENEMY_COUNT_FILTER = {
	includeNormal = false,
	includeElite = true,
	includeBoss = false,
}
local BOSS_ENEMY_COUNT_FILTER = {
	includeNormal = false,
	includeElite = false,
	includeBoss = true,
}

local function getDebugNumber(name: string, defaultValue: number): number
	local folder = ReplicatedStorage:FindFirstChild("DebugSettings")
	local value = folder and folder:FindFirstChild(name)
	if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then
		return tonumber(value.Value) or defaultValue
	end
	return defaultValue
end

local function getDebugBoolean(name: string, defaultValue: boolean): boolean
	local folder = ReplicatedStorage:FindFirstChild("DebugSettings")
	local value = folder and folder:FindFirstChild(name)
	if value and value:IsA("BoolValue") then
		return value.Value
	end
	return defaultValue
end

local function isSpawnStressEnabled(): boolean
	return getDebugBoolean("SpawnStressMode", false)
end

local function areAutoMobSpawnsEnabled(): boolean
	return getDebugBoolean("AutoMobSpawnsEnabled", true)
end

local function getSpawnStressConfig(): (number, number, number)
	if not isSpawnStressEnabled() then
		return 1, 1, 1
	end
	local burstSize = math.max(1, math.floor(getDebugNumber("SpawnBurstSize", 1)))
	local intervalScale = math.clamp(getDebugNumber("SpawnIntervalScale", 1), 0.1, 3)
	local maxAliveScale = math.max(1, getDebugNumber("MaxAliveScale", 1))
	return burstSize, intervalScale, maxAliveScale
end

local function getAverageRunLevel(): number
	local ok, value = pcall(function()
		return require(ServerScriptService.ModuleScript.RunProgressApi).GetAverageRunLevel()
	end)
	if not ok then
		return 0
	end

	return math.max(0, tonumber(value) or 0)
end

local encounterScheduler

local function getRunPressure(elapsedSeconds: number)
	local avgRunLevel = getAverageRunLevel()
	return encounterScheduler:GetRunPressure(elapsedSeconds, avgRunLevel)
end

local function timeScaleMult(elapsed: number)
	return encounterScheduler:TimeScaleMult(elapsed, getAverageRunLevel())
end

local function getPool(elapsed: number)
	return encounterScheduler:GetPool(elapsed)
end

local function pickWeighted(pool)
	return EncounterScheduler.PickWeighted(pool)
end

local function activeEnemiesCount()
    return NpcService.GetActiveCount()
end

local function activeNormalEnemiesCount()
	return NpcService.GetActiveCount(NORMAL_ENEMY_COUNT_FILTER)
end

local function activeEliteEnemiesCount()
	return NpcService.GetActiveCount(ELITE_ENEMY_COUNT_FILTER)
end

local function activeBossEnemiesCount()
	return NpcService.GetActiveCount(BOSS_ENEMY_COUNT_FILTER)
end

local function getImportantEncounterConfig(kind: string?)
	return encounterScheduler:GetImportantEncounterConfig(kind)
end

local function getActiveImportantEncounter()
	if activeBossEnemiesCount() > 0 then
		return "boss", getImportantEncounterConfig("boss")
	end
	if activeEliteEnemiesCount() > 0 then
		return "elite", getImportantEncounterConfig("elite")
	end
	return nil, getImportantEncounterConfig(nil)
end

local function cleanupTemplateScripts(mob: Model)
    local animationsFolder = mob:FindFirstChild("Animations")
    for _, d in ipairs(mob:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then
            if string.lower(d.Name) == "animate" then
                if not animationsFolder then
                    animationsFolder = Instance.new("Folder")
                    animationsFolder.Name = "Animations"
                    animationsFolder.Parent = mob
                end
                for _, child in ipairs(d:GetChildren()) do
                    child.Parent = animationsFolder
                end
            end
            d:Destroy()
        end
    end
end

local function getActiveRunPlayers(): {Player}
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Parent and plr:GetAttribute("RunEnded") ~= true then
			table.insert(out, plr)
		end
	end
	return out
end

local function addPersistentCount(plr: Player, bucketName: string, itemId: string, amount: number)
	if typeof(itemId) ~= "string" or itemId == "" then
		return
	end
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return
	end

	local data = PlayerData.Get(plr)
	data.crafting = data.crafting or {}
	data.crafting[bucketName] = data.crafting[bucketName] or {}
	local bucket = data.crafting[bucketName]
	bucket[itemId] = math.max(0, math.floor(tonumber(bucket[itemId]) or 0)) + amount
	if PlayerData.MarkDirty then
		PlayerData.MarkDirty(plr)
	end
end

local function discoverCodex(plr: Player, category: string, id: string, reason: string)
	if PlayerData.DiscoverCodex then
		PlayerData.DiscoverCodex(plr, category, id, reason)
	end
end

local function awardPersistentMobDrops(mobType: string, isElite: boolean, isBoss: boolean)
	local materialId = CraftingConfig.GetMobMaterialForMob(mobType)
	local activePlayers = getActiveRunPlayers()
	if #activePlayers == 0 then
		return
	end

	local crystalAward = 0
	if isBoss then
		local range = CraftingConfig.BOSS_UPGRADE_CRYSTAL_RANGE or { min = 8, max = 12 }
		crystalAward = materialRng:NextInteger(range.min or 8, range.max or 12)
	elseif isElite then
		local range = CraftingConfig.ELITE_UPGRADE_CRYSTAL_RANGE or { min = 3, max = 5 }
		crystalAward = materialRng:NextInteger(range.min or 3, range.max or 5)
	elseif materialRng:NextNumber() <= (tonumber(CraftingConfig.NORMAL_MOB_UPGRADE_CRYSTAL_CHANCE) or 0) then
		crystalAward = 1
	end

	for _, plr in ipairs(activePlayers) do
		discoverCodex(plr, isBoss and "Bosses" or (isElite and "Elites" or "Enemies"), mobType, "mob_defeated")
		if materialId then
			local materialCount = isBoss and 3 or (isElite and 2 or 1)
			addPersistentCount(plr, "mobMaterials", materialId, materialCount)
			discoverCodex(plr, "Materials", materialId, "mob_drop")
			PickupToastService.PushMaterial(plr, materialId, materialCount, "Mob Drop", "mobMaterials")
		end
		if crystalAward > 0 then
			addPersistentCount(plr, "upgradeMaterials", CraftingConfig.UPGRADE_CRYSTAL_ID, crystalAward)
			discoverCodex(plr, "Materials", CraftingConfig.UPGRADE_CRYSTAL_ID, "upgrade_drop")
			PickupToastService.PushMaterial(plr, CraftingConfig.UPGRADE_CRYSTAL_ID, crystalAward, "Mob Drop", "upgradeMaterials")
		end
		if isBoss then
			addPersistentCount(plr, "upgradeMaterials", CraftingConfig.BOSS_SPECIAL_ID, 1)
			discoverCodex(plr, "Materials", CraftingConfig.BOSS_SPECIAL_ID, "boss_drop")
			PickupToastService.PushMaterial(plr, CraftingConfig.BOSS_SPECIAL_ID, 1, "Boss Drop", "upgradeMaterials")
		elseif isElite then
			addPersistentCount(plr, "upgradeMaterials", CraftingConfig.ELITE_SPECIAL_ID, 1)
			discoverCodex(plr, "Materials", CraftingConfig.ELITE_SPECIAL_ID, "elite_drop")
			PickupToastService.PushMaterial(plr, CraftingConfig.ELITE_SPECIAL_ID, 1, "Elite Drop", "upgradeMaterials")
		end
	end
end

local function handleMobDeath(mob: Model, rewardCfg, isElite: boolean, isBoss: boolean, _ctx)
	local pos = (_ctx and _ctx.position) or NpcService.GetPosition(mob) or mob:GetPivot().Position
	local killer = _ctx and _ctx.player
	local runSeconds = require(ServerScriptService.ModuleScript.RunProgressApi).GetRunSeconds()
	local minutes, _, levelPressure = getRunPressure(runSeconds)

	pcall(function()
		require(ServerScriptService.ModuleScript.RunProgressApi).RegisterEnemyKill(pos, killer)
	end)

    if MissionProgress and MissionProgress.OnKill and killer and killer.Parent == Players and killer:GetAttribute("RunEnded") ~= true then
        pcall(function() MissionProgress.OnKill(killer, mob) end)
    end

    local xpDrop = rewardCfg.xp or 5
    local coinDrop = rewardCfg.coins or 1
    local soulsDrop = 0

	local xpScale = 1 + (minutes * 0.04) + (levelPressure * 0.06)
	local coinScale = 1.45 + (minutes * 0.08) + (levelPressure * 0.10)

	xpDrop = math.max(1, math.floor(xpDrop * xpScale))
	coinDrop = math.max(1, math.floor(coinDrop * coinScale))

	if isBoss then
		xpDrop = math.floor(xpDrop * 6)
		coinDrop = math.floor(coinDrop * 6)
		soulsDrop = math.random(BOSS_SOUL_DROP_MIN, BOSS_SOUL_DROP_MAX)
	elseif isElite then
		xpDrop = math.floor(xpDrop * 7)
		coinDrop = math.floor(coinDrop * 7)
		soulsDrop = math.random(ELITE_SOUL_DROP_MIN, ELITE_SOUL_DROP_MAX)
	else
		local soulChance = math.clamp(tonumber(NORMAL_SOUL_DROP_CONFIG.chance) or 0, 0, 1)
		if soulChance > 0 and math.random() <= soulChance then
			local minSouls = math.max(1, math.floor(tonumber(NORMAL_SOUL_DROP_CONFIG.minAmount) or 1))
			local maxSouls = math.max(minSouls, math.floor(tonumber(NORMAL_SOUL_DROP_CONFIG.maxAmount) or minSouls))
			soulsDrop = math.random(minSouls, maxSouls)
		end
	end

	coinDrop = math.max(1, math.floor(coinDrop * RUN_COIN_DROP_MULTIPLIER))
	soulsDrop = math.max(0, math.floor(soulsDrop * RUN_SOUL_DROP_MULTIPLIER))

	local dropsOk, dropsErr = pcall(function()
		awardPersistentMobDrops(tostring(mob:GetAttribute("MobType") or mob.Name), isElite, isBoss)
	end)
	if not dropsOk then
		warn("[WaveController] Persistent mob drops failed:", dropsErr)
	end
	if _G.SpawnDropsAt then
		pcall(function() _G.SpawnDropsAt(pos, xpDrop, coinDrop, soulsDrop) end)
	end
end

local ELITE_VISUAL_SCALE = 3
local BOSS_VISUAL_SCALE = 3

local function getMobVisualScale(isElite: boolean, isBoss: boolean, stats): number
	local overrideScale = stats and tonumber(stats.visualScale) or nil
	if overrideScale and overrideScale > 0 then
		return overrideScale
	end
	if isBoss then
		return BOSS_VISUAL_SCALE
	end
	if isElite then
		return ELITE_VISUAL_SCALE
	end
	return 1
end

local function applyMobVisualScale(mob: Model, isElite: boolean, isBoss: boolean, stats): number
	local desiredScale = getMobVisualScale(isElite, isBoss, stats)
	local appliedScale = 1
	if desiredScale > 1.001 then
		local ok, err = pcall(function()
			mob:ScaleTo(desiredScale)
		end)
		if ok then
			appliedScale = desiredScale
		else
			warn("[WaveController] Failed to scale mob:", mob.Name, err)
		end
	end
	mob:SetAttribute("NpcVisualScale", appliedScale)
	return appliedScale
end

local function setOptionalMobAttribute(mob: Model, name: string, value: any)
	if value ~= nil then
		mob:SetAttribute(name, value)
	end
end

local function registerMobModel(mob: Model, mobType: string, stats, rewardCfg, isElite: boolean, isBoss: boolean, extraOnDeath)
	mob:SetAttribute("MobType", mobType)
	mob:SetAttribute("DisplayName", mobType)
	mob:SetAttribute("Damage", stats.dmg)
	mob:SetAttribute("AttackRange", stats.range)
	mob:SetAttribute("AttackCooldown", stats.cd)
	mob:SetAttribute("IsElite", isElite)
	mob:SetAttribute("IsBoss", isBoss == true)
	mob:SetAttribute("IsRanged", stats.isRanged == true)
	mob:SetAttribute("IsDead", false)
	mob:SetAttribute("IsAttacking", false)
	setOptionalMobAttribute(mob, "NpcFacingYawDegrees", stats.facingYawDegrees)
	setOptionalMobAttribute(mob, "MovementProfile", stats.movementProfile)
	setOptionalMobAttribute(mob, "MovementMode", stats.movementMode)
	setOptionalMobAttribute(mob, "MovementSystem", stats.movementSystem)
	setOptionalMobAttribute(mob, "MovementBehavior", stats.movementBehavior)
	setOptionalMobAttribute(mob, "CombatBehavior", stats.combatBehavior)
	setOptionalMobAttribute(mob, "CanFly", stats.canFly)
	setOptionalMobAttribute(mob, "NpcGroundOffset", stats.groundOffset)
	setOptionalMobAttribute(mob, "EnemyMeleeIgnoreVerticalValidation", stats.meleeIgnoreVerticalValidation)
	setOptionalMobAttribute(mob, "EnemyMeleeMaxVerticalDelta", stats.meleeMaxVerticalDelta)
	setOptionalMobAttribute(mob, "EnemyMeleeMaxHitHeightAboveEnemy", stats.meleeMaxHitHeightAboveEnemy)
	setOptionalMobAttribute(mob, "EnemyMeleeUse3DDistance", stats.meleeUse3DDistance)

    local registeredId = NpcService.Register(mob, {
        mobType = mobType,
        maxHealth = stats.hp,
        speed = stats.speed,
        attackRange = stats.range,
        attackCooldown = stats.cd,
        damage = stats.dmg,
        isElite = isElite,
        isBoss = isBoss == true,
        isRanged = stats.isRanged == true,
		movementProfile = stats.movementProfile,
		movementMode = stats.movementMode,
		movementSystem = stats.movementSystem,
		movementBehavior = stats.movementBehavior,
		combatBehavior = stats.combatBehavior,
		canFly = stats.canFly,
		groundOffset = stats.groundOffset,
        despawnDelay = 3,
        attackWindup = math.min(0.6, math.max(0.2, stats.cd * 0.45)),
        onDeath = function(_npc, ctx)
            handleMobDeath(mob, rewardCfg, isElite, isBoss == true, ctx)
            if extraOnDeath then
                extraOnDeath(mob, ctx)
            end
        end,
    })

    if not registeredId then
        mob:Destroy()
        return nil
    end

    return mob
end

local registerEliteController

local function spawnMob(mobName: string, isElite: boolean, spawnAnchorPos: Vector3?, spawnSource: string?)
    local templateFolder = isElite and EliteFolder or NormalFolder
    local template = templateFolder:FindFirstChild(mobName)
    if not template or not template:IsA("Model") then
        warn("[Horde] Missing template:", (isElite and "Elite" or "Normal"), mobName)
        return
    end

    local cfg = ENEMY_CONFIGS[mobName]
    if not cfg then
        warn("[Horde] Missing config for", mobName)
        return
    end

    local mob = template:Clone()
    mob.Name = mobName
    cleanupTemplateScripts(mob)
    setMobGroup(mob)
    applyMobVisualScale(mob, isElite, false, cfg)
    mob:SetAttribute("SpawnSource", spawnSource or (isElite and "Elite" or "RunAmbient"))

    local cf = pickSpawnCFrame(spawnAnchorPos, mob, cfg)
	if not cf then
		mob:Destroy()
		return
	end

    mob.Parent = ENEMIES_FOLDER
    mob:PivotTo(cf)

    local hpMult, dmgMult, speedMult, cooldownMult = timeScaleMult(require(ServerScriptService.ModuleScript.RunProgressApi).GetRunSeconds())
    local hp = math.floor(cfg.hp * ENEMY_HP_MULTIPLIER * hpMult)
    local dmg = math.floor(cfg.dmg * dmgMult)
    local speed = cfg.speed * speedMult
    local cd = math.max(0.7, cfg.cd * cooldownMult)

    if isElite then
        hp = math.floor(hp * 5.0)
        dmg = math.floor(dmg * 2.4)
        speed = speed * 1.08
        cd = math.max(0.60, cd * 0.90)
    end

    local registered = registerMobModel(mob, mobName, {
        hp = hp,
        speed = speed,
        range = cfg.range,
        cd = cd,
        dmg = dmg,
        isRanged = cfg.isRanged == true,
		movementProfile = cfg.movementProfile,
		movementMode = cfg.movementMode,
		movementSystem = cfg.movementSystem,
		movementBehavior = cfg.movementBehavior,
		combatBehavior = cfg.combatBehavior,
		canFly = cfg.canFly,
		groundOffset = cfg.groundOffset,
		meleeIgnoreVerticalValidation = cfg.meleeIgnoreVerticalValidation,
		meleeMaxVerticalDelta = cfg.meleeMaxVerticalDelta,
		meleeMaxHitHeightAboveEnemy = cfg.meleeMaxHitHeightAboveEnemy,
		meleeUse3DDistance = cfg.meleeUse3DDistance,
    }, cfg, isElite, false, nil)

    if registered and isElite then
		registerEliteController(registered, mobName, dmg)
    end

    return registered
end

local elapsed: () -> number
local getMaxLivingEnemyCap: (number?) -> number

local function spawnBurst(count: number, anchorPos: Vector3?, poolTime: number?, spawnSource: string?)
    local spawned = {}
    local targetCount = math.max(0, math.floor(tonumber(count) or 0))
    if targetCount <= 0 then
        return spawned
    end

    local burstTime = math.max(0, tonumber(poolTime) or elapsed())
    local pool = getPool(burstTime)
	local aliveNow = activeEnemiesCount()
    for _ = 1, targetCount do
		if aliveNow >= getMaxLivingEnemyCap(burstTime) then
			break
		end
        local mobName = pickWeighted(pool)
        local mob = spawnMob(mobName, false, anchorPos, spawnSource or "Burst")
        if mob then
            table.insert(spawned, mob)
			aliveNow += 1
        end
    end

    return spawned
end

_G.SpawnEnemyBurst = function(count: number, anchorPos: Vector3?, poolTime: number?, spawnSource: string?)
    return spawnBurst(count, anchorPos, poolTime, spawnSource)
end

local AbilityVfxFolder = workspace:FindFirstChild("EnemyAbilityVFX")
if not AbilityVfxFolder then
	AbilityVfxFolder = Instance.new("Folder")
	AbilityVfxFolder.Name = "EnemyAbilityVFX"
	AbilityVfxFolder.Parent = workspace
end

local eliteControllers = {}
local bossAbilityController = nil

local ABILITY_COLORS = {
	Elite = Color3.fromRGB(255, 132, 82),
	Golem = Color3.fromRGB(201, 175, 112),
	Knight = Color3.fromRGB(132, 186, 255),
	Demon = Color3.fromRGB(255, 98, 54),
	Ent = Color3.fromRGB(120, 188, 108),
	Boss = Color3.fromRGB(255, 170, 76),
}

local function getAliveCombatPlayers()
	local out = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Parent and plr:GetAttribute("RunEnded") ~= true then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				out[#out + 1] = {
					player = plr,
					humanoid = hum,
					hrp = hrp,
				}
			end
		end
	end
	return out
end

local function pickNearestCombatPlayer(fromPos: Vector3)
	local bestInfo = nil
	local bestDist = math.huge
	for _, info in ipairs(getAliveCombatPlayers()) do
		local dist = (info.hrp.Position - fromPos).Magnitude
		if dist < bestDist then
			bestDist = dist
			bestInfo = info
		end
	end
	return bestInfo, bestDist
end

local abilityExecutor = AbilityExecutor.new({
	abilityVfxFolder = AbilityVfxFolder,
	raycastGround = raycastGround,
	runStarted = RunStarted,
	pauseState = PauseState,
	spawnBurst = function(count: number, anchorPos: Vector3?, poolTime: number?, spawnSource: string?)
		return spawnBurst(count, anchorPos, poolTime, spawnSource)
	end,
	elapsed = function()
		return elapsed()
	end,
	runTimeLimit = RUN_TIME_LIMIT,
})

local function abilityReady(controller, abilityId: string, now: number)
	return abilityExecutor:AbilityReady(controller, abilityId, now)
end

local function tryCastAbility(controller, targetInfo, now, cfg)
	return abilityExecutor:TryCast(controller, targetInfo, now, cfg)
end

local ELITE_ABILITY_DATA = {
	Golem = {
		{ id = "GroundSlam", kind = "GroundSlam", cooldown = 8.5, globalCooldown = 1.8, telegraph = 1.0, radius = 11, damageMultiplier = 1.55, color = ABILITY_COLORS.Golem },
		{ id = "RockToss", kind = "TargetImpact", cooldown = 6.8, globalCooldown = 1.5, telegraph = 0.9, radius = 5.5, damageMultiplier = 1.15, color = ABILITY_COLORS.Golem },
		{ id = "ArmorUp", kind = "ArmorUp", cooldown = 18.0, globalCooldown = 1.2, duration = 4.5, damageTakenMult = 0.72, color = ABILITY_COLORS.Golem },
	},
	Knight = {
		{ id = "DashThrust", kind = "Dash", cooldown = 7.0, globalCooldown = 1.4, telegraph = 0.8, width = 4.0, distance = 18, damageMultiplier = 1.35, color = ABILITY_COLORS.Knight },
		{ id = "ShieldCone", kind = "Cone", cooldown = 8.0, globalCooldown = 1.3, telegraph = 0.7, range = 12, angle = 55, damageMultiplier = 1.10, color = ABILITY_COLORS.Knight },
		{ id = "TripleCombo", kind = "TripleCombo", cooldown = 10.0, globalCooldown = 1.8, totalDuration = 1.0, hitDelays = { 0.2, 0.45, 0.72 }, range = 8, angle = 60, damageMultiplier = 0.55, color = ABILITY_COLORS.Knight },
	},
	Demon = {
		{ id = "FireballVolley", kind = "Volley", cooldown = 9.0, globalCooldown = 1.6, telegraph = 0.9, radius = 4.8, count = 3, spread = 5, damageMultiplier = 0.82, color = ABILITY_COLORS.Demon },
		{ id = "FlamePool", kind = "Hazard", cooldown = 12.0, globalCooldown = 1.5, telegraph = 0.9, radius = 6.0, duration = 4.5, tickRate = 0.75, damageMultiplier = 0.46, color = ABILITY_COLORS.Demon },
		{ id = "TeleportStep", kind = "TeleportStep", cooldown = 10.0, globalCooldown = 1.3, telegraph = 0.35, radius = 5.5, distance = 9, damageMultiplier = 0.95, color = ABILITY_COLORS.Demon },
	},
	Ent = {
		{ id = "RootCage", kind = "Hazard", cooldown = 12.5, globalCooldown = 1.5, telegraph = 0.95, radius = 7.5, duration = 3.6, tickRate = 0.80, damageMultiplier = 0.38, color = ABILITY_COLORS.Ent },
		{ id = "SeedMortar", kind = "Volley", cooldown = 9.5, globalCooldown = 1.5, telegraph = 1.0, radius = 5.2, count = 3, spread = 6, damageMultiplier = 0.84, color = ABILITY_COLORS.Ent },
		{ id = "Sweep", kind = "Cone", cooldown = 8.5, globalCooldown = 1.4, telegraph = 0.75, range = 13, angle = 70, damageMultiplier = 1.18, color = ABILITY_COLORS.Ent },
	},
}

local BOSS_PHASE_ABILITIES = {
	[1] = {
		{ id = "StoneFist", kind = "TargetImpact", cooldown = 7.0, globalCooldown = 1.5, telegraph = 1.0, radius = 8.0, damageMultiplier = 1.40, color = ABILITY_COLORS.Boss },
		{ id = "Shockwave", kind = "ShockwaveSequence", cooldown = 10.0, globalCooldown = 1.8, pulses = { { delay = 0.85, radius = 17, damageMultiplier = 1.10 } }, color = ABILITY_COLORS.Boss },
		{ id = "BoulderRain", kind = "MeteorRain", cooldown = 14.0, globalCooldown = 1.8, telegraph = 1.1, radius = 5.2, count = 5, spread = 8, damageMultiplier = 0.86, color = ABILITY_COLORS.Boss },
		{ id = "SummonShards", kind = "Summon", cooldown = 18.0, globalCooldown = 1.4, telegraph = 0.8, count = 3, color = ABILITY_COLORS.Boss },
	},
	[2] = {
		{ id = "ChargeCrush", kind = "Dash", cooldown = 8.0, globalCooldown = 1.5, telegraph = 0.8, width = 5.0, distance = 24, damageMultiplier = 1.60, color = ABILITY_COLORS.Boss },
		{ id = "CrackedEarth", kind = "LineStrike", cooldown = 11.0, globalCooldown = 1.7, telegraph = 1.0, width = 4.5, distance = 28, damageMultiplier = 1.25, color = ABILITY_COLORS.Boss },
		{ id = "HardenSkin", kind = "ArmorUp", cooldown = 20.0, globalCooldown = 1.2, duration = 5.0, damageTakenMult = 0.70, color = ABILITY_COLORS.Boss },
		{ id = "DoubleShockwave", kind = "ShockwaveSequence", cooldown = 16.0, globalCooldown = 1.8, pulses = { { delay = 0.80, radius = 14, damageMultiplier = 0.95 }, { delay = 1.35, radius = 20, damageMultiplier = 0.95 } }, color = ABILITY_COLORS.Boss },
	},
	[3] = {
		{ id = "ArenaPressure", kind = "ArenaPressure", cooldown = 15.0, globalCooldown = 1.7, telegraph = 0.9, radius = 6.0, duration = 4.5, tickRate = 0.80, spread = 8, damageMultiplier = 0.42, color = ABILITY_COLORS.Boss },
		{ id = "MeteorCore", kind = "MeteorRain", cooldown = 17.0, globalCooldown = 1.8, telegraph = 1.2, radius = 6.2, count = 6, spread = 10, damageMultiplier = 1.05, color = ABILITY_COLORS.Boss },
		{ id = "ChargeCrush", kind = "Dash", cooldown = 7.0, globalCooldown = 1.4, telegraph = 0.75, width = 5.2, distance = 26, damageMultiplier = 1.68, color = ABILITY_COLORS.Boss },
		{ id = "Enrage", kind = "Enrage", cooldown = 999.0, globalCooldown = 0.8, damageMultiplier = 1.15, cooldownScale = 0.88, color = ABILITY_COLORS.Boss },
	},
}

registerEliteController = function(model: Model, mobType: string, baseDamage: number)
	if not ELITE_ABILITY_DATA[mobType] then
		return
	end
	eliteControllers[model] = {
		model = model,
		mobType = mobType,
		baseDamage = baseDamage,
		cooldowns = {},
		globalCooldown = 0,
		cooldownScale = 1,
	}
end

local function unregisterEncounterController(model: Model)
	eliteControllers[model] = nil
	if bossAbilityController and bossAbilityController.model == model then
		bossAbilityController = nil
	end
end

local function stepEliteControllers(now: number)
	for model, controller in pairs(eliteControllers) do
		if not model.Parent or not NpcService.IsAlive(model) then
			eliteControllers[model] = nil
		else
			local pos = NpcService.GetPosition(model)
			local targetInfo, dist = nil, math.huge
			if pos then
				targetInfo, dist = pickNearestCombatPlayer(pos)
			end
			if pos and targetInfo then
				local casts = ELITE_ABILITY_DATA[controller.mobType]
				if controller.mobType == "Golem" then
					if dist <= 14 and tryCastAbility(controller, targetInfo, now, casts[1]) then
						continue
					end
					if dist <= 36 and tryCastAbility(controller, targetInfo, now, casts[2]) then
						continue
					end
					if not abilityReady(controller, casts[3].id, now) then
						continue
					end
					local hp, maxHp = NpcService.GetHealth(model)
					if maxHp > 0 and (hp / maxHp) <= 0.70 then
						tryCastAbility(controller, targetInfo, now, casts[3])
					end
				elseif controller.mobType == "Knight" then
					if dist >= 8 and dist <= 22 and tryCastAbility(controller, targetInfo, now, casts[1]) then
						continue
					end
					if dist <= 12 and tryCastAbility(controller, targetInfo, now, casts[2]) then
						continue
					end
					if dist <= 8 then
						tryCastAbility(controller, targetInfo, now, casts[3])
					end
				elseif controller.mobType == "Demon" then
					if dist <= 34 and tryCastAbility(controller, targetInfo, now, casts[1]) then
						continue
					end
					if dist <= 30 and tryCastAbility(controller, targetInfo, now, casts[2]) then
						continue
					end
					if dist <= 24 then
						tryCastAbility(controller, targetInfo, now, casts[3])
					end
				elseif controller.mobType == "Ent" then
					if dist <= 28 and tryCastAbility(controller, targetInfo, now, casts[1]) then
						continue
					end
					if dist <= 38 and tryCastAbility(controller, targetInfo, now, casts[2]) then
						continue
					end
					if dist <= 14 then
						tryCastAbility(controller, targetInfo, now, casts[3])
					end
				end
			end
		end
	end
end

local function registerBossController(model: Model, baseDamage: number)
	bossAbilityController = {
		model = model,
		baseDamage = baseDamage,
		cooldowns = {},
		globalCooldown = 0,
		cooldownScale = 1,
		phase = 1,
		enraged = false,
	}
end

local function stepBossController(now: number)
	local controller = bossAbilityController
	if not controller then
		return
	end
	if not controller.model.Parent or not NpcService.IsAlive(controller.model) then
		bossAbilityController = nil
		return
	end

	local bossPos = NpcService.GetPosition(controller.model)
	local targetInfo, dist = nil, math.huge
	if bossPos then
		targetInfo, dist = pickNearestCombatPlayer(bossPos)
	end
	if not bossPos or not targetInfo then
		return
	end

	local hp, maxHp = NpcService.GetHealth(controller.model)
	local hpRatio = maxHp > 0 and (hp / maxHp) or 1
	local phase = hpRatio <= 0.35 and 3 or (hpRatio <= 0.70 and 2 or 1)
	controller.phase = phase
	local casts = BOSS_PHASE_ABILITIES[phase]

	if phase == 3 and not controller.enraged then
		if tryCastAbility(controller, targetInfo, now, casts[4]) then
			return
		end
	end

	if phase == 1 then
		if dist <= 22 and tryCastAbility(controller, targetInfo, now, casts[1]) then
			return
		end
		if dist <= 20 and tryCastAbility(controller, targetInfo, now, casts[2]) then
			return
		end
		if tryCastAbility(controller, targetInfo, now, casts[3]) then
			return
		end
		tryCastAbility(controller, targetInfo, now, casts[4])
	elseif phase == 2 then
		if dist >= 10 and dist <= 30 and tryCastAbility(controller, targetInfo, now, casts[1]) then
			return
		end
		if tryCastAbility(controller, targetInfo, now, casts[2]) then
			return
		end
		if hpRatio <= 0.58 and tryCastAbility(controller, targetInfo, now, casts[3]) then
			return
		end
		tryCastAbility(controller, targetInfo, now, casts[4])
	else
		if tryCastAbility(controller, targetInfo, now, casts[2]) then
			return
		end
		if tryCastAbility(controller, targetInfo, now, casts[1]) then
			return
		end
		tryCastAbility(controller, targetInfo, now, casts[3])
	end
end

-- Run clock (server-side)
local runStart = 0 -- set when RunStarted becomes true
local pausedAccum = 0
local pauseStart = nil

elapsed = function()
    if not RunStarted.Value then
        return 0
    end
    if runStart == 0 then
        runStart = time()
    end
    local now = time()
    if PauseState.Value then
        if not pauseStart then
            pauseStart = now
        end
        return pauseStart - runStart - pausedAccum
    end

    if pauseStart then
        pausedAccum += (now - pauseStart)
        pauseStart = nil
    end

    return now - runStart - pausedAccum
end

require(ServerScriptService.ModuleScript.RunProgressApi).SetRunSecondsProvider(function()
    return math.floor(elapsed())
end)


-- Counters for InfoUI (must be defined before wrappers below)
local runKills = 0
local runCoins = 0
require(ServerScriptService.ModuleScript.RunProgressApi).Wrap("RegisterEnemyKill", function(prevKill)
	return function(pos, killer)
		runKills += 1
		return prevKill(pos, killer)
	end
end)

require(ServerScriptService.ModuleScript.RunProgressApi).Wrap("AwardPlayer", function(prevAward)
	return function(plr: Player, xp: number, coins: number)
		xp = math.max(0, math.floor(tonumber(xp) or 0))
		coins = math.max(0, math.floor(tonumber(coins) or 0))
		if coins > 0 then runCoins += coins end
		return prevAward(plr, xp, coins)
	end
end)

local function isSwarmActiveAt(t: number): boolean
	return encounterScheduler:IsSwarmActiveAt(t)
end

getMaxLivingEnemyCap = function(t: number?): number
	return encounterScheduler:GetMaxLivingEnemyCap(tonumber(t) or elapsed())
end

local function hasEnemyCapacity(slotsNeeded: number?, t: number?): boolean
	return encounterScheduler:HasEnemyCapacity(activeEnemiesCount(), slotsNeeded, t)
end

local function buildEliteOrder(): {string}
	-- Prefer named elites if they exist, fallback to any elite model in ReplicatedStorage.
	local preferred = { "Ent", "Golem", "Knight", "Demon" }
	local result = {}
	local used = {}

	for _, name in ipairs(preferred) do
		local obj = EliteFolder:FindFirstChild(name)
		if obj and obj:IsA("Model") then
			table.insert(result, name)
			used[name] = true
		end
	end

	if #result == 0 then
		for _, obj in ipairs(EliteFolder:GetChildren()) do
			if obj:IsA("Model") and not used[obj.Name] then
				table.insert(result, obj.Name)
				used[obj.Name] = true
			end
		end
	end

	table.sort(result)
	return result
end

local eliteOrder = buildEliteOrder()
encounterScheduler = EncounterScheduler.new({
	runTimeLimit = RUN_TIME_LIMIT,
	eliteIntervalSeconds = ELITE_INTERVAL_SECONDS,
	maxLivingEnemies = MAX_LIVING_ENEMIES,
	levelSpawnBands = LEVEL_SPAWN_BANDS,
	overtimeSpawnConfig = OVERTIME_SPAWN_CONFIG,
	swarmSpawnConfig = SWARM_SPAWN_CONFIG,
	importantEncounterSpawnConfig = IMPORTANT_ENCOUNTER_SPAWN_CONFIG,
	spawnLimitConfig = spawnLimitConfig,
	swarmEventTimes = SWARM_EVENT_TIMES,
	swarmDuration = SWARM_DURATION,
	eliteOrder = eliteOrder,
})
-- === Portal + Boss end condition ===
local portalController = nil
local bossModel: Model? = nil
local bossSpawnPending = false
local nextBossReinforcementAt = math.huge
local function isPortalActivated(): boolean
	return portalController ~= nil and portalController:IsActivated()
end

local function isBossDefeated(): boolean
	return portalController ~= nil and portalController:IsBossDefeated()
end

local function refreshPortalPromptState()
	if portalController then
		portalController:RefreshPrompt()
	end
end

local spawnBossNearPortal: (() -> boolean)? = nil

-- Stats for InfoUI
local function fmtTimePayload(tSeconds: number)
	local left = math.max(0, RUN_TIME_LIMIT - tSeconds)
	local over = math.max(0, tSeconds - RUN_TIME_LIMIT)
	return left, over
end

local function getBossHealthForCurrentRun(): number
	local elapsedSeconds = math.max(0, elapsed())
	local timeProgress = math.clamp(elapsedSeconds / RUN_TIME_LIMIT, 0, 1)

	local _, avgRunLevel, levelPressure = getRunPressure(elapsedSeconds)
	local levelProgress = math.clamp(avgRunLevel / BOSS_LEVEL_TARGET, 0, 1)

	local readiness = math.max(timeProgress, levelProgress)
	local hpMultiplier = BOSS_HP_MULT_EARLY + ((BOSS_HP_MULT_LATE - BOSS_HP_MULT_EARLY) * readiness) + (levelPressure * 0.08)
	return math.max(BOSS_BASE_HP, math.floor(BOSS_BASE_HP * hpMultiplier))
end

local function getBossCombatStatsForCurrentRun()
	local elapsedSeconds = math.max(0, elapsed())
	local timeProgress = math.clamp(elapsedSeconds / RUN_TIME_LIMIT, 0, 1)
	local _, avgRunLevel, levelPressure = getRunPressure(elapsedSeconds)
	local levelProgress = math.clamp(avgRunLevel / BOSS_LEVEL_TARGET, 0, 1)
	local readiness = math.max(timeProgress, levelProgress)

	return {
		hp = getBossHealthForCurrentRun(),
		speed = 9.8 + math.min(2.4, (levelPressure * 0.18) + (readiness * 1.0)),
		range = 9,
		cd = math.max(0.95, 1.35 - (readiness * 0.14)),
		dmg = math.max(24, math.floor(24 * (1 + (timeProgress * 0.42) + (levelPressure * 0.08)))),
	}
end

local function endRun(reason: string)
	reason = tostring(reason or "Victory")
	local eliteProgress = encounterScheduler:GetEliteProgress()
	broadcast({
		type = "complete",
		reason = reason,
		elitesDefeated = eliteProgress.defeated,
		elitesTotal = eliteProgress.total,
	})

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Parent and plr:GetAttribute("RunEnded") ~= true then
			pcall(function()
				require(ServerScriptService.ModuleScript.RunProgressApi).EndRunForPlayer(plr, reason)
			end)
		end
	end
end

local function watchEliteDeath(mob: Model)
    NpcService.BindDeath(mob, function()
        local defeated, total = encounterScheduler:RecordEliteDefeated()
        broadcast({ type = "eliteProgress", elitesDefeated = defeated, elitesTotal = total })
        broadcast({ type = "eliteDefeated", elitesDefeated = defeated, elitesTotal = total })
    end)
end
local function getWorldBoundsXZ()
	return WorldBounds.GetXZ(18, Vector2.new(-200, -200), Vector2.new(200, 200))
end

local function randomGroundPoint()
	local point = WorldBounds.FindRandomTerrainPoint({
		pad = 18,
		tries = 40,
		heightOffset = 2.2,
		raycastIgnoreInstances = buildSpawnRaycastIgnore(),
		overlapIgnoreInstances = buildSpawnOverlapIgnore(),
		clearanceRadius = 7.5,
		clearanceHeight = 12,
		maxSlopeDeg = 30,
		fallbackMin = Vector2.new(-200, -200),
		fallbackMax = Vector2.new(200, 200),
	})
	return point or Vector3.new(0, 5, 0)
end

local function getPortalController()
	if portalController then
		return portalController
	end

	portalController = RunPortalController.new({
		parent = workspace,
		getPortalPosition = randomGroundPoint,
		canUsePortal = function(plr)
			return RunStarted.Value == true and plr:GetAttribute("RunEnded") ~= true
		end,
		onActivated = function()
			bossSpawnPending = true
			broadcast({ type = "portalActivated" })
			if spawnBossNearPortal then
				spawnBossNearPortal()
			end
		end,
		onVictory = function()
			endRun("Victory")
		end,
	})
	return portalController
end

spawnBossNearPortal = function()
	local controller = getPortalController()
	local base = controller:GetBasePart()
	if not base then
		return false
	end
	if bossModel and bossModel.Parent then
		bossSpawnPending = false
		return true
	end
	if not hasEnemyCapacity(1) then
		return false
	end

	controller:SetBossDefeated(false)
	local bossName = "Golem" -- change if you have a dedicated boss model
	local tpl = EliteFolder:FindFirstChild(bossName) or NormalFolder:FindFirstChild(bossName)
	if not tpl or not tpl:IsA("Model") then
		warn("[Portal] Missing boss template:", bossName)
		bossSpawnPending = false
		return false
	end

	local mob = tpl:Clone()
	mob.Name = "Boss_" .. bossName
	cleanupTemplateScripts(mob)
	setMobGroup(mob)
	local bossConfig = ENEMY_CONFIGS[bossName]
	applyMobVisualScale(mob, true, true, bossConfig)
	mob:SetAttribute("SpawnSource", "Boss")
	mob.Parent = ENEMIES_FOLDER

	local desiredBossFrame = base.CFrame * CFrame.new(0, 0, -18)
	local bossIgnore = { mob }
	local bossGroundPoint = nil
	local bossHit = raycastGround(desiredBossFrame.Position, bossIgnore)
	if bossHit and bossHit.Position and slopeDeg(bossHit.Normal) <= MAX_GROUND_SLOPE_DEG then
		local clear = WorldBounds.IsAreaClear(
			bossHit.Position + Vector3.new(0, WorldBounds.SpawnGroundClearance, 0),
			7.5,
			12,
			buildSpawnOverlapIgnore(bossIgnore)
		)
		if clear == true then
			bossGroundPoint = bossHit.Position
		end
	end
	if not bossGroundPoint then
		bossGroundPoint = WorldBounds.FindNearbyTerrainPoint(desiredBossFrame.Position, {
			searchRadii = { 0, 5, 10, 15, 22, 30 },
			samplesPerRing = 12,
			heightOffset = 0,
			raycastIgnoreInstances = buildSpawnRaycastIgnore(bossIgnore),
			overlapIgnoreInstances = buildSpawnOverlapIgnore(bossIgnore),
			clearanceRadius = 7.5,
			clearanceHeight = 12,
			maxSlopeDeg = MAX_GROUND_SLOPE_DEG,
		})
	end
	if not bossGroundPoint then
		warn("[Portal] Could not find grounded boss spawn point near portal")
		mob:Destroy()
		return false
	end

	local bossGrounding = WorldBounds.BuildMobGrounding(mob, bossConfig)
	mob:PivotTo(WorldBounds.CFrameFromGround(bossGroundPoint, bossGrounding, WorldBounds.CFrameRotationOnly(base.CFrame)))

	local bossStats = getBossCombatStatsForCurrentRun()
	local registered = registerMobModel(mob, bossName, {
		hp = bossStats.hp,
		speed = bossStats.speed,
		range = bossStats.range,
		cd = bossStats.cd,
		dmg = bossStats.dmg,
		isRanged = false,
	}, { xp = 120, coins = 60 }, true, true, function()
		controller:SetBossDefeated(true)
		bossSpawnPending = false
		nextBossReinforcementAt = math.huge
		unregisterEncounterController(mob)
		broadcast({ type = "portalBossDefeated" })
	end)
	if not registered then
		return false
	end

	bossSpawnPending = false
	bossModel = registered
	registerBossController(registered, bossStats.dmg)
	nextBossReinforcementAt = math.huge
	pcall(function()
		require(ServerScriptService.ModuleScript.RunProgressApi).NotifyBossSpawn()
	end)
	broadcast({ type = "portalBossSpawn" })
	return true
end

local function ensurePortal()
	getPortalController():Ensure()
end

-- Keep portal present from the start of the run
RunStarted.Changed:Connect(function(v)
	if v == true then
		ensurePortal()
	else
		require(ServerScriptService.ModuleScript.AbilityHazards).CancelAll()
	end
end)

if RunStarted.Value == true then
	ensurePortal()
end

local function ensureDebugSettingsFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("DebugSettings")
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "DebugSettings"
	folder.Parent = ReplicatedStorage
	return folder
end

local function setDebugBool(name: string, value: boolean): boolean
	local folder = ensureDebugSettingsFolder()
	local flag = folder:FindFirstChild(name)
	if flag and not flag:IsA("BoolValue") then
		flag:Destroy()
		flag = nil
	end
	if not flag then
		flag = Instance.new("BoolValue")
		flag.Name = name
		flag.Parent = folder
	end
	flag.Value = value == true
	return flag.Value
end

local function resolveDebugSpawnName(mobName: string?, isElite: boolean): string?
	local cleaned = typeof(mobName) == "string" and string.gsub(mobName, "^%s*(.-)%s*$", "%1") or ""
	if cleaned ~= "" then
		return cleaned
	end

	if isElite then
		local scheduledElite = encounterScheduler:GetCurrentEliteName()
		if scheduledElite then
			return scheduledElite
		end
		local fallback = EliteFolder:FindFirstChildWhichIsA("Model")
		return fallback and fallback.Name or nil
	end

	local pool = getPool(elapsed())
	return pickWeighted(pool)
end

local function debugForceSpawn(mobName: string?, isElite: boolean, count: number?): {Model}
	local spawned = {}
	local targetCount = math.max(1, math.floor(tonumber(count) or 1))

	for _ = 1, targetCount do
		if not hasEnemyCapacity(1) then
			break
		end

		local chosenName = resolveDebugSpawnName(mobName, isElite)
		if not chosenName then
			break
		end

		local mob = spawnMob(chosenName, isElite, nil)
		if not mob then
			break
		end

		table.insert(spawned, mob)
	end

	return spawned
end

local function debugClearEnemies(): number
	local cleared = 0
	for _, enemy in ipairs(ENEMIES_FOLDER:GetChildren()) do
		if enemy:IsA("Model") then
			cleared += 1
			if NpcService and NpcService.Despawn then
				pcall(function()
					NpcService.Despawn(enemy)
				end)
			elseif enemy.Parent then
				enemy:Destroy()
			end
		end
	end
	return cleared
end

local function debugForceBossSpawn()
	ensurePortal()
	getPortalController():Activate()
	bossSpawnPending = true
	refreshPortalPromptState()
	if not spawnBossNearPortal then
		return nil
	end
	local ok = spawnBossNearPortal()
	refreshPortalPromptState()
	if not ok then
		return nil
	end
	return bossModel
end

if RunService:IsStudio() then
	requireServerModule("WaveDebugApi").Register({
		areAutoMobSpawnsEnabled = areAutoMobSpawnsEnabled,
		setAutoMobSpawnsEnabled = function(enabled: boolean)
			return setDebugBool("AutoMobSpawnsEnabled", enabled == true)
		end,
		forceSpawnMob = function(mobName: string?, isElite: boolean?, count: number?)
			return debugForceSpawn(mobName, isElite == true, count)
		end,
		forceEliteSpawn = function(mobName: string?, count: number?)
			return debugForceSpawn(mobName, true, count)
		end,
		forceBossSpawn = debugForceBossSpawn,
		clearEnemies = debugClearEnemies,
	})
end

-- Initial HUD ping
do
	local left, over = fmtTimePayload(0)
	local eliteProgress = encounterScheduler:GetEliteProgress()
	broadcast({
		type = "timeUpdate",
		seconds = 0,
		secondsLeft = left,
		overtime = over,
		nextEliteIn = encounterScheduler:GetNextEliteIn(0),
		elitesDefeated = 0,
		elitesTotal = eliteProgress.total,
		kills = 0,
		coins = 0,
		portalActivated = isPortalActivated(),
		bossDefeated = isBossDefeated(),
	})
end

local lastHudPush = 0

RunService.Heartbeat:Connect(function(dt)
    if not RunStarted.Value then
        return
    end
    local t = elapsed()
	if refreshPortalPromptState then
		refreshPortalPromptState()
	end

    if PauseState.Value then
        return
    end

    -- Stop if nobody is in a run / everyone ended.
    if not anyPlayersAlive() then
        return
    end

	stepEliteControllers(os.clock())
	stepBossController(os.clock())

    -- HUD update (4x/sec max)
	if t - lastHudPush >= 0.25 then
        lastHudPush = t
		local nextIn = encounterScheduler:GetNextEliteIn(t)
		local left, over = fmtTimePayload(t)
		local eliteProgress = encounterScheduler:GetEliteProgress()
        broadcast({
            type = "timeUpdate",
            seconds = math.floor(t),
			secondsLeft = math.floor(left),
			overtime = math.floor(over),
            nextEliteIn = nextIn and math.floor(nextIn) or nil,
            elitesDefeated = eliteProgress.defeated,
			elitesTotal = eliteProgress.total,
			kills = runKills,
			coins = runCoins,
			portalActivated = isPortalActivated(),
			bossDefeated = isBossDefeated(),
        })
	end

	if not areAutoMobSpawnsEnabled() then
		return
	end

    -- Elites (every 5 minutes during the scheduled run)
	local pendingEliteName = encounterScheduler:GetPendingElite(t)
    if pendingEliteName then
		if not hasEnemyCapacity(1, t) then
			encounterScheduler:RecordEliteSpawnResult(false, t)
		else
			local elite = spawnMob(pendingEliteName, true, nil)
			if elite then
				local eliteProgress = encounterScheduler:GetEliteProgress()
				broadcast({ type = "eliteSpawn", name = pendingEliteName, elitesDefeated = eliteProgress.defeated, elitesTotal = eliteProgress.total })
				watchEliteDeath(elite)
				encounterScheduler:RecordEliteSpawnResult(true, t)
			else
				-- Spawn could fail due temporary position/template issues; retry shortly.
				encounterScheduler:RecordEliteSpawnResult(false, t)
			end
        end
    end

	if isPortalActivated() and bossSpawnPending and not isBossDefeated() and (not bossModel or not bossModel.Parent) then
		spawnBossNearPortal()
	end

	local eliteEncounterActive = activeEliteEnemiesCount() > 0
	local swarmStep = encounterScheduler:StepSwarm(t, eliteEncounterActive)
	for _, event in ipairs(swarmStep.events) do
		broadcast(event)
	end
	if swarmStep.suppressAmbientNormals then
		for _, enemy in ipairs(ENEMIES_FOLDER:GetChildren()) do
			if enemy:IsA("Model") and enemy:GetAttribute("IsElite") ~= true and enemy:GetAttribute("IsBoss") ~= true then
				local source = enemy:GetAttribute("SpawnSource")
				if source == nil or source == "RunAmbient" or source == "RunSwarm" then
					NpcService.Despawn(enemy)
				end
			end
		end
	end

	local avgRunLevel = getAverageRunLevel()
	local stressBurstSize, stressIntervalScale, stressMaxAliveScale = getSpawnStressConfig()
	local encounterKind = getActiveImportantEncounter()
	local normalPlan = encounterScheduler:BuildNormalSpawnBudget(t, dt, eliteEncounterActive, avgRunLevel, {
		burstSize = stressBurstSize,
		intervalScale = stressIntervalScale,
	}, encounterKind)

	if normalPlan.pausedForElite then
		return
	end

	local scheduledSpawnBudget = normalPlan.scheduledSpawnBudget
	local catchupBudget = normalPlan.catchupBudget
	if scheduledSpawnBudget <= 0 and catchupBudget <= 0 then
		return
	end

	local maxAlive = encounterScheduler:DesiredMaxAlive(t, avgRunLevel, stressMaxAliveScale, encounterKind)
	local aliveNow = activeEnemiesCount()
	local normalAliveNow = activeNormalEnemiesCount()
	if encounterScheduler:ShouldTrimNormal(t, encounterKind, normalAliveNow, maxAlive) then
		local encounterConfig = encounterScheduler:RecordNormalTrim(t, encounterKind)
		if NpcService.DespawnOldestFarNormal(encounterConfig.trimDistance) then
			aliveNow = math.max(0, aliveNow - 1)
			normalAliveNow = math.max(0, normalAliveNow - 1)
		end
	end
	local pool = getPool(t)
	for _ = 1, (scheduledSpawnBudget + catchupBudget) do
		if aliveNow >= getMaxLivingEnemyCap(t) or normalAliveNow >= maxAlive then
			break
		end

		local mobName = pickWeighted(pool)
		local spawnSource = isSwarmActiveAt(t) and "RunSwarm" or "RunAmbient"
		local spawnedMob = spawnMob(mobName, false, nil, spawnSource)
		if spawnedMob then
			aliveNow += 1
			normalAliveNow += 1
			if scheduledSpawnBudget > 0 then
				scheduledSpawnBudget -= 1
			elseif catchupBudget > 0 then
				catchupBudget -= 1
				encounterScheduler:RecordNormalSpawned("catchup")
			end
		end
	end
end)

print("[HordeController] Ready (time-based)")
