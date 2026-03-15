local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenBlacksmithUI = remoteEvents:WaitForChild("OpenBlacksmithUI")
local BlacksmithSync = remoteEvents:WaitForChild("BlacksmithSync")
local BlacksmithAction = remoteEvents:WaitForChild("BlacksmithAction")

local rarityColors = {
	Common = Color3.fromRGB(176, 184, 198),
	Rare = Color3.fromRGB(100, 165, 255),
	Epic = Color3.fromRGB(190, 120, 255),
	Legendary = Color3.fromRGB(255, 196, 96),
	Mythical = Color3.fromRGB(255, 110, 118),
}

local function blendColor(fromColor, toColor, alpha)
	return Color3.new(
		fromColor.R + (toColor.R - fromColor.R) * alpha,
		fromColor.G + (toColor.G - fromColor.G) * alpha,
		fromColor.B + (toColor.B - fromColor.B) * alpha
	)
end

local function getRarityColor(rarity)
	return rarityColors[tostring(rarity or "")] or rarityColors.Common
end

local gui = Instance.new("ScreenGui")
gui.Name = "BlacksmithGui"
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.4
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.9, 0.9)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)
local panelSizeConstraint = Instance.new("UISizeConstraint", panel)
panelSizeConstraint.MaxSize = Vector2.new(1100, 640)
local panelAspect = Instance.new("UIAspectRatioConstraint", panel)
panelAspect.AspectRatio = 1100 / 640
panelAspect.DominantAxis = Enum.DominantAxis.Height
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color = Color3.fromRGB(46, 54, 70)
panelStroke.Thickness = 1

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 18)
title.Size = UDim2.fromOffset(400, 28)
title.Font = Enum.Font.GothamBlack
title.TextSize = 22
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.Text = "Blacksmith"
title.Parent = panel

local subTitle = Instance.new("TextLabel")
subTitle.BackgroundTransparency = 1
subTitle.Position = UDim2.fromOffset(24, 48)
subTitle.Size = UDim2.fromOffset(520, 20)
subTitle.Font = Enum.Font.Gotham
subTitle.TextSize = 12
subTitle.TextXAlignment = Enum.TextXAlignment.Left
subTitle.TextColor3 = Color3.fromRGB(190, 190, 190)
subTitle.Text = "Found recipes only. Mine resources and mob materials are tracked separately."
subTitle.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -18, 0, 18)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.BackgroundColor3 = Color3.fromRGB(34, 36, 44)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(235, 235, 235)
closeBtn.Text = "X"
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)

local summary = Instance.new("Frame")
summary.Position = UDim2.fromOffset(24, 82)
summary.Size = UDim2.new(1, -48, 0, 96)
summary.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
summary.BorderSizePixel = 0
summary.Parent = panel
Instance.new("UICorner", summary).CornerRadius = UDim.new(0, 14)
local summaryStroke = Instance.new("UIStroke", summary)
summaryStroke.Color = Color3.fromRGB(46, 54, 70)
summaryStroke.Thickness = 1

local topInfo = Instance.new("TextLabel")
topInfo.BackgroundTransparency = 1
topInfo.Position = UDim2.fromOffset(16, 10)
topInfo.Size = UDim2.new(1, -32, 0, 18)
topInfo.Font = Enum.Font.GothamBold
topInfo.TextSize = 13
topInfo.TextXAlignment = Enum.TextXAlignment.Left
topInfo.TextColor3 = Color3.fromRGB(240, 240, 240)
topInfo.Text = "Account Lv 1 | Silver 0"
topInfo.Parent = summary

local mineLabel = Instance.new("TextLabel")
mineLabel.BackgroundTransparency = 1
mineLabel.Position = UDim2.fromOffset(16, 34)
mineLabel.Size = UDim2.new(0.32, -12, 1, -44)
mineLabel.Font = Enum.Font.Gotham
mineLabel.TextSize = 12
mineLabel.TextWrapped = true
mineLabel.TextXAlignment = Enum.TextXAlignment.Left
mineLabel.TextYAlignment = Enum.TextYAlignment.Top
mineLabel.TextColor3 = Color3.fromRGB(214, 214, 214)
mineLabel.Text = "Mine Resources:\n-"
mineLabel.Parent = summary

