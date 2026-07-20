local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventoryGui = playerGui:WaitForChild("InventoryGui")

local function waitDeep(parent, name, timeout)
	local deadline = os.clock() + (timeout or 10)
	repeat
		local found = parent:FindFirstChild(name, true)
		if found then return found end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

local panel = waitDeep(inventoryGui, "RemakePanel", 12)
local center = panel and panel:FindFirstChild("ContentColumn", true)
local detailsColumn = panel and panel:FindFirstChild("DetailsColumn", true)
local tabBar = center and center:FindFirstChild("TabBar")
if not (panel and center and detailsColumn and tabBar) then
	warn("[InventorySpellTabReference] Inventory layout contract is incomplete")
	return
end

local spellTab
local tabButtons = {}
for _, child in ipairs(tabBar:GetChildren()) do
	if child:IsA("TextButton") then
		table.insert(tabButtons, child)
		if child.Text == "Spell Loadout" then spellTab = child end
	end
end
if not spellTab then
	warn("[InventorySpellTabReference] Spell Loadout tab is missing")
	return
end

local modules = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = modules and require(modules:WaitForChild("SpellDefinitions")) or {}
local EntryBuilder = require(script.Parent:WaitForChild("InventoryEntryBuilder"))
local IconResolver = require(script.Parent:WaitForChild("InventoryIconResolver"))
local entriesBuilder = EntryBuilder.new({ SpellDefs = SpellDefs, WeaponConfigs = {}, CraftingConfig = {} })
local icons = IconResolver.new({ ReplicatedStorage = ReplicatedStorage, WeaponConfigs = {} })

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
local inventoryAction = remoteEvents and remoteEvents:WaitForChild("InventoryAction", 10)
local snapshotUpdatedEvent = panel:WaitForChild("InventorySnapshotUpdated", 10)
local currentSnapshotFunction = panel:WaitForChild("GetCurrentInventorySnapshot", 10)
local focusSpellSearchEvent = panel:WaitForChild("FocusSpellSearch", 10)

if not (
	snapshotUpdatedEvent and snapshotUpdatedEvent:IsA("BindableEvent")
	and currentSnapshotFunction and currentSnapshotFunction:IsA("BindableFunction")
	and focusSpellSearchEvent and focusSpellSearchEvent:IsA("BindableEvent")
) then
	warn("[InventorySpellTabReference] Inventory state bridge is incomplete")
	return
end

local C = {
	bg = Color3.fromRGB(7, 8, 13), panel = Color3.fromRGB(12, 15, 23),
	panel2 = Color3.fromRGB(16, 19, 29), card = Color3.fromRGB(18, 22, 32),
	stroke = Color3.fromRGB(47, 48, 66), text = Color3.fromRGB(239, 239, 247),
	muted = Color3.fromRGB(154, 157, 176), dim = Color3.fromRGB(98, 101, 120),
	purple = Color3.fromRGB(184, 89, 255), gold = Color3.fromRGB(224, 181, 104),
	red = Color3.fromRGB(205, 78, 94),
}
local fallbackElements = {
	Fire = Color3.fromRGB(255, 100, 45), Water = Color3.fromRGB(62, 155, 255),
	Air = Color3.fromRGB(164, 211, 228), Earth = Color3.fromRGB(109, 174, 74),
	Void = Color3.fromRGB(171, 77, 242), Light = Color3.fromRGB(244, 210, 98),
	Electricity = Color3.fromRGB(71, 145, 255), Electric = Color3.fromRGB(71, 145, 255),
	Physical = Color3.fromRGB(184, 166, 151),
}
local ELEMENTS = { "All", "Fire", "Water", "Air", "Earth", "Void", "Light", "Electricity", "Physical" }
local SORTS = { "Equipped", "Element", "Damage", "Name" }

local function blend(a, b, t)
	return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
local function elementColor(element)
	if SpellDefs.GetElementColor then
		local ok, result = pcall(SpellDefs.GetElementColor, element)
		if ok and typeof(result) == "Color3" then return result end
	end
	return fallbackElements[tostring(element or "")] or C.purple
end
local function make(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do object[key] = value end
	if object:IsA("GuiObject") and (not props or props.ZIndex == nil) then object.ZIndex = 31 end
	object.Parent = parent
	return object
end
local function corner(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 7) }, parent)
end
local function stroke(parent, color, thickness, transparency)
	return make("UIStroke", { Color = color or C.stroke, Thickness = thickness or 1, Transparency = transparency or 0 }, parent)
