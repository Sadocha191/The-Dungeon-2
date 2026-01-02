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

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlayerProgressEvent = remoteEvents:WaitForChild("PlayerProgressEvent")
local InventoryAction = remoteEvents:WaitForChild("InventoryAction", 5)
local InventorySync = remoteEvents:WaitForChild("InventorySync", 5)

local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local GetInventorySnapshot = remoteFunctions:WaitForChild("RF_GetInventorySnapshot")

local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts")
local WeaponConfigs = require(moduleFolder:WaitForChild("WeaponConfigs"))
local Races = require(moduleFolder:WaitForChild("Races"))

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

local function rarityColor(rarity)
	local hex = WeaponConfigs.RarityColors and WeaponConfigs.RarityColors[rarity or ""]
	return hexToColor3(hex or "#B0B0B0")
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

local inventoryTemplate = StarterGui:FindFirstChild("InventoryGui")
if not inventoryTemplate then
	inventoryTemplate = Instance.new("ScreenGui")
	inventoryTemplate.Name = "InventoryGui"
	inventoryTemplate.ResetOnSpawn = false
	inventoryTemplate.IgnoreGuiInset = true
	inventoryTemplate.Enabled = false
	inventoryTemplate:SetAttribute("Modal", true)
	inventoryTemplate.Parent = StarterGui
end

local inventoryGui = inventoryTemplate:Clone()
inventoryGui.Enabled = false
inventoryGui.ResetOnSpawn = false
inventoryGui.IgnoreGuiInset = true
inventoryGui:SetAttribute("Modal", true)
inventoryGui.Parent = pg

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Parent = inventoryGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(980, 560)
panel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
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
playerPanel.Size = UDim2.new(1, 0, 0, 250)
playerPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
playerPanel.BackgroundTransparency = 0.08
playerPanel.BorderSizePixel = 0
playerPanel.ScrollBarThickness = 6
playerPanel.CanvasSize = UDim2.fromOffset(0, 0)
playerPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerPanel.Parent = leftColumn
Instance.new("UICorner", playerPanel).CornerRadius = UDim.new(0, 12)
local playerPad = Instance.new("UIPadding", playerPanel)
playerPad.PaddingTop = UDim.new(0, 16)
playerPad.PaddingBottom = UDim.new(0, 16)
playerPad.PaddingLeft = UDim.new(0, 16)
playerPad.PaddingRight = UDim.new(0, 16)
local playerLayout = Instance.new("UIListLayout", playerPanel)
playerLayout.Padding = UDim.new(0, 8)

local playerName = Instance.new("TextLabel")
playerName.BackgroundTransparency = 1
playerName.Size = UDim2.new(1, 0, 0, 20)
playerName.Font = Enum.Font.GothamBold
playerName.TextSize = 16
playerName.TextColor3 = Color3.fromRGB(240, 240, 240)
playerName.TextXAlignment = Enum.TextXAlignment.Left
playerName.Text = "PlayerName • Lv. 1"
playerName.Parent = playerPanel

local expWrap = Instance.new("Frame")
expWrap.BackgroundTransparency = 1
expWrap.Size = UDim2.new(1, 0, 0, 28)
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
raceLabel.Size = UDim2.new(1, 0, 0, 18)
raceLabel.Font = Enum.Font.GothamSemibold
raceLabel.TextSize = 12
raceLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
raceLabel.TextXAlignment = Enum.TextXAlignment.Left
raceLabel.Text = "Race: -"
raceLabel.Parent = playerPanel

local statsTitle = Instance.new("TextLabel")
statsTitle.BackgroundTransparency = 1
statsTitle.Size = UDim2.new(1, 0, 0, 16)
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextSize = 12
statsTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
statsTitle.TextXAlignment = Enum.TextXAlignment.Left
statsTitle.Text = "Stats"
statsTitle.Parent = playerPanel

local buffsList = Instance.new("Frame")
buffsList.BackgroundTransparency = 1
buffsList.Size = UDim2.new(1, 0, 0, 118)
buffsList.Parent = playerPanel
local buffsLayout = Instance.new("UIListLayout", buffsList)
buffsLayout.Padding = UDim.new(0, 2)

local function makeBuffRow(labelText)
	local row = Instance.new("TextLabel")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 16)
	row.Font = Enum.Font.Gotham
	row.TextSize = 12
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = Color3.fromRGB(200, 200, 200)
	row.Text = labelText
	row.Parent = buffsList
	return row
end

local buffRows = {
	HP = makeBuffRow("HP: -"),
	ATK = makeBuffRow("ATK: -"),
	DEF = makeBuffRow("DEF: -"),
	LIFESTEAL = makeBuffRow("Lifesteal: -"),
	CRIT_RATE = makeBuffRow("Crit Rate: -"),
	CRIT_DMG = makeBuffRow("Crit DMG: -"),
	SPEED = makeBuffRow("Speed: -"),
}

local currenciesFrame = Instance.new("Frame")
currenciesFrame.BackgroundTransparency = 1
currenciesFrame.Size = UDim2.new(1, 0, 0, 34)
currenciesFrame.Parent = playerPanel

local coinsLabel = Instance.new("TextLabel")
coinsLabel.BackgroundTransparency = 1
coinsLabel.Size = UDim2.new(1, 0, 0, 16)
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.TextSize = 13
coinsLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.Text = "Coins: 0"
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