local mobLabel = Instance.new("TextLabel")
mobLabel.BackgroundTransparency = 1
mobLabel.Position = UDim2.new(0.34, 0, 0, 34)
mobLabel.Size = UDim2.new(0.32, -12, 1, -44)
mobLabel.Font = Enum.Font.Gotham
mobLabel.TextSize = 12
mobLabel.TextWrapped = true
mobLabel.TextXAlignment = Enum.TextXAlignment.Left
mobLabel.TextYAlignment = Enum.TextYAlignment.Top
mobLabel.TextColor3 = Color3.fromRGB(214, 214, 214)
mobLabel.Text = "Mob Materials:\n-"
mobLabel.Parent = summary

local upgradeMatLabel = Instance.new("TextLabel")
upgradeMatLabel.BackgroundTransparency = 1
upgradeMatLabel.Position = UDim2.new(0.68, 0, 0, 34)
upgradeMatLabel.Size = UDim2.new(0.32, -16, 1, -44)
upgradeMatLabel.Font = Enum.Font.Gotham
upgradeMatLabel.TextSize = 12
upgradeMatLabel.TextWrapped = true
upgradeMatLabel.TextXAlignment = Enum.TextXAlignment.Left
upgradeMatLabel.TextYAlignment = Enum.TextYAlignment.Top
upgradeMatLabel.TextColor3 = Color3.fromRGB(214, 214, 214)
upgradeMatLabel.Text = "Upgrade Materials:\n-"
upgradeMatLabel.Parent = summary

local tabBar = Instance.new("Frame")
tabBar.Position = UDim2.fromOffset(24, 194)
tabBar.Size = UDim2.fromOffset(360, 42)
tabBar.BackgroundTransparency = 1
tabBar.Parent = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabBar

local function createTabButton(text)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(110, 42)
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

local tabButtons = {
	Craft = createTabButton("Craft"),
	Upgrade = createTabButton("Upgrade"),
	Sell = createTabButton("Sell"),
}

local listFrame = Instance.new("ScrollingFrame")
listFrame.Position = UDim2.fromOffset(24, 246)
listFrame.Size = UDim2.fromOffset(420, 330)
listFrame.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 6
listFrame.Parent = panel
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 14)
local listStroke = Instance.new("UIStroke", listFrame)
listStroke.Color = Color3.fromRGB(46, 54, 70)
listStroke.Thickness = 1

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = listFrame

local emptyLabel = Instance.new("TextLabel")
emptyLabel.BackgroundTransparency = 1
emptyLabel.Position = UDim2.fromOffset(16, 14)
emptyLabel.Size = UDim2.new(1, -32, 1, -28)
emptyLabel.Font = Enum.Font.Gotham
emptyLabel.TextSize = 14
emptyLabel.TextWrapped = true
emptyLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
emptyLabel.Text = "Nothing to show in this tab yet."
emptyLabel.Visible = false
emptyLabel.Parent = listFrame

local details = Instance.new("Frame")
details.Position = UDim2.fromOffset(460, 246)
details.Size = UDim2.new(1, -484, 0, 330)
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
detailTitle.Size = UDim2.new(1, -36, 0, 22)
detailTitle.Font = Enum.Font.GothamBold
detailTitle.TextSize = 17
detailTitle.TextXAlignment = Enum.TextXAlignment.Left
detailTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
detailTitle.Text = "Select an entry"
detailTitle.Parent = details

local detailBody = Instance.new("TextLabel")
detailBody.BackgroundTransparency = 1
detailBody.Position = UDim2.fromOffset(18, 46)
detailBody.Size = UDim2.new(1, -36, 1, -124)
detailBody.Font = Enum.Font.Gotham
detailBody.TextSize = 12
detailBody.TextWrapped = true
detailBody.TextXAlignment = Enum.TextXAlignment.Left
detailBody.TextYAlignment = Enum.TextYAlignment.Top
detailBody.TextColor3 = Color3.fromRGB(220, 220, 220)
detailBody.Text = "Select an entry from the list."
detailBody.Parent = details

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.fromOffset(18, 272)
statusLabel.Size = UDim2.new(1, -36, 0, 18)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
statusLabel.Text = ""
statusLabel.Parent = details

