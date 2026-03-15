local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local BountyBoardEvent = remoteEvents:WaitForChild("BountyBoardEvent")

local rarityColors = {
	Common = Color3.fromRGB(176, 184, 198),
	Uncommon = Color3.fromRGB(112, 196, 120),
	Rare = Color3.fromRGB(100, 165, 255),
	Epic = Color3.fromRGB(190, 120, 255),
	Legendary = Color3.fromRGB(255, 196, 96),
	Mythical = Color3.fromRGB(255, 110, 118),
}

local reasonText = {
	BoardFull = "The board is full right now.",
	TooManyActiveBounties = "You already have the maximum number of active bounties.",
	UnknownMaterial = "That material is not valid for bounty requests.",
	BadAmount = "Choose an amount between 1 and 99.",
	BadReward = "Choose a reward per item between 1 and 50000 silver.",
	NotEnoughSilver = "You do not have enough silver to reserve that bounty.",
	UnknownBounty = "That bounty is no longer available.",
	Forbidden = "Only the poster can cancel this bounty.",
	OwnBounty = "You cannot fulfill your own bounty.",
	PosterUnavailable = "The poster is no longer in this server.",
	NotEnoughMaterial = "You do not currently have enough of that material.",
}

local currentMode = "Browse"
local snapshot = {
	silver = 0,
	materials = {},
	mineResources = {},
	mobMaterials = {},
	bounties = {},
	activeOwnedCount = 0,
	maxActivePerPlayer = 5,
	maxAmount = 99,
	maxRewardPerUnit = 50000,
}
local selectedBountyId = nil
local selectedMaterialId = nil
local currentStatusText = ""
local currentStatusOk = true

local function getRarityColor(rarity)
	return rarityColors[tostring(rarity or "")] or rarityColors.Common
end

local function blendColor(fromColor, toColor, alpha)
	return Color3.new(
		fromColor.R + (toColor.R - fromColor.R) * alpha,
		fromColor.G + (toColor.G - fromColor.G) * alpha,
		fromColor.B + (toColor.B - fromColor.B) * alpha
	)
end

local function sumAmounts(list)
	local total = 0
	for _, entry in ipairs(list or {}) do
		total += math.floor(tonumber(entry.amount) or 0)
	end
	return total
end

local function findBountyById(bountyId)
	for _, entry in ipairs(snapshot.bounties or {}) do
		if entry.id == bountyId then
			return entry
		end
	end
	return nil
end

local function findMaterialById(materialId)
	for _, entry in ipairs(snapshot.materials or {}) do
		if entry.id == materialId then
			return entry
		end
	end
	return nil
end

local function setStatus(text, ok)
	currentStatusText = tostring(text or "")
	currentStatusOk = ok ~= false
end

local function setStatusFromResult(result)
	if typeof(result) ~= "table" then
		return
	end
	if result.ok == true then
		setStatus(tostring(result.message or "Board updated."), true)
		return
	end
	local reason = tostring(result.reason or "")
	setStatus(reasonText[reason] or reason or "Action failed.", false)
end

local gui = playerGui:WaitForChild("BountyBoardGui")
gui.ResetOnSpawn = false
gui.Enabled = false
gui.IgnoreGuiInset = true
gui:SetAttribute("Modal", true)

local overlay = gui:WaitForChild("overlay")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.4
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = overlay:WaitForChild("panel")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.92, 0.92)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)
local panelSizeConstraint = Instance.new("UISizeConstraint", panel)
panelSizeConstraint.MaxSize = Vector2.new(1160, 660)
local panelAspect = Instance.new("UIAspectRatioConstraint", panel)
panelAspect.AspectRatio = 1160 / 660
panelAspect.DominantAxis = Enum.DominantAxis.Height
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(46, 54, 70)
panelStroke.Thickness = 1

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 18)
title.Size = UDim2.fromOffset(420, 28)
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Text = "Bounty Board"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(24, 48)
subtitle.Size = UDim2.fromOffset(600, 20)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextColor3 = Color3.fromRGB(190, 190, 190)
subtitle.Text = "Post requests for crafting materials. Rewards are reserved in silver until the bounty is fulfilled or cancelled."
subtitle.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -18, 0, 18)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.TextColor3 = Color3.fromRGB(235, 235, 235)
closeButton.Text = "X"
closeButton.Parent = panel
Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 10)

