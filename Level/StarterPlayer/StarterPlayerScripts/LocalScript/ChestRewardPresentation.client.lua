local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local chestItemEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChestItemEvent")

local CHEST_OPENING_GUI_NAME = "ChestOpening"
local ACTION_FRAME_NAME = "ChestRewardActions"
local PRESENTATION_NAME = "ChestRewardPresentation"
local REVEAL_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local currentPayload = nil
local activeSession = 0
local actionVisibilityConnection = nil
local presentationRoot = nil
local backdrop = nil
local openingStatus = nil
local detailsCard = nil
local detailsScale = nil
local rarityStrip = nil
local rarityText = nil
local sourceText = nil
local titleText = nil
local descriptionText = nil
local stackText = nil
local modifiersList = nil
local modifiersLayout = nil
local boundOpeningGui = nil
local boundActionFrame = nil

local function disconnectActionVisibility()
	if actionVisibilityConnection then
		actionVisibilityConnection:Disconnect()
		actionVisibilityConnection = nil
	end
	boundActionFrame = nil
end

local function getOpeningGui()
	local openingGui = playerGui:FindFirstChild(CHEST_OPENING_GUI_NAME)
	if not openingGui then
		openingGui = playerGui:WaitForChild(CHEST_OPENING_GUI_NAME, 1)
	end
	if openingGui and openingGui:IsA("ScreenGui") then
		return openingGui
	end
	return nil
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

local function clearModifierRows()
	if not modifiersList then
		return
	end
	for _, child in ipairs(modifiersList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addModifierRow(entry, layoutOrder)
	local text = tostring(entry.Text or entry.text or entry)
	local delta = tonumber(entry.Delta or entry.delta)
	local positive = delta == nil or delta >= 0

	local row = Instance.new("Frame")
	row.Name = "Modifier"
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, -4, 0, 34)
	row.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
	row.BackgroundTransparency = 0.08
	row.BorderSizePixel = 0
	row.ZIndex = 92
	row.Parent = modifiersList
	addCorner(row, 10)

	local marker = Instance.new("Frame")
	marker.Size = UDim2.fromOffset(4, 18)
	marker.Position = UDim2.fromOffset(10, 8)
	marker.BackgroundColor3 = positive and Color3.fromRGB(104, 225, 157) or Color3.fromRGB(255, 119, 119)
	marker.BorderSizePixel = 0
	marker.ZIndex = 93
	marker.Parent = row
	addCorner(marker, 2)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(24, 0)
	label.Size = UDim2.new(1, -34, 1, 0)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(232, 236, 245)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.ZIndex = 93
	label.Parent = row
end

local function updateModifierCanvas()
	if modifiersList and modifiersLayout then
		modifiersList.CanvasSize = UDim2.new(0, 0, 0, modifiersLayout.AbsoluteContentSize.Y + 4)
	end
end

local function styleActionFrame(actionFrame, accent)
	if not actionFrame or not actionFrame:IsA("Frame") then
		return
	end

	actionFrame.BackgroundTransparency = 1
	actionFrame.BorderSizePixel = 0
	actionFrame.ZIndex = 100

	local button = actionFrame:FindFirstChild("TakeRewardAction")
	if button and button:IsA("TextButton") then
		button.AnchorPoint = Vector2.new(0.5, 0)
		button.Position = UDim2.new(0.5, 0, 0, 0)
		button.Size = UDim2.new(1, 0, 0, 46)
		button.BackgroundColor3 = accent
		button.TextColor3 = Color3.fromRGB(17, 19, 24)
		button.TextSize = 16
		button.ZIndex = 101
		if not button:FindFirstChildOfClass("UICorner") then
			addCorner(button, 12)
		end
	end

	local status = actionFrame:FindFirstChild("Status")
	if status and status:IsA("TextLabel") then
		status.Position = UDim2.fromOffset(4, 50)
		status.Size = UDim2.new(1, -8, 0, 18)
		status.TextColor3 = Color3.fromRGB(188, 197, 214)
		status.TextSize = 11
		status.ZIndex = 101
	end
