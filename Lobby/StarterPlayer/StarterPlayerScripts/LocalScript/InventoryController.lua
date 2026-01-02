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

local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local GetInventorySnapshot = remoteFunctions:WaitForChild("RF_GetInventorySnapshot")

local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))
local Races = require(ReplicatedStorage:WaitForChild("Races"))

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

local playerPanel = Instance.new("Frame")
playerPanel.Position = UDim2.fromOffset(0, 0)
playerPanel.Size = UDim2.new(1, 0, 0, 250)
playerPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
playerPanel.BackgroundTransparency = 0.08
playerPanel.BorderSizePixel = 0
playerPanel.Parent = leftColumn
Instance.new("UICorner", playerPanel).CornerRadius = UDim.new(0, 12)
local playerPad = Instance.new("UIPadding", playerPanel)
playerPad.PaddingTop = UDim.new(0, 16)
playerPad.PaddingBottom = UDim.new(0, 16)
playerPad.PaddingLeft = UDim.new(0, 16)
playerPad.PaddingRight = UDim.new(0, 16)

local playerName = Instance.new("TextLabel")
playerName.BackgroundTransparency = 1
playerName.Size = UDim2.new(1, 0, 0, 20)
playerName.Font = Enum.Font.GothamBold
playerName.TextSize = 16
playerName.TextColor3 = Color3.fromRGB(240, 240, 240)
playerName.TextXAlignment = Enum.TextXAlignment.Left
playerName.Text = "PlayerName • Lv. 1"
playerName.Parent = playerPanel

local expLabel = Instance.new("TextLabel")
expLabel.BackgroundTransparency = 1
expLabel.Position = UDim2.fromOffset(0, 26)
expLabel.Size = UDim2.new(1, 0, 0, 14)
expLabel.Font = Enum.Font.Gotham
expLabel.TextSize = 12
expLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
expLabel.TextXAlignment = Enum.TextXAlignment.Left
expLabel.Text = "EXP: 0/0"
expLabel.Parent = playerPanel

local expBack = Instance.new("Frame")
expBack.Position = UDim2.fromOffset(0, 44)
expBack.Size = UDim2.new(1, 0, 0, 8)
expBack.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
expBack.BorderSizePixel = 0
expBack.Parent = playerPanel
Instance.new("UICorner", expBack).CornerRadius = UDim.new(0, 999)

local expFill = Instance.new("Frame")
expFill.Size = UDim2.new(0, 0, 1, 0)
expFill.BackgroundColor3 = Color3.fromRGB(96, 165, 250)
expFill.BorderSizePixel = 0
expFill.Parent = expBack
Instance.new("UICorner", expFill).CornerRadius = UDim.new(0, 999)

local raceLabel = Instance.new("TextLabel")
raceLabel.BackgroundTransparency = 1
raceLabel.Position = UDim2.fromOffset(0, 64)
raceLabel.Size = UDim2.new(1, 0, 0, 16)
raceLabel.Font = Enum.Font.Gotham
raceLabel.TextSize = 13
raceLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
raceLabel.TextXAlignment = Enum.TextXAlignment.Left
raceLabel.Text = "Race: -"
raceLabel.Parent = playerPanel

local buffsTitle = Instance.new("TextLabel")
buffsTitle.BackgroundTransparency = 1
buffsTitle.Position = UDim2.fromOffset(0, 88)
buffsTitle.Size = UDim2.new(1, 0, 0, 16)
buffsTitle.Font = Enum.Font.GothamBold
buffsTitle.TextSize = 13
buffsTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
buffsTitle.TextXAlignment = Enum.TextXAlignment.Left
buffsTitle.Text = "Race Buffs"
buffsTitle.Parent = playerPanel

local buffsList = Instance.new("Frame")
buffsList.BackgroundTransparency = 1
buffsList.Position = UDim2.fromOffset(0, 108)
buffsList.Size = UDim2.new(1, 0, 0, 92)
buffsList.Parent = playerPanel
local buffsLayout = Instance.new("UIListLayout", buffsList)
buffsLayout.Padding = UDim.new(0, 4)

local function makeBuffRow(labelText)
	local row = Instance.new("TextLabel")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 14)
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
	LIFESTEAL = makeBuffRow("Life Steal: -"),
	CRIT_RATE = makeBuffRow("Crit Rate: -"),
	CRIT_DMG = makeBuffRow("Crit DMG: -"),
	SPEED = makeBuffRow("Speed: -"),
}

local currenciesFrame = Instance.new("Frame")
currenciesFrame.BackgroundTransparency = 1
currenciesFrame.AnchorPoint = Vector2.new(0, 1)
currenciesFrame.Position = UDim2.new(0, 0, 1, 0)
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

local gridTitle = Instance.new("TextLabel")
gridTitle.BackgroundTransparency = 1
gridTitle.Size = UDim2.new(1, 0, 0, 20)
gridTitle.Font = Enum.Font.GothamBold
gridTitle.TextSize = 16
gridTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
gridTitle.TextXAlignment = Enum.TextXAlignment.Left
gridTitle.Text = "Inventory Slots"
gridTitle.Parent = rightPanel

local slotsFrame = Instance.new("ScrollingFrame")
slotsFrame.BackgroundTransparency = 1
slotsFrame.Position = UDim2.fromOffset(0, 30)
slotsFrame.Size = UDim2.new(1, 0, 1, -30)
slotsFrame.ScrollBarThickness = 6
slotsFrame.BorderSizePixel = 0
slotsFrame.CanvasSize = UDim2.fromOffset(0, 0)
slotsFrame.Parent = rightPanel

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
emptyLabel.Parent = rightPanel

local inventoryItems = {}
local selectedIndex
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
	buffRows.LIFESTEAL.Text = ("Life Steal: %+d%%"):format(getStat("LifeSteal"))
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

local slotWidgets = {}

local function setSelected(index)
	selectedIndex = index
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

	local item = inventoryItems[index]
	applyDetails(item and item.def)
end

local function rebuildSlots()
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

		addHover(slot, slot.BackgroundColor3, Color3.fromRGB(32, 32, 44))

		slot.MouseButton1Click:Connect(function()
			setSelected(index)
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

	updatePlayerInfo()
	rebuildSlots()
end

closeBtn.MouseButton1Click:Connect(function()
	inventoryGui.Enabled = false
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.B then
		inventoryGui.Enabled = not inventoryGui.Enabled
		if inventoryGui.Enabled then
			loadSnapshot()
		end
	end
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