local summary = Instance.new("Frame")
summary.Position = UDim2.fromOffset(24, 82)
summary.Size = UDim2.new(1, -48, 0, 84)
summary.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
summary.BorderSizePixel = 0
summary.Parent = panel
Instance.new("UICorner", summary).CornerRadius = UDim.new(0, 14)
local summaryStroke = Instance.new("UIStroke", summary)
summaryStroke.Color = Color3.fromRGB(46, 54, 70)
summaryStroke.Thickness = 1

local summaryLabel = Instance.new("TextLabel")
summaryLabel.BackgroundTransparency = 1
summaryLabel.Position = UDim2.fromOffset(16, 12)
summaryLabel.Size = UDim2.new(1, -32, 1, -24)
summaryLabel.Font = Enum.Font.Gotham
summaryLabel.TextSize = 13
summaryLabel.TextWrapped = true
summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
summaryLabel.TextYAlignment = Enum.TextYAlignment.Top
summaryLabel.TextColor3 = Color3.fromRGB(222, 222, 222)
summaryLabel.Text = "Loading..."
summaryLabel.Parent = summary

local tabBar = Instance.new("Frame")
tabBar.Position = UDim2.fromOffset(24, 182)
tabBar.Size = UDim2.fromOffset(280, 42)
tabBar.BackgroundTransparency = 1
tabBar.Parent = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabBar

local function createTabButton(text)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(132, 42)
	button.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(226, 226, 226)
	button.Text = text
	button.Parent = tabBar
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	return button
end

local browseTabButton = createTabButton("Browse")
local createTabButtonRef = createTabButton("Create")

local listFrame = Instance.new("ScrollingFrame")
listFrame.Position = UDim2.fromOffset(24, 238)
listFrame.Size = UDim2.fromOffset(420, 382)
listFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.Parent = panel
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 14)
local listStroke = Instance.new("UIStroke", listFrame)
listStroke.Color = Color3.fromRGB(46, 54, 70)
listStroke.Thickness = 1
local listPadding = Instance.new("UIPadding", listFrame)
listPadding.PaddingTop = UDim.new(0, 14)
listPadding.PaddingBottom = UDim.new(0, 14)
listPadding.PaddingLeft = UDim.new(0, 14)
listPadding.PaddingRight = UDim.new(0, 14)
local listLayoutRef = Instance.new("UIListLayout", listFrame)
listLayoutRef.Padding = UDim.new(0, 8)

local emptyListLabel = Instance.new("TextLabel")
emptyListLabel.BackgroundTransparency = 1
emptyListLabel.Size = UDim2.new(1, 0, 0, 44)
emptyListLabel.Font = Enum.Font.Gotham
emptyListLabel.TextSize = 14
emptyListLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
emptyListLabel.TextWrapped = true
emptyListLabel.Text = "Nothing to show here yet."
emptyListLabel.Visible = false
emptyListLabel.Parent = listFrame

local details = Instance.new("Frame")
details.Position = UDim2.fromOffset(460, 182)
details.Size = UDim2.new(1, -484, 0, 438)
details.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
details.BorderSizePixel = 0
details.Parent = panel
Instance.new("UICorner", details).CornerRadius = UDim.new(0, 14)
local detailsStroke = Instance.new("UIStroke", details)
detailsStroke.Color = Color3.fromRGB(46, 54, 70)
detailsStroke.Thickness = 1
local detailAccent = Instance.new("Frame")
detailAccent.Size = UDim2.new(1, 0, 0, 4)
detailAccent.BackgroundColor3 = Color3.fromRGB(96, 165, 250)
detailAccent.BorderSizePixel = 0
detailAccent.Parent = details
Instance.new("UICorner", detailAccent).CornerRadius = UDim.new(0, 10)

