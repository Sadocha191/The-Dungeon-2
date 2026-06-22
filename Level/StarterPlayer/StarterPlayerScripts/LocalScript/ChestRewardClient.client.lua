local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local ChestItemConfig = require(moduleFolder:WaitForChild("Items"):WaitForChild("ChestItemConfig"))
local StatsConfig = require(moduleFolder:WaitForChild("Stats"):WaitForChild("StatsConfig"))

local chestItemEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChestItemEvent")

local ROLL_DURATION = 0.6
local ROLL_MIN_STEP = 0.03
local ROLL_MAX_STEP = 0.08
local CHEST_OPENING_GUI_NAME = "ChestOpening"
local CHEST_MODEL_NAME = "skrzynia"
local CHEST_ITEM_IMAGE_NAME = "Item"
local CHEST_OPEN_ANIMATION_NAME = "OpenAnimation"
local CHEST_OPEN_ANIMATION_ID = "rbxassetid://128606196135074"
local CHEST_OPEN_ANIMATION_DURATION = 2.02
local CHEST_OPEN_ANIMATION_DELAY = 0.5

local rng = Random.new()

local initialChestOpeningGui = playerGui:FindFirstChild(CHEST_OPENING_GUI_NAME)
if initialChestOpeningGui and initialChestOpeningGui:IsA("ScreenGui") then
	initialChestOpeningGui.Enabled = false

	local initialItemImage = initialChestOpeningGui:FindFirstChild(CHEST_ITEM_IMAGE_NAME, true)
	if initialItemImage and initialItemImage:IsA("ImageLabel") then
		initialItemImage.Image = ""
		initialItemImage.Visible = false
	end
end

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
dim.BackgroundTransparency = 1
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

local iconImage = Instance.new("ImageLabel")
iconImage.BackgroundTransparency = 1
iconImage.Position = UDim2.fromOffset(12, 12)
iconImage.Size = UDim2.new(1, -24, 1, -24)
iconImage.Image = ""
iconImage.ScaleType = Enum.ScaleType.Fit
iconImage.Visible = false
iconImage.Parent = iconFrame

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
statusText.Position = UDim2.fromOffset(28, 350)
statusText.Size = UDim2.new(1, -220, 0, 28)
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 12
statusText.TextWrapped = true
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.TextYAlignment = Enum.TextYAlignment.Top
statusText.TextColor3 = Color3.fromRGB(140, 152, 175)
statusText.Text = "Take the reward to resume the run."
statusText.Parent = card

local currentToken = nil
local takePending = false
local uiState = "hidden"
local skipRoll = false
local activeRollSession = 0
local usingChestOpeningGui = false
local chestOpeningTrack = nil
local boundChestOpeningItem = nil
local chestOpeningItemConnection = nil
local boundChestOpeningTakeButton = nil
local chestOpeningTakeConnection = nil
local setChestOpeningTakeEnabled

local function getChestOpeningGui()
	local openingGui = playerGui:FindFirstChild(CHEST_OPENING_GUI_NAME)
	if not openingGui then
		openingGui = playerGui:WaitForChild(CHEST_OPENING_GUI_NAME, 1)
	end
	if not openingGui or not openingGui:IsA("ScreenGui") then
		return nil
	end

	openingGui.ResetOnSpawn = false
	openingGui.IgnoreGuiInset = true
	openingGui.DisplayOrder = math.max(openingGui.DisplayOrder, 92)
	return openingGui
end

local function getChestOpeningParts()
	local openingGui = getChestOpeningGui()
	if not openingGui then
		return nil
	end

	local itemImage = openingGui:FindFirstChild(CHEST_ITEM_IMAGE_NAME, true)
	local chestModel = openingGui:FindFirstChild(CHEST_MODEL_NAME, true)
	if not itemImage or not itemImage:IsA("ImageLabel") then
		warn("[ChestRewardClient] ChestOpening.Item ImageLabel not found")
		return nil
	end
	if not chestModel or not chestModel:IsA("Model") then
		warn("[ChestRewardClient] ChestOpening skrzynia model not found")
		return nil
	end

	local viewport = openingGui:FindFirstChild("ViewportFrame", true)
	local camera = openingGui:FindFirstChild("Camera", true)
	if viewport and viewport:IsA("ViewportFrame") and camera and camera:IsA("Camera") then
		viewport.CurrentCamera = camera
	end

	return openingGui, itemImage, chestModel
