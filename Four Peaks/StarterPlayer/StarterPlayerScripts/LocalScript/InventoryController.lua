-- LOCALSCRIPT: InventoryController.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/InventoryController (LocalScript)
-- CO: UI ekwipunku lobby (layout mockup + styl gry)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")
local moduleRoot = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local UiResponsive = require(moduleRoot:WaitForChild("UiResponsive"))

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

local SpellDefs = {}
do
	local module = findModule(ReplicatedStorage, "SpellDefinitions")
	if module then
		local ok, result = pcall(require, module)
		if ok and result then
			SpellDefs = result
		else
			warn("[InventoryController] Failed to load SpellDefinitions")
		end
	else
		warn("[InventoryController] Missing SpellDefinitions module")
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

local function spellElementColor(element)
	if SpellDefs.GetElementColor then
		return SpellDefs.GetElementColor(element)
	end
	return Color3.fromRGB(190, 120, 255)
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
inventoryGui.IgnoreGuiInset = false
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
UiResponsive.attachCenteredPanel(panel, Vector2.new(1120, 620))

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
leftColumn.Size = UDim2.new(0, 272, 1, 0)
leftColumn.BackgroundTransparency = 1
leftColumn.Parent = body

local leftLayout = Instance.new("UIListLayout", leftColumn)
leftLayout.FillDirection = Enum.FillDirection.Vertical
leftLayout.Padding = UDim.new(0, 16)
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder

local playerPanel = Instance.new("ScrollingFrame")
playerPanel.Size = UDim2.new(1, 0, 1, 0)
playerPanel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
playerPanel.BackgroundTransparency = 0.08
playerPanel.BorderSizePixel = 0
playerPanel.ScrollBarThickness = 6
playerPanel.CanvasSize = UDim2.fromOffset(0, 0)
playerPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerPanel.LayoutOrder = 1
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

local rightColumn = Instance.new("Frame")
rightColumn.Size = UDim2.new(1, -288, 1, 0)
rightColumn.BackgroundTransparency = 1
rightColumn.Parent = body

local rightLayout = Instance.new("UIListLayout", rightColumn)
rightLayout.FillDirection = Enum.FillDirection.Vertical
rightLayout.Padding = UDim.new(0, 12)
rightLayout.SortOrder = Enum.SortOrder.LayoutOrder

local tabButtons = {}

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, 0, 0, 44)
tabBar.BackgroundTransparency = 1
tabBar.Parent = rightColumn

local tabLayout = Instance.new("UIListLayout", tabBar)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function createTabButton(tabId, labelText, accentColor)
	local button = Instance.new("TextButton")
	button.Name = tabId .. "Tab"
	button.Size = UDim2.fromOffset(118, 44)
	button.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	button.BackgroundTransparency = 0.04
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(182, 192, 210)
	button.Text = labelText
	button.Parent = tabBar
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke", button)
	stroke.Name = "Stroke"
	stroke.Color = Color3.fromRGB(48, 56, 72)
	stroke.Thickness = 1

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(1, 0, 0, 4)
	accent.BackgroundColor3 = accentColor
	accent.BorderSizePixel = 0
	accent.Visible = false
	accent.Parent = button
	Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 12)

	tabButtons[tabId] = button
	return button
end

createTabButton("Weapons", "Weapons", Color3.fromRGB(96, 165, 250))
createTabButton("SpellLoadout", "Spell Loadout", Color3.fromRGB(190, 120, 255))
createTabButton("Codex", "Codex", Color3.fromRGB(255, 204, 126))
createTabButton("MineCache", "Mine Cache", Color3.fromRGB(88, 196, 139))
createTabButton("MonsterLoot", "Monster Loot", Color3.fromRGB(233, 174, 94))
createTabButton("ForgeStock", "Forge Stock", Color3.fromRGB(176, 135, 255))

local inventorySection = Instance.new("Frame")
inventorySection.Size = UDim2.new(1, 0, 1, -56)
inventorySection.BackgroundTransparency = 1
inventorySection.Parent = rightColumn

local inventorySectionLayout = Instance.new("UIListLayout", inventorySection)
inventorySectionLayout.FillDirection = Enum.FillDirection.Horizontal
inventorySectionLayout.Padding = UDim.new(0, 16)
inventorySectionLayout.SortOrder = Enum.SortOrder.LayoutOrder

local gridPanel = Instance.new("Frame")
gridPanel.Size = UDim2.new(0.68, -8, 1, 0)
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
gridTitle.Size = UDim2.new(1, -150, 0, 20)
gridTitle.Font = Enum.Font.GothamBold
gridTitle.TextSize = 16
gridTitle.TextColor3 = Color3.fromRGB(235, 239, 246)
gridTitle.TextXAlignment = Enum.TextXAlignment.Left
gridTitle.Text = "Weapons"
gridTitle.Parent = gridPanel

local gridCountLabel = Instance.new("TextLabel")
gridCountLabel.AnchorPoint = Vector2.new(1, 0)
gridCountLabel.Position = UDim2.new(1, 0, 0, 2)
gridCountLabel.Size = UDim2.fromOffset(140, 16)
gridCountLabel.BackgroundTransparency = 1
gridCountLabel.Font = Enum.Font.Gotham
gridCountLabel.TextSize = 11
gridCountLabel.TextColor3 = Color3.fromRGB(154, 165, 184)
gridCountLabel.TextXAlignment = Enum.TextXAlignment.Right
gridCountLabel.Text = "0 collected"
gridCountLabel.Parent = gridPanel

