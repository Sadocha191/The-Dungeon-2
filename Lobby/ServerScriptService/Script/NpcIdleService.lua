local Workspace = game:GetService("Workspace")

local IDLE_ANIMATION_ID = "rbxassetid://180435571"

local npcFolder = Workspace:FindFirstChild("NPCs")
if not npcFolder then
	warn("[NpcIdleService] Missing workspace.NPCs")
	return
end

local idleAnimation = Instance.new("Animation")
idleAnimation.Name = "LobbyNpcIdle"
idleAnimation.AnimationId = IDLE_ANIMATION_ID

local tracked = {}

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

	local ok, track = pcall(function()
		return animator:LoadAnimation(idleAnimation)
	end)
	if not ok or not track then
		warn(string.format("[NpcIdleService] Failed to load idle for %s", model:GetFullName()))
		return
	end

	track.Name = string.format("%sIdleTrack", model.Name)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.15, 1, 1)

	local state = {
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

for _, child in ipairs(npcFolder:GetChildren()) do
	startIdle(child)
end

npcFolder.ChildAdded:Connect(function(child)
	task.defer(startIdle, child)
end)

print("[NpcIdleService] Ready")
