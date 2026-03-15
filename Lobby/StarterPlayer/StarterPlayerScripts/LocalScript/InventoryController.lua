-- LOCALSCRIPT: InventoryController.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/InventoryController (LocalScript)
-- CO: UI ekwipunku lobby (layout mockup + styl gry)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local function waitForChild(parent, name, timeout)
	local found = parent:FindFirstChild(name)
	if found then
		return found
	end
	local start = os.clock()
	while os.clock() - start < (timeout or 5) do
		found = parent:FindFirstChild(name)
		if found then
			return found
		end
		task.wait(0.1)
	end
	return nil
end

local remoteEvents = waitForChild(ReplicatedStorage, "RemoteEvents", 5)
local PlayerProgressEvent = remoteEvents and waitForChild(remoteEvents, "PlayerProgressEvent", 5)
local InventoryAction = remoteEvents and remoteEvents:FindFirstChild("InventoryAction")

local remoteFunctions = waitForChild(ReplicatedStorage, "RemoteFunctions", 5)
local GetInventorySnapshot = remoteFunctions and remoteFunctions:FindFirstChild("RF_GetInventorySnapshot")

local function findModule(root, name)
	local direct = root:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	local moduleFolder = root:FindFirstChild("ModuleScripts")
		or root:FindFirstChild("ModuleScript")
	if moduleFolder then
		local nested = moduleFolder:FindFirstChild(name, true)
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end
	return nil
end

local WeaponConfigs = {}
do
	local module = findModule(ReplicatedStorage, "WeaponConfigs")
	if module then
		local ok, result = pcall(require, module)
		if ok and result then
			WeaponConfigs = result
		else
			warn("[InventoryController] Failed to load WeaponConfigs")
		end
	else
		warn("[InventoryController] Missing WeaponConfigs module")
	end
end

local Races = { Defs = {} }
do
	local module = findModule(ReplicatedStorage, "Races")
	if module then
		local ok, result = pcall(require, module)
		if ok and result then
			Races = result
		else
			warn("[InventoryController] Failed to load Races")
		end
	else
		warn("[InventoryController] Missing Races module")
	end
end

local CraftingConfig = {}
do
	local module = findModule(ReplicatedStorage, "CraftingConfig")
	if module then
		local ok, result = pcall(require, module)
		if ok and result then
			CraftingConfig = result
		else
			warn("[InventoryController] Failed to load CraftingConfig")
		end
	else
		warn("[InventoryController] Missing CraftingConfig module")
	end
end

local function hexToColor3(hex)
	hex = tostring(hex or "")
	hex = hex:gsub("#", "")
	if #hex ~= 6 then
		return Color3.fromRGB(255, 255, 255)
	end
	local r = tonumber(hex:sub(1, 2), 16) or 255
	local g = tonumber(hex:sub(3, 4), 16) or 255
	local b = tonumber(hex:sub(5, 6), 16) or 255
	return Color3.fromRGB(r, g, b)
end

local extraRarityColors = {
	Uncommon = "#73C991",
}

local function rarityColor(rarity)
	local key = tostring(rarity or "")
	local hex = (WeaponConfigs.RarityColors and WeaponConfigs.RarityColors[key]) or extraRarityColors[key]
	return hexToColor3(hex or "#B0B0B0")
end

local function blendColor(fromColor, toColor, alpha)
	return Color3.new(
		fromColor.R + (toColor.R - fromColor.R) * alpha,
		fromColor.G + (toColor.G - fromColor.G) * alpha,
		fromColor.B + (toColor.B - fromColor.B) * alpha
	)
end

local function addHover(frame, normalColor, hoverColor)
	frame.MouseEnter:Connect(function()
		TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverColor,
		}):Play()
	end)
	frame.MouseLeave:Connect(function()
		TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = normalColor,
		}):Play()
	end)
end

local inventoryGui = pg:WaitForChild("InventoryGui")
inventoryGui.Enabled = false
inventoryGui.ResetOnSpawn = false
inventoryGui.IgnoreGuiInset = true
inventoryGui:SetAttribute("Modal", true)

local overlay = inventoryGui:WaitForChild("overlay")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Parent = inventoryGui

local panel = overlay:WaitForChild("panel")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.9)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local panelSizeConstraint = Instance.new("UISizeConstraint", panel)
panelSizeConstraint.MaxSize = Vector2.new(1120, 620)
local panelAspect = Instance.new("UIAspectRatioConstraint", panel)
panelAspect.AspectRatio = 1120 / 620
panelAspect.DominantAxis = Enum.DominantAxis.Height
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(40, 40, 48)
panelStroke.Thickness = 1

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 16)
title.Size = UDim2.new(1, -80, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Inventory"
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
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)
addHover(closeBtn, closeBtn.BackgroundColor3, Color3.fromRGB(38, 38, 48))

local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(20, 56)
body.Size = UDim2.new(1, -40, 1, -76)
body.BackgroundTransparency = 1
body.Parent = panel

local bodyLayout = Instance.new("UIListLayout", body)
bodyLayout.FillDirection = Enum.FillDirection.Horizontal
bodyLayout.Padding = UDim.new(0, 16)

local leftColumn = Instance.new("Frame")
leftColumn.Size = UDim2.new(0, 320, 1, 0)
leftColumn.BackgroundTransparency = 1
leftColumn.Parent = body

local playerPanel = Instance.new("ScrollingFrame")
playerPanel.Position = UDim2.fromOffset(0, 0)
playerPanel.Size = UDim2.new(1, 0, 0, 242)
playerPanel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
playerPanel.BackgroundTransparency = 0.08
playerPanel.BorderSizePixel = 0
playerPanel.ScrollBarThickness = 6
playerPanel.CanvasSize = UDim2.fromOffset(0, 0)
playerPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerPanel.Parent = leftColumn
Instance.new("UICorner", playerPanel).CornerRadius = UDim.new(0, 12)
local playerPanelStroke = Instance.new("UIStroke", playerPanel)
playerPanelStroke.Color = Color3.fromRGB(48, 56, 72)
playerPanelStroke.Thickness = 1
local playerPad = Instance.new("UIPadding", playerPanel)
playerPad.PaddingTop = UDim.new(0, 16)
playerPad.PaddingBottom = UDim.new(0, 16)
playerPad.PaddingLeft = UDim.new(0, 16)
playerPad.PaddingRight = UDim.new(0, 16)
local playerLayout = Instance.new("UIListLayout", playerPanel)
playerLayout.Padding = UDim.new(0, 6)
playerLayout.SortOrder = Enum.SortOrder.LayoutOrder

local playerName = Instance.new("TextLabel")
playerName.BackgroundTransparency = 1
playerName.Size = UDim2.new(1, 0, 0, 20)
playerName.Font = Enum.Font.GothamBold
playerName.TextSize = 16
playerName.TextColor3 = Color3.fromRGB(240, 240, 240)
playerName.TextXAlignment = Enum.TextXAlignment.Left
playerName.LayoutOrder = 1
playerName.Text = "PlayerName - Lv. 1"
playerName.Parent = playerPanel

local expWrap = Instance.new("Frame")
expWrap.BackgroundTransparency = 1
expWrap.Size = UDim2.new(1, 0, 0, 26)
expWrap.LayoutOrder = 2
expWrap.Parent = playerPanel

local expLabel = Instance.new("TextLabel")
expLabel.BackgroundTransparency = 1
expLabel.Size = UDim2.new(1, 0, 0, 14)
expLabel.Font = Enum.Font.Gotham
expLabel.TextSize = 12
expLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
expLabel.TextXAlignment = Enum.TextXAlignment.Left
expLabel.Text = "EXP: 0/0"
expLabel.Parent = expWrap

local expBack = Instance.new("Frame")
expBack.Position = UDim2.fromOffset(0, 16)
expBack.Size = UDim2.new(1, 0, 0, 8)
expBack.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
expBack.BorderSizePixel = 0
expBack.Parent = expWrap
Instance.new("UICorner", expBack).CornerRadius = UDim.new(0, 999)