local slotsFrame = Instance.new("ScrollingFrame")
slotsFrame.BackgroundTransparency = 1
slotsFrame.Position = UDim2.fromOffset(0, 42)
slotsFrame.Size = UDim2.new(1, 0, 1, -42)
slotsFrame.ScrollBarThickness = 6
slotsFrame.BorderSizePixel = 0
slotsFrame.CanvasSize = UDim2.fromOffset(0, 0)
slotsFrame.Parent = gridPanel

local slotsLayout = Instance.new("UIGridLayout", slotsFrame)
slotsLayout.CellPadding = UDim2.fromOffset(12, 12)
slotsLayout.CellSize = UDim2.fromOffset(128, 148)
slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local emptyLabel = Instance.new("TextLabel")
emptyLabel.BackgroundTransparency = 1
emptyLabel.Position = UDim2.fromOffset(0, 42)
emptyLabel.Size = UDim2.new(1, 0, 1, -42)
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
detailsPanel.Size = UDim2.new(0.32, -8, 1, 0)
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
detailsTitle.Text = "Item Details"
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
itemName.Text = "Select an item"
itemName.Parent = detailsScroll

local itemDesc = Instance.new("TextLabel")
itemDesc.BackgroundTransparency = 1
itemDesc.Size = UDim2.new(1, 0, 0, 34)
itemDesc.AutomaticSize = Enum.AutomaticSize.Y
itemDesc.Font = Enum.Font.Gotham
itemDesc.TextSize = 12
itemDesc.TextColor3 = Color3.fromRGB(190, 190, 190)
itemDesc.TextXAlignment = Enum.TextXAlignment.Left
itemDesc.TextWrapped = true
itemDesc.Text = "Pick a tab and slot to see its details."
itemDesc.Parent = detailsScroll

local infoLine = Instance.new("TextLabel")
infoLine.BackgroundTransparency = 1
infoLine.Size = UDim2.new(1, 0, 0, 18)
infoLine.Font = Enum.Font.Gotham
infoLine.TextSize = 12
infoLine.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLine.TextXAlignment = Enum.TextXAlignment.Left
infoLine.Text = "Category: - | Rarity: -"
infoLine.Parent = detailsScroll

local statLine = Instance.new("TextLabel")
statLine.BackgroundTransparency = 1
statLine.Size = UDim2.new(1, 0, 0, 18)
statLine.Font = Enum.Font.Gotham
statLine.TextSize = 12
statLine.TextColor3 = Color3.fromRGB(200, 200, 200)
statLine.TextXAlignment = Enum.TextXAlignment.Left
statLine.Text = "Count: -"
statLine.Parent = detailsScroll

local bonusStats = Instance.new("TextLabel")
bonusStats.BackgroundTransparency = 1
bonusStats.Size = UDim2.new(1, 0, 0, 52)
bonusStats.AutomaticSize = Enum.AutomaticSize.Y
bonusStats.Font = Enum.Font.Gotham
bonusStats.TextSize = 12
bonusStats.TextColor3 = Color3.fromRGB(190, 190, 190)
bonusStats.TextXAlignment = Enum.TextXAlignment.Left
bonusStats.TextWrapped = true
bonusStats.Text = "Summary: -"
bonusStats.Parent = detailsScroll

local passiveTitle = Instance.new("TextLabel")
passiveTitle.BackgroundTransparency = 1
passiveTitle.Size = UDim2.new(1, 0, 0, 16)
passiveTitle.Font = Enum.Font.GothamBold
passiveTitle.TextSize = 12
passiveTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
passiveTitle.TextXAlignment = Enum.TextXAlignment.Left
passiveTitle.Text = "Usage"
passiveTitle.Parent = detailsScroll

local passiveDesc = Instance.new("TextLabel")
passiveDesc.BackgroundTransparency = 1
passiveDesc.Size = UDim2.new(1, 0, 0, 92)
passiveDesc.AutomaticSize = Enum.AutomaticSize.Y
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
abilityTitle.Text = "Notes"
abilityTitle.Parent = detailsScroll

local abilityDesc = Instance.new("TextLabel")
abilityDesc.BackgroundTransparency = 1
abilityDesc.Size = UDim2.new(1, 0, 0, 72)
abilityDesc.AutomaticSize = Enum.AutomaticSize.Y
abilityDesc.Font = Enum.Font.Gotham
abilityDesc.TextSize = 12
abilityDesc.TextColor3 = Color3.fromRGB(190, 190, 190)
abilityDesc.TextXAlignment = Enum.TextXAlignment.Left
abilityDesc.TextWrapped = true
abilityDesc.Text = "-"
abilityDesc.Parent = detailsScroll

local detailActions = Instance.new("Frame")
detailActions.BackgroundTransparency = 1
detailActions.Size = UDim2.new(1, 0, 0, 34)
detailActions.Visible = false
detailActions.Parent = detailsScroll

local detailActionsLayout = Instance.new("UIListLayout", detailActions)
detailActionsLayout.FillDirection = Enum.FillDirection.Horizontal
detailActionsLayout.Padding = UDim.new(0, 8)
detailActionsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function makeDetailActionButton(label)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.33, -6, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(36, 42, 54)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.TextColor3 = Color3.fromRGB(236, 242, 250)
	button.Text = label
	button.Parent = detailActions
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
	addHover(button, button.BackgroundColor3, Color3.fromRGB(48, 56, 72))
	return button
end

local spellEquipBtn = makeDetailActionButton("Equip")
local spellMoveUpBtn = makeDetailActionButton("Up")
local spellMoveDownBtn = makeDetailActionButton("Down")

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
local spellSnapshot = {
	entries = {},
	loadout = {},
	maxSlots = 0,
	damageSummary = {},
	combinations = {},
}
local spellEntries = {}
local codexSnapshot = {
	categories = {},
	entries = {},
	counts = {},
}
local codexEntries = {}
local currentEntries = {}
local currentTab = "Weapons"
local selectedEntryIdByTab = {}
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