local function createActionButton(text, x)
	local button = Instance.new("TextButton")
	button.Position = UDim2.fromOffset(x, 294)
	button.Size = UDim2.fromOffset(180, 38)
	button.BackgroundColor3 = Color3.fromRGB(42, 44, 54)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(240, 240, 240)
	button.Text = text
	button.Parent = details
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke", button)
	stroke.Name = "ButtonStroke"
	stroke.Color = Color3.fromRGB(56, 64, 82)
	stroke.Thickness = 1
	return button
end

local primaryButton = createActionButton("Action", 18)
local secondaryButton = createActionButton("Action", 210)

local footer = Instance.new("TextLabel")
footer.BackgroundTransparency = 1
footer.Position = UDim2.fromOffset(24, 590)
footer.Size = UDim2.new(1, -48, 0, 20)
footer.Font = Enum.Font.Gotham
footer.TextSize = 12
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.TextColor3 = Color3.fromRGB(158, 158, 158)
footer.Text = "Crafting uses recipes + mob materials + mine resources. Upgrading uses Silver + upgrade materials."
footer.Parent = panel

local snapshot = nil
local activeTab = "Craft"
local lastActionMessage = nil
local lastActionOk = nil
local selectedKeys = {
	Craft = nil,
	Upgrade = nil,
	Sell = nil,
}

local function getEntryRarity(entry)
	if typeof(entry) ~= "table" then
		return "Common"
	end
	return tostring(entry.rarity or "Common")
end

local function applyEntryTheme(entry)
	local accent = entry and getRarityColor(getEntryRarity(entry)) or Color3.fromRGB(96, 165, 250)
	detailAccent.BackgroundColor3 = accent
	detailsStroke.Color = blendColor(Color3.fromRGB(46, 54, 70), accent, 0.45)
	listStroke.Color = blendColor(Color3.fromRGB(46, 54, 70), accent, 0.28)
	summaryStroke.Color = blendColor(Color3.fromRGB(46, 54, 70), accent, 0.22)
	detailTitle.TextColor3 = entry and accent or Color3.fromRGB(245, 245, 245)
end

