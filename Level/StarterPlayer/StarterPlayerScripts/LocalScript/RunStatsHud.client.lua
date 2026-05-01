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
statsPanel.AnchorPoint = Vector2.new(1, 0)
statsPanel.Position = UDim2.new(1, -18, 0, 74)
statsPanel.Size = UDim2.fromOffset(300, 540)
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
statsTitle.Size = UDim2.new(1, -36, 0, 24)
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextSize = 16
statsTitle.TextXAlignment = Enum.TextXAlignment.Left
statsTitle.TextColor3 = Color3.fromRGB(241, 244, 250)
statsTitle.Text = "Run Stats"
statsTitle.Parent = statsPanel

local statsHint = Instance.new("TextLabel")
statsHint.BackgroundTransparency = 1
statsHint.Position = UDim2.fromOffset(18, 38)
statsHint.Size = UDim2.new(1, -36, 0, 18)
statsHint.Font = Enum.Font.Gotham
statsHint.TextSize = 11
statsHint.TextXAlignment = Enum.TextXAlignment.Left
statsHint.TextColor3 = Color3.fromRGB(141, 154, 181)
statsHint.Text = "Updates live during the current run."
statsHint.Parent = statsPanel

local statsScroll = Instance.new("ScrollingFrame")
statsScroll.Name = "StatsScroll"
statsScroll.Position = UDim2.fromOffset(14, 68)
statsScroll.Size = UDim2.new(1, -28, 1, -82)
statsScroll.BackgroundTransparency = 1
statsScroll.BorderSizePixel = 0
statsScroll.ScrollBarThickness = 5
statsScroll.CanvasSize = UDim2.new()
statsScroll.Parent = statsPanel

local statsLayout = Instance.new("UIListLayout")
statsLayout.Padding = UDim.new(0, 6)
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsScroll

local inventoryPanel = Instance.new("Frame")
inventoryPanel.Name = "InventoryPanel"
inventoryPanel.AnchorPoint = Vector2.new(1, 1)
inventoryPanel.Position = UDim2.new(1, -18, 1, -18)
inventoryPanel.Size = UDim2.fromOffset(300, 168)
inventoryPanel.BackgroundColor3 = Color3.fromRGB(14, 18, 27)
inventoryPanel.BackgroundTransparency = 0.12
inventoryPanel.BorderSizePixel = 0
inventoryPanel.Parent = root

local inventoryCorner = Instance.new("UICorner")
inventoryCorner.CornerRadius = UDim.new(0, 18)
inventoryCorner.Parent = inventoryPanel

local inventoryStroke = Instance.new("UIStroke")
inventoryStroke.Color = Color3.fromRGB(64, 76, 102)
inventoryStroke.Transparency = 0.25
inventoryStroke.Parent = inventoryPanel

local inventoryTitle = Instance.new("TextLabel")
inventoryTitle.BackgroundTransparency = 1
inventoryTitle.Position = UDim2.fromOffset(18, 14)
inventoryTitle.Size = UDim2.new(1, -36, 0, 24)
inventoryTitle.Font = Enum.Font.GothamBold
inventoryTitle.TextSize = 16
inventoryTitle.TextXAlignment = Enum.TextXAlignment.Left
inventoryTitle.TextColor3 = Color3.fromRGB(241, 244, 250)
inventoryTitle.Text = "Run Items"
inventoryTitle.Parent = inventoryPanel

local inventoryBody = Instance.new("Frame")
inventoryBody.BackgroundTransparency = 1
inventoryBody.Position = UDim2.fromOffset(14, 46)
inventoryBody.Size = UDim2.new(1, -28, 1, -58)
inventoryBody.Parent = inventoryPanel

local inventoryLayout = Instance.new("UIGridLayout")
inventoryLayout.CellPadding = UDim2.fromOffset(8, 8)
inventoryLayout.CellSize = UDim2.fromOffset(64, 64)
inventoryLayout.Parent = inventoryBody

local inventoryEmpty = Instance.new("TextLabel")
inventoryEmpty.BackgroundTransparency = 1
inventoryEmpty.Position = UDim2.fromOffset(18, 58)
inventoryEmpty.Size = UDim2.new(1, -36, 1, -72)
inventoryEmpty.Font = Enum.Font.Gotham
inventoryEmpty.TextSize = 12
inventoryEmpty.TextWrapped = true
inventoryEmpty.TextColor3 = Color3.fromRGB(145, 156, 178)
inventoryEmpty.Text = "Open a chest to start building your run inventory."
inventoryEmpty.Parent = inventoryPanel

local inventorySnapshot = {}

local rarityColors = {
	Common = Color3.fromRGB(220, 225, 234),
	Uncommon = Color3.fromRGB(96, 203, 115),
	Rare = Color3.fromRGB(89, 162, 255),
	Epic = Color3.fromRGB(181, 111, 255),
	Legendary = Color3.fromRGB(242, 194, 82),
}