local TAB_CONFIGS = {
	Weapons = {
		label = "Weapons",
		countSuffix = "collected",
		detailsTitle = "Weapon Details",
		emptyText = "No weapons yet.",
		accent = Color3.fromRGB(96, 165, 250),
		placeholderName = "Select a weapon",
		placeholderDesc = "Pick a weapon slot to see its details.",
	},
	SpellLoadout = {
		label = "Spell Loadout",
		countSuffix = "known",
		detailsTitle = "Spell Details",
		emptyText = "No spells unlocked yet.",
		accent = Color3.fromRGB(190, 120, 255),
		placeholderName = "Select a spell",
		placeholderDesc = "Pick an unlocked spell to equip it for your next run.",
	},
	Codex = {
		label = "Codex",
		countSuffix = "entries",
		detailsTitle = "Codex Entry",
		emptyText = "No codex entries available.",
		accent = Color3.fromRGB(255, 204, 126),
		placeholderName = "Select an entry",
		placeholderDesc = "Pick a discovered entry to inspect it.",
	},
	MineCache = {
		label = "Mine Cache",
		countSuffix = "types stored",
		detailsTitle = "Mine Cache",
		emptyText = "No ore or crystals stored.",
		accent = Color3.fromRGB(88, 196, 139),
		resourceKey = "mineResources",
		placeholderName = "Select a material",
		placeholderDesc = "Pick a stored material to see its count and usage.",
		usageTitle = "Used For",
		usageText = "Ore, crystals and mine finds used in crafting, trading and future recipes.",
		notesTitle = "Storage",
		notesText = "This tab shows everything currently stored in your mine cache.",
	},
	MonsterLoot = {
		label = "Monster Loot",
		countSuffix = "types stored",
		detailsTitle = "Monster Loot",
		emptyText = "No monster materials stored.",
		accent = Color3.fromRGB(233, 174, 94),
		resourceKey = "mobMaterials",
		placeholderName = "Select a material",
		placeholderDesc = "Pick a drop to see its count and usage.",
		usageTitle = "Used For",
		usageText = "Drops from enemies used in recipes, trades and progression systems.",
		notesTitle = "Storage",
		notesText = "This tab shows everything currently stored from defeated monsters.",
	},
	ForgeStock = {
		label = "Forge Stock",
		countSuffix = "types stored",
		detailsTitle = "Forge Stock",
		emptyText = "No forge stock stored.",
		accent = Color3.fromRGB(176, 135, 255),
		resourceKey = "upgradeMaterials",
		placeholderName = "Select a material",
		placeholderDesc = "Pick a forge material to see its count and usage.",
		usageTitle = "Used For",
		usageText = "Special upgrade stock reserved for forging, enhancing and late-game crafting.",
		notesTitle = "Storage",
		notesText = "This tab shows everything currently stored for the forge.",
	},
}

local TAB_ORDER = { "Weapons", "SpellLoadout", "Codex", "MineCache", "MonsterLoot", "ForgeStock" }

local function getTabConfig(tabId)
	return TAB_CONFIGS[tabId] or TAB_CONFIGS.Weapons
end

local function formatResourceLabel(resourceId)
	return tostring(resourceId or "Unknown"):gsub("_", " ")
end

local function buildResourceEntries(entries)
	local built = {}
	for _, entry in ipairs(entries or {}) do
		if typeof(entry) == "table" then
			local resourceId = tostring(entry.id or entry.name or "")
			if resourceId ~= "" then
				table.insert(built, {
					id = resourceId,
					displayName = formatResourceLabel(resourceId),
					amount = math.max(0, math.floor(tonumber(entry.amount) or 0)),
					rarity = resourceMetaById[resourceId] and resourceMetaById[resourceId].rarity or nil,
				})
			end
		end
	end
	table.sort(built, function(a, b)
		if a.amount == b.amount then
			return a.displayName < b.displayName
		end
		return a.amount > b.amount
	end)
	return built
end

local function buildSpellEntries(entries)
	local built = {}
	for _, entry in ipairs(entries or {}) do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and entry.id ~= "" then
			table.insert(built, {
				id = entry.id,
				productId = entry.productId or entry.id,
				familyId = entry.familyId,
				displayName = entry.displayName or entry.name or entry.id,
				rarity = entry.rarity or entry.baseQuality or "Spell",
				element = entry.element or "Physical",
				attackType = entry.attackType,
				spellType = entry.spellType,
				description = entry.description or "",
				iconGlyph = entry.iconGlyph,
				artMotif = entry.artMotif,
				loreDescription = entry.loreDescription,
				gameplayDescription = entry.gameplayDescription,
				visualDirection = entry.visualDirection,
				frameStyle = entry.frameStyle,
				codexCategory = entry.codexCategory,
				witchbookAccent = entry.witchbookAccent,
				presentation = entry.presentation or {},
				visualProfile = entry.visualProfile or {},
				unlocked = entry.unlocked == true,
				equipped = entry.equipped == true,
				statLines = entry.statLines or {},
				upgradeLevels = entry.upgradeLevels or {},
				combinations = entry.combinations or {},
			})
		end
	end
	table.sort(built, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if a.unlocked ~= b.unlocked then
			return a.unlocked
		end
		local ea = SpellDefs.ELEMENTS and SpellDefs.ELEMENTS[a.element]
		local eb = SpellDefs.ELEMENTS and SpellDefs.ELEMENTS[b.element]
		local oa = ea and ea.order or 99
		local ob = eb and eb.order or 99
		if oa ~= ob then
			return oa < ob
		end
		return tostring(a.displayName) < tostring(b.displayName)
	end)
	return built
end