local detailsPanel = Instance.new("Frame")
detailsPanel.Position = UDim2.fromOffset(0, 264)
detailsPanel.Size = UDim2.new(1, 0, 1, -264)
detailsPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
detailsPanel.BackgroundTransparency = 0.08
detailsPanel.BorderSizePixel = 0
detailsPanel.Parent = leftColumn
Instance.new("UICorner", detailsPanel).CornerRadius = UDim.new(0, 12)
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
detailsTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
detailsTitle.TextXAlignment = Enum.TextXAlignment.Left
detailsTitle.Text = "Selected Item Details"
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
iconFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
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

local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(1, -336, 1, 0)
rightPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
rightPanel.BackgroundTransparency = 0.08
rightPanel.BorderSizePixel = 0
rightPanel.Parent = body
Instance.new("UICorner", rightPanel).CornerRadius = UDim.new(0, 12)
local rightPad = Instance.new("UIPadding", rightPanel)
rightPad.PaddingTop = UDim.new(0, 16)
rightPad.PaddingBottom = UDim.new(0, 16)
rightPad.PaddingLeft = UDim.new(0, 16)
rightPad.PaddingRight = UDim.new(0, 16)

local gridPanel = Instance.new("Frame")
gridPanel.BackgroundTransparency = 1
gridPanel.Position = UDim2.fromOffset(0, 0)
gridPanel.Size = UDim2.new(1, 0, 1, -140)
gridPanel.Parent = rightPanel

local gridTitle = Instance.new("TextLabel")
gridTitle.BackgroundTransparency = 1
gridTitle.Size = UDim2.new(1, 0, 0, 20)
gridTitle.Font = Enum.Font.GothamBold
gridTitle.TextSize = 16
gridTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
gridTitle.TextXAlignment = Enum.TextXAlignment.Left
gridTitle.Text = "Inventory Slots"
gridTitle.Parent = gridPanel

local slotsFrame = Instance.new("ScrollingFrame")
slotsFrame.BackgroundTransparency = 1
slotsFrame.Position = UDim2.fromOffset(0, 30)
slotsFrame.Size = UDim2.new(1, 0, 1, -30)
slotsFrame.ScrollBarThickness = 6
slotsFrame.BorderSizePixel = 0
slotsFrame.CanvasSize = UDim2.fromOffset(0, 0)
slotsFrame.Parent = gridPanel

local slotsLayout = Instance.new("UIGridLayout", slotsFrame)
slotsLayout.CellPadding = UDim2.fromOffset(12, 12)
slotsLayout.CellSize = UDim2.fromOffset(110, 110)
slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local emptyLabel = Instance.new("TextLabel")
emptyLabel.BackgroundTransparency = 1
emptyLabel.Position = UDim2.fromOffset(0, 30)
emptyLabel.Size = UDim2.new(1, 0, 1, -30)
emptyLabel.Font = Enum.Font.Gotham
emptyLabel.TextSize = 14
emptyLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
emptyLabel.Text = "No weapons yet."
emptyLabel.TextWrapped = true
emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
emptyLabel.TextYAlignment = Enum.TextYAlignment.Center
emptyLabel.Visible = false
emptyLabel.Parent = gridPanel

local equippedPanel = Instance.new("Frame")
equippedPanel.AnchorPoint = Vector2.new(0, 1)
equippedPanel.Position = UDim2.new(0, 0, 1, 0)
equippedPanel.Size = UDim2.new(1, 0, 0, 120)
equippedPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
equippedPanel.BackgroundTransparency = 0.08
equippedPanel.BorderSizePixel = 0
equippedPanel.Parent = rightPanel
Instance.new("UICorner", equippedPanel).CornerRadius = UDim.new(0, 12)
local equippedPad = Instance.new("UIPadding", equippedPanel)
equippedPad.PaddingTop = UDim.new(0, 12)
equippedPad.PaddingBottom = UDim.new(0, 12)
equippedPad.PaddingLeft = UDim.new(0, 12)
equippedPad.PaddingRight = UDim.new(0, 12)

local equippedTitle = Instance.new("TextLabel")
equippedTitle.BackgroundTransparency = 1
equippedTitle.Size = UDim2.new(1, 0, 0, 18)
equippedTitle.Font = Enum.Font.GothamBold
equippedTitle.TextSize = 13
equippedTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
equippedTitle.TextXAlignment = Enum.TextXAlignment.Left
equippedTitle.Text = "Currently Equipped"
equippedTitle.Parent = equippedPanel

local equippedRow = Instance.new("Frame")
equippedRow.BackgroundTransparency = 1
equippedRow.Position = UDim2.fromOffset(0, 26)
equippedRow.Size = UDim2.new(1, 0, 1, -26)
equippedRow.Parent = equippedPanel

local equippedIcon = Instance.new("Frame")
equippedIcon.Size = UDim2.fromOffset(48, 48)
equippedIcon.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
equippedIcon.BorderSizePixel = 0
equippedIcon.Parent = equippedRow
Instance.new("UICorner", equippedIcon).CornerRadius = UDim.new(0, 10)
local equippedIconStroke = Instance.new("UIStroke", equippedIcon)
equippedIconStroke.Color = Color3.fromRGB(50, 50, 64)
equippedIconStroke.Thickness = 1

local equippedIconText = Instance.new("TextLabel")
equippedIconText.BackgroundTransparency = 1
equippedIconText.Size = UDim2.new(1, 0, 1, 0)
equippedIconText.Font = Enum.Font.GothamBold
equippedIconText.TextSize = 18
equippedIconText.TextColor3 = Color3.fromRGB(220, 220, 220)
equippedIconText.Text = "?"
equippedIconText.Parent = equippedIcon

