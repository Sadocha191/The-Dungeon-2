local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local npcBatchEvent = remotes:WaitForChild("NpcBatchEvent")
local playerHitVfxEvent = remotes:WaitForChild("PlayerHitVFXEvent")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local NpcShared = require(moduleFolder:WaitForChild("NpcShared"))
local VfxTemplatePlayer = require(moduleFolder:WaitForChild("VfxTemplatePlayer"))

local GOBLIN_TYPE = "Goblin"
local GOBLIN_EXPLOSION_EMIT_COUNTS = {
	Default = 6,
	Boom = 2,
	Center = 4,
	Fire = 12,
	Fire2 = 12,
	Fire3 = 12,
	Fire4 = 12,
	Fire5 = 12,
	Smoke = 8,
	Smoke2 = 8,
	Smoke3 = 8,
	Spark1 = 10,
	Spark2 = 10,
	Spark3 = 10,
	Star = 3,
	Wind = 4,
}

local goblins = {}
local npcBatchConnection = nil
local playerHitVfxConnection = nil

local function resolveAnimationTemplate(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	return animations and animations:FindFirstChild(name) or nil
end

local function cleanupGoblin(id)
	goblins[id] = nil
end

local function playGoblinExplosion(entry, position)
	local template = resolveAnimationTemplate("Explosion")
	if not template then
		warn("[CombatFeedback] Missing ReplicatedStorage.Assets.Animations.Explosion")
		return
	end

	local scale = math.max(0.1, tonumber(entry.visualScale) or 1)

	local visualPosition = position + Vector3.new(0, 0.75 * math.clamp(scale, 1, 2), 0)
	VfxTemplatePlayer.Play(template, CFrame.new(visualPosition), {
		emissionDuration = 0.2,
		cleanupDelay = 3.5 * math.clamp(scale, 1, 2),
		emitCounts = GOBLIN_EXPLOSION_EMIT_COUNTS,
	})
end

npcBatchConnection = npcBatchEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.items) ~= "table" then
		return
	end

	local fullSnapshot = payload.full == true
	local seen = fullSnapshot and {} or nil
	local now = os.clock()

	for _, item in ipairs(payload.items) do
		if typeof(item) ~= "table" or item.id == nil then
			continue
		end

		local id = tostring(item.id)
		local existing = goblins[id]
		local mobType = typeof(item.type) == "string" and item.type or (existing and existing.mobType)
		if mobType ~= GOBLIN_TYPE then
			continue
		end

		local entry = existing
		if not entry then
			entry = {
				id = id,
				mobType = GOBLIN_TYPE,
				state = nil,
				stateChangedAt = now,
				dead = false,
				despawned = false,
				explosionPlayed = false,
				lastPosition = nil,
			}
			goblins[id] = entry
		end

		if seen then
			seen[id] = true
		end
		if typeof(item.visual) == "table" and typeof(item.visual.visualScale) == "number" then
			entry.visualScale = item.visual.visualScale
		end
		if typeof(item.pos) == "Vector3" then
			entry.lastPosition = item.pos
		end
		if typeof(item.state) == "string" and item.state ~= entry.state then
			entry.state = item.state
			entry.stateChangedAt = now
		end

		local wasDead = entry.dead == true
		entry.dead = item.dead == true
		entry.despawned = item.despawned == true
		if not fullSnapshot
			and not wasDead
			and entry.dead
			and entry.state == NpcShared.States.Dead
			and not entry.explosionPlayed
			and typeof(entry.lastPosition) == "Vector3"
		then
			entry.explosionPlayed = true
			playGoblinExplosion(entry, entry.lastPosition)
		end

		if entry.despawned then
			cleanupGoblin(id)
		end
	end

	if seen then
		for id in pairs(goblins) do
			if not seen[id] then
				cleanupGoblin(id)
			end
		end
	end
end)

playerHitVfxConnection = playerHitVfxEvent.OnClientEvent:Connect(function(payload)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end

	local template = resolveAnimationTemplate("PlayerHitVFX")
	if not template then
		warn("[CombatFeedback] Missing ReplicatedStorage.Assets.Animations.PlayerHitVFX")
		return
	end

	VfxTemplatePlayer.Play(template, root.CFrame, {
		anchorTo = root,
		emissionDuration = 0.16,
		cleanupDelay = 2.5,
		playCamera = true,
		cameraFallback = {
			duration = 0.22,
			positionMagnitude = 0.1,
			rotationDegrees = 1.4,
			frequency = 28,
		},
	})
end)

script.Destroying:Connect(function()
	if npcBatchConnection then
		npcBatchConnection:Disconnect()
		npcBatchConnection = nil
	end
	if playerHitVfxConnection then
		playerHitVfxConnection:Disconnect()
		playerHitVfxConnection = nil
	end
	for id in pairs(goblins) do
		cleanupGoblin(id)
	end
end)