local function buildCodexEntries(entries)
	local built = {}
	for _, entry in ipairs(entries or {}) do
		if typeof(entry) == "table" and typeof(entry.id) == "string" and entry.id ~= "" then
			table.insert(built, {
				id = entry.id,
				category = entry.category or "Codex",
				displayName = entry.displayName or entry.id,
				description = entry.description or "",
				rarity = entry.rarity or (entry.discovered and "Discovered" or "Locked"),
				discovered = entry.discovered == true,
				seen = entry.seen == true,
				element = entry.element,
				tags = entry.tags or {},
				iconText = entry.iconText,
				artMotif = entry.artMotif,
				loreDescription = entry.loreDescription,
				gameplayDescription = entry.gameplayDescription,
				visualDirection = entry.visualDirection,
				frameStyle = entry.frameStyle,
				witchbookAccent = entry.witchbookAccent,
				presentation = entry.presentation or {},
				ingredients = entry.ingredients or {},
			})
		end
	end
	table.sort(built, function(a, b)
		if a.discovered ~= b.discovered then
			return a.discovered
		end
		if tostring(a.category) ~= tostring(b.category) then
			return tostring(a.category) < tostring(b.category)
		end
		return tostring(a.displayName) < tostring(b.displayName)
	end)
	return built
end

local function getEntriesForTab(tabId)
	local config = getTabConfig(tabId)
	if tabId == "SpellLoadout" then
		return spellEntries
	end
	if tabId == "Codex" then
		return codexEntries
	end
	if not config.resourceKey then
		return inventoryItems
	end
	return buildResourceEntries(inventoryResources[config.resourceKey])
end

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
end


local function applyWeaponDetails(item)
	detailActions.Visible = false
	local config = getTabConfig("Weapons")
	detailsTitle.Text = config.detailsTitle

	if not item or not item.def then
		itemName.Text = config.placeholderName
		itemName.TextColor3 = Color3.fromRGB(245, 245, 245)
		itemDesc.Text = config.placeholderDesc
		infoLine.Text = "Type: - | Rarity: -"
		infoLine.TextColor3 = Color3.fromRGB(200, 200, 200)
		statLine.Text = "Level: - | ATK: -"
		bonusStats.Text = "Bonus Stats: -"
		passiveTitle.Text = "Passive"
		passiveDesc.Text = "-"
		abilityTitle.Text = "Ability"
		abilityDesc.Text = "-"
		iconLabel.Text = "?"
		iconFrame.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
		iconStroke.Color = Color3.fromRGB(50, 50, 64)
		detailsPanelStroke.Color = Color3.fromRGB(48, 56, 72)
		detailsAccent.BackgroundColor3 = config.accent
		updateDetailsCanvas()
		return
	end

	local def = item.def
	local rarity = item.rarity or def.rarity or "Common"
	local color = rarityColor(rarity)
	itemName.Text = item.displayName or def.name or def.id or "Unknown"
	itemName.TextColor3 = color
	itemDesc.Text = def.description or def.passiveDescription or def.abilityDescription or "No description."
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

	iconLabel.Text = def.weaponType and def.weaponType:sub(1, 1) or "?"
	iconFrame.BackgroundColor3 = blendColor(Color3.fromRGB(26, 30, 40), color, 0.18)
	iconStroke.Color = color
	detailsPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), color, 0.45)
	detailsAccent.BackgroundColor3 = color
	updateDetailsCanvas()
end

local function applyResourceDetails(entry)
	detailActions.Visible = false
	local config = getTabConfig(currentTab)
	detailsTitle.Text = config.detailsTitle

	if not entry then
		itemName.Text = config.placeholderName
		itemName.TextColor3 = Color3.fromRGB(245, 245, 245)
		itemDesc.Text = config.placeholderDesc
		infoLine.Text = ("Category: %s | Rarity: -"):format(config.label)
		infoLine.TextColor3 = Color3.fromRGB(200, 200, 200)
		statLine.Text = "Count: -"
		bonusStats.Text = "Summary: Select a stored item."
		passiveTitle.Text = config.usageTitle or "Usage"
		passiveDesc.Text = config.usageText or "-"
		abilityTitle.Text = config.notesTitle or "Notes"
		abilityDesc.Text = config.notesText or "-"
		iconLabel.Text = "?"
		iconFrame.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
		iconStroke.Color = Color3.fromRGB(50, 50, 64)
		detailsPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), config.accent, 0.35)
		detailsAccent.BackgroundColor3 = config.accent
		updateDetailsCanvas()
		return
	end

	local rarity = entry.rarity or "Common"
	local color = getResourceColor(entry.id, config.accent)
	itemName.Text = entry.displayName or formatResourceLabel(entry.id)
	itemName.TextColor3 = color
	itemDesc.Text = config.placeholderDesc
	infoLine.Text = ("Category: %s | Rarity: %s"):format(config.label, rarity)
	infoLine.TextColor3 = color
	statLine.Text = ("Count: %d"):format(entry.amount or 0)
	bonusStats.Text = ("Summary: %d stored in %s."):format(entry.amount or 0, config.label)
	passiveTitle.Text = config.usageTitle or "Usage"
	passiveDesc.Text = config.usageText or "-"
	abilityTitle.Text = config.notesTitle or "Notes"
	abilityDesc.Text = ("%s Current amount: %d."):format(config.notesText or "Stored in your inventory.", entry.amount or 0)

	local iconText = (entry.displayName or entry.id or "?"):sub(1, 1)
	iconLabel.Text = iconText ~= "" and string.upper(iconText) or "?"
	iconFrame.BackgroundColor3 = blendColor(Color3.fromRGB(26, 30, 40), color, 0.18)
	iconStroke.Color = color
	detailsPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), color, 0.45)
	detailsAccent.BackgroundColor3 = color
	updateDetailsCanvas()
