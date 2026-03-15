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

local NpcService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("NpcService"))
local PlayerData = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PlayerData"))
local PickupToastService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PickupToastService"))
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

local function getClosestLivingHRP(fromPos: Vector3): BasePart?
    local best, bestDist = nil, math.huge
    for _, hrp in ipairs(getAliveHRPs()) do
        local d = (hrp.Position - fromPos).Magnitude
        if d < bestDist then
            bestDist = d
            best = hrp
        end
    end
    return best
end

local function buildSpawnRaycastIgnore()
	local blacklist = {
		ENEMIES_FOLDER,
		workspace:FindFirstChild("Drops"),
		workspace:FindFirstChild("Chests"),
		workspace:FindFirstChild("Shrines"),
		workspace:FindFirstChild("Statues"),
		workspace:FindFirstChild("RunPortal"),
	}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(blacklist, plr.Character)
		end
	end
	return blacklist
end

local function buildSpawnOverlapIgnore()
	local ignore = {
		workspace:FindFirstChild("Drops"),
	}
	return ignore
end

local function raycastGround(pos: Vector3)
	return WorldBounds.RaycastTerrainAtXZ(pos.X, pos.Z, {
		originY = SPAWN_RAY_START_Y,
		distance = GROUND_RAY_DIST,
		ignoreWater = true,
		raycastIgnoreInstances = buildSpawnRaycastIgnore(),
	})
end

local function slopeDeg(normal: Vector3): number
    local up = Vector3.new(0, 1, 0)
    local dot = math.clamp(normal:Dot(up), -1, 1)
    return math.deg(math.acos(dot))
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

