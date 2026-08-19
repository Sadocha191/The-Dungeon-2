local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function getToggleEvent(): BindableEvent?
	local pauseGui = playerGui:FindFirstChild("Pause") or playerGui:WaitForChild("Pause", 10)
	if not pauseGui or not pauseGui:IsA("ScreenGui") then
		return nil
	end

	local toggleRequested = pauseGui:FindFirstChild("ToggleRequested") or pauseGui:WaitForChild("ToggleRequested", 10)
	if toggleRequested and toggleRequested:IsA("BindableEvent") then
		return toggleRequested
	end

	return nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.P then
		return
	end

	local toggleRequested = getToggleEvent()
	if toggleRequested then
		toggleRequested:Fire()
	end
end)
