-- EscMenu.client.lua

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local returnToLobby = ReplicatedStorage:WaitForChild("ReturnToLobby")

local plr = Players.LocalPlayer
local gui = Instance.new("ScreenGui", plr.PlayerGui)
gui.Name = "EscMenu"
gui.Enabled = false
gui:SetAttribute("Modal", true)

local btn = Instance.new("TextButton", gui)
btn.Size = UDim2.fromOffset(260, 60)
btn.Position = UDim2.fromScale(0.5, 0.5)
btn.AnchorPoint = Vector2.new(0.5, 0.5)
btn.Text = "WRÓĆ DO LOBBY"
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16

UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.Escape then
		gui.Enabled = not gui.Enabled
	end
end)

btn.MouseButton1Click:Connect(function()
	returnToLobby:FireServer()
end)