local expFill = Instance.new("Frame")
expFill.Size = UDim2.new(0, 0, 1, 0)
expFill.BackgroundColor3 = Color3.fromRGB(96, 165, 250)
expFill.BorderSizePixel = 0
expFill.Parent = expBack
Instance.new("UICorner", expFill).CornerRadius = UDim.new(0, 999)

local raceLabel = Instance.new("TextLabel")
raceLabel.BackgroundTransparency = 1
raceLabel.Size = UDim2.new(1, 0, 0, 16)
raceLabel.Font = Enum.Font.Gotham
raceLabel.TextSize = 13
raceLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
raceLabel.TextXAlignment = Enum.TextXAlignment.Left
raceLabel.LayoutOrder = 3
raceLabel.Text = "Race: -"
raceLabel.Parent = playerPanel

local statsList = Instance.new("Frame")
statsList.BackgroundTransparency = 1
statsList.Size = UDim2.new(1, 0, 0, 126)
statsList.LayoutOrder = 4
statsList.Parent = playerPanel
local statsLayout = Instance.new("UIListLayout", statsList)
statsLayout.Padding = UDim.new(0, 4)

local function makeStatRow(labelText)
	local row = Instance.new("TextLabel")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 14)
	row.Font = Enum.Font.Gotham
	row.TextSize = 12
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = Color3.fromRGB(200, 200, 200)
	row.Text = labelText
	row.Parent = statsList
	return row
end

local statRows = {
	HP = makeStatRow("HP: -"),
	ATK = makeStatRow("ATK: -"),
	DEF = makeStatRow("DEF: -"),
	LIFESTEAL = makeStatRow("Lifesteal: -"),
	CRIT_RATE = makeStatRow("Crit Rate: -"),
	CRIT_DMG = makeStatRow("Crit DMG: -"),
	SPEED = makeStatRow("Speed: -"),
}

local currenciesFrame = Instance.new("Frame")
currenciesFrame.BackgroundTransparency = 1
currenciesFrame.Size = UDim2.new(1, 0, 0, 34)
currenciesFrame.LayoutOrder = 5
currenciesFrame.Parent = playerPanel
currenciesFrame.LayoutOrder = 999

local coinsLabel = Instance.new("TextLabel")
coinsLabel.BackgroundTransparency = 1
coinsLabel.Size = UDim2.new(1, 0, 0, 16)
coinsLabel.Font = Enum.Font.Gotham
coinsLabel.TextSize = 13
coinsLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Text = "Silver: 0"
coinsLabel.Parent = currenciesFrame

local wpLabel = Instance.new("TextLabel")
wpLabel.BackgroundTransparency = 1
wpLabel.Position = UDim2.fromOffset(0, 18)
wpLabel.Size = UDim2.new(1, 0, 0, 16)
wpLabel.Font = Enum.Font.Gotham
wpLabel.TextSize = 12
wpLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
wpLabel.TextXAlignment = Enum.TextXAlignment.Left
wpLabel.Text = "WP: 0"
wpLabel.Parent = currenciesFrame

local equippedPanel = Instance.new("Frame")
equippedPanel.Position = UDim2.fromOffset(0, 256)
equippedPanel.Size = UDim2.new(1, 0, 1, -256)
equippedPanel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
equippedPanel.BackgroundTransparency = 0.08
equippedPanel.BorderSizePixel = 0
equippedPanel.Parent = leftColumn
Instance.new("UICorner", equippedPanel).CornerRadius = UDim.new(0, 12)
local equippedPanelStroke = Instance.new("UIStroke", equippedPanel)
equippedPanelStroke.Color = Color3.fromRGB(48, 56, 72)
equippedPanelStroke.Thickness = 1
local equippedAccent = Instance.new("Frame")
equippedAccent.Size = UDim2.new(1, 0, 0, 4)
equippedAccent.BackgroundColor3 = Color3.fromRGB(96, 165, 250)
equippedAccent.BorderSizePixel = 0
equippedAccent.Parent = equippedPanel
Instance.new("UICorner", equippedAccent).CornerRadius = UDim.new(0, 10)
local equippedPad = Instance.new("UIPadding", equippedPanel)
equippedPad.PaddingTop = UDim.new(0, 16)
equippedPad.PaddingBottom = UDim.new(0, 16)
equippedPad.PaddingLeft = UDim.new(0, 16)
equippedPad.PaddingRight = UDim.new(0, 16)

local equippedTitle = Instance.new("TextLabel")
equippedTitle.BackgroundTransparency = 1
equippedTitle.Size = UDim2.new(1, 0, 0, 18)
equippedTitle.Font = Enum.Font.GothamBold
equippedTitle.TextSize = 14
equippedTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
equippedTitle.TextXAlignment = Enum.TextXAlignment.Left
equippedTitle.Text = "Currently Equipped"
equippedTitle.Parent = equippedPanel

local equippedBody = Instance.new("Frame")
equippedBody.BackgroundTransparency = 1
equippedBody.Position = UDim2.fromOffset(0, 26)
equippedBody.Size = UDim2.new(1, 0, 1, -26)
equippedBody.Parent = equippedPanel

local equippedLayout = Instance.new("UIListLayout", equippedBody)
equippedLayout.Padding = UDim.new(0, 8)

local equippedIconFrame = Instance.new("Frame")
equippedIconFrame.Size = UDim2.fromOffset(72, 72)
equippedIconFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
equippedIconFrame.BorderSizePixel = 0
equippedIconFrame.Parent = equippedBody
Instance.new("UICorner", equippedIconFrame).CornerRadius = UDim.new(0, 12)
local equippedIconStroke = Instance.new("UIStroke", equippedIconFrame)
equippedIconStroke.Color = Color3.fromRGB(50, 50, 64)
equippedIconStroke.Thickness = 1

local equippedIconLabel = Instance.new("TextLabel")
equippedIconLabel.BackgroundTransparency = 1
equippedIconLabel.Size = UDim2.new(1, 0, 1, 0)
equippedIconLabel.Font = Enum.Font.GothamBold
equippedIconLabel.TextSize = 20
equippedIconLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
equippedIconLabel.Text = "?"
equippedIconLabel.Parent = equippedIconFrame

local equippedName = Instance.new("TextLabel")
equippedName.BackgroundTransparency = 1
equippedName.Size = UDim2.new(1, 0, 0, 20)
equippedName.Font = Enum.Font.GothamBold
equippedName.TextSize = 16
equippedName.TextColor3 = Color3.fromRGB(245, 245, 245)
equippedName.TextXAlignment = Enum.TextXAlignment.Left
equippedName.TextWrapped = true
equippedName.Text = "No weapon equipped"
equippedName.Parent = equippedBody

local equippedMeta = Instance.new("TextLabel")
equippedMeta.BackgroundTransparency = 1
equippedMeta.Size = UDim2.new(1, 0, 0, 18)
equippedMeta.Font = Enum.Font.Gotham
equippedMeta.TextSize = 12
equippedMeta.TextColor3 = Color3.fromRGB(200, 200, 200)
equippedMeta.TextXAlignment = Enum.TextXAlignment.Left
equippedMeta.Text = "Type: - | Rarity: -"
equippedMeta.Parent = equippedBody

local equippedStats = Instance.new("TextLabel")
equippedStats.BackgroundTransparency = 1
equippedStats.Size = UDim2.new(1, 0, 0, 18)
equippedStats.Font = Enum.Font.Gotham
equippedStats.TextSize = 12
equippedStats.TextColor3 = Color3.fromRGB(200, 200, 200)
equippedStats.TextXAlignment = Enum.TextXAlignment.Left
equippedStats.Text = "Level: - | ATK: -"
equippedStats.Parent = equippedBody

local equippedBonus = Instance.new("TextLabel")
equippedBonus.BackgroundTransparency = 1
equippedBonus.Size = UDim2.new(1, 0, 0, 32)
equippedBonus.Font = Enum.Font.Gotham
equippedBonus.TextSize = 12
equippedBonus.TextColor3 = Color3.fromRGB(190, 190, 190)
equippedBonus.TextXAlignment = Enum.TextXAlignment.Left
equippedBonus.TextWrapped = true
equippedBonus.Text = "Bonus Stats: -"
equippedBonus.Parent = equippedBody