end

local function isChestOpeningGuiEnabled()
	local openingGui = playerGui:FindFirstChild(CHEST_OPENING_GUI_NAME)
	return openingGui ~= nil and openingGui:IsA("ScreenGui") and openingGui.Enabled
end

local function isRewardUiOpen()
	return gui.Enabled or isChestOpeningGuiEnabled()
end

local function showGuiAncestors(guiObject, stopAncestor)
	local current = guiObject
	while current and current ~= stopAncestor do
		if current:IsA("GuiObject") then
			current.Visible = true
		end
		current = current.Parent
	end
end

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

local function buildModifierDisplay(statName, delta)
	local definition = StatsConfig.Get(statName)
	if not definition then
		return string.format("%s %+0.2f", tostring(statName), tonumber(delta) or 0)
	end

	local numericDelta = tonumber(delta) or 0
	local sign = numericDelta >= 0 and "+" or "-"
	local absDelta = math.abs(numericDelta)
	local label = definition.Label or statName

	if definition.Format == "percent" then
		return string.format("%s %s%d%%", label, sign, math.floor(absDelta * 100 + 0.5))
	end
	if definition.Format == "multiplier" then
		return string.format("%s %s%.2fx", label, sign, absDelta)
	end

	local decimals = math.max(0, math.floor(tonumber(definition.Decimals) or 0))
	return string.format("%s %s%." .. decimals .. "f", label, sign, absDelta)
end

local function buildModifierLinesFromModifiers(modifiers)
	local entries = {}
	for statName, delta in pairs(modifiers or {}) do
		entries[#entries + 1] = {
			StatName = statName,
			Text = buildModifierDisplay(statName, delta),
		}
	end

	table.sort(entries, function(a, b)
		local orderA = table.find(StatsConfig.DisplayOrder, a.StatName) or math.huge
		local orderB = table.find(StatsConfig.DisplayOrder, b.StatName) or math.huge
		if orderA ~= orderB then
			return orderA < orderB
		end
		return tostring(a.StatName) < tostring(b.StatName)
	end)

	return entries
end

local function shuffleInPlace(list)
	for index = #list, 2, -1 do
		local swapIndex = rng:NextInteger(1, index)
		list[index], list[swapIndex] = list[swapIndex], list[index]
	end
end

local function buildItemPreview(itemDefinition)
	return {
		Id = itemDefinition.Id,
		Name = itemDefinition.Name,
		Description = itemDefinition.Description,
		Rarity = itemDefinition.Rarity,
		ModifierLines = buildModifierLinesFromModifiers(itemDefinition.Modifiers),
	}
end

local function buildFallbackPreview(rewardDefinition)
	return {
		Id = rewardDefinition.Id,
		Name = rewardDefinition.Name,
		Description = rewardDefinition.Description,
		Rarity = "Common",
		ModifierLines = {
			{
				Text = string.format("+%d %s", tonumber(rewardDefinition.Amount) or 0, tostring(rewardDefinition.Kind or "Reward")),
			},
		},
	}
end

local function buildPayloadPreview(payload)
	local rewardData = payload.item or payload.fallback or {}
	return {
		Id = rewardData.Id,
		Name = tostring(rewardData.Name or "Reward"),
		Description = tostring(rewardData.Description or "Take this reward to continue the run."),
		Rarity = tostring(payload.rarity or rewardData.Rarity or "Common"),
		ModifierLines = rewardData.ModifierLines or {},
	}
end