end
local function padding(parent, x, y)
	return make("UIPadding", {
		PaddingLeft = UDim.new(0, x), PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y), PaddingBottom = UDim.new(0, y),
	}, parent)
end
local function clear(parent, keep)
	for _, child in ipairs(parent:GetChildren()) do
		if not (keep and keep[child.ClassName]) then child:Destroy() end
	end
end
local function fmt(value)
	local n = tonumber(value) or 0
	if math.abs(n) >= 1000000 then return string.format("%.1fm", n / 1000000) end
	if math.abs(n) >= 1000 then return string.format("%.1fk", n / 1000) end
	if math.abs(n - math.floor(n + 0.5)) < 0.01 then return tostring(math.floor(n + 0.5)) end
	return string.format("%.1f", n)
end
local function stat(entry, names)
	for _, line in ipairs(entry.statLines or {}) do
		for _, name in ipairs(names) do
			local value = tostring(line):match(name .. "%s*[:%-]?%s*([%d%.]+)")
			if value then return tonumber(value) or 0 end
		end
	end
	return 0
end
local function damage(entry) return stat(entry, { "Damage", "DMG", "Power" }) end
local function cooldown(entry) return stat(entry, { "Cooldown", "CD" }) end
local function radius(entry) return stat(entry, { "Radius", "Range" }) end
local function duration(entry) return stat(entry, { "Duration" }) end
local function normalized(value) return string.lower(tostring(value or "")):gsub("[%p%s]+", " ") end
local function icon(parent, entry, size)
	local color = entry and elementColor(entry.element) or C.dim
	local image = entry and icons.SpellImage(entry)
	if image and image ~= "" then
		make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit }, parent)
	else
		make("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
			Text = entry and (entry.iconGlyph or "?") or "+", TextColor3 = color, TextSize = size or 20,
		}, parent)
	end
end
local function label(parent, text, props)
	props = props or {}
	return make("TextLabel", {
		Position = props.Position or UDim2.fromOffset(0, 0), Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Font = props.Font or Enum.Font.Gotham,
		Text = text or "", TextColor3 = props.Color or C.text, TextSize = props.TextSize or 9,
		TextXAlignment = props.X or Enum.TextXAlignment.Left, TextYAlignment = props.Y or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrapped or false, TextTruncate = props.Truncate or Enum.TextTruncate.None,
		AnchorPoint = props.AnchorPoint or Vector2.zero, ZIndex = props.ZIndex,
	}, parent)
end
local function section(parent, name, position, size)
	local frame = make("Frame", { Name = name, Position = position, Size = size, BackgroundColor3 = C.panel2, BorderSizePixel = 0 }, parent)
	corner(frame, 9); stroke(frame, blend(C.stroke, C.purple, 0.2), 1)
	return frame
end
local function title(parent, text)
	return label(parent, "✦  " .. text, {
		Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 23),
		Font = Enum.Font.GothamBold, Color = C.gold, TextSize = 10,
	})
end

local root = make("Frame", {
	Name = "SpellInventoryReferenceView", BackgroundColor3 = C.bg, BorderSizePixel = 0,
	Visible = false, Active = true, ClipsDescendants = true, ZIndex = 30,
}, panel)
corner(root, 10); stroke(root, blend(C.stroke, C.purple, 0.4), 1)
local main = make("Frame", { BackgroundTransparency = 1 }, root)
local side = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 326, 1, 0), BackgroundTransparency = 1 }, root)

local loadoutPanel = section(main, "EquippedLoadout", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 184))
title(loadoutPanel, "EQUIPPED LOADOUT")
local powerText = label(loadoutPanel, "Loadout Power  ✦ 0", {
	Position = UDim2.new(0.55, 0, 0, 6), Size = UDim2.new(0.45, -12, 0, 23),
	Font = Enum.Font.GothamBold, Color = C.purple, TextSize = 10, X = Enum.TextXAlignment.Right,
})
local loadoutScroll = make("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 35), Size = UDim2.new(1, -20, 1, -44), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.dim,
	AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.fromOffset(0, 0), ScrollingDirection = Enum.ScrollingDirection.X,
}, loadoutPanel)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, loadoutScroll)

