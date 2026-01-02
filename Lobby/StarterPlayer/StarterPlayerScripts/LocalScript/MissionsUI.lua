-- LOCALSCRIPT: MissionsUI.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/MissionsUI (LocalScript)
-- CO: UI misji + obsługa testowych claimów

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local GetMissions = remoteFunctions:WaitForChild("RF_GetMissions")
local ClaimMission = remoteFunctions:WaitForChild("RF_ClaimMission")

local gui = Instance.new("ScreenGui")
gui.Name = "MissionsUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
overlay.BackgroundTransparency = 0.25
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(640, 420)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.Position = UDim2.fromOffset(596, 12)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
closeButton.TextColor3 = Color3.fromRGB(230, 230, 230)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Parent = panel
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.fromOffset(300, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Missions"
title.Parent = panel

local currencyText = Instance.new("TextLabel")
currencyText.BackgroundTransparency = 1
currencyText.Position = UDim2.fromOffset(18, 40)
currencyText.Size = UDim2.fromOffset(480, 20)
currencyText.Font = Enum.Font.Gotham
currencyText.TextSize = 13
currencyText.TextColor3 = Color3.fromRGB(210, 210, 210)
currencyText.TextXAlignment = Enum.TextXAlignment.Left
currencyText.Text = "Coins: 0 | WeaponPoints: 0 | Tickets: 0"
currencyText.Parent = panel

local tabFrame = Instance.new("Frame")
tabFrame.Position = UDim2.fromOffset(18, 70)
tabFrame.Size = UDim2.fromOffset(300, 30)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = panel

local dailyButton = Instance.new("TextButton")
dailyButton.Size = UDim2.fromOffset(120, 28)
dailyButton.Position = UDim2.fromOffset(0, 0)
dailyButton.BackgroundColor3 = Color3.fromRGB(62, 90, 120)
dailyButton.TextColor3 = Color3.fromRGB(240, 240, 240)
dailyButton.Text = "Daily"
dailyButton.Font = Enum.Font.GothamBold
dailyButton.TextSize = 12
dailyButton.Parent = tabFrame
Instance.new("UICorner", dailyButton).CornerRadius = UDim.new(0, 8)

local weeklyButton = Instance.new("TextButton")
weeklyButton.Size = UDim2.fromOffset(120, 28)
weeklyButton.Position = UDim2.fromOffset(130, 0)
weeklyButton.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
weeklyButton.TextColor3 = Color3.fromRGB(200, 200, 200)
weeklyButton.Text = "Weekly"
weeklyButton.Font = Enum.Font.GothamBold
weeklyButton.TextSize = 12
weeklyButton.Parent = tabFrame
Instance.new("UICorner", weeklyButton).CornerRadius = UDim.new(0, 8)

local listFrame = Instance.new("ScrollingFrame")
listFrame.Position = UDim2.fromOffset(18, 110)
listFrame.Size = UDim2.fromOffset(604, 290)
listFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
listFrame.BorderSizePixel = 0
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.ScrollBarThickness = 6
listFrame.Parent = panel
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 10)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = listFrame

local missionsData = {}
local selectedTab = "Daily"

local function setCurrencyText(currencies)
	currencies = currencies or {}
	local coins = tonumber(currencies.Coins) or 0
	local weaponPoints = tonumber(currencies.WeaponPoints) or 0
	local tickets = tonumber(currencies.Tickets) or 0
	currencyText.Text = ("Coins: %d | WeaponPoints: %d | Tickets: %d"):format(coins, weaponPoints, tickets)
end

local function clearList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child ~= listLayout then
			child:Destroy()
		end
	end
end

local function updateCanvas()
	listFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 8)
end

