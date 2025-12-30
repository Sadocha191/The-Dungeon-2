-- MissionSummary.client.lua (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local MissionSummaryEvent = remotes:WaitForChild("MissionSummaryEvent")

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
card.Size = UDim2.fromOffset(520, 260)
card.BackgroundColor3 = Color3.fromRGB(14,14,16)
card.BackgroundTransparency = 0.06
card.BorderSizePixel = 0
card.Parent = dim
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(22, 16)
title.Size = UDim2.new(1, -44, 0, 26)
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Text = "Misja ukończona"
title.Parent = card

local body = Instance.new("TextLabel")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(22, 56)
body.Size = UDim2.new(1, -44, 1, -96)
body.Font = Enum.Font.Gotham
body.TextSize = 14
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextColor3 = Color3.fromRGB(220,220,220)
body.TextWrapped = true
body.Text = ""
body.Parent = card

local ok = Instance.new("TextButton")
ok.AnchorPoint = Vector2.new(0.5,1)
ok.Position = UDim2.new(0.5,0,1,-18)
ok.Size = UDim2.fromOffset(220, 40)
ok.BackgroundColor3 = Color3.fromRGB(96,165,250)
ok.BorderSizePixel = 0
ok.Font = Enum.Font.GothamBold
ok.TextSize = 14
ok.TextColor3 = Color3.fromRGB(10,10,12)
ok.Text = "OK"
ok.Parent = card
Instance.new("UICorner", ok).CornerRadius = UDim.new(0, 14)

ok.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

MissionSummaryEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "summary" then return end
	local waves = tonumber(payload.waves) or 0
	local sec = tonumber(payload.time) or 0
	local lvl = tonumber(payload.level) or 1
	local coins = tonumber(payload.coins) or 0
	body.Text = ("Fale: %d\nCzas: %ds\nPoziom: %d\nMonety (global): %d"):format(waves, sec, lvl, coins)
	gui.Enabled = true
end)
