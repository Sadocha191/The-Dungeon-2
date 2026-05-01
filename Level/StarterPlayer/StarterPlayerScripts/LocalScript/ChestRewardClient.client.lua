local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local chestItemEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChestItemEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "ChestRewardGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 92
gui.Enabled = false
gui.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
dim.BackgroundTransparency = 0.28
dim.BorderSizePixel = 0
dim.Parent = gui

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(680, 392)
card.BackgroundColor3 = Color3.fromRGB(15, 19, 29)
card.BorderSizePixel = 0
card.Parent = dim

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 22)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(96, 168, 255)
cardStroke.Transparency = 0.12
cardStroke.Thickness = 1.2
cardStroke.Parent = card

local rarityPill = Instance.new("TextLabel")
rarityPill.Position = UDim2.fromOffset(28, 22)
rarityPill.Size = UDim2.fromOffset(136, 28)
rarityPill.BackgroundColor3 = Color3.fromRGB(96, 168, 255)
rarityPill.BorderSizePixel = 0
rarityPill.Font = Enum.Font.GothamBold
rarityPill.TextSize = 12
rarityPill.TextColor3 = Color3.fromRGB(14, 18, 24)
rarityPill.Text = "RARE"
rarityPill.Parent = card

local rarityCorner = Instance.new("UICorner")
rarityCorner.CornerRadius = UDim.new(0, 12)
rarityCorner.Parent = rarityPill

local sourceText = Instance.new("TextLabel")
sourceText.BackgroundTransparency = 1
sourceText.Position = UDim2.fromOffset(180, 25)
sourceText.Size = UDim2.new(1, -208, 0, 22)
sourceText.Font = Enum.Font.Gotham
sourceText.TextSize = 12
sourceText.TextXAlignment = Enum.TextXAlignment.Left
sourceText.TextColor3 = Color3.fromRGB(170, 181, 203)
sourceText.Text = "Treasure Chest Reward"
sourceText.Parent = card

local iconFrame = Instance.new("Frame")
iconFrame.Position = UDim2.fromOffset(28, 72)
iconFrame.Size = UDim2.fromOffset(136, 136)
iconFrame.BackgroundColor3 = Color3.fromRGB(22, 28, 40)
iconFrame.BorderSizePixel = 0
iconFrame.Parent = card

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 18)
iconCorner.Parent = iconFrame

local iconText = Instance.new("TextLabel")
iconText.BackgroundTransparency = 1
iconText.Size = UDim2.fromScale(1, 1)
iconText.Font = Enum.Font.GothamBlack
iconText.TextSize = 42
iconText.TextColor3 = Color3.fromRGB(96, 168, 255)
iconText.Text = "IT"
iconText.Parent = iconFrame

local titleText = Instance.new("TextLabel")
titleText.BackgroundTransparency = 1
titleText.Position = UDim2.fromOffset(184, 72)
titleText.Size = UDim2.new(1, -212, 0, 40)
titleText.Font = Enum.Font.GothamBlack
titleText.TextSize = 28
titleText.TextWrapped = true
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextColor3 = Color3.fromRGB(244, 247, 252)
titleText.Text = "Item Name"
titleText.Parent = card

local descriptionText = Instance.new("TextLabel")
descriptionText.BackgroundTransparency = 1
descriptionText.Position = UDim2.fromOffset(184, 120)
descriptionText.Size = UDim2.new(1, -212, 0, 62)
descriptionText.Font = Enum.Font.Gotham
descriptionText.TextSize = 14
descriptionText.TextWrapped = true
descriptionText.TextXAlignment = Enum.TextXAlignment.Left
descriptionText.TextYAlignment = Enum.TextYAlignment.Top
descriptionText.TextColor3 = Color3.fromRGB(185, 194, 212)
descriptionText.Text = "Description"
descriptionText.Parent = card

local modifiersHeader = Instance.new("TextLabel")
modifiersHeader.BackgroundTransparency = 1
modifiersHeader.Position = UDim2.fromOffset(28, 228)
modifiersHeader.Size = UDim2.new(1, -56, 0, 24)
modifiersHeader.Font = Enum.Font.GothamBold
modifiersHeader.TextSize = 14
modifiersHeader.TextXAlignment = Enum.TextXAlignment.Left
modifiersHeader.TextColor3 = Color3.fromRGB(241, 244, 250)
modifiersHeader.Text = "Stat Changes"
modifiersHeader.Parent = card

