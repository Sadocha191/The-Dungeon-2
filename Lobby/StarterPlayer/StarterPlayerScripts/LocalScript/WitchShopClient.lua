-- WitchShopClient.client.lua (StarterPlayerScripts)

local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local WitchShopEvent = remoteEvents:WaitForChild("WitchShopEvent")

local PauseState = ReplicatedStorage:WaitForChild("PauseState")

local gui = pg:WaitForChild("WitchShopGui")
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)

local overlay = gui:WaitForChild("overlay")
overlay.Size = UDim2.fromScale(1,1)
overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.45
overlay.BorderSizePixel = 0
overlay.Parent = gui

local panel = overlay:WaitForChild("panel")
panel.AnchorPoint = Vector2.new(0.5,0.5)
panel.Position = UDim2.fromScale(0.5,0.5)
panel.Size = UDim2.fromScale(0.84, 0.76)
panel.BackgroundColor3 = Color3.fromRGB(14,14,16)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 18)
local panelSizeConstraint = Instance.new("UISizeConstraint", panel)
panelSizeConstraint.MaxSize = Vector2.new(820, 460)
local panelAspect = Instance.new("UIAspectRatioConstraint", panel)
panelAspect.AspectRatio = 820 / 460
panelAspect.DominantAxis = Enum.DominantAxis.Height

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(18, 14)
title.Size = UDim2.new(1,-36,0,26)
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(245,245,245)
title.Text = "Witch Shop"
title.Parent = panel

local coinsLabel = Instance.new("TextLabel")
coinsLabel.BackgroundTransparency = 1
coinsLabel.Position = UDim2.fromOffset(18, 42)
coinsLabel.Size = UDim2.new(1,-36,0,18)
coinsLabel.Font = Enum.Font.Gotham
coinsLabel.TextSize = 12
coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
coinsLabel.TextColor3 = Color3.fromRGB(210,210,210)
coinsLabel.Text = "Souls: 0"
coinsLabel.Parent = panel

local sortBar = Instance.new("Frame")
sortBar.Position = UDim2.fromOffset(18, 70)
sortBar.Size = UDim2.fromOffset(360, 28)
sortBar.BackgroundTransparency = 1
sortBar.Parent = panel

local sortLayout = Instance.new("UIListLayout")
sortLayout.FillDirection = Enum.FillDirection.Horizontal
sortLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
sortLayout.Padding = UDim.new(0, 6)
sortLayout.Parent = sortBar

local left = Instance.new("ScrollingFrame")
left.Position = UDim2.fromOffset(18, 106)
left.Size = UDim2.fromOffset(360, 294)
left.BackgroundColor3 = Color3.fromRGB(20,20,24)
left.BackgroundTransparency = 0.10
left.BorderSizePixel = 0
left.ScrollBarThickness = 6
left.Parent = panel
Instance.new("UICorner", left).CornerRadius = UDim.new(0, 14)

local leftLay = Instance.new("UIListLayout")
leftLay.Padding = UDim.new(0, 8)
leftLay.Parent = left

local right = Instance.new("Frame")
right.Position = UDim2.fromOffset(396, 70)
right.Size = UDim2.fromOffset(406, 330)
right.BackgroundColor3 = Color3.fromRGB(20,20,24)
right.BackgroundTransparency = 0.10
right.BorderSizePixel = 0
right.Parent = panel
Instance.new("UICorner", right).CornerRadius = UDim.new(0, 14)

local rName = Instance.new("TextLabel")
rName.BackgroundTransparency = 1
rName.Position = UDim2.fromOffset(16, 14)
rName.Size = UDim2.new(1,-32,0,22)
rName.Font = Enum.Font.GothamBold
rName.TextSize = 16
rName.TextXAlignment = Enum.TextXAlignment.Left
rName.TextColor3 = Color3.fromRGB(245,245,245)
rName.Text = "Select a spell"
rName.Parent = right

local rInfo = Instance.new("TextLabel")
rInfo.BackgroundTransparency = 1
rInfo.Position = UDim2.fromOffset(16, 44)
rInfo.Size = UDim2.new(1,-32,1,-110)
rInfo.Font = Enum.Font.Gotham
rInfo.TextSize = 12
rInfo.TextXAlignment = Enum.TextXAlignment.Left
rInfo.TextYAlignment = Enum.TextYAlignment.Top
rInfo.TextColor3 = Color3.fromRGB(220,220,220)
rInfo.TextWrapped = true
rInfo.Text = ""
rInfo.Parent = right

