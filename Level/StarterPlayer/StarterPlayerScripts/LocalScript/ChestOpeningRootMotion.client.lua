local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CHEST_OPENING_GUI_NAME = "ChestOpening"
local CHEST_MODEL_NAME = "skrzynia"
local ROOT_MOTION_BONE_NAME = "Bone"
local OPEN_ANIMATION_NAME = "OpenAnimation"
local OPEN_ANIMATION_ID = "rbxassetid://128606196135074"
local TRACK_TIME_EPSILON = 1e-5

local activeRootMotion = nil
local guiEnabledConnection = nil

local function findRootMotionBone(chestModel)
	local namedBone = chestModel:FindFirstChild(ROOT_MOTION_BONE_NAME, true)
	if namedBone and namedBone:IsA("Bone") then
		return namedBone
	end

	local rootBones = {}
	for _, descendant in ipairs(chestModel:GetDescendants()) do
		if descendant:IsA("Bone") and not descendant.Parent:IsA("Bone") then
			table.insert(rootBones, descendant)
		end
	end

	if #rootBones == 1 then
		return rootBones[1]
	end

	return nil
end

local function getChestAnimator(chestModel)
	local controller = chestModel:FindFirstChildOfClass("AnimationController")
	return controller and controller:FindFirstChildOfClass("Animator") or nil
end

local function isOpenAnimationTrack(track)
	if track.Name == OPEN_ANIMATION_NAME then
		return true
	end

	local animationId = nil
	pcall(function()
		local animation = track.Animation
		animationId = animation and animation.AnimationId or nil
	end)
	return animationId == OPEN_ANIMATION_ID
end

local function findOpenAnimationTrack(animator)
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if isOpenAnimationTrack(track) then
			return track
		end
	end
	return nil
end

local function stopRootMotion(restoreBasePivot)
	local state = activeRootMotion
	activeRootMotion = nil
	if not state then
		return
	end

	if state.renderConnection then
		state.renderConnection:Disconnect()
	end

	if state.rootBone and state.rootBone.Parent then
		state.rootBone.Transform = CFrame.identity
	end

	if restoreBasePivot ~= false and state.chestModel and state.chestModel.Parent then
		state.chestModel:PivotTo(state.basePivot)
	end
end

local function startRootMotion(openingGui, chestModel)
	stopRootMotion(true)

	local rootBone = findRootMotionBone(chestModel)
	if not rootBone then
		warn("[ChestOpeningRootMotion] Root Bone not found in ChestOpening.skrzynia")
		return
	end

	local animator = getChestAnimator(chestModel)
	if not animator then
		warn("[ChestOpeningRootMotion] Animator not found in ChestOpening.skrzynia")
		return
	end

	-- The imported animation stores the chest jump on the armature root Bone.
	-- Roblox evaluates that transform inside the skinned mesh but does not move
	-- the containing Model in a WorldModel. Convert that exact authored transform
	-- into Model pivot motion and clear it from the Bone to avoid double movement.
	rootBone.Transform = CFrame.identity
	local basePivot = chestModel:GetPivot()
	local boneFromPivot = basePivot:ToObjectSpace(rootBone.WorldCFrame)

	local state = {
		openingGui = openingGui,
		chestModel = chestModel,
		rootBone = rootBone,
		animator = animator,
		basePivot = basePivot,
		boneFromPivot = boneFromPivot,
		pivotFromBone = boneFromPivot:Inverse(),
		lastRootTransform = CFrame.identity,
		currentTrack = nil,
		lastTrackTime = nil,
		renderConnection = nil,
	}
	activeRootMotion = state

	state.renderConnection = RunService.PreRender:Connect(function()
		if activeRootMotion ~= state then
			return
		end
		if not openingGui.Enabled or not chestModel.Parent or not rootBone.Parent then
			return
		end

		local track = findOpenAnimationTrack(animator)
		local sampledTransform = rootBone.Transform
		if track then
			local trackTime = track.TimePosition
			local trackChanged = track ~= state.currentTrack
			local timeChanged = state.lastTrackTime == nil
				or math.abs(trackTime - state.lastTrackTime) > TRACK_TIME_EPSILON

			-- While the track advances, the Animator has supplied a fresh Bone.Transform.
			-- When ChestRewardClient freezes the final frame at speed 0, retain the last
			-- sampled transform instead of mistaking our own identity reset for new data.
			if trackChanged or timeChanged or sampledTransform ~= CFrame.identity then
				state.lastRootTransform = sampledTransform
			end
			state.currentTrack = track
			state.lastTrackTime = trackTime
		elseif sampledTransform ~= CFrame.identity then
			state.lastRootTransform = sampledTransform
			state.currentTrack = nil
			state.lastTrackTime = nil
		end

		local rootTransform = state.lastRootTransform
		chestModel:PivotTo(
			basePivot
				* state.boneFromPivot
				* rootTransform
				* state.pivotFromBone
		)
		rootBone.Transform = CFrame.identity
	end)
end

local function bindOpeningGui(openingGui)
	if guiEnabledConnection then
		guiEnabledConnection:Disconnect()
		guiEnabledConnection = nil
	end
	stopRootMotion(true)

	local function syncEnabledState()
		if not openingGui.Enabled then
			stopRootMotion(true)
			return
		end

		local chestModel = openingGui:FindFirstChild(CHEST_MODEL_NAME, true)
		if not chestModel or not chestModel:IsA("Model") then
			warn("[ChestOpeningRootMotion] ChestOpening.skrzynia model not found")
			return
		end
		startRootMotion(openingGui, chestModel)
	end

	guiEnabledConnection = openingGui:GetPropertyChangedSignal("Enabled"):Connect(syncEnabledState)
	syncEnabledState()
end

local openingGui = playerGui:WaitForChild(CHEST_OPENING_GUI_NAME)
if openingGui:IsA("ScreenGui") then
	bindOpeningGui(openingGui)
else
	warn("[ChestOpeningRootMotion] ChestOpening must be a ScreenGui")
end