end

local function applyResponsiveLayout()
	if not presentationRoot or not presentationRoot.Parent or not detailsCard then
		return
	end

	local size = presentationRoot.AbsoluteSize
	local wide = size.X >= 1050
	local compact = not wide and size.Y < 430
	local actionFrame = boundActionFrame
	local rarity = rarityText
	local source = sourceText
	local title = titleText
	local description = descriptionText
	local modifierHeader = detailsCard:FindFirstChild("ModifierHeader")
	local list = modifiersList
	local stack = stackText

	if wide then
		detailsCard.AnchorPoint = Vector2.new(1, 0.5)
		detailsCard.Position = UDim2.new(1, -42, 0.5, -24)
		detailsCard.Size = UDim2.fromOffset(430, 350)

		if actionFrame then
			actionFrame.AnchorPoint = Vector2.new(1, 0)
			actionFrame.Position = UDim2.new(1, -42, 0.5, 164)
			actionFrame.Size = UDim2.fromOffset(430, 72)
		end
	else
		local width = math.max(300, math.min(560, size.X - 28))
		local cardHeight = compact and math.clamp(size.Y - 90, 200, 262) or 262
		local cardBottomOffset = compact and 80 or 112
		detailsCard.AnchorPoint = Vector2.new(0.5, 1)
		detailsCard.Position = UDim2.new(0.5, 0, 1, -cardBottomOffset)
		detailsCard.Size = UDim2.fromOffset(width, cardHeight)

		if actionFrame then
			actionFrame.AnchorPoint = Vector2.new(0.5, 1)
			actionFrame.Position = UDim2.new(0.5, 0, 1, compact and -12 or -24)
			actionFrame.Size = UDim2.fromOffset(width, compact and 60 or 72)
		end
	end

	if compact then
		rarity.Position = UDim2.fromOffset(18, 10)
		rarity.Size = UDim2.fromOffset(110, 20)
		rarity.TextSize = 10
		source.Position = UDim2.fromOffset(140, 10)
		source.Size = UDim2.new(1, -158, 0, 20)
		source.TextSize = 10
		title.Position = UDim2.fromOffset(18, 36)
		title.Size = UDim2.new(1, -36, 0, 32)
		title.TextSize = 20
		description.Position = UDim2.fromOffset(18, 70)
		description.Size = UDim2.new(1, -36, 0, 38)
		description.TextSize = 11
		modifierHeader.Position = UDim2.fromOffset(18, 112)
		modifierHeader.Size = UDim2.new(1, -36, 0, 16)
		list.Position = UDim2.fromOffset(18, 130)
		list.Size = UDim2.new(1, -36, 1, -158)
		stack.Position = UDim2.new(1, -18, 1, -6)
		stack.Size = UDim2.new(0.55, 0, 0, 14)

		if actionFrame then
			local button = actionFrame:FindFirstChild("TakeRewardAction")
			local status = actionFrame:FindFirstChild("Status")
			if button and button:IsA("TextButton") then
				button.Size = UDim2.new(1, 0, 0, 40)
				button.TextSize = 14
			end
			if status and status:IsA("TextLabel") then
				status.Position = UDim2.fromOffset(4, 42)
				status.Size = UDim2.new(1, -8, 0, 14)
				status.TextSize = 9
			end
		end
	else
		rarity.Position = UDim2.fromOffset(24, 18)
		rarity.Size = UDim2.fromOffset(122, 24)
		rarity.TextSize = 11
		source.Position = UDim2.fromOffset(158, 19)
		source.Size = UDim2.new(1, -180, 0, 22)
		source.TextSize = 11
		title.Position = UDim2.fromOffset(24, 54)
		title.Size = UDim2.new(1, -48, 0, 42)
		title.TextSize = 26
		description.Position = UDim2.fromOffset(24, 100)
		description.Size = UDim2.new(1, -48, 0, 56)
		description.TextSize = 14
		modifierHeader.Position = UDim2.fromOffset(24, 164)
		modifierHeader.Size = UDim2.new(1, -48, 0, 20)
		list.Position = UDim2.fromOffset(24, 190)
		list.Size = UDim2.new(1, -48, 1, -226)
		stack.Position = UDim2.new(1, -24, 1, -12)
		stack.Size = UDim2.new(0.5, 0, 0, 18)

		if actionFrame then
			local button = actionFrame:FindFirstChild("TakeRewardAction")
			local status = actionFrame:FindFirstChild("Status")
			if button and button:IsA("TextButton") then
				button.Size = UDim2.new(1, 0, 0, 46)
				button.TextSize = 16
			end
			if status and status:IsA("TextLabel") then
				status.Position = UDim2.fromOffset(4, 50)
				status.Size = UDim2.new(1, -8, 0, 18)
				status.TextSize = 11
			end
		end
	end
