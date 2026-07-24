local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local GOBLIN_TILT_DURATION = 0.38
local GOBLIN_TILT_DEGREES = 28
local GOBLIN_TILT_BIND_NAME = "GoblinForwardAttackTilt"

local goblins = {}

local function resolveAnimationTemplate(name)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	return animations and animations:FindFirstChild(name) or nil
end

local function resolveRoot(model)
	local root = model:FindFirstChild("RootPart") or model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function resolveRootJoint(entry)
	if entry.rootJoint and entry.rootJoint.Parent then
		return entry.rootJoint
	end

	local model = entry.model
	if not model or not model.Parent then
		return nil
	end

	local root = resolveRoot(model)
	local namedFallback = nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			if root and (descendant.Part0 == root or descendant.Part1 == root) then
				entry.rootJoint = descendant
				return descendant
			end

			local lowerName = string.lower(descendant.Name)
			if not namedFallback and (lowerName == "root" or lowerName == "rootjoint" or string.find(lowerName, "root", 1, true)) then
				namedFallback = descendant
			end
		end
	end

	entry.rootJoint = namedFallback
	return namedFallback
end

local function cframesApproximatelyEqual(first, second)
	local delta = first:ToObjectSpace(second)
	local _, angle = delta:ToAxisAngle()
	return delta.Position.Magnitude <= 1e-4 and math.abs(angle) <= 1e-4
end

local function removeAppliedTilt(entry)
	local joint = entry.rootJoint
	if not joint or not joint.Parent or not entry.lastTilt or not entry.lastTransformAfter then
		entry.lastTilt = nil
		entry.lastTransformAfter = nil
		return
	end

	local current = joint.Transform
	if cframesApproximatelyEqual(current, entry.lastTransformAfter) then
		joint.Transform = current * entry.lastTilt:Inverse()
	end
	entry.lastTilt = nil
	entry.lastTransformAfter = nil
end

local function cleanupGoblin(id)
	local entry = goblins[id]
	if not entry then
		return
	end
	removeAppliedTilt(entry)
	goblins[id] = nil
end

local function playGoblinExplosion(entry, position)
	local template = resolveAnimationTemplate("Explosion")
	if not template then
		warn("[CombatFeedback] Missing ReplicatedStorage.Assets.Animations.Explosion")
		return
	end

	local scale = 1
	if entry.model then
		local configuredScale = entry.model:GetAttribute("NpcVisualScale")
		if typeof(configuredScale) == "number" and configuredScale > 0 then
			scale = configuredScale
		end
	end

	VfxTemplatePlayer.Play(template, CFrame.new(position), {
		emissionDuration = 0.2,
		cleanupDelay = 3.5 * math.clamp(scale, 1, 2),
	})
end

npcBatchEvent.OnClientEvent:Connect(function(payload)
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
		if typeof(item.model) == "Instance" and item.model:IsA("Model") then
			entry.model = item.model
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

RunService:BindToRenderStep(GOBLIN_TILT_BIND_NAME, Enum.RenderPriority.Last.Value, function()
	local now = os.clock()
	for id, entry in pairs(goblins) do
		local model = entry.model
		if not model or not model.Parent or entry.despawned then
			cleanupGoblin(id)
			continue
		end

		local joint = resolveRootJoint(entry)
		local shouldTilt = joint
			and not entry.dead
			and entry.state == NpcShared.States.Attacking
		if not shouldTilt then
			removeAppliedTilt(entry)
			continue
		end

		local elapsed = math.max(0, now - (entry.stateChangedAt or now))
		local alpha = math.clamp(elapsed / GOBLIN_TILT_DURATION, 0, 1)
		local tiltWeight = math.sin(alpha * math.pi)
		local tilt = CFrame.Angles(math.rad(-GOBLIN_TILT_DEGREES * tiltWeight), 0, 0)

		local baseline = joint.Transform
		if entry.lastTilt and entry.lastTransformAfter and cframesApproximatelyEqual(baseline, entry.lastTransformAfter) then
			baseline = baseline * entry.lastTilt:Inverse()
		end

		joint.Transform = baseline * tilt
		entry.lastTilt = tilt
		entry.lastTransformAfter = joint.Transform
	end
end)

playerHitVfxEvent.OnClientEvent:Connect(function(payload)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
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
	RunService:UnbindFromRenderStep(GOBLIN_TILT_BIND_NAME)
	for id in pairs(goblins) do
		cleanupGoblin(id)
	end
end)
