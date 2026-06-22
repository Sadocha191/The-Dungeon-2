local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local runStarted = ReplicatedStorage:WaitForChild("RunStarted")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local StatsConfig = require(moduleFolder:WaitForChild("Stats"):WaitForChild("StatsConfig"))

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local chestItemEvent = remotesFolder:WaitForChild("ChestItemEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "RunStatsHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 48
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local statsPanel = Instance.new("Frame")
statsPanel.Name = "StatsPanel"
statsPanel.Position = UDim2.fromOffset(18, 28)
statsPanel.Size = UDim2.new(0, 336, 1, -56)
statsPanel.BackgroundColor3 = Color3.fromRGB(14, 18, 27)
statsPanel.BackgroundTransparency = 0.12
statsPanel.BorderSizePixel = 0
statsPanel.Parent = root

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 18)
statsCorner.Parent = statsPanel

local statsStroke = Instance.new("UIStroke")
statsStroke.Color = Color3.fromRGB(64, 76, 102)
statsStroke.Transparency = 0.25
statsStroke.Parent = statsPanel

local statsTitle = Instance.new("TextLabel")
statsTitle.BackgroundTransparency = 1
statsTitle.Position = UDim2.fromOffset(18, 14)
statsTitle.Size = UDim2.new(1, -36, 0, 22)
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextSize = 16
statsTitle.TextXAlignment = Enum.TextXAlignment.Left
statsTitle.TextColor3 = Color3.fromRGB(241, 244, 250)
statsTitle.Text = "Run Stats"
statsTitle.Parent = statsPanel

local statsHint = Instance.new("TextLabel")
statsHint.BackgroundTransparency = 1
statsHint.Position = UDim2.fromOffset(18, 36)
statsHint.Size = UDim2.new(1, -36, 0, 18)
statsHint.Font = Enum.Font.Gotham
statsHint.TextSize = 11
statsHint.TextXAlignment = Enum.TextXAlignment.Left
statsHint.TextColor3 = Color3.fromRGB(141, 154, 181)
statsHint.Text = "Visible while paused or opening a chest."
statsHint.Parent = statsPanel

local statsViewport = Instance.new("Frame")
statsViewport.Name = "StatsViewport"
statsViewport.ClipsDescendants = true
statsViewport.BackgroundTransparency = 1
statsViewport.Position = UDim2.fromOffset(14, 62)
statsViewport.Size = UDim2.new(1, -28, 1, -76)
statsViewport.Parent = statsPanel

local statsContent = Instance.new("Frame")
statsContent.Name = "StatsContent"
statsContent.BackgroundTransparency = 1
statsContent.Size = UDim2.new(1, 0, 0, 0)
statsContent.Parent = statsViewport

local statsScale = Instance.new("UIScale")
statsScale.Parent = statsContent

local statsLayout = Instance.new("UIListLayout")
statsLayout.Padding = UDim.new(0, 4)
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsContent

local inventoryPanel = Instance.new("Frame")
inventoryPanel.Name = "InventoryPanel"
inventoryPanel.AnchorPoint = Vector2.new(1, 0.5)
inventoryPanel.Position = UDim2.new(1, -18, 0.5, 0)
inventoryPanel.Size = UDim2.fromOffset(228, 296)
inventoryPanel.BackgroundTransparency = 1
inventoryPanel.BorderSizePixel = 0
inventoryPanel.Parent = root

local inventoryBody = Instance.new("Frame")
inventoryBody.BackgroundTransparency = 1
inventoryBody.Size = UDim2.fromScale(1, 1)
inventoryBody.Parent = inventoryPanel

local inventoryLayout = Instance.new("UIGridLayout")
inventoryLayout.CellPadding = UDim2.fromOffset(6, 6)
inventoryLayout.CellSize = UDim2.fromOffset(48, 48)
inventoryLayout.FillDirection = Enum.FillDirection.Horizontal
inventoryLayout.FillDirectionMaxCells = 4
inventoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
inventoryLayout.StartCorner = Enum.StartCorner.TopRight
inventoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
inventoryLayout.Parent = inventoryBody

local inventorySnapshot = {}
local pauseGuiConnections = {}
local chestGuiConnections = {}
local boundPauseGui = nil
local boundChestRewardGui = nil
local boundChestOpeningGui = nil

