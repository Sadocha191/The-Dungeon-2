-- WaveHud.client.lua (StarterPlayerScripts)
-- Reworked: time-based horde HUD
-- Shows: elapsed time, next elite timer, elite progress, and short center alerts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Support both layouts:
-- 1) ReplicatedStorage/Remotes/WaveStatusEvent (preferred)
-- 2) ReplicatedStorage/WaveStatusEvent (legacy)
local function getWaveStatusEvent()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local ev = remotes:FindFirstChild("WaveStatusEvent")
		if ev and ev:IsA("RemoteEvent") then return ev end
	end
	local ev = ReplicatedStorage:FindFirstChild("WaveStatusEvent")
	if ev and ev:IsA("RemoteEvent") then return ev end
	-- last resort: don't infinite-yield on the wrong path
	return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WaveStatusEvent")
end

local WaveStatusEvent = getWaveStatusEvent()

local plr = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "WaveHud"
gui.ResetOnSpawn = false
gui.Parent = plr:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Position = UDim2.fromOffset(18, 18)
panel.Size = UDim2.fromOffset(280, 130)
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
title.Size = UDim2.new(1,0,0,22)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Text = "Time: 00:00"
title.Parent = panel

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Position = UDim2.fromOffset(0, 24)
sub.Size = UDim2.new(1,0,0,18)
sub.Font = Enum.Font.Gotham
sub.TextSize = 12
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.TextColor3 = Color3.fromRGB(210,210,210)
sub.Text = "Next Elite: --:--"
sub.Parent = panel

local elites = Instance.new("TextLabel")
elites.BackgroundTransparency = 1
elites.Position = UDim2.fromOffset(0, 44)
elites.Size = UDim2.new(1,0,0,18)
elites.Font = Enum.Font.Gotham
elites.TextSize = 12
elites.TextXAlignment = Enum.TextXAlignment.Left
elites.TextColor3 = Color3.fromRGB(210,210,210)
elites.Text = "Elites: 0/2"
elites.Parent = panel

local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(0, 72)
barBack.Size = UDim2.new(1,0,0,10)
barBack.BackgroundColor3 = Color3.fromRGB(40,40,44)
barBack.BorderSizePixel = 0
barBack.Parent = panel
Instance.new("UICorner", barBack).CornerRadius = UDim.new(0, 999)

local fill = Instance.new("Frame")
fill.Size = UDim2.new(0,0,1,0)
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

local center = Instance.new("TextLabel")
center.AnchorPoint = Vector2.new(0.5, 0)
center.Position = UDim2.new(0.5, 0, 0, 18)
center.Size = UDim2.fromOffset(540, 44)
center.BackgroundColor3 = Color3.fromRGB(14,14,16)
center.BackgroundTransparency = 0.2
center.BorderSizePixel = 0
center.Font = Enum.Font.GothamBold
center.TextSize = 22
center.TextColor3 = Color3.fromRGB(255,255,255)
center.Visible = false
center.Parent = gui
Instance.new("UICorner", center).CornerRadius = UDim.new(0, 14)

local function sanitizeEliteProgress(defeatedRaw, totalRaw)
	local total = math.floor(tonumber(totalRaw) or 0)
	if total <= 0 then total = 2 end
	total = math.min(total, 99)

	local defeated = math.floor(tonumber(defeatedRaw) or 0)
	defeated = math.clamp(defeated, 0, total)

	return defeated, total
end

local function fmtTime(sec)
	if typeof(sec) ~= "number" or sec ~= sec or sec == math.huge or sec == -math.huge then
		return "--:--"
	end
	sec = math.max(0, math.floor(sec))
	local m = math.floor(sec / 60)
	local s = sec % 60
	return string.format("%02d:%02d", m, s)
end

WaveStatusEvent.OnClientEvent:Connect(function(p)
	if typeof(p) ~= "table" then return end

	if p.type == "timeUpdate" then
		local defeated, total = sanitizeEliteProgress(p.elitesDefeated, p.elitesTotal)
		title.Text = ("Time: %s"):format(fmtTime(p.seconds))
		sub.Text = ("Next Elite: %s"):format(fmtTime(p.nextEliteIn))
		elites.Text = ("Elites: %d/%d"):format(defeated, total)
		setBar(defeated / math.max(1, total))

	elseif p.type == "eliteSpawn" then
		local name = tostring(p.name or "Elite")
		center.Visible = true
		center.Text = ("ELITE SPAWNED: %s"):format(name)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "eliteDefeated" or p.type == "eliteProgress" then
		local defeated, total = sanitizeEliteProgress(p.elitesDefeated, p.elitesTotal)
		center.Visible = true
		center.Text = ("ELITE DEFEATED (%d/%d)"):format(defeated, total)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "shrinesSpawned" then
		local count = math.max(0, math.floor(tonumber(p.count) or 0))
		local seconds = math.max(1, math.floor(tonumber(p.chargeSeconds) or 5))
		center.Visible = true
		center.Text = ("SHRINES: %d (STAY %ds)"):format(count, seconds)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "shrineComplete" then
		local playerName = tostring(p.playerName or "Player")
		local bonusName = tostring(p.bonusName or "Bonus")
		local rarity = tostring(p.rarity or "Common")
		center.Visible = true
		center.Text = ("SHRINE [%s]: %s (%s)"):format(rarity, bonusName, playerName)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "complete" then
		local defeated, total = sanitizeEliteProgress(p.elitesDefeated, p.elitesTotal)
		center.Visible = true
		center.Text = "LEVEL COMPLETE"
		task.delay(5, function() center.Visible = false end)
		elites.Text = ("Elites: %d/%d"):format(defeated, total)
		setBar(total > 0 and (defeated / total) or 1)
	end
end)