local function setButtonState(button, enabled, text, accent)
	local color = accent or Color3.fromRGB(96, 165, 250)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundColor3 = enabled and blendColor(Color3.fromRGB(42, 44, 54), color, 0.45) or Color3.fromRGB(42, 44, 54)
	button.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
	button.Text = text
	local stroke = button:FindFirstChild("ButtonStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = enabled and blendColor(Color3.fromRGB(56, 64, 82), color, 0.7) or Color3.fromRGB(56, 64, 82)
	end
end

local function formatResourceLines(label, list)
	if typeof(list) ~= "table" or #list == 0 then
		if label == "" then
			return "-"
		end
		return label .. ":\n-"
	end
	local parts = {}
	for index, entry in ipairs(list) do
		parts[index] = string.format("%s x%d", tostring(entry.id), tonumber(entry.amount) or 0)
	end
	if label == "" then
		return table.concat(parts, ", ")
	end
	return label .. ":\n" .. table.concat(parts, ", ")
end

local function getEntriesForTab()
	if not snapshot then
		return {}
	end
	if activeTab == "Craft" then
		return snapshot.craftEntries or {}
	end
	if activeTab == "Upgrade" then
		return snapshot.upgradeEntries or {}
	end
	return snapshot.sellEntries or {}
end

local function getEntryKey(entry)
	if activeTab == "Craft" then
		return entry.recipeId
	end
	return entry.instanceId
end

local function getSelectedEntry()
	local entries = getEntriesForTab()
	local selectedKey = selectedKeys[activeTab]
	for _, entry in ipairs(entries) do
		if getEntryKey(entry) == selectedKey then
			return entry
		end
	end
	return entries[1]
end

local function setTabVisuals()
	local accent = getRarityColor(getEntryRarity(getSelectedEntry()))
	for tabName, button in pairs(tabButtons) do
		local isActive = tabName == activeTab
		button.BackgroundColor3 = isActive and blendColor(Color3.fromRGB(32, 34, 42), accent, 0.45) or Color3.fromRGB(32, 34, 42)
		button.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(226, 226, 226)
	end
end

local function updateDetailPanel()
	local entry = getSelectedEntry()
	if not entry then
		applyEntryTheme(nil)
		detailTitle.Text = "Select an entry"
		detailBody.Text = "Select an entry from the list."
		statusLabel.Text = lastActionMessage or ""
		statusLabel.TextColor3 = lastActionOk == false and Color3.fromRGB(232, 144, 144) or Color3.fromRGB(170, 170, 170)
		setButtonState(primaryButton, false, "Action", nil)
		setButtonState(secondaryButton, false, "Action", nil)
		secondaryButton.Visible = false
		return
	end

	selectedKeys[activeTab] = getEntryKey(entry)
	local accent = getRarityColor(getEntryRarity(entry))
	applyEntryTheme(entry)

	if activeTab == "Craft" then
		detailTitle.Text = string.format("%s [%s]", tostring(entry.name), tostring(entry.status))
		detailBody.Text = table.concat({
			string.format("Weapon: %s", tostring(entry.name)),
			string.format("Rarity: %s", tostring(entry.rarity)),
			string.format("Required Account Level: %d", tonumber(entry.requiredLevel) or 0),
			string.format("Recipe Tier: %d", tonumber(entry.tier) or 1),
			string.format("Recipe Copies: %d", tonumber(entry.copies) or 0),
			string.format("Crafted Copies: %d", tonumber(entry.craftedCount) or 0),
			entry.nextTierCopies and string.format("Next Tier At: %d copies", tonumber(entry.nextTierCopies) or 0) or "Recipe Tier Maxed",
			"",
			string.format("Unlock Cost: %d Silver", tonumber(entry.unlockSilverCost) or 0),
			string.format("Craft Cost: %d Silver", tonumber(entry.craftSilverCost) or 0),
			"",
			"Mob Materials:",
			formatResourceLines("", entry.mobMaterials),
			"",
			"Mine Resources:",
			formatResourceLines("", entry.mineResources),
		}, "\n")
		statusLabel.Text = entry.unlocked and "Recipe unlocked." or "Recipe found. Unlock it at the blacksmith first."
		if not entry.unlocked then
			setButtonState(primaryButton, entry.canUnlock == true, string.format("Buy Recipe (%d)", tonumber(entry.unlockSilverCost) or 0), accent)
		else
			setButtonState(primaryButton, entry.canCraft == true, string.format("Craft (%d)", tonumber(entry.craftSilverCost) or 0), accent)
		end
		setButtonState(secondaryButton, false, "", accent)
		secondaryButton.Visible = false
	elseif activeTab == "Upgrade" then
		local cost = entry.upgradeCost
		local upgradeLines = {
			string.format("Weapon: %s", tostring(entry.name)),
			string.format("Rarity: %s", tostring(entry.rarity)),
			string.format("Level: %d / %d", tonumber(entry.level) or 1, tonumber(entry.maxLevel) or 1),
			"",
			string.format("ATK: %s", tostring(entry.stats and entry.stats.ATK or "-")),
			string.format("HP: %s", tostring(entry.stats and entry.stats.HP or "-")),
			string.format("DEF: %s", tostring(entry.stats and entry.stats.DEF or "-")),
			string.format("SPD: %s%%", tostring(entry.stats and entry.stats.SPD or 0)),
			string.format("CRIT: %s%%", tostring(entry.stats and entry.stats.CRIT_RATE or 0)),
			string.format("CRIT DMG: %s%%", tostring(entry.stats and entry.stats.CRIT_DMG or 0)),
			string.format("LIFESTEAL: %s%%", tostring(entry.stats and entry.stats.LIFESTEAL or 0)),
		}
		if cost then
			table.insert(upgradeLines, "")
			table.insert(upgradeLines, "Next Upgrade Cost:")
			table.insert(upgradeLines, string.format("Silver: %d", tonumber(cost.silver) or 0))
			table.insert(upgradeLines, string.format("%s: %d", "Upgrade Crystal", tonumber(cost.crystals) or 0))
			if cost.special then
				table.insert(upgradeLines, string.format("%s: %d", tostring(cost.special.id), tonumber(cost.special.amount) or 0))
			end
		else
			table.insert(upgradeLines, "")
			table.insert(upgradeLines, "This weapon reached its max level.")
		end
		detailTitle.Text = tostring(entry.name)
		detailBody.Text = table.concat(upgradeLines, "\n")
		statusLabel.Text = entry.canUpgrade and ((entry.canAfford and "Ready to upgrade.") or "Missing Silver or upgrade materials.") or "Weapon already maxed."
		setButtonState(primaryButton, entry.canUpgrade == true and entry.canAfford == true, "Upgrade +1", accent)
		setButtonState(secondaryButton, entry.canUpgrade == true and entry.canAfford == true, "Upgrade +10", accent)
		secondaryButton.Visible = true
	else
		detailTitle.Text = tostring(entry.name)
		detailBody.Text = table.concat({
			string.format("Weapon: %s", tostring(entry.name)),
			string.format("Rarity: %s", tostring(entry.rarity)),
			string.format("Level: %d / %d", tonumber(entry.level) or 1, tonumber(entry.maxLevel) or 1),
			"",
			string.format("Silver Refund: %d", tonumber(entry.silverRefund) or 0),
			"",
			"Mine Resource Refunds:",
			formatResourceLines("", entry.mineResources),
			"",
			"Mob Material Refunds:",
			formatResourceLines("", entry.mobMaterials),
		}, "\n")
		statusLabel.Text = "Selling returns Silver and part of the crafting materials."
		setButtonState(primaryButton, true, "Sell Weapon", accent)
		setButtonState(secondaryButton, false, "", accent)
		secondaryButton.Visible = false
	end

	if lastActionMessage then
		statusLabel.Text = lastActionMessage .. " | " .. statusLabel.Text
		statusLabel.TextColor3 = lastActionOk == true and Color3.fromRGB(156, 220, 170) or Color3.fromRGB(232, 144, 144)
	else
		statusLabel.TextColor3 = blendColor(Color3.fromRGB(170, 170, 170), accent, 0.3)
	end
end

local function clearList()
	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= emptyLabel and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function rebuildList()
	clearList()
	local entries = getEntriesForTab()
	local currentKey = selectedKeys[activeTab] or (entries[1] and getEntryKey(entries[1]))
	emptyLabel.Visible = #entries == 0

	for _, entry in ipairs(entries) do
		local key = getEntryKey(entry)
		local accent = getRarityColor(getEntryRarity(entry))
		local selected = currentKey == key
		local baseColor = blendColor(Color3.fromRGB(30, 34, 44), accent, selected and 0.2 or 0.1)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -16, 0, 62)
		button.Position = UDim2.fromOffset(8, 0)
		button.BackgroundColor3 = baseColor
		button.BorderSizePixel = 0
		button.AutoButtonColor = false
		button.Text = ""
		button.Parent = listFrame
		Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
		local stroke = Instance.new("UIStroke", button)
		stroke.Color = selected and accent or blendColor(Color3.fromRGB(56, 64, 82), accent, 0.4)
		stroke.Thickness = selected and 2 or 1

		local line1 = ""
		local line2 = ""

		if activeTab == "Craft" then
			line1 = string.format("%s [%s]", tostring(entry.name), tostring(entry.status))
			line2 = string.format("Req Lv %d | Tier %d | Copies %d", tonumber(entry.requiredLevel) or 0, tonumber(entry.tier) or 1, tonumber(entry.copies) or 0)
		elseif activeTab == "Upgrade" then
			line1 = string.format("%s [Lv %d/%d]", tostring(entry.name), tonumber(entry.level) or 1, tonumber(entry.maxLevel) or 1)
			if entry.upgradeCost then
				line2 = string.format("Next: %d Silver | %d Upgrade Crystal", tonumber(entry.upgradeCost.silver) or 0, tonumber(entry.upgradeCost.crystals) or 0)
			else
				line2 = "Max level reached"
			end
		else
			line1 = string.format("%s [Lv %d/%d]", tostring(entry.name), tonumber(entry.level) or 1, tonumber(entry.maxLevel) or 1)
			line2 = string.format("Refund: %d Silver", tonumber(entry.silverRefund) or 0)
		end

		local accentBar = Instance.new("Frame")
		accentBar.Size = UDim2.fromOffset(4, 46)
		accentBar.Position = UDim2.fromOffset(10, 8)
		accentBar.BackgroundColor3 = accent
		accentBar.BorderSizePixel = 0
		accentBar.Parent = button
		Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 10)

		local titleLabel = Instance.new("TextLabel")
		titleLabel.BackgroundTransparency = 1
		titleLabel.Position = UDim2.fromOffset(24, 10)
		titleLabel.Size = UDim2.new(1, -32, 0, 20)
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextSize = 13
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextColor3 = accent
		titleLabel.Text = line1
		titleLabel.Parent = button

		local metaLabel = Instance.new("TextLabel")
		metaLabel.BackgroundTransparency = 1
		metaLabel.Position = UDim2.fromOffset(24, 31)
		metaLabel.Size = UDim2.new(1, -32, 0, 16)
		metaLabel.Font = Enum.Font.Gotham
		metaLabel.TextSize = 11
		metaLabel.TextXAlignment = Enum.TextXAlignment.Left
		metaLabel.TextColor3 = Color3.fromRGB(214, 220, 232)
		metaLabel.Text = line2
		metaLabel.Parent = button

		button.MouseButton1Click:Connect(function()
			selectedKeys[activeTab] = key
			rebuildList()
		end)
	end

	task.defer(function()
		listFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 16)
	end)
	updateDetailPanel()
	setTabVisuals()