local equippedName = Instance.new("TextLabel")
equippedName.BackgroundTransparency = 1
equippedName.Position = UDim2.fromOffset(60, 0)
equippedName.Size = UDim2.new(1, -60, 0, 20)
equippedName.Font = Enum.Font.GothamBold
equippedName.TextSize = 14
equippedName.TextColor3 = Color3.fromRGB(245, 245, 245)
equippedName.TextXAlignment = Enum.TextXAlignment.Left
equippedName.Text = "None"
equippedName.Parent = equippedRow

local equippedMeta = Instance.new("TextLabel")
equippedMeta.BackgroundTransparency = 1
equippedMeta.Position = UDim2.fromOffset(60, 22)
equippedMeta.Size = UDim2.new(1, -60, 0, 16)
equippedMeta.Font = Enum.Font.Gotham
equippedMeta.TextSize = 12
equippedMeta.TextColor3 = Color3.fromRGB(190, 190, 190)
equippedMeta.TextXAlignment = Enum.TextXAlignment.Left
equippedMeta.Text = "Rarity: -"
equippedMeta.Parent = equippedRow

local equippedLevel = Instance.new("TextLabel")
equippedLevel.BackgroundTransparency = 1
equippedLevel.Position = UDim2.fromOffset(60, 40)
equippedLevel.Size = UDim2.new(1, -60, 0, 16)
equippedLevel.Font = Enum.Font.Gotham
equippedLevel.TextSize = 12
equippedLevel.TextColor3 = Color3.fromRGB(170, 170, 170)
equippedLevel.TextXAlignment = Enum.TextXAlignment.Left
equippedLevel.Text = ""
equippedLevel.Visible = false
equippedLevel.Parent = equippedRow

local contextBlocker = Instance.new("TextButton")
contextBlocker.Size = UDim2.fromScale(1, 1)
contextBlocker.BackgroundTransparency = 1
contextBlocker.Text = ""
contextBlocker.AutoButtonColor = false
contextBlocker.Visible = false
contextBlocker.ZIndex = 30
contextBlocker.Parent = inventoryGui

local contextMenu = Instance.new("Frame")
contextMenu.Size = UDim2.fromOffset(200, 220)
contextMenu.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
contextMenu.BorderSizePixel = 0
contextMenu.Visible = false
contextMenu.ZIndex = 40
contextMenu.Parent = inventoryGui
Instance.new("UICorner", contextMenu).CornerRadius = UDim.new(0, 10)
local contextStroke = Instance.new("UIStroke", contextMenu)
contextStroke.Color = Color3.fromRGB(50, 50, 64)
contextStroke.Thickness = 1
local contextPad = Instance.new("UIPadding", contextMenu)
contextPad.PaddingTop = UDim.new(0, 8)
contextPad.PaddingBottom = UDim.new(0, 8)
contextPad.PaddingLeft = UDim.new(0, 8)
contextPad.PaddingRight = UDim.new(0, 8)
local contextLayout = Instance.new("UIListLayout", contextMenu)
contextLayout.Padding = UDim.new(0, 4)

local function makeContextButton(text)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 28)
	btn.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(230, 230, 230)
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = "  " .. text
	btn.AutoButtonColor = false
	btn.ZIndex = 41
	btn.Parent = contextMenu
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	addHover(btn, btn.BackgroundColor3, Color3.fromRGB(40, 40, 56))
	return btn
end

local equipAction = makeContextButton("Equip (Wyposaż)")
local sellAction = makeContextButton("Sell (Sprzedaj)")
local upgradeAction = makeContextButton("Upgrade (Ulepsz)")
local favoriteAction = makeContextButton("Add to Favorites (Dodaj do ulubionych)")
local infoAction = makeContextButton("Weapon Info (Informacje o broni)")

local infoOverlay = Instance.new("Frame")
infoOverlay.Size = UDim2.fromScale(1, 1)
infoOverlay.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
infoOverlay.BackgroundTransparency = 0.35
infoOverlay.BorderSizePixel = 0
infoOverlay.Visible = false
infoOverlay.ZIndex = 50
infoOverlay.Parent = inventoryGui

local infoCloseBackdrop = Instance.new("TextButton")
infoCloseBackdrop.Size = UDim2.fromScale(1, 1)
infoCloseBackdrop.BackgroundTransparency = 1
infoCloseBackdrop.Text = ""
infoCloseBackdrop.AutoButtonColor = false
infoCloseBackdrop.ZIndex = 51
infoCloseBackdrop.Parent = infoOverlay

local infoPanel = Instance.new("Frame")
infoPanel.AnchorPoint = Vector2.new(0.5, 0.5)
infoPanel.Position = UDim2.fromScale(0.5, 0.5)
infoPanel.Size = UDim2.fromOffset(420, 430)
infoPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
infoPanel.BorderSizePixel = 0
infoPanel.ZIndex = 52
infoPanel.Parent = infoOverlay
Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 14)
local infoStroke = Instance.new("UIStroke", infoPanel)
infoStroke.Color = Color3.fromRGB(44, 44, 56)
infoStroke.Thickness = 1
local infoPad = Instance.new("UIPadding", infoPanel)
infoPad.PaddingTop = UDim.new(0, 16)
infoPad.PaddingBottom = UDim.new(0, 16)
infoPad.PaddingLeft = UDim.new(0, 16)
infoPad.PaddingRight = UDim.new(0, 16)