local allPanel = section(main, "AllSpells", UDim2.fromOffset(0, 192), UDim2.new(1, 0, 1, -192))
title(allPanel, "ALL SPELLS")
local search = make("TextBox", {
	Position = UDim2.fromOffset(132, 5), Size = UDim2.new(1, -356, 0, 27), BackgroundColor3 = C.panel,
	BorderSizePixel = 0, ClearTextOnFocus = false, PlaceholderText = "Search spells...", PlaceholderColor3 = C.dim,
	Text = "", TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left,
}, allPanel)
corner(search, 6); stroke(search, C.stroke, 1); padding(search, 8, 0)
local elementButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -100, 0, 5), Size = UDim2.fromOffset(112, 27),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.GothamMedium,
	Text = "All Elements⌄", TextColor3 = C.text, TextSize = 7, AutoButtonColor = false,
}, allPanel)
corner(elementButton, 6); stroke(elementButton, C.stroke, 1)
local sortButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(86, 27),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.GothamMedium,
	Text = "Sort: Equipped", TextColor3 = C.text, TextSize = 7, AutoButtonColor = false,
}, allPanel)
corner(sortButton, 6); stroke(sortButton, C.stroke, 1)
local grid = make("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 39), Size = UDim2.new(1, -16, 1, -58), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.dim,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.fromOffset(0, 0),
}, allPanel)
local gridLayout = make("UIGridLayout", { CellSize = UDim2.fromOffset(116, 144), CellPadding = UDim2.fromOffset(7, 7), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
label(allPanel, "✦  Click to inspect. Double-click to equip or unequip.", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -16, 0, 13),
	Color = C.muted, TextSize = 7, X = Enum.TextXAlignment.Center,
})

local combosPanel = section(side, "AvailableCombos", UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 180))
title(combosPanel, "AVAILABLE COMBOS")
local combosList = make("Frame", { Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 1, -39), BackgroundTransparency = 1 }, combosPanel)
make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, combosList)

local damagePanel = section(side, "ElementDamage", UDim2.fromOffset(0, 188), UDim2.new(1, 0, 0, 152))
title(damagePanel, "ELEMENT DAMAGE BREAKDOWN")
local damageList = make("Frame", { Position = UDim2.fromOffset(10, 31), Size = UDim2.new(1, -20, 1, -37), BackgroundTransparency = 1 }, damagePanel)
make("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, damageList)

local spellDetails = section(side, "SpellDetails", UDim2.fromOffset(0, 348), UDim2.new(1, 0, 1, -348))
title(spellDetails, "SPELL DETAILS")
local detailStroke = spellDetails:FindFirstChildOfClass("UIStroke")
local detailIcon = make("Frame", { Position = UDim2.fromOffset(9, 31), Size = UDim2.fromOffset(74, 74), BackgroundColor3 = C.panel, BorderSizePixel = 0 }, spellDetails)
corner(detailIcon, 7); local detailIconStroke = stroke(detailIcon, C.purple, 1)
local detailName = label(spellDetails, "Select a spell", { Position = UDim2.fromOffset(92, 30), Size = UDim2.new(1, -101, 0, 23), Font = Enum.Font.GothamBold, TextSize = 12 })
local detailTags = label(spellDetails, "", { Position = UDim2.fromOffset(92, 53), Size = UDim2.new(1, -101, 0, 17), Color = C.purple, Font = Enum.Font.GothamMedium, TextSize = 7 })
local detailDescription = label(spellDetails, "Choose a spell to inspect it.", {
	Position = UDim2.fromOffset(92, 71), Size = UDim2.new(1, -101, 0, 49), Color = C.muted, TextSize = 7,
	Wrapped = true, Y = Enum.TextYAlignment.Top,
})
local statsFrame = make("Frame", { Position = UDim2.fromOffset(9, 127), Size = UDim2.new(1, -18, 0, 41), BackgroundTransparency = 1 }, spellDetails)
make("UIGridLayout", { CellSize = UDim2.new(0.25, -4, 1, 0), CellPadding = UDim2.fromOffset(5, 0), SortOrder = Enum.SortOrder.LayoutOrder }, statsFrame)
local statLabels = {}
for index, spec in ipairs({ {"Cooldown","cooldown"}, {"Damage","damage"}, {"Radius","radius"}, {"Duration","duration"} }) do
	local cell = make("Frame", { LayoutOrder = index, BackgroundColor3 = C.panel, BorderSizePixel = 0 }, statsFrame)
	corner(cell, 5)
	label(cell, spec[1], { Size = UDim2.new(1, 0, 0, 13), Color = C.muted, TextSize = 6, X = Enum.TextXAlignment.Center })
	statLabels[spec[2]] = label(cell, "-", { Position = UDim2.fromOffset(0, 13), Size = UDim2.new(1, 0, 1, -13), Font = Enum.Font.GothamBold, TextSize = 8, X = Enum.TextXAlignment.Center })
end
local status = label(spellDetails, "Status: -", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 9, 1, -8), Size = UDim2.new(1, -178, 0, 28),
	Color = C.muted, Font = Enum.Font.GothamMedium, TextSize = 7,
})
local moveUpButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -137, 1, -8), Size = UDim2.fromOffset(27, 27),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.GothamBold,
	Text = "‹", TextColor3 = C.gold, TextSize = 16, AutoButtonColor = false, Visible = false,
}, spellDetails)
corner(moveUpButton, 6); stroke(moveUpButton, C.stroke, 1)
local moveDownButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -103, 1, -8), Size = UDim2.fromOffset(27, 27),
	BackgroundColor3 = C.panel, BorderSizePixel = 0, Font = Enum.Font.GothamBold,
	Text = "›", TextColor3 = C.gold, TextSize = 16, AutoButtonColor = false, Visible = false,
}, spellDetails)
corner(moveDownButton, 6); stroke(moveDownButton, C.stroke, 1)
local equipButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -9, 1, -8), Size = UDim2.fromOffset(86, 27),
	BackgroundColor3 = C.purple, BorderSizePixel = 0, Font = Enum.Font.GothamBold,
	Text = "Equip", TextColor3 = Color3.new(1,1,1), TextSize = 8, AutoButtonColor = false,
}, spellDetails)
corner(equipButton, 6)

