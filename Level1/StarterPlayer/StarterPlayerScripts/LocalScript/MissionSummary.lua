-- MissionSummary.client.lua (Level1)
-- Game Over UI. Listens on Remotes/MissionSummaryEvent type="gameover".
-- If you already have ReturnToLobby RemoteEvent, it will use it; otherwise it only shows stats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local MissionSummaryEvent = remotes:WaitForChild("MissionSummaryEvent")

local ReturnToLobby = ReplicatedStorage:FindFirstChild("ReturnToLobby")

local gui = Instance.new("ScreenGui")
gui.Name = "MissionSummary"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = pg

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1,1)
dim.BackgroundColor3 = Color3.fromRGB(0,0,0)
dim.BackgroundTransparency = 0.35
dim.BorderSizePixel = 0
dim.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5,0.5)
card.Position = UDim2.fromScale(0.5,0.5)
card.Size = UDim2.fromScale(0.62, 0.52)
card.BackgroundColor3 = Color3.fromRGB(14,14,16)
card.BackgroundTransparency = 0.06
card.BorderSizePixel = 0
card.Parent = dim
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)
local cardSizeConstraint = Instance.new("UISizeConstraint", card)
cardSizeConstraint.MaxSize = Vector2.new(560, 320)
local cardAspect = Instance.new("UIAspectRatioConstraint", card)
cardAspect.AspectRatio = 560 / 320
cardAspect.DominantAxis = Enum.DominantAxis.Height

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 16)
title.Size = UDim2.new(1, -44, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.TextColor3 = Color3.fromRGB(245,245,245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Game Over"
title.Parent = card

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -16, 0, 16)
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.TextColor3 = Color3.fromRGB(245, 245, 245)
closeButton.Text = "X"
closeButton.Parent = card
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 10)

local body = Instance.new("TextLabel")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(22, 58)
body.Size = UDim2.new(1, -44, 1, -120)
body.Font = Enum.Font.Gotham
body.TextSize = 15
body.TextColor3 = Color3.fromRGB(220,220,220)
body.TextWrapped = true
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextXAlignment = Enum.TextXAlignment.Left
body.Text = ""
body.Parent = card

local btn = Instance.new("TextButton")
btn.AnchorPoint = Vector2.new(0.5, 1)
btn.Position = UDim2.new(0.5, 0, 1, -22)
btn.Size = UDim2.fromOffset(220, 40)
btn.BackgroundColor3 = Color3.fromRGB(120,190,255)
btn.BorderSizePixel = 0
btn.Font = Enum.Font.GothamBold
btn.TextSize = 15
btn.TextColor3 = Color3.fromRGB(10,10,10)
btn.Text = ReturnToLobby and "Return to Village" or "Close"
btn.Parent = card
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

btn.MouseButton1Click:Connect(function()
	if ReturnToLobby and ReturnToLobby:IsA("RemoteEvent") then
		ReturnToLobby:FireServer()
	else
		gui.Enabled = false
	end
end)

closeButton.MouseButton1Click:Connect(function()
	if ReturnToLobby and ReturnToLobby:IsA("RemoteEvent") then
		ReturnToLobby:FireServer()
	else
		gui.Enabled = false
	end
end)

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec or 0))
	local m = math.floor(sec / 60)
	local s = sec % 60
	return string.format("%02d:%02d", m, s)
end

MissionSummaryEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type ~= "gameover" then return end

	local sec = tonumber(payload.time) or 0
	local kills = tonumber(payload.kills) or 0
	local coins = tonumber(payload.coinsGained) or 0
	local xp = tonumber(payload.accountXp) or 0
	local lvl = tonumber(payload.accountLevel) or 1
	local reason = tostring(payload.reason or "Game Over")

	body.Text = ("Reason: %s\nRun time: %s\nEnemies defeated: %d\nSilver gained: %d\nAccount XP gained: %d\nAccount level: %d"):format(
		reason, fmtTime(sec), kills, coins, xp, lvl
	)
	gui.Enabled = true
end)