local function makeMissionRow(mission)
	local row = Instance.new("Frame")
	row.Size = UDim2.fromOffset(580, 84)
	row.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	row.BorderSizePixel = 0
	row.Parent = listFrame
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

	local titleLabel = Instance.new("TextLabel")	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.Size = UDim2.fromOffset(360, 18)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = mission.Title or "-"
	titleLabel.Parent = row

	local descLabel = Instance.new("TextLabel")	descLabel.BackgroundTransparency = 1
	descLabel.Position = UDim2.fromOffset(12, 28)
	descLabel.Size = UDim2.fromOffset(360, 36)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.Text = mission.Description or "-"
	descLabel.Parent = row

	local reward = mission.Reward or {}
	local rewardText = Instance.new("TextLabel")	rewardText.BackgroundTransparency = 1
	rewardText.Position = UDim2.fromOffset(380, 8)
	rewardText.Size = UDim2.fromOffset(180, 18)
	rewardText.Font = Enum.Font.Gotham
	rewardText.TextSize = 12
	rewardText.TextColor3 = Color3.fromRGB(210, 210, 210)
	rewardText.TextXAlignment = Enum.TextXAlignment.Right
	rewardText.Text = ("Reward: %d Coins / %d WP"):format(tonumber(reward.Coins) or 0, tonumber(reward.WeaponPoints) or 0)
	rewardText.Parent = row

	local claimCountText = Instance.new("TextLabel")	claimCountText.BackgroundTransparency = 1
	claimCountText.Position = UDim2.fromOffset(380, 28)
	claimCountText.Size = UDim2.fromOffset(180, 18)
	claimCountText.Font = Enum.Font.Gotham
	claimCountText.TextSize = 12
	claimCountText.TextColor3 = Color3.fromRGB(180, 180, 180)
	claimCountText.TextXAlignment = Enum.TextXAlignment.Right
	claimCountText.Text = ("Claims: %d"):format(tonumber(mission.ClaimCount) or 0)
	claimCountText.Parent = row

	local claimButton = Instance.new("TextButton")	claimButton.Size = UDim2.fromOffset(120, 28)
	claimButton.Position = UDim2.fromOffset(440, 52)
	claimButton.BackgroundColor3 = Color3.fromRGB(62, 90, 120)
	claimButton.TextColor3 = Color3.fromRGB(240, 240, 240)
	claimButton.Text = "Claim"
	claimButton.Font = Enum.Font.GothamBold
	claimButton.TextSize = 12
	claimButton.Parent = row
	Instance.new("UICorner", claimButton).CornerRadius = UDim.new(0, 8)

	if not mission.Claimable then
		claimButton.AutoButtonColor = false
		claimButton.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
		claimButton.TextColor3 = Color3.fromRGB(160, 160, 160)
		claimButton.Text = "Not ready"
	end

	claimButton.Activated:Connect(function()
		if not mission.Claimable then
			return
		end
		local ok, response = pcall(function()
			return ClaimMission:InvokeServer(mission.Id)
		end)
		if not ok or typeof(response) ~= "table" then
			return
		end
		if response.currencies then
			setCurrencyText(response.currencies)
		end
		if response.updatedMission then
			mission.Claimable = response.updatedMission.Claimable
			mission.ClaimCount = response.updatedMission.ClaimCount
			claimCountText.Text = ("Claims: %d"):format(tonumber(mission.ClaimCount) or 0)
		end
	end)
end

local function renderList()
	clearList()
	for _, mission in ipairs(missionsData) do
		if selectedTab == "Daily" then
			if mission.Type == "Daily" or mission.Type == "Test" then
				makeMissionRow(mission)
			end
		elseif selectedTab == "Weekly" then
			if mission.Type == "Weekly" then
				makeMissionRow(mission)
			end
		end
	end
	updateCanvas()
end

local function setTab(tabName)
	selectedTab = tabName
	if tabName == "Daily" then
		dailyButton.BackgroundColor3 = Color3.fromRGB(62, 90, 120)
		dailyButton.TextColor3 = Color3.fromRGB(240, 240, 240)
		weeklyButton.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
		weeklyButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	else
		weeklyButton.BackgroundColor3 = Color3.fromRGB(62, 90, 120)
		weeklyButton.TextColor3 = Color3.fromRGB(240, 240, 240)
		dailyButton.BackgroundColor3 = Color3.fromRGB(38, 38, 44)
		dailyButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
	selectedTab = tabName
	renderList()
end

dailyButton.Activated:Connect(function()
	setTab("Daily")
end)

weeklyButton.Activated:Connect(function()
	setTab("Weekly")
end)

local function refreshMissions()
	local ok, response = pcall(function()
		return GetMissions:InvokeServer()
	end)
	if not ok or typeof(response) ~= "table" then
		return
	end
	missionsData = response.missions or {}
	setCurrencyText(response.currencies)
	renderList()
end

closeButton.Activated:Connect(function()
	gui.Enabled = false
end)

local function openMissions()
	gui.Enabled = true
	refreshMissions()
end

local function findMissionPrompt()
	local npcFolder = Workspace:FindFirstChild("NPCs")
	if not npcFolder then
		return nil
	end

	local missionContainer = npcFolder:FindFirstChild("MissionNPC")
	if not missionContainer then
		return nil
	end

	local missionNpc = missionContainer:FindFirstChild("MissionNPC")
	if not missionNpc then
		return nil
	end

	return missionNpc:FindFirstChild("MissionPrompt", true)
end

local function bindMissionPrompt(prompt: ProximityPrompt)
	prompt.Triggered:Connect(function()
		openMissions()
	end)
end

local missionPrompt = findMissionPrompt()
if missionPrompt and missionPrompt:IsA("ProximityPrompt") then
	bindMissionPrompt(missionPrompt)
else
	local connection
	connection = Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") and descendant.Name == "MissionPrompt" then
			connection:Disconnect()
			bindMissionPrompt(descendant)
		end
	end)

	task.delay(10, function()
		if connection and connection.Connected then
			connection:Disconnect()
			warn("[MissionsUI] MissionPrompt not found")
		end
	end)
end