end

local function summarizeUpgradeLevels(levels)
	local rows = {}
	for _, levelInfo in ipairs(levels or {}) do
		local statLines = levelInfo.statLines or {}
		local firstLine = statLines[1] or "scales core stats"
		table.insert(rows, ("Lv.%s: %s"):format(tostring(levelInfo.level or "?"), firstLine))
		if #rows >= 6 then
			break
		end
	end
	return #rows > 0 and table.concat(rows, "\n") or "-"
end

local function summarizeCombinations(combinations)
	local rows = {}
	for _, combo in ipairs(combinations or {}) do
		local result = SpellDefs.GetSpell and SpellDefs.GetSpell(combo.resultId) or nil
		local resultName = result and result.name or tostring(combo.resultId or "?")
		local ingredientNames = {}
		for _, ingredient in ipairs(combo.ingredients or {}) do
			local def = SpellDefs.GetSpell and SpellDefs.GetSpell(ingredient) or nil
			table.insert(ingredientNames, def and def.name or tostring(ingredient))
		end
		table.insert(rows, ("%s: %s"):format(resultName, table.concat(ingredientNames, " + ")))
	end
	return #rows > 0 and table.concat(rows, "\n") or "No known combinations."
end

local function summarizeElementDamage()
	local rows = {}
	for _, entry in ipairs(spellSnapshot.damageSummary or {}) do
		table.insert(rows, ("%s %.1f"):format(tostring(entry.element or "?"), tonumber(entry.damage) or 0))
	end
	return #rows > 0 and table.concat(rows, " | ") or "-"
end

local function getPresentationField(entry, key, fallback)
	if not entry then
		return fallback
	end
	local value = entry[key]
	if value ~= nil and value ~= "" then
		return value
	end
	local presentation = entry.presentation
	if typeof(presentation) == "table" then
		value = presentation[key]
		if value ~= nil and value ~= "" then
			return value
		end
	end
	return fallback
end

local function formatSpellPresentation(entry)
	local lore = getPresentationField(entry, "loreDescription", nil)
	local gameplay = getPresentationField(entry, "gameplayDescription", nil)
	local visual = getPresentationField(entry, "visualDirection", nil)
	local motif = getPresentationField(entry, "artMotif", nil)
	local rows = {}
	if lore then
		table.insert(rows, ("Lore: %s"):format(lore))
	end
	if gameplay then
		table.insert(rows, ("Gameplay: %s"):format(gameplay))
	end
	if motif then
		table.insert(rows, ("Art: %s"):format(motif))
	end
	if visual then
		table.insert(rows, ("VFX: %s"):format(visual))
	end
	return #rows > 0 and table.concat(rows, "\n") or nil
end

local function applySpellDetails(entry)
	local config = getTabConfig("SpellLoadout")
	detailsTitle.Text = config.detailsTitle
	detailActions.Visible = entry ~= nil

	if not entry then
		itemName.Text = config.placeholderName
		itemName.TextColor3 = Color3.fromRGB(245, 245, 245)
		itemDesc.Text = config.placeholderDesc
		infoLine.Text = ("Loadout: %d/%d selected"):format(#(spellSnapshot.loadout or {}), tonumber(spellSnapshot.maxSlots) or 0)
		infoLine.TextColor3 = Color3.fromRGB(200, 200, 200)
		statLine.Text = "Status: -"
		bonusStats.Text = ("Element Summary: %s"):format(summarizeElementDamage())
		passiveTitle.Text = "Upgrade Levels"
		passiveDesc.Text = "-"
		abilityTitle.Text = "Combinations"
		abilityDesc.Text = "-"
		iconLabel.Text = "S"
		iconFrame.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
		iconStroke.Color = config.accent
		detailsPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), config.accent, 0.35)
		detailsAccent.BackgroundColor3 = config.accent
		updateDetailsCanvas()
		return
	end

	local color = spellElementColor(entry.element)
	itemName.Text = entry.displayName
	itemName.TextColor3 = color
	itemDesc.Text = getPresentationField(entry, "loreDescription", entry.description ~= "" and entry.description or "Unlocks this spell for run upgrade offers.")
	infoLine.Text = ("Type: %s | Element: %s | Attack: %s"):format(entry.spellType or "-", entry.element or "-", entry.attackType or "-")
	infoLine.TextColor3 = color
	statLine.Text = ("Status: %s | Loadout %d/%d"):format(entry.equipped and "Equipped" or (entry.unlocked and "Unlocked" or "Locked"), #(spellSnapshot.loadout or {}), tonumber(spellSnapshot.maxSlots) or 0)
	bonusStats.Text = ("Art: %s\nBase Stats: %s\nLoadout Elements: %s"):format(
		getPresentationField(entry, "artMotif", "-"),
		table.concat(entry.statLines or {}, " | "),
		summarizeElementDamage()
	)
	passiveTitle.Text = "Gameplay and Upgrades"
	passiveDesc.Text = ("%s\n\n%s"):format(
		getPresentationField(entry, "gameplayDescription", "Unlocks this spell for run upgrade offers."),
		summarizeUpgradeLevels(entry.upgradeLevels)
	)
	abilityTitle.Text = "Visual Direction and Combinations"
	abilityDesc.Text = ("%s\n\n%s"):format(
		getPresentationField(entry, "visualDirection", "-"),
		summarizeCombinations(entry.combinations)
	)

	iconLabel.Text = getPresentationField(entry, "iconGlyph", string.upper((entry.element or "S"):sub(1, 1)))
	iconFrame.BackgroundColor3 = blendColor(Color3.fromRGB(26, 30, 40), color, 0.18)
	iconStroke.Color = color
	detailsPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), color, 0.45)
	detailsAccent.BackgroundColor3 = color

	spellEquipBtn.Text = entry.equipped and "Unequip" or "Equip"
	spellEquipBtn.Active = entry.unlocked
	spellEquipBtn.AutoButtonColor = entry.unlocked
	spellEquipBtn.TextTransparency = entry.unlocked and 0 or 0.45
	spellMoveUpBtn.Active = entry.equipped
	spellMoveDownBtn.Active = entry.equipped
	spellMoveUpBtn.TextTransparency = entry.equipped and 0 or 0.45
	spellMoveDownBtn.TextTransparency = entry.equipped and 0 or 0.45
	updateDetailsCanvas()
