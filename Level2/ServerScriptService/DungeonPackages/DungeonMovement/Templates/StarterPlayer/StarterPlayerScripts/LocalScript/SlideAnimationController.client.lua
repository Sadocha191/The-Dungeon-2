local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

if not moduleFolder then
	warn("[SlideAnimation] Movement config folder was not found.")
	return
end

local MovementConfig = require(moduleFolder:WaitForChild("MovementConfig"))
local slideActiveAttribute = MovementConfig.SlideActiveAttribute

if type(slideActiveAttribute) ~= "string" or slideActiveAttribute == "" then
	warn("[SlideAnimation] Slide state attribute is not configured.")
	return
end

local humanoidConnection: RBXScriptConnection? = nil
local deathConnection: RBXScriptConnection? = nil
local slideTrack: AnimationTrack? = nil

local function stopSlideAnimation()
	local track = slideTrack
	slideTrack = nil

	if not track then
		return
	end

	track:Stop(tonumber(MovementConfig.SlideAnimationFadeTime) or 0.1)
	track:Destroy()
end

local function playSlideAnimation(humanoid: Humanoid)
	if slideTrack and slideTrack.IsPlaying then
		return
	end

	stopSlideAnimation()

	local animationId = MovementConfig.SlideAnimationId
	if type(animationId) ~= "string" or animationId == "" then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = humanoid:WaitForChild("Animator", 2)
	end
	if not animator or not animator:IsA("Animator") then
		warn("[SlideAnimation] Animator was not found.")
		return
	end

	local animation = Instance.new("Animation")
	animation.Name = "SlideAnimation"
	animation.AnimationId = animationId

	local success, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if not success then
		warn("[SlideAnimation] Failed to load animation:", trackOrError)
		return
	end

	local track = trackOrError :: AnimationTrack
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(
		tonumber(MovementConfig.SlideAnimationFadeTime) or 0.1,
		1,
		tonumber(MovementConfig.SlideAnimationSpeed) or 1
	)
	slideTrack = track
end

local function updateSlideAnimation(humanoid: Humanoid)
	local isSliding = humanoid.Health > 0 and humanoid:GetAttribute(slideActiveAttribute) == true

	if isSliding then
		playSlideAnimation(humanoid)
	else
		stopSlideAnimation()
	end
end

local function disconnectCharacter()
	if humanoidConnection then
		humanoidConnection:Disconnect()
		humanoidConnection = nil
	end
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end
	stopSlideAnimation()
end

local function bindCharacter(character: Model)
	disconnectCharacter()

	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	humanoidConnection = humanoid:GetAttributeChangedSignal(slideActiveAttribute):Connect(function()
		updateSlideAnimation(humanoid)
	end)
	deathConnection = humanoid.Died:Connect(stopSlideAnimation)

	updateSlideAnimation(humanoid)
end

player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(disconnectCharacter)

if player.Character then
	task.defer(bindCharacter, player.Character)
end