local state = { snapshot = {}, entries = {}, selectedId = nil, element = "All", sort = "Equipped", lastClick = {}, searchToken = 0 }
local refreshToken = 0
local toastToken = 0

local function toast(text, color)
	toastToken += 1
	local token = toastToken
	local object = panel:FindFirstChild("SpellReferenceToast")
	if not object then
		object = make("TextLabel", {
			Name = "SpellReferenceToast", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.fromOffset(320, 33), BackgroundColor3 = C.panel2, BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium, TextColor3 = C.text, TextSize = 9, ZIndex = 80,
		}, panel)
		corner(object, 7); local s = stroke(object, C.purple, 1); s.Name = "ToastStroke"
	end
	object.Text = tostring(text or ""); object.Visible = true
	local s = object:FindFirstChild("ToastStroke"); if s then s.Color = color or C.purple end
	task.delay(2, function() if token == toastToken and object.Parent then object.Visible = false end end)
end
local function selected()
	for _, entry in ipairs(state.entries) do if entry.id == state.selectedId then return entry end end
	return nil
end
local function byFamily(id)
	for _, entry in ipairs(state.entries) do if entry.familyId == id or entry.id == id then return entry end end
	return nil
end
local function loadoutFamilies()
	local set = {}
	for _, productId in ipairs((state.snapshot.spells and state.snapshot.spells.loadout) or {}) do
		local product = SpellDefs.GetProduct and SpellDefs.GetProduct(productId)
		local family = product and product.familyId or (SpellDefs.ProductToSpellId and SpellDefs.ProductToSpellId(productId)) or productId
		set[family] = true
	end
	return set
end
local function fire(actionType, payload)
	if not inventoryAction then toast("Inventory service is unavailable.", C.red); return false end
	local message = payload or {}; message.type = actionType; inventoryAction:FireServer(message); return true
end
local loadSnapshot
local function refresh(delaySeconds)
	refreshToken += 1; local token = refreshToken
	task.delay(delaySeconds or 0, function()
		if token == refreshToken and inventoryGui.Enabled and root.Visible then loadSnapshot() end
	end)
end
local function toggle(entry)
	entry = entry or selected(); if not entry then return end
	if not entry.unlocked then toast("This spell is locked.", C.red); return end
	local count = #((state.snapshot.spells and state.snapshot.spells.loadout) or {})
	local limit = tonumber(state.snapshot.spells and state.snapshot.spells.maxSlots) or 6
	if not entry.equipped and count >= limit then toast("Spell loadout is full.", C.red); return end
	fire(entry.equipped and "spellLoadoutUnequip" or "spellLoadoutEquip", { productId = entry.productId })
	toast(entry.equipped and "Spell removed from loadout" or "Spell added to loadout", elementColor(entry.element)); refresh(0.2)