local detailTitle = Instance.new("TextLabel")
detailTitle.BackgroundTransparency = 1
detailTitle.Position = UDim2.fromOffset(18, 14)
detailTitle.Size = UDim2.new(1, -36, 0, 24)
detailTitle.Font = Enum.Font.GothamBold
detailTitle.TextSize = 18
detailTitle.TextXAlignment = Enum.TextXAlignment.Left
detailTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
detailTitle.Text = "Select an entry"
detailTitle.Parent = details

local detailSubtitle = Instance.new("TextLabel")
detailSubtitle.BackgroundTransparency = 1
detailSubtitle.Position = UDim2.fromOffset(18, 40)
detailSubtitle.Size = UDim2.new(1, -36, 0, 20)
detailSubtitle.Font = Enum.Font.Gotham
detailSubtitle.TextSize = 12
detailSubtitle.TextXAlignment = Enum.TextXAlignment.Left
detailSubtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
detailSubtitle.Text = ""
detailSubtitle.Parent = details

local detailBody = Instance.new("TextLabel")
detailBody.BackgroundTransparency = 1
detailBody.Position = UDim2.fromOffset(18, 72)
detailBody.Size = UDim2.new(1, -36, 0, 150)
detailBody.Font = Enum.Font.Gotham
detailBody.TextSize = 13
detailBody.TextWrapped = true
detailBody.TextXAlignment = Enum.TextXAlignment.Left
detailBody.TextYAlignment = Enum.TextYAlignment.Top
detailBody.TextColor3 = Color3.fromRGB(220, 220, 220)
detailBody.Text = "Select an entry from the list."
detailBody.Parent = details

local browseActionButton = Instance.new("TextButton")
browseActionButton.Position = UDim2.fromOffset(18, 370)
browseActionButton.Size = UDim2.new(1, -36, 0, 44)
browseActionButton.BackgroundColor3 = Color3.fromRGB(70, 110, 255)
browseActionButton.BorderSizePixel = 0
browseActionButton.Font = Enum.Font.GothamBold
browseActionButton.TextSize = 14
browseActionButton.TextColor3 = Color3.fromRGB(245, 245, 245)
browseActionButton.Text = "Fulfill Bounty"
browseActionButton.Parent = details
Instance.new("UICorner", browseActionButton).CornerRadius = UDim.new(0, 12)

local createForm = Instance.new("Frame")
createForm.Position = UDim2.fromOffset(18, 238)
createForm.Size = UDim2.new(1, -36, 0, 176)
createForm.BackgroundTransparency = 1
createForm.Parent = details
createForm.Visible = false

local formLayout = Instance.new("UIListLayout")
formLayout.Padding = UDim.new(0, 10)
formLayout.Parent = createForm

local function createField(labelText, defaultValue)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 62)
	holder.BackgroundTransparency = 1
	holder.Parent = createForm

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.Text = labelText
	label.Parent = holder

	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(0, 24)
	box.Size = UDim2.new(1, 0, 0, 38)
	box.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.TextSize = 14
	box.TextColor3 = Color3.fromRGB(245, 245, 245)
	box.PlaceholderColor3 = Color3.fromRGB(160, 160, 160)
	box.Text = defaultValue
	box.Parent = holder
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
	return box
end

local amountBox = createField("Amount Wanted", "1")
local rewardBox = createField("Reward Per Item", "25")

local costPreview = Instance.new("TextLabel")
costPreview.BackgroundTransparency = 1
costPreview.Size = UDim2.new(1, 0, 0, 18)
costPreview.Font = Enum.Font.Gotham
costPreview.TextSize = 12
costPreview.TextXAlignment = Enum.TextXAlignment.Left
costPreview.TextColor3 = Color3.fromRGB(214, 214, 214)
costPreview.Text = "Reserved silver: 25"
costPreview.Parent = createForm

