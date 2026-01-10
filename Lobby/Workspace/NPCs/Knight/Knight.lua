-- MissionsUI.lua (LocalScript)
-- OPCJA A: używa istniejącego prompta na Knight (np. tutorialowego "Porozmawiaj")
-- i otwiera Missions UI, gdy prompt jest w modelu "Workspace/NPCs/Knight/Knight".
-- Nie wymaga prompta o nazwie MissionPrompt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== RemoteFunctions =====
local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctions then
	warn("[MissionsUI] Missing ReplicatedStorage.RemoteFunctions")
	return
end

local RF_GetMissions = remoteFunctions:FindFirstChild("RF_GetMissions")
local RF_ClaimMission = remoteFunctions:FindFirstChild("RF_ClaimMission")

if not (RF_GetMissions and RF_GetMissions:IsA("RemoteFunction")) then
	warn("[MissionsUI] Missing RemoteFunction RF_GetMissions")
	return
end
if not (RF_ClaimMission and RF_ClaimMission:IsA("RemoteFunction")) then
	warn("[MissionsUI] Missing RemoteFunction RF_ClaimMission")
	return
end

-- ===== Config =====
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
title.Size = UDim2.new(1, -140, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Missions"
title.Parent = panel

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
		if ch:IsA("Frame") then
			ch:Destroy()
		end
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
		if claimable then
			onClaim(mission)
		end
	end)
end

-- ===== Data load / refresh =====
local lastOpenAt = 0

local function safeInvokeGet()
	local ok, result = pcall(function()
		return RF_GetMissions:InvokeServer()
	end)
	if not ok then
		warn("[MissionsUI] RF_GetMissions failed:", result)
		return nil
	end
	return result
end

local function safeInvokeClaim(id: string)
	local ok, a = pcall(function()
		return RF_ClaimMission:InvokeServer(id)
	end)
	if not ok then
		warn("[MissionsUI] RF_ClaimMission failed:", a)
		return false
	end
	if typeof(a) == "boolean" then return a end
	if typeof(a) == "table" then return a.success == true end
	return false
end

local function refreshUI()
	local missions = safeInvokeGet()
	clearList(dailyList)
	clearList(weeklyList)

	if typeof(missions) ~= "table" then
		makeMissionRow(dailyList, {Title="Error", Description="Failed to load missions.", Claimable=false}, function() end)
		return
	end

	local daily = {}
	local weekly = {}

	for _, m in ipairs(missions) do
		if typeof(m) == "table" then
			if m.Type == "Daily" then
				table.insert(daily, m)
			elseif m.Type == "Weekly" then
				table.insert(weekly, m)
			end
		end
	end

	while #daily > DAILY_MAX do table.remove(daily) end
	while #weekly > WEEKLY_MAX do table.remove(weekly) end

	local function onClaim(mission)
		local id = tostring(mission.Id or "")
		if id == "" then return end
		if safeInvokeClaim(id) then
			refreshUI()
		end
	end

	for _, m in ipairs(daily) do
		makeMissionRow(dailyList, m, onClaim)
	end
	for _, m in ipairs(weekly) do
		makeMissionRow(weeklyList, m, onClaim)
	end
end

-- ===== Open / Close =====
local function openUI()
	local now = os.clock()
	if (now - lastOpenAt) < 0.3 then return end
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
		if not inside then
			closeUI()
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
	-- DEBUG fallback: M otwiera misje
	if input.KeyCode == Enum.KeyCode.M and not gui.Enabled then
		openUI()
	end
end)

-- ===== Hook: otwieraj na dowolnym promcie będącym w modelu Knight =====
local function isPromptInsideKnight(prompt: ProximityPrompt): boolean
	if not prompt then return false end

	local p = prompt.Parent
	while p do
		-- ścieżka u Ciebie: Workspace/NPCs/Knight/Knight (Model)
		if p.Name == "Knight" and p.Parent and p.Parent.Name == "Knight" then
			-- p to model "Knight" wewnątrz folderu NPCs/Knight
			return true
		end
		p = p.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr ~= player then return end
	if isPromptInsideKnight(prompt) then
		openUI()
	end
end)

print("[MissionsUI] Ready (Knight prompt hook)")
