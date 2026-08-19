-- codex test
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local batchEvent = remotes:WaitForChild("NpcBatchEvent")
local syncRequestEvent = remotes:WaitForChild("NpcSyncRequest")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local NpcShared = require(moduleFolder:WaitForChild("NpcShared"))
local LoadingOverlay = require(moduleFolder:WaitForChild("ClientLoadingOverlay"))

local ATTR = NpcShared.Attributes
local LOOPED_BY_STATE = {
	idle = true,
	run = true,
	attack = false,
	death = false,
}

local PRIORITY_BY_STATE = {
	idle = Enum.AnimationPriority.Core,
	run = Enum.AnimationPriority.Movement,
	attack = Enum.AnimationPriority.Action,
	death = Enum.AnimationPriority.Action4,
}

local SEARCH_NAMES = {
	idle = { "idle" },
	run = { "run", "walk" },
	attack = { "attack", "toolslash", "toollunge" },
	death = { "death", "dead", "died" },
}

local CONFIGURED_ANIMATION_ATTRIBUTE_BY_STATE = {
	idle = "NpcIdleAnimationId",
	run = "NpcRunAnimationId",
	attack = "NpcAttackAnimationId",
	death = "NpcDeathAnimationId",
}

local presentations = {}
local pendingTrackBuilds = {}
local currentSyncRequestId = 0
local syncOverlayToken = nil
local RUN_ANIM_START_SPEED = 1.5
local RUN_ANIM_STOP_SPEED = 0.75
local RUN_ANIM_HOLD_TIME = 0.18
local PROCEDURAL_VISUAL_ATTR = "NpcLightweight"
local VISUAL_SCALE_ATTR = "NpcVisualScale"
local FACING_YAW_ATTR = "NpcFacingYawDegrees"
local PROCEDURAL_IDLE_SWAY_SPEED = 1.8
local PROCEDURAL_MOVE_BOUNCE_SPEED = 8
local SPAWN_RISE_DURATION = 0.65
local SPAWN_RISE_DEPTH = 5.75
local SPAWN_DUST_DURATION = 0.55
local SHOW_NPC_NAMEPLATES = false
local NAME_COLOR_NORMAL = Color3.fromRGB(242, 246, 252)
local NAME_COLOR_ELITE = Color3.fromRGB(255, 171, 102)
local NAME_COLOR_BOSS = Color3.fromRGB(255, 214, 128)

local function flatDir(v: Vector3?): Vector3
	if typeof(v) ~= "Vector3" then
		return Vector3.new(0, 0, -1)
	end
	local xz = Vector3.new(v.X, 0, v.Z)
	if xz.Magnitude <= 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return xz.Unit
end

local function flatSpeed(v: Vector3?): number
	if typeof(v) ~= "Vector3" then
		return 0
	end

	return math.sqrt((v.X * v.X) + (v.Z * v.Z))
end

local function surfaceUp(v: Vector3?): Vector3
	if typeof(v) == "Vector3" and v.Magnitude > 1e-4 then
		return v.Unit
	end
	return Vector3.yAxis
end

local function movementDir(v: Vector3?, movementMode: string?, surfaceNormal: Vector3?): Vector3
	if movementMode == "Surface" then
		local up = surfaceUp(surfaceNormal)
		local source = typeof(v) == "Vector3" and v or Vector3.new(0, 0, -1)
		local tangent = source - up * source:Dot(up)
		if tangent.Magnitude <= 1e-4 then
			local fallback = math.abs(up:Dot(Vector3.zAxis)) < 0.95 and Vector3.zAxis or Vector3.xAxis
			tangent = fallback - up * fallback:Dot(up)
		end
		return tangent.Unit
	end
	if movementMode ~= "Flying" then
		return flatDir(v)
	end
	if typeof(v) ~= "Vector3" or v.Magnitude <= 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return v.Unit
end

local function movementSpeed(v: Vector3?, movementMode: string?): number
	if (movementMode == "Flying" or movementMode == "Surface") and typeof(v) == "Vector3" then
		return v.Magnitude
	end
	return flatSpeed(v)
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

local function getVisualScale(entry): number
	local model = entry and entry.model
	local scale = model and model:GetAttribute(VISUAL_SCALE_ATTR)
	if typeof(scale) == "number" and scale > 0 then
		return scale
	end
	return 1
end