end

local function renderSummary()
	if not snapshot then
		topInfo.Text = "Account Lv - | Silver -"
		mineLabel.Text = "Mine Resources:\n-"
		mobLabel.Text = "Mob Materials:\n-"
		upgradeMatLabel.Text = "Upgrade Materials:\n-"
		return
	end

	topInfo.Text = string.format("Account Lv %d | Silver %d", tonumber(snapshot.accountLevel) or 1, tonumber(snapshot.silver) or 0)
	mineLabel.Text = formatResourceLines("Mine Resources", snapshot.mineResources)
	mobLabel.Text = formatResourceLines("Mob Materials", snapshot.mobMaterials)
	upgradeMatLabel.Text = formatResourceLines("Upgrade Materials", snapshot.upgradeMaterials)
end

local function refresh()
	setTabVisuals()
	renderSummary()
	rebuildList()
end

local function openUI()
	gui.Enabled = true
	BlacksmithAction:FireServer({ type = "request" })
end

local function closeUI()
	gui.Enabled = false
end

closeBtn.MouseButton1Click:Connect(closeUI)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)

for tabName, button in pairs(tabButtons) do
	button.MouseButton1Click:Connect(function()
		activeTab = tabName
		refresh()
	end)
end

primaryButton.MouseButton1Click:Connect(function()
	local entry = getSelectedEntry()
	if not entry then
		return
	end
	if activeTab == "Craft" then
		if entry.unlocked then
			BlacksmithAction:FireServer({ type = "craft", recipeId = entry.recipeId })
		else
			BlacksmithAction:FireServer({ type = "unlockRecipe", recipeId = entry.recipeId })
		end
	elseif activeTab == "Upgrade" then
		BlacksmithAction:FireServer({ type = "upgrade", instanceId = entry.instanceId, steps = 1 })
	elseif activeTab == "Sell" then
		BlacksmithAction:FireServer({ type = "sell", instanceId = entry.instanceId })
	end
end)