end

local function buildPresentation(openingGui)
	if boundOpeningGui == openingGui and presentationRoot and presentationRoot.Parent == openingGui then
		return
	end

	disconnectActionVisibility()
	boundOpeningGui = openingGui

	local existing = openingGui:FindFirstChild(PRESENTATION_NAME)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = PRESENTATION_NAME
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Visible = false
	root.ZIndex = 70
	root.Parent = openingGui
	presentationRoot = root

	local scrim = Instance.new("Frame")
	scrim.Name = "Backdrop"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.fromRGB(4, 6, 10)
	scrim.BackgroundTransparency = 0.52
	scrim.BorderSizePixel = 0
	scrim.ZIndex = 70
	scrim.Parent = root
	backdrop = scrim

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 0
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(0.55, 0.82),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	gradient.Parent = scrim

	local status = Instance.new("TextLabel")
	status.Name = "OpeningStatus"
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, 34)
	status.Size = UDim2.new(0.8, 0, 0, 54)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBlack
	status.Text = "OPENING TREASURE CHEST"
	status.TextColor3 = Color3.fromRGB(240, 222, 169)
	status.TextSize = 22
	status.TextStrokeColor3 = Color3.fromRGB(10, 12, 17)
	status.TextStrokeTransparency = 0.55
	status.ZIndex = 82
	status.Parent = root
	openingStatus = status

	local card = Instance.new("Frame")
	card.Name = "RewardDetails"
	card.BackgroundColor3 = Color3.fromRGB(13, 16, 24)
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Visible = false
	card.ZIndex = 90
	card.Parent = root
	detailsCard = card
	addCorner(card, 18)
	addStroke(card, Color3.fromRGB(225, 191, 92), 0.12, 1.5)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = card
	detailsScale = scale

	local strip = Instance.new("Frame")
	strip.Name = "RarityStrip"
	strip.Size = UDim2.new(0, 6, 1, 0)
	strip.BackgroundColor3 = Color3.fromRGB(225, 191, 92)
	strip.BorderSizePixel = 0
	strip.ZIndex = 91
	strip.Parent = card
	rarityStrip = strip
	addCorner(strip, 3)

	local rarity = Instance.new("TextLabel")
	rarity.Name = "Rarity"
	rarity.Position = UDim2.fromOffset(24, 18)
	rarity.Size = UDim2.fromOffset(122, 24)
	rarity.BackgroundColor3 = Color3.fromRGB(225, 191, 92)
	rarity.BorderSizePixel = 0
	rarity.Font = Enum.Font.GothamBold
	rarity.Text = "REWARD"
	rarity.TextColor3 = Color3.fromRGB(17, 19, 24)
	rarity.TextSize = 11
	rarity.ZIndex = 92
	rarity.Parent = card
	rarityText = rarity
	addCorner(rarity, 10)

	local source = Instance.new("TextLabel")
	source.Name = "Source"
	source.BackgroundTransparency = 1
	source.Position = UDim2.fromOffset(158, 19)
	source.Size = UDim2.new(1, -180, 0, 22)
	source.Font = Enum.Font.GothamMedium
	source.Text = "TREASURE CHEST"
	source.TextColor3 = Color3.fromRGB(158, 169, 190)
	source.TextSize = 11
	source.TextXAlignment = Enum.TextXAlignment.Right
	source.TextTruncate = Enum.TextTruncate.AtEnd
	source.ZIndex = 92
	source.Parent = card
	sourceText = source

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 54)
	title.Size = UDim2.new(1, -48, 0, 42)
	title.Font = Enum.Font.GothamBlack
	title.Text = "Reward"
	title.TextColor3 = Color3.fromRGB(245, 247, 252)
	title.TextSize = 26
	title.TextWrapped = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.ZIndex = 92
	title.Parent = card
	titleText = title

	local description = Instance.new("TextLabel")
	description.Name = "Description"
	description.BackgroundTransparency = 1
	description.Position = UDim2.fromOffset(24, 100)
	description.Size = UDim2.new(1, -48, 0, 56)
	description.Font = Enum.Font.Gotham
	description.Text = ""
	description.TextColor3 = Color3.fromRGB(191, 200, 217)
	description.TextSize = 14
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.ZIndex = 92
	description.Parent = card
	descriptionText = description

	local modifierHeader = Instance.new("TextLabel")
	modifierHeader.Name = "ModifierHeader"
	modifierHeader.BackgroundTransparency = 1
	modifierHeader.Position = UDim2.fromOffset(24, 164)
	modifierHeader.Size = UDim2.new(1, -48, 0, 20)
	modifierHeader.Font = Enum.Font.GothamBold
	modifierHeader.Text = "WHAT IT GIVES"
	modifierHeader.TextColor3 = Color3.fromRGB(232, 235, 242)
	modifierHeader.TextSize = 11
	modifierHeader.TextXAlignment = Enum.TextXAlignment.Left
	modifierHeader.ZIndex = 92
	modifierHeader.Parent = card

	local list = Instance.new("ScrollingFrame")
	list.Name = "Modifiers"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(24, 190)
	list.Size = UDim2.new(1, -48, 1, -226)
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = Color3.fromRGB(145, 154, 173)
	list.ZIndex = 92
	list.Parent = card
	modifiersList = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	modifiersLayout = layout
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateModifierCanvas)

	local stack = Instance.new("TextLabel")
	stack.Name = "StackLimit"
	stack.AnchorPoint = Vector2.new(1, 1)
	stack.Position = UDim2.new(1, -24, 1, -12)
	stack.Size = UDim2.new(0.5, 0, 0, 18)
	stack.BackgroundTransparency = 1
	stack.Font = Enum.Font.GothamMedium
	stack.Text = ""
	stack.TextColor3 = Color3.fromRGB(137, 148, 169)
	stack.TextSize = 10
	stack.TextXAlignment = Enum.TextXAlignment.Right
	stack.ZIndex = 92
	stack.Parent = card
	stackText = stack

	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyResponsiveLayout)
	applyResponsiveLayout()