end

local function renderDetails()
	local entry = selected()
	clear(detailIcon, { UICorner = true, UIStroke = true })
	if not entry then detailName.Text = "Select a spell"; return end
	local color = elementColor(entry.element); detailIconStroke.Color = color; detailStroke.Color = blend(C.stroke, color, 0.5)
	icon(detailIcon, entry, 20); detailName.Text = entry.displayName; detailName.TextColor3 = color
	detailTags.Text = string.format("%s   •   %s", entry.element or "Spell", entry.spellType or entry.attackType or "Magic"); detailTags.TextColor3 = color
	detailDescription.Text = tostring(entry.gameplayDescription or entry.description or entry.loreDescription or "")
	local d, cd, r, dur = damage(entry), cooldown(entry), radius(entry), duration(entry)
	statLabels.damage.Text = d > 0 and fmt(d) or "-"; statLabels.cooldown.Text = cd > 0 and fmt(cd).."s" or "-"
	statLabels.radius.Text = r > 0 and fmt(r) or "-"; statLabels.duration.Text = dur > 0 and fmt(dur).."s" or "-"
	status.Text = entry.equipped and ("✦  Status: Equipped in slot "..tostring(entry.loadoutIndex or "?")) or (entry.unlocked and "Status: Unlocked" or "Status: Locked")
	status.TextColor3 = entry.equipped and C.purple or (entry.unlocked and C.text or C.muted)
	local count = #((state.snapshot.spells and state.snapshot.spells.loadout) or {}); local limit = tonumber(state.snapshot.spells and state.snapshot.spells.maxSlots) or 6
	equipButton.Text = entry.equipped and "Unequip" or "Equip"; equipButton.BackgroundColor3 = entry.equipped and C.red or color
	equipButton.Active = entry.unlocked and (entry.equipped or count < limit); equipButton.TextTransparency = equipButton.Active and 0 or 0.5
	moveUpButton.Visible = entry.equipped; moveDownButton.Visible = entry.equipped
	moveUpButton.Active = entry.equipped and (tonumber(entry.loadoutIndex) or 1) > 1
	moveDownButton.Active = entry.equipped and (tonumber(entry.loadoutIndex) or limit) < count
	moveUpButton.TextTransparency = moveUpButton.Active and 0 or 0.55
	moveDownButton.TextTransparency = moveDownButton.Active and 0 or 0.55
end

local function renderLoadout()
	clear(loadoutScroll, { UIListLayout = true })
	local loadout = (state.snapshot.spells and state.snapshot.spells.loadout) or {}; local limit = tonumber(state.snapshot.spells and state.snapshot.spells.maxSlots) or 6; local power = 0
	for slotIndex = 1, limit do
		local productId = loadout[slotIndex]; local product = productId and SpellDefs.GetProduct and SpellDefs.GetProduct(productId)
		local family = product and product.familyId or (productId and SpellDefs.ProductToSpellId and SpellDefs.ProductToSpellId(productId)); local entry = family and byFamily(family)
		local color = entry and elementColor(entry.element) or C.stroke; if entry then power += damage(entry) end
		local card = make("TextButton", { LayoutOrder = slotIndex, Size = UDim2.fromOffset(103, 132), BackgroundColor3 = entry and blend(C.card, color, 0.14) or C.panel, BorderSizePixel = 0, Text = "", AutoButtonColor = false }, loadoutScroll)
		corner(card, 7); stroke(card, entry and color or C.stroke, entry and 1.4 or 1, entry and 0.12 or 0.35)
		local badge = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5,0,0,1), Size = UDim2.fromOffset(23,23), BackgroundColor3 = blend(C.panel,C.gold,0.18), BorderSizePixel=0, Font=Enum.Font.GothamBold, Text=tostring(slotIndex), TextColor3=C.gold, TextSize=9, ZIndex=34 }, card)
		corner(badge,4); stroke(badge,C.gold,1,0.25)
		local iconFrame = make("Frame", { Position=UDim2.fromOffset(8,15), Size=UDim2.new(1,-16,0,72), BackgroundColor3=entry and blend(C.panel,color,0.18) or C.panel2, BorderSizePixel=0 }, card); corner(iconFrame,6); icon(iconFrame,entry,20)
		label(card, entry and entry.displayName or "Empty Slot", { Position=UDim2.fromOffset(6,91), Size=UDim2.new(1,-12,0,18), Font=Enum.Font.GothamBold, Color=entry and color or C.dim, TextSize=8, X=Enum.TextXAlignment.Center, Truncate=Enum.TextTruncate.AtEnd })
		label(card, entry and string.format("%s  DMG %s",entry.element or "Spell",fmt(damage(entry))) or "Select a spell", { Position=UDim2.fromOffset(6,110), Size=UDim2.new(1,-12,0,14), Color=entry and C.muted or C.dim, TextSize=6, X=Enum.TextXAlignment.Center, Truncate=Enum.TextTruncate.AtEnd })
		if entry then card.MouseButton1Click:Connect(function() state.selectedId=entry.id; renderDetails() end) end
	end
	powerText.Text = "Loadout Power  ✦ "..fmt(power)