local function playSpawnGroundFx(pos: Vector3, scale: number)
	if typeof(pos) ~= "Vector3" then
		return
	end

	local sizeScale = math.clamp(tonumber(scale) or 1, 1, 3.5)
	local dust = Instance.new("Part")
	dust.Name = "NpcSpawnGroundFx"
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanTouch = false
	dust.CanQuery = false
	dust.CastShadow = false
	dust.Material = Enum.Material.Ground
	dust.Color = Color3.fromRGB(98, 75, 52)
	dust.Transparency = 0.32
	dust.Size = Vector3.new(2.8 * sizeScale, 0.08, 2.8 * sizeScale)
	dust.CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0))
	dust.Parent = workspace

	local tween = TweenService:Create(dust, TweenInfo.new(SPAWN_DUST_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(5.5 * sizeScale, 0.08, 5.5 * sizeScale),
		Transparency = 1,
	})
	tween:Play()
	Debris:AddItem(dust, SPAWN_DUST_DURATION + 0.15)
end

local function startSpawnRise(entry, pos: Vector3)
	entry.spawnRiseStart = os.clock()
	entry.spawnRiseDepth = SPAWN_RISE_DEPTH * math.clamp(getVisualScale(entry), 1, 3.5)
	playSpawnGroundFx(pos, getVisualScale(entry))
end

local function getSpawnRiseOffset(entry, now: number): Vector3
	local startTime = entry and entry.spawnRiseStart
	if type(startTime) ~= "number" then
		return Vector3.zero
	end

	local alpha = math.clamp((now - startTime) / SPAWN_RISE_DURATION, 0, 1)
	if alpha >= 1 then
		entry.spawnRiseStart = nil
		entry.spawnRiseDepth = nil
		return Vector3.zero
	end

	local eased = 1 - ((1 - alpha) * (1 - alpha) * (1 - alpha))
	local depth = tonumber(entry.spawnRiseDepth) or SPAWN_RISE_DEPTH
	return Vector3.new(0, -depth * (1 - eased), 0)
end

local function formatDisplayName(rawName: any): string
	local text = tostring(rawName or "Enemy")
	text = string.gsub(text, "_", " ")
	text = string.gsub(text, "(%l)(%u)", "%1 %2")
	return text
end

local function resolveDisplayName(entry): string
	local model = entry and entry.model
	if not model then
		return "Enemy"
	end

	local rawName = model:GetAttribute("DisplayName")
		or model:GetAttribute(ATTR.MobType)
		or model:GetAttribute(ATTR.Type)
		or model.Name
	return formatDisplayName(rawName)
end

local function resolveNameColor(entry): Color3
	local model = entry and entry.model
	if model and model:GetAttribute(ATTR.IsBoss) == true then
		return NAME_COLOR_BOSS
	end
	if model and model:GetAttribute(ATTR.IsElite) == true then
		return NAME_COLOR_ELITE
	end
	return NAME_COLOR_NORMAL
end

local function updateNameplateAppearance(entry)
	local gui = entry and entry.healthbar
	if not gui then
		return
	end

	local scale = getVisualScale(entry)
	gui.Size = UDim2.fromOffset(math.floor(148 + math.min(28, math.max(0, scale - 1) * 14)), 36)
	gui.StudsOffset = Vector3.new(0, 2 + (scale * 1.2), 0)

	if entry.nameLabel then
		entry.nameLabel.Text = resolveDisplayName(entry)
		entry.nameLabel.TextColor3 = resolveNameColor(entry)
	end
end

local function computeRootToPivot(model: Model, root: BasePart): CFrame?
	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)
	if not ok then
		return nil
	end
	return root.CFrame:ToObjectSpace(pivot)
end

local function getFacingYawOffset(model: Model): CFrame
	local yawDegrees = model:GetAttribute(FACING_YAW_ATTR)
	if typeof(yawDegrees) ~= "number" or math.abs(yawDegrees) <= 1e-4 then
		return CFrame.identity
	end
	return CFrame.Angles(0, math.rad(yawDegrees), 0)
end

local function isProceduralVisualModel(model: Model?): boolean
	return model ~= nil and model:GetAttribute(PROCEDURAL_VISUAL_ATTR) == true
end