local infoTitle = Instance.new("TextLabel")
infoTitle.BackgroundTransparency = 1
infoTitle.Size = UDim2.new(1, -32, 0, 22)
infoTitle.Font = Enum.Font.GothamBold
infoTitle.TextSize = 16
infoTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
infoTitle.TextXAlignment = Enum.TextXAlignment.Left
infoTitle.Text = "Weapon Info"
infoTitle.ZIndex = 53
infoTitle.Parent = infoPanel

local infoClose = Instance.new("TextButton")
infoClose.AnchorPoint = Vector2.new(1, 0)
infoClose.Position = UDim2.new(1, 0, 0, 0)
infoClose.Size = UDim2.fromOffset(24, 24)
infoClose.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
infoClose.BorderSizePixel = 0
infoClose.Font = Enum.Font.GothamBold
infoClose.TextSize = 12
infoClose.TextColor3 = Color3.fromRGB(220, 220, 220)
infoClose.Text = "X"
infoClose.ZIndex = 53
infoClose.Parent = infoPanel
Instance.new("UICorner", infoClose).CornerRadius = UDim.new(0, 8)
addHover(infoClose, infoClose.BackgroundColor3, Color3.fromRGB(40, 40, 52))

local infoScroll = Instance.new("ScrollingFrame")
infoScroll.BackgroundTransparency = 1
infoScroll.Position = UDim2.fromOffset(0, 30)
infoScroll.Size = UDim2.new(1, 0, 1, -30)
infoScroll.ScrollBarThickness = 6
infoScroll.BorderSizePixel = 0
infoScroll.CanvasSize = UDim2.fromOffset(0, 0)
infoScroll.ZIndex = 53
infoScroll.Parent = infoPanel
local infoLayout = Instance.new("UIListLayout", infoScroll)
infoLayout.Padding = UDim.new(0, 8)

local infoName = Instance.new("TextLabel")
infoName.BackgroundTransparency = 1
infoName.Size = UDim2.new(1, 0, 0, 22)
infoName.Font = Enum.Font.GothamBold
infoName.TextSize = 16
infoName.TextColor3 = Color3.fromRGB(245, 245, 245)
infoName.TextXAlignment = Enum.TextXAlignment.Left
infoName.TextWrapped = true
infoName.Text = "Weapon Name"
infoName.ZIndex = 54
infoName.Parent = infoScroll

local infoDesc = Instance.new("TextLabel")
infoDesc.BackgroundTransparency = 1
infoDesc.Size = UDim2.new(1, 0, 0, 40)
infoDesc.Font = Enum.Font.Gotham
infoDesc.TextSize = 12
infoDesc.TextColor3 = Color3.fromRGB(190, 190, 190)
infoDesc.TextXAlignment = Enum.TextXAlignment.Left
infoDesc.TextWrapped = true
infoDesc.Text = "-"
infoDesc.ZIndex = 54
infoDesc.Parent = infoScroll

local infoLineMeta = Instance.new("TextLabel")
infoLineMeta.BackgroundTransparency = 1
infoLineMeta.Size = UDim2.new(1, 0, 0, 18)
infoLineMeta.Font = Enum.Font.Gotham
infoLineMeta.TextSize = 12
infoLineMeta.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLineMeta.TextXAlignment = Enum.TextXAlignment.Left
infoLineMeta.Text = "Type: - | Rarity: -"
infoLineMeta.ZIndex = 54
infoLineMeta.Parent = infoScroll

local infoLineStats = Instance.new("TextLabel")
infoLineStats.BackgroundTransparency = 1
infoLineStats.Size = UDim2.new(1, 0, 0, 18)
infoLineStats.Font = Enum.Font.Gotham
infoLineStats.TextSize = 12
infoLineStats.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLineStats.TextXAlignment = Enum.TextXAlignment.Left
infoLineStats.Text = "Max Level: - | ATK: -"
infoLineStats.ZIndex = 54
infoLineStats.Parent = infoScroll

local infoBonus = Instance.new("TextLabel")
infoBonus.BackgroundTransparency = 1
infoBonus.Size = UDim2.new(1, 0, 0, 34)
infoBonus.Font = Enum.Font.Gotham
infoBonus.TextSize = 12
infoBonus.TextColor3 = Color3.fromRGB(190, 190, 190)
infoBonus.TextXAlignment = Enum.TextXAlignment.Left
infoBonus.TextWrapped = true
infoBonus.Text = "Bonus Stats: -"
infoBonus.ZIndex = 54
infoBonus.Parent = infoScroll

local infoPassiveTitle = Instance.new("TextLabel")
infoPassiveTitle.BackgroundTransparency = 1
infoPassiveTitle.Size = UDim2.new(1, 0, 0, 16)
infoPassiveTitle.Font = Enum.Font.GothamBold
infoPassiveTitle.TextSize = 12
infoPassiveTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
infoPassiveTitle.TextXAlignment = Enum.TextXAlignment.Left
infoPassiveTitle.Text = "Passive"
infoPassiveTitle.ZIndex = 54
infoPassiveTitle.Parent = infoScroll

local infoPassiveDesc = Instance.new("TextLabel")
infoPassiveDesc.BackgroundTransparency = 1
infoPassiveDesc.Size = UDim2.new(1, 0, 0, 40)
infoPassiveDesc.Font = Enum.Font.Gotham
infoPassiveDesc.TextSize = 12
infoPassiveDesc.TextColor3 = Color3.fromRGB(190, 190, 190)
infoPassiveDesc.TextXAlignment = Enum.TextXAlignment.Left
infoPassiveDesc.TextWrapped = true
infoPassiveDesc.Text = "-"
infoPassiveDesc.ZIndex = 54
infoPassiveDesc.Parent = infoScroll