local equippedPassive = Instance.new("TextLabel")
equippedPassive.BackgroundTransparency = 1
equippedPassive.Size = UDim2.new(1, 0, 0, 36)
equippedPassive.Font = Enum.Font.Gotham
equippedPassive.TextSize = 12
equippedPassive.TextColor3 = Color3.fromRGB(190, 190, 190)
equippedPassive.TextXAlignment = Enum.TextXAlignment.Left
equippedPassive.TextWrapped = true
equippedPassive.Text = "Passive/Ability: -"
equippedPassive.Parent = equippedBody

local rightColumn = Instance.new("Frame")
rightColumn.Size = UDim2.new(1, -336, 1, 0)
rightColumn.BackgroundTransparency = 1
rightColumn.Parent = body

local rightLayout = Instance.new("UIListLayout", rightColumn)
rightLayout.FillDirection = Enum.FillDirection.Vertical
rightLayout.Padding = UDim.new(0, 16)

local summaryStrip = Instance.new("Frame")
summaryStrip.Size = UDim2.new(1, 0, 0, 136)
summaryStrip.BackgroundTransparency = 1
summaryStrip.Parent = rightColumn

local summaryLayout = Instance.new("UIListLayout", summaryStrip)
summaryLayout.FillDirection = Enum.FillDirection.Horizontal
summaryLayout.Padding = UDim.new(0, 8)
summaryLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function createSummaryCard(titleText, subtitleText)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(171, 136)
	card.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Parent = summaryStrip
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke", card)
	stroke.Color = Color3.fromRGB(48, 56, 72)
	stroke.Thickness = 1

	local pad = Instance.new("UIPadding", card)
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 18)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 13
	titleLabel.TextColor3 = Color3.fromRGB(235, 239, 246)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = titleText
	titleLabel.Parent = card

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.fromOffset(0, 20)
	subtitleLabel.Size = UDim2.new(1, 0, 0, 14)
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextSize = 11
	subtitleLabel.TextColor3 = Color3.fromRGB(154, 165, 184)
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.Text = subtitleText
	subtitleLabel.Parent = card

	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, 42)
	body.Size = UDim2.new(1, 0, 1, -42)
	body.Parent = card

	local bodyLayout = Instance.new("UIListLayout", body)
	bodyLayout.Padding = UDim.new(0, 5)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder

	return card, stroke, subtitleLabel, body
end

local walletCard, walletStroke, walletSubtitle, walletBody = createSummaryCard("Wallet", "Lobby balances")
local mineCard, mineStroke, mineSubtitle, mineBody = createSummaryCard("Mine Cache", "Owned ore and minerals")
local mobCard, mobStroke, mobSubtitle, mobBody = createSummaryCard("Monster Loot", "Materials from enemies")
local upgradeCard, upgradeStroke, upgradeSubtitle, upgradeBody = createSummaryCard("Forge Stock", "Upgrade materials")

walletStroke.Color = Color3.fromRGB(94, 167, 255)
mineStroke.Color = Color3.fromRGB(88, 196, 139)
mobStroke.Color = Color3.fromRGB(233, 174, 94)
upgradeStroke.Color = Color3.fromRGB(176, 135, 255)

local inventorySection = Instance.new("Frame")
inventorySection.Size = UDim2.new(1, 0, 1, -152)
inventorySection.BackgroundTransparency = 1
inventorySection.Parent = rightColumn

local inventorySectionLayout = Instance.new("UIListLayout", inventorySection)
inventorySectionLayout.FillDirection = Enum.FillDirection.Horizontal
inventorySectionLayout.Padding = UDim.new(0, 16)
inventorySectionLayout.SortOrder = Enum.SortOrder.LayoutOrder

local gridPanel = Instance.new("Frame")
gridPanel.Size = UDim2.new(0.62, -8, 1, 0)
gridPanel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
gridPanel.BackgroundTransparency = 0.08
gridPanel.BorderSizePixel = 0
gridPanel.Parent = inventorySection
Instance.new("UICorner", gridPanel).CornerRadius = UDim.new(0, 12)
local gridPanelStroke = Instance.new("UIStroke", gridPanel)
gridPanelStroke.Color = Color3.fromRGB(48, 56, 72)
gridPanelStroke.Thickness = 1
local gridPad = Instance.new("UIPadding", gridPanel)
gridPad.PaddingTop = UDim.new(0, 16)
gridPad.PaddingBottom = UDim.new(0, 16)
gridPad.PaddingLeft = UDim.new(0, 16)
gridPad.PaddingRight = UDim.new(0, 16)

local gridTitle = Instance.new("TextLabel")
gridTitle.BackgroundTransparency = 1
gridTitle.Size = UDim2.new(1, -120, 0, 20)
gridTitle.Font = Enum.Font.GothamBold
gridTitle.TextSize = 16
gridTitle.TextColor3 = Color3.fromRGB(235, 239, 246)
gridTitle.TextXAlignment = Enum.TextXAlignment.Left
gridTitle.Text = "Weapons"
gridTitle.Parent = gridPanel

local gridCountLabel = Instance.new("TextLabel")
gridCountLabel.AnchorPoint = Vector2.new(1, 0)
gridCountLabel.Position = UDim2.new(1, 0, 0, 2)
gridCountLabel.Size = UDim2.fromOffset(110, 16)
gridCountLabel.BackgroundTransparency = 1
gridCountLabel.Font = Enum.Font.Gotham
gridCountLabel.TextSize = 11
gridCountLabel.TextColor3 = Color3.fromRGB(154, 165, 184)
gridCountLabel.TextXAlignment = Enum.TextXAlignment.Right
gridCountLabel.Text = "0 collected"
gridCountLabel.Parent = gridPanel

local slotsFrame = Instance.new("ScrollingFrame")
slotsFrame.BackgroundTransparency = 1
slotsFrame.Position = UDim2.fromOffset(0, 38)
slotsFrame.Size = UDim2.new(1, 0, 1, -38)
slotsFrame.ScrollBarThickness = 6
slotsFrame.BorderSizePixel = 0
slotsFrame.CanvasSize = UDim2.fromOffset(0, 0)
slotsFrame.Parent = gridPanel

local slotsLayout = Instance.new("UIGridLayout", slotsFrame)
slotsLayout.CellPadding = UDim2.fromOffset(12, 12)
slotsLayout.CellSize = UDim2.fromOffset(126, 144)
slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local emptyLabel = Instance.new("TextLabel")
emptyLabel.BackgroundTransparency = 1
emptyLabel.Position = UDim2.fromOffset(0, 38)
emptyLabel.Size = UDim2.new(1, 0, 1, -38)
emptyLabel.Font = Enum.Font.Gotham
emptyLabel.TextSize = 14
emptyLabel.TextColor3 = Color3.fromRGB(160, 170, 188)
emptyLabel.Text = "No weapons yet."
emptyLabel.TextWrapped = true
emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
emptyLabel.TextYAlignment = Enum.TextYAlignment.Center
emptyLabel.Visible = false
emptyLabel.Parent = gridPanel

local detailsPanel = Instance.new("Frame")
detailsPanel.Size = UDim2.new(0.38, -8, 1, 0)
detailsPanel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
detailsPanel.BackgroundTransparency = 0.08
detailsPanel.BorderSizePixel = 0
detailsPanel.Parent = inventorySection
Instance.new("UICorner", detailsPanel).CornerRadius = UDim.new(0, 12)
local detailsPanelStroke = Instance.new("UIStroke", detailsPanel)
detailsPanelStroke.Color = Color3.fromRGB(48, 56, 72)
detailsPanelStroke.Thickness = 1
local detailsAccent = Instance.new("Frame")
detailsAccent.Size = UDim2.new(1, 0, 0, 4)
detailsAccent.BackgroundColor3 = Color3.fromRGB(96, 165, 250)
detailsAccent.BorderSizePixel = 0
detailsAccent.Parent = detailsPanel
Instance.new("UICorner", detailsAccent).CornerRadius = UDim.new(0, 10)
local detailsPad = Instance.new("UIPadding", detailsPanel)
detailsPad.PaddingTop = UDim.new(0, 16)
detailsPad.PaddingBottom = UDim.new(0, 16)
detailsPad.PaddingLeft = UDim.new(0, 16)
detailsPad.PaddingRight = UDim.new(0, 16)

