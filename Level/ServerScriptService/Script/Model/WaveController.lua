-- WaveController.server.lua (Level1)
-- Reworked: time-based horde spawning (VS / Mega Bonk style)
-- No waves. Difficulty ramps with elapsed run time.
-- Elites spawn on a recurring timer during the run.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

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

local DamageService = (function()
	local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript")
	assert(moduleFolder and moduleFolder:IsA("Folder"), "[WaveController] ServerScriptService.ModuleScript folder is required")
	local damageServiceModule = moduleFolder:FindFirstChild("DamageService")
	assert(damageServiceModule and damageServiceModule:IsA("ModuleScript"), "[WaveController] DamageService ModuleScript is required for player damage")
	return require(damageServiceModule)
end)()
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
		root = nil,
		rootLocalCFrame = nil,
		rootGroundOffset = 0,
	}

	if not mob then
		return grounding
	end

	grounding.groundSnapDisabled = mob:GetAttribute("IgnoreGroundSnap") == true
		or mob:GetAttribute("CanFly") == true
		or (type(spawnConfig) == "table" and (spawnConfig.ignoreGroundSnap == true or spawnConfig.canFly == true))
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
		return CFrame.new(surfacePos + Vector3.new(0, WorldBounds.SpawnGroundClearance, 0)) * rootRotation
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
local materialRng = Random.new()
local MAX_LIVING_ENEMIES = math.max(1, math.floor(tonumber(RunSpawnConfig.MAX_LIVING_ENEMIES) or 100))
local NORMAL_SOUL_DROP_CONFIG = RunSpawnConfig.NORMAL_SOUL_DROP or {}
local LEVEL_SPAWN_BANDS = RunSpawnConfig.LEVEL_SPAWN_BANDS or {}
local OVERTIME_SPAWN_CONFIG = RunSpawnConfig.OVERTIME or {}
local SWARM_SPAWN_CONFIG = RunSpawnConfig.SWARM or {}
local IMPORTANT_ENCOUNTER_SPAWN_CONFIG = RunSpawnConfig.IMPORTANT_ENCOUNTER or {}
local DEFAULT_LEVEL_SPAWN_BAND = {
	baseMaxAlive = 24,
	alivePerMinute = 4,
	spawnBurst = 1,
	intervalMultiplier = 1,
}
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
local DEFAULT_IMPORTANT_ENCOUNTER_CONFIG = {
	maxAliveMultiplier = 1,
	intervalMultiplier = 1,
	burstMultiplier = 1,
	minNormalAlive = 0,
	trimInterval = 0,
	trimDistance = 0,
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
	if type(_G.GetAverageRunLevel) ~= "function" then
		return 0
	end

	local ok, value = pcall(function()
		return _G.GetAverageRunLevel()
	end)
	if not ok then
		return 0
	end

	return math.max(0, tonumber(value) or 0)
end

local function getRunPressure(elapsedSeconds: number)
	local minutes = math.floor(math.max(0, elapsedSeconds) / 60)
	local avgRunLevel = getAverageRunLevel()
	local levelPressure = math.max(0, avgRunLevel - 2)
	return minutes, avgRunLevel, levelPressure
end

local function getSpawnBand(avgRunLevel: number)
	local resolvedLevel = math.max(1, math.floor((tonumber(avgRunLevel) or 0) + 0.5))
	for _, band in ipairs(LEVEL_SPAWN_BANDS) do
		local minLevel = math.max(1, math.floor(tonumber(band.minLevel) or 1))
		local maxLevel = tonumber(band.maxLevel) or math.huge
		if resolvedLevel >= minLevel and resolvedLevel <= maxLevel then
			return band
		end
	end
	return LEVEL_SPAWN_BANDS[#LEVEL_SPAWN_BANDS] or DEFAULT_LEVEL_SPAWN_BAND
end

local function timeScaleMult(elapsed: number)
	local minutes, _, levelPressure = getRunPressure(elapsed)
	local hpMult = (1.07) ^ minutes * (1.14 ^ levelPressure)
	local dmgMult = (1.045) ^ minutes * (1.09 ^ levelPressure)
	local speedMult = math.min(1.35, 1 + (minutes * 0.015) + (levelPressure * 0.035))
	local cooldownMult = math.max(0.78, 1 - (minutes * 0.01) - (levelPressure * 0.025))
	return hpMult, dmgMult, speedMult, cooldownMult
end

local function getPool(elapsed: number)
    -- returns weighted pool (normal mobs)
    if elapsed < 90 then
        return { {"Slime", 100} }
    elseif elapsed < 210 then
        return { {"Slime", 58}, {"Zombie", 42} }
    elseif elapsed < 360 then
        return { {"Slime", 18}, {"Zombie", 38}, {"Skeleton", 28}, {"Grzyb", 16} }
    elseif elapsed < 540 then
        return { {"Zombie", 24}, {"Skeleton", 26}, {"Goblin", 26}, {"Grzyb", 16}, {"Slime", 8} }
    elseif elapsed < 720 then
        return { {"Skeleton", 22}, {"Goblin", 28}, {"Warewolf", 24}, {"Zombie", 16}, {"Grzyb", 10} }
    elseif elapsed < 900 then
        return { {"Goblin", 22}, {"Warewolf", 23}, {"Harp", 19}, {"Demon", 17}, {"Skeleton", 13}, {"Grzyb", 6} }
    elseif elapsed < 1080 then
        return { {"Warewolf", 22}, {"Harp", 20}, {"Demon", 20}, {"LandShark", 20}, {"Knight", 18} }
    elseif elapsed < 1200 then
        return { {"Harp", 18}, {"Demon", 18}, {"LandShark", 18}, {"Knight", 18}, {"Golem", 14}, {"Ent", 14} }
    else
        return { {"Goblin", 10}, {"Warewolf", 16}, {"Harp", 14}, {"Demon", 16}, {"LandShark", 16}, {"Golem", 12}, {"Knight", 10}, {"Ent", 6} }
    end
end

local function pickWeighted(pool)
    local total = 0
    for _, it in ipairs(pool) do total += it[2] end
    local r = math.random() * total
    local acc = 0
    for _, it in ipairs(pool) do
        acc += it[2]
        if r <= acc then
            return it[1]
        end
    end
    return pool[#pool][1]
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
	local cfg = kind and IMPORTANT_ENCOUNTER_SPAWN_CONFIG[kind] or nil
	if typeof(cfg) ~= "table" then
		cfg = DEFAULT_IMPORTANT_ENCOUNTER_CONFIG
	end
	return {
		maxAliveMultiplier = math.max(0.05, tonumber(cfg.maxAliveMultiplier) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.maxAliveMultiplier),
		intervalMultiplier = math.max(0.05, tonumber(cfg.intervalMultiplier) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.intervalMultiplier),
		burstMultiplier = math.max(0.05, tonumber(cfg.burstMultiplier) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.burstMultiplier),
		minNormalAlive = math.max(0, math.floor(tonumber(cfg.minNormalAlive) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.minNormalAlive)),
		trimInterval = math.max(0, tonumber(cfg.trimInterval) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.trimInterval),
		trimDistance = math.max(0, tonumber(cfg.trimDistance) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.trimDistance),
	}
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
	local runSeconds = (_G.GetRunSeconds and _G.GetRunSeconds()) or 0
	local minutes, _, levelPressure = getRunPressure(runSeconds)

	if _G.RegisterEnemyKill then
        pcall(function() _G.RegisterEnemyKill(pos, killer) end)
    end

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

    local hpMult, dmgMult, speedMult, cooldownMult = timeScaleMult(_G.GetRunSeconds and _G.GetRunSeconds() or 0)
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

local function flatVector(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function groundify(pos: Vector3): Vector3
	local hit = raycastGround(pos)
	if hit and hit.Position then
		return hit.Position + Vector3.new(0, 0.2, 0)
	end
	return pos
end

local function distancePointToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom <= 1e-4 then
		return (point - a).Magnitude
	end
	local t = math.clamp(((point - a):Dot(ab)) / denom, 0, 1)
	local projection = a + (ab * t)
	return (point - projection).Magnitude
end

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

local function applyAbilityDamageToPlayer(player: Player, amount: number, context: {[string]: any}?)
	amount = math.max(1, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return
	end

	local damageContext = nil
	if typeof(context) == "table" then
		damageContext = {
			sourceType = context.sourceType,
		}
		if context.abilityId ~= nil then
			damageContext.abilityId = context.abilityId
		end
	end

	DamageService.Apply(player, amount, damageContext)
end

local function makeTelegraphPart(name: string, color: Color3, transparency: number)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.CastShadow = false
	part.Color = color
	part.Transparency = transparency
	part.Parent = AbilityVfxFolder
	return part
end

local function telegraphCircle(center: Vector3, radius: number, duration: number, color: Color3?)
	local disk = makeTelegraphPart("TelegraphCircle", color or ABILITY_COLORS.Elite, 0.30)
	disk.Shape = Enum.PartType.Cylinder
	disk.Size = Vector3.new(radius * 2, 0.12, radius * 2)
	disk.CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(disk, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Transparency = 0.75,
		Size = Vector3.new(radius * 2.18, 0.12, radius * 2.18),
	}):Play()
	Debris:AddItem(disk, duration + 0.2)
	return disk
end

local function telegraphLine(startPos: Vector3, endPos: Vector3, width: number, duration: number, color: Color3?)
	local dir = endPos - startPos
	local length = math.max(1, dir.Magnitude)
	local beam = makeTelegraphPart("TelegraphLine", color or ABILITY_COLORS.Elite, 0.36)
	beam.Size = Vector3.new(width, 0.18, length)
	beam.CFrame = CFrame.lookAt(startPos:Lerp(endPos, 0.5) + Vector3.new(0, 0.2, 0), endPos + Vector3.new(0, 0.2, 0))
	TweenService:Create(beam, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Transparency = 0.8,
		Size = Vector3.new(width * 1.08, 0.18, length),
	}):Play()
	Debris:AddItem(beam, duration + 0.2)
	return beam
end

local function burstMarker(pos: Vector3, color: Color3?, scale: number?, duration: number?)
	local burst = makeTelegraphPart("AbilityBurst", color or ABILITY_COLORS.Elite, 0.16)
	burst.Shape = Enum.PartType.Ball
	local size = math.max(1, tonumber(scale) or 1)
	burst.Size = Vector3.new(size, size, size)
	burst.CFrame = CFrame.new(pos)
	TweenService:Create(burst, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(size * 2.2, size * 2.2, size * 2.2),
	}):Play()
	Debris:AddItem(burst, (duration or 0.35) + 0.1)
end

local function damagePlayersInRadius(center: Vector3, radius: number, damage: number, context: {[string]: any}?)
	for _, info in ipairs(getAliveCombatPlayers()) do
		if (info.hrp.Position - center).Magnitude <= radius then
			applyAbilityDamageToPlayer(info.player, damage, context)
		end
	end
end

local function damagePlayersAlongLine(startPos: Vector3, endPos: Vector3, width: number, damage: number, context: {[string]: any}?)
	for _, info in ipairs(getAliveCombatPlayers()) do
		if (info.hrp.Position - startPos).Magnitude <= ((endPos - startPos).Magnitude + width + 2)
			and distancePointToSegment(info.hrp.Position, startPos, endPos) <= width
		then
			applyAbilityDamageToPlayer(info.player, damage, context)
		end
	end
end

local function damagePlayersInCone(origin: Vector3, forward: Vector3, range: number, halfAngleDeg: number, damage: number, context: {[string]: any}?)
	local flatForward = flatVector(forward)
	if flatForward.Magnitude <= 1e-4 then
		return
	end
	flatForward = flatForward.Unit
	local dotMin = math.cos(math.rad(halfAngleDeg))
	for _, info in ipairs(getAliveCombatPlayers()) do
		local toPlayer = flatVector(info.hrp.Position - origin)
		if toPlayer.Magnitude <= range and toPlayer.Magnitude > 1e-4 then
			if flatForward:Dot(toPlayer.Unit) >= dotMin then
				applyAbilityDamageToPlayer(info.player, damage, context)
			end
		end
	end
end

local function createHazardZone(center: Vector3, radius: number, duration: number, tickRate: number, damage: number, color: Color3?, context: {[string]: any}?)
	local zone = telegraphCircle(center, radius, duration, color)
	zone.Transparency = 0.48
	task.spawn(function()
		local remaining = math.max(0.05, tonumber(duration) or 0)
		while remaining > 0 do
			if not RunStarted.Value or not anyPlayersAlive() then
				return
			end
			if PauseState.Value then
				task.wait(0.1)
			else
				damagePlayersInRadius(center, radius, damage, context)
				local step = math.min(math.max(0.05, tonumber(tickRate) or 0.5), remaining)
				task.wait(step)
				remaining -= step
			end
		end
	end)
end

local function scheduleGameplayDelay(delaySeconds: number, callback: () -> ())
	task.spawn(function()
		local remaining = math.max(0, tonumber(delaySeconds) or 0)
		while remaining > 0 do
			if not RunStarted.Value or not anyPlayersAlive() then
				return
			end
			if PauseState.Value then
				task.wait(0.1)
			else
				local step = math.min(0.1, remaining)
				task.wait(step)
				remaining -= step
			end
		end
		if PauseState.Value or not RunStarted.Value or not anyPlayersAlive() then
			return
		end
		callback()
	end)
end

local function abilityReady(controller, abilityId: string, now: number)
	return now >= (controller.globalCooldown or 0) and now >= ((controller.cooldowns and controller.cooldowns[abilityId]) or 0)
end

local function setAbilityCooldown(controller, abilityId: string, now: number, cooldown: number, globalCooldown: number?)
	local scale = tonumber(controller.cooldownScale) or 1
	controller.cooldowns = controller.cooldowns or {}
	controller.cooldowns[abilityId] = now + (cooldown * scale)
	controller.globalCooldown = now + ((globalCooldown or 1.25) * scale)
end

local function castTargetImpact(controller, targetInfo, now, cfg)
	local targetPos = targetInfo and groundify(targetInfo.hrp.Position) or nil
	if not targetPos then
		return false
	end
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	telegraphCircle(targetPos, cfg.radius, cfg.telegraph, cfg.color)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			burstMarker(targetPos, cfg.color, cfg.radius * 0.45, 0.4)
			damagePlayersInRadius(targetPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
		end
	end)
	return true
end

local function castGroundSlam(controller, targetInfo, now, cfg)
	local center = NpcService.GetPosition(controller.model)
	if not center then
		return false
	end
	center = groundify(center)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetInfo and targetInfo.hrp.Position or center)
	telegraphCircle(center, cfg.radius, cfg.telegraph, cfg.color)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			local currentPos = NpcService.GetPosition(controller.model) or center
			burstMarker(currentPos, cfg.color, cfg.radius * 0.55, 0.45)
			damagePlayersInRadius(currentPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
		end
	end)
	return true
end

local function castDash(controller, targetInfo, now, cfg)
	local startPos = NpcService.GetPosition(controller.model)
	local targetPos = targetInfo and groundify(targetInfo.hrp.Position) or nil
	if not startPos or not targetPos then
		return false
	end
	local dir = flatVector(targetPos - startPos)
	if dir.Magnitude <= 1e-4 then
		return false
	end
	dir = dir.Unit
	local dashDistance = math.min(cfg.distance, math.max(6, (targetPos - startPos).Magnitude - 2))
	local endPos = startPos + (dir * dashDistance)
	endPos = groundify(endPos)
	telegraphLine(startPos, endPos, cfg.width, cfg.telegraph, cfg.color)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			NpcService.SetPosition(controller.model, endPos, dir)
			burstMarker(endPos, cfg.color, cfg.width * 0.8, 0.35)
			damagePlayersAlongLine(startPos, endPos, cfg.width, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
		end
	end)
	return true
end

local function castLineStrike(controller, targetInfo, now, cfg)
	local startPos = NpcService.GetPosition(controller.model)
	local targetPos = targetInfo and groundify(targetInfo.hrp.Position) or nil
	if not startPos or not targetPos then
		return false
	end
	local dir = flatVector(targetPos - startPos)
	if dir.Magnitude <= 1e-4 then
		return false
	end
	dir = dir.Unit
	local strikeDistance = math.min(cfg.distance, math.max(8, (targetPos - startPos).Magnitude))
	local endPos = groundify(startPos + (dir * strikeDistance))
	telegraphLine(startPos, endPos, cfg.width, cfg.telegraph, cfg.color)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			damagePlayersAlongLine(startPos, endPos, cfg.width, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			burstMarker(endPos, cfg.color, cfg.width * 0.7, 0.35)
		end
	end)
	return true
end

local function castCone(controller, targetInfo, now, cfg)
	local startPos = NpcService.GetPosition(controller.model)
	local targetPos = targetInfo and groundify(targetInfo.hrp.Position) or nil
	if not startPos or not targetPos then
		return false
	end
	local dir = flatVector(targetPos - startPos)
	if dir.Magnitude <= 1e-4 then
		return false
	end
	telegraphCircle(startPos + (dir.Unit * math.min(cfg.range * 0.45, 6)), cfg.range * 0.52, cfg.telegraph, cfg.color)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			damagePlayersInCone(startPos, dir.Unit, cfg.range, cfg.angle, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			burstMarker(startPos + (dir.Unit * math.min(cfg.range * 0.55, 7)), cfg.color, cfg.range * 0.20, 0.32)
		end
	end)
	return true
end

local function castTripleCombo(controller, targetInfo, now, cfg)
	local startPos = NpcService.GetPosition(controller.model)
	local targetPos = targetInfo and groundify(targetInfo.hrp.Position) or nil
	if not startPos or not targetPos then
		return false
	end
	local dir = flatVector(targetPos - startPos)
	if dir.Magnitude <= 1e-4 then
		return false
	end
	NpcService.LockForAbility(controller.model, cfg.totalDuration, targetPos)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for _, hitDelay in ipairs(cfg.hitDelays) do
			scheduleGameplayDelay(hitDelay, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				damagePlayersInCone(startPos, dir.Unit, cfg.range, cfg.angle, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
				burstMarker(startPos + (dir.Unit * math.min(cfg.range * 0.5, 6)), cfg.color, cfg.range * 0.16, 0.20)
			end
		end)
	end
	return true
end

local function castArmorUp(controller, now, cfg)
	NpcService.SetIncomingDamageModifier(controller.model, cfg.damageTakenMult, cfg.duration)
	local pos = NpcService.GetPosition(controller.model)
	if pos then
		burstMarker(pos, cfg.color, 5, 0.45)
	end
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	return true
end

local function castVolley(controller, targetInfo, now, cfg)
	local targetPos = targetInfo and groundify(targetInfo.hrp.Position) or nil
	if not targetPos then
		return false
	end
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for index = 1, cfg.count do
		local angle = ((index - 1) / math.max(1, cfg.count)) * math.pi * 2
		local impactPos = groundify(targetPos + Vector3.new(math.cos(angle) * cfg.spread, 0, math.sin(angle) * cfg.spread))
		telegraphCircle(impactPos, cfg.radius, cfg.telegraph, cfg.color)
		task.delay(cfg.telegraph, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				burstMarker(impactPos, cfg.color, cfg.radius * 0.45, 0.35)
				damagePlayersInRadius(impactPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			end
		end)
	end
	return true
end

local function castTeleportStep(controller, targetInfo, now, cfg)
	local targetPos = targetInfo and groundify(targetInfo.hrp.Position) or nil
	if not targetPos then
		return false
	end
	local offsetBase = flatVector(targetPos - (NpcService.GetPosition(controller.model) or targetPos))
	if offsetBase.Magnitude <= 1e-4 then
		offsetBase = Vector3.new(1, 0, 0)
	end
	local side = Vector3.new(-offsetBase.Z, 0, offsetBase.X).Unit * (math.random() < 0.5 and -cfg.distance or cfg.distance)
	local endPos = groundify(targetPos + side)
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			NpcService.SetPosition(controller.model, endPos, flatVector(targetPos - endPos))
			burstMarker(endPos, cfg.color, cfg.radius * 0.55, 0.35)
			damagePlayersInRadius(endPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
		end
	end)
	return true
end

local function castHazard(controller, targetInfo, now, cfg)
	local targetPos = targetInfo and groundify(targetInfo.hrp.Position) or nil
	if not targetPos then
		return false
	end
	NpcService.LockForAbility(controller.model, cfg.telegraph, targetPos)
	telegraphCircle(targetPos, cfg.radius, cfg.telegraph, cfg.color)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	task.delay(cfg.telegraph, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			createHazardZone(
				targetPos,
				cfg.radius,
				cfg.duration,
				cfg.tickRate,
				math.floor(controller.baseDamage * cfg.damageMultiplier),
				cfg.color,
				{ sourceType = "hazard", abilityId = cfg.id }
			)
		end
	end)
	return true
end

local function castSummon(controller, now, cfg)
	local bossPos = NpcService.GetPosition(controller.model)
	if not bossPos then
		return false
	end
	bossPos = groundify(bossPos)
	NpcService.LockForAbility(controller.model, cfg.telegraph or 0.6, bossPos)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	scheduleGameplayDelay(cfg.telegraph or 0.6, function()
		if controller.model.Parent and NpcService.IsAlive(controller.model) then
			spawnBurst(cfg.count, bossPos, math.max(elapsed(), RUN_TIME_LIMIT - 60), "BossSummon")
			burstMarker(bossPos, cfg.color, 6, 0.5)
		end
	end)
	return true
end

local function castShockwaveSequence(controller, targetInfo, now, cfg)
	local center = NpcService.GetPosition(controller.model)
	if not center then
		return false
	end
	center = groundify(center)
	local longestDelay = 0
	for _, pulse in ipairs(cfg.pulses) do
		longestDelay = math.max(longestDelay, pulse.delay)
	end
	NpcService.LockForAbility(controller.model, longestDelay, targetInfo and targetInfo.hrp.Position or center)
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for _, pulse in ipairs(cfg.pulses) do
		telegraphCircle(center, pulse.radius, pulse.delay, cfg.color)
			scheduleGameplayDelay(pulse.delay, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				burstMarker(center, cfg.color, pulse.radius * 0.35, 0.35)
				damagePlayersInRadius(center, pulse.radius, math.floor(controller.baseDamage * pulse.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			end
		end)
	end
	return true
end

local function castMeteorRain(controller, now, cfg)
	local players = getAliveCombatPlayers()
	if #players <= 0 then
		return false
	end
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for index = 1, cfg.count do
		local info = players[((index - 1) % #players) + 1]
		local impactPos = groundify(info.hrp.Position + Vector3.new(math.random(-cfg.spread, cfg.spread), 0, math.random(-cfg.spread, cfg.spread)))
		telegraphCircle(impactPos, cfg.radius, cfg.telegraph, cfg.color)
		task.delay(cfg.telegraph, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				burstMarker(impactPos, cfg.color, cfg.radius * 0.55, 0.45)
				damagePlayersInRadius(impactPos, cfg.radius, math.floor(controller.baseDamage * cfg.damageMultiplier), { sourceType = "ability", abilityId = cfg.id })
			end
		end)
	end
	return true
end

local function castArenaPressure(controller, now, cfg)
	local players = getAliveCombatPlayers()
	if #players <= 0 then
		return false
	end
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	for _, info in ipairs(players) do
		local offset = Vector3.new(math.random(-cfg.spread, cfg.spread), 0, math.random(-cfg.spread, cfg.spread))
		local center = groundify(info.hrp.Position + offset)
		telegraphCircle(center, cfg.radius, cfg.telegraph, cfg.color)
		task.delay(cfg.telegraph, function()
			if controller.model.Parent and NpcService.IsAlive(controller.model) then
				createHazardZone(center, cfg.radius, cfg.duration, cfg.tickRate, math.floor(controller.baseDamage * cfg.damageMultiplier), cfg.color, { sourceType = "hazard", abilityId = cfg.id })
			end
		end)
	end
	return true
end

local function castEnrage(controller, now, cfg)
	if controller.enraged then
		return false
	end
	controller.enraged = true
	controller.cooldownScale = cfg.cooldownScale
	controller.baseDamage *= cfg.damageMultiplier
	local bossPos = NpcService.GetPosition(controller.model)
	if bossPos then
		burstMarker(bossPos, cfg.color, 8, 0.55)
	end
	setAbilityCooldown(controller, cfg.id, now, cfg.cooldown, cfg.globalCooldown)
	return true
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

local function tryCastAbility(controller, targetInfo, now, cfg)
	if not abilityReady(controller, cfg.id, now) then
		return false
	end
	if cfg.kind == "TargetImpact" then
		return castTargetImpact(controller, targetInfo, now, cfg)
	elseif cfg.kind == "GroundSlam" then
		return castGroundSlam(controller, targetInfo, now, cfg)
	elseif cfg.kind == "Dash" then
		return castDash(controller, targetInfo, now, cfg)
	elseif cfg.kind == "LineStrike" then
		return castLineStrike(controller, targetInfo, now, cfg)
	elseif cfg.kind == "Cone" then
		return castCone(controller, targetInfo, now, cfg)
	elseif cfg.kind == "TripleCombo" then
		return castTripleCombo(controller, targetInfo, now, cfg)
	elseif cfg.kind == "ArmorUp" then
		return castArmorUp(controller, now, cfg)
	elseif cfg.kind == "Volley" then
		return castVolley(controller, targetInfo, now, cfg)
	elseif cfg.kind == "TeleportStep" then
		return castTeleportStep(controller, targetInfo, now, cfg)
	elseif cfg.kind == "Hazard" then
		return castHazard(controller, targetInfo, now, cfg)
	elseif cfg.kind == "Summon" then
		return castSummon(controller, now, cfg)
	elseif cfg.kind == "ShockwaveSequence" then
		return castShockwaveSequence(controller, targetInfo, now, cfg)
	elseif cfg.kind == "MeteorRain" then
		return castMeteorRain(controller, now, cfg)
	elseif cfg.kind == "ArenaPressure" then
		return castArenaPressure(controller, now, cfg)
	elseif cfg.kind == "Enrage" then
		return castEnrage(controller, now, cfg)
	end
	return false
end

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

-- Expose run seconds for other scripts if needed
_G.GetRunSeconds = function()
    return math.floor(elapsed())
end


-- Counters for InfoUI (must be defined before wrappers below)
local runKills = 0
local runCoins = 0
-- Track kills + coins for InfoUI.
-- Coins are counted when the player actually picks them up (AwardPlayer).
if not _G.__InfoUI_Wrapped then
	_G.__InfoUI_Wrapped = true

	-- Kills: WaveController already calls _G.RegisterEnemyKill on enemy death.
	local prevKill = _G.RegisterEnemyKill
	_G.RegisterEnemyKill = function(pos, killer)
		runKills += 1
		if prevKill then
			pcall(function()
				prevKill(pos, killer)
			end)
		end
	end

	-- Coins: wrap AwardPlayer *when it exists* (ProgressService defines it).
	task.spawn(function()
		local waited = 0
		while type(_G.AwardPlayer) ~= "function" and waited < 10 do
			waited += 0.1
			task.wait(0.1)
		end
		if type(_G.AwardPlayer) ~= "function" then return end

		local prevAward = _G.AwardPlayer
		_G.AwardPlayer = function(plr: Player, xp: number, coins: number)
			xp = math.max(0, math.floor(tonumber(xp) or 0))
			coins = math.max(0, math.floor(tonumber(coins) or 0))
			if coins > 0 then runCoins += coins end
			return prevAward(plr, xp, coins)
		end
	end)
end

local SWARM_EVENT_TIMES = { 240, 720 } -- 4:00, 12:00
local SWARM_DURATION = 60

local swarmState = {
	index = 1,
	nextAt = SWARM_EVENT_TIMES[1] or math.huge,
	active = false,
	activeUntil = 0,
	queuedDuration = 0,
	eliteSuppressionActive = false,
}
local normalSpawnState = {
	nextAt = 0,
	debt = 0,
	catchupAccumulator = 0,
	wasEliteEncounterActive = false,
	nextEncounterTrimAt = 0,
}

local function isSwarmActiveAt(t: number): boolean
    return swarmState.active and t < swarmState.activeUntil
end

getMaxLivingEnemyCap = function(t: number?): number
	local currentTime = math.max(0, tonumber(t) or elapsed())
	if isSwarmActiveAt(currentTime) then
		return spawnLimitConfig.swarmMaxLivingEnemies
	end
	return MAX_LIVING_ENEMIES
end

local function hasEnemyCapacity(slotsNeeded: number?, t: number?): boolean
	local needed = math.max(1, math.floor(tonumber(slotsNeeded) or 1))
	return (activeEnemiesCount() + needed) <= getMaxLivingEnemyCap(t)
end

local function desiredMaxAlive(t: number)
	local minutes, avgRunLevel = getRunPressure(t)
	local band = getSpawnBand(avgRunLevel)
	local base = math.max(1, math.floor(tonumber(band.baseMaxAlive) or DEFAULT_LEVEL_SPAWN_BAND.baseMaxAlive))
	local addPerMinute = math.max(0, math.floor(tonumber(band.alivePerMinute) or DEFAULT_LEVEL_SPAWN_BAND.alivePerMinute))
	local v = base + (minutes * addPerMinute)
	if t >= RUN_TIME_LIMIT then
		local overtimeBase = math.max(0, math.floor(tonumber(OVERTIME_SPAWN_CONFIG.extraMaxAlive) or 0))
		local overtimeStepSeconds = math.max(1, math.floor(tonumber(OVERTIME_SPAWN_CONFIG.maxAliveStepSeconds) or 12))
		local overtimeStepAmount = math.max(0, math.floor(tonumber(OVERTIME_SPAWN_CONFIG.maxAliveStepAmount) or 0))
		v += overtimeBase + (math.floor((t - RUN_TIME_LIMIT) / overtimeStepSeconds) * overtimeStepAmount)
	end
	local _, _, maxAliveScale = getSpawnStressConfig()
	local scaled = math.max(base, math.floor((v * maxAliveScale) + 0.5))
	local _, encounterConfig = getActiveImportantEncounter()
	scaled = math.max(
		encounterConfig.minNormalAlive,
		math.floor((scaled * encounterConfig.maxAliveMultiplier) + 0.5)
	)
	if isSwarmActiveAt(t) and spawnLimitConfig.swarmTargetMaxAlive > 0 then
		scaled = math.max(scaled, spawnLimitConfig.swarmTargetMaxAlive)
	end
	return math.clamp(scaled, math.max(1, encounterConfig.minNormalAlive), getMaxLivingEnemyCap(t))
end

local function spawnInterval(t: number)
	local _, avgRunLevel, levelPressure = getRunPressure(t)
	local band = getSpawnBand(avgRunLevel)
	local minI = 0.24
	local maxI = 0.56
	local p = math.clamp(t / 1500, 0, 1)
	local i = maxI - (maxI - minI) * p
	i = i / (1 + (levelPressure * 0.08))
	i *= math.max(0.05, tonumber(band.intervalMultiplier) or DEFAULT_LEVEL_SPAWN_BAND.intervalMultiplier)
	if t >= RUN_TIME_LIMIT then
		i = math.max(0.09, i * math.max(0.05, tonumber(OVERTIME_SPAWN_CONFIG.intervalMultiplier) or 0.42))
	end
	if isSwarmActiveAt(t) then
		i = math.max(0.08, i * math.max(0.05, tonumber(SWARM_SPAWN_CONFIG.intervalMultiplier) or 0.33))
	end
	local _, intervalScale = getSpawnStressConfig()
	local _, encounterConfig = getActiveImportantEncounter()
	return math.max(0.04, i * intervalScale * encounterConfig.intervalMultiplier)
end

local function getNormalSpawnBurstSize(t: number): number
	local _, avgRunLevel = getRunPressure(t)
	local band = getSpawnBand(avgRunLevel)
	local burst = math.max(1, math.floor(tonumber(band.spawnBurst) or DEFAULT_LEVEL_SPAWN_BAND.spawnBurst))
	if isSwarmActiveAt(t) then
		burst += math.max(0, math.floor(tonumber(SWARM_SPAWN_CONFIG.extraBurst) or 0))
	end
	if t >= RUN_TIME_LIMIT then
		burst += math.max(0, math.floor(tonumber(OVERTIME_SPAWN_CONFIG.extraBurst) or 0))
	end
	local debugBurstSize = select(1, getSpawnStressConfig())
	local _, encounterConfig = getActiveImportantEncounter()
	local scaledBurst = math.floor((burst * debugBurstSize * encounterConfig.burstMultiplier) + 0.5)
	return math.max(1, scaledBurst)
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

local eliteCount = 0
local eliteOrder = buildEliteOrder()
local eliteTotal = (#eliteOrder > 0) and math.max(1, math.floor(RUN_TIME_LIMIT / ELITE_INTERVAL_SECONDS)) or 0
local eliteIndex = 1 -- next elite to spawn
local nextEliteAt = eliteTotal > 0 and ELITE_INTERVAL_SECONDS or math.huge
-- === Portal + Boss end condition ===
local portalModel: Model? = nil
local portalActivated = false
local bossModel: Model? = nil
local bossSpawnPending = false
local bossDefeated = false
local nextBossReinforcementAt = math.huge
local refreshPortalPromptState = nil
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
	broadcast({
		type = "complete",
		reason = reason,
		elitesDefeated = eliteCount,
		elitesTotal = eliteTotal,
	})

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Parent and plr:GetAttribute("RunEnded") ~= true then
			if _G.EndRunForPlayer then
				pcall(function() _G.EndRunForPlayer(plr, reason) end)
			elseif _G.EndRun then
				pcall(function() _G.EndRun(reason) end)
			end
		end
	end
end

local function watchEliteDeath(mob: Model)
    NpcService.BindDeath(mob, function()
        eliteCount += 1
        broadcast({ type = "eliteProgress", elitesDefeated = eliteCount, elitesTotal = eliteTotal })
        broadcast({ type = "eliteDefeated", elitesDefeated = eliteCount, elitesTotal = eliteTotal })
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

local function ensurePortal()
	if portalModel and portalModel.Parent then return end

	local m = Instance.new("Model")
	m.Name = "RunPortal"

	local base = Instance.new("Part")
	base.Name = "Portal"
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.Material = Enum.Material.Neon
	base.Size = Vector3.new(10, 10, 1)
	base.CFrame = CFrame.new(randomGroundPoint()) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	base.Parent = m

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PortalPrompt"
	prompt.ActionText = "Awaken Boss"
	prompt.ObjectText = "Portal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	local function setPromptState()
		if not portalActivated then
			prompt.ActionText = "Awaken Boss"
			prompt.ObjectText = "Portal"
			prompt.Enabled = true
		elseif not bossDefeated then
			prompt.ActionText = "Boss Active"
			prompt.ObjectText = "Portal"
			prompt.Enabled = false
		else
			prompt.ActionText = "Enter Portal"
			prompt.ObjectText = "Portal"
			prompt.Enabled = true
		end
	end

	spawnBossNearPortal = function()
		if bossModel and bossModel.Parent then
			bossSpawnPending = false
			return true
		end
		if not hasEnemyCapacity(1) then
			return false
		end

		bossDefeated = false
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
			bossDefeated = true
			bossSpawnPending = false
			nextBossReinforcementAt = math.huge
			unregisterEncounterController(mob)
			broadcast({ type = "portalBossDefeated" })
			setPromptState()
		end)
		if not registered then
			return false
		end

		bossSpawnPending = false
		bossModel = registered
		registerBossController(registered, bossStats.dmg)
		nextBossReinforcementAt = math.huge
		if type(_G.NotifyBossSpawn) == "function" then
			pcall(function()
				_G.NotifyBossSpawn()
			end)
		end
		broadcast({ type = "portalBossSpawn" })
		return true
	end

	prompt.Triggered:Connect(function(plr)
		if not RunStarted.Value then return end
		if plr:GetAttribute("RunEnded") == true then return end

		if not portalActivated then
			portalActivated = true
			bossSpawnPending = true
			broadcast({ type = "portalActivated" })
			spawnBossNearPortal()
			setPromptState()
			return
		end

		if bossDefeated then
			endRun("Victory")
		end
	end)

	setPromptState()
	refreshPortalPromptState = setPromptState
	m.PrimaryPart = base
	m.Parent = workspace
	portalModel = m
end

-- Keep portal present from the start of the run
RunStarted.Changed:Connect(function(v)
	if v == true then
		ensurePortal()
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
		if #eliteOrder > 0 then
			return eliteOrder[((eliteIndex - 1) % #eliteOrder) + 1]
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

_G.DebugAreAutoMobSpawnsEnabled = areAutoMobSpawnsEnabled
_G.DebugSetAutoMobSpawnsEnabled = function(enabled: boolean)
	return setDebugBool("AutoMobSpawnsEnabled", enabled == true)
end
_G.DebugForceSpawnMob = function(mobName: string?, isElite: boolean?, count: number?)
	return debugForceSpawn(mobName, isElite == true, count)
end
_G.DebugForceEliteSpawn = function(mobName: string?, count: number?)
	return debugForceSpawn(mobName, true, count)
end
_G.DebugForceBossSpawn = function()
	ensurePortal()
	portalActivated = true
	bossDefeated = false
	bossSpawnPending = true
	if refreshPortalPromptState then
		refreshPortalPromptState()
	end
	if not spawnBossNearPortal then
		return nil
	end
	local ok = spawnBossNearPortal()
	if refreshPortalPromptState then
		refreshPortalPromptState()
	end
	if not ok then
		return nil
	end
	return bossModel
end
_G.DebugClearEnemies = debugClearEnemies

-- Initial HUD ping
do
	local left, over = fmtTimePayload(0)
	broadcast({
		type = "timeUpdate",
		seconds = 0,
		secondsLeft = left,
		overtime = over,
		nextEliteIn = (eliteIndex <= eliteTotal) and nextEliteAt or nil,
		elitesDefeated = 0,
		elitesTotal = eliteTotal,
		kills = 0,
		coins = 0,
		portalActivated = portalActivated,
		bossDefeated = bossDefeated,
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
		local nextIn = nil
		if eliteIndex <= eliteTotal and nextEliteAt < math.huge then
			nextIn = math.max(0, nextEliteAt - t)
		end
		local left, over = fmtTimePayload(t)
        broadcast({
            type = "timeUpdate",
            seconds = math.floor(t),
			secondsLeft = math.floor(left),
			overtime = math.floor(over),
            nextEliteIn = nextIn and math.floor(nextIn) or nil,
            elitesDefeated = eliteCount,
            elitesTotal = eliteTotal,
			kills = runKills,
			coins = runCoins,
			portalActivated = portalActivated,
			bossDefeated = bossDefeated,
        })
	end

	if not areAutoMobSpawnsEnabled() then
		return
	end

    -- Elites (every 5 minutes during the scheduled run)
    if eliteIndex <= eliteTotal and t >= nextEliteAt then
		if not hasEnemyCapacity(1, t) then
			nextEliteAt = t + 1
		else
			local eliteName = eliteOrder[((eliteIndex - 1) % #eliteOrder) + 1]
			local elite = spawnMob(eliteName, true, nil)
			if elite then
				broadcast({ type = "eliteSpawn", name = eliteName, elitesDefeated = eliteCount, elitesTotal = eliteTotal })
				watchEliteDeath(elite)
				eliteIndex += 1
				nextEliteAt = eliteIndex <= eliteTotal and (eliteIndex * ELITE_INTERVAL_SECONDS) or math.huge
			else
				-- Spawn could fail due temporary position/template issues; retry shortly.
				nextEliteAt = t + 1
			end
        end
    end

	if portalActivated and bossSpawnPending and not bossDefeated and (not bossModel or not bossModel.Parent) then
		spawnBossNearPortal()
	end

	local eliteEncounterActive = activeEliteEnemiesCount() > 0
	while swarmState.index <= #SWARM_EVENT_TIMES and t >= swarmState.nextAt do
		swarmState.queuedDuration += SWARM_DURATION
		swarmState.index += 1
		swarmState.nextAt = SWARM_EVENT_TIMES[swarmState.index] or math.huge
	end
	if eliteEncounterActive then
		if swarmState.active then
			swarmState.queuedDuration += math.max(0, swarmState.activeUntil - t)
			swarmState.active = false
			swarmState.activeUntil = 0
			broadcast({ type = "swarmEnd" })
		end
		if not swarmState.eliteSuppressionActive then
			swarmState.eliteSuppressionActive = true
			for _, enemy in ipairs(ENEMIES_FOLDER:GetChildren()) do
				if enemy:IsA("Model") and enemy:GetAttribute("IsElite") ~= true and enemy:GetAttribute("IsBoss") ~= true then
					local source = enemy:GetAttribute("SpawnSource")
					if source == nil or source == "RunAmbient" or source == "RunSwarm" then
						NpcService.Despawn(enemy)
					end
				end
			end
		end
	else
		swarmState.eliteSuppressionActive = false
		if swarmState.active and t >= swarmState.activeUntil then
			swarmState.active = false
			swarmState.activeUntil = 0
			broadcast({ type = "swarmEnd" })
		end
		if (not swarmState.active) and swarmState.queuedDuration > 0 then
			local swarmDuration = swarmState.queuedDuration
			swarmState.queuedDuration = 0
			swarmState.active = true
			swarmState.activeUntil = t + swarmDuration
			broadcast({
				type = "swarmStart",
				duration = math.max(1, math.ceil(swarmDuration)),
				startedAt = math.floor(t),
			})
		end
	end

	if normalSpawnState.nextAt <= 0 then
		normalSpawnState.nextAt = t + spawnInterval(t)
	end

	local scheduledSpawnBudget = 0
	local scheduleGuard = 0
	while t >= normalSpawnState.nextAt and scheduleGuard < 24 do
		scheduleGuard += 1
		local spawnAt = normalSpawnState.nextAt
		normalSpawnState.nextAt += spawnInterval(spawnAt)
		local burstSize = getNormalSpawnBurstSize(spawnAt)
		if eliteEncounterActive then
			normalSpawnState.debt += burstSize
		else
			scheduledSpawnBudget += burstSize
		end
	end

	if normalSpawnState.wasEliteEncounterActive and not eliteEncounterActive then
		normalSpawnState.catchupAccumulator = 0
	end
	normalSpawnState.wasEliteEncounterActive = eliteEncounterActive

	if eliteEncounterActive then
		return
	end

	local catchupBudget = 0
	if normalSpawnState.debt > 0 then
		local catchupRate = normalSpawnState.debt / spawnLimitConfig.postEliteCatchupDuration
		normalSpawnState.catchupAccumulator += catchupRate * dt
	end

	if normalSpawnState.debt > 0 then
		catchupBudget = math.min(
			normalSpawnState.debt,
			spawnLimitConfig.postEliteMaxPerTick,
			math.floor(normalSpawnState.catchupAccumulator)
		)
	end

	if scheduledSpawnBudget <= 0 and catchupBudget <= 0 then
		return
	end

	local maxAlive = desiredMaxAlive(t)
	local aliveNow = activeEnemiesCount()
	local normalAliveNow = activeNormalEnemiesCount()
	local encounterKind, encounterConfig = getActiveImportantEncounter()
	if encounterKind and normalAliveNow > maxAlive and encounterConfig.trimInterval > 0 and t >= normalSpawnState.nextEncounterTrimAt then
		normalSpawnState.nextEncounterTrimAt = t + encounterConfig.trimInterval
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
				normalSpawnState.debt = math.max(0, normalSpawnState.debt - 1)
				normalSpawnState.catchupAccumulator = math.max(0, normalSpawnState.catchupAccumulator - 1)
			end
		end
	end
end)

print("[HordeController] Ready (time-based)")