secondaryButton.MouseButton1Click:Connect(function()
	local entry = getSelectedEntry()
	if not entry or activeTab ~= "Upgrade" then
		return
	end
	BlacksmithAction:FireServer({ type = "upgrade", instanceId = entry.instanceId, steps = 10 })
end)

local function isPromptInsideBlacksmith(prompt)
	local npcs = workspace:FindFirstChild("NPCs")
	local smith = npcs and (npcs:FindFirstChild("Blacksmith") or npcs:FindFirstChild("BlacksmithNPC"))
	if not smith then
		return false
	end
	local current = prompt and prompt.Parent
	while current do
		if current == smith then
			return true
		end
		current = current.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, localPlayer)
	if localPlayer ~= player or gui.Enabled then
		return
	end
	if isPromptInsideBlacksmith(prompt) then
		openUI()
	end
end)

OpenBlacksmithUI.OnClientEvent:Connect(function()
	if not gui.Enabled then
		openUI()
	end
end)

BlacksmithSync.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	snapshot = data
	if data.lastResult then
		lastActionOk = data.lastResult.ok == true
		lastActionMessage = lastActionOk and "Action completed" or ("Action failed: " .. tostring(data.lastResult.reason or "Unknown"))
	else
		lastActionOk = nil
		lastActionMessage = nil
	end
	refresh()
end)
