-- LobbyPauseState.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
else
	if PauseState:IsA("BoolValue") then
		PauseState.Value = false
	end
end
