-- Replace with your default animation IDs

local Players = game:GetService("Players")

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	print("Animator found!")

	local animateScript = character:WaitForChild("Animate")
	animateScript.walk.WalkAnim.AnimationId = "rbxassetid://89814244152772"
	local animateScript = character:WaitForChild("Animate")
	animateScript.run.RunAnim.AnimationId = "rbxassetid://89814244152772"
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(onPlayerAdded)