local createActionButton = Instance.new("TextButton")
createActionButton.Position = UDim2.fromOffset(18, 370)
createActionButton.Size = UDim2.new(1, -36, 0, 44)
createActionButton.BackgroundColor3 = Color3.fromRGB(66, 176, 112)
createActionButton.BorderSizePixel = 0
createActionButton.Font = Enum.Font.GothamBold
createActionButton.TextSize = 14
createActionButton.TextColor3 = Color3.fromRGB(245, 245, 245)
createActionButton.Text = "Post Bounty"
createActionButton.Parent = details
createActionButton.Visible = false
Instance.new("UICorner", createActionButton).CornerRadius = UDim.new(0, 12)

local footerStatus = Instance.new("TextLabel")
footerStatus.BackgroundTransparency = 1
footerStatus.Position = UDim2.fromOffset(24, 626)
footerStatus.Size = UDim2.new(1, -48, 0, 20)
footerStatus.Font = Enum.Font.Gotham
footerStatus.TextSize = 12
footerStatus.TextXAlignment = Enum.TextXAlignment.Left
footerStatus.TextColor3 = Color3.fromRGB(190, 190, 190)
footerStatus.Text = ""
footerStatus.Parent = panel

local function setVisible(visible)
	gui.Enabled = visible == true
end

local function setButtonState(button, enabled, activeColor)
	button.AutoButtonColor = enabled
	button.Active = enabled
	button.Selectable = enabled
	if enabled then
		button.BackgroundColor3 = activeColor
	else
		button.BackgroundColor3 = Color3.fromRGB(60, 64, 74)
	end
end

local function makeListButton(titleText, subtitleText, accentColor)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 72)
	button.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel = 0
	accent.Parent = button
	Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 8)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(16, 10)
	titleLabel.Size = UDim2.new(1, -28, 0, 22)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Color3.fromRGB(242, 242, 242)
	titleLabel.Text = titleText
	titleLabel.Parent = button

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromOffset(16, 34)
	subtitleLabel.Size = UDim2.new(1, -28, 0, 28)
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextSize = 12
	subtitleLabel.TextWrapped = true
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextYAlignment = Enum.TextYAlignment.Top
	subtitleLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	subtitleLabel.Text = subtitleText
	subtitleLabel.Parent = button

	return button
end

local function clearListEntries()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function selectDefaultEntries()
	if currentMode == "Browse" then
		if selectedBountyId and findBountyById(selectedBountyId) then
			return
		end
		selectedBountyId = snapshot.bounties[1] and snapshot.bounties[1].id or nil
		return
	end
	if selectedMaterialId and findMaterialById(selectedMaterialId) then
		return
	end
	selectedMaterialId = snapshot.materials[1] and snapshot.materials[1].id or nil
end

local render

local function updateTabStyles()
	local activeColor = Color3.fromRGB(70, 110, 255)
	local inactiveColor = Color3.fromRGB(32, 34, 42)
	browseTabButton.BackgroundColor3 = currentMode == "Browse" and activeColor or inactiveColor
	createTabButtonRef.BackgroundColor3 = currentMode == "Create" and activeColor or inactiveColor
end

local function updateCostPreview()
	local amount = math.max(1, math.floor(tonumber(amountBox.Text) or 1))
	local rewardPerUnit = math.max(1, math.floor(tonumber(rewardBox.Text) or 1))
	costPreview.Text = string.format("Reserved silver: %d", amount * rewardPerUnit)
end