local rarityColors = {
	Common = Color3.fromRGB(220, 225, 234),
	Uncommon = Color3.fromRGB(96, 203, 115),
	Rare = Color3.fromRGB(89, 162, 255),
	Epic = Color3.fromRGB(181, 111, 255),
	Legendary = Color3.fromRGB(242, 194, 82),
}

local function getItemIconImage(rarity, itemName)
	if typeof(rarity) ~= "string" or typeof(itemName) ~= "string" or itemName == "" then
		return nil
	end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		return nil
	end

	local itemsFolder = assetsFolder:FindFirstChild("Items")
	if not itemsFolder then
		return nil
	end

	local rarityFolder = itemsFolder:FindFirstChild(rarity)
	if not rarityFolder then
		return nil
	end

	local candidateNames = {
		itemName,
		string.gsub(itemName, "'", "’"),
		string.gsub(itemName, "’", "'"),
	}

	for _, candidateName in ipairs(candidateNames) do
		local iconSource = rarityFolder:FindFirstChild(candidateName)
		if iconSource and iconSource:IsA("ImageLabel") and iconSource.Image ~= "" then
			return iconSource.Image
		end
	end

	return nil
end

local function disconnectConnections(connectionList)
	for _, connection in ipairs(connectionList) do
		connection:Disconnect()
	end
	table.clear(connectionList)
end

local function clearChildren(instance)
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function getStatValue(statName)
	local value = player:GetAttribute("RunStat_" .. statName)
	if typeof(value) == "number" then
		return value
	end
	local definition = StatsConfig.Get(statName)
	return definition and definition.Default or 0
end

local function buildStatRow(layoutOrder, labelText, valueText, isHeader)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -4, 0, isHeader and 20 or 22)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder

	if isHeader then
		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 1, 0)
		header.Font = Enum.Font.GothamBold
		header.TextSize = 12
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextColor3 = Color3.fromRGB(246, 210, 118)
		header.Text = labelText
		header.Parent = row
		return row
	end

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.58, 0, 1, 0)
	label.Font = Enum.Font.Gotham
	label.TextSize = 11
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(205, 212, 225)
	label.Text = labelText
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Size = UDim2.new(0.38, 0, 1, 0)
	value.Font = Enum.Font.GothamBold
	value.TextSize = 11
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextColor3 = Color3.fromRGB(244, 247, 252)
	value.Text = valueText
	value.Parent = row

	return row
end

local function formatStatValue(statName)
	local value = getStatValue(statName)
	if statName == "Shield" then
		local currentShield = tonumber(player:GetAttribute("RunCurrentShield")) or 0
		return string.format("%d / %d", math.floor(currentShield + 0.5), math.floor(value + 0.5))
	end
	if statName == "Overheal" then
		local currentOverheal = tonumber(player:GetAttribute("RunCurrentOverheal")) or 0
		if currentOverheal > 0 then
			return string.format("%d / %d", math.floor(currentOverheal + 0.5), math.floor(value + 0.5))
		end
	end
	return StatsConfig.FormatValue(statName, value)
end

local function updateStatsScale()
	local contentHeight = statsLayout.AbsoluteContentSize.Y
	statsContent.Size = UDim2.new(1, 0, 0, contentHeight)

	local availableHeight = statsViewport.AbsoluteSize.Y
	if contentHeight <= 0 or availableHeight <= 0 then
		statsScale.Scale = 1
		return
	end

	statsScale.Scale = math.min(1, math.max(0.1, (availableHeight - 4) / contentHeight))
end