end

local function getAccent(payload)
	if typeof(payload.color) == "Color3" then
		return payload.color
	end
	local rarity = tostring(payload.rarity or "Common")
	local defaults = {
		Common = Color3.fromRGB(226, 229, 235),
		Uncommon = Color3.fromRGB(98, 203, 110),
		Rare = Color3.fromRGB(87, 161, 255),
		Epic = Color3.fromRGB(173, 106, 255),
		Legendary = Color3.fromRGB(246, 194, 84),
	}
	return defaults[rarity] or Color3.fromRGB(225, 191, 92)
end

local function populateReward(payload)
	local rewardData = payload.item or payload.fallback or {}
	local accent = getAccent(payload)
	local rarity = tostring(payload.rarity or rewardData.Rarity or "Reward")

	rarityStrip.BackgroundColor3 = accent
	rarityText.BackgroundColor3 = accent
	rarityText.Text = string.upper(rarity)
	sourceText.Text = string.upper(tostring(payload.sourceName or "Treasure Chest"))
	titleText.Text = tostring(rewardData.Name or "Reward")
	descriptionText.Text = tostring(rewardData.Description or "Take this reward to continue the run.")

	local maxStacks = tonumber(rewardData.MaxStacks)
	stackText.Text = maxStacks and string.format("MAX STACKS: %d", maxStacks) or "IMMEDIATE REWARD"

	clearModifierRows()
	local lines = rewardData.ModifierLines
	if typeof(lines) == "table" and #lines > 0 then
		for index, entry in ipairs(lines) do
			addModifierRow(entry, index)
		end
	else
		addModifierRow({ Text = "Reward applied immediately." }, 1)
	end
	updateModifierCanvas()

	if boundActionFrame then
		styleActionFrame(boundActionFrame, accent)
	end
