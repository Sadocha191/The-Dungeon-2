-- WeaponClient.client.lua (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local WeaponEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponEvent")

local mouse = plr:GetMouse()

local function getEquippedTool()
	local char = plr.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Tool")
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if PauseState.Value then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

	local tool = getEquippedTool()
	if not tool then return end

	local wType = tool:GetAttribute("WeaponType")
	if typeof(wType) ~= "string" then return end

	if wType == "Melee" then
		WeaponEvent:FireServer({ action = "MELEE" })
	elseif wType == "Bow" or wType == "Wand" then
		local hitPos = mouse.Hit and mouse.Hit.Position
		if typeof(hitPos) ~= "Vector3" then return end
		WeaponEvent:FireServer({ action = "SHOOT", aim = hitPos })
	end
end)
