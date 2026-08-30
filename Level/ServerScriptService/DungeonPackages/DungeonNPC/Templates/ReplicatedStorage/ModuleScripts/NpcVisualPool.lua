local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcVisualPool = {}
NpcVisualPool.__index = NpcVisualPool

local PARK_Y = -10000
local PARK_SPACING = 18

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

local TRANSIENT_CLASSES = {
	Attachment = true,
	Beam = true,
	BillboardGui = true,
	Highlight = true,
	ParticleEmitter = true,
	PointLight = true,
	Smoke = true,
	Sound = true,
	Sparkles = true,
	SurfaceGui = true,
	Trail = true,
}

local function descriptorKey(descriptor): string
	return string.format("%s/%s", tostring(descriptor.rank or "Normal"), tostring(descriptor.type or "Enemy"))
end

local function normalizeAnimationId(value: any): string?
	if typeof(value) == "number" then
		value = tostring(math.floor(value))
	end
	if typeof(value) ~= "string" or value == "" then
		return nil
	end
	if string.match(value, "^%d+$") then
		return "rbxassetid://" .. value
	end
	return value
end

local function resolveRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function ensureAnimator(model: Model): Animator
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

local function moveLegacyAnimationsAndRemoveScripts(model: Model)
	local animationFolder = model:FindFirstChild("Animations")
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			if string.lower(descendant.Name) == "animate" then
				if not animationFolder then
					animationFolder = Instance.new("Folder")
					animationFolder.Name = "Animations"
					animationFolder.Parent = model
				end
				for _, child in ipairs(descendant:GetChildren()) do
					child.Parent = animationFolder
				end
			end
			descendant:Destroy()
		end
	end
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

local function resolveWeight(animation: Animation): number
	local weight = animation:FindFirstChild("Weight")
	if weight and (weight:IsA("NumberValue") or weight:IsA("IntValue")) then
		return math.max(0, tonumber(weight.Value) or 1)
	end
	return 1
end

local function collectAnimations(model: Model, descriptor, stateName: string, configuredFolder: Folder): {Animation}
	local animations = {}
	local seen = {}
	local configured = descriptor.animationIds and normalizeAnimationId(descriptor.animationIds[stateName])
	if configured then
		local animation = Instance.new("Animation")
		animation.Name = "Configured_" .. stateName
		animation.AnimationId = configured
		animation.Parent = configuredFolder
		table.insert(animations, animation)
		seen[animation] = true
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Animation") and not seen[descendant] then
			for _, probe in ipairs(SEARCH_NAMES[stateName] or { stateName }) do
				if animationMatchesProbe(descendant, probe) then
					seen[descendant] = true
					table.insert(animations, descendant)
					break
				end
			end
		end
	end
	return animations
end

