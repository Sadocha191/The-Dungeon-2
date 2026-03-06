local model = script.Parent
if not model or not model:IsA("Model") then
    return
end

local function resolveAnimator()
    -- Current AI stack still depends on Humanoid for movement/combat.
    -- If Humanoid exists, drive animations from its Animator to avoid controller conflicts.
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local humAnimator = humanoid:FindFirstChildOfClass("Animator")
        if not humAnimator then
            humAnimator = Instance.new("Animator")
            humAnimator.Parent = humanoid
        end
        return humAnimator
    end

    local animationController = model:FindFirstChildOfClass("AnimationController")
    if not animationController then
        animationController = model:WaitForChild("AnimationController", 5)
    end
    if not animationController then
        return nil
    end

    local controllerAnimator = animationController:FindFirstChildOfClass("Animator")
    if not controllerAnimator then
        controllerAnimator = animationController:WaitForChild("Animator", 5)
    end

    return controllerAnimator
end

local animator = resolveAnimator()
if not animator then
    return
end

local STATE_ORDER = { "idle", "run", "attack", "death" }
local STATE_SEARCH_NAMES = {
    idle = { "idle" },
    run = { "run", "walk" },
    attack = { "attack", "toolslash", "toollunge" },
    death = { "death", "dead", "died" },
}

local LOOPED_BY_STATE = {
    idle = true,
    run = true,
    attack = model:GetAttribute("AttackLooped") == true,
    death = false,
}

local PRIORITY_BY_STATE = {
    idle = Enum.AnimationPriority.Core,
    run = Enum.AnimationPriority.Movement,
    attack = Enum.AnimationPriority.Action,
    death = Enum.AnimationPriority.Action4,
}

local DEAD_BOOL_ATTRS = { "IsDead", "Dead", "Died" }
local DEAD_STATE_ATTRS = { "State", "AIState", "NPCState", "CombatState" }
local ATTACK_BOOL_ATTRS = { "IsAttacking", "Attacking", "InAttack", "AttackActive", "AttackState", "IsInAttack" }
local ATTACK_STATE_ATTRS = { "State", "AIState", "NPCState", "CombatState" }

local MOVE_SPEED_THRESHOLD = 0.75
local MOVE_POSITION_THRESHOLD = 0.03
local UPDATE_INTERVAL = 0.08

local rng = Random.new()
local generatedAnimations = {}
local stateTracks = {}
local currentState = nil
local currentTrack = nil
local rootPart = nil
local lastPosition = nil

local function findChildByNameCaseInsensitive(parent, targetName)
    if not parent then
        return nil
    end

    local lowerTarget = string.lower(targetName)
    for _, child in ipairs(parent:GetChildren()) do
        if string.lower(child.Name) == lowerTarget then
            return child
        end
    end

    return nil
end

local function normalizeAnimationId(raw)
    local rawType = typeof(raw)
    if rawType == "number" then
        if raw <= 0 then
            return nil
        end
        return "rbxassetid://" .. tostring(math.floor(raw))
    end

    if rawType == "string" then
        local trimmed = string.gsub(raw, "%s+", "")
        if trimmed == "" then
            return nil
        end

        local lowered = string.lower(trimmed)
        if string.find(lowered, "rbxassetid://", 1, true) then
            return trimmed
        end

        if string.find(lowered, "roblox.com/asset", 1, true) then
            return trimmed
        end

        local digits = string.match(trimmed, "%d+")
        if digits then
            return "rbxassetid://" .. digits
        end
    end

    return nil
end

local function animationFromValueNode(node, stateName)
    if node:IsA("ObjectValue") then
        local value = node.Value
        if value and value:IsA("Animation") then
            return value
        end
        return nil
    end

    if not (node:IsA("StringValue") or node:IsA("NumberValue") or node:IsA("IntValue")) then
        return nil
    end

    local id = normalizeAnimationId(node.Value)
    if not id then
        return nil
    end

    local cached = generatedAnimations[node]
    if cached and cached.AnimationId == id then
        return cached
    end

    local generated = Instance.new("Animation")
    generated.Name = stateName .. "_Generated"
    generated.AnimationId = id
    generatedAnimations[node] = generated
    return generated