function render()
	selectDefaultEntries()
	updateTabStyles()
	updateCostPreview()

	local mineTotal = sumAmounts(snapshot.mineResources)
	local mobTotal = sumAmounts(snapshot.mobMaterials)
	summaryLabel.Text = string.format(
		"Silver: %d\nYour active bounty slots: %d/%d\nCrafting materials on hand: %d mined, %d mob drops",
		math.floor(tonumber(snapshot.silver) or 0),
		math.floor(tonumber(snapshot.activeOwnedCount) or 0),
		math.floor(tonumber(snapshot.maxActivePerPlayer) or 0),
		mineTotal,
		mobTotal
	)

	footerStatus.Text = currentStatusText
	footerStatus.TextColor3 = currentStatusOk and Color3.fromRGB(140, 214, 164) or Color3.fromRGB(255, 136, 136)

	clearListEntries()

	if currentMode == "Browse" then
		emptyListLabel.Visible = #snapshot.bounties == 0
		for _, entry in ipairs(snapshot.bounties) do
			local accent = getRarityColor(entry.rarity)
			local subtitleText = string.format(
				"%s needs %d | Reward %d silver | You have %d",
				tostring(entry.posterName or entry.posterUsername or "Unknown"),
				math.floor(tonumber(entry.amount) or 0),
				math.floor(tonumber(entry.totalReward) or 0),
				math.floor(tonumber(entry.owned) or 0)
			)
			local button = makeListButton(tostring(entry.materialName or entry.materialId), subtitleText, accent)
			button.Parent = listFrame
			local isSelected = selectedBountyId == entry.id
			button.BackgroundColor3 = isSelected and Color3.fromRGB(44, 54, 76) or Color3.fromRGB(30, 32, 40)
			button.MouseButton1Click:Connect(function()
				selectedBountyId = entry.id
				render()
			end)
		end

		createForm.Visible = false
		createActionButton.Visible = false
		browseActionButton.Visible = true

		local selected = selectedBountyId and findBountyById(selectedBountyId) or nil
		if not selected then
			detailTitle.Text = "No active bounties"
			detailSubtitle.Text = "Post one from the Create tab."
			detailBody.Text = "There are no active bounty requests on this server."
			browseActionButton.Text = "Fulfill Bounty"
			setButtonState(browseActionButton, false, Color3.fromRGB(70, 110, 255))
			return
		end

		detailTitle.Text = tostring(selected.materialName or selected.materialId)
		detailSubtitle.Text = string.format(
			"%s | %s | Posted by %s",
			tostring(selected.source or "Crafting Material"),
			tostring(selected.rarity or "Standard"),
			tostring(selected.posterName or selected.posterUsername or "Unknown")
		)
		detailBody.Text = string.format(
			"Needed amount: %d\nReward per item: %d silver\nTotal reward: %d silver\nYou currently have: %d\n\nIf you complete this bounty, the material is transferred to the poster and you receive the reserved silver.",
			math.floor(tonumber(selected.amount) or 0),
			math.floor(tonumber(selected.rewardPerUnit) or 0),
			math.floor(tonumber(selected.totalReward) or 0),
			math.floor(tonumber(selected.owned) or 0)
		)

		if selected.isOwn then
			browseActionButton.Text = "Cancel Bounty"
			setButtonState(browseActionButton, true, Color3.fromRGB(206, 98, 98))
		elseif selected.canFulfill then
			browseActionButton.Text = "Fulfill Bounty"
			setButtonState(browseActionButton, true, Color3.fromRGB(70, 110, 255))
		else
			browseActionButton.Text = "Need More Materials"
			setButtonState(browseActionButton, false, Color3.fromRGB(70, 110, 255))
		end
		return
	end

	emptyListLabel.Visible = #snapshot.materials == 0
	for _, entry in ipairs(snapshot.materials) do
		local accent = getRarityColor(entry.rarity)
		local subtitleText = string.format(
			"%s | You own %d",
			tostring(entry.source or "Crafting Material"),
			math.floor(tonumber(entry.owned) or 0)
		)
		local button = makeListButton(tostring(entry.name or entry.id), subtitleText, accent)
		button.Parent = listFrame
		local isSelected = selectedMaterialId == entry.id
		button.BackgroundColor3 = isSelected and Color3.fromRGB(44, 54, 76) or Color3.fromRGB(30, 32, 40)
		button.MouseButton1Click:Connect(function()
			selectedMaterialId = entry.id
			render()
		end)
	end

	createForm.Visible = true
	createActionButton.Visible = true
	browseActionButton.Visible = false

	local selected = selectedMaterialId and findMaterialById(selectedMaterialId) or nil
	if not selected then
		detailTitle.Text = "Choose a material"
		detailSubtitle.Text = ""
		detailBody.Text = "Select one of the tracked crafting materials from the list, then choose amount and reward."
		setButtonState(createActionButton, false, Color3.fromRGB(66, 176, 112))
		return
	end

	local amount = math.max(1, math.floor(tonumber(amountBox.Text) or 1))
	local rewardPerUnit = math.max(1, math.floor(tonumber(rewardBox.Text) or 1))
	local totalCost = amount * rewardPerUnit
	local enoughSilver = math.floor(tonumber(snapshot.silver) or 0) >= totalCost
	local slotAvailable = math.floor(tonumber(snapshot.activeOwnedCount) or 0) < math.floor(tonumber(snapshot.maxActivePerPlayer) or 0)

	detailTitle.Text = tostring(selected.name or selected.id)
	detailSubtitle.Text = string.format("%s | %s", tostring(selected.source or "Crafting Material"), tostring(selected.rarity or "Standard"))
	detailBody.Text = string.format(
		"You currently own: %d\nRequested amount: %d\nReward per item: %d silver\nReserved total: %d silver\n\nBounties stay active only for the current server session. If you leave the server, your active bounties are cancelled and their reserved silver is refunded.",
		math.floor(tonumber(selected.owned) or 0),
		amount,
		rewardPerUnit,
		totalCost
	)

	createActionButton.Text = enoughSilver and "Post Bounty" or "Not Enough Silver"
	setButtonState(createActionButton, enoughSilver and slotAvailable, Color3.fromRGB(66, 176, 112))