local function chooseTrack(variants)
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
	local accumulated = 0
	for _, variant in ipairs(variants) do
		accumulated += math.max(0, variant.weight)
		if roll <= accumulated then
			return variant.track
		end
	end
	return variants[#variants].track
end

local function setIdentityAttribute(model: Model, name: string, value: any)
	if model:GetAttribute(name) ~= value then
		model:SetAttribute(name, value)
	end
end

function NpcVisualPool.new(options)
	options = options or {}
	local assets = options.assets or ReplicatedStorage:WaitForChild("Assets")
	local visualFolder = options.parent
	if not visualFolder then
		visualFolder = workspace:FindFirstChild("NpcVisuals")
		if not visualFolder then
			visualFolder = Instance.new("Folder")
			visualFolder.Name = "NpcVisuals"
			visualFolder.Parent = workspace
		end
	end

	return setmetatable({
		enemiesRoot = assets:WaitForChild("Enemies"),
		visualFolder = visualFolder,
		inactiveByKey = {},
		activeById = {},
		descriptorsByKey = {},
		capacityByKey = {},
		prewarmQueuedByKey = {},
		prewarmQueue = {},
		nextVisualIndex = 0,
		metrics = {
			active = 0,
			capacity = 0,
			growths = 0,
			created = 0,
			createdDuringRun = 0,
			acquires = 0,
			releases = 0,
			acquireSeconds = 0,
			acquireMaxSeconds = 0,
			releaseSeconds = 0,
			releaseMaxSeconds = 0,
		},
	}, NpcVisualPool)
end

function NpcVisualPool:_findTemplate(descriptor): Model?
	local rankFolder = self.enemiesRoot:FindFirstChild(tostring(descriptor.rank or "Normal"))
	local template = rankFolder and rankFolder:FindFirstChild(tostring(descriptor.type or ""))
	if template and template:IsA("Model") then
		return template
	end
	for _, folder in ipairs(self.enemiesRoot:GetChildren()) do
		local fallback = folder:FindFirstChild(tostring(descriptor.type or ""))
		if fallback and fallback:IsA("Model") then
			return fallback
		end
	end
	return nil
end

function NpcVisualPool:_park(record)
	local index = record.index
	record.model:PivotTo(CFrame.new(0, PARK_Y - (index * PARK_SPACING), 0))
end

function NpcVisualPool:_setVfxActive(record, active: boolean)
	for instance, enabled in pairs(record.vfxEnabled) do
		if instance.Parent then
			if instance:IsA("ParticleEmitter") then
				instance.Enabled = active and enabled or false
				if not active then
					pcall(function() instance:Clear() end)
				end
			elseif instance:IsA("Trail") or instance:IsA("Beam") then
				instance.Enabled = active and enabled or false
			end
		end
	end
	for sound in pairs(record.sounds) do
		if sound.Parent and not active then
			sound:Stop()
		end
	end
end

function NpcVisualPool:_clearTransientDescendants(record)
	for _, descendant in ipairs(record.model:GetDescendants()) do
		if not record.baselineDescendants[descendant]
			and (TRANSIENT_CLASSES[descendant.ClassName] or descendant:GetAttribute("NpcTransientVisual") == true)
		then
			descendant:Destroy()
		end
	end
end

function NpcVisualPool:_stopTracks(record)
	for _, variants in pairs(record.tracksByState) do
		for _, variant in ipairs(variants) do
			local track = variant.track
			pcall(function()
				track:Stop(0)
				track.TimePosition = 0
				track:AdjustSpeed(1)
			end)
		end
	end
	record.currentTrack = nil
	record.currentAnimationState = nil
	record.currentAnimationToken = nil
end

function NpcVisualPool:_create(descriptor, prewarming: boolean)
	local template = self:_findTemplate(descriptor)
	if not template then
		warn(string.format("[NpcVisualPool] Missing visual template %s", descriptorKey(descriptor)))
		return nil
	end

	debug.profilebegin("NpcVisualPool.Create")
	local model = template:Clone()
	moveLegacyAnimationsAndRemoveScripts(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
		humanoid.AutoRotate = false
		pcall(function() humanoid.EvaluateStateMachine = false end)
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	local root = resolveRoot(model)
	if not root then
		model:Destroy()
		debug.profileend()
		warn(string.format("[NpcVisualPool] Missing root in visual template %s", descriptorKey(descriptor)))
		return nil
	end
	model.PrimaryPart = root

	local animator = ensureAnimator(model)
	local configuredFolder = Instance.new("Folder")
	configuredFolder.Name = "NpcPoolAnimations"
	configuredFolder.Parent = model
	local tracksByState = {}
	for stateName in pairs(SEARCH_NAMES) do
		local variants = {}
		for _, animation in ipairs(collectAnimations(model, descriptor, stateName, configuredFolder)) do
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if ok and track then
				track.Looped = LOOPED_BY_STATE[stateName] == true
				track.Priority = PRIORITY_BY_STATE[stateName] or Enum.AnimationPriority.Core
				table.insert(variants, { track = track, weight = resolveWeight(animation) })
			end
		end
		tracksByState[stateName] = variants
	end

	self.nextVisualIndex += 1
	local yaw = tonumber(descriptor.facingYawDegrees) or tonumber(model:GetAttribute("NpcFacingYawDegrees")) or 0
	local rootToPivot = root.CFrame:ToObjectSpace(model:GetPivot())
	local record = {
		index = self.nextVisualIndex,
		key = descriptorKey(descriptor),
		descriptor = descriptor,
		model = model,
		root = root,
		rootToPivot = CFrame.Angles(0, math.rad(yaw), 0) * rootToPivot,
		tracksByState = tracksByState,
		vfxEnabled = {},
		sounds = {},
		baselineDescendants = {},
		active = false,
	}

	for _, descendant in ipairs(model:GetDescendants()) do
		record.baselineDescendants[descendant] = true
		if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			record.vfxEnabled[descendant] = descendant.Enabled
		elseif descendant:IsA("Sound") then
			record.sounds[descendant] = true
		end
	end

	model.Name = string.format("NpcVisual_%s_%d", tostring(descriptor.type or "Enemy"), record.index)
	model:SetAttribute("NpcPoolActive", false)
	model.Parent = self.visualFolder
	self:_setVfxActive(record, false)
	self:_park(record)

	local key = record.key
	self.capacityByKey[key] = (self.capacityByKey[key] or 0) + 1
	self.metrics.capacity += 1
	self.metrics.created += 1
	if not prewarming then
		self.metrics.growths += 1
		self.metrics.createdDuringRun += 1
	end
	debug.profileend()
	return record
end

function NpcVisualPool:QueuePrewarm(plan)
	if typeof(plan) ~= "table" then
		return
	end
	for _, rawDescriptor in ipairs(plan) do
		if typeof(rawDescriptor) == "table" and rawDescriptor.type ~= nil then
			local descriptor = table.clone(rawDescriptor)
			descriptor.rank = tostring(descriptor.rank or "Normal")
			descriptor.type = tostring(descriptor.type)
			descriptor.animationIds = typeof(descriptor.animationIds) == "table" and table.clone(descriptor.animationIds) or {}
			local key = descriptorKey(descriptor)
			self.descriptorsByKey[key] = descriptor
			local desired = math.max(0, math.floor(tonumber(descriptor.count) or 0))
			local current = (self.capacityByKey[key] or 0) + (self.prewarmQueuedByKey[key] or 0)
			for _ = current + 1, desired do
				table.insert(self.prewarmQueue, descriptor)
				self.prewarmQueuedByKey[key] = (self.prewarmQueuedByKey[key] or 0) + 1
			end
		end
	end
end

function NpcVisualPool:StepPrewarm(maxCreates: number?): number
	local budget = math.max(0, math.floor(tonumber(maxCreates) or 1))
	local created = 0
	while created < budget and #self.prewarmQueue > 0 do
		local descriptor = table.remove(self.prewarmQueue)
		local key = descriptorKey(descriptor)
		self.prewarmQueuedByKey[key] = math.max(0, (self.prewarmQueuedByKey[key] or 0) - 1)
		local record = self:_create(descriptor, true)
		if record then
			local list = self.inactiveByKey[record.key]
			if not list then
				list = {}
				self.inactiveByKey[record.key] = list
			end
			table.insert(list, record)
		end
		created += 1
	end
	return created
end

function NpcVisualPool:IsPrewarmComplete(): boolean
	return #self.prewarmQueue == 0
end

function NpcVisualPool:Acquire(rawDescriptor, npcId: string)
	local startedAt = os.clock()
	debug.profilebegin("NpcVisualPool.Acquire")
	local descriptor = table.clone(rawDescriptor or {})
	descriptor.rank = tostring(descriptor.rank or "Normal")
	descriptor.type = tostring(descriptor.type or "Enemy")
	descriptor.animationIds = typeof(descriptor.animationIds) == "table" and table.clone(descriptor.animationIds) or {}
	local key = descriptorKey(descriptor)
	local list = self.inactiveByKey[key]
	local record = list and table.remove(list) or nil
	if not record then
		record = self:_create(self.descriptorsByKey[key] or descriptor, false)
	end
	if not record then
		debug.profileend()
		return nil
	end

	record.active = true
	record.id = tostring(npcId)
	record.descriptor = descriptor
	self.activeById[record.id] = record
	self.metrics.active += 1
	self.metrics.acquires += 1

	local model = record.model
	setIdentityAttribute(model, "NpcId", record.id)
	setIdentityAttribute(model, "NpcType", descriptor.type)
	setIdentityAttribute(model, "MobType", descriptor.type)
	setIdentityAttribute(model, "EnemyRank", descriptor.rank)
	setIdentityAttribute(model, "DisplayName", descriptor.displayName or descriptor.type)
	setIdentityAttribute(model, "IsElite", descriptor.isElite == true)
	setIdentityAttribute(model, "IsMiniBoss", descriptor.isMiniBoss == true)
	setIdentityAttribute(model, "IsBoss", descriptor.isBoss == true)
	setIdentityAttribute(model, "NpcVisualScale", tonumber(descriptor.visualScale) or model:GetAttribute("NpcVisualScale") or 1)
	setIdentityAttribute(model, "NpcPoolActive", true)
	self:_setVfxActive(record, true)

	local elapsed = os.clock() - startedAt
	self.metrics.acquireSeconds += elapsed
	self.metrics.acquireMaxSeconds = math.max(self.metrics.acquireMaxSeconds, elapsed)
	debug.profileend()
	return record
end

function NpcVisualPool:Release(record)
	if not record or not record.active then
		return
	end
	local startedAt = os.clock()
	debug.profilebegin("NpcVisualPool.Release")
	self:_stopTracks(record)
	self:_setVfxActive(record, false)
	self:_clearTransientDescendants(record)

	local model = record.model
	model:SetAttribute("NpcId", nil)
	model:SetAttribute("NpcPoolActive", false)
	model:SetAttribute("NpcState", nil)
	model:SetAttribute("NpcDead", nil)
	self:_park(record)

	self.activeById[record.id] = nil
	record.id = nil
	record.active = false
	record.overlayTransform = nil
	local list = self.inactiveByKey[record.key]
	if not list then
		list = {}
		self.inactiveByKey[record.key] = list
	end
	table.insert(list, record)
	self.metrics.active = math.max(0, self.metrics.active - 1)
	self.metrics.releases += 1

	local elapsed = os.clock() - startedAt
	self.metrics.releaseSeconds += elapsed
	self.metrics.releaseMaxSeconds = math.max(self.metrics.releaseMaxSeconds, elapsed)
	debug.profileend()
end

function NpcVisualPool:PlayAnimation(record, stateName: string, transitionToken: any?)
	if not record or not record.active then
		return
	end
	if record.currentAnimationState == stateName
		and record.currentAnimationToken == transitionToken
		and record.currentTrack
		and record.currentTrack.IsPlaying
	then
		return
	end

	local nextTrack = chooseTrack(record.tracksByState[stateName])
	if not nextTrack then
		return
	end
	if record.currentTrack and record.currentTrack ~= nextTrack then
		pcall(function() record.currentTrack:Stop(0.1) end)
	end
	nextTrack.Looped = LOOPED_BY_STATE[stateName] == true
	if not nextTrack.IsPlaying or LOOPED_BY_STATE[stateName] ~= true then
		pcall(function()
			nextTrack.TimePosition = 0
			nextTrack:Play(0.1, 1, 1)
		end)
	end
	record.currentTrack = nextTrack
	record.currentAnimationState = stateName
	record.currentAnimationToken = transitionToken
end

function NpcVisualPool:GetMetrics()
	local result = table.clone(self.metrics)
	result.inactive = math.max(0, result.capacity - result.active)
	result.prewarmRemaining = #self.prewarmQueue
	result.averageAcquireMs = result.acquires > 0 and (result.acquireSeconds / result.acquires) * 1000 or 0
	result.maximumAcquireMs = result.acquireMaxSeconds * 1000
	result.averageReleaseMs = result.releases > 0 and (result.releaseSeconds / result.releases) * 1000 or 0
	result.maximumReleaseMs = result.releaseMaxSeconds * 1000
	return result
end

return NpcVisualPool