local buyBtn = Instance.new("TextButton")
buyBtn.AnchorPoint = Vector2.new(0.5,1)
buyBtn.Position = UDim2.new(0.5,0,1,-18)
buyBtn.Size = UDim2.fromOffset(320, 44)
buyBtn.BackgroundColor3 = Color3.fromRGB(180,120,255)
buyBtn.BackgroundTransparency = 0.15
buyBtn.BorderSizePixel = 0
buyBtn.Font = Enum.Font.GothamBold
buyBtn.TextSize = 14
buyBtn.TextColor3 = Color3.fromRGB(10,10,12)
buyBtn.Text = "Buy"
buyBtn.Parent = right
Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 14)

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -16, 0, 16)
closeBtn.Size = UDim2.fromOffset(34, 34)
closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,34)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(245,245,245)
closeBtn.Text = "X"
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 14)

local selected = nil
local currentCoins = 0
local currentSpells = {}
local sortButtons = {}
local sortState = { key = "name", ascending = true }
local addRow
local setRight

local ELEMENT_ORDER = {
	Fire = 1,
	Electricity = 2,
	Air = 3,
	Water = 4,
	Earth = 5,
	Void = 6,
	Light = 7,
	Physical = 8,
}

local RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythical = 6,
	Standard = 1,
	Amplified = 3,
}

local SORT_DEFAULT_ASC = {
	name = true,
	price = true,
	element = true,
	rarity = false,
}

local SORT_LABELS = {
	name = "Name",
	price = "Price",
	element = "Element",
	rarity = "Rarity",
}

local function refreshCanvas()
	left.CanvasSize = UDim2.fromOffset(0, leftLay.AbsoluteContentSize.Y + 16)
end

local function clearList()
	for _,c in ipairs(left:GetChildren()) do
		if c:IsA("GuiObject") and not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function getSpellName(spell)
	return tostring(spell.displayName or spell.name or "Spell")
end

local function getSpellRarity(spell)
	return tostring(spell.rarity or spell.cardQuality or spell.baseQuality or "Common")
end

local function getSpellElementRank(spell)
	return ELEMENT_ORDER[tostring(spell.element or "Physical")] or 99
end

local function getSpellRarityRank(spell)
	return RARITY_ORDER[getSpellRarity(spell)] or 0
end

local function updateSortButtons()
	for key, button in pairs(sortButtons) do
		local active = sortState.key == key
		local dir = ""
		if active then
			dir = sortState.ascending and " ASC" or " DESC"
		end
		button.Text = (SORT_LABELS[key] or key) .. dir
		button.BackgroundColor3 = active and Color3.fromRGB(180,120,255) or Color3.fromRGB(30,30,34)
		button.TextColor3 = active and Color3.fromRGB(10,10,12) or Color3.fromRGB(245,245,245)
	end
end

local function spellLess(a, b)
	local key = sortState.key
	local ascending = sortState.ascending

	local function pick(primaryA, primaryB)
		if primaryA == primaryB then
			return nil
		end
		if ascending then
			return primaryA < primaryB
		end
		return primaryA > primaryB
	end

	if key == "price" then
		local cmp = pick(tonumber(a.costCoins) or 0, tonumber(b.costCoins) or 0)
		if cmp ~= nil then
			return cmp
		end
	elseif key == "element" then
		local cmp = pick(getSpellElementRank(a), getSpellElementRank(b))
		if cmp ~= nil then
			return cmp
		end
	elseif key == "rarity" then
		local cmp = pick(getSpellRarityRank(a), getSpellRarityRank(b))
		if cmp ~= nil then
			return cmp
		end
	else
		local cmp = pick(string.lower(getSpellName(a)), string.lower(getSpellName(b)))
		if cmp ~= nil then
			return cmp
		end
	end

	local aName = string.lower(getSpellName(a))
	local bName = string.lower(getSpellName(b))
	if aName ~= bName then
		return aName < bName
	end

	return (tonumber(a.costCoins) or 0) < (tonumber(b.costCoins) or 0)
end

local function renderList()
	local selectedId = selected and selected.id or nil
	table.sort(currentSpells, spellLess)

	clearList()
	for _, spell in ipairs(currentSpells) do
		addRow(spell)
	end
	refreshCanvas()

	if selectedId then
		for _, spell in ipairs(currentSpells) do
			if spell.id == selectedId then
				setRight(spell)
				return
			end
		end
	end

	setRight(nil)
end

local function setSort(key)
	if sortState.key == key then
		sortState.ascending = not sortState.ascending
	else
		sortState.key = key
		sortState.ascending = SORT_DEFAULT_ASC[key] ~= false
	end
	updateSortButtons()
	renderList()
