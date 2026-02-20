-- WaveController.server.lua (Level1)
-- Reworked: time-based horde spawning (VS / Mega Bonk style)
-- No waves. Difficulty ramps with elapsed run time.
-- Elites spawn every 10 minutes. After the 3rd elite is defeated -> Victory.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

-- Shared pause flag (used by upgrade UI in single)
local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
    PauseState = Instance.new("BoolValue")
    PauseState.Name = "PauseState"
    PauseState.Value = false
    PauseState.Parent = ReplicatedStorage
end

-- We keep the same RemoteEvent name so you don't need new remotes.
local WaveStatusEvent = ReplicatedStorage:FindFirstChild("WaveStatusEvent")
if not WaveStatusEvent then
    WaveStatusEvent = Instance.new("RemoteEvent")
    WaveStatusEvent.Name = "WaveStatusEvent"
    WaveStatusEvent.Parent = ReplicatedStorage
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
        end
    end
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

local function raycastGround(pos: Vector3)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist

    local blacklist = { ENEMIES_FOLDER }
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            table.insert(blacklist, plr.Character)
        end
    end
    params.FilterDescendantsInstances = blacklist
    params.IgnoreWater = true

    local origin = Vector3.new(pos.X, SPAWN_RAY_START_Y, pos.Z)
    return workspace:Raycast(origin, Vector3.new(0, -GROUND_RAY_DIST, 0), params)
end

local function slopeDeg(normal: Vector3)
    local up = Vector3.new(0, 1, 0)
    local dot = math.clamp(normal:Dot(up), -1, 1)
    return math.deg(math.acos(dot))
end

-- Best-effort spawn bounds: scan anchored, collidable "ground-like" parts so we do not bias spawns when ring samples land in void.
local _boundsCache = nil
local _boundsCacheT = 0
local BOUNDS_REFRESH_SEC = 10
local MIN_GROUND_AREA = 20 * 20 -- studs^2 (ignore tiny parts)

local function computeSpawnBounds()
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    local found = false

    for _, inst in ipairs(workspace:GetDescendants()) do
        if inst:IsA("BasePart") then
            if inst.Anchored and inst.CanCollide and inst.CanQuery then
                if not inst:IsDescendantOf(ENEMIES_FOLDER) then
                    local model = inst:FindFirstAncestorOfClass("Model")
                    local isCharacter = model and Players:GetPlayerFromCharacter(model) ~= nil
                    if not isCharacter then
                        local area = inst.Size.X * inst.Size.Z
                        if area >= MIN_GROUND_AREA then
                            local halfX, halfZ = inst.Size.X * 0.5, inst.Size.Z * 0.5
                            local x1, x2 = inst.Position.X - halfX, inst.Position.X + halfX
                            local z1, z2 = inst.Position.Z - halfZ, inst.Position.Z + halfZ
                            if x1 < minX then minX = x1 end
                            if x2 > maxX then maxX = x2 end
                            if z1 < minZ then minZ = z1 end
                            if z2 > maxZ then maxZ = z2 end
                            found = true
                        end
                    end
                end
            end
        end
    end

    if not found then return nil end
    return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
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