local modifierList = Instance.new("ScrollingFrame")
modifierList.BackgroundTransparency = 1
modifierList.Position = UDim2.fromOffset(28, 258)
modifierList.Size = UDim2.new(1, -56, 0, 96)
modifierList.BorderSizePixel = 0
modifierList.ScrollBarThickness = 4
modifierList.CanvasSize = UDim2.new()
modifierList.Parent = card

local modifierLayout = Instance.new("UIListLayout")
modifierLayout.Padding = UDim.new(0, 6)
modifierLayout.Parent = modifierList

local takeButton = Instance.new("TextButton")
takeButton.AnchorPoint = Vector2.new(1, 1)
takeButton.Position = UDim2.new(1, -28, 1, -24)
takeButton.Size = UDim2.fromOffset(166, 48)
takeButton.BackgroundColor3 = Color3.fromRGB(96, 168, 255)
takeButton.BorderSizePixel = 0
takeButton.Font = Enum.Font.GothamBold
takeButton.TextSize = 18
takeButton.TextColor3 = Color3.fromRGB(14, 18, 24)
takeButton.Text = "TAKE"
takeButton.Parent = card

local takeCorner = Instance.new("UICorner")
takeCorner.CornerRadius = UDim.new(0, 14)
takeCorner.Parent = takeButton

local statusText = Instance.new("TextLabel")
statusText.BackgroundTransparency = 1
statusText.Position = UDim2.fromOffset(28, 358)
statusText.Size = UDim2.new(1, -220, 0, 18)
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 12
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.TextColor3 = Color3.fromRGB(140, 152, 175)
statusText.Text = "Take the reward to resume the run."
statusText.Parent = card

local currentToken = nil
local takePending = false

local function clearModifierLines()
	for _, child in ipairs(modifierList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addModifierLine(text)
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(22, 28, 40)
	label.BackgroundTransparency = 0.1
	label.BorderSizePixel = 0
	label.Size = UDim2.new(1, 0, 0, 24)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(229, 233, 241)
	label.Text = "  " .. tostring(text)
	label.Parent = modifierList

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
end

modifierLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	modifierList.CanvasSize = UDim2.new(0, 0, 0, modifierLayout.AbsoluteContentSize.Y + 4)
end)

local function setTakeEnabled(enabled)
	takeButton.Active = enabled
	takeButton.AutoButtonColor = enabled
	takeButton.BackgroundTransparency = enabled and 0 or 0.35
end

local function showReward(payload)
	local accent = typeof(payload.color) == "Color3" and payload.color or Color3.fromRGB(96, 168, 255)
	local rewardData = payload.item or payload.fallback or {}
	local modifierLines = rewardData.ModifierLines or {}

	currentToken = payload.token
	takePending = false
	setTakeEnabled(true)
	takeButton.Text = "TAKE"

	gui.Enabled = true
	cardStroke.Color = accent
	rarityPill.BackgroundColor3 = accent
	rarityPill.Text = string.upper(tostring(payload.rarity or "Reward"))
	iconText.TextColor3 = accent
	sourceText.Text = tostring(payload.sourceName or "Treasure Chest")
	titleText.Text = tostring(rewardData.Name or "Reward")
	descriptionText.Text = tostring(rewardData.Description or "Take this reward to continue the run.")
	iconText.Text = string.upper(string.sub(tostring(rewardData.Name or "IT"), 1, 2))
	statusText.Text = payload.rewardType == "Fallback"
		and "Take the fallback reward to resume the run."
		or "Take the item to add it to this run and resume play."

	clearModifierLines()
	for _, entry in ipairs(modifierLines) do
		addModifierLine(entry.Text or entry.text or "")
	end
end

local function hideReward()
	currentToken = nil
	takePending = false
	gui.Enabled = false
	clearModifierLines()
end

takeButton.MouseButton1Click:Connect(function()
	if not currentToken or takePending then
		return
	end

	takePending = true
	setTakeEnabled(false)
	takeButton.Text = "TAKING..."
	chestItemEvent:FireServer({
		type = "takeReward",
		token = currentToken,
	})
end)

chestItemEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.type == "openReward" then
		showReward(payload)
	elseif payload.type == "rewardClosed" then
		hideReward()
	end
end)
