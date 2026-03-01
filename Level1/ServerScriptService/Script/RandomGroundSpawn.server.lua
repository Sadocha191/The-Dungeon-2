-- RandomGroundSpawn.server.lua (Level1)
-- Teleports player characters to a random point on walkable ground right after spawn.
-- Works without explicit SpawnLocations; uses raycasts to find a collidable surface.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MAX_TRIES = 40
local HEIGHT_ABOVE = 250
local SAFE_OFFSET_Y = 4

local function isGroundCandidate(inst)
    if not inst:IsA("BasePart") then return false end
    if not inst.CanCollide then return false end
    if not inst.Anchored then return false end
    if inst.Transparency >= 1 then return false end
    -- ignore tiny parts
    if inst.Size.X < 8 or inst.Size.Z < 8 then return false end
    -- ignore obvious props
    local n = inst.Name:lower()
    if n:find("wall") or n:find("fence") or n:find("tree") or n:find("rock") then
        -- still might be ground; keep excluded
        return false
    end
    return true
end

local function collectCandidates()
    local candidates = {}
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if isGroundCandidate(inst) then
            table.insert(candidates, inst)
        end
    end
    return candidates
end

local function boundsXZ(parts)
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    local maxY = -math.huge

    for _, p in ipairs(parts) do
        local pos = p.Position
        local sx, sy, sz = p.Size.X, p.Size.Y, p.Size.Z
        minX = math.min(minX, pos.X - sx/2)
        maxX = math.max(maxX, pos.X + sx/2)
        minZ = math.min(minZ, pos.Z - sz/2)
        maxZ = math.max(maxZ, pos.Z + sz/2)
        maxY = math.max(maxY, pos.Y + sy/2)
    end

    if minX == math.huge then
        return nil
    end
    return minX, maxX, minZ, maxZ, maxY
end

local function getHumanoidRoot(character)
    return character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 10)
end

local function findRandomGroundPoint(candidates)
    local b = { boundsXZ(candidates) }
    if not b[1] then return nil end
    local minX, maxX, minZ, maxZ, maxY = table.unpack(b)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true

    for _ = 1, MAX_TRIES do
        local x = (math.random() * (maxX - minX)) + minX
        local z = (math.random() * (maxZ - minZ)) + minZ
        local origin = Vector3.new(x, maxY + HEIGHT_ABOVE, z)
        local dir = Vector3.new(0, -(HEIGHT_ABOVE * 3), 0)

        local result = Workspace:Raycast(origin, dir, params)
        if result and result.Instance and isGroundCandidate(result.Instance) then
            return result.Position + Vector3.new(0, SAFE_OFFSET_Y, 0)
        end
    end

    return nil
end

local function moveCharacterToGround(player, character)
    local hrp = getHumanoidRoot(character)
    if not hrp then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local candidates = collectCandidates()
    if #candidates == 0 then
        warn("[RandomGroundSpawn] No ground candidates found in Workspace.")
        return
    end

    local targetPos = findRandomGroundPoint(candidates)
    if not targetPos then
        warn("[RandomGroundSpawn] Failed to find random ground point.")
        return
    end

    -- avoid falling through while physics settles
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    hrp.CFrame = CFrame.new(targetPos)
    task.wait(0.05)
    humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        -- small delay to let default spawn complete and map load
        task.wait(0.2)
        pcall(function()
            moveCharacterToGround(player, character)
        end)
    end)
end)