local function buildProceduralPose(entry, now: number): CFrame
	local motion = math.max(0, tonumber(entry.animMotionSpeed) or 0)
	if entry.state == NpcShared.States.Attacking then
		local pulse = math.sin(now * 16)
		return CFrame.new(0, 0.1 + math.abs(pulse) * 0.08, 0) * CFrame.Angles(math.rad(-10), 0, math.rad(pulse * 3))
	end
	if entry.animMoving == true or motion >= RUN_ANIM_STOP_SPEED then
		local amp = math.clamp(motion / 18, 0.25, 1)
		local bounce = math.abs(math.sin(now * PROCEDURAL_MOVE_BOUNCE_SPEED))
		local roll = math.sin(now * (PROCEDURAL_MOVE_BOUNCE_SPEED * 0.5))
		return CFrame.new(0, bounce * 0.22 * amp, 0) * CFrame.Angles(math.rad(-8 * amp), 0, math.rad(roll * 4 * amp))
	end
	local sway = math.sin(now * PROCEDURAL_IDLE_SWAY_SPEED)
	return CFrame.new(0, math.abs(sway) * 0.05, 0) * CFrame.Angles(0, 0, math.rad(sway * 2.5))
end

local function refreshRigBinding(entry)
	local model = entry.model
	if not model then
		return nil
	end

	local root = resolveRoot(model)
	if not root then
		return nil
	end

	if entry.boundRoot ~= root or not entry.rootToPivot then
		entry.boundRoot = root
		local rootToPivot = computeRootToPivot(model, root)
		if rootToPivot then
			entry.rootToPivot = getFacingYawOffset(model) * rootToPivot
		else
			entry.rootToPivot = nil
		end
	end

	return root
end

local function ensureAnimator(model: Model): Animator?
	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end
	return animator
end

local function resolveWeight(animation: Animation): number
	local weightValue = animation:FindFirstChild("Weight")
	if weightValue and (weightValue:IsA("NumberValue") or weightValue:IsA("IntValue")) then
		return math.max(0, tonumber(weightValue.Value) or 1)
	end
	return 1
end