end

local function applyCodexDetails(entry)
	detailActions.Visible = false
	local config = getTabConfig("Codex")
	detailsTitle.Text = config.detailsTitle

	if not entry then
		itemName.Text = config.placeholderName
		itemName.TextColor3 = Color3.fromRGB(245, 245, 245)
		itemDesc.Text = config.placeholderDesc
		infoLine.Text = "Category: - | Status: -"
		infoLine.TextColor3 = Color3.fromRGB(200, 200, 200)
		statLine.Text = "Discovery: -"
		bonusStats.Text = "Progress: Select an entry."
		passiveTitle.Text = "Tags"
		passiveDesc.Text = "-"
		abilityTitle.Text = "Notes"
		abilityDesc.Text = "-"
		iconLabel.Text = "C"
		iconFrame.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
		iconStroke.Color = config.accent
		detailsPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), config.accent, 0.35)
		detailsAccent.BackgroundColor3 = config.accent
		updateDetailsCanvas()
		return
	end

	local color = entry.element and spellElementColor(entry.element) or (entry.discovered and config.accent or Color3.fromRGB(120, 126, 142))
	itemName.Text = entry.displayName
	itemName.TextColor3 = color
	itemDesc.Text = getPresentationField(entry, "loreDescription", entry.description ~= "" and entry.description or (entry.discovered and "Discovered entry." or "Undiscovered entry."))
	infoLine.Text = ("Category: %s | Status: %s"):format(entry.category or "-", entry.discovered and "Discovered" or "Locked")
	infoLine.TextColor3 = color
	statLine.Text = entry.seen and "Discovery: seen" or "Discovery: new or unseen"
	local counts = codexSnapshot.counts and codexSnapshot.counts[entry.category]
	if counts then
		bonusStats.Text = ("Progress: %d/%d discovered\nArt: %s"):format(counts.discovered or 0, counts.total or 0, getPresentationField(entry, "artMotif", "-"))
	else
		bonusStats.Text = ("Progress: -\nArt: %s"):format(getPresentationField(entry, "artMotif", "-"))
	end
	passiveTitle.Text = "Gameplay"
	passiveDesc.Text = getPresentationField(entry, "gameplayDescription", #(entry.tags or {}) > 0 and table.concat(entry.tags, ", ") or "-")
	abilityTitle.Text = "Visual Direction"
	abilityDesc.Text = getPresentationField(entry, "visualDirection", entry.discovered and "Stored permanently in account progress." or "Find this entry during runs or unlock it through progression.")
	iconLabel.Text = getPresentationField(entry, "iconGlyph", string.upper((entry.iconText or entry.displayName or "C"):sub(1, 1)))
	iconFrame.BackgroundColor3 = blendColor(Color3.fromRGB(26, 30, 40), color, 0.18)
	iconStroke.Color = color
	detailsPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), color, 0.45)
	detailsAccent.BackgroundColor3 = color
	updateDetailsCanvas()
end

local function applyDetails(entry)
	if currentTab == "Weapons" then
		applyWeaponDetails(entry)
	elseif currentTab == "SpellLoadout" then
		applySpellDetails(entry)
	elseif currentTab == "Codex" then
		applyCodexDetails(entry)
	else
		applyResourceDetails(entry)
	end
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
	if currentTab ~= "Weapons" then
		return
	end
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

local function refreshSlotVisual(slot, entry, selected)
	local config = getTabConfig(currentTab)
	local accent = config.accent
	if currentTab == "Weapons" then
		accent = rarityColor(entry and entry.rarity or "Common")
	elseif currentTab == "SpellLoadout" and entry then
		accent = spellElementColor(entry.element)
	elseif currentTab == "Codex" and entry then
		accent = entry.element and spellElementColor(entry.element) or (entry.discovered and config.accent or Color3.fromRGB(120, 126, 142))
	elseif entry then
		accent = getResourceColor(entry.id, config.accent)
	end

	local equipped = (currentTab == "Weapons" and entry and entry.id == equippedWeaponId)
		or (currentTab == "SpellLoadout" and entry and entry.equipped == true)
	local stroke = slot:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		if selected then
			stroke.Color = accent
			stroke.Thickness = 2
		elseif equipped then
			stroke.Color = blendColor(Color3.fromRGB(48, 56, 72), accent, 0.65)
			stroke.Thickness = 2
		else
			stroke.Color = blendColor(Color3.fromRGB(48, 56, 72), accent, 0.35)
			stroke.Thickness = 1
		end
	end

	local glow = slot:FindFirstChild("SelectedGlow")
	if glow and glow:IsA("Frame") then
		glow.BackgroundColor3 = accent
		glow.Visible = selected
	end

	local iconBubble = slot:FindFirstChild("IconBubble")
	if iconBubble and iconBubble:IsA("Frame") then
		iconBubble.BackgroundColor3 = blendColor(Color3.fromRGB(24, 28, 38), accent, equipped and 0.38 or (selected and 0.3 or 0.24))
		local iconStroke = iconBubble:FindFirstChild("IconStroke")
		if iconStroke and iconStroke:IsA("UIStroke") then
			iconStroke.Color = equipped and accent or blendColor(Color3.fromRGB(48, 56, 72), accent, selected and 0.55 or 0.25)
			iconStroke.Thickness = equipped and 2 or 1
		end
		local equippedMark = iconBubble:FindFirstChild("EquippedMark")
		if equippedMark and equippedMark:IsA("TextLabel") then
			equippedMark.Visible = equipped
		end
	end