local detailsTitle = Instance.new("TextLabel")
detailsTitle.BackgroundTransparency = 1
detailsTitle.Size = UDim2.new(1, 0, 0, 18)
detailsTitle.Font = Enum.Font.GothamBold
detailsTitle.TextSize = 14
detailsTitle.TextColor3 = Color3.fromRGB(235, 239, 246)
detailsTitle.TextXAlignment = Enum.TextXAlignment.Left
detailsTitle.Text = "Weapon Details"
detailsTitle.Parent = detailsPanel

local detailsScroll = Instance.new("ScrollingFrame")
detailsScroll.BackgroundTransparency = 1
detailsScroll.Position = UDim2.fromOffset(0, 26)
detailsScroll.Size = UDim2.new(1, 0, 1, -26)
detailsScroll.ScrollBarThickness = 6
detailsScroll.BorderSizePixel = 0
detailsScroll.CanvasSize = UDim2.fromOffset(0, 0)
detailsScroll.Parent = detailsPanel

local detailsLayout = Instance.new("UIListLayout", detailsScroll)
detailsLayout.Padding = UDim.new(0, 8)

local iconFrame = Instance.new("Frame")
iconFrame.Size = UDim2.fromOffset(72, 72)
iconFrame.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
iconFrame.BorderSizePixel = 0
iconFrame.Parent = detailsScroll
Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 12)
local iconStroke = Instance.new("UIStroke", iconFrame)
iconStroke.Color = Color3.fromRGB(50, 50, 64)
iconStroke.Thickness = 1

local iconLabel = Instance.new("TextLabel")
iconLabel.BackgroundTransparency = 1
iconLabel.Size = UDim2.new(1, 0, 1, 0)
iconLabel.Font = Enum.Font.GothamBold
iconLabel.TextSize = 20
iconLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
iconLabel.Text = "?"
iconLabel.Parent = iconFrame

local itemName = Instance.new("TextLabel")
itemName.BackgroundTransparency = 1
itemName.Size = UDim2.new(1, 0, 0, 20)
itemName.Font = Enum.Font.GothamBold
itemName.TextSize = 16
itemName.TextColor3 = Color3.fromRGB(245, 245, 245)
itemName.TextXAlignment = Enum.TextXAlignment.Left
itemName.TextWrapped = true
itemName.Text = "Select a weapon"
itemName.Parent = detailsScroll

local itemDesc = Instance.new("TextLabel")
itemDesc.BackgroundTransparency = 1
itemDesc.Size = UDim2.new(1, 0, 0, 34)
itemDesc.Font = Enum.Font.Gotham
itemDesc.TextSize = 12
itemDesc.TextColor3 = Color3.fromRGB(190, 190, 190)
itemDesc.TextXAlignment = Enum.TextXAlignment.Left
itemDesc.TextWrapped = true
itemDesc.Text = "Pick a weapon slot to see its details."
itemDesc.Parent = detailsScroll

local infoLine = Instance.new("TextLabel")
infoLine.BackgroundTransparency = 1
infoLine.Size = UDim2.new(1, 0, 0, 18)
infoLine.Font = Enum.Font.Gotham
infoLine.TextSize = 12
infoLine.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLine.TextXAlignment = Enum.TextXAlignment.Left
infoLine.Text = "Type: - | Rarity: -"
infoLine.Parent = detailsScroll

local statLine = Instance.new("TextLabel")
statLine.BackgroundTransparency = 1
statLine.Size = UDim2.new(1, 0, 0, 18)
statLine.Font = Enum.Font.Gotham
statLine.TextSize = 12
statLine.TextColor3 = Color3.fromRGB(200, 200, 200)
statLine.TextXAlignment = Enum.TextXAlignment.Left
statLine.Text = "Max Level: - | ATK: -"
statLine.Parent = detailsScroll

local bonusStats = Instance.new("TextLabel")
bonusStats.BackgroundTransparency = 1
bonusStats.Size = UDim2.new(1, 0, 0, 34)
bonusStats.Font = Enum.Font.Gotham
bonusStats.TextSize = 12
bonusStats.TextColor3 = Color3.fromRGB(190, 190, 190)
bonusStats.TextXAlignment = Enum.TextXAlignment.Left
bonusStats.TextWrapped = true
bonusStats.Text = "Bonus Stats: -"
bonusStats.Parent = detailsScroll

local passiveTitle = Instance.new("TextLabel")
passiveTitle.BackgroundTransparency = 1
passiveTitle.Size = UDim2.new(1, 0, 0, 16)
passiveTitle.Font = Enum.Font.GothamBold
passiveTitle.TextSize = 12
passiveTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
passiveTitle.TextXAlignment = Enum.TextXAlignment.Left
passiveTitle.Text = "Passive"
passiveTitle.Parent = detailsScroll

local passiveDesc = Instance.new("TextLabel")
passiveDesc.BackgroundTransparency = 1
passiveDesc.Size = UDim2.new(1, 0, 0, 40)
passiveDesc.Font = Enum.Font.Gotham
passiveDesc.TextSize = 12
passiveDesc.TextColor3 = Color3.fromRGB(190, 190, 190)
passiveDesc.TextXAlignment = Enum.TextXAlignment.Left
passiveDesc.TextWrapped = true
passiveDesc.Text = "-"
passiveDesc.Parent = detailsScroll

local abilityTitle = Instance.new("TextLabel")
abilityTitle.BackgroundTransparency = 1
abilityTitle.Size = UDim2.new(1, 0, 0, 16)
abilityTitle.Font = Enum.Font.GothamBold
abilityTitle.TextSize = 12
abilityTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
abilityTitle.TextXAlignment = Enum.TextXAlignment.Left
abilityTitle.Text = "Ability"
abilityTitle.Parent = detailsScroll

local abilityDesc = Instance.new("TextLabel")
abilityDesc.BackgroundTransparency = 1
abilityDesc.Size = UDim2.new(1, 0, 0, 40)
abilityDesc.Font = Enum.Font.Gotham
abilityDesc.TextSize = 12
abilityDesc.TextColor3 = Color3.fromRGB(190, 190, 190)
abilityDesc.TextXAlignment = Enum.TextXAlignment.Left
abilityDesc.TextWrapped = true
abilityDesc.Text = "-"
abilityDesc.Parent = detailsScroll

local function updateDetailsCanvas()
	task.defer(function()
		detailsScroll.CanvasSize = UDim2.fromOffset(0, detailsLayout.AbsoluteContentSize.Y + 8)
	end)
end

updateDetailsCanvas()

local infoOverlay = Instance.new("Frame")
infoOverlay.Size = UDim2.fromScale(1, 1)
infoOverlay.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
infoOverlay.BackgroundTransparency = 0.35
infoOverlay.BorderSizePixel = 0
infoOverlay.Visible = false
infoOverlay.Parent = inventoryGui

local infoPanel = Instance.new("Frame")
infoPanel.AnchorPoint = Vector2.new(0.5, 0.5)
infoPanel.Position = UDim2.fromScale(0.5, 0.5)
infoPanel.Size = UDim2.fromOffset(420, 240)
infoPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
infoPanel.BackgroundTransparency = 0.06
infoPanel.BorderSizePixel = 0
infoPanel.Parent = infoOverlay
Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 14)
local infoStroke = Instance.new("UIStroke", infoPanel)
infoStroke.Color = Color3.fromRGB(40, 40, 48)
infoStroke.Thickness = 1

local infoTitle = Instance.new("TextLabel")
infoTitle.BackgroundTransparency = 1
infoTitle.Position = UDim2.fromOffset(20, 16)
infoTitle.Size = UDim2.new(1, -40, 0, 18)
infoTitle.Font = Enum.Font.GothamBold
infoTitle.TextSize = 14
infoTitle.TextColor3 = Color3.fromRGB(235, 235, 235)
infoTitle.TextXAlignment = Enum.TextXAlignment.Left
infoTitle.Text = "Weapon Info"
infoTitle.Parent = infoPanel

