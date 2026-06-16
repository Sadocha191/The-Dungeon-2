local Workspace = game:GetService("Workspace")

local DEFAULT_IDLE_ANIMATION_ID = "rbxassetid://180435571"
local NPC_IDLE_ANIMATION_IDS = {
	Blacksmith = "rbxassetid://82125789411976",
}

local npcFolder = Workspace:FindFirstChild("NPCs")
local EXTRA_IDLE_NPCS = {
	Blacksmith = true,
}

local tracked = {}

local function getIdleAnimationId(model)
	return NPC_IDLE_ANIMATION_IDS[model.Name] or DEFAULT_IDLE_ANIMATION_ID
end

local function cleanup(model)
	local state = tracked[model]
	if not state then
		return
	end

	if state.trackStoppedConnection then
		state.trackStoppedConnection:Disconnect()
	end
	if state.diedConnection then
		state.diedConnection:Disconnect()
	end
	if state.ancestryConnection then
		state.ancestryConnection:Disconnect()
	end
	if state.track then
		pcall(function()
			state.track:Stop(0.1)
			state.track:Destroy()
		end)
	end
	if state.animation then
		state.animation:Destroy()
	end

	tracked[model] = nil
end

local function ensureAnimator(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

local function hasPlayingTracks(animator)
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.IsPlaying then
			return true
		end
	end
	return false
end

local function startIdle(model)
	if tracked[model] then
		return
	end
	if not model:IsA("Model") then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local animator = ensureAnimator(humanoid)
	if hasPlayingTracks(animator) then
		return
	end

	local idleAnimation = Instance.new("Animation")
	idleAnimation.Name = string.format("%sIdleAnimation", model.Name)
	idleAnimation.AnimationId = getIdleAnimationId(model)

	local ok, track = pcall(function()
		return animator:LoadAnimation(idleAnimation)
	end)
	if not ok or not track then
		idleAnimation:Destroy()
		warn(string.format("[NpcIdleService] Failed to load idle for %s", model:GetFullName()))
		return
	end

	track.Name = string.format("%sIdleTrack", model.Name)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.15, 1, 1)

	local state = {
		animation = idleAnimation,
		track = track,
	}
	tracked[model] = state

	state.trackStoppedConnection = track.Stopped:Connect(function()
		cleanup(model)
		if model.Parent and humanoid.Parent and humanoid.Health > 0 then
			task.defer(startIdle, model)
		end
	end)

	state.diedConnection = humanoid.Died:Connect(function()
		cleanup(model)
	end)

	state.ancestryConnection = model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanup(model)
		end
		end)
end

if npcFolder then
	for _, child in ipairs(npcFolder:GetChildren()) do
		startIdle(child)
	end

	npcFolder.ChildAdded:Connect(function(child)
		task.defer(startIdle, child)
	end)
else
	warn("[NpcIdleService] Missing workspace.NPCs")
end

for modelName in pairs(EXTRA_IDLE_NPCS) do
	local model = Workspace:FindFirstChild(modelName)
	if model then
		startIdle(model)
	end
end

Workspace.ChildAdded:Connect(function(child)
	if EXTRA_IDLE_NPCS[child.Name] then
		task.defer(startIdle, child)
	end
end)

print("[NpcIdleService] Ready")