local infoAbilityTitle = Instance.new("TextLabel")
infoAbilityTitle.BackgroundTransparency = 1
infoAbilityTitle.Size = UDim2.new(1, 0, 0, 16)
infoAbilityTitle.Font = Enum.Font.GothamBold
infoAbilityTitle.TextSize = 12
infoAbilityTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
infoAbilityTitle.TextXAlignment = Enum.TextXAlignment.Left
infoAbilityTitle.Text = "Ability"
infoAbilityTitle.ZIndex = 54
infoAbilityTitle.Parent = infoScroll

local infoAbilityDesc = Instance.new("TextLabel")
infoAbilityDesc.BackgroundTransparency = 1
infoAbilityDesc.Size = UDim2.new(1, 0, 0, 40)
infoAbilityDesc.Font = Enum.Font.Gotham
infoAbilityDesc.TextSize = 12
infoAbilityDesc.TextColor3 = Color3.fromRGB(190, 190, 190)
infoAbilityDesc.TextXAlignment = Enum.TextXAlignment.Left
infoAbilityDesc.TextWrapped = true
infoAbilityDesc.Text = "-"
infoAbilityDesc.ZIndex = 54
infoAbilityDesc.Parent = infoScroll

local upgradeOverlay = Instance.new("Frame")
upgradeOverlay.Size = UDim2.fromScale(1, 1)
upgradeOverlay.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
upgradeOverlay.BackgroundTransparency = 0.35
upgradeOverlay.BorderSizePixel = 0
upgradeOverlay.Visible = false
upgradeOverlay.ZIndex = 50
upgradeOverlay.Parent = inventoryGui

local upgradeCloseBackdrop = Instance.new("TextButton")
upgradeCloseBackdrop.Size = UDim2.fromScale(1, 1)
upgradeCloseBackdrop.BackgroundTransparency = 1
upgradeCloseBackdrop.Text = ""
upgradeCloseBackdrop.AutoButtonColor = false
upgradeCloseBackdrop.ZIndex = 51
upgradeCloseBackdrop.Parent = upgradeOverlay

local upgradePanel = Instance.new("Frame")
upgradePanel.AnchorPoint = Vector2.new(0.5, 0.5)
upgradePanel.Position = UDim2.fromScale(0.5, 0.5)
upgradePanel.Size = UDim2.fromOffset(320, 180)
upgradePanel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
upgradePanel.BorderSizePixel = 0
upgradePanel.ZIndex = 52
upgradePanel.Parent = upgradeOverlay
Instance.new("UICorner", upgradePanel).CornerRadius = UDim.new(0, 14)
local upgradeStroke = Instance.new("UIStroke", upgradePanel)
upgradeStroke.Color = Color3.fromRGB(44, 44, 56)
upgradeStroke.Thickness = 1
local upgradePad = Instance.new("UIPadding", upgradePanel)
upgradePad.PaddingTop = UDim.new(0, 16)
upgradePad.PaddingBottom = UDim.new(0, 16)
upgradePad.PaddingLeft = UDim.new(0, 16)
upgradePad.PaddingRight = UDim.new(0, 16)

local upgradeTitle = Instance.new("TextLabel")
upgradeTitle.BackgroundTransparency = 1
upgradeTitle.Size = UDim2.new(1, -32, 0, 22)
upgradeTitle.Font = Enum.Font.GothamBold
upgradeTitle.TextSize = 16
upgradeTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
upgradeTitle.TextXAlignment = Enum.TextXAlignment.Left
upgradeTitle.Text = "Upgrade (Placeholder)"
upgradeTitle.ZIndex = 53
upgradeTitle.Parent = upgradePanel

local upgradeClose = Instance.new("TextButton")
upgradeClose.AnchorPoint = Vector2.new(1, 0)
upgradeClose.Position = UDim2.new(1, 0, 0, 0)
upgradeClose.Size = UDim2.fromOffset(24, 24)
upgradeClose.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
upgradeClose.BorderSizePixel = 0
upgradeClose.Font = Enum.Font.GothamBold
upgradeClose.TextSize = 12
upgradeClose.TextColor3 = Color3.fromRGB(220, 220, 220)
upgradeClose.Text = "X"
upgradeClose.ZIndex = 53
upgradeClose.Parent = upgradePanel
Instance.new("UICorner", upgradeClose).CornerRadius = UDim.new(0, 8)
addHover(upgradeClose, upgradeClose.BackgroundColor3, Color3.fromRGB(40, 40, 52))

local upgradeBody = Instance.new("TextLabel")
upgradeBody.BackgroundTransparency = 1
upgradeBody.Position = UDim2.fromOffset(0, 36)
upgradeBody.Size = UDim2.new(1, 0, 1, -36)
upgradeBody.Font = Enum.Font.Gotham
upgradeBody.TextSize = 12
upgradeBody.TextColor3 = Color3.fromRGB(190, 190, 190)
upgradeBody.TextXAlignment = Enum.TextXAlignment.Left
upgradeBody.TextWrapped = true
upgradeBody.Text = "Upgrade flow will be available soon."
upgradeBody.ZIndex = 53
upgradeBody.Parent = upgradePanel

local inventoryItems = {}
local selectedIndex
local selectedWeaponId
local equippedWeaponId
local weaponPoints = 0
local level, xp, nextXp, coins = 1, 0, 120, 0

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

