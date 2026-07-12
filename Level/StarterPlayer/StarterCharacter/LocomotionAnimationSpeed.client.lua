-- Keeps walk/run animation playback independent from the character's movement speed.

local RunService = game:GetService("RunService")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local animateScript = character:WaitForChild("Animate")

local LOCOMOTION_PLAYBACK_SPEED = 1
local trackedTracks = setmetatable({}, { __mode = "k" })

local function isWalkOrRunName(name)
	local loweredName = string.lower(name)
	return loweredName == "walk"
		or loweredName == "run"
		or loweredName == "walkanim"
		or loweredName == "runanim"
end

local function belongsToWalkOrRunSet(animation)
	local current = animation
	while current and current ~= animateScript do
		if isWalkOrRunName(current.Name) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isLocomotionTrack(track)
	if isWalkOrRunName(track.Name) then
		return true
	end

	local animation = track.Animation
	return animation ~= nil and belongsToWalkOrRunSet(animation)
end

local function enforceTrackSpeed(track)
	if not isLocomotionTrack(track) then
		return
	end

	trackedTracks[track] = true
	track:AdjustSpeed(LOCOMOTION_PLAYBACK_SPEED)
end

local function enforcePlayingTracks()
	for _, track in animator:GetPlayingAnimationTracks() do
		enforceTrackSpeed(track)
	end
end

animator.AnimationPlayed:Connect(enforceTrackSpeed)

-- Animate.lua changes locomotion speed from Humanoid.Running. Defer this pass so it
-- runs after the event's existing listeners and restores the fixed playback speed.
humanoid.Running:Connect(function()
	task.defer(enforcePlayingTracks)
end)

-- Guard against any later AdjustSpeed calls from Animate.lua or another controller.
RunService.PreAnimation:Connect(function()
	for track in trackedTracks do
		if track.IsPlaying then
			if math.abs(track.Speed - LOCOMOTION_PLAYBACK_SPEED) > 0.001 then
				track:AdjustSpeed(LOCOMOTION_PLAYBACK_SPEED)
			end
		else
			trackedTracks[track] = nil
		end
	end
end)

enforcePlayingTracks()