end

closeButton.MouseButton1Click:Connect(function()
	setVisible(false)
end)

browseTabButton.MouseButton1Click:Connect(function()
	currentMode = "Browse"
	render()
end)

createTabButtonRef.MouseButton1Click:Connect(function()
	currentMode = "Create"
	render()
end)

amountBox:GetPropertyChangedSignal("Text"):Connect(updateCostPreview)
rewardBox:GetPropertyChangedSignal("Text"):Connect(updateCostPreview)

browseActionButton.MouseButton1Click:Connect(function()
	local selected = selectedBountyId and findBountyById(selectedBountyId) or nil
	if not selected then
		return
	end
	if selected.isOwn then
		BountyBoardEvent:FireServer({
			type = "CANCEL",
			bountyId = selected.id,
		})
		return
	end
	if not selected.canFulfill then
		setStatus("You do not have enough materials to complete that bounty.", false)
		render()
		return
	end
	BountyBoardEvent:FireServer({
		type = "FULFILL",
		bountyId = selected.id,
	})
end)

createActionButton.MouseButton1Click:Connect(function()
	local selected = selectedMaterialId and findMaterialById(selectedMaterialId) or nil
	if not selected then
		setStatus("Pick a material first.", false)
		render()
		return
	end

	local amount = math.floor(tonumber(amountBox.Text) or 0)
	local rewardPerUnit = math.floor(tonumber(rewardBox.Text) or 0)
	if amount < 1 or amount > 99 then
		setStatus(reasonText.BadAmount, false)
		render()
		return
	end
	if rewardPerUnit < 1 or rewardPerUnit > 50000 then
		setStatus(reasonText.BadReward, false)
		render()
		return
	end

	BountyBoardEvent:FireServer({
		type = "CREATE",
		materialId = selected.id,
		amount = amount,
		rewardPerUnit = rewardPerUnit,
	})
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui.Enabled then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		setVisible(false)
	end
end)

BountyBoardEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local payloadType = tostring(payload.type or "")
	if payloadType == "OPEN" then
		setVisible(true)
		BountyBoardEvent:FireServer({ type = "REQUEST_SYNC" })
		return
	end

	if payloadType == "SYNC" and typeof(payload.data) == "table" then
		snapshot = payload.data
		if typeof(snapshot.lastResult) == "table" then
			setStatusFromResult(snapshot.lastResult)
		end
		render()
	end
end)

render()