end

setRight = function(spell)
	selected = spell
	if not spell then
		rName.Text = "Select a spell"
		rInfo.Text = ""
		buyBtn.Text = "Buy"
		buyBtn.BackgroundTransparency = 0.5
		buyBtn.Active = false
		return
	end

	rName.Text = tostring(spell.displayName or spell.name)
	rInfo.Text = string.format(
		"Type: %s\nElement: %s\nAttack: %s\nRarity: %s\nBase Variant: %s\nCost: %d Souls\nStatus: %s\n\n%s",
		tostring(spell.spellType or "Spell"),
		tostring(spell.element or "-"),
		tostring(spell.attackType or "-"),
		getSpellRarity(spell),
		tostring(spell.baseQuality or "Standard"),
		tonumber(spell.costCoins) or 0,
		spell.owned and "Owned" or "Locked",
		tostring(spell.desc or "Unlocks the spell so it can appear during level up.")
	)

	if spell.owned then
		buyBtn.Text = "Owned"
		buyBtn.BackgroundTransparency = 0.5
		buyBtn.Active = false
	else
		buyBtn.Text = ("Buy (%d)"):format(tonumber(spell.costCoins) or 0)
		buyBtn.BackgroundTransparency = 0.15
		buyBtn.Active = true
	end
end

addRow = function(spell)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -16, 0, 46)
	row.Position = UDim2.fromOffset(8, 0)
	row.BackgroundColor3 = Color3.fromRGB(26,26,30)
	row.BackgroundTransparency = 0.10
	row.BorderSizePixel = 0
	row.Font = Enum.Font.Gotham
	row.TextSize = 12
	row.TextColor3 = Color3.fromRGB(230,230,230)
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = ("  %s  [%s | %s]  %s"):format(
		getSpellName(spell),
		tostring(spell.element or spell.category or "Spell"),
		getSpellRarity(spell),
		spell.owned and "Owned" or ("Cost: "..tostring(spell.costCoins).." Souls")
	)
	row.Parent = left
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)

	row.MouseButton1Click:Connect(function()
		setRight(spell)
	end)
end

local function openShop(payload)
	currentCoins = tonumber(payload.souls) or 0
	currentSpells = payload.spells or {}
	coinsLabel.Text = ("Souls: %d"):format(currentCoins)

	updateSortButtons()
	renderList()

	gui.Enabled = true
	PauseState.Value = true
end

local function openMessage(msg: string)
	gui.Enabled = true
	PauseState.Value = true
	rName.Text = "Witch Shop"
	rInfo.Text = msg
	buyBtn.Text = "Buy"
	buyBtn.BackgroundTransparency = 0.5
	buyBtn.Active = false
end

local function closeShop()
	gui.Enabled = false
	PauseState.Value = false
end

closeBtn.MouseButton1Click:Connect(closeShop)

buyBtn.MouseButton1Click:Connect(function()
	if not selected or selected.owned then return end
	WitchShopEvent:FireServer({ type = "BUY", id = selected.id })
end)

for _, key in ipairs({ "name", "price", "element", "rarity" }) do
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(85, 28)
	button.BackgroundColor3 = Color3.fromRGB(30,30,34)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 11
	button.TextColor3 = Color3.fromRGB(245,245,245)
	button.Parent = sortBar
	Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)

	button.MouseButton1Click:Connect(function()
		setSort(key)
	end)

	sortButtons[key] = button
end

updateSortButtons()

UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeShop()
	end
end)

-- Open via proximity prompt (Witch NPC)
local function isPromptInsideWitch(prompt: ProximityPrompt): boolean
	local npcs = workspace:FindFirstChild("NPCs")
	local witch = npcs and (npcs:FindFirstChild("Witch") or npcs:FindFirstChild("Wiedzma"))
	if not witch then return false end

	local p = prompt and prompt.Parent
	while p do
		if p == witch then return true end
		p = p.Parent
	end
	return false
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if player ~= plr then return end
	if gui.Enabled then return end
	if isPromptInsideWitch(prompt) then
		WitchShopEvent:FireServer({ type = "OPEN" })
	end
end)

WitchShopEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.type == "OPEN" then
		openShop(payload)

	elseif payload.type == "BOUGHT" then
		if payload.souls then
			currentCoins = tonumber(payload.souls) or 0
			coinsLabel.Text = ("Souls: %d"):format(currentCoins)
		end
		if payload.spells then
			currentSpells = payload.spells
			renderList()
		end

	elseif payload.type == "ERROR" or payload.type == "INFO" then
		openMessage(tostring(payload.message or "..."))
	end
end)
