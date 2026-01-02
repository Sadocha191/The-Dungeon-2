-- LOCALSCRIPT: PlayerHudLobby.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/PlayerHudLobby (LocalScript)
-- CO: HUD (monety + nick/lvl/rasa + HP/EXP) + auto-hide gdy istnieje ScreenGui z atrybutem Modal=true i Enabled=true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlayerProgressEvent = remoteEvents:WaitForChild("PlayerProgressEvent")

-- Race updates (opcjonalnie)
local RaceUpdated = remoteEvents:FindFirstChild("RaceUpdated")
local InventoryAction = remoteEvents:WaitForChild("InventoryAction")
local InventorySync = remoteEvents:WaitForChild("InventorySync")

local gui = Instance.new("ScreenGui")
gui.Name = "PlayerHudGui_Lobby"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = pg

-- Coins (left)
local coinsBox = Instance.new("Frame")
coinsBox.Position = UDim2.fromOffset(18, 150)
coinsBox.Size = UDim2.fromOffset(200, 36)
coinsBox.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
coinsBox.BackgroundTransparency = 0.12
coinsBox.BorderSizePixel = 0
coinsBox.Parent = gui
Instance.new("UICorner", coinsBox).CornerRadius = UDim.new(0, 14)
local padL = Instance.new("UIPadding", coinsBox)
padL.PaddingLeft = UDim.new(0, 12)

local coinsText = Instance.new("TextLabel")
coinsText.BackgroundTransparency = 1
coinsText.Size = UDim2.new(1, 0, 1, 0)
coinsText.Font = Enum.Font.GothamBold
coinsText.TextSize = 14
coinsText.TextXAlignment = Enum.TextXAlignment.Left
coinsText.TextYAlignment = Enum.TextYAlignment.Center
coinsText.TextColor3 = Color3.fromRGB(245, 245, 245)
coinsText.Text = "Monety: 0"
coinsText.Parent = coinsBox

-- Name + level + race (right) - autosize width
local nameBox = Instance.new("Frame")
nameBox.AnchorPoint = Vector2.new(1, 0)
nameBox.Position = UDim2.new(1, -18, 0, 18)
nameBox.Size = UDim2.fromOffset(260, 38)
nameBox.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
nameBox.BackgroundTransparency = 0.12
nameBox.BorderSizePixel = 0
nameBox.Parent = gui
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 14)
local padR = Instance.new("UIPadding", nameBox)
padR.PaddingLeft = UDim.new(0, 14)
padR.PaddingRight = UDim.new(0, 14)

local nameText = Instance.new("TextLabel")
nameText.BackgroundTransparency = 1
nameText.Size = UDim2.new(1, 0, 1, 0)
nameText.Font = Enum.Font.GothamBold
nameText.TextSize = 14
nameText.TextXAlignment = Enum.TextXAlignment.Right
nameText.TextYAlignment = Enum.TextYAlignment.Center
nameText.TextColor3 = Color3.fromRGB(245, 245, 245)
nameText.Text = plr.Name .. " • Lv. 1 • Rasa: -"
nameText.Parent = nameBox

-- Bottom bars
local bottom = Instance.new("Frame")
bottom.AnchorPoint = Vector2.new(0.5, 1)
bottom.Position = UDim2.new(0.5, 0, 1, -18)
bottom.Size = UDim2.fromOffset(520, 66)
bottom.BackgroundTransparency = 1
bottom.Parent = gui

local bl = Instance.new("UIListLayout", bottom)
bl.FillDirection = Enum.FillDirection.Vertical
bl.Padding = UDim.new(0, 10)

local function makeBar(labelText, fillColor)
	local wrap = Instance.new("Frame")
	wrap.Size = UDim2.new(1, 0, 0, 28)
	wrap.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	wrap.BackgroundTransparency = 0.12
	wrap.BorderSizePixel = 0
	wrap.Parent = bottom
	Instance.new("UICorner", wrap).CornerRadius = UDim.new(0, 14)
	local p = Instance.new("UIPadding", wrap)
	p.PaddingLeft = UDim.new(0, 12); p.PaddingRight = UDim.new(0, 12)
	p.PaddingTop = UDim.new(0, 6); p.PaddingBottom = UDim.new(0, 6)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 14)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(220, 220, 220)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.Parent = wrap

	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0, 16)
	back.Size = UDim2.new(1, 0, 0, 6)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
	back.BorderSizePixel = 0
	back.Parent = wrap
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 999)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 999)

	return label, fill
end