local function refreshRaceBuffs(raceName)
	local def = Races.Defs and Races.Defs[raceName or ""]
	local stats = def and def.stats or {}
	local function getStat(...)
		for _, key in ipairs({ ... }) do
			local value = stats[key]
			if value ~= nil then
				return value
			end
		end
		return 0
	end

	buffRows.HP.Text = ("HP: %+d"):format(getStat("HP"))
	buffRows.ATK.Text = ("ATK: %+d"):format(getStat("PhysicalPower", "MagicPower", "STR"))
	buffRows.DEF.Text = ("DEF: %+d"):format(getStat("Armor"))
	buffRows.LIFESTEAL.Text = ("Lifesteal: %+d%%"):format(getStat("LifeSteal"))
	buffRows.CRIT_RATE.Text = ("Crit Rate: %+d%%"):format(getStat("CritChance"))
	buffRows.CRIT_DMG.Text = ("Crit DMG: %+d%%"):format(getStat("CritDmg"))
	buffRows.SPEED.Text = ("Speed: %+d%%"):format(getStat("MoveSpeed", "AttackSpeed"))
end

local function updatePlayerInfo()
	playerName.Text = ("%s • Lv. %d"):format(plr.Name, level)
	expLabel.Text = ("EXP: %d/%d"):format(xp, math.max(1, nextXp))
	local pct = math.clamp(xp / math.max(1, nextXp), 0, 1)
	TweenService:Create(expFill, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(pct, 0, 1, 0),
	}):Play()
	local raceName = tostring(plr:GetAttribute("Race") or "-")
	raceLabel.Text = ("Race: %s"):format(raceName)
	refreshRaceBuffs(raceName)
	coinsLabel.Text = ("Coins: %d"):format(coins)
	wpLabel.Text = ("WP: %d"):format(weaponPoints)
end

local function applyDetails(def)
	if not def then
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
		updateDetailsCanvas()
		return
	end

	local rarity = def.rarity or "Common"
	local color = rarityColor(rarity)
	itemName.Text = def.name or def.id or "Unknown"
	itemName.TextColor3 = color

	local description = def.description or def.passiveDescription or def.abilityDescription or "Brak opisu."
	itemDesc.Text = description
	infoLine.Text = ("Type: %s | Rarity: %s"):format(def.weaponType or "-", rarity)
	infoLine.TextColor3 = color
	statLine.Text = ("Max Level: %s | ATK: %s"):format(tostring(def.maxLevel or "-"), tostring(def.baseDamage or "-"))
	bonusStats.Text = formatStats(def.stats)

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
	iconStroke.Color = color

	updateDetailsCanvas()
end

local function updateEquippedPanel()
	local equippedItem
	if equippedWeaponId then
		for _, item in ipairs(inventoryItems) do
			if item.id == equippedWeaponId then
				equippedItem = item
				break
			end
		end
	end

	if not equippedItem or not equippedItem.def then
		equippedName.Text = "None"
		equippedName.TextColor3 = Color3.fromRGB(245, 245, 245)
		equippedMeta.Text = "Rarity: -"
		equippedMeta.TextColor3 = Color3.fromRGB(190, 190, 190)
		equippedLevel.Text = ""
		equippedLevel.Visible = false
		equippedIconText.Text = "?"
		equippedIconStroke.Color = Color3.fromRGB(50, 50, 64)
		return
	end

	local def = equippedItem.def
	local rarity = def.rarity or "Common"
	local color = rarityColor(rarity)
	equippedName.Text = def.name or equippedItem.id or "Unknown"
	equippedName.TextColor3 = color
	equippedMeta.Text = ("Rarity: %s"):format(rarity)
	equippedMeta.TextColor3 = color
	equippedIconText.Text = def.weaponType and def.weaponType:sub(1, 1) or "?"
	equippedIconStroke.Color = color

	local levelText = equippedItem.level and ("Lv. %s"):format(tostring(equippedItem.level)) or ""
	equippedLevel.Text = levelText
	equippedLevel.Visible = levelText ~= ""
end

local function updateInfoCanvas()
	task.defer(function()
		infoScroll.CanvasSize = UDim2.fromOffset(0, infoLayout.AbsoluteContentSize.Y + 8)
	end)
end

local function openWeaponInfo(def)
	if not def then return end
	local rarity = def.rarity or "Common"
	local color = rarityColor(rarity)
	infoName.Text = def.name or def.id or "Unknown"
	infoName.TextColor3 = color
	infoDesc.Text = def.description or def.passiveDescription or def.abilityDescription or "Brak opisu."
	infoLineMeta.Text = ("Type: %s | Rarity: %s"):format(def.weaponType or "-", rarity)
	infoLineMeta.TextColor3 = color
	infoLineStats.Text = ("Max Level: %s | ATK: %s"):format(tostring(def.maxLevel or "-"), tostring(def.baseDamage or "-"))
	infoBonus.Text = formatStats(def.stats)

	local passiveName = def.passiveName or ""
	if passiveName ~= "" then
		infoPassiveTitle.Text = ("Passive: %s"):format(passiveName)
		infoPassiveDesc.Text = def.passiveDescription or "-"
	else
		infoPassiveTitle.Text = "Passive"
		infoPassiveDesc.Text = "-"
	end

	local abilityName = def.abilityName or ""
	if abilityName ~= "" then
		infoAbilityTitle.Text = ("Ability: %s"):format(abilityName)
		infoAbilityDesc.Text = def.abilityDescription or "-"
	else
		infoAbilityTitle.Text = "Ability"
		infoAbilityDesc.Text = "-"
	end

	updateInfoCanvas()
	infoOverlay.Visible = true