end

local function gatherAnimationsFromNode(node, stateName)
    if not node then
        return {}
    end

    local list = {}
    local seen = {}

    local function addAnimation(animation)
        if animation and not seen[animation] then
            seen[animation] = true
            table.insert(list, animation)
        end
    end

    local function walk(inst)
        if inst:IsA("Animation") then
            addAnimation(inst)
            return
        end

        local generated = animationFromValueNode(inst, stateName)
        if generated then
            addAnimation(generated)
        end

        for _, child in ipairs(inst:GetChildren()) do
            walk(child)
        end
    end

    walk(node)
    return list
end

local function gatherAnimationsForName(stateName, searchName)
    local animations = {}
    local seen = {}

    local function addFromNode(node)
        for _, animation in ipairs(gatherAnimationsFromNode(node, stateName)) do
            if not seen[animation] then
                seen[animation] = true
                table.insert(animations, animation)
            end
        end
    end

    addFromNode(findChildByNameCaseInsensitive(script, searchName))
    addFromNode(findChildByNameCaseInsensitive(model, searchName))

    local animationsFolder = findChildByNameCaseInsensitive(model, "Animations")
    addFromNode(findChildByNameCaseInsensitive(animationsFolder, searchName))

    return animations
end

local function resolveWeight(animation)
    local weightValue = animation:FindFirstChild("Weight")
    if weightValue and (weightValue:IsA("NumberValue") or weightValue:IsA("IntValue")) then
        return math.max(0, tonumber(weightValue.Value) or 1)
    end

    return 1
end

local function loadTracksForState(stateName)
    local entries = {}
    local seenAnimations = {}
    local names = STATE_SEARCH_NAMES[stateName] or { stateName }

    for _, searchName in ipairs(names) do
        local found = gatherAnimationsForName(stateName, searchName)
        for _, animation in ipairs(found) do
            if not seenAnimations[animation] then
                seenAnimations[animation] = true
                local ok, track = pcall(function()
                    return animator:LoadAnimation(animation)
                end)

                if ok and track then
                    track.Looped = LOOPED_BY_STATE[stateName] == true
                    track.Priority = PRIORITY_BY_STATE[stateName] or Enum.AnimationPriority.Core
                    table.insert(entries, {
                        track = track,
                        weight = resolveWeight(animation),
                    })
                end
            end
        end
    end

    stateTracks[stateName] = entries
end

for _, stateName in ipairs(STATE_ORDER) do
    loadTracksForState(stateName)
end

local function getRootPart()
    if rootPart and rootPart.Parent then
        return rootPart
    end

    rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart

    if not rootPart then
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA("BasePart") then
                rootPart = child
                break
            end
        end
    end

    return rootPart
end

local function getAttributeValue(name)
    return model:GetAttribute(name)
end

local function isTruthy(value)
    local valueType = typeof(value)

    if valueType == "boolean" then
        return value
    end

    if valueType == "number" then
        return value > 0
    end

    if valueType == "string" then
        local normalized = string.lower(value)
        return normalized == "true" or normalized == "1"
    end

    return false
end

local function getStringState(attrs)
    for _, attrName in ipairs(attrs) do
        local value = getAttributeValue(attrName)
        if typeof(value) == "string" and value ~= "" then
            return string.lower(value)
        end
    end

    return nil
end