local infoBody = Instance.new("TextLabel")
infoBody.BackgroundTransparency = 1
infoBody.Position = UDim2.fromOffset(20, 44)
infoBody.Size = UDim2.new(1, -40, 1, -88)
infoBody.Font = Enum.Font.Gotham
infoBody.TextSize = 12
infoBody.TextColor3 = Color3.fromRGB(200, 200, 200)
infoBody.TextXAlignment = Enum.TextXAlignment.Left
infoBody.TextYAlignment = Enum.TextYAlignment.Top
infoBody.TextWrapped = true
infoBody.Text = "-"
infoBody.Parent = infoPanel

local infoClose = Instance.new("TextButton")
infoClose.AnchorPoint = Vector2.new(1, 0)
infoClose.Position = UDim2.new(1, -16, 0, 16)
infoClose.Size = UDim2.fromOffset(28, 28)
infoClose.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
infoClose.BorderSizePixel = 0
infoClose.Font = Enum.Font.GothamBold
infoClose.TextSize = 12
infoClose.TextColor3 = Color3.fromRGB(230, 230, 230)
infoClose.Text = "X"
infoClose.Parent = infoPanel
Instance.new("UICorner", infoClose).CornerRadius = UDim.new(0, 10)
addHover(infoClose, infoClose.BackgroundColor3, Color3.fromRGB(52, 52, 66))

infoClose.MouseButton1Click:Connect(function()
	infoOverlay.Visible = false
end)

local contextMenu = Instance.new("Frame")
contextMenu.Size = UDim2.fromOffset(150, 190)
contextMenu.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
contextMenu.BackgroundTransparency = 0.06
contextMenu.BorderSizePixel = 0
contextMenu.Visible = false
contextMenu.Parent = inventoryGui
Instance.new("UICorner", contextMenu).CornerRadius = UDim.new(0, 10)
local contextStroke = Instance.new("UIStroke", contextMenu)
contextStroke.Color = Color3.fromRGB(50, 50, 64)
contextStroke.Thickness = 1

local contextLayout = Instance.new("UIListLayout", contextMenu)
contextLayout.Padding = UDim.new(0, 6)
local contextPad = Instance.new("UIPadding", contextMenu)
contextPad.PaddingTop = UDim.new(0, 6)
contextPad.PaddingBottom = UDim.new(0, 6)
contextPad.PaddingLeft = UDim.new(0, 6)
contextPad.PaddingRight = UDim.new(0, 6)

local function makeContextButton(label)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, -12, 0, 28)
	button.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(230, 230, 230)
	button.Text = label
	button.Parent = contextMenu
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	addHover(button, button.BackgroundColor3, Color3.fromRGB(40, 40, 52))
	return button
end

local equipBtn = makeContextButton("Equip")
local sellBtn = makeContextButton("Sell")
local upgradeBtn = makeContextButton("Upgrade")
local favoriteBtn = makeContextButton("Favorite")
local infoBtn = makeContextButton("Weapon Info")

local inventoryItems = {}
local selectedIndex
local equippedWeaponId
local contextIndex
local weaponPoints = 0
local souls = 0
local tickets = 0
local inventoryResources = {
	mineResources = {},
	mobMaterials = {},
	upgradeMaterials = {},
}
local level, xp, nextXp, coins = 1, 0, 120, 0

local resourceMetaById = {}
for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS or {}) do
	if typeof(def) == "table" and typeof(def.id) == "string" then
		resourceMetaById[def.id] = {
			rarity = def.rarity,
		}
	end
end

for _, def in ipairs(CraftingConfig.MOB_MATERIAL_DEFS or {}) do
	if typeof(def) == "table" and typeof(def.id) == "string" then
		resourceMetaById[def.id] = resourceMetaById[def.id] or {}
	end
end

resourceMetaById[CraftingConfig.UPGRADE_CRYSTAL_ID or "Upgrade Crystal"] = { rarity = "Rare" }
resourceMetaById[CraftingConfig.ELITE_SPECIAL_ID or "Elite Sigil"] = { rarity = "Epic" }
resourceMetaById[CraftingConfig.BOSS_SPECIAL_ID or "Boss Core"] = { rarity = "Legendary" }

local function clearTextRows(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function addCardRow(container, order, text, color)
	local row = Instance.new("TextLabel")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 16)
	row.Font = Enum.Font.Gotham
	row.TextSize = 11
	row.TextColor3 = color or Color3.fromRGB(220, 226, 238)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextWrapped = false
	row.LayoutOrder = order
	row.Text = text
	row.Parent = container
	return row
end

local function getResourceColor(resourceId, fallbackColor)
	local meta = resourceMetaById[resourceId]
	if meta and meta.rarity then
		return rarityColor(meta.rarity)
	end
	return fallbackColor or Color3.fromRGB(220, 226, 238)
end

local function totalAmount(entries)
	local total = 0
	for _, entry in ipairs(entries or {}) do
		total += math.max(0, math.floor(tonumber(entry.amount) or 0))
	end
	return total
end