end

local function revealDetails(payload)
	if not presentationRoot or not presentationRoot.Visible or not detailsCard then
		return
	end

	populateReward(payload)
	openingStatus.Visible = false
	detailsCard.Visible = true
	detailsScale.Scale = 0.9
	TweenService:Create(detailsScale, REVEAL_TWEEN, { Scale = 1 }):Play()
end

local function bindActionFrame(sessionId, openingGui)
	disconnectActionVisibility()

	local actionFrame = openingGui:FindFirstChild(ACTION_FRAME_NAME)
	if not actionFrame then
		actionFrame = openingGui:WaitForChild(ACTION_FRAME_NAME, 2)
	end
	if activeSession ~= sessionId or not actionFrame or not actionFrame:IsA("Frame") then
		return
	end

	boundActionFrame = actionFrame
	styleActionFrame(actionFrame, getAccent(currentPayload or {}))
	applyResponsiveLayout()

	local function refreshReveal()
		if activeSession ~= sessionId or not currentPayload then
			return
		end
		if actionFrame.Visible then
			revealDetails(currentPayload)
		end
	end

	actionVisibilityConnection = actionFrame:GetPropertyChangedSignal("Visible"):Connect(refreshReveal)
	refreshReveal()
end

local function showPresentation(payload)
	local openingGui = getOpeningGui()
	if not openingGui then
		return
	end

	activeSession += 1
	local sessionId = activeSession
	currentPayload = payload
	buildPresentation(openingGui)

	presentationRoot.Visible = true
	backdrop.BackgroundTransparency = 0.52
	openingStatus.Visible = true
	openingStatus.Text = "OPENING " .. string.upper(tostring(payload.sourceName or "TREASURE CHEST"))
	detailsCard.Visible = false
	clearModifierRows()

	task.spawn(bindActionFrame, sessionId, openingGui)
end

local function hidePresentation()
	activeSession += 1
	currentPayload = nil
	disconnectActionVisibility()
	if presentationRoot then
		presentationRoot.Visible = false
	end
end

playerGui.ChildRemoved:Connect(function(child)
	if child == boundOpeningGui then
		hidePresentation()
		boundOpeningGui = nil
		presentationRoot = nil
		backdrop = nil
		openingStatus = nil
		detailsCard = nil
		detailsScale = nil
		rarityStrip = nil
		rarityText = nil
		sourceText = nil
		titleText = nil
		descriptionText = nil
		stackText = nil
		modifiersList = nil
		modifiersLayout = nil
	end
end)

chestItemEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	if payload.type == "openReward" then
		showPresentation(payload)
	elseif payload.type == "rewardClosed" then
		hidePresentation()
	end
end)