local function clearChildren(instance)
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("GuiObject") and child ~= inventoryEmpty then
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
	row.Size = UDim2.new(1, -4, 0, isHeader and 24 or 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = layoutOrder

	if isHeader then
		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 1, 0)
		header.Font = Enum.Font.GothamBold
		header.TextSize = 13
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextColor3 = Color3.fromRGB(246, 210, 118)
		header.Text = labelText
		header.Parent = row
		return row
	end

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.57, 0, 1, 0)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(205, 212, 225)
	label.Text = labelText
	label.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Size = UDim2.new(0.40, 0, 1, 0)
	value.Font = Enum.Font.GothamBold
	value.TextSize = 12
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

local function renderStats()
	for _, child in ipairs(statsScroll:GetChildren()) do
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
				header.Parent = statsScroll
				layoutOrder += 1
				lastGroup = definition.Group
			end

			local row = buildStatRow(layoutOrder, definition.Label or statName, formatStatValue(statName), false)
			row.Parent = statsScroll
			layoutOrder += 1
		end
	end

	task.defer(function()
		statsScroll.CanvasSize = UDim2.new(0, 0, 0, statsLayout.AbsoluteContentSize.Y + 8)
	end)
end

local function createInventoryCard(entry)
	local color = rarityColors[entry.Rarity] or Color3.fromRGB(190, 196, 210)

	local card = Instance.new("Frame")
	card.Name = entry.Id
	card.BackgroundColor3 = Color3.fromRGB(20, 25, 37)
	card.BorderSizePixel = 0
	card.Parent = inventoryBody

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.1
	stroke.Parent = card

	local rarityBar = Instance.new("Frame")
	rarityBar.Size = UDim2.new(1, 0, 0, 5)
	rarityBar.BackgroundColor3 = color
	rarityBar.BorderSizePixel = 0
	rarityBar.Parent = card

	local iconText = Instance.new("TextLabel")
	iconText.BackgroundTransparency = 1
	iconText.Position = UDim2.fromOffset(8, 10)
	iconText.Size = UDim2.new(1, -16, 0, 28)
	iconText.Font = Enum.Font.GothamBlack
	iconText.TextSize = 18
	iconText.TextColor3 = color
	iconText.Text = string.upper(string.sub(entry.Name, 1, 2))
	iconText.Parent = card

	local nameText = Instance.new("TextLabel")
	nameText.BackgroundTransparency = 1
	nameText.Position = UDim2.fromOffset(6, 34)
	nameText.Size = UDim2.new(1, -12, 0, 22)
	nameText.Font = Enum.Font.Gotham
	nameText.TextSize = 10
	nameText.TextWrapped = true
	nameText.TextColor3 = Color3.fromRGB(230, 234, 242)
	nameText.Text = entry.Name
	nameText.Parent = card

	local stackPill = Instance.new("TextLabel")
	stackPill.AnchorPoint = Vector2.new(1, 1)
	stackPill.Position = UDim2.new(1, -6, 1, -6)
	stackPill.Size = UDim2.fromOffset(22, 18)
	stackPill.BackgroundColor3 = color
	stackPill.BorderSizePixel = 0
	stackPill.Font = Enum.Font.GothamBold
	stackPill.TextSize = 10
	stackPill.TextColor3 = Color3.fromRGB(15, 18, 24)
	stackPill.Text = tostring(entry.Stacks)
	stackPill.Parent = card

	local stackCorner = Instance.new("UICorner")
	stackCorner.CornerRadius = UDim.new(0, 9)
	stackCorner.Parent = stackPill

	if entry.IsConsumed then
		local overlay = Instance.new("Frame")
		overlay.BackgroundColor3 = Color3.fromRGB(7, 10, 15)
		overlay.BackgroundTransparency = 0.22
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BorderSizePixel = 0
		overlay.Parent = card

		local overlayCorner = Instance.new("UICorner")
		overlayCorner.CornerRadius = UDim.new(0, 14)
		overlayCorner.Parent = overlay

		local usedText = Instance.new("TextLabel")
		usedText.BackgroundTransparency = 1
		usedText.AnchorPoint = Vector2.new(0.5, 0.5)
		usedText.Position = UDim2.fromScale(0.5, 0.5)
		usedText.Size = UDim2.new(1, -8, 0, 18)
		usedText.Font = Enum.Font.GothamBold
		usedText.TextSize = 11
		usedText.TextColor3 = Color3.fromRGB(250, 201, 100)
		usedText.Text = "USED"
		usedText.Parent = overlay
	end
end

local function renderInventory()
	clearChildren(inventoryBody)

	local hasEntries = #inventorySnapshot > 0
	inventoryEmpty.Visible = not hasEntries
	if not hasEntries then
		return
	end

	for _, entry in ipairs(inventorySnapshot) do
		createInventoryCard(entry)
	end
end

local function refreshVisibility()
	local visible = runStarted.Value == true
	statsPanel.Visible = visible
	inventoryPanel.Visible = visible
end

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

chestItemEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.type == "inventorySync" and typeof(payload.inventory) == "table" then
		inventorySnapshot = payload.inventory
		renderInventory()
	end
end)

refreshVisibility()
renderStats()
renderInventory()

chestItemEvent:FireServer({
	type = "requestInventorySync",
})