local function isDead()
    for _, attrName in ipairs(DEAD_BOOL_ATTRS) do
        if isTruthy(getAttributeValue(attrName)) then
            return true
        end
    end

    local alive = getAttributeValue("Alive")
    if typeof(alive) == "boolean" and alive == false then
        return true
    end

    local health = getAttributeValue("Health")
    if typeof(health) == "number" and health <= 0 then
        return true
    end

    local stateName = getStringState(DEAD_STATE_ATTRS)
    if stateName == "dead" or stateName == "death" or stateName == "died" then
        return true
    end

    return false
end

local function isAttacking()
    for _, attrName in ipairs(ATTACK_BOOL_ATTRS) do
        if isTruthy(getAttributeValue(attrName)) then
            return true
        end
    end

    local stateName = getStringState(ATTACK_STATE_ATTRS)
    if stateName == "attack" or stateName == "attacking" then
        return true
    end

    return false
end

local function isMoving()
    local root = getRootPart()
    if not root then
        return false
    end

    local velocity = root.AssemblyLinearVelocity
    local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

    local nowPosition = root.Position
    local movedByPosition = false

    if lastPosition then
        local delta = Vector3.new(nowPosition.X - lastPosition.X, 0, nowPosition.Z - lastPosition.Z)
        movedByPosition = delta.Magnitude > MOVE_POSITION_THRESHOLD
    end

    lastPosition = nowPosition

    return horizontalSpeed > MOVE_SPEED_THRESHOLD or movedByPosition
end

local function chooseTrack(stateName)
    local entries = stateTracks[stateName]
    if not entries or #entries == 0 then
        return nil
    end

    if #entries == 1 then
        return entries[1].track
    end

    local totalWeight = 0
    for _, entry in ipairs(entries) do
        totalWeight += math.max(0, entry.weight)
    end

    if totalWeight <= 0 then
        return entries[rng:NextInteger(1, #entries)].track
    end

    local roll = rng:NextNumber(0, totalWeight)
    local cumulative = 0

    for _, entry in ipairs(entries) do
        cumulative += math.max(0, entry.weight)
        if roll <= cumulative then
            return entry.track
        end
    end

    return entries[#entries].track
end

local function stopTrack(track, fadeTime)
    if not track then
        return
    end

    pcall(function()
        track:Stop(fadeTime or 0.1)
    end)
end

local function playState(stateName)
    if currentState == stateName and currentTrack and currentTrack.IsPlaying then
        return
    end

    local nextTrack = chooseTrack(stateName)
    if not nextTrack then
        return
    end

    if currentTrack and currentTrack ~= nextTrack then
        stopTrack(currentTrack, 0.1)
    end

    local shouldLoop = LOOPED_BY_STATE[stateName] == true
    if nextTrack.Looped ~= shouldLoop then
        nextTrack.Looped = shouldLoop
    end

    if not nextTrack.IsPlaying then
        pcall(function()
            nextTrack:Play(0.1, 1, 1)
        end)
    end

    currentState = stateName
    currentTrack = nextTrack
end

local function hasTrack(stateName)
    local entries = stateTracks[stateName]
    return entries ~= nil and #entries > 0
end

local function resolveDesiredState()
    if currentState == "death" then
        return "death"
    end

    if isDead() then
        return "death"
    end

    if hasTrack("attack") then
        if isAttacking() then
            return "attack"
        end

        if currentState == "attack" and currentTrack and currentTrack.IsPlaying then
            return "attack"
        end
    end

    if isMoving() and hasTrack("run") then
        return "run"
    end

    if hasTrack("idle") then
        return "idle"
    end

    return nil
end

while model.Parent do
    local desiredState = resolveDesiredState()

    if desiredState == "death" then
        if hasTrack("death") then
            playState("death")
        else
            stopTrack(currentTrack, 0.1)
            currentState = "death"
            currentTrack = nil
        end
    elseif desiredState then
        playState(desiredState)
    end

    task.wait(UPDATE_INTERVAL)
end

for _, entries in pairs(stateTracks) do
    for _, entry in ipairs(entries) do
        stopTrack(entry.track, 0)
    end
end