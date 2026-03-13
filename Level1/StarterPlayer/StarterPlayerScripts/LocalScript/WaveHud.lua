-- WaveHud.client.lua (StarterPlayerScripts)
-- Reworked: time-based horde HUD
-- Shows: elapsed time, next elite timer, elite progress, and short center alerts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Support both layouts:
-- 1) ReplicatedStorage/Remotes/WaveStatusEvent (preferred)
-- 2) ReplicatedStorage/WaveStatusEvent (legacy mirror used by older clients)
local function getWaveStatusEvents()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local preferred = nil
	if remotes then
		local ev = remotes:FindFirstChild("WaveStatusEvent")
		if ev and ev:IsA("RemoteEvent") then
			preferred = ev
		end
	end
	local legacy = ReplicatedStorage:FindFirstChild("WaveStatusEvent")
	if not (legacy and legacy:IsA("RemoteEvent")) then
		legacy = nil
	end

	if not preferred then
		preferred = legacy or ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WaveStatusEvent")
		legacy = nil
	end

	if legacy == preferred then
		legacy = nil
	end

	return preferred, legacy
end

local WaveStatusEvent, LegacyWaveStatusEvent = getWaveStatusEvents()

if LegacyWaveStatusEvent then
	LegacyWaveStatusEvent.OnClientEvent:Connect(function()
		-- Drain the legacy mirror event so the server-side compatibility fire does not exhaust the queue.
	end)
end

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
elites.Text = "Elites: 0/3"
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
	if total <= 0 then total = 3 end
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

local function handleWaveStatus(p)
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

	elseif p.type == "chestsSpawned" then
		local count = math.max(0, math.floor(tonumber(p.count) or 0))
		center.Visible = true
		center.Text = ("CHESTS SPAWNED: %d"):format(count)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "chestOpened" then
		local playerName = tostring(p.playerName or "Player")
		local rewardName = tostring(p.rewardName or "Reward")
		local rarity = tostring(p.rarity or "Common")
		local openedForFree = (p.free == true)
		local suffix = openedForFree and "FREE" or ("-%d COINS"):format(math.max(0, math.floor(tonumber(p.cost) or 0)))
		center.Visible = true
		center.Text = ("CHEST [%s]: %s (%s, %s)"):format(rarity, rewardName, playerName, suffix)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "chestFail" then
		local cost = math.max(0, math.floor(tonumber(p.cost) or 0))
		center.Visible = true
		center.Text = ("CHEST: NEED %d COINS"):format(cost)
		task.delay(2, function() center.Visible = false end)

	elseif p.type == "recipeFound" then
		local recipeName = tostring(p.recipeName or p.recipeId or "Recipe")
		local rarity = tostring(p.rarity or "Common")
		center.Visible = true
		center.Text = ("RECIPE [%s]: %s"):format(rarity, recipeName)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "heroMonumentsSpawned" then
		local count = math.max(0, math.floor(tonumber(p.count) or 0))
		center.Visible = true
		center.Text = ("HERO MONUMENTS: %d"):format(count)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "heroMonumentActivated" then
		local playerName = tostring(p.playerName or "Player")
		local duration = math.max(1, math.floor(tonumber(p.duration) or 0))
		local rarity = tostring(p.rarity or "Common")
		center.Visible = true
		center.Text = ("HERO TRIAL [%s]: %ds (%s)"):format(rarity, duration, playerName)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "heroMonumentRewardReady" then
		local rarity = tostring(p.rarity or "Common")
		local recipeName = tostring(p.recipeName or "Recipe")
		center.Visible = true
		center.Text = ("RECIPE CHEST [%s]: %s"):format(rarity, recipeName)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "heroMonumentFailed" then
		local playerName = tostring(p.playerName or "Player")
		center.Visible = true
		center.Text = ("HERO TRIAL FAILED (%s)"):format(playerName)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "statuesSpawned" then
		local count = math.max(0, math.floor(tonumber(p.count) or 0))
		center.Visible = true
		center.Text = ("STATUES READY: %d"):format(count)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "statueActivated" then
		local statueType = tostring(p.statueType or "statue")
		local playerName = tostring(p.playerName or "Player")
		center.Visible = true
		if statueType == "battle" then
			local spawnCount = math.max(0, math.floor(tonumber(p.spawnCount) or 0))
			center.Text = ("WAR STATUE: %d ENEMIES (%s)"):format(spawnCount, playerName)
		else
			local duration = math.max(1, math.floor(tonumber(p.duration) or 0))
			center.Text = ("MAGNET STATUE: %ds (%s)"):format(duration, playerName)
		end
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "statueRewardReady" then
		local playerName = tostring(p.playerName or "Player")
		center.Visible = true
		center.Text = ("STATUE CLEARED: REWARD CHEST (%s)"):format(playerName)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "swarmStart" then
		local duration = math.max(1, math.floor(tonumber(p.duration) or 0))
		center.Visible = true
		center.Text = ("SWARM: x3 SPAWN RATE (%ds)"):format(duration)
		task.delay(3, function() center.Visible = false end)

	elseif p.type == "swarmEnd" then
		center.Visible = true
		center.Text = "SWARM ENDED"
		task.delay(2, function() center.Visible = false end)

	elseif p.type == "portalLocked" then
		center.Visible = true
		center.Text = ("PORTAL LOCKED: %s"):format(fmtTime(p.secondsLeft))
		task.delay(2, function() center.Visible = false end)

	elseif p.type == "complete" then
		local defeated, total = sanitizeEliteProgress(p.elitesDefeated, p.elitesTotal)
		center.Visible = true
		center.Text = "LEVEL COMPLETE"
		task.delay(5, function() center.Visible = false end)
		elites.Text = ("Elites: %d/%d"):format(defeated, total)
		setBar(total > 0 and (defeated / total) or 1)
	end
end

WaveStatusEvent.OnClientEvent:Connect(handleWaveStatus)