end

local function mini(parent, familyId, position)
	local entry = byFamily(familyId); local def = SpellDefs.GetSpell and SpellDefs.GetSpell(familyId); local element = entry and entry.element or def and def.element; local color = elementColor(element)
	local frame = make("Frame", { Position=position, Size=UDim2.fromOffset(31,31), BackgroundColor3=blend(C.panel,color,0.17), BorderSizePixel=0 }, parent); corner(frame,5); stroke(frame,color,1,0.3)
	if entry then icon(frame,entry,14) else label(frame,def and def.iconGlyph or "?",{Size=UDim2.fromScale(1,1),Font=Enum.Font.GothamBold,Color=color,TextSize=14,X=Enum.TextXAlignment.Center}) end
end
local function renderCombos()
	clear(combosList,{UIListLayout=true}); local equipped=loadoutFamilies(); local available={}
	for _, combo in ipairs((state.snapshot.spells and state.snapshot.spells.combinations) or {}) do
		local ok=true; for _, ingredient in ipairs(combo.ingredients or {}) do if not equipped[ingredient] then ok=false; break end end
		if ok then table.insert(available,combo) end
	end
	if #available==0 then label(combosList,"No active combination. Equip matching spell families.",{Size=UDim2.new(1,0,0,34),Color=C.muted,TextSize=8,Wrapped=true,X=Enum.TextXAlignment.Center}); return end
	for i=1,math.min(3,#available) do
		local combo=available[i]; local row=make("Frame",{LayoutOrder=i,Size=UDim2.new(1,0,0,42),BackgroundColor3=C.panel,BorderSizePixel=0},combosList); corner(row,6)
		local ingredients=combo.ingredients or {}; mini(row,ingredients[1],UDim2.fromOffset(6,5)); label(row,"+",{Position=UDim2.fromOffset(39,8),Size=UDim2.fromOffset(16,25),Font=Enum.Font.GothamBold,Color=C.gold,TextSize=11,X=Enum.TextXAlignment.Center})
		mini(row,ingredients[2],UDim2.fromOffset(56,5)); label(row,"→",{Position=UDim2.fromOffset(90,8),Size=UDim2.fromOffset(20,25),Font=Enum.Font.GothamBold,Color=C.gold,TextSize=12,X=Enum.TextXAlignment.Center}); mini(row,combo.resultId,UDim2.fromOffset(112,5))
		label(row,tostring(combo.name or combo.resultId or "Combination"),{Position=UDim2.fromOffset(150,3),Size=UDim2.new(1,-156,0,36),Font=Enum.Font.GothamBold,TextSize=7,Wrapped=true})
	end
end
local function renderDamage()
	clear(damageList,{UIListLayout=true}); local summary=(state.snapshot.spells and state.snapshot.spells.damageSummary) or {}; local total,max=0,0
	for _,b in ipairs(summary) do local d=math.max(0,tonumber(b.damage) or 0); total+=d; max=math.max(max,d) end
	for i,b in ipairs(summary) do if i>7 then break end; local d=math.max(0,tonumber(b.damage) or 0); local color=typeof(b.color)=="Color3" and b.color or elementColor(b.element)
		local row=make("Frame",{LayoutOrder=i,Size=UDim2.new(1,0,0,13),BackgroundTransparency=1},damageList); label(row,tostring(b.element or "Spell"),{Size=UDim2.fromOffset(57,13),Color=color,TextSize=6})
		local back=make("Frame",{Position=UDim2.fromOffset(61,4),Size=UDim2.new(1,-125,0,5),BackgroundColor3=blend(C.panel,C.stroke,0.25),BorderSizePixel=0},row); corner(back,999)
		local fill=make("Frame",{Size=UDim2.new(max>0 and d/max or 0,0,1,0),BackgroundColor3=color,BorderSizePixel=0},back); corner(fill,999)
		label(row,string.format("%s (%d%%)",fmt(d),total>0 and math.floor(d/total*100+0.5) or 0),{AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromOffset(61,13),Color=C.muted,TextSize=6,X=Enum.TextXAlignment.Right})
	end
end

local function filteredEntries()
	local result={}; local needle=normalized(search.Text)
	for _,entry in ipairs(state.entries) do
		local matchElement=state.element=="All" or entry.element==state.element; local hay=normalized((entry.displayName or "").." "..(entry.element or "").." "..(entry.attackType or ""))
		if matchElement and (needle=="" or string.find(hay,needle,1,true)) then table.insert(result,entry) end
	end
	table.sort(result,function(a,b)
		if state.sort=="Equipped" then if a.equipped~=b.equipped then return a.equipped end; if (a.loadoutIndex or math.huge)~=(b.loadoutIndex or math.huge) then return (a.loadoutIndex or math.huge)<(b.loadoutIndex or math.huge) end
		elseif state.sort=="Element" and tostring(a.element)~=tostring(b.element) then return tostring(a.element)<tostring(b.element)
		elseif state.sort=="Damage" and damage(a)~=damage(b) then return damage(a)>damage(b) end
		return tostring(a.displayName)<tostring(b.displayName)
	end); return result
end
local renderGrid
renderGrid=function()
	clear(grid,{UIGridLayout=true})
	for index,entry in ipairs(filteredEntries()) do
		local color=elementColor(entry.element); local chosen=entry.id==state.selectedId
		local card=make("TextButton",{LayoutOrder=index,BackgroundColor3=chosen and blend(C.card,color,0.2) or C.card,BorderSizePixel=0,Text="",AutoButtonColor=false,ClipsDescendants=true},grid); corner(card,7); stroke(card,chosen and color or blend(C.stroke,color,0.2),chosen and 1.7 or 1)
		local iconFrame=make("Frame",{Position=UDim2.fromOffset(6,6),Size=UDim2.new(1,-12,0,80),BackgroundColor3=blend(C.panel,color,0.16),BorderSizePixel=0},card); corner(iconFrame,6); icon(iconFrame,entry,20)
		if entry.equipped then local badge=make("TextLabel",{Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(40,14),BackgroundColor3=blend(C.panel,color,0.5),BorderSizePixel=0,Font=Enum.Font.GothamBold,Text="SLOT "..tostring(entry.loadoutIndex or "?"),TextColor3=Color3.new(1,1,1),TextSize=6,ZIndex=34},card); corner(badge,4) end
		label(card,entry.displayName,{Position=UDim2.fromOffset(6,90),Size=UDim2.new(1,-12,0,18),Font=Enum.Font.GothamBold,Color=entry.unlocked and color or C.muted,TextSize=8,X=Enum.TextXAlignment.Center,Truncate=Enum.TextTruncate.AtEnd})
		label(card,tostring(entry.element or "Spell"),{Position=UDim2.fromOffset(6,108),Size=UDim2.new(1,-12,0,12),Color=color,TextSize=6,X=Enum.TextXAlignment.Center})
		label(card,entry.unlocked and string.format("DMG %s  •  CD %ss",fmt(damage(entry)),fmt(cooldown(entry))) or "Locked",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,6,1,-4),Size=UDim2.new(1,-12,0,13),Color=entry.unlocked and C.muted or C.red,TextSize=6,X=Enum.TextXAlignment.Center})
		card.MouseButton1Click:Connect(function()
			state.selectedId=entry.id; renderGrid(); renderDetails(); local now=os.clock(); local last=state.lastClick[entry.id] or 0; state.lastClick[entry.id]=now; if now-last<=0.32 then toggle(entry) end
		end)
	end