local function renderEntryCard(body, subtitleLabel, entries, emptyText, fallbackColor)
	clearTextRows(body)

	if typeof(entries) ~= "table" or #entries == 0 then
		subtitleLabel.Text = "Nothing stored"
		addCardRow(body, 1, emptyText, Color3.fromRGB(145, 153, 171))
		return
	end

	subtitleLabel.Text = ("%d types | %d total"):format(#entries, totalAmount(entries))
	local limit = 4
	for index = 1, math.min(#entries, limit) do
		local entry = entries[index]
		addCardRow(
			body,
			index,
			("%s x%d"):format(tostring(entry.id or "?"), math.max(0, math.floor(tonumber(entry.amount) or 0))),
			getResourceColor(entry.id, fallbackColor)
		)
	end
	if #entries > limit then
		addCardRow(body, limit + 1, ("+%d more types"):format(#entries - limit), Color3.fromRGB(154, 165, 184))
	end
end

local function renderWalletCard()
	clearTextRows(walletBody)
	walletSubtitle.Text = "Lobby balances"
	addCardRow(walletBody, 1, ("Silver: %d"):format(coins), Color3.fromRGB(242, 198, 92))
	addCardRow(walletBody, 2, ("Souls: %d"):format(souls), Color3.fromRGB(134, 164, 255))
	addCardRow(walletBody, 3, ("WP: %d"):format(weaponPoints), Color3.fromRGB(111, 218, 255))
	addCardRow(walletBody, 4, ("Tickets: %d"):format(tickets), Color3.fromRGB(226, 232, 242))
end

local function renderResourceCards()
	renderWalletCard()
	renderEntryCard(mineBody, mineSubtitle, inventoryResources.mineResources, "No ore or crystals", Color3.fromRGB(88, 196, 139))
	renderEntryCard(mobBody, mobSubtitle, inventoryResources.mobMaterials, "No monster materials", Color3.fromRGB(233, 174, 94))
	renderEntryCard(upgradeBody, upgradeSubtitle, inventoryResources.upgradeMaterials, "No upgrade stock", Color3.fromRGB(176, 135, 255))
end

local function formatStats(stats)
	if typeof(stats) ~= "table" then
		return "Bonus Stats: -"
	end
	local parts = {}
	if stats.HP and stats.HP ~= 0 then
		table.insert(parts, ("HP %+d"):format(stats.HP))
	end
	if stats.ATK and stats.ATK ~= 0 then
		table.insert(parts, ("ATK %+d"):format(stats.ATK))
	end
	if stats.DEF and stats.DEF ~= 0 then
		table.insert(parts, ("DEF %+d"):format(stats.DEF))
	end
	if stats.LIFESTEAL and stats.LIFESTEAL ~= 0 then
		table.insert(parts, ("Life Steal %+d%%"):format(stats.LIFESTEAL))
	end
	if stats.CRIT_RATE and stats.CRIT_RATE ~= 0 then
		table.insert(parts, ("Crit Rate %+d%%"):format(stats.CRIT_RATE))
	end
	if stats.CRIT_DMG and stats.CRIT_DMG ~= 0 then
		table.insert(parts, ("Crit DMG %+d%%"):format(stats.CRIT_DMG))
	end
	if stats.SPD and stats.SPD ~= 0 then
		table.insert(parts, ("Speed %+d%%"):format(stats.SPD))
	end
	if #parts == 0 then
		return "Bonus Stats: -"
	end
	return "Bonus Stats: " .. table.concat(parts, " | ")
end

local function formatStatsShort(stats)
	if typeof(stats) ~= "table" then
		return "Bonus Stats: -"
	end
	local parts = {}
	if stats.HP and stats.HP ~= 0 then
		table.insert(parts, ("HP %+d"):format(stats.HP))
	end
	if stats.DEF and stats.DEF ~= 0 then
		table.insert(parts, ("DEF %+d"):format(stats.DEF))
	end
	if stats.CRIT_RATE and stats.CRIT_RATE ~= 0 then
		table.insert(parts, ("Crit %+d%%"):format(stats.CRIT_RATE))
	end
	if stats.CRIT_DMG and stats.CRIT_DMG ~= 0 then
		table.insert(parts, ("Crit DMG %+d%%"):format(stats.CRIT_DMG))
	end
	if stats.LIFESTEAL and stats.LIFESTEAL ~= 0 then
		table.insert(parts, ("LS %+d%%"):format(stats.LIFESTEAL))
	end
	if stats.SPD and stats.SPD ~= 0 then
		table.insert(parts, ("SPD %+d%%"):format(stats.SPD))
	end
	if #parts == 0 then
		return "Bonus Stats: -"
	end
	return "Bonus Stats: " .. table.concat(parts, " | ")
end

local function refreshFinalStats(raceName)
	local raceDef = Races.Defs and Races.Defs[raceName or ""]
	local raceStats = raceDef and raceDef.stats or {}
	local equippedItem
	if equippedWeaponId then
		for _, it in ipairs(inventoryItems) do
			if it.id == equippedWeaponId then
				equippedItem = it
				break
			end
		end
	end
	local weaponDef = equippedItem and equippedItem.def or nil
	local weaponStats = (equippedItem and equippedItem.stats) or (weaponDef and weaponDef.stats) or {}
	local weaponATK = (equippedItem and equippedItem.stats and equippedItem.stats.ATK) or (weaponDef and weaponDef.baseDamage) or 0

	local function getRaceStat(key)
		return tonumber(raceStats[key]) or 0
	end

	local function getWeaponStat(key)
		return tonumber(weaponStats[key]) or 0
	end

	local hp = getRaceStat("HP") + getWeaponStat("HP")
	local atk = weaponATK
		+ getRaceStat("PhysicalPower")
		+ getRaceStat("MagicPower")
		+ getRaceStat("STR")
	local def = getRaceStat("Armor") + getWeaponStat("DEF")
	local lifesteal = getRaceStat("LifeSteal") + getWeaponStat("LIFESTEAL")
	local critRate = getRaceStat("CritChance") + getWeaponStat("CRIT_RATE")
	local critDmg = getRaceStat("CritDmg") + getWeaponStat("CRIT_DMG")
	local speed = getRaceStat("MoveSpeed") + getWeaponStat("SPD")

	statRows.HP.Text = ("HP: %d"):format(hp)
	statRows.ATK.Text = ("ATK: %d"):format(atk)
	statRows.DEF.Text = ("DEF: %d"):format(def)
	statRows.LIFESTEAL.Text = ("Lifesteal: %d%%"):format(lifesteal)
	statRows.CRIT_RATE.Text = ("Crit Rate: %d%%"):format(critRate)
	statRows.CRIT_DMG.Text = ("Crit DMG: %d%%"):format(critDmg)
	statRows.SPEED.Text = ("Speed: %d%%"):format(speed)
end

local function updatePlayerInfo()
	playerName.Text = ("%s - Lv. %d"):format(plr.Name, level)
	expLabel.Text = ("EXP: %d/%d"):format(xp, math.max(1, nextXp))
	local pct = math.clamp(xp / math.max(1, nextXp), 0, 1)
	TweenService:Create(expFill, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(pct, 0, 1, 0),
	}):Play()
	local raceName = tostring(plr:GetAttribute("Race") or "-")
	raceLabel.Text = ("Race: %s"):format(raceName)
	refreshFinalStats(raceName)
	coinsLabel.Text = ("Silver: %d | Souls: %d"):format(coins, souls)
	wpLabel.Text = ("WP: %d | Tickets: %d"):format(weaponPoints, tickets)
	renderResourceCards()
end


local function applyEquipped(item)
	if not item or not item.def then
		equippedName.Text = "No weapon equipped"
		equippedName.TextColor3 = Color3.fromRGB(245, 245, 245)
		equippedMeta.Text = "Type: - | Rarity: -"
		equippedMeta.TextColor3 = Color3.fromRGB(200, 200, 200)
		equippedStats.Text = "Level: - | ATK: -"
		equippedBonus.Text = "Bonus Stats: -"
		equippedPassive.Text = "Passive/Ability: -"
		equippedIconLabel.Text = "?"
		equippedIconStroke.Color = Color3.fromRGB(50, 50, 64)
		equippedIconFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		equippedPanelStroke.Color = Color3.fromRGB(48, 56, 72)
		equippedAccent.BackgroundColor3 = Color3.fromRGB(96, 165, 250)
		return
	end

	local def = item.def
	local rarity = item.rarity or def.rarity or "Common"
	local color = rarityColor(rarity)
	equippedName.Text = item.displayName or def.name or def.id or "Unknown"
	equippedName.TextColor3 = color
	equippedMeta.Text = ("Type: %s | Rarity: %s"):format(def.weaponType or "-", rarity)
	equippedMeta.TextColor3 = color
	local lvl = tonumber(item.level) or 1
	local maxLvl = tonumber(item.maxLevel) or def.maxLevel or "-"
	local atk = (item.stats and item.stats.ATK) or def.baseDamage or "-"
	equippedStats.Text = ("Level: %s/%s | ATK: %s"):format(tostring(lvl), tostring(maxLvl), tostring(atk))
	equippedBonus.Text = formatStatsShort(item.stats or def.stats)

	local passiveText = def.passiveName or ""
	local abilityText = def.abilityName or ""
	if passiveText == "" and abilityText == "" then
		equippedPassive.Text = "Passive/Ability: -"
	else
		local summary = passiveText ~= "" and passiveText or abilityText
		equippedPassive.Text = ("Passive/Ability: %s"):format(summary)
	end

	equippedIconLabel.Text = def.weaponType and def.weaponType:sub(1, 1) or "?"
	equippedIconStroke.Color = color
	equippedIconFrame.BackgroundColor3 = blendColor(Color3.fromRGB(26, 30, 40), color, 0.18)
	equippedPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), color, 0.45)
	equippedAccent.BackgroundColor3 = color
end

local function refreshEquippedPanel()
	local equippedItem
	if equippedWeaponId then
		for _, it in ipairs(inventoryItems) do
			if it.id == equippedWeaponId then
				equippedItem = it
				break
			end
		end
	end
	applyEquipped(equippedItem)
	updatePlayerInfo()
end

local function applyDetails(item)
	if not item or not item.def then
		itemName.Text = "Select a weapon"
		itemName.TextColor3 = Color3.fromRGB(245, 245, 245)
		itemDesc.Text = "Pick a weapon slot to see its details."
		infoLine.Text = "Type: - | Rarity: -"
		infoLine.TextColor3 = Color3.fromRGB(200, 200, 200)
		statLine.Text = "Max Level: - | ATK: -"
		bonusStats.Text = "Bonus Stats: -"
		passiveTitle.Text = "Passive"
		passiveDesc.Text = "-"
		abilityTitle.Text = "Ability"
		abilityDesc.Text = "-"
		iconLabel.Text = "?"
		iconFrame.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
		iconStroke.Color = Color3.fromRGB(50, 50, 64)
		detailsPanelStroke.Color = Color3.fromRGB(48, 56, 72)
		detailsAccent.BackgroundColor3 = Color3.fromRGB(96, 165, 250)
		updateDetailsCanvas()
		return
	end

	local def = item.def
	local rarity = item.rarity or def.rarity or "Common"
	local color = rarityColor(rarity)
	itemName.Text = item.displayName or def.name or def.id or "Unknown"
	itemName.TextColor3 = color

	local description = def.description or def.passiveDescription or def.abilityDescription or "No description."
	itemDesc.Text = description
	infoLine.Text = ("Type: %s | Rarity: %s"):format(def.weaponType or "-", rarity)
	infoLine.TextColor3 = color
	local lvl = tonumber(item.level) or 1
	local maxLvl = tonumber(item.maxLevel) or def.maxLevel or "-"
	local atk = (item.stats and item.stats.ATK) or def.baseDamage or "-"
	statLine.Text = ("Level: %s/%s | ATK: %s"):format(tostring(lvl), tostring(maxLvl), tostring(atk))
	bonusStats.Text = formatStats(item.stats or def.stats)

	local passiveName = def.passiveName or ""
	if passiveName ~= "" then
		passiveTitle.Text = ("Passive: %s"):format(passiveName)
		passiveDesc.Text = def.passiveDescription or "-"
	else
		passiveTitle.Text = "Passive"
		passiveDesc.Text = "-"
	end

	local abilityName = def.abilityName or ""
	if abilityName ~= "" then
		abilityTitle.Text = ("Ability: %s"):format(abilityName)
		abilityDesc.Text = def.abilityDescription or "-"
	else
		abilityTitle.Text = "Ability"
		abilityDesc.Text = "-"
	end

	local iconText = def.weaponType and def.weaponType:sub(1, 1) or "?"
	iconLabel.Text = iconText
	iconFrame.BackgroundColor3 = blendColor(Color3.fromRGB(26, 30, 40), color, 0.18)
	iconStroke.Color = color
	detailsPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), color, 0.45)
	detailsAccent.BackgroundColor3 = color

	updateDetailsCanvas()