local hpLabel, hpFill = makeBar("HP: 0/0", Color3.fromRGB(34, 197, 94))
local xpLabel, xpFill = makeBar("EXP: 0/0", Color3.fromRGB(96, 165, 250))

local function tweenFill(fill, pct)
	pct = math.clamp(pct, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(pct, 0, 1, 0)
	}):Play()
end

local function bindCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then return end
	local function refresh()
		local maxHp = math.max(1, hum.MaxHealth)
		local cur = math.clamp(hum.Health, 0, maxHp)
		hpLabel.Text = ("HP: %d/%d"):format(math.floor(cur + 0.5), math.floor(maxHp + 0.5))
		tweenFill(hpFill, cur / maxHp)
		if inventoryGui and inventoryGui.Enabled and refreshInventoryStats then
			refreshInventoryStats()
		end
	end
	refresh()
	hum.HealthChanged:Connect(refresh)
end
if plr.Character then bindCharacter(plr.Character) end
plr.CharacterAdded:Connect(bindCharacter)

local level, xp, nextXp, coins = 1, 0, 120, 0
local race = tostring(plr:GetAttribute("Race") or "-")
local inventoryGui
local refreshInventoryStats

local function autoSizeNameBox()
	local bounds = TextService:GetTextSize(nameText.Text, nameText.TextSize, nameText.Font, Vector2.new(2000, 2000))
	local targetW = math.clamp(bounds.X + 28, 200, 520)
	nameBox.Size = UDim2.fromOffset(targetW, 38)
end

local function render()
	race = tostring(plr:GetAttribute("Race") or race or "-")
	nameText.Text = ("%s • Lv. %d • Rasa: %s"):format(plr.Name, level, race)
	coinsText.Text = ("Monety: %d"):format(coins)

	local n = math.max(1, nextXp)
	xpLabel.Text = ("EXP: %d/%d"):format(xp, n)
	tweenFill(xpFill, xp / n)

	autoSizeNameBox()
	if inventoryGui and inventoryGui.Enabled and refreshInventoryStats then
		refreshInventoryStats()
	end
end

PlayerProgressEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "progress" then return end
	level = tonumber(payload.level) or level
	xp = tonumber(payload.xp) or xp
	nextXp = tonumber(payload.nextXp) or nextXp
	coins = tonumber(payload.coins) or coins
	render()
end)

if RaceUpdated and RaceUpdated:IsA("RemoteEvent") then
	RaceUpdated.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.race) == "string" then
			plr:SetAttribute("Race", payload.race)
		end
	end)
end

plr:GetAttributeChangedSignal("Race"):Connect(render)

-- INVENTORY (Lobby only)
inventoryGui = Instance.new("ScreenGui")
inventoryGui.Name = "InventoryGui_Lobby"
inventoryGui.ResetOnSpawn = false
inventoryGui.IgnoreGuiInset = true
inventoryGui.Enabled = false
inventoryGui:SetAttribute("Modal", true)
inventoryGui.Parent = pg

local invOverlay = Instance.new("Frame")
invOverlay.Size = UDim2.fromScale(1, 1)
invOverlay.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
invOverlay.BackgroundTransparency = 0.35
invOverlay.BorderSizePixel = 0
invOverlay.Parent = inventoryGui

local invPanel = Instance.new("Frame")
invPanel.AnchorPoint = Vector2.new(0.5, 0.5)
invPanel.Position = UDim2.fromScale(0.5, 0.5)
invPanel.Size = UDim2.fromOffset(840, 420)
invPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
invPanel.BackgroundTransparency = 0.06
invPanel.BorderSizePixel = 0
invPanel.Parent = invOverlay
Instance.new("UICorner", invPanel).CornerRadius = UDim.new(0, 16)
local invStroke = Instance.new("UIStroke", invPanel)
invStroke.Color = Color3.fromRGB(40, 40, 48)
invStroke.Thickness = 1

local invTitle = Instance.new("TextLabel")
invTitle.BackgroundTransparency = 1
invTitle.Position = UDim2.fromOffset(24, 16)
invTitle.Size = UDim2.new(1, -80, 0, 28)
invTitle.Font = Enum.Font.GothamBold
invTitle.TextSize = 20
invTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
invTitle.TextXAlignment = Enum.TextXAlignment.Left
invTitle.Text = "Ekwipunek"
invTitle.Parent = invPanel

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
closeBtn.Parent = invPanel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)