end
local function renderAll() renderLoadout(); renderCombos(); renderDamage(); renderGrid(); renderDetails(); elementButton.Text=state.element=="All" and "All Elements⌄" or state.element.."⌄"; sortButton.Text="Sort: "..state.sort end

local function updateBounds()
	local origin=panel.AbsolutePosition; local x=center.AbsolutePosition.X-origin.X; local y=tabBar.AbsolutePosition.Y+tabBar.AbsoluteSize.Y+8-origin.Y
	local right=detailsColumn.AbsolutePosition.X+detailsColumn.AbsoluteSize.X-origin.X; local bottom=detailsColumn.AbsolutePosition.Y+detailsColumn.AbsoluteSize.Y-origin.Y
	root.Position=UDim2.fromOffset(math.max(0,x),math.max(0,y)); root.Size=UDim2.fromOffset(math.max(300,right-x),math.max(240,bottom-y))
	local showSide=root.AbsoluteSize.X>=820; side.Visible=showSide; main.Size=showSide and UDim2.new(1,-338,1,0) or UDim2.fromScale(1,1)
	local width=grid.AbsoluteSize.X; if width>10 then local columns=width>=650 and 5 or (width>=510 and 4 or (width>=370 and 3 or 2)); local gap=7; gridLayout.CellSize=UDim2.fromOffset(math.max(90,math.floor((width-gap*(columns-1)-4)/columns)),144) end
