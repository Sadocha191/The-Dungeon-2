-- WaveUI.client.lua (StarterPlayerScripts) - Progress bar + countdown

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")
local WaveStatusEvent = ReplicatedStorage:WaitForChild("WaveStatusEvent")

-- single instance
local existing = pg:FindFirstChild("WaveUI")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "WaveUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = pg

-- Left panel with progress
local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(18, 18)
panel.Size = UDim2.fromOffset(260, 84)
panel.BackgroundColor3 = Color3.fromRGB(14,14,16)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local pad = Instance.new("UIPadding", panel)
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.PaddingTop = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 12)

local waveText = Instance.new("TextLabel")
waveText.BackgroundTransparency = 1
waveText.Size = UDim2.new(1,0,0,18)
waveText.Font = Enum.Font.GothamBold
waveText.TextSize = 14
waveText.TextXAlignment = Enum.TextXAlignment.Left
waveText.TextColor3 = Color3.fromRGB(245,245,245)
waveText.Text = "Fala: -"
waveText.Parent = panel

local subText = Instance.new("TextLabel")
subText.BackgroundTransparency = 1
subText.Position = UDim2.fromOffset(0, 20)
subText.Size = UDim2.new(1,0,0,16)
subText.Font = Enum.Font.Gotham
subText.TextSize = 12
subText.TextXAlignment = Enum.TextXAlignment.Left
subText.TextColor3 = Color3.fromRGB(220,220,220)
subText.Text = "Pozostało: -"
subText.Parent = panel

local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(0, 44)
barBack.Size = UDim2.new(1,0,0,10)
barBack.BackgroundColor3 = Color3.fromRGB(40,40,44)
barBack.BorderSizePixel = 0
barBack.Parent = panel
Instance.new("UICorner", barBack).CornerRadius = UDim.new(0, 999)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(1,0,1,0)
barFill.BackgroundColor3 = Color3.fromRGB(96,165,250)
barFill.BorderSizePixel = 0
barFill.Parent = barBack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 999)

-- Center countdown
local center = Instance.new("TextLabel")
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.new(0.5, 0, 0.22, 0)
center.Size = UDim2.fromOffset(520, 80)
center.BackgroundTransparency = 1
center.Font = Enum.Font.GothamBlack
center.TextSize = 42
center.TextColor3 = Color3.fromRGB(245,245,245)
center.TextStrokeTransparency = 0.65
center.Text = ""
center.Visible = false
center.Parent = gui

local function setCountdown(text: string?)
	if text and text ~= "" then
		center.Text = text
		center.Visible = true
	else
		center.Visible = false
	end
end

local function tweenFill(pct)
	pct = math.clamp(pct, 0, 1)
	TweenService:Create(barFill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(pct, 0, 1, 0)
	}):Play()
end

local currentWave = 0
local totalWaves = 0
local totalToKill = 1
local remaining = 1

local function render()
	waveText.Text = ("Fala: %d/%d"):format(currentWave, math.max(1,totalWaves))
	subText.Text = ("Pozostało: %d/%d"):format(remaining, totalToKill)
	tweenFill(remaining / math.max(1,totalToKill))
end

WaveStatusEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.type == "prepTick" then
		local s = tonumber(payload.seconds) or 0
		if s > 0 then
			setCountdown(("Start za %d"):format(s))
		else
			setCountdown(nil)
		end

	elseif payload.type == "waveCountdown" then
		local s = tonumber(payload.seconds) or 0
		if s > 0 then
			setCountdown(("Następna fala za %d"):format(s))
		else
			setCountdown(nil)
		end

	elseif payload.type == "waveStart" then
		currentWave = tonumber(payload.wave) or currentWave
		totalWaves = tonumber(payload.totalWaves) or totalWaves
		totalToKill = tonumber(payload.totalToKill) or tonumber(payload.totalToSpawn) or totalToKill
		remaining = tonumber(payload.remaining) or totalToKill
		setCountdown(nil)
		render()

	elseif payload.type == "waveUpdate" then
		currentWave = tonumber(payload.wave) or currentWave
		totalWaves = tonumber(payload.totalWaves) or totalWaves
		totalToKill = tonumber(payload.totalToKill) or tonumber(payload.totalToSpawn) or totalToKill
		remaining = tonumber(payload.remaining) or remaining
		render()

	elseif payload.type == "complete" then
		setCountdown("MISJA UKOŃCZONA")
	end
end)

render()