end

local function hideContextMenu()
	contextMenu.Visible = false
	contextIndex = nil
end

local function showInfoPopup(def)
	if not def then
		return
	end
	infoTitle.Text = def.name or "Weapon Info"
	local parts = {}
	if def.passiveName and def.passiveName ~= "" then
		table.insert(parts, ("Passive: %s\n%s"):format(def.passiveName, def.passiveDescription or "-"))
	end
	if def.abilityName and def.abilityName ~= "" then
		table.insert(parts, ("Ability: %s\n%s"):format(def.abilityName, def.abilityDescription or "-"))
	end
	if #parts == 0 then
		infoBody.Text = "No passive or ability details."
	else
		infoBody.Text = table.concat(parts, "\n\n")
	end
	infoOverlay.Visible = true
end

local function showContextMenu(index, screenPos)
	contextIndex = index
	local item = inventoryItems[index]
	if not item then
		return
	end
	favoriteBtn.Text = item.favorite and "Unfavorite" or "Favorite"

	local menuSize = contextMenu.AbsoluteSize
	local x = math.clamp(screenPos.X, 10, workspace.CurrentCamera.ViewportSize.X - menuSize.X - 10)
	local y = math.clamp(screenPos.Y, 10, workspace.CurrentCamera.ViewportSize.Y - menuSize.Y - 10)
	contextMenu.Position = UDim2.fromOffset(x, y)
	contextMenu.Visible = true
end

local slotWidgets = {}