end

loadSnapshot=function(snapshot)
	if snapshot == nil then
		local ok, currentSnapshot = pcall(function() return currentSnapshotFunction:Invoke() end)
		if not ok or typeof(currentSnapshot) ~= "table" then toast("Could not load spell inventory.",C.red); return false end
		snapshot = currentSnapshot
	end
	if typeof(snapshot) ~= "table" then return false end
	state.snapshot=snapshot; state.entries=entriesBuilder.BuildSpellEntries((snapshot.spells and snapshot.spells.entries) or {},snapshot.spells)
	if not selected() then local first; for _,entry in ipairs(state.entries) do if entry.equipped then first=entry; break end end; first=first or state.entries[1]; state.selectedId=first and first.id end
	renderAll(); return true
end

search:GetPropertyChangedSignal("Text"):Connect(function() state.searchToken+=1; local token=state.searchToken; task.delay(0.08,function() if token==state.searchToken and root.Visible then renderGrid() end end) end)
elementButton.MouseButton1Click:Connect(function() local i=table.find(ELEMENTS,state.element) or 1; state.element=ELEMENTS[i%#ELEMENTS+1]; renderGrid(); elementButton.Text=state.element=="All" and "All Elements⌄" or state.element.."⌄" end)
sortButton.MouseButton1Click:Connect(function() local i=table.find(SORTS,state.sort) or 1; state.sort=SORTS[i%#SORTS+1]; renderGrid(); sortButton.Text="Sort: "..state.sort end)
equipButton.MouseButton1Click:Connect(function() toggle(selected()) end)
moveUpButton.MouseButton1Click:Connect(function()
	local entry = selected(); if not (entry and entry.equipped and moveUpButton.Active) then return end
	fire("spellLoadoutMove", { productId = entry.productId, direction = -1 })
	toast("Loadout order updated", elementColor(entry.element)); refresh(0.18)
end)
moveDownButton.MouseButton1Click:Connect(function()
	local entry = selected(); if not (entry and entry.equipped and moveDownButton.Active) then return end
	fire("spellLoadoutMove", { productId = entry.productId, direction = 1 })
	toast("Loadout order updated", elementColor(entry.element)); refresh(0.18)
end)

local function spellActive()
	local accent=spellTab:FindFirstChild("Accent"); return accent and accent:IsA("GuiObject") and accent.Visible
end
local function syncVisible()
	local visible=inventoryGui.Enabled and spellActive(); root.Visible=visible
	if visible then updateBounds(); loadSnapshot(); task.defer(updateBounds) end
end
for _,button in ipairs(tabButtons) do local accent=button:FindFirstChild("Accent"); if accent and accent:IsA("GuiObject") then accent:GetPropertyChangedSignal("Visible"):Connect(syncVisible) end end
inventoryGui:GetPropertyChangedSignal("Enabled"):Connect(syncVisible)
for _,object in ipairs({panel,center,detailsColumn,tabBar}) do object:GetPropertyChangedSignal("AbsolutePosition"):Connect(updateBounds); object:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateBounds) end
grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateBounds)
snapshotUpdatedEvent.Event:Connect(function(snapshot)
	if root.Visible then loadSnapshot(snapshot) end
end)
focusSpellSearchEvent.Event:Connect(function()
	if root.Visible then search:CaptureFocus() end
end)
syncVisible()