local invBody = Instance.new("Frame")
invBody.Position = UDim2.fromOffset(20, 56)
invBody.Size = UDim2.new(1, -40, 1, -76)
invBody.BackgroundTransparency = 1
invBody.Parent = invPanel

local invLayout = Instance.new("UIListLayout", invBody)
invLayout.FillDirection = Enum.FillDirection.Horizontal
invLayout.Padding = UDim.new(0, 16)

local statsPanel = Instance.new("Frame")
statsPanel.Size = UDim2.new(0.4, 0, 1, 0)
statsPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
statsPanel.BackgroundTransparency = 0.08
statsPanel.BorderSizePixel = 0
statsPanel.Parent = invBody
Instance.new("UICorner", statsPanel).CornerRadius = UDim.new(0, 12)
local statsPad = Instance.new("UIPadding", statsPanel)
statsPad.PaddingTop = UDim.new(0, 16)
statsPad.PaddingBottom = UDim.new(0, 16)
statsPad.PaddingLeft = UDim.new(0, 16)
statsPad.PaddingRight = UDim.new(0, 16)

local statsTitle = Instance.new("TextLabel")
statsTitle.BackgroundTransparency = 1
statsTitle.Size = UDim2.new(1, 0, 0, 20)
statsTitle.Font = Enum.Font.GothamBold
statsTitle.TextSize = 16
statsTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
statsTitle.TextXAlignment = Enum.TextXAlignment.Left
statsTitle.Text = "Statystyki gracza"
statsTitle.Parent = statsPanel

local statsList = Instance.new("Frame")
statsList.BackgroundTransparency = 1
statsList.Position = UDim2.fromOffset(0, 30)
statsList.Size = UDim2.new(1, 0, 1, -30)
statsList.Parent = statsPanel
local statsLayout = Instance.new("UIListLayout", statsList)
statsLayout.Padding = UDim.new(0, 10)

local function makeStatRow(labelText)
	local row = Instance.new("TextLabel")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 18)
	row.Font = Enum.Font.Gotham
	row.TextSize = 14
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = Color3.fromRGB(210, 210, 210)
	row.Text = labelText
	row.Parent = statsList
	return row
end

local statLevel = makeStatRow("Poziom: -")
local statRace = makeStatRow("Rasa: -")
local statCoins = makeStatRow("Monety: -")
local statHP = makeStatRow("HP: -")
local statEXP = makeStatRow("EXP: -")

local itemsPanel = Instance.new("Frame")
itemsPanel.Size = UDim2.new(0.6, 0, 1, 0)
itemsPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
itemsPanel.BackgroundTransparency = 0.08
itemsPanel.BorderSizePixel = 0
itemsPanel.Parent = invBody
Instance.new("UICorner", itemsPanel).CornerRadius = UDim.new(0, 12)
local itemsPad = Instance.new("UIPadding", itemsPanel)
itemsPad.PaddingTop = UDim.new(0, 16)
itemsPad.PaddingBottom = UDim.new(0, 16)
itemsPad.PaddingLeft = UDim.new(0, 16)
itemsPad.PaddingRight = UDim.new(0, 16)

local itemsTitle = Instance.new("TextLabel")
itemsTitle.BackgroundTransparency = 1
itemsTitle.Size = UDim2.new(1, 0, 0, 20)
itemsTitle.Font = Enum.Font.GothamBold
itemsTitle.TextSize = 16
itemsTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
itemsTitle.TextXAlignment = Enum.TextXAlignment.Left
itemsTitle.Text = "Przedmioty"
itemsTitle.Parent = itemsPanel

local itemsList = Instance.new("ScrollingFrame")
itemsList.BackgroundTransparency = 1
itemsList.Position = UDim2.fromOffset(0, 30)
itemsList.Size = UDim2.new(1, 0, 1, -30)
itemsList.ScrollBarThickness = 6
itemsList.BorderSizePixel = 0
itemsList.CanvasSize = UDim2.fromOffset(0, 0)
itemsList.Parent = itemsPanel

local itemsLayout = Instance.new("UIGridLayout", itemsList)
itemsLayout.CellPadding = UDim2.fromOffset(12, 12)
itemsLayout.CellSize = UDim2.fromOffset(220, 120)
itemsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local emptyItemsLabel = Instance.new("TextLabel")
emptyItemsLabel.BackgroundTransparency = 1
emptyItemsLabel.Position = UDim2.fromOffset(0, 30)
emptyItemsLabel.Size = UDim2.new(1, 0, 1, -30)
emptyItemsLabel.Font = Enum.Font.Gotham
emptyItemsLabel.TextSize = 14
emptyItemsLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
emptyItemsLabel.Text = "Brak broni. Odbierz je z gacha."
emptyItemsLabel.TextWrapped = true
emptyItemsLabel.TextXAlignment = Enum.TextXAlignment.Center
emptyItemsLabel.TextYAlignment = Enum.TextYAlignment.Center
emptyItemsLabel.Visible = false
emptyItemsLabel.Parent = itemsPanel