local function pickSpawnCFrame(): CFrame?
    local hrps = getAliveHRPs()
    if #hrps == 0 then return nil end
    local anchor = hrps[math.random(1, #hrps)].Position

    -- Optional explicit spawn points (best)
    local spFolder = workspace:FindFirstChild("SpawnPoints")
    if spFolder then
        local pts = spFolder:GetChildren()
        if #pts > 0 then
            local p = pts[math.random(1, #pts)]
            if p:IsA("BasePart") then
                return CFrame.new(p.Position + Vector3.new(0, 2.5, 0))
            elseif p:IsA("Attachment") then
                return CFrame.new(p.WorldPosition + Vector3.new(0, 2.5, 0))
            end
        end
    end

    local bounds = getSpawnBounds()
    local BOUNDS_MARGIN = 6

    for _ = 1, MAX_SPAWN_TRIES do
        local ang = math.random() * math.pi * 2
        local r = SPAWN_RING_MIN + math.random() * (SPAWN_RING_MAX - SPAWN_RING_MIN)
        local x = anchor.X + math.cos(ang) * r
        local z = anchor.Z + math.sin(ang) * r

        if bounds and not inBounds(bounds, x, z, BOUNDS_MARGIN) then
            continue
        end

        local hit = raycastGround(Vector3.new(x, 0, z))
        if hit and hit.Position and slopeDeg(hit.Normal) <= MAX_GROUND_SLOPE_DEG then
            return CFrame.new(hit.Position + Vector3.new(0, 2.5, 0))
        end
    end

    -- Fallback 1: force samples inside bounds so we do not collapse into one direction when outside area is void
    if bounds then
        for _ = 1, MAX_SPAWN_TRIES do
            local ang = math.random() * math.pi * 2
            local r = SPAWN_RING_MIN + math.random() * (SPAWN_RING_MAX - SPAWN_RING_MIN)
            local x = math.clamp(anchor.X + math.cos(ang) * r, bounds.minX + BOUNDS_MARGIN, bounds.maxX - BOUNDS_MARGIN)
            local z = math.clamp(anchor.Z + math.sin(ang) * r, bounds.minZ + BOUNDS_MARGIN, bounds.maxZ - BOUNDS_MARGIN)

            local hit = raycastGround(Vector3.new(x, 0, z))
            if hit and hit.Position and slopeDeg(hit.Normal) <= MAX_GROUND_SLOPE_DEG then
                return CFrame.new(hit.Position + Vector3.new(0, 2.5, 0))
            end
        end
    end

    -- Fallback 2: last resort, still random direction (never fixed -Z)
    local ang = math.random() * math.pi * 2
    local dx, dz = math.cos(ang) * SPAWN_RING_MIN, math.sin(ang) * SPAWN_RING_MIN
    return CFrame.new(anchor + Vector3.new(dx, 2.5, dz))
end

-- Enemy config (studs, Roblox Humanoid speeds)
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

local function timeScaleMult(elapsed: number)
    -- Per minute: HP +5%, Damage +3%
    local minutes = math.floor(math.max(0, elapsed) / 60)
    local hpMult = (1.05) ^ minutes
    local dmgMult = (1.03) ^ minutes
    return hpMult, dmgMult
end

local function getPool(elapsed: number)
    -- returns weighted pool (normal mobs)
    if elapsed < 120 then
        return { {"Slime", 100} }
    elseif elapsed < 300 then
        return { {"Slime", 70}, {"Zombie", 30} }
    elseif elapsed < 480 then
        return { {"Slime", 50}, {"Zombie", 30}, {"Skeleton", 20} }
    elseif elapsed < 600 then
        return { {"Slime", 35}, {"Zombie", 25}, {"Skeleton", 20}, {"Goblin", 20} }
    elseif elapsed < 900 then
        return { {"Zombie", 30}, {"Skeleton", 25}, {"Goblin", 25}, {"Warewolf", 20} }
    elseif elapsed < 1200 then
        return { {"Skeleton", 22}, {"Goblin", 22}, {"Warewolf", 22}, {"Harp", 18}, {"LandShark", 16} }
    else
        return { {"Goblin", 18}, {"Warewolf", 20}, {"Harp", 18}, {"LandShark", 16}, {"Golem", 14}, {"Ent", 14} }
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
    local n = 0
    for _, ch in ipairs(ENEMIES_FOLDER:GetChildren()) do
        if ch:IsA("Model") then
            local h = ch:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                n += 1
            end
        end
    end
    return n
end

local PATH_PARAMS = {
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentJumpHeight = 7,
    AgentMaxSlope = 35,
}

local function waitIfPaused()
    while PauseState.Value do
        task.wait(0.05)
    end
end

local function cleanupTemplateScripts(mob: Model)
    -- Prevent the template "Respawn" scripts from duplicating mobs in a horde run.
    for _, d in ipairs(mob:GetDescendants()) do
        if d:IsA("Script") and string.lower(d.Name) == "respawn" then
            d:Destroy()
        end
    end
end

local function startSimpleAI(mob: Model)
    local hum = mob:FindFirstChildOfClass("Humanoid")
    local hrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
    if not hum or not hrp then return end

    -- Ensure server owns NPC physics (prevents \"one step then freeze\" when client ownership/streaming kicks in)
    pcall(function() hrp:SetNetworkOwner(nil) end)

    hum.AutoRotate = true
    hum:ChangeState(Enum.HumanoidStateType.Running)

    local attackRange = tonumber(mob:GetAttribute("AttackRange")) or 4
    local attackCD = tonumber(mob:GetAttribute("AttackCooldown")) or 1.5
    local damage = tonumber(mob:GetAttribute("Damage")) or 8
    local ranged = mob:GetAttribute("IsRanged") == true

    local lastAttack = 0
    local lastPathAt = 0
    local currentWaypoints = nil
    local currentIdx = 1
    local stuckPos = hrp.Position
    local stuckT = time()

    local function getTarget()
        return getClosestLivingHRP(hrp.Position)
    end

    local function computePath(goalPos: Vector3)
        local path = PathfindingService:CreatePath(PATH_PARAMS)
        path:ComputeAsync(hrp.Position, goalPos)
        if path.Status == Enum.PathStatus.Success then
            currentWaypoints = path:GetWaypoints()
            currentIdx = 1
        else
            currentWaypoints = nil
            currentIdx = 1
        end
    end

    task.spawn(function()
        while mob.Parent and hum.Health > 0 do
            if not anyPlayersAlive() then
                task.wait(0.2)
                continue
            end

            waitIfPaused()

            local targetHRP = getTarget()
            if not targetHRP then
                task.wait(0.2)
                continue
            end

            local dist = (targetHRP.Position - hrp.Position).Magnitude

            -- Attack
            if dist <= attackRange then
                if time() - lastAttack >= attackCD then
                    lastAttack = time()
                    local targetHum = targetHRP.Parent and targetHRP.Parent:FindFirstChildOfClass("Humanoid")
                    if targetHum and targetHum.Health > 0 then
                        -- In this project we keep it simple: direct damage.
                        targetHum:TakeDamage(damage)
                    end
                end
                -- keep slight pressure but don't path spam
                hum:MoveTo(targetHRP.Position)
                task.wait(0.12)
                continue
            end

            -- Movement (horde-friendly)
            -- Default: direct MoveTo (cheap). Only use pathfinding when stuck to avoid PathfindingService overload.
            local now = time()

            local function moveDirect()
                hum:MoveTo(targetHRP.Position)
            end

            if currentWaypoints and currentWaypoints[currentIdx] then
                local wp = currentWaypoints[currentIdx]
                hum:MoveTo(wp.Position)
                if (wp.Position - hrp.Position).Magnitude < 3 then
                    currentIdx += 1
                end
                if not currentWaypoints[currentIdx] then
                    currentWaypoints = nil
                    currentIdx = 1
                end
            else
                moveDirect()
            end

            -- Stuck handling (trigger pathfinding rarely)
            if (hrp.Position - stuckPos).Magnitude < 0.5 then
                if now - stuckT > 1.25 then
                    if now - lastPathAt > 2.0 then
                        lastPathAt = now
                        computePath(targetHRP.Position)
                    end
                    stuckT = now
                end
            else
                stuckPos = hrp.Position
                stuckT = now
            end

            task.wait(0.2)
        end
    end)
end

local function wireDropsAndKills(mob: Model, cfg, isElite: boolean)
    local hum = mob:FindFirstChildOfClass("Humanoid")
    local hrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
    if not hum or not hrp then return end

    hum.Died:Connect(function()
        local pos = hrp.Position
        if _G.RegisterEnemyKill then
            pcall(function() _G.RegisterEnemyKill(pos) end)
        end

        -- Mission progress hooks
        local ServerScriptService = game:GetService("ServerScriptService")
        local mp = nil
        pcall(function()
            mp = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("MissionProgress"))
        end)
        if mp and mp.OnKill then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr:GetAttribute("RunEnded") ~= true then
                    pcall(function() mp.OnKill(plr, mob) end)
                end
            end
        end

        local xpDrop = cfg.xp or 5
        local coinDrop = cfg.coins or 1
        if isElite then
            xpDrop = math.floor(xpDrop * 10)
            coinDrop = math.floor(coinDrop * 8)
        end
        if _G.SpawnDropsAt then
            pcall(function() _G.SpawnDropsAt(pos, xpDrop, coinDrop) end)
        end

        
        -- Make the corpse non-walkable for players, but keep it resting on the ground.
        for _, d in ipairs(mob:GetDescendants()) do
            if d:IsA("BasePart") then
                d.CollisionGroup = CORPSES_GROUP
                d.CanTouch = false
                d.CanQuery = false
                d.CanCollide = true
            end
        end

task.delay(3, function()
            if mob and mob.Parent then mob:Destroy() end
        end)
    end)
end

local function spawnMob(mobName: string, isElite: boolean)
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

    local cf = pickSpawnCFrame()
    if not cf then return end

    local mob = template:Clone()
    mob.Name = mobName
    mob.Parent = ENEMIES_FOLDER
    mob:PivotTo(cf)

    cleanupTemplateScripts(mob)
    setMobGroup(mob)

    local hum = mob:FindFirstChildOfClass("Humanoid")
    if not hum then
        warn("[Horde] Template has no Humanoid:", mobName)
        mob:Destroy()
        return
    end

    local hpMult, dmgMult = timeScaleMult(_G.GetRunSeconds and _G.GetRunSeconds() or 0)
    local hp = math.floor(cfg.hp * hpMult)
    local dmg = math.floor(cfg.dmg * dmgMult)

    if isElite then
        hp = math.floor(hp * 4)
        dmg = math.floor(dmg * 2)
    end

    hum.MaxHealth = math.max(1, hp)
    hum.Health = hum.MaxHealth
    hum.WalkSpeed = cfg.speed

    mob:SetAttribute("MobType", mobName)
    mob:SetAttribute("Damage", dmg)
    mob:SetAttribute("AttackRange", cfg.range)
    mob:SetAttribute("AttackCooldown", cfg.cd)
    mob:SetAttribute("IsElite", isElite)
    mob:SetAttribute("IsRanged", cfg.isRanged == true)

    wireDropsAndKills(mob, cfg, isElite)
    startSimpleAI(mob)

    return mob
end

-- Run clock (server-side)
local runStart = time()
local function elapsed()
    return time() - runStart
end

-- Expose run seconds for other scripts if needed
_G.GetRunSeconds = function()
    return math.floor(elapsed())
end

local function desiredMaxAlive(t: number)
    -- Starts low for fast leveling, grows steadily.
    local base = 25
    local add = math.floor(t / 60) * 5
    return math.clamp(base + add, 25, 140)
end

local function spawnInterval(t: number)
    -- Slightly faster over time, but not insane.
    local minI = 0.28
    local maxI = 0.60
    local p = math.clamp(t / 1800, 0, 1)
    return maxI - (maxI - minI) * p
end

local eliteCount = 0
local nextEliteAt = 600 -- 10 minutes
local eliteOrder = { "Knight", "Demon", "Ent" }

local function endRunVictory()
    broadcast({ type = "complete", reason = "Victory" })

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Parent and plr:GetAttribute("RunEnded") ~= true then
            if _G.EndRunForPlayer then
                pcall(function() _G.EndRunForPlayer(plr, "Victory") end)
            elseif _G.EndRun then
                pcall(function() _G.EndRun("Victory") end)
            end
        end
    end
end

local function watchEliteDeath(mob: Model)
    local hum = mob and mob:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.Died:Connect(function()
        eliteCount += 1
        broadcast({ type = "eliteProgress", elitesDefeated = eliteCount, elitesTotal = 3 })
        if eliteCount >= 3 then
            endRunVictory()
        end
    end)
end

-- Initial HUD ping
broadcast({ type = "timeUpdate", seconds = 0, nextEliteIn = nextEliteAt, elitesDefeated = 0, elitesTotal = 3 })

local lastHudPush = 0
local lastSpawnAt = 0

RunService.Heartbeat:Connect(function()
    local t = elapsed()

    -- Stop if nobody is in a run / everyone ended.
    if not anyPlayersAlive() then
        return
    end

    -- HUD update (4x/sec max)
    if t - lastHudPush >= 0.25 then
        lastHudPush = t
        local nextIn = math.max(0, nextEliteAt - t)
        broadcast({
            type = "timeUpdate",
            seconds = math.floor(t),
            nextEliteIn = math.floor(nextIn),
            elitesDefeated = eliteCount,
            elitesTotal = 3,
        })
    end

    -- Elites
    if eliteCount < 3 and t >= nextEliteAt then
        local eliteName = eliteOrder[eliteCount + 1] or "Knight"
        local elite = spawnMob(eliteName, true)
        if elite then
            broadcast({ type = "eliteSpawn", name = eliteName, elitesDefeated = eliteCount, elitesTotal = 3 })
            watchEliteDeath(elite)
        end
        nextEliteAt += 600
    end

    -- Normal spawns
    local interval = spawnInterval(t)
    if t - lastSpawnAt < interval then
        return
    end
    lastSpawnAt = t

    waitIfPaused()

    local maxAlive = desiredMaxAlive(t)
    if activeEnemiesCount() >= maxAlive then
        return
    end

    local pool = getPool(t)
    local mobName = pickWeighted(pool)
    spawnMob(mobName, false)
end)

print("[HordeController] Ready (time-based)")
