local Players = game:GetService("Players")

local LEVEL_LOCOMOTION_ANIMATION_ID = "rbxassetid://89814244152772"

local function setAnimationId(animateScript, setName, animationName)
	local animationSet = animateScript:WaitForChild(setName, 5)
	if not animationSet then
		return
	end

	local animation = animationSet:WaitForChild(animationName, 5)
	if animation and animation:IsA("Animation") then
		animation.AnimationId = LEVEL_LOCOMOTION_ANIMATION_ID
	end
end

local function applyLevelLocomotionAnimations(character)
	local animateScript = character:WaitForChild("Animate", 10)
	if not animateScript then
		return
	end

	setAnimationId(animateScript, "walk", "WalkAnim")
	setAnimationId(animateScript, "run", "RunAnim")
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(applyLevelLocomotionAnimations)

	if player.Character then
		task.spawn(applyLevelLocomotionAnimations, player.Character)
	end
end

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