local confirmOverlay = Instance.new("Frame")
confirmOverlay.Size = UDim2.fromScale(1, 1)
confirmOverlay.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
confirmOverlay.BackgroundTransparency = 0.35
confirmOverlay.BorderSizePixel = 0
confirmOverlay.Visible = false
confirmOverlay.Parent = inventoryGui

local confirmPanel = Instance.new("Frame")
confirmPanel.AnchorPoint = Vector2.new(0.5, 0.5)
confirmPanel.Position = UDim2.fromScale(0.5, 0.5)
confirmPanel.Size = UDim2.fromOffset(360, 180)
confirmPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
confirmPanel.BackgroundTransparency = 0.06
confirmPanel.BorderSizePixel = 0
confirmPanel.Parent = confirmOverlay
Instance.new("UICorner", confirmPanel).CornerRadius = UDim.new(0, 14)
local confirmStroke = Instance.new("UIStroke", confirmPanel)
confirmStroke.Color = Color3.fromRGB(40, 40, 48)
confirmStroke.Thickness = 1

local confirmText = Instance.new("TextLabel")
confirmText.BackgroundTransparency = 1
confirmText.Position = UDim2.fromOffset(20, 18)
confirmText.Size = UDim2.new(1, -40, 0, 60)
confirmText.Font = Enum.Font.GothamBold
confirmText.TextSize = 16
confirmText.TextColor3 = Color3.fromRGB(235, 235, 235)
confirmText.TextWrapped = true
confirmText.Text = "Czy na pewno chcesz sprzedać tę broń?"
confirmText.Parent = confirmPanel

local confirmButtons = Instance.new("Frame")
confirmButtons.BackgroundTransparency = 1
confirmButtons.AnchorPoint = Vector2.new(0.5, 1)
confirmButtons.Position = UDim2.new(0.5, 0, 1, -16)
confirmButtons.Size = UDim2.new(1, -40, 0, 44)
confirmButtons.Parent = confirmPanel
local confirmLayout = Instance.new("UIListLayout", confirmButtons)
confirmLayout.FillDirection = Enum.FillDirection.Horizontal
confirmLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
confirmLayout.Padding = UDim.new(0, 12)

local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.fromOffset(120, 40)
cancelBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
cancelBtn.BorderSizePixel = 0
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.TextSize = 14
cancelBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
cancelBtn.Text = "Anuluj"
cancelBtn.Parent = confirmButtons
Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 10)

local confirmBtn = Instance.new("TextButton")
confirmBtn.Size = UDim2.fromOffset(140, 40)
confirmBtn.BackgroundColor3 = Color3.fromRGB(185, 62, 62)
confirmBtn.BorderSizePixel = 0
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.TextSize = 14
confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
confirmBtn.Text = "Sprzedaj"
confirmBtn.Parent = confirmButtons
Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(0, 10)

local equippedItemId
local pendingSellId
local pendingSellName
local inventoryItems = {}

local function sortItems(items)
	table.sort(items, function(a, b)
		if (a.favorite and not b.favorite) then
			return true
		elseif (b.favorite and not a.favorite) then
			return false
		end
		return (a.name or "") < (b.name or "")
	end)
end