local function renderStats()
	for _, child in ipairs(statsContent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local layoutOrder = 1
	local lastGroup = nil
	for _, statName in ipairs(StatsConfig.DisplayOrder) do
		local definition = StatsConfig.Get(statName)
		if definition then
			if definition.Group ~= lastGroup then
				local header = buildStatRow(layoutOrder, tostring(definition.Group), "", true)
				header.Parent = statsContent
				layoutOrder += 1
				lastGroup = definition.Group
			end

			local row = buildStatRow(layoutOrder, definition.Label or statName, formatStatValue(statName), false)
			row.Parent = statsContent
			layoutOrder += 1
		end
	end

	task.defer(updateStatsScale)
end

local function createInventoryCard(entry)
	local color = rarityColors[entry.Rarity] or Color3.fromRGB(190, 196, 210)
	local iconImageId = getItemIconImage(entry.Rarity, entry.Name)
	local initials = string.upper(string.sub(tostring(entry.Name or "IT"), 1, 2))

	local card = Instance.new("Frame")
	card.Name = entry.Id
	card.LayoutOrder = tonumber(entry.AcquisitionIndex) or 0
	card.BackgroundColor3 = Color3.fromRGB(20, 25, 37)
	card.BackgroundTransparency = entry.IsConsumed and 0.52 or 0.22
	card.BorderSizePixel = 0
	card.Parent = inventoryBody

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = entry.IsConsumed and 0.68 or 0.22
	stroke.Thickness = 1
	stroke.Parent = card

	local iconText = Instance.new("TextLabel")
	iconText.BackgroundTransparency = 1
	iconText.Font = Enum.Font.GothamBlack
	iconText.TextColor3 = color
	iconText.TextTransparency = entry.IsConsumed and 0.45 or 0
	iconText.Text = initials
	iconText.Parent = card

	if iconImageId then
		local iconImage = Instance.new("ImageLabel")
		iconImage.BackgroundTransparency = 1
		iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
		iconImage.Position = UDim2.fromScale(0.5, 0.47)
		iconImage.Size = UDim2.fromOffset(28, 28)
		iconImage.Image = iconImageId
		iconImage.ImageTransparency = entry.IsConsumed and 0.45 or 0
		iconImage.ScaleType = Enum.ScaleType.Fit
		iconImage.Parent = card

		iconText.Position = UDim2.fromOffset(4, 3)
		iconText.Size = UDim2.fromOffset(18, 10)
		iconText.TextSize = 8
		iconText.TextXAlignment = Enum.TextXAlignment.Left
		iconText.TextYAlignment = Enum.TextYAlignment.Top
	else
		iconText.Position = UDim2.fromOffset(0, 9)
		iconText.Size = UDim2.new(1, 0, 0, 18)
		iconText.TextSize = 16
		iconText.TextXAlignment = Enum.TextXAlignment.Center
		iconText.TextYAlignment = Enum.TextYAlignment.Top
	end

	local stackPill = Instance.new("TextLabel")
	stackPill.AnchorPoint = Vector2.new(1, 1)
	stackPill.Position = UDim2.new(1, -5, 1, -5)
	stackPill.Size = UDim2.fromOffset(16, 14)
	stackPill.BackgroundColor3 = color
	stackPill.BackgroundTransparency = entry.IsConsumed and 0.3 or 0
	stackPill.BorderSizePixel = 0
	stackPill.Font = Enum.Font.GothamBold
	stackPill.TextSize = 8
	stackPill.TextColor3 = Color3.fromRGB(15, 18, 24)
	stackPill.TextTransparency = entry.IsConsumed and 0.3 or 0
	stackPill.Text = tostring(entry.Stacks)
	stackPill.Parent = card

	local stackCorner = Instance.new("UICorner")
	stackCorner.CornerRadius = UDim.new(0, 7)
	stackCorner.Parent = stackPill

	if entry.IsConsumed then
		local overlay = Instance.new("Frame")
		overlay.BackgroundColor3 = Color3.fromRGB(7, 10, 15)
		overlay.BackgroundTransparency = 0.42
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BorderSizePixel = 0
		overlay.Parent = card

		local overlayCorner = Instance.new("UICorner")
		overlayCorner.CornerRadius = UDim.new(0, 12)
		overlayCorner.Parent = overlay
	end
end

local function renderInventory()
	clearChildren(inventoryBody)

	for _, entry in ipairs(inventorySnapshot) do
		createInventoryCard(entry)
	end
end

local function isPauseMenuOpen()
	local pauseGui = playerGui:FindFirstChild("Pause")
	if not pauseGui or not pauseGui:IsA("ScreenGui") then
		return false
	end

	local overlay = pauseGui:FindFirstChild("MenuOverlay")
	local menuOpen = pauseGui:GetAttribute("MenuOpen") == true
	return menuOpen or (overlay and overlay:IsA("GuiObject") and overlay.Visible) == true
end

local function isChestRewardOpen()
	local chestRewardGui = playerGui:FindFirstChild("ChestRewardGui")
	local chestOpeningGui = playerGui:FindFirstChild("ChestOpening")
	return (chestRewardGui ~= nil and chestRewardGui:IsA("ScreenGui") and chestRewardGui.Enabled)
		or (chestOpeningGui ~= nil and chestOpeningGui:IsA("ScreenGui") and chestOpeningGui.Enabled)
end

local function refreshVisibility()
	local runVisible = runStarted.Value == true
	statsPanel.Visible = runVisible and (isPauseMenuOpen() or isChestRewardOpen())
	inventoryPanel.Visible = runVisible

	if statsPanel.Visible then
		task.defer(updateStatsScale)
	end
end

local function bindPauseGuiSignals()
	local pauseGui = playerGui:FindFirstChild("Pause")
	if pauseGui == boundPauseGui then
		return
	end

	disconnectConnections(pauseGuiConnections)
	boundPauseGui = nil

	if pauseGui and pauseGui:IsA("ScreenGui") then
		boundPauseGui = pauseGui
		pauseGuiConnections[#pauseGuiConnections + 1] = pauseGui:GetAttributeChangedSignal("MenuOpen"):Connect(refreshVisibility)
		pauseGuiConnections[#pauseGuiConnections + 1] = pauseGui.ChildAdded:Connect(function(child)
			if child.Name == "MenuOverlay" and child:IsA("GuiObject") then
				pauseGuiConnections[#pauseGuiConnections + 1] = child:GetPropertyChangedSignal("Visible"):Connect(refreshVisibility)
				refreshVisibility()
			end
		end)

		local overlay = pauseGui:FindFirstChild("MenuOverlay")
		if overlay and overlay:IsA("GuiObject") then
			pauseGuiConnections[#pauseGuiConnections + 1] = overlay:GetPropertyChangedSignal("Visible"):Connect(refreshVisibility)
		end
	end
end

local function bindChestRewardGuiSignals()
	local chestRewardGui = playerGui:FindFirstChild("ChestRewardGui")
	local chestOpeningGui = playerGui:FindFirstChild("ChestOpening")
	if chestRewardGui == boundChestRewardGui and chestOpeningGui == boundChestOpeningGui then
		return
	end

	disconnectConnections(chestGuiConnections)
	boundChestRewardGui = nil
	boundChestOpeningGui = nil

	if chestRewardGui and chestRewardGui:IsA("ScreenGui") then
		boundChestRewardGui = chestRewardGui
		chestGuiConnections[#chestGuiConnections + 1] = chestRewardGui:GetPropertyChangedSignal("Enabled"):Connect(refreshVisibility)
	end
	if chestOpeningGui and chestOpeningGui:IsA("ScreenGui") then
		boundChestOpeningGui = chestOpeningGui
		chestGuiConnections[#chestGuiConnections + 1] = chestOpeningGui:GetPropertyChangedSignal("Enabled"):Connect(refreshVisibility)
	end
end

statsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateStatsScale)
statsViewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateStatsScale)

for _, statName in ipairs(StatsConfig.DisplayOrder) do
	player:GetAttributeChangedSignal("RunStat_" .. statName):Connect(renderStats)
end
player:GetAttributeChangedSignal("RunCurrentShield"):Connect(renderStats)
player:GetAttributeChangedSignal("RunCurrentOverheal"):Connect(renderStats)
runStarted:GetPropertyChangedSignal("Value"):Connect(function()
	if runStarted.Value ~= true then
		inventorySnapshot = {}
		renderInventory()
	end
	refreshVisibility()
	renderStats()
end)

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "Pause" then
		bindPauseGuiSignals()
	elseif child.Name == "ChestRewardGui" or child.Name == "ChestOpening" then
		bindChestRewardGuiSignals()
	end
	refreshVisibility()
end)

playerGui.ChildRemoved:Connect(function(child)
	if child == boundPauseGui then
		bindPauseGuiSignals()
	elseif child == boundChestRewardGui or child == boundChestOpeningGui then
		bindChestRewardGuiSignals()
	end
	refreshVisibility()
end)

chestItemEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.type == "inventorySync" and typeof(payload.inventory) == "table" then
		inventorySnapshot = payload.inventory
		renderInventory()
	elseif payload.type == "openReward" or payload.type == "rewardClosed" then
		refreshVisibility()
	end
end)

bindPauseGuiSignals()
bindChestRewardGuiSignals()
refreshVisibility()
renderStats()
renderInventory()

chestItemEvent:FireServer({
	type = "requestInventorySync",
})
