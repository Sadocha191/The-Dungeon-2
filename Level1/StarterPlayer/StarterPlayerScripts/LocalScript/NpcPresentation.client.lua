local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local batchEvent = remotes:WaitForChild("NpcBatchEvent")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript")
local NpcShared = require(moduleFolder:WaitForChild("NpcShared"))

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

local presentations = {}

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

local function computeRootToPivot(model: Model, root: BasePart): CFrame?
	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)
	if not ok then
		return nil
	end
	return root.CFrame:ToObjectSpace(pivot)
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
		entry.rootToPivot = computeRootToPivot(model, root)
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

local function collectAnimations(model: Model, stateName: string): {Animation}
	local list = {}
	local seen = {}
	local names = SEARCH_NAMES[stateName] or { stateName }

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Animation") then
			local lower = string.lower(descendant.Name)
			for _, probe in ipairs(names) do
				if lower == probe or string.find(lower, probe, 1, true) then
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
	entry.animBuilt = true
	entry.animTracks = {}

	local model = entry.model
	if not model then
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

local function playAnimation(entry)
	buildTracks(entry)
	local animState = NpcShared.AnimationStateByNpcState[entry.state] or "idle"
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
	gui.Size = UDim2.fromOffset(110, 14)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = root
	gui.Parent = entry.model

	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
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
	entry.healthFill = fill
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
	gui.Enabled = not entry.dead
end

local function cleanupEntry(id: string)
	local entry = presentations[id]
	if not entry then
		return
	end
	if entry.currentTrack then
		pcall(function()
			entry.currentTrack:Stop(0)
		end)
	end
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
		hp = 0,
		maxHp = 1,
		dead = false,
		despawned = false,
		lastSeen = os.clock(),
		rootToPivot = nil,
		boundRoot = nil,
	}
	presentations[id] = entry
	return entry
end

batchEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local items = payload.items
	if typeof(items) ~= "table" then
		return
	end

	local now = os.clock()
	for _, item in ipairs(items) do
		if typeof(item) == "table" and item.id ~= nil then
			local id = tostring(item.id)
			local entry = ensureEntry(id)
			if typeof(item.model) == "Instance" and item.model:IsA("Model") then
				entry.model = item.model
				refreshRigBinding(entry)
			end
			if typeof(item.pos) == "Vector3" then
				entry.targetPos = item.pos
				if not entry.renderPos then
					entry.renderPos = item.pos
				end
			end
			if typeof(item.dir) == "Vector3" then
				entry.targetDir = flatDir(item.dir)
				if not entry.renderDir then
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
			updateHealthbar(entry)
			playAnimation(entry)
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for id, entry in pairs(presentations) do
		local model = entry.model
		if (entry.despawned and (not model or not model.Parent)) or (now - entry.lastSeen) > 2 then
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
		local goalDir = flatDir(entry.targetDir or entry.velocity)
		if typeof(entry.velocity) == "Vector3" and entry.velocity.Magnitude > 0.2 then
			goalDir = flatDir(entry.velocity)
		end

		entry.renderPos = entry.renderPos and entry.renderPos:Lerp(goalPos, math.clamp(dt * 12, 0, 1)) or goalPos
		entry.renderDir = entry.renderDir and entry.renderDir:Lerp(goalDir, math.clamp(dt * 14, 0, 1)) or goalDir
		entry.renderDir = flatDir(entry.renderDir)

		refreshRigBinding(entry)
		local rootFrame = CFrame.lookAt(entry.renderPos, entry.renderPos + entry.renderDir)
		if entry.rootToPivot then
			model:PivotTo(rootFrame * entry.rootToPivot)
		else
			model:PivotTo(rootFrame)
		end
		updateHealthbar(entry)
		playAnimation(entry)
	end
end)



