-- MissionsUI.lua (LocalScript)
-- Działa z MissionRemotes.lua:
-- RF_GetMissions -> { missions = {...}, currencies = {...} }
-- RF_ClaimMission -> { ok = true/false, ... }
-- Otwiera UI na promcie w Workspace.NPCs.Knight

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local RF_GetMissions = remoteFunctions:WaitForChild("RF_GetMissions")
local RF_ClaimMission = remoteFunctions:WaitForChild("RF_ClaimMission")

local DAILY_MAX = 6
local WEEKLY_MAX = 12

-- ===== UI helpers =====
local function addCorner(inst: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function addStroke(inst: Instance, color: Color3)
	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Color = color
	s.Parent = inst
	return s
end

local function formatReward(reward: any): string
	if typeof(reward) ~= "table" then return "" end
	local coins = tonumber(reward.Coins) or 0
	local wp = tonumber(reward.WeaponPoints) or 0
	local parts = {}
	if coins > 0 then table.insert(parts, ("Coins +%d"):format(coins)) end
	if wp > 0 then table.insert(parts, ("WP +%d"):format(wp)) end
	return table.concat(parts, " | ")
end

local function formatProgress(mission: any): string
	local prog = (typeof(mission) == "table") and mission.Progress
	if typeof(prog) ~= "table" then return "" end
	local cur = tonumber(prog.Current) or 0
	local tgt = tonumber(prog.Target) or 0
	if tgt <= 0 then return "" end
	return ("Progress: %d/%d"):format(cur, tgt)
end

-- ===== UI build =====
local gui = Instance.new("ScreenGui")
gui.Name = "MissionsGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(980, 560)
panel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
panel.BorderSizePixel = 0
panel.Parent = overlay
addCorner(panel, 16)
addStroke(panel, Color3.fromRGB(40, 40, 48))

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 16)
title.Size = UDim2.new(1, -280, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Missions"
title.Parent = panel

local currencyLabel = Instance.new("TextLabel")
currencyLabel.BackgroundTransparency = 1
currencyLabel.AnchorPoint = Vector2.new(1, 0)
currencyLabel.Position = UDim2.new(1, -60, 0, 20)
currencyLabel.Size = UDim2.fromOffset(240, 20)
currencyLabel.Font = Enum.Font.Gotham
currencyLabel.TextSize = 12
currencyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
currencyLabel.TextXAlignment = Enum.TextXAlignment.Right
currencyLabel.Text = ""
currencyLabel.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -16, 0, 16)
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(210, 210, 210)
closeBtn.Text = "X"
closeBtn.Parent = panel
addCorner(closeBtn, 10)

local tabs = Instance.new("Frame")
tabs.BackgroundTransparency = 1
tabs.Position = UDim2.fromOffset(24, 52)
tabs.Size = UDim2.new(1, -48, 0, 36)
tabs.Parent = panel

local function makeTab(text: string, x: number)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(160, 32)
	b.Position = UDim2.fromOffset(x, 2)
	b.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(230, 230, 230)
	b.Text = text
	b.Parent = tabs
	addCorner(b, 10)
	addStroke(b, Color3.fromRGB(45, 45, 55))
	return b
end

local tabDaily = makeTab("Daily", 0)
local tabWeekly = makeTab("Weekly", 170)

local body = Instance.new("Frame")
body.BackgroundTransparency = 1
body.Position = UDim2.fromOffset(24, 96)
body.Size = UDim2.new(1, -48, 1, -120)
body.Parent = panel

local pageDaily = Instance.new("Frame")
pageDaily.BackgroundTransparency = 1
pageDaily.Size = UDim2.fromScale(1, 1)
pageDaily.Parent = body

local pageWeekly = Instance.new("Frame")
pageWeekly.BackgroundTransparency = 1
pageWeekly.Size = UDim2.fromScale(1, 1)
pageWeekly.Visible = false
pageWeekly.Parent = body

local function setTab(which: string)
	if which == "Daily" then
		pageDaily.Visible = true
		pageWeekly.Visible = false
		tabDaily.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		tabWeekly.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	else
		pageDaily.Visible = false
		pageWeekly.Visible = true
		tabDaily.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
		tabWeekly.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
	end
end

tabDaily.MouseButton1Click:Connect(function() setTab("Daily") end)
tabWeekly.MouseButton1Click:Connect(function() setTab("Weekly") end)

local function makeList(parent: Instance)
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.Parent = list

	return list
end

local dailyList = makeList(pageDaily)
local weeklyList = makeList(pageWeekly)

