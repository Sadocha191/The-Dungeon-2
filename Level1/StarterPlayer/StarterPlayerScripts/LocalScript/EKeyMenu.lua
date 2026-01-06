-- EKeyMenu.client.lua (StarterPlayerScripts)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local PauseState = ReplicatedStorage:WaitForChild("PauseState")

local returnToLobby = ReplicatedStorage:WaitForChild("ReturnToLobby")

local gui = Instance.new("ScreenGui")
gui.Name = "EKeyMenu"
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")
gui.Enabled = false
gui:SetAttribute("Modal", true)

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1,1)
overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.5
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5,0.5)
panel.Position = UDim2.fromScale(0.5,0.5)
panel.Size = UDim2.fromOffset(420, 220)
panel.BackgroundColor3 = Color3.fromRGB(14,14,16)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 16)
title.Size = UDim2.new(1,-36,0,28)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Text = "Menu (E)"
title.Parent = panel

local btnLobby = Instance.new("TextButton")
btnLobby.Position = UDim2.fromOffset(18, 70)
btnLobby.Size = UDim2.new(1,-36,0,46)
btnLobby.BackgroundColor3 = Color3.fromRGB(60,140,255)
btnLobby.BorderSizePixel = 0
btnLobby.Font = Enum.Font.GothamBold
btnLobby.TextSize = 16
btnLobby.TextColor3 = Color3.fromRGB(255,255,255)
btnLobby.Text = "Return to lobby"
btnLobby.Parent = panel
Instance.new("UICorner", btnLobby).CornerRadius = UDim.new(0, 14)

local btnClose = Instance.new("TextButton")
btnClose.Position = UDim2.fromOffset(18, 130)
btnClose.Size = UDim2.new(1,-36,0,46)
btnClose.BackgroundColor3 = Color3.fromRGB(30,30,34)
btnClose.BorderSizePixel = 0
btnClose.Font = Enum.Font.GothamBold
btnClose.TextSize = 16
btnClose.TextColor3 = Color3.fromRGB(255,255,255)
btnClose.Text = "Close"
btnClose.Parent = panel
Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 14)

local function open()
	gui.Enabled = true
	PauseState.Value = true
end
local function close()
	gui.Enabled = false
	PauseState.Value = false
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.E then
		if gui.Enabled then close() else open() end
	end
end)

btnClose.MouseButton1Click:Connect(close)

btnLobby.MouseButton1Click:Connect(function()
	returnToLobby:FireServer()
end)