local function pickSpawnCFrame(anchorPos: Vector3?): CFrame?
    local anchor = anchorPos
    if not anchor then
        local hrps = getAliveHRPs()
        if #hrps == 0 then return nil end
        anchor = hrps[math.random(1, #hrps)].Position
    end

    -- We intentionally do NOT use SpawnPoints here (raycast-based spawning only).

    local bounds = getSpawnBounds()
    local BOUNDS_MARGIN = 6

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

		local hit = raycastGround(Vector3.new(x, 0, z))
		if hit and hit.Position and slopeDeg(hit.Normal) <= MAX_GROUND_SLOPE_DEG then
			local spawnPos = hit.Position + Vector3.new(0, 0.05, 0)
			local clear = WorldBounds.IsAreaClear(spawnPos, 3.5, 7, buildSpawnOverlapIgnore())
			if clear == true then
				return CFrame.new(spawnPos)
			end
		end
	end

    -- Fallback: random point inside Map bounds.
    if bounds then
        for _ = 1, MAX_SPAWN_TRIES do
			local x = (bounds.minX + BOUNDS_MARGIN) + math.random() * ((bounds.maxX - BOUNDS_MARGIN) - (bounds.minX + BOUNDS_MARGIN))
			local z = (bounds.minZ + BOUNDS_MARGIN) + math.random() * ((bounds.maxZ - BOUNDS_MARGIN) - (bounds.minZ + BOUNDS_MARGIN))
			local hit = raycastGround(Vector3.new(x, 0, z))
			if hit and hit.Position and slopeDeg(hit.Normal) <= MAX_GROUND_SLOPE_DEG then
				local spawnPos = hit.Position + Vector3.new(0, 0.05, 0)
				local clear = WorldBounds.IsAreaClear(spawnPos, 3.5, 7, buildSpawnOverlapIgnore())
				if clear == true then
					return CFrame.new(spawnPos)
				end
			end
		end
	end

    return CFrame.new(anchor + Vector3.new(0, 0.05, 0))
end

-- Enemy config (custom movement/combat stats)
local ENEMY_CONFIGS = {
    Slime =      { hp = 30,  speed = 9,  range = 3,  cd = 1.8, dmg = 6,  xp = 5,  coins = 1 },
    Zombie =     { hp = 110, speed = 8,  range = 4,  cd = 2.2, dmg = 10, xp = 10, coins = 2 },
    Skeleton =   { hp = 70,  speed = 12, range = 4,  cd = 1.4, dmg = 9,  xp = 12, coins = 2 },
    Goblin =     { hp = 80,  speed = 16, range = 3,  cd = 1.2, dmg = 8,  xp = 15, coins = 2 },
    Warewolf =   { hp = 240, speed = 18, range = 5,  cd = 1.1, dmg = 14, xp = 25, coins = 3 },
    Harp =       { hp = 160, speed = 14, range = 25, cd = 2.0, dmg = 12, xp = 22, coins = 3, isRanged = true },
    Demon =      { hp = 300, speed = 11, range = 6,  cd = 1.6, dmg = 16, xp = 28, coins = 4, hasFireball = true },
    LandShark =  { hp = 260, speed = 20, range = 8,  cd = 3.0, dmg = 18, xp = 26, coins = 4, isBurrow = true },
    Golem =      { hp = 550, speed = 6,  range = 6,  cd = 2.5, dmg = 20, xp = 35, coins = 5 },
    Knight =     { hp = 280, speed = 12, range = 5,  cd = 1.3, dmg = 15, xp = 30, coins = 4 },
    Ent =        { hp = 650, speed = 5,  range = 8,  cd = 3.0, dmg = 22, xp = 40, coins = 6 },
}

local RUN_TIME_LIMIT = 15 * 60 -- 15:00 (portal/boss threshold)
local ENEMY_HP_MULTIPLIER = 1.5
local BOSS_BASE_HP = math.floor(1600 * ENEMY_HP_MULTIPLIER)
local BOSS_HP_MULT_EARLY = 22
local BOSS_HP_MULT_LATE = 6
local BOSS_LEVEL_TARGET = 10
local ELITE_SOUL_DROP_MIN = 18
local ELITE_SOUL_DROP_MAX = 28
local BOSS_SOUL_DROP_MIN = 45
local BOSS_SOUL_DROP_MAX = 65
local ELITE_INTERVAL_SECONDS = 5 * 60
local BOSS_REINFORCEMENT_INTERVAL = 10
local materialRng = Random.new()

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
    if elapsed < 75 then
        return { {"Slime", 100} }
    elseif elapsed < 180 then
        return { {"Slime", 65}, {"Zombie", 35} }
    elseif elapsed < 300 then
        return { {"Slime", 35}, {"Zombie", 40}, {"Skeleton", 25} }
    elseif elapsed < 450 then
        return { {"Zombie", 30}, {"Skeleton", 30}, {"Goblin", 25}, {"Slime", 15} }
    elseif elapsed < 600 then
        return { {"Zombie", 22}, {"Skeleton", 28}, {"Goblin", 28}, {"Warewolf", 22} }
    elseif elapsed < 780 then
        return { {"Skeleton", 20}, {"Goblin", 24}, {"Warewolf", 24}, {"Harp", 18}, {"Demon", 14} }
    elseif elapsed < 960 then
        return { {"Goblin", 22}, {"Warewolf", 24}, {"Harp", 18}, {"Demon", 18}, {"LandShark", 18} }
    elseif elapsed < 1200 then
        return { {"Warewolf", 20}, {"Harp", 18}, {"Demon", 18}, {"LandShark", 18}, {"Golem", 13}, {"Knight", 13} }
    else
        return { {"Goblin", 12}, {"Warewolf", 18}, {"Harp", 16}, {"Demon", 18}, {"LandShark", 14}, {"Golem", 11}, {"Knight", 11}, {"Ent", 10} }
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
		if materialId then
			local materialCount = isBoss and 3 or (isElite and 2 or 1)
			addPersistentCount(plr, "mobMaterials", materialId, materialCount)
			PickupToastService.PushMaterial(plr, materialId, materialCount, "Mob Drop", "mobMaterials")
		end
		if crystalAward > 0 then
			addPersistentCount(plr, "upgradeMaterials", CraftingConfig.UPGRADE_CRYSTAL_ID, crystalAward)
			PickupToastService.PushMaterial(plr, CraftingConfig.UPGRADE_CRYSTAL_ID, crystalAward, "Mob Drop", "upgradeMaterials")
		end
		if isBoss then
			addPersistentCount(plr, "upgradeMaterials", CraftingConfig.BOSS_SPECIAL_ID, 1)
			PickupToastService.PushMaterial(plr, CraftingConfig.BOSS_SPECIAL_ID, 1, "Boss Drop", "upgradeMaterials")
		elseif isElite then
			addPersistentCount(plr, "upgradeMaterials", CraftingConfig.ELITE_SPECIAL_ID, 1)
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
	end

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

local function registerMobModel(mob: Model, mobType: string, stats, rewardCfg, isElite: boolean, isBoss: boolean, extraOnDeath)
	mob:SetAttribute("MobType", mobType)
	mob:SetAttribute("Damage", stats.dmg)
	mob:SetAttribute("AttackRange", stats.range)
	mob:SetAttribute("AttackCooldown", stats.cd)
	mob:SetAttribute("IsElite", isElite)
	mob:SetAttribute("IsBoss", isBoss == true)
	mob:SetAttribute("IsRanged", stats.isRanged == true)
	mob:SetAttribute("IsDead", false)
	mob:SetAttribute("IsAttacking", false)

    local registeredId = NpcService.Register(mob, {
        mobType = mobType,
        maxHealth = stats.hp,
        speed = stats.speed,
        attackRange = stats.range,
        attackCooldown = stats.cd,
        damage = stats.dmg,
        isElite = isElite,
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

local function spawnMob(mobName: string, isElite: boolean, spawnAnchorPos: Vector3?)
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

    local cf = pickSpawnCFrame(spawnAnchorPos)
    if not cf then return end

    local mob = template:Clone()
    mob.Name = mobName
    cleanupTemplateScripts(mob)
    setMobGroup(mob)
    mob.Parent = ENEMIES_FOLDER
    mob:PivotTo(cf)

    local hpMult, dmgMult, speedMult, cooldownMult = timeScaleMult(_G.GetRunSeconds and _G.GetRunSeconds() or 0)
    local hp = math.floor(cfg.hp * ENEMY_HP_MULTIPLIER * hpMult)
    local dmg = math.floor(cfg.dmg * dmgMult)
    local speed = cfg.speed * speedMult
    local cd = math.max(0.7, cfg.cd * cooldownMult)

    if isElite then
        hp = math.floor(hp * 6)
        dmg = math.floor(dmg * 2.8)
        speed = speed * 1.12
        cd = math.max(0.55, cd * 0.88)
    end

    return registerMobModel(mob, mobName, {
        hp = hp,
        speed = speed,
        range = cfg.range,
        cd = cd,
        dmg = dmg,
        isRanged = cfg.isRanged == true,
    }, cfg, isElite, false, nil)
end

local elapsed: () -> number

local function spawnBurst(count: number, anchorPos: Vector3?, poolTime: number?)
    local spawned = {}
    local targetCount = math.max(0, math.floor(tonumber(count) or 0))
    if targetCount <= 0 then
        return spawned
    end

    local pool = getPool(tonumber(poolTime) or elapsed())
    for _ = 1, targetCount do
        local mobName = pickWeighted(pool)
        local mob = spawnMob(mobName, false, anchorPos)
        if mob then
            table.insert(spawned, mob)
        end
    end

    return spawned
end

_G.SpawnEnemyBurst = function(count: number, anchorPos: Vector3?, poolTime: number?)
    return spawnBurst(count, anchorPos, poolTime)
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

local swarmIndex = 1
local nextSwarmAt = SWARM_EVENT_TIMES[swarmIndex] or math.huge
local swarmActive = false
local swarmActiveUntil = 0

local function isSwarmActiveAt(t: number): boolean
    return swarmActive and t < swarmActiveUntil
end

local function desiredMaxAlive(t: number)
	local _, _, levelPressure = getRunPressure(t)
    local base = 28
    local add = math.floor(t / 60) * 6
	local v = math.clamp(base + add + math.floor(levelPressure * 8), 28, 170)
	-- After 15 minutes: big pressure increase
	if t >= RUN_TIME_LIMIT then
		v = math.clamp(v + 90 + math.floor((t - RUN_TIME_LIMIT) / 12) * 7, 140, 300)
	end
	return v
end

local function spawnInterval(t: number)
	local _, _, levelPressure = getRunPressure(t)
    local minI = 0.24
    local maxI = 0.56
    local p = math.clamp(t / 1500, 0, 1)
	local i = maxI - (maxI - minI) * p
	i = i / (1 + (levelPressure * 0.08))
	if t >= RUN_TIME_LIMIT then
		-- After 15 minutes: noticeably faster
		i = math.max(0.09, i * 0.42)
	end
    if isSwarmActiveAt(t) then
        i = math.max(0.08, i / 3)
    end
	return i
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
local bossDefeated = false
local nextBossReinforcementAt = math.huge
local refreshPortalPromptState = nil

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
	local hpMultiplier = BOSS_HP_MULT_EARLY + ((BOSS_HP_MULT_LATE - BOSS_HP_MULT_EARLY) * readiness) + (levelPressure * 0.85)
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
		speed = 10.5 + math.min(4, (levelPressure * 0.4) + (readiness * 1.6)),
		range = 8,
		cd = math.max(0.85, 1.25 - (readiness * 0.18)),
		dmg = math.max(28, math.floor(28 * (1 + (timeProgress * 0.55) + (levelPressure * 0.12)))),
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
	prompt.HoldDuration = 1
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

	local function spawnBossNearPortal()
		if bossModel and bossModel.Parent then
			return
		end

		bossDefeated = false
		local bossName = "Golem" -- change if you have a dedicated boss model
		local tpl = EliteFolder:FindFirstChild(bossName) or NormalFolder:FindFirstChild(bossName)
		if not tpl or not tpl:IsA("Model") then
			warn("[Portal] Missing boss template:", bossName)
			return
		end

		local mob = tpl:Clone()
		mob.Name = "Boss_" .. bossName
		cleanupTemplateScripts(mob)
		setMobGroup(mob)
		mob.Parent = ENEMIES_FOLDER

		pcall(function()
			mob:PivotTo(base.CFrame * CFrame.new(0, 0, -18))
		end)

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
			nextBossReinforcementAt = math.huge
			broadcast({ type = "portalBossDefeated" })
			setPromptState()
		end)
		if not registered then
			return
		end

		bossModel = registered
		nextBossReinforcementAt = elapsed() + BOSS_REINFORCEMENT_INTERVAL
		if type(_G.NotifyBossSpawn) == "function" then
			pcall(function()
				_G.NotifyBossSpawn()
			end)
		end
		broadcast({ type = "portalBossSpawn" })
	end

	prompt.Triggered:Connect(function(plr)
		if not RunStarted.Value then return end
		if plr:GetAttribute("RunEnded") == true then return end

		if not portalActivated then
			portalActivated = true
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
local lastSpawnAt = 0

RunService.Heartbeat:Connect(function()
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
    -- Elites (every 5 minutes during the scheduled run)
    if eliteIndex <= eliteTotal and t >= nextEliteAt then
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

    if (not swarmActive) and swarmIndex <= #SWARM_EVENT_TIMES and t >= nextSwarmAt then
        local startedAt = nextSwarmAt
        swarmActive = true
        swarmActiveUntil = t + SWARM_DURATION
        swarmIndex += 1
        nextSwarmAt = SWARM_EVENT_TIMES[swarmIndex] or math.huge
        broadcast({
            type = "swarmStart",
            duration = SWARM_DURATION,
            startedAt = math.floor(startedAt),
        })
    elseif swarmActive and t >= swarmActiveUntil then
        swarmActive = false
        swarmActiveUntil = 0
        broadcast({ type = "swarmEnd" })
    end

	if bossModel and bossModel.Parent and not bossDefeated and NpcService.IsAlive(bossModel) and t >= nextBossReinforcementAt then
		local bossPos = NpcService.GetPosition(bossModel)
		if bossPos then
			local reinforcementCount = math.clamp(3 + math.floor(math.max(0, t - RUN_TIME_LIMIT) / 45), 3, 6)
			spawnBurst(reinforcementCount, bossPos, math.max(t, RUN_TIME_LIMIT))
			nextBossReinforcementAt = t + math.max(7, BOSS_REINFORCEMENT_INTERVAL - math.floor(math.max(0, t - RUN_TIME_LIMIT) / 90))
		else
			nextBossReinforcementAt = t + 2
		end
	end

    -- Normal spawns
    local interval = spawnInterval(t)
    if t - lastSpawnAt < interval then
        return
    end
    lastSpawnAt = t

    local maxAlive = desiredMaxAlive(t)
    if activeEnemiesCount() >= maxAlive then
        return
    end

    local pool = getPool(t)
    local mobName = pickWeighted(pool)
    spawnMob(mobName, false, nil)
end)

print("[HordeController] Ready (time-based)")