end

local function closeWeaponInfo()
	infoOverlay.Visible = false
end

local function openUpgradePlaceholder(item)
	local name = item and item.def and item.def.name or item and item.id or "weapon"
	upgradeBody.Text = ("Upgrade flow for %s will be available soon."):format(name)
	upgradeOverlay.Visible = true
end

local function closeUpgradePlaceholder()
	upgradeOverlay.Visible = false
end

local contextItemIndex

local function closeContextMenu()
	contextItemIndex = nil
	contextMenu.Visible = false
	contextBlocker.Visible = false
end

local function openContextMenu(index)
	local item = inventoryItems[index]
	if not item then return end
	contextItemIndex = index
	local isFavorite = item.isFavorite == true
	favoriteAction.Text = "  " .. (isFavorite and "Remove from Favorites (Usuń z ulubionych)" or "Add to Favorites (Dodaj do ulubionych)")

	contextBlocker.Visible = true
	contextMenu.Visible = true

	task.defer(function()
		local mousePos = UserInputService:GetMouseLocation()
		local guiSize = inventoryGui.AbsoluteSize
		local menuSize = contextMenu.AbsoluteSize
		local x = math.clamp(mousePos.X, 8, guiSize.X - menuSize.X - 8)
		local y = math.clamp(mousePos.Y, 8, guiSize.Y - menuSize.Y - 8)
		contextMenu.Position = UDim2.fromOffset(x, y)
	end)
end

local function setItemFavorite(index, isFavorite)
	local item = inventoryItems[index]
	if not item then return end
	item.isFavorite = isFavorite
	local slot = slotWidgets[index]
	if slot then
		local favoriteIcon = slot:FindFirstChild("FavoriteIcon")
		if favoriteIcon and favoriteIcon:IsA("TextLabel") then
			favoriteIcon.Visible = isFavorite
		end
	end
end

local slotWidgets = {}

local function setSelected(index)
	selectedIndex = index
	local selectedItem = inventoryItems[index]
	selectedWeaponId = selectedItem and selectedItem.id or nil
	for i, slot in ipairs(slotWidgets) do
		local selected = i == index
		local stroke = slot:FindFirstChild("Stroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = selected and Color3.fromRGB(96, 165, 250) or Color3.fromRGB(50, 50, 64)
			stroke.Thickness = selected and 2 or 1
		end
		local glow = slot:FindFirstChild("SelectedGlow")
		if glow and glow:IsA("Frame") then
			glow.Visible = selected
		end
	end

	applyDetails(selectedItem and selectedItem.def)
end

local function rebuildSlots()
	local previousSelectedId = selectedWeaponId
	for _, child in ipairs(slotsFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	slotWidgets = {}

	emptyLabel.Visible = #inventoryItems == 0

	for index, item in ipairs(inventoryItems) do
		local def = item.def
		local slot = Instance.new("TextButton")
		slot.Name = "Slot_" .. index
		slot.Size = UDim2.fromOffset(110, 110)
		slot.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
		slot.BorderSizePixel = 0
		slot.Text = ""
		slot.AutoButtonColor = false
		slot.Parent = slotsFrame
		Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 12)

		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Color = Color3.fromRGB(50, 50, 64)
		stroke.Thickness = 1
		stroke.Parent = slot

		local glow = Instance.new("Frame")
		glow.Name = "SelectedGlow"
		glow.Size = UDim2.new(1, 0, 1, 0)
		glow.BackgroundColor3 = Color3.fromRGB(60, 140, 255)
		glow.BackgroundTransparency = 0.85
		glow.BorderSizePixel = 0
		glow.Visible = false
		glow.Parent = slot
		Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 12)

		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Position = UDim2.fromOffset(8, 8)
		icon.Size = UDim2.fromOffset(28, 28)
		icon.Font = Enum.Font.GothamBold
		icon.TextSize = 14
		icon.TextColor3 = Color3.fromRGB(220, 220, 220)
		icon.Text = def and def.weaponType and def.weaponType:sub(1, 1) or "?"
		icon.Parent = slot

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(8, 40)
		name.Size = UDim2.new(1, -16, 0, 40)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 12
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.TextWrapped = true
		name.TextColor3 = def and rarityColor(def.rarity) or Color3.fromRGB(220, 220, 220)
		name.Text = def and def.name or item.id
		name.Parent = slot

		local rarityTag = Instance.new("TextLabel")
		rarityTag.BackgroundTransparency = 1
		rarityTag.AnchorPoint = Vector2.new(0, 1)
		rarityTag.Position = UDim2.new(0, 8, 1, -8)
		rarityTag.Size = UDim2.new(1, -16, 0, 14)
		rarityTag.Font = Enum.Font.Gotham
		rarityTag.TextSize = 11
		rarityTag.TextXAlignment = Enum.TextXAlignment.Left
		rarityTag.TextColor3 = def and rarityColor(def.rarity) or Color3.fromRGB(180, 180, 180)
		rarityTag.Text = def and (def.rarity or "") or ""
		rarityTag.Parent = slot

		local favoriteIcon = Instance.new("TextLabel")
		favoriteIcon.Name = "FavoriteIcon"
		favoriteIcon.BackgroundTransparency = 1
		favoriteIcon.AnchorPoint = Vector2.new(1, 0)
		favoriteIcon.Position = UDim2.new(1, -8, 0, 8)
		favoriteIcon.Size = UDim2.fromOffset(16, 16)
		favoriteIcon.Font = Enum.Font.GothamBold
		favoriteIcon.TextSize = 14
		favoriteIcon.TextColor3 = Color3.fromRGB(255, 214, 102)
		favoriteIcon.Text = "★"
		favoriteIcon.Visible = item.isFavorite == true
		favoriteIcon.Parent = slot

		addHover(slot, slot.BackgroundColor3, Color3.fromRGB(32, 32, 44))

		slot.MouseButton1Click:Connect(function()
			setSelected(index)
		end)
		slot.MouseButton2Click:Connect(function()
			setSelected(index)
			openContextMenu(index)
		end)

		slotWidgets[index] = slot
	end

	task.defer(function()
		slotsFrame.CanvasSize = UDim2.fromOffset(0, slotsLayout.AbsoluteContentSize.Y + 12)
	end)

	if #inventoryItems > 0 then
		local desiredIndex = selectedIndex
		if previousSelectedId then
			for idx, item in ipairs(inventoryItems) do
				if item.id == previousSelectedId then
					desiredIndex = idx
					break
				end
			end
		end
		if not desiredIndex or not inventoryItems[desiredIndex] then
			desiredIndex = 1
		end
		setSelected(desiredIndex)
	else
		applyDetails(nil)
	end
	updateEquippedPanel()