local function makeItemCard(item)
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(220, 120)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	card.BorderSizePixel = 0
	card.Parent = itemsList
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	local favoriteBtn = Instance.new("TextButton")
	favoriteBtn.Size = UDim2.fromOffset(22, 22)
	favoriteBtn.Position = UDim2.fromOffset(8, 8)
	favoriteBtn.BackgroundColor3 = Color3.fromRGB(34, 34, 44)
	favoriteBtn.BorderSizePixel = 0
	favoriteBtn.Font = Enum.Font.GothamBold
	favoriteBtn.TextSize = 14
	favoriteBtn.TextColor3 = Color3.fromRGB(255, 214, 102)
	favoriteBtn.Text = item.favorite and "★" or "☆"
	favoriteBtn.Parent = card
	Instance.new("UICorner", favoriteBtn).CornerRadius = UDim.new(0, 6)

	local sellBtn = Instance.new("TextButton")
	sellBtn.AnchorPoint = Vector2.new(1, 0)
	sellBtn.Position = UDim2.new(1, -8, 0, 8)
	sellBtn.Size = UDim2.fromOffset(22, 22)
	sellBtn.BackgroundColor3 = Color3.fromRGB(44, 34, 34)
	sellBtn.BorderSizePixel = 0
	sellBtn.Font = Enum.Font.GothamBold
	sellBtn.TextSize = 12
	sellBtn.TextColor3 = Color3.fromRGB(255, 160, 160)
	sellBtn.Text = "X"
	sellBtn.Parent = card
	Instance.new("UICorner", sellBtn).CornerRadius = UDim.new(0, 6)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(12, 36)
	name.Size = UDim2.new(1, -24, 0, 18)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.fromRGB(245, 245, 245)
	name.Text = item.name or "Nieznana broń"
	name.Parent = card

	local meta = Instance.new("TextLabel")
	meta.BackgroundTransparency = 1
	meta.Position = UDim2.fromOffset(12, 56)
	meta.Size = UDim2.new(1, -24, 0, 16)
	meta.Font = Enum.Font.Gotham
	meta.TextSize = 12
	meta.TextXAlignment = Enum.TextXAlignment.Left
	meta.TextColor3 = Color3.fromRGB(180, 180, 180)
	meta.Text = item.meta or "Pozyskaj z gacha"
	meta.Parent = card

	local valueLabel = Instance.new("TextLabel")
	valueLabel.BackgroundTransparency = 1
	valueLabel.Position = UDim2.fromOffset(12, 74)
	valueLabel.Size = UDim2.new(1, -24, 0, 16)
	valueLabel.Font = Enum.Font.Gotham
	valueLabel.TextSize = 12
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	valueLabel.Text = ("Wartość: %s monet"):format(item.sellValue and tostring(item.sellValue) or "?")
	valueLabel.Parent = card

	local equipBtn = Instance.new("TextButton")
	equipBtn.AnchorPoint = Vector2.new(1, 1)
	equipBtn.Position = UDim2.new(1, -10, 1, -10)
	equipBtn.Size = UDim2.fromOffset(90, 28)
	equipBtn.BackgroundColor3 = item.id == equippedItemId and Color3.fromRGB(60, 140, 255) or Color3.fromRGB(36, 36, 48)
	equipBtn.BorderSizePixel = 0
	equipBtn.Font = Enum.Font.GothamBold
	equipBtn.TextSize = 12
	equipBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
	equipBtn.Text = item.id == equippedItemId and "Wyposażona" or "Wyposaż"
	equipBtn.Parent = card
	Instance.new("UICorner", equipBtn).CornerRadius = UDim.new(0, 8)

	favoriteBtn.MouseButton1Click:Connect(function()
		InventoryAction:FireServer({
			type = "favorite",
			id = item.id,
			value = not item.favorite,
		})
	end)

	sellBtn.MouseButton1Click:Connect(function()
		pendingSellId = item.id
		pendingSellName = item.name
		confirmText.Text = ("Czy na pewno chcesz sprzedać broń \"%s\"?"):format(item.name or "tę broń")
		confirmOverlay.Visible = true
	end)

	equipBtn.MouseButton1Click:Connect(function()
		InventoryAction:FireServer({
			type = "equip",
			id = item.id,
		})
	end)
end