end

local function refreshTabButtons()
	local activeConfig = getTabConfig(currentTab)
	gridTitle.Text = activeConfig.label
	emptyLabel.Text = activeConfig.emptyText
	gridPanelStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), activeConfig.accent, 0.35)

	for _, tabId in ipairs(TAB_ORDER) do
		local button = tabButtons[tabId]
		if button then
			local config = getTabConfig(tabId)
			local active = tabId == currentTab
			button.BackgroundColor3 = active and blendColor(Color3.fromRGB(20, 24, 32), config.accent, 0.22) or Color3.fromRGB(20, 24, 32)
			button.TextColor3 = active and Color3.fromRGB(245, 247, 250) or Color3.fromRGB(182, 192, 210)

			local stroke = button:FindFirstChild("Stroke")
			if stroke and stroke:IsA("UIStroke") then
				stroke.Color = active and blendColor(Color3.fromRGB(48, 56, 72), config.accent, 0.65) or Color3.fromRGB(48, 56, 72)
				stroke.Thickness = active and 2 or 1
			end

			local accent = button:FindFirstChild("Accent")
			if accent and accent:IsA("Frame") then
				accent.BackgroundColor3 = config.accent
				accent.Visible = active
			end
		end
	end
end

local function setSelected(index)
	local entry = currentEntries[index]
	selectedEntryIdByTab[currentTab] = entry and entry.id or nil

	for i, slot in ipairs(slotWidgets) do
		refreshSlotVisual(slot, currentEntries[i], i == index)
	end

	applyDetails(entry)
	hideContextMenu()
end