local function setSelected(index)
	selectedIndex = index
	for i, slot in ipairs(slotWidgets) do
		local selected = i == index
		local item = inventoryItems[i]
		local accent = rarityColor(item and item.rarity or "Common")
		local stroke = slot:FindFirstChild("Stroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = selected and accent or blendColor(Color3.fromRGB(48, 56, 72), accent, 0.35)
			stroke.Thickness = selected and 2 or 1
		end
		local glow = slot:FindFirstChild("SelectedGlow")
		if glow and glow:IsA("Frame") then
			glow.BackgroundColor3 = accent
			glow.Visible = selected
		end
	end

	local item = inventoryItems[index]
	applyDetails(item)
	hideContextMenu()
end

local function rebuildSlots()
	for _, child in ipairs(slotsFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	slotWidgets = {}

	emptyLabel.Visible = #inventoryItems == 0
	gridCountLabel.Text = ("%d collected"):format(#inventoryItems)

	for index, item in ipairs(inventoryItems) do
		local def = item.def
		local rarity = item.rarity or (def and def.rarity) or "Common"
		local accent = rarityColor(rarity)
		local baseColor = blendColor(Color3.fromRGB(24, 28, 38), accent, 0.09)
		local hoverColor = blendColor(baseColor, accent, 0.12)

		local slot = Instance.new("TextButton")
		slot.Name = "Slot_" .. index
		slot.Size = UDim2.fromOffset(126, 144)
		slot.BackgroundColor3 = baseColor
		slot.BorderSizePixel = 0
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.Parent = slotsFrame
		Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 12)

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Color = blendColor(Color3.fromRGB(48, 56, 72), accent, 0.35)
		stroke.Thickness = 1
		stroke.Parent = slot

		local glow = Instance.new("Frame")
		glow.Name = "SelectedGlow"
		glow.Size = UDim2.new(1, 0, 1, 0)
		glow.BackgroundColor3 = accent
		glow.BackgroundTransparency = 0.88
		glow.BorderSizePixel = 0
		glow.Visible = false
		glow.Parent = slot
		Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 12)

		local iconBubble = Instance.new("Frame")
		iconBubble.Position = UDim2.fromOffset(10, 10)
		iconBubble.Size = UDim2.fromOffset(34, 34)
		iconBubble.BackgroundColor3 = blendColor(Color3.fromRGB(24, 28, 38), accent, 0.24)
		iconBubble.BorderSizePixel = 0
		iconBubble.Parent = slot
		Instance.new("UICorner", iconBubble).CornerRadius = UDim.new(0, 10)

		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(1, 1)
		icon.Font = Enum.Font.GothamBold
		icon.TextSize = 15
		icon.TextColor3 = Color3.fromRGB(236, 242, 250)
		icon.Text = def and def.weaponType and def.weaponType:sub(1, 1) or "?"
		icon.Parent = iconBubble

		if item.favorite then
			local favoriteTag = Instance.new("TextLabel")
			favoriteTag.AnchorPoint = Vector2.new(1, 0)
			favoriteTag.Position = UDim2.new(1, -10, 0, 10)
			favoriteTag.Size = UDim2.fromOffset(18, 18)
			favoriteTag.BackgroundColor3 = Color3.fromRGB(255, 210, 96)
			favoriteTag.BorderSizePixel = 0
			favoriteTag.Font = Enum.Font.GothamBold
			favoriteTag.TextSize = 10
			favoriteTag.TextColor3 = Color3.fromRGB(30, 24, 10)
			favoriteTag.Text = "F"
			favoriteTag.Parent = slot
			Instance.new("UICorner", favoriteTag).CornerRadius = UDim.new(0, 6)
		end

		if equippedWeaponId == item.id then
			local equippedTag = Instance.new("TextLabel")
			equippedTag.AnchorPoint = Vector2.new(1, 0)
			equippedTag.Position = UDim2.new(1, -10, 0, item.favorite and 34 or 10)
			equippedTag.Size = UDim2.fromOffset(18, 18)
			equippedTag.BackgroundColor3 = accent
			equippedTag.BorderSizePixel = 0
			equippedTag.Font = Enum.Font.GothamBold
			equippedTag.TextSize = 11
			equippedTag.TextColor3 = Color3.fromRGB(255, 255, 255)
			equippedTag.Text = "E"
			equippedTag.Parent = slot
			Instance.new("UICorner", equippedTag).CornerRadius = UDim.new(0, 6)
		end

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(10, 52)
		name.Size = UDim2.new(1, -20, 0, 46)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 12
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.TextWrapped = true
		name.TextColor3 = accent
		name.Text = item.displayName or (def and def.name) or item.id
		name.Parent = slot

		local rarityTag = Instance.new("TextLabel")
		rarityTag.BackgroundTransparency = 1
		rarityTag.AnchorPoint = Vector2.new(0, 1)
		rarityTag.Position = UDim2.new(0, 10, 1, -28)
		rarityTag.Size = UDim2.new(1, -20, 0, 14)
		rarityTag.Font = Enum.Font.Gotham
		rarityTag.TextSize = 11
		rarityTag.TextXAlignment = Enum.TextXAlignment.Left
		rarityTag.TextColor3 = Color3.fromRGB(198, 206, 220)
		rarityTag.Text = ("%s | Lv %d"):format(rarity, tonumber(item.level) or 1)
		rarityTag.Parent = slot

		local statTag = Instance.new("TextLabel")
		statTag.BackgroundTransparency = 1
		statTag.AnchorPoint = Vector2.new(0, 1)
		statTag.Position = UDim2.new(0, 10, 1, -10)
		statTag.Size = UDim2.new(1, -20, 0, 14)
		statTag.Font = Enum.Font.Gotham
		statTag.TextSize = 10
		statTag.TextXAlignment = Enum.TextXAlignment.Left
		statTag.TextColor3 = Color3.fromRGB(154, 165, 184)
		statTag.Text = ("ATK %s"):format(tostring((item.stats and item.stats.ATK) or (def and def.baseDamage) or "-"))
		statTag.Parent = slot

		addHover(slot, baseColor, hoverColor)

		slot.MouseButton1Click:Connect(function()
			setSelected(index)
		end)
		slot.MouseButton2Click:Connect(function()
			setSelected(index)
			showContextMenu(index, UserInputService:GetMouseLocation())
		end)

		slotWidgets[index] = slot
	end

	task.defer(function()
		slotsFrame.CanvasSize = UDim2.fromOffset(0, slotsLayout.AbsoluteContentSize.Y + 12)
	end)

	if #inventoryItems > 0 then
		if not selectedIndex or not inventoryItems[selectedIndex] then
			setSelected(1)
		else
			setSelected(selectedIndex)
		end
	else
		applyDetails(nil)
	end
end

local function loadSnapshot()
	if not GetInventorySnapshot then
		warn("[InventoryController] RF_GetInventorySnapshot missing")
		return
	end
	local ok, payload = pcall(function()
		return GetInventorySnapshot:InvokeServer()
	end)
	if not ok or typeof(payload) ~= "table" then
		warn("[InventoryController] Failed to load snapshot")
		return
	end

	local info = payload.playerInfo or {}
	level = tonumber(info.level) or level
	xp = tonumber(info.xp) or xp
	nextXp = tonumber(info.nextXp) or nextXp

	local currencies = payload.currencies or {}
	coins = tonumber(currencies.Silver or currencies.Coins) or coins
	souls = tonumber(currencies.Souls) or souls
	weaponPoints = tonumber(currencies.WeaponPoints) or weaponPoints
	tickets = tonumber(currencies.Tickets) or tickets

	local resources = payload.resources or {}
	inventoryResources.mineResources = resources.mineResources or {}
	inventoryResources.mobMaterials = resources.mobMaterials or {}
	inventoryResources.upgradeMaterials = resources.upgradeMaterials or {}

	equippedWeaponId = payload.equippedId

	inventoryItems = {}
	for _, entry in ipairs(payload.weapons or {}) do
		local instanceId = entry.InstanceId or entry.instanceId or entry.id
		local weaponId = entry.WeaponId or entry.weaponId or entry.weapon
		if typeof(instanceId) == "string" and instanceId ~= "" and typeof(weaponId) == "string" and weaponId ~= "" then
			local def = WeaponConfigs.Get and WeaponConfigs.Get(weaponId) or nil
			local rarity = entry.Rarity or (def and def.rarity) or "Common"
			local prefix = entry.Prefix or "Standard"
			local baseName = (def and def.name) or weaponId
			local displayName = prefix ~= "Standard" and (prefix .. " " .. baseName) or baseName
			table.insert(inventoryItems, {
				id = instanceId,
				weaponId = weaponId,
				displayName = displayName,
				def = def,
				rarity = rarity,
				level = tonumber(entry.Level) or 1,
				maxLevel = tonumber(entry.MaxLevel) or (def and def.maxLevel) or nil,
				stats = entry.Stats or {},
				favorite = entry.Favorite == true,
			})
		end
	end

	updatePlayerInfo()
	rebuildSlots()
	refreshEquippedPanel()
end

local function fireInventoryAction(actionType, payload)
	if not InventoryAction then
		warn("[InventoryController] InventoryAction remote missing")
		return
	end
	local message = payload or {}
	message.type = actionType
	InventoryAction:FireServer(message)
end

local function closeInventory()
	inventoryGui.Enabled = false
	hideContextMenu()
	infoOverlay.Visible = false
end

local function openInventory()
	inventoryGui.Enabled = true
	loadSnapshot()
end

local function toggleInventory()
	if inventoryGui.Enabled then
		closeInventory()
	else
		openInventory()
	end
end

local lastScreenButtonsNonce = nil

local function handleScreenButtonsRequest()
	local nonce = inventoryGui:GetAttribute("ScreenButtonsNonce")
	if nonce == nil or nonce == lastScreenButtonsNonce then
		return
	end

	lastScreenButtonsNonce = nonce

	local action = inventoryGui:GetAttribute("ScreenButtonsAction")
	if action == "open" then
		openInventory()
	elseif action == "close" then
		closeInventory()
	elseif action == "toggle" then
		toggleInventory()
	end
end

inventoryGui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(handleScreenButtonsRequest)
handleScreenButtonsRequest()

equipBtn.MouseButton1Click:Connect(function()
	local item = contextIndex and inventoryItems[contextIndex]
	if not item then return end
	fireInventoryAction("equip", { id = item.id })
	equippedWeaponId = item.id
	refreshEquippedPanel()
	hideContextMenu()
	task.delay(0.2, loadSnapshot)
end)

sellBtn.MouseButton1Click:Connect(function()
	local item = contextIndex and inventoryItems[contextIndex]
	if not item then return end
	fireInventoryAction("sell", { id = item.id })
	hideContextMenu()
	task.delay(0.2, loadSnapshot)
end)

upgradeBtn.MouseButton1Click:Connect(function()
	hideContextMenu()
	warn("[InventoryController] Upgrade not implemented yet.")
end)

favoriteBtn.MouseButton1Click:Connect(function()
	local item = contextIndex and inventoryItems[contextIndex]
	if not item then return end
	local nextValue = not item.favorite
	fireInventoryAction("favorite", { id = item.id, value = nextValue })
	item.favorite = nextValue
	favoriteBtn.Text = nextValue and "Unfavorite" or "Favorite"
	hideContextMenu()
	task.delay(0.2, loadSnapshot)
end)

infoBtn.MouseButton1Click:Connect(function()
	local item = contextIndex and inventoryItems[contextIndex]
	if not item then return end
	showInfoPopup(item.def)
	hideContextMenu()
end)

closeBtn.MouseButton1Click:Connect(function()
	closeInventory()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed and input.KeyCode ~= Enum.KeyCode.Tab then return end
	if contextMenu.Visible and input.UserInputType == Enum.UserInputType.MouseButton1 then
		hideContextMenu()
	end
	if input.KeyCode == Enum.KeyCode.Tab then
		toggleInventory()
	end
end)

if PlayerProgressEvent then
	PlayerProgressEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or payload.type ~= "progress" then return end
		level = tonumber(payload.level) or level
		xp = tonumber(payload.xp) or xp
		nextXp = tonumber(payload.nextXp) or nextXp
		coins = tonumber(payload.coins) or coins
		if inventoryGui.Enabled then
			updatePlayerInfo()
		end
	end)
else
	warn("[InventoryController] PlayerProgressEvent missing")
end

plr:GetAttributeChangedSignal("Race"):Connect(function()
	if inventoryGui.Enabled then
		updatePlayerInfo()
	end
end)

print("[InventoryController] Ready")