local function renderInventory(items)
	for _, child in ipairs(itemsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	sortItems(items)
	emptyItemsLabel.Visible = #items == 0
	for _, item in ipairs(items) do
		makeItemCard(item)
	end
	task.defer(function()
		itemsList.CanvasSize = UDim2.fromOffset(0, itemsLayout.AbsoluteContentSize.Y + 12)
	end)
end

local function buildMeta(item)
	local parts = {}
	if item.rarity and item.rarity ~= "" then
		table.insert(parts, ("Rzadkość: %s"):format(item.rarity))
	end
	if item.weaponType and item.weaponType ~= "" then
		table.insert(parts, ("Typ: %s"):format(item.weaponType))
	end
	if item.baseDamage then
		table.insert(parts, ("DMG: %d"):format(item.baseDamage))
	end
	if item.maxLevel then
		table.insert(parts, ("Max lvl: %d"):format(item.maxLevel))
	end
	if typeof(item.stats) == "table" then
		local statParts = {}
		if item.stats.HP and item.stats.HP ~= 0 then
			table.insert(statParts, ("HP: +%d"):format(item.stats.HP))
		end
		if item.stats.SPD and item.stats.SPD ~= 0 then
			table.insert(statParts, ("SPD: +%d%%"):format(item.stats.SPD))
		end
		if item.stats.CRIT_RATE and item.stats.CRIT_RATE ~= 0 then
			table.insert(statParts, ("CRIT_RATE: +%d%%"):format(item.stats.CRIT_RATE))
		end
		if item.stats.CRIT_DMG and item.stats.CRIT_DMG ~= 0 then
			table.insert(statParts, ("CRIT_DMG: +%d%%"):format(item.stats.CRIT_DMG))
		end
		if item.stats.LIFESTEAL and item.stats.LIFESTEAL ~= 0 then
			table.insert(statParts, ("LIFESTEAL: +%d%%"):format(item.stats.LIFESTEAL))
		end
		if item.stats.DEF and item.stats.DEF ~= 0 then
			table.insert(statParts, ("DEF: +%d"):format(item.stats.DEF))
		end
		if #statParts > 0 then
			table.insert(parts, table.concat(statParts, " "))
		end
	end
	if item.passiveName and item.passiveName ~= "" then
		table.insert(parts, ("Pasyw: %s"):format(item.passiveName))
	end
	if item.abilityName and item.abilityName ~= "" then
		table.insert(parts, ("Umiejętność: %s"):format(item.abilityName))
	end
	if #parts > 0 then
		return table.concat(parts, " • ")
	end
	return "Pozyskaj z gacha"
end

local function syncInventory(payload)
	if typeof(payload) ~= "table" or typeof(payload.items) ~= "table" then
		return
	end
	inventoryItems = {}
	for _, raw in ipairs(payload.items) do
		if typeof(raw) == "table" then
			local entry = {
				id = raw.id or raw.name,
				name = raw.name or raw.id or "Nieznana broń",
				rarity = raw.rarity,
				weaponType = raw.weaponType,
				baseDamage = raw.baseDamage,
				sellValue = raw.sellValue,
				maxLevel = raw.maxLevel,
				stats = raw.stats,
				passiveName = raw.passiveName,
				passiveDescription = raw.passiveDescription,
				abilityName = raw.abilityName,
				abilityDescription = raw.abilityDescription,
				favorite = raw.favorite == true,
			}
			entry.meta = raw.meta or buildMeta(entry)
			table.insert(inventoryItems, entry)
		end
	end
	equippedItemId = payload.equippedId
	renderInventory(inventoryItems)
end

InventorySync.OnClientEvent:Connect(syncInventory)

refreshInventoryStats = function()
	statLevel.Text = ("Poziom: %d"):format(level)
	statRace.Text = ("Rasa: %s"):format(tostring(plr:GetAttribute("Race") or "-"))
	statCoins.Text = ("Monety: %d"):format(coins)
	statHP.Text = hpLabel.Text
	statEXP.Text = xpLabel.Text
end

local function setInventoryVisible(state)
	inventoryGui.Enabled = state
	if not state then
		confirmOverlay.Visible = false
		pendingSellId = nil
		pendingSellName = nil
	end
	if state then
		refreshInventoryStats()
		InventoryAction:FireServer({ type = "request" })
	end
end

closeBtn.MouseButton1Click:Connect(function()
	setInventoryVisible(false)
end)

cancelBtn.MouseButton1Click:Connect(function()
	confirmOverlay.Visible = false
	pendingSellId = nil
	pendingSellName = nil
end)

confirmBtn.MouseButton1Click:Connect(function()
	if pendingSellId then
		InventoryAction:FireServer({
			type = "sell",
			id = pendingSellId,
		})
	end
	confirmOverlay.Visible = false
	pendingSellId = nil
	pendingSellName = nil
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.B then
		setInventoryVisible(not inventoryGui.Enabled)
	end
end)

InventoryAction:FireServer({ type = "request" })

-- AUTO-HIDE: jeśli jakikolwiek ScreenGui ma Modal=true i Enabled=true, chowamy HUD
local function anyModalOpen(): boolean
	for _, inst in ipairs(pg:GetChildren()) do
		if inst:IsA("ScreenGui") and inst.Enabled then
			if inst:GetAttribute("Modal") == true then
				return true
			end
		end
	end
	return false
end

local lastHidden = false
RunService.RenderStepped:Connect(function()
	local hide = anyModalOpen()
	if hide ~= lastHidden then
		gui.Enabled = not hide
		lastHidden = hide
	end
end)

render()
print("[PlayerHudLobby] Ready (auto-hide on Modal)")