end

local function loadSnapshot()
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
	coins = tonumber(currencies.Coins) or coins
	weaponPoints = tonumber(currencies.WeaponPoints) or weaponPoints

	updatePlayerInfo()
	if not InventorySync then
		inventoryItems = {}
		for _, entry in ipairs(payload.weapons or {}) do
			local weaponId = entry.WeaponId or entry.weaponId or entry.id or entry
			if typeof(weaponId) == "string" and weaponId ~= "" then
				local def = WeaponConfigs.Get(weaponId)
				table.insert(inventoryItems, {
					id = weaponId,
					def = def,
				})
			end
		end
		equippedWeaponId = nil
		rebuildSlots()
	else
		updateEquippedPanel()
	end
end

closeBtn.MouseButton1Click:Connect(function()
	inventoryGui.Enabled = false
	closeContextMenu()
	closeWeaponInfo()
	closeUpgradePlaceholder()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape then
		if contextMenu.Visible then
			closeContextMenu()
		end
		if infoOverlay.Visible then
			closeWeaponInfo()
		end
		if upgradeOverlay.Visible then
			closeUpgradePlaceholder()
		end
	end
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.B then
		inventoryGui.Enabled = not inventoryGui.Enabled
		if inventoryGui.Enabled then
			loadSnapshot()
			if InventoryAction then
				InventoryAction:FireServer({ type = "request" })
			end
		end
	end
end)

if InventorySync then
	InventorySync.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		equippedWeaponId = payload.equippedId
		inventoryItems = {}
		for _, entry in ipairs(payload.items or {}) do
			local weaponId = entry.id or entry.WeaponId or entry.weaponId or entry.name
			if typeof(weaponId) == "string" and weaponId ~= "" then
				local def = WeaponConfigs.Get(weaponId)
				table.insert(inventoryItems, {
					id = weaponId,
					def = def,
					isFavorite = entry.favorite == true,
					level = entry.level or entry.Level,
				})
			end
		end
		rebuildSlots()
	end)
end

contextBlocker.MouseButton1Click:Connect(closeContextMenu)
contextBlocker.MouseButton2Click:Connect(closeContextMenu)
infoClose.MouseButton1Click:Connect(closeWeaponInfo)
infoCloseBackdrop.MouseButton1Click:Connect(closeWeaponInfo)
upgradeClose.MouseButton1Click:Connect(closeUpgradePlaceholder)
upgradeCloseBackdrop.MouseButton1Click:Connect(closeUpgradePlaceholder)

equipAction.MouseButton1Click:Connect(function()
	local item = contextItemIndex and inventoryItems[contextItemIndex]
	if not item then return end
	if InventoryAction then
		InventoryAction:FireServer({ type = "equip", id = item.id })
	end
	equippedWeaponId = item.id
	updateEquippedPanel()
	closeContextMenu()
end)

sellAction.MouseButton1Click:Connect(function()
	local item = contextItemIndex and inventoryItems[contextItemIndex]
	if not item then return end
	if InventoryAction then
		InventoryAction:FireServer({ type = "sell", id = item.id })
	else
		table.remove(inventoryItems, contextItemIndex)
		rebuildSlots()
	end
	closeContextMenu()
end)

upgradeAction.MouseButton1Click:Connect(function()
	local item = contextItemIndex and inventoryItems[contextItemIndex]
	if not item then return end
	closeContextMenu()
	openUpgradePlaceholder(item)
end)

favoriteAction.MouseButton1Click:Connect(function()
	local item = contextItemIndex and inventoryItems[contextItemIndex]
	if not item then return end
	local newValue = not item.isFavorite
	setItemFavorite(contextItemIndex, newValue)
	if InventoryAction then
		InventoryAction:FireServer({ type = "favorite", id = item.id, value = newValue })
	end
	closeContextMenu()
end)

infoAction.MouseButton1Click:Connect(function()
	local item = contextItemIndex and inventoryItems[contextItemIndex]
	if not item then return end
	closeContextMenu()
	openWeaponInfo(item.def)
end)

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

plr:GetAttributeChangedSignal("Race"):Connect(function()
	if inventoryGui.Enabled then
		updatePlayerInfo()
	end
end)

print("[InventoryController] Ready")
