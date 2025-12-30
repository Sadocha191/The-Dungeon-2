-- WaveHud.client.lua (StarterPlayerScripts) - lewy panel + countdown

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local WaveStatusEvent = ReplicatedStorage:WaitForChild("WaveStatusEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "WaveHud"
gui.ResetOnSpawn = false
gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- LEFT PANEL
local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(18, 18)
panel.Size = UDim2.fromOffset(260, 120)
panel.BackgroundColor3 = Color3.fromRGB(14,14,16)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local pad = Instance.new("UIPadding", panel)
pad.PaddingLeft = UDim.new(0, 12)
pad.PaddingRight = UDim.new(0, 12)
pad.PaddingTop = UDim.new(0, 10)
pad.PaddingBottom = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1,0,0,20)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Text = "Fala -/-"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromOffset(0, 22)
sub.Size = UDim2.new(1,0,0,18)
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextColor3 = Color3.fromRGB(210,210,210)
sub.Text = "Zostało: -/-"
sub.Parent = panel

local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(0, 48)
barBack.Size = UDim2.new(1,0,0,10)
barBack.BackgroundColor3 = Color3.fromRGB(40,40,44)
barBack.BorderSizePixel = 0
barBack.Parent = panel
Instance.new("UICorner", barBack).CornerRadius = UDim.new(0, 999)

local fill = Instance.new("Frame")
fill.Size = UDim2.new(1,0,1,0)
fill.BackgroundColor3 = Color3.fromRGB(255,180,60)
fill.BorderSizePixel = 0
fill.Parent = barBack
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 999)

local function setBar(p)
	p = math.clamp(p, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(p, 0, 1, 0)
	}):Play()
end

-- CENTER COUNTDOWN
local center = Instance.new("TextLabel")
center.AnchorPoint = Vector2.new(0.5, 0)
center.Position = UDim2.new(0.5, 0, 0, 18)
center.Size = UDim2.fromOffset(520, 44)
center.BackgroundColor3 = Color3.fromRGB(14,14,16)
center.BackgroundTransparency = 0.2
center.BorderSizePixel = 0
center.Font = Enum.Font.GothamBold
center.TextSize = 22
center.TextColor3 = Color3.fromRGB(255,255,255)
center.Visible = false
center.Parent = gui
Instance.new("UICorner", center).CornerRadius = UDim.new(0, 14)

WaveStatusEvent.OnClientEvent:Connect(function(p)
	if typeof(p) ~= "table" then return end

	if p.type == "prepTick" then
		local s = tonumber(p.seconds) or 0
		center.Visible = s > 0
		if s > 0 then center.Text = ("START ZA: %d"):format(s) end

	elseif p.type == "waveCountdown" then
		local s = tonumber(p.seconds) or 0
		center.Visible = s > 0
		if s > 0 then center.Text = ("NOWA FALA ZA: %d"):format(s) end

	elseif p.type == "waveStart" or p.type == "waveUpdate" then
		local wave = tonumber(p.wave) or 0
		local tw = tonumber(p.totalWaves) or 0
		local rem = tonumber(p.remaining) or 0
		local tot = tonumber(p.totalToKill) or 1

		title.Text = ("Fala %d/%d"):format(wave, tw)
		sub.Text = ("Zostało: %d/%d"):format(rem, tot)
		setBar(rem / math.max(1, tot))

	elseif p.type == "complete" then
		title.Text = "Misja ukończona"
		sub.Text = ""
		setBar(0)
	end
end)