local function rebuildSlots()
	for _, child in ipairs(slotsFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	slotWidgets = {}
	currentEntries = getEntriesForTab(currentTab)

	local config = getTabConfig(currentTab)
	refreshTabButtons()
	emptyLabel.Visible = #currentEntries == 0
	gridCountLabel.Text = ("%d %s"):format(#currentEntries, config.countSuffix)

	for index, entry in ipairs(currentEntries) do
		local def = entry.def
		local rarity = currentTab == "Weapons" and (entry.rarity or (def and def.rarity) or "Common") or (entry.rarity or "Common")
		local accent = currentTab == "Weapons" and rarityColor(rarity) or getResourceColor(entry.id, config.accent)
		if currentTab == "SpellLoadout" then
			accent = spellElementColor(entry.element)
		elseif currentTab == "Codex" then
			accent = entry.element and spellElementColor(entry.element) or (entry.discovered and config.accent or Color3.fromRGB(120, 126, 142))
		end
		local baseColor = blendColor(Color3.fromRGB(24, 28, 38), accent, 0.09)
		local hoverColor = blendColor(baseColor, accent, 0.12)

		local slot = Instance.new("TextButton")
		slot.Name = "Slot_" .. index
		slot.Size = UDim2.fromOffset(128, 148)
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
		iconBubble.Name = "IconBubble"
		iconBubble.Position = UDim2.fromOffset(10, 10)
		iconBubble.Size = UDim2.fromOffset(38, 38)
		iconBubble.BackgroundColor3 = blendColor(Color3.fromRGB(24, 28, 38), accent, 0.24)
		iconBubble.BorderSizePixel = 0
		iconBubble.Parent = slot
		Instance.new("UICorner", iconBubble).CornerRadius = UDim.new(0, 10)

		local iconBubbleStroke = Instance.new("UIStroke")
		iconBubbleStroke.Name = "IconStroke"
		iconBubbleStroke.Color = blendColor(Color3.fromRGB(48, 56, 72), accent, 0.25)
		iconBubbleStroke.Thickness = 1
		iconBubbleStroke.Parent = iconBubble

		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(1, 1)
		icon.Font = Enum.Font.GothamBold
		icon.TextSize = 16
		icon.TextColor3 = Color3.fromRGB(236, 242, 250)
		if currentTab == "Weapons" then
			icon.Text = def and def.weaponType and def.weaponType:sub(1, 1) or "?"
		elseif currentTab == "SpellLoadout" then
			icon.Text = string.upper((entry.element or "S"):sub(1, 1))
		elseif currentTab == "Codex" then
			icon.Text = string.upper((entry.iconText or entry.displayName or "C"):sub(1, 1))
		else
			icon.Text = string.upper((entry.displayName or entry.id or "?"):sub(1, 1))
		end
		icon.Parent = iconBubble

		if (currentTab == "Weapons" and entry.id == equippedWeaponId) or (currentTab == "SpellLoadout" and entry.equipped) then
			local equippedMark = Instance.new("TextLabel")
			equippedMark.Name = "EquippedMark"
			equippedMark.AnchorPoint = Vector2.new(1, 0)
			equippedMark.Position = UDim2.new(1, -4, 0, 4)
			equippedMark.Size = UDim2.fromOffset(16, 16)
			equippedMark.BackgroundColor3 = accent
			equippedMark.BorderSizePixel = 0
			equippedMark.Font = Enum.Font.GothamBold
			equippedMark.TextSize = 10
			equippedMark.TextColor3 = Color3.fromRGB(255, 255, 255)
			equippedMark.Text = currentTab == "SpellLoadout" and "#" or "E"
			equippedMark.Parent = iconBubble
			Instance.new("UICorner", equippedMark).CornerRadius = UDim.new(0, 999)
		end

		if currentTab == "Weapons" and entry.favorite then
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

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(10, 56)
		name.Size = UDim2.new(1, -20, 0, 42)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 12
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.TextWrapped = true
		name.TextColor3 = accent
		if currentTab == "Weapons" then
			name.Text = entry.displayName or (def and def.name) or entry.id
		elseif currentTab == "SpellLoadout" or currentTab == "Codex" then
			name.Text = entry.displayName or entry.id
		else
			name.Text = entry.displayName or formatResourceLabel(entry.id)
		end
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
		if currentTab == "Weapons" then
			rarityTag.Text = ("%s | Lv %d"):format(rarity, tonumber(entry.level) or 1)
		elseif currentTab == "SpellLoadout" then
			rarityTag.Text = ("%s | %s"):format(entry.element or "Spell", entry.equipped and "Equipped" or (entry.unlocked and "Unlocked" or "Locked"))
		elseif currentTab == "Codex" then
			rarityTag.Text = ("%s | %s"):format(entry.category or "Codex", entry.discovered and "Discovered" or "Locked")
		else
			rarityTag.Text = ("%s | x%d"):format(rarity, entry.amount or 0)
		end
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
		if currentTab == "Weapons" then
			statTag.Text = ("ATK %s"):format(tostring((entry.stats and entry.stats.ATK) or (def and def.baseDamage) or "-"))
		elseif currentTab == "SpellLoadout" then
			statTag.Text = (entry.statLines and entry.statLines[1]) or (entry.attackType or "Spell")
		elseif currentTab == "Codex" then
			statTag.Text = entry.discovered and "Persistent discovery" or "Undiscovered"
		else
			statTag.Text = ("Stored %d"):format(entry.amount or 0)
		end
		statTag.Parent = slot

		addHover(slot, baseColor, hoverColor)
		slot.MouseButton1Click:Connect(function()
			setSelected(index)
		end)

		if currentTab == "Weapons" then
			slot.MouseButton2Click:Connect(function()
				setSelected(index)
				showContextMenu(index, UserInputService:GetMouseLocation())
			end)
		end

		slotWidgets[index] = slot
	end

	task.defer(function()
		slotsFrame.CanvasSize = UDim2.fromOffset(0, slotsLayout.AbsoluteContentSize.Y + 12)
	end)

	local selectedId = selectedEntryIdByTab[currentTab]
	local selectedSlotIndex
	if selectedId then
		for index, entry in ipairs(currentEntries) do
			if entry.id == selectedId then
				selectedSlotIndex = index
				break
			end
		end
	end

	if not selectedSlotIndex and #currentEntries > 0 then
		selectedSlotIndex = 1
	end

	if selectedSlotIndex then
		setSelected(selectedSlotIndex)
	else
		selectedEntryIdByTab[currentTab] = nil
		applyDetails(nil)
		hideContextMenu()
	end
end

local function setActiveTab(tabId)
	if not TAB_CONFIGS[tabId] then
		return
	end
	if currentTab == tabId then
		refreshTabButtons()
		return
	end

	currentTab = tabId
	hideContextMenu()
	rebuildSlots()
end

for _, tabId in ipairs(TAB_ORDER) do
	local button = tabButtons[tabId]
	if button then
		button.MouseButton1Click:Connect(function()
			setActiveTab(tabId)
		end)
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

	spellSnapshot = payload.spells or spellSnapshot
	spellSnapshot.entries = spellSnapshot.entries or {}
	spellSnapshot.loadout = spellSnapshot.loadout or {}
	spellSnapshot.damageSummary = spellSnapshot.damageSummary or {}
	spellSnapshot.combinations = spellSnapshot.combinations or {}
	spellEntries = buildSpellEntries(spellSnapshot.entries)

	codexSnapshot = payload.codex or codexSnapshot
	codexSnapshot.entries = codexSnapshot.entries or {}
	codexSnapshot.counts = codexSnapshot.counts or {}
	codexEntries = buildCodexEntries(codexSnapshot.entries)

	updatePlayerInfo()
	rebuildSlots()
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

local function getSelectedEntryForCurrentTab()
	local selectedId = selectedEntryIdByTab[currentTab]
	if not selectedId then
		return nil
	end
	for _, entry in ipairs(currentEntries or {}) do
		if entry.id == selectedId then
			return entry
		end
	end
	return nil
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
	updatePlayerInfo()
	rebuildSlots()
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

spellEquipBtn.MouseButton1Click:Connect(function()
	if currentTab ~= "SpellLoadout" then return end
	local entry = getSelectedEntryForCurrentTab()
	if not entry or not entry.unlocked then return end
	if entry.equipped then
		fireInventoryAction("spellLoadoutUnequip", { productId = entry.productId or entry.id })
	else
		fireInventoryAction("spellLoadoutEquip", { productId = entry.productId or entry.id })
	end
	task.delay(0.2, loadSnapshot)
end)

spellMoveUpBtn.MouseButton1Click:Connect(function()
	if currentTab ~= "SpellLoadout" then return end
	local entry = getSelectedEntryForCurrentTab()
	if not entry or not entry.equipped then return end
	fireInventoryAction("spellLoadoutMove", { productId = entry.productId or entry.id, direction = -1 })
	task.delay(0.2, loadSnapshot)
end)

spellMoveDownBtn.MouseButton1Click:Connect(function()
	if currentTab ~= "SpellLoadout" then return end
	local entry = getSelectedEntryForCurrentTab()
	if not entry or not entry.equipped then return end
	fireInventoryAction("spellLoadoutMove", { productId = entry.productId or entry.id, direction = 1 })
	task.delay(0.2, loadSnapshot)
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
