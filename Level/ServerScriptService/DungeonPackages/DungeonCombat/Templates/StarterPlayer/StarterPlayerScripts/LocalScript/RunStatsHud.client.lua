local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local runStarted = ReplicatedStorage:WaitForChild("RunStarted")
local chestItemEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChestItemEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "RunStatsHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 48
gui.Parent = playerGui

local inventoryPanel = Instance.new("Frame")
inventoryPanel.Name = "InventoryPanel"
inventoryPanel.AnchorPoint = Vector2.new(1, 0.5)
inventoryPanel.Position = UDim2.new(1, -18, 0.5, 0)
inventoryPanel.Size = UDim2.fromOffset(228, 296)
inventoryPanel.BackgroundTransparency = 1
inventoryPanel.BorderSizePixel = 0
inventoryPanel.Visible = false
inventoryPanel.Parent = gui

local inventoryBody = Instance.new("Frame")
inventoryBody.Name = "InventoryBody"
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
	local itemsFolder = assetsFolder and assetsFolder:FindFirstChild("Items")
	local rarityFolder = itemsFolder and itemsFolder:FindFirstChild(rarity)
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

local function clearInventoryCards()
	for _, child in ipairs(inventoryBody:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function createInventoryCard(entry)
	local color = rarityColors[entry.Rarity] or Color3.fromRGB(190, 196, 210)
	local iconImageId = getItemIconImage(entry.Rarity, entry.Name)
	local initials = string.upper(string.sub(tostring(entry.Name or "IT"), 1, 2))
	local consumed = entry.IsConsumed == true

	local card = Instance.new("Frame")
	card.Name = tostring(entry.Id or "Item")
	card.LayoutOrder = tonumber(entry.AcquisitionIndex) or 0
	card.BackgroundColor3 = Color3.fromRGB(20, 25, 37)
	card.BackgroundTransparency = consumed and 0.52 or 0.22
	card.BorderSizePixel = 0
	card.Parent = inventoryBody
	addCorner(card, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = consumed and 0.68 or 0.22
	stroke.Thickness = 1
	stroke.Parent = card

	local iconText = Instance.new("TextLabel")
	iconText.BackgroundTransparency = 1
	iconText.Font = Enum.Font.GothamBlack
	iconText.TextColor3 = color
	iconText.TextTransparency = consumed and 0.45 or 0
	iconText.Text = initials
	iconText.Parent = card

	if iconImageId then
		local iconImage = Instance.new("ImageLabel")
		iconImage.BackgroundTransparency = 1
		iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
		iconImage.Position = UDim2.fromScale(0.5, 0.47)
		iconImage.Size = UDim2.fromOffset(28, 28)
		iconImage.Image = iconImageId
		iconImage.ImageTransparency = consumed and 0.45 or 0
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
	stackPill.BackgroundTransparency = consumed and 0.3 or 0
	stackPill.BorderSizePixel = 0
	stackPill.Font = Enum.Font.GothamBold
	stackPill.TextSize = 8
	stackPill.TextColor3 = Color3.fromRGB(15, 18, 24)
	stackPill.TextTransparency = consumed and 0.3 or 0
	stackPill.Text = tostring(tonumber(entry.Stacks) or 0)
	stackPill.Parent = card
	addCorner(stackPill, 7)

	if consumed then
		local overlay = Instance.new("Frame")
		overlay.BackgroundColor3 = Color3.fromRGB(7, 10, 15)
		overlay.BackgroundTransparency = 0.42
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BorderSizePixel = 0
		overlay.Parent = card
		addCorner(overlay, 12)
	end
end

local function renderInventory()
	clearInventoryCards()
	for _, entry in ipairs(inventorySnapshot) do
		createInventoryCard(entry)
	end
end

local function refreshVisibility()
	inventoryPanel.Visible = runStarted.Value == true
end

runStarted:GetPropertyChangedSignal("Value"):Connect(function()
	if runStarted.Value ~= true then
		inventorySnapshot = {}
		renderInventory()
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
	end
end)

refreshVisibility()
renderInventory()

chestItemEvent:FireServer({
	type = "requestInventorySync",
})