local function animationMatchesProbe(animation: Animation, probe: string): boolean
	local lowerProbe = string.lower(probe)
	local animationName = string.lower(animation.Name)
	if animationName == lowerProbe or string.sub(animationName, 1, #lowerProbe) == lowerProbe then
		return true
	end

	local parent = animation.Parent
	while parent and not parent:IsA("Model") do
		if string.lower(parent.Name) == lowerProbe then
			return true
		end
		parent = parent.Parent
	end

	return false
end

local function collectAnimations(model: Model, stateName: string): {Animation}
	local list = {}
	local seen = {}
	local names = SEARCH_NAMES[stateName] or { stateName }
	local configuredAttribute = CONFIGURED_ANIMATION_ATTRIBUTE_BY_STATE[stateName]
	local configuredId = configuredAttribute and model:GetAttribute(configuredAttribute) or nil
	if typeof(configuredId) == "number" then
		configuredId = tostring(math.floor(configuredId))
	end
	if typeof(configuredId) == "string" and configuredId ~= "" then
		if string.match(configuredId, "^%d+$") then
			configuredId = "rbxassetid://" .. configuredId
		end
		local configuredAnimation = Instance.new("Animation")
		configuredAnimation.Name = "Configured_" .. stateName
		configuredAnimation.AnimationId = configuredId
		table.insert(list, configuredAnimation)
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Animation") then
			for _, probe in ipairs(names) do
				if animationMatchesProbe(descendant, probe) then
					if not seen[descendant] then
						seen[descendant] = true
						table.insert(list, descendant)
					end
					break
				end
			end
		end
	end

	return list
end

local function buildTracks(entry)
	if entry.animBuilt then
		return
	end
	entry.animQueued = false
	entry.animBuilt = true
	entry.animTracks = {}

	local model = entry.model
	if not model then
		return
	end
	if isProceduralVisualModel(model) then
		return
	end
	local animator = ensureAnimator(model)
	if not animator then
		return
	end

	for stateName, _ in pairs(SEARCH_NAMES) do
		local entries = {}
		for _, animation in ipairs(collectAnimations(model, stateName)) do
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
		entry.animTracks[stateName] = entries
	end
end

local function queueTrackBuild(entry)
	if entry.animBuilt or entry.animQueued or not entry.model then
		return
	end
	if isProceduralVisualModel(entry.model) then
		entry.animBuilt = true
		entry.animTracks = {}
		return
	end

	entry.animQueued = true
	pendingTrackBuilds[#pendingTrackBuilds + 1] = entry
end

local function chooseTrack(entry, stateName: string)
	local variants = entry.animTracks and entry.animTracks[stateName]
	if not variants or #variants == 0 then
		return nil
	end
	if #variants == 1 then
		return variants[1].track
	end

	local total = 0
	for _, variant in ipairs(variants) do
		total += math.max(0, variant.weight)
	end
	if total <= 0 then
		return variants[1].track
	end

	local roll = math.random() * total
	local acc = 0
	for _, variant in ipairs(variants) do
		acc += math.max(0, variant.weight)
		if roll <= acc then
			return variant.track
		end
	end
	return variants[#variants].track
end

local function stopAnimation(entry, fadeTime: number?)
	if entry.currentTrack then
		pcall(function()
			entry.currentTrack:Stop(fadeTime or 0.1)
		end)
	end
	entry.currentTrack = nil
	entry.currentAnimState = nil
end

local function updateAnimationMotion(entry, dt: number, now: number)
	local renderPos = entry.renderPos
	if typeof(renderPos) ~= "Vector3" then
		return
	end

	local previousPos = entry.lastRenderPos or renderPos
	local displayedSpeed = 0
	if typeof(previousPos) == "Vector3" and dt > 1e-4 then
		displayedSpeed = movementSpeed(renderPos - previousPos, entry.movementMode) / dt
	end

	local targetSpeed = math.max(displayedSpeed, movementSpeed(entry.velocity, entry.movementMode))
	if entry.animMotionSpeed == nil then
		entry.animMotionSpeed = targetSpeed
	else
		entry.animMotionSpeed += (targetSpeed - entry.animMotionSpeed) * math.clamp(dt * 10, 0, 1)
	end

	local threshold = entry.animMoving and RUN_ANIM_STOP_SPEED or RUN_ANIM_START_SPEED
	if (entry.animMotionSpeed or 0) >= threshold then
		entry.animMoving = true
		entry.lastMoveAt = now
	elseif entry.animMoving and (now - (entry.lastMoveAt or 0)) > RUN_ANIM_HOLD_TIME then
		entry.animMoving = false
	end

	entry.lastRenderPos = renderPos
end

local function resolveAnimationState(entry): string
	if entry.dead or NpcShared.IsDeadState(entry.state) then
		return "death"
	end
	if entry.state == NpcShared.States.Attacking then
		return "attack"
	end
	if entry.animMoving == true then
		return "run"
	end
	return "idle"
end

local function playAnimation(entry)
	if not entry.animBuilt then
		queueTrackBuild(entry)
		return
	end

	local animState = resolveAnimationState(entry)
	if animState == "death" and entry.currentAnimState == "death" then
		return
	end
	if entry.currentAnimState == animState and entry.currentTrack and entry.currentTrack.IsPlaying then
		return
	end

	local nextTrack = chooseTrack(entry, animState)
	if not nextTrack then
		return
	end

	if entry.currentTrack and entry.currentTrack ~= nextTrack then
		pcall(function()
			entry.currentTrack:Stop(0.1)
		end)
	end

	nextTrack.Looped = LOOPED_BY_STATE[animState] == true
	if not nextTrack.IsPlaying then
		pcall(function()
			nextTrack:Play(0.1, 1, 1)
		end)
	end

	entry.currentTrack = nextTrack
	entry.currentAnimState = animState
end

local function ensureHealthbar(entry)
	if not SHOW_NPC_NAMEPLATES then
		return nil
	end
	if entry.healthbar then
		return entry.healthbar
	end
	if not entry.model then
		return nil
	end

	local root = resolveRoot(entry.model)
	if not root then
		return nil
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "NpcHealthbarClient"
	gui.Size = UDim2.fromOffset(148, 36)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Adornee = root
	gui.Parent = entry.model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextStrokeTransparency = 0.55
	nameLabel.Text = resolveDisplayName(entry)
	nameLabel.Parent = gui

	local bg = Instance.new("Frame")
	bg.Name = "Bar"
	bg.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0
	bg.Position = UDim2.new(0, 8, 0, 22)
	bg.Size = UDim2.new(1, -16, 0, 10)
	bg.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(84, 214, 124)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bg

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = bg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	entry.healthbar = gui
	entry.nameLabel = nameLabel
	entry.healthFill = fill
	updateNameplateAppearance(entry)
	return gui
end

local function updateHealthbar(entry)
	local gui = ensureHealthbar(entry)
	if not gui or not entry.healthFill then
		return
	end

	local maxHp = math.max(1, tonumber(entry.maxHp) or 1)
	local hp = math.max(0, tonumber(entry.hp) or 0)
	entry.healthFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	updateNameplateAppearance(entry)
	gui.Enabled = not entry.dead and entry.spawnRiseStart == nil
end

local function cleanupEntry(id: string)
	local entry = presentations[id]
	if not entry then
		return
	end
	stopAnimation(entry, 0)
	if entry.healthbar then
		pcall(function()
			entry.healthbar:Destroy()
		end)
	end
	if entry.animTracks then
		for _, variants in pairs(entry.animTracks) do
			for _, variant in ipairs(variants) do
				pcall(function()
					variant.track:Destroy()
				end)
			end
		end
	end
	presentations[id] = nil
end

local function ensureEntry(id: string)
	local entry = presentations[id]
	if entry then
		return entry
	end
	entry = {
		id = id,
		state = NpcShared.States.Idle,
		targetPos = nil,
		renderPos = nil,
		targetDir = Vector3.new(0, 0, -1),
		renderDir = Vector3.new(0, 0, -1),
		velocity = Vector3.zero,
		movementMode = "Ground",
		movementProfile = "GroundSmall",
		movementSystem = "Legacy",
		movementBehavior = "GroundWalker",
		combatBehavior = nil,
		surfaceNormal = Vector3.yAxis,
		renderSurfaceNormal = Vector3.yAxis,
		hp = 0,
		maxHp = 1,
		dead = false,
		despawned = false,
		lastSeen = os.clock(),
		rootToPivot = nil,
		boundRoot = nil,
		animQueued = false,
		lastRenderPos = nil,
		animMotionSpeed = 0,
		animMoving = false,
		lastMoveAt = 0,
	}
	presentations[id] = entry
	return entry
end

local finishSyncGate

local function beginSyncGate()
	currentSyncRequestId += 1
	local requestId = currentSyncRequestId
	if syncOverlayToken then
		LoadingOverlay.Update(syncOverlayToken, {
			title = "Synchronizing...",
			message = "Waiting for full enemy sync from server",
			progress = nil,
		})
	else
		syncOverlayToken = LoadingOverlay.Acquire({
			title = "Synchronizing...",
			message = "Waiting for full enemy sync from server",
			progress = nil,
		})
	end

	task.delay(12, function()
		if requestId == currentSyncRequestId and syncOverlayToken then
			warn("[NpcPresentation] Full NPC sync timed out; releasing loading overlay")
			finishSyncGate(requestId)
		end
	end)

	syncRequestEvent:FireServer(requestId)
	return requestId
end

finishSyncGate = function(requestId: number?)
	if requestId and requestId ~= currentSyncRequestId then
		return
	end

	if not syncOverlayToken then
		return
	end

	LoadingOverlay.Release(syncOverlayToken)
	syncOverlayToken = nil
end

batchEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local items = payload.items
	if typeof(items) ~= "table" then
		return
	end

	local fullSnapshot = payload.full == true
	local seen = fullSnapshot and {} or nil
	local now = os.clock()
	for _, item in ipairs(items) do
		if typeof(item) == "table" and item.id ~= nil then
			local id = tostring(item.id)
			local isNew = presentations[id] == nil
			local entry = ensureEntry(id)
			if typeof(item.movementMode) == "string" then
				entry.movementMode = item.movementMode
			end
			if typeof(item.movementProfile) == "string" then
				entry.movementProfile = item.movementProfile
			end
			if typeof(item.movementSystem) == "string" then
				entry.movementSystem = item.movementSystem
			end
			if typeof(item.movementBehavior) == "string" then
				entry.movementBehavior = item.movementBehavior
			end
			if typeof(item.combatBehavior) == "string" then
				entry.combatBehavior = item.combatBehavior
			end
			if typeof(item.surfaceNormal) == "Vector3" then
				entry.surfaceNormal = surfaceUp(item.surfaceNormal)
				if fullSnapshot or not entry.renderSurfaceNormal then
					entry.renderSurfaceNormal = entry.surfaceNormal
				end
			end
			if seen then
				seen[id] = true
			end
			local spawnFxPos = nil
			local serverSpawnFxPos = nil
			if typeof(item.model) == "Instance" and item.model:IsA("Model") then
				entry.model = item.model
				refreshRigBinding(entry)
				queueTrackBuild(entry)
			end
			if typeof(item.spawnSurfacePos) == "Vector3" then
				serverSpawnFxPos = item.spawnSurfacePos
			end
			if typeof(item.pos) == "Vector3" then
				entry.targetPos = item.pos
				spawnFxPos = item.pos
				if fullSnapshot or not entry.renderPos then
					entry.renderPos = item.pos
				end
			end
			if typeof(item.dir) == "Vector3" then
				entry.targetDir = movementDir(item.dir, entry.movementMode, entry.surfaceNormal)
				if fullSnapshot or not entry.renderDir then
					entry.renderDir = entry.targetDir
				end
			end
			if typeof(item.vel) == "Vector3" then
				entry.velocity = item.vel
			end
			if typeof(item.state) == "string" then
				entry.state = item.state
			end
			if typeof(item.hp) == "number" then
				entry.hp = item.hp
			end
			if typeof(item.maxHp) == "number" then
				entry.maxHp = item.maxHp
			end
			entry.dead = item.dead == true
			entry.despawned = item.despawned == true
			entry.lastSeen = now
			if entry.model and not entry.model:GetAttribute(ATTR.Id) then
				entry.model:SetAttribute(ATTR.Id, id)
			end
			if isNew and fullSnapshot ~= true and not entry.dead and not entry.despawned and spawnFxPos then
				if serverSpawnFxPos then
					entry.spawnRiseStart = nil
					entry.spawnRiseDepth = nil
					playSpawnGroundFx(serverSpawnFxPos, getVisualScale(entry))
				else
					startSpawnRise(entry, spawnFxPos)
				end
			end
		end
	end

	if seen then
		for id in pairs(presentations) do
			if not seen[id] then
				cleanupEntry(id)
			end
		end
	end

	if fullSnapshot then
		finishSyncGate(tonumber(payload.requestId))
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()

	local buildsLeft = 3
	while buildsLeft > 0 and #pendingTrackBuilds > 0 do
		local index = #pendingTrackBuilds
		local entry = pendingTrackBuilds[index]
		pendingTrackBuilds[index] = nil
		if entry and presentations[entry.id] == entry and entry.model and entry.model.Parent then
			buildTracks(entry)
		elseif entry then
			entry.animQueued = false
		end
		buildsLeft -= 1
	end

	for id, entry in pairs(presentations) do
		local model = entry.model
		if model and not model.Parent then
			cleanupEntry(id)
			continue
		end
		if (entry.despawned and not model) or (now - entry.lastSeen) > 2 then
			cleanupEntry(id)
			continue
		end
		if not model or not model.Parent then
			continue
		end
		if not entry.targetPos then
			continue
		end

		local goalPos = entry.targetPos
		if typeof(entry.velocity) == "Vector3" and not entry.dead then
			goalPos += entry.velocity * 0.05
		end
		local goalDir = movementDir(entry.targetDir or entry.velocity, entry.movementMode, entry.surfaceNormal)
		if typeof(entry.velocity) == "Vector3" and entry.velocity.Magnitude > 0.2 then
			goalDir = movementDir(entry.velocity, entry.movementMode, entry.surfaceNormal)
		end

		entry.renderPos = entry.renderPos and entry.renderPos:Lerp(goalPos, math.clamp(dt * 12, 0, 1)) or goalPos
		if entry.movementMode == "Surface" then
			entry.renderSurfaceNormal = surfaceUp(
				entry.renderSurfaceNormal and entry.renderSurfaceNormal:Lerp(entry.surfaceNormal, math.clamp(dt * 12, 0, 1))
					or entry.surfaceNormal
			)
		end
		entry.renderDir = entry.renderDir and entry.renderDir:Lerp(goalDir, math.clamp(dt * 14, 0, 1)) or goalDir
		entry.renderDir = movementDir(entry.renderDir, entry.movementMode, entry.renderSurfaceNormal)

		updateAnimationMotion(entry, dt, now)
		refreshRigBinding(entry)
		local displayPos = entry.renderPos + getSpawnRiseOffset(entry, now)
		local up = entry.movementMode == "Surface"
			and surfaceUp(entry.renderSurfaceNormal)
			or (math.abs(entry.renderDir:Dot(Vector3.yAxis)) > 0.98 and Vector3.xAxis or Vector3.yAxis)
		local forward = movementDir(entry.renderDir, entry.movementMode, up)
		local rootFrame = CFrame.lookAt(displayPos, displayPos + forward, up)
		if isProceduralVisualModel(model) then
			rootFrame = rootFrame * buildProceduralPose(entry, now)
		end
		if entry.rootToPivot then
			model:PivotTo(rootFrame * entry.rootToPivot)
		else
			model:PivotTo(rootFrame)
		end
		updateHealthbar(entry)
		playAnimation(entry)
	end
end)

local function requestFullSync()
	beginSyncGate()
end

requestFullSync()
localPlayer.CharacterAdded:Connect(function()
	requestFullSync()
end)

