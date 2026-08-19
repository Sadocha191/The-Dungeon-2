-- Keeps walk/run animation playback independent from the character's movement speed.

local RunService = game:GetService("RunService")

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local animateScript = character:WaitForChild("Animate")

local DEFAULT_PLAYBACK_SPEED_BY_KIND = {
	walk = 1,
	run = 1,
}

local PLAYBACK_SPEED_ATTRIBUTE_BY_KIND = {
	walk = "WalkPlaybackSpeed",
	run = "RunPlaybackSpeed",
}

local MAX_PLAYBACK_SPEED = 4
local playbackSpeedByKind = {}
local trackedTracks = setmetatable({}, { __mode = "k" })

local function clampPlaybackSpeed(value, fallback)
	local numericValue = tonumber(value)
	if numericValue == nil or numericValue ~= numericValue then
		return fallback
	end
	return math.clamp(numericValue, 0, MAX_PLAYBACK_SPEED)
end

local function refreshPlaybackSpeed(kind)
	local attributeName = PLAYBACK_SPEED_ATTRIBUTE_BY_KIND[kind]
	local defaultValue = DEFAULT_PLAYBACK_SPEED_BY_KIND[kind]
	if script:GetAttribute(attributeName) == nil then
		script:SetAttribute(attributeName, defaultValue)
	end
	playbackSpeedByKind[kind] = clampPlaybackSpeed(script:GetAttribute(attributeName), defaultValue)
end

for kind in pairs(PLAYBACK_SPEED_ATTRIBUTE_BY_KIND) do
	refreshPlaybackSpeed(kind)
end

local function resolveWalkOrRunKind(name)
	local loweredName = string.lower(name)
	if loweredName == "walk" or loweredName == "walkanim" then
		return "walk"
	end
	if loweredName == "run" or loweredName == "runanim" then
		return "run"
	end
	return nil
end

local function resolveAnimationKind(animation)
	local current = animation
	while current and current ~= animateScript do
		local kind = resolveWalkOrRunKind(current.Name)
		if kind then
			return kind
		end
		current = current.Parent
	end
	return nil
end

local function resolveTrackKind(track)
	local trackKind = resolveWalkOrRunKind(track.Name)
	if trackKind then
		return trackKind
	end

	local animation = track.Animation
	if animation == nil then
		return nil
	end
	return resolveAnimationKind(animation)
end

local function enforceTrackSpeed(track)
	local kind = resolveTrackKind(track)
	if not kind then
		return
	end

	trackedTracks[track] = kind
	track:AdjustSpeed(playbackSpeedByKind[kind])
end

local function enforcePlayingTracks()
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
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
	for track, kind in pairs(trackedTracks) do
		if track.IsPlaying then
			local playbackSpeed = playbackSpeedByKind[kind]
			if math.abs(track.Speed - playbackSpeed) > 0.001 then
				track:AdjustSpeed(playbackSpeed)
			end
		else
			trackedTracks[track] = nil
		end
	end
end)

for kind, attributeName in pairs(PLAYBACK_SPEED_ATTRIBUTE_BY_KIND) do
	script:GetAttributeChangedSignal(attributeName):Connect(function()
		refreshPlaybackSpeed(kind)
		enforcePlayingTracks()
	end)
end

enforcePlayingTracks()