local function clearList(list: ScrollingFrame)
	for _, ch in ipairs(list:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
end

local function makeMissionRow(parentList: ScrollingFrame, mission: any, onClaim)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 92)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	row.BorderSizePixel = 0
	row.Parent = parentList
	addCorner(row, 14)
	addStroke(row, Color3.fromRGB(40, 40, 48))

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(16, 12)
	t.Size = UDim2.new(1, -220, 0, 18)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 14
	t.TextColor3 = Color3.fromRGB(240, 240, 240)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = tostring(mission.Title or mission.Id or "Mission")
	t.Parent = row

	local d = Instance.new("TextLabel")
	d.BackgroundTransparency = 1
	d.Position = UDim2.fromOffset(16, 32)
	d.Size = UDim2.new(1, -220, 0, 16)
	d.Font = Enum.Font.Gotham
	d.TextSize = 12
	d.TextColor3 = Color3.fromRGB(200, 200, 200)
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.Text = tostring(mission.Description or "")
	d.Parent = row

	local p = Instance.new("TextLabel")
	p.BackgroundTransparency = 1
	p.Position = UDim2.fromOffset(16, 50)
	p.Size = UDim2.new(1, -220, 0, 16)
	p.Font = Enum.Font.Gotham
	p.TextSize = 12
	p.TextColor3 = Color3.fromRGB(200, 200, 200)
	p.TextXAlignment = Enum.TextXAlignment.Left
	p.Text = formatProgress(mission)
	p.Parent = row

	local reward = Instance.new("TextLabel")
	reward.BackgroundTransparency = 1
	reward.AnchorPoint = Vector2.new(1, 0)
	reward.Position = UDim2.new(1, -120, 0, 12)
	reward.Size = UDim2.fromOffset(320, 16)
	reward.Font = Enum.Font.Gotham
	reward.TextSize = 12
	reward.TextColor3 = Color3.fromRGB(200, 200, 200)
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward.Text = formatReward(mission.Reward)
	reward.Parent = row

	local claim = Instance.new("TextButton")
	claim.AnchorPoint = Vector2.new(1, 0.5)
	claim.Position = UDim2.new(1, -16, 0.5, 0)
	claim.Size = UDim2.fromOffset(96, 34)
	claim.BorderSizePixel = 0
	claim.Font = Enum.Font.GothamBold
	claim.TextSize = 13
	claim.TextColor3 = Color3.fromRGB(255, 255, 255)
	claim.Parent = row
	addCorner(claim, 12)

	local claimable = (mission.Claimable == true)
	if claimable then
		claim.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
		claim.Text = "Claim"
		claim.AutoButtonColor = true
		claim.Active = true
	else
		claim.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
		claim.Text = "Not ready"
		claim.AutoButtonColor = false
		claim.Active = false
	end

	claim.MouseButton1Click:Connect(function()
		if claimable then onClaim(mission) end
	end)
end

-- ===== Server calls (dopasowane do MissionRemotes.lua) =====
local function getPayload()
	local ok, payload = pcall(function()
		return RF_GetMissions:InvokeServer()
	end)
	if not ok then
		warn("[MissionsUI] RF_GetMissions error:", payload)
		return nil
	end
	return payload
end

local function claimMission(id: string): boolean
	local ok, payload = pcall(function()
		return RF_ClaimMission:InvokeServer(id)
	end)
	if not ok then
		warn("[MissionsUI] RF_ClaimMission error:", payload)
		return false
	end
	return (typeof(payload) == "table" and payload.ok == true) or false
end

local function refreshUI()
	clearList(dailyList)
	clearList(weeklyList)

	local payload = getPayload()
	if typeof(payload) ~= "table" then
		makeMissionRow(dailyList, { Title="Error", Description="Failed to load missions.", Claimable=false }, function() end)
		return
	end

	local missions = payload.missions
	local currencies = payload.currencies

	if typeof(currencies) == "table" then
		local coins = tonumber(currencies.Coins) or 0
		local wp = tonumber(currencies.WeaponPoints) or 0
		currencyLabel.Text = ("Coins: %d | WP: %d"):format(coins, wp)
	else
		currencyLabel.Text = ""
	end

	if typeof(missions) ~= "table" then
		makeMissionRow(dailyList, { Title="Error", Description="Server returned no mission list.", Claimable=false }, function() end)
		return
	end

	local daily = {}
	local weekly = {}

	for _, m in ipairs(missions) do
		if typeof(m) == "table" then
			if m.Type == "Daily" then table.insert(daily, m) end
			if m.Type == "Weekly" then table.insert(weekly, m) end
		end
	end

	while #daily > DAILY_MAX do table.remove(daily) end
	while #weekly > WEEKLY_MAX do table.remove(weekly) end

	local function onClaim(mission)
		local id = tostring(mission.Id or "")
		if id == "" then return end
		if claimMission(id) then
			refreshUI()
		end
	end

	for _, m in ipairs(daily) do
		makeMissionRow(dailyList, m, onClaim)
	end
	for _, m in ipairs(weekly) do
		makeMissionRow(weeklyList, m, onClaim)
	end

	if #daily == 0 and #weekly == 0 then
		makeMissionRow(dailyList, { Title="No missions", Description="Server returned empty pools. Check MissionConfigs + MissionService.", Claimable=false }, function() end)
	end
end

-- ===== Open / Close =====
local lastOpenAt = 0

local function openUI()
	local now = os.clock()
	if (now - lastOpenAt) < 0.25 then return end
	lastOpenAt = now

	gui.Enabled = true
	setTab("Daily")
	refreshUI()
end

local function closeUI()
	gui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(closeUI)

overlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local pos = input.Position
		local absPos = panel.AbsolutePosition
		local absSize = panel.AbsoluteSize
		local inside = pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
			and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
		if not inside then closeUI() end
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
	-- debug: M otwiera
	if input.KeyCode == Enum.KeyCode.M and not gui.Enabled then
		openUI()
	end
end)

-- ===== Prompt hook: Workspace.NPCs.Knight =====
local function isPromptInsideKnight(prompt: ProximityPrompt): boolean
	local npcs = workspace:FindFirstChild("NPCs")
	local knight = npcs and npcs:FindFirstChild("Knight")
	if not knight then return false end

	local p = prompt and prompt.Parent
	while p do
		if p == knight then return true end
		p = p.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if isPromptInsideKnight(prompt) then
		-- otwieraj misje tylko jeśli tutorial już zakończony
		if player:GetAttribute("TutorialComplete") then
			openUI()
		end
	end
end)


print("[MissionsUI] Ready")