local function buildMixedItemRollPreviews(excludedItemId)
	local rarityBuckets = {}
	local totalCandidates = 0

	for _, rarity in ipairs(ChestItemConfig.RarityOrder or {}) do
		local bucket = {}
		for _, itemDefinition in ipairs(ChestItemConfig.GetItemsForRarity(rarity)) do
			if itemDefinition.Id ~= excludedItemId then
				bucket[#bucket + 1] = buildItemPreview(itemDefinition)
			end
		end
		shuffleInPlace(bucket)
		rarityBuckets[rarity] = bucket
		totalCandidates += #bucket
	end

	if totalCandidates <= 0 then
		return {}
	end

	local sequence = {}
	while #sequence < math.min(6, totalCandidates) do
		local addedInPass = false
		for _, rarity in ipairs(ChestItemConfig.RarityOrder or {}) do
			local bucket = rarityBuckets[rarity]
			if bucket and #bucket > 0 then
				sequence[#sequence + 1] = table.remove(bucket, 1)
				addedInPass = true
				if #sequence >= math.min(6, totalCandidates) then
					break
				end
			end
		end

		if not addedInPass then
			break
		end
	end

	shuffleInPlace(sequence)
	return sequence
end

local function buildRollSequence(payload)
	local finalPreview = buildPayloadPreview(payload)
	local sequence = {}

	if payload.rewardType == "Item" and payload.item then
		sequence = buildMixedItemRollPreviews(payload.item.Id)
	elseif payload.rewardType == "Fallback" and payload.fallback then
		local candidates = {}
		for _, fallbackDefinition in ipairs(ChestItemConfig.FallbackRewards or {}) do
			if fallbackDefinition.Id ~= payload.fallback.Id then
				candidates[#candidates + 1] = buildFallbackPreview(fallbackDefinition)
			end
		end
		shuffleInPlace(candidates)
		for index = 1, math.min(3, #candidates) do
			sequence[#sequence + 1] = candidates[index]
		end
	end

	if #sequence == 0 then
		sequence[1] = finalPreview
	end

	return sequence, finalPreview
end

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

	table.insert(candidateNames, string.gsub(itemName, "'", utf8.char(0x2019)))
	table.insert(candidateNames, string.gsub(itemName, utf8.char(0x2019), "'"))

	for _, candidateName in ipairs(candidateNames) do
		local iconSource = rarityFolder:FindFirstChild(candidateName)
		if iconSource and iconSource:IsA("ImageLabel") and iconSource.Image ~= "" then
			return iconSource.Image
		end
	end

	return nil
end

local function getPreviewIconImage(previewData, payload)
	if payload.rewardType == "Item" then
		local iconImageId = getItemIconImage(previewData.Rarity, previewData.Name)
		if iconImageId then
			return iconImageId
		end

		local payloadIcon = payload.item and payload.item.Icon
		if typeof(payloadIcon) == "string" and string.match(payloadIcon, "^rbx") then
			return payloadIcon
		end
	end

	return nil
end

local function setPreviewIcon(previewData, payload)
	local initials = string.upper(string.sub(tostring(previewData.Name or "IT"), 1, 2))
	local iconImageId = getPreviewIconImage(previewData, payload)

	iconText.Text = initials

	if iconImageId then
		iconImage.Image = iconImageId
		iconImage.Visible = true
		iconText.Visible = false
		return
	end

	iconImage.Image = ""
	iconImage.Visible = false
	iconText.Visible = true
end

local function setPreview(previewData, payload, isFinal)
	local accent = ChestItemConfig.RarityColors[previewData.Rarity] or (typeof(payload.color) == "Color3" and payload.color) or Color3.fromRGB(96, 168, 255)
	local modifierLines = previewData.ModifierLines or {}

	cardStroke.Color = accent
	rarityPill.BackgroundColor3 = accent
	rarityPill.Text = string.upper(tostring(previewData.Rarity or payload.rarity or "Reward"))
	iconText.TextColor3 = accent
	sourceText.Text = tostring(payload.sourceName or "Treasure Chest")
	titleText.Text = tostring(previewData.Name or "Reward")
	descriptionText.Text = tostring(previewData.Description or "Take this reward to continue the run.")
	setPreviewIcon(previewData, payload)

	clearModifierLines()
	if #modifierLines > 0 then
		for _, entry in ipairs(modifierLines) do
			addModifierLine(entry.Text or entry.text or entry)
		end
	elseif isFinal then
		addModifierLine("No additional stat changes.")
	else
		addModifierLine("Scanning chest reward...")
	end
end

local function getRevealInstruction(payload)
	if payload.rewardType == "Fallback" then
		return "Press Space or click TAKE to accept the fallback reward."
	end
	return "Press Space or click TAKE to accept the item."
end

local function setRollingState()
	uiState = "rolling"
	takePending = false
	setTakeEnabled(false)
	takeButton.Text = "ROLLING..."
	statusText.Text = "Press Space to skip the chest draw."
end

local function setRevealState(payload)
	uiState = "revealed"
	takePending = false
	setTakeEnabled(true)
	takeButton.Text = "TAKE"
	statusText.Text = getRevealInstruction(payload)
end

local function attemptTakeReward()
	if uiState ~= "revealed" or not currentToken or takePending then
		return
	end

	uiState = "taking"
	takePending = true
	setTakeEnabled(false)
	takeButton.Text = "TAKING..."
	statusText.Text = "Taking reward..."
	chestItemEvent:FireServer({
		type = "takeReward",
		token = currentToken,
	})
end

local function stopChestOpeningTrack()
	if chestOpeningTrack then
		pcall(function()
			chestOpeningTrack:Stop(0)
			chestOpeningTrack:Destroy()
		end)
		chestOpeningTrack = nil
	end
end

local function hideChestOpeningGui()
	stopChestOpeningTrack()
	usingChestOpeningGui = false

	local openingGui = getChestOpeningGui()
	if openingGui then
		local itemImage = openingGui:FindFirstChild(CHEST_ITEM_IMAGE_NAME, true)
		if itemImage and itemImage:IsA("ImageLabel") then
			setChestOpeningTakeEnabled(itemImage, false)
			itemImage.Image = ""
			itemImage.Visible = false
		end
		openingGui.Enabled = false
	end
end

local function getChestAnimator(chestModel)
	local controller = chestModel:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = chestModel
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	return animator
end

local function getChestOpenAnimation(chestModel)
	local animation = chestModel:FindFirstChild(CHEST_OPEN_ANIMATION_NAME)
	if not animation or not animation:IsA("Animation") then
		animation = Instance.new("Animation")
		animation.Name = CHEST_OPEN_ANIMATION_NAME
		animation.Parent = chestModel
	end
	animation.AnimationId = CHEST_OPEN_ANIMATION_ID
	return animation
end

local function bindChestOpeningItem(itemImage)
	if boundChestOpeningItem == itemImage and chestOpeningItemConnection then
		return
	end
	if chestOpeningItemConnection then
		chestOpeningItemConnection:Disconnect()
		chestOpeningItemConnection = nil
	end

	boundChestOpeningItem = itemImage
	itemImage.Active = true
	chestOpeningItemConnection = itemImage.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			attemptTakeReward()
		end
	end)
end

function setChestOpeningTakeEnabled(itemImage, enabled)
	local takeButton = itemImage:FindFirstChild("TakeRewardButton")
	if not takeButton or not takeButton:IsA("TextButton") then
		if takeButton then
			takeButton:Destroy()
		end
		takeButton = Instance.new("TextButton")
		takeButton.Name = "TakeRewardButton"
		takeButton.BackgroundTransparency = 1
		takeButton.BorderSizePixel = 0
		takeButton.Text = ""
		takeButton.AutoButtonColor = false
		takeButton.Selectable = false
		takeButton.Size = UDim2.fromScale(1, 1)
		takeButton.ZIndex = itemImage.ZIndex + 1
		takeButton.Parent = itemImage
	end

	if boundChestOpeningTakeButton ~= takeButton then
		if chestOpeningTakeConnection then
			chestOpeningTakeConnection:Disconnect()
			chestOpeningTakeConnection = nil
		end
		boundChestOpeningTakeButton = takeButton
		chestOpeningTakeConnection = takeButton.MouseButton1Click:Connect(function()
			attemptTakeReward()
		end)
	end

	takeButton.Active = enabled
	takeButton.Visible = enabled
end

local function getChestOpeningTrackDuration(track)
	local timeoutAt = os.clock() + 1
	while track and track.Length <= 0 and os.clock() < timeoutAt do
		task.wait()
	end
	if track and track.Length > 0 then
		return track.Length
	end
	return CHEST_OPEN_ANIMATION_DURATION
end

local function freezeChestOpeningTrack(track, duration)
	if not track then
		return
	end

	pcall(function()
		local targetPosition = tonumber(duration) or CHEST_OPEN_ANIMATION_DURATION
		if track.Length and track.Length > 0 then
			targetPosition = math.min(track.Length, targetPosition)
		end
		targetPosition = math.max(0, targetPosition - (1 / 60))

		if not track.IsPlaying then
			track:Play(0, 1, 0)
		end
		track.TimePosition = targetPosition
		track:AdjustSpeed(0)
	end)
end

local function playChestOpeningAnimation(chestModel)
	stopChestOpeningTrack()

	local animator = getChestAnimator(chestModel)
	local animation = getChestOpenAnimation(chestModel)
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok or not track then
		warn("[ChestRewardClient] Failed to load ChestOpening animation")
		return nil
	end

	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0, 1, 1)
	chestOpeningTrack = track
	return track
end

local function revealChestOpeningItem(itemImage, previewData, payload)
	local iconImageId = getPreviewIconImage(previewData, payload)
	showGuiAncestors(itemImage, nil)
	itemImage.BackgroundTransparency = 1
	itemImage.Image = iconImageId or "rbxasset://textures/ui/GuiImagePlaceholder.png"
	itemImage.ImageColor3 = Color3.new(1, 1, 1)
	itemImage.ImageTransparency = 0
	itemImage.ScaleType = Enum.ScaleType.Fit
	itemImage.Visible = true
	setChestOpeningTakeEnabled(itemImage, true)
end

local function showChestOpeningReward(sessionId, payload, openingGui, itemImage, chestModel)
	local _, finalPreview = buildRollSequence(payload)

	usingChestOpeningGui = true
	gui.Enabled = false
	openingGui.Enabled = true
	itemImage.Image = ""
	itemImage.ImageTransparency = 0
	itemImage.Visible = false
	bindChestOpeningItem(itemImage)
	setChestOpeningTakeEnabled(itemImage, false)
	setRollingState()

	task.delay(CHEST_OPEN_ANIMATION_DELAY, function()
		if activeRollSession ~= sessionId or not usingChestOpeningGui then
			return
		end

		local track = playChestOpeningAnimation(chestModel)
		local duration = getChestOpeningTrackDuration(track)
		task.delay(duration, function()
			if activeRollSession ~= sessionId or not usingChestOpeningGui then
				return
			end

			freezeChestOpeningTrack(track, duration)
			revealChestOpeningItem(itemImage, finalPreview, payload)
			setRevealState(payload)
		end)
	end)
end

local function hideReward()
	activeRollSession += 1
	currentToken = nil
	takePending = false
	uiState = "hidden"
	skipRoll = false
	hideChestOpeningGui()
	gui.Enabled = false
	takeButton.Text = "TAKE"
	statusText.Text = "Take the reward to resume the run."
	clearModifierLines()
end

local function startRollAnimation(sessionId, payload)
	local sequence, finalPreview = buildRollSequence(payload)
	local startedAt = os.clock()
	local index = 1

	while activeRollSession == sessionId and not skipRoll and (os.clock() - startedAt) < ROLL_DURATION do
		local preview = sequence[((index - 1) % #sequence) + 1]
		setPreview(preview, payload, false)
		index += 1

		local alpha = math.clamp((os.clock() - startedAt) / ROLL_DURATION, 0, 1)
		task.wait(ROLL_MIN_STEP + ((ROLL_MAX_STEP - ROLL_MIN_STEP) * alpha))
	end

	if activeRollSession ~= sessionId then
		return
	end

	setPreview(finalPreview, payload, true)
	setRevealState(payload)
end

local function showReward(payload)
	activeRollSession += 1
	local sessionId = activeRollSession

	currentToken = payload.token
	skipRoll = false
	local openingGui, itemImage, chestModel = getChestOpeningParts()
	if openingGui and itemImage and chestModel then
		showChestOpeningReward(sessionId, payload, openingGui, itemImage, chestModel)
		return
	end

	usingChestOpeningGui = false
	gui.Enabled = true
	setRollingState()

	local initialSequence = buildRollSequence(payload)
	setPreview(initialSequence[1], payload, false)

	task.spawn(startRollAnimation, sessionId, payload)
end

takeButton.MouseButton1Click:Connect(function()
	attemptTakeReward()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if not isRewardUiOpen() then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.Space then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end

	if uiState == "rolling" then
		if usingChestOpeningGui then
			return
		end
		skipRoll = true
		statusText.Text = "Skipping chest draw..."
	elseif uiState == "revealed" then
		attemptTakeReward()
	end
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
