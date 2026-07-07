-- LOCALSCRIPT: InventoryController.client.lua
-- GDZIE: Four Peaks/StarterPlayer/StarterPlayerScripts/InventoryController
-- CO: Kompletny remake ekwipunku lobby: podglad postaci, ikony, filtry, sortowanie,
--     porownanie broni, loadout spelli, materialy i Codex.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Only one InventoryController may control InventoryGui. Older copies left in
-- nested folders can wait for obsolete UI objects and consume the same inputs.
task.defer(function()
	local playerScripts = player:WaitForChild("PlayerScripts")
	for _, other in ipairs(playerScripts:GetDescendants()) do
		if other ~= script and other:IsA("LocalScript") and other.Name == "InventoryController" then
			pcall(function()
				other.Enabled = false
			end)
			warn("[InventoryController] Disabled duplicate controller:", other:GetFullName())
		end
	end
end)

local function findModule(name)
	local direct = ReplicatedStorage:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	for _, folderName in ipairs({ "ModuleScripts", "ModuleScript" }) do
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		local found = folder and folder:FindFirstChild(name, true)
		if found and found:IsA("ModuleScript") then
			return found
		end
	end
	return nil
end

local function safeRequire(name, fallback)
	local module = findModule(name)
	if not module then
		warn("[InventoryController] Missing module:", name)
		return fallback
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn("[InventoryController] Failed to require", name, result)
		return fallback
	end
	return result
end

local UiResponsive = safeRequire("UiResponsive", {})
local WeaponConfigs = safeRequire("WeaponConfigs", { Defs = {}, List = {} })
local Races = safeRequire("Races", { Defs = {} })
local CraftingConfig = safeRequire("CraftingConfig", {})
local SpellDefs = safeRequire("SpellDefinitions", {})
local MaterialDefinitions = safeRequire("MaterialDefinitions", nil)
local inventoryIconResolverModule = script.Parent:FindFirstChild("InventoryIconResolver")
assert(inventoryIconResolverModule and inventoryIconResolverModule:IsA("ModuleScript"), "[InventoryController] InventoryIconResolver ModuleScript is required")
local InventoryIconResolver = require(inventoryIconResolverModule)
local inventoryEntryBuilderModule = script.Parent:FindFirstChild("InventoryEntryBuilder")
assert(inventoryEntryBuilderModule and inventoryEntryBuilderModule:IsA("ModuleScript"), "[InventoryController] InventoryEntryBuilder ModuleScript is required")
local InventoryEntryBuilder = require(inventoryEntryBuilderModule)
local inventoryFilterSorterModule = script.Parent:FindFirstChild("InventoryFilterSorter")
assert(inventoryFilterSorterModule and inventoryFilterSorterModule:IsA("ModuleScript"), "[InventoryController] InventoryFilterSorter ModuleScript is required")
local InventoryFilterSorter = require(inventoryFilterSorterModule)

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions", 10)
local InventoryAction = remoteEvents and remoteEvents:WaitForChild("InventoryAction", 10)
local InventorySync = remoteEvents and remoteEvents:FindFirstChild("InventorySync")
local PlayerProgressEvent = remoteEvents and remoteEvents:FindFirstChild("PlayerProgressEvent")
local GetInventorySnapshot = remoteFunctions and remoteFunctions:WaitForChild("RF_GetInventorySnapshot", 10)

local THEME = {
	background = Color3.fromRGB(8, 10, 15),
	panel = Color3.fromRGB(15, 18, 26),
	panelAlt = Color3.fromRGB(20, 24, 34),
	panelSoft = Color3.fromRGB(25, 30, 42),
	card = Color3.fromRGB(25, 30, 42),
	cardHover = Color3.fromRGB(31, 38, 53),
	stroke = Color3.fromRGB(51, 60, 78),
	strokeSoft = Color3.fromRGB(40, 48, 64),
	text = Color3.fromRGB(240, 244, 251),
	muted = Color3.fromRGB(153, 165, 186),
	mutedDark = Color3.fromRGB(108, 119, 139),
	accent = Color3.fromRGB(98, 165, 255),
	purple = Color3.fromRGB(190, 120, 255),
	gold = Color3.fromRGB(255, 194, 92),
	green = Color3.fromRGB(92, 207, 139),
	red = Color3.fromRGB(235, 91, 91),
	orange = Color3.fromRGB(255, 146, 72),
}

local RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Mythical = 6,
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(176, 184, 198),
	Uncommon = Color3.fromRGB(99, 191, 119),
	Rare = Color3.fromRGB(83, 161, 255),
	Epic = Color3.fromRGB(178, 104, 255),
	Legendary = Color3.fromRGB(255, 173, 55),
	Mythic = Color3.fromRGB(255, 70, 82),
	Mythical = Color3.fromRGB(255, 70, 82),
}

local ELEMENT_COLORS = {
	Fire = Color3.fromRGB(255, 91, 55),
	Electricity = Color3.fromRGB(255, 226, 76),
	Electric = Color3.fromRGB(255, 226, 76),
	Air = Color3.fromRGB(181, 218, 228),
	Water = Color3.fromRGB(73, 157, 255),
	Earth = Color3.fromRGB(112, 171, 81),
	Void = Color3.fromRGB(159, 91, 236),
	Light = Color3.fromRGB(255, 232, 153),
	Physical = Color3.fromRGB(180, 180, 188),
}

local function create(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function addCorner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function addStroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color or THEME.stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, parent)
end

local function addPadding(parent, left, right, top, bottom)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or left or 0),
		PaddingTop = UDim.new(0, top or left or 0),
		PaddingBottom = UDim.new(0, bottom or top or left or 0),
	}, parent)
end

local function blend(a, b, alpha)
	return Color3.new(
		a.R + (b.R - a.R) * alpha,
		a.G + (b.G - a.G) * alpha,
		a.B + (b.B - a.B) * alpha
	)
end

local function formatNumber(value)
	local n = tonumber(value) or 0
	if math.abs(n) >= 1000000 then
		return string.format("%.1fm", n / 1000000)
	elseif math.abs(n) >= 1000 then
		return string.format("%.1fk", n / 1000)
	elseif math.abs(n - math.floor(n + 0.5)) < 0.01 then
		return tostring(math.floor(n + 0.5))
	end
	return string.format("%.1f", n)
end

local function normalizeSearch(value)
	return string.lower(tostring(value or "")):gsub("[%p%s]+", " ")
end

local function textContains(haystack, needle)
	needle = normalizeSearch(needle)
	if needle == "" then
		return true
	end
	return string.find(normalizeSearch(haystack), needle, 1, true) ~= nil
end

local function safeColor(value, fallback)
	return typeof(value) == "Color3" and value or fallback
end

local function getRarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "Common")] or RARITY_COLORS.Common
end

local function getElementColor(element)
	if SpellDefs.GetElementColor then
		local ok, result = pcall(SpellDefs.GetElementColor, element)
		if ok and typeof(result) == "Color3" then
			return result
		end
	end
	return ELEMENT_COLORS[tostring(element or "")] or THEME.accent
end

local function hoverColor(button, normal, hover)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			BackgroundColor3 = hover,
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
			BackgroundColor3 = normal,
		}):Play()
	end)
end

local function clearChildren(parent, keepClasses)
	keepClasses = keepClasses or {}
	for _, child in ipairs(parent:GetChildren()) do
		if not keepClasses[child.ClassName] then
			child:Destroy()
		end
	end
end

local inventoryIcons = InventoryIconResolver.new({
	ReplicatedStorage = ReplicatedStorage,
	WeaponConfigs = WeaponConfigs,
	MaterialDefinitions = MaterialDefinitions,
})
local weaponImage = inventoryIcons.WeaponImage
local materialImage = inventoryIcons.MaterialImage
local spellImage = inventoryIcons.SpellImage
local codexImage = inventoryIcons.CodexImage
local inventoryEntryBuilder = InventoryEntryBuilder.new({
	WeaponConfigs = WeaponConfigs,
	SpellDefs = SpellDefs,
	CraftingConfig = CraftingConfig,
	MaterialDefinitions = MaterialDefinitions,
})

local inventoryGui = playerGui:WaitForChild("InventoryGui")
inventoryGui.Enabled = false
inventoryGui.ResetOnSpawn = false
inventoryGui.IgnoreGuiInset = false
inventoryGui:SetAttribute("Modal", true)

local overlay = inventoryGui:FindFirstChild("overlay")
if not overlay or not overlay:IsA("Frame") then
	if overlay then overlay:Destroy() end
	overlay = create("Frame", { Name = "overlay" }, inventoryGui)
end
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
overlay.BackgroundTransparency = 0.25
overlay.BorderSizePixel = 0
clearChildren(overlay)

local panel = create("Frame", {
	Name = "RemakePanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.94, 0.9),
	BackgroundColor3 = THEME.panel,
	BorderSizePixel = 0,
}, overlay)
addCorner(panel, 16)
addStroke(panel, Color3.fromRGB(46, 55, 72), 1)
create("UISizeConstraint", {
	MinSize = Vector2.new(880, 520),
	MaxSize = Vector2.new(1280, 720),
}, panel)
if UiResponsive.attachCenteredPanel then
	pcall(UiResponsive.attachCenteredPanel, panel, Vector2.new(1280, 720))
end

local header = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 58),
	BackgroundTransparency = 1,
}, panel)

local title = create("TextLabel", {
	Position = UDim2.fromOffset(22, 11),
	Size = UDim2.new(0, 250, 0, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "Inventory",
	TextColor3 = THEME.text,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local subtitle = create("TextLabel", {
	Position = UDim2.fromOffset(22, 34),
	Size = UDim2.new(0, 420, 0, 16),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "Build, compare and prepare for the next run",
	TextColor3 = THEME.muted,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = THEME.panelSoft,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "×",
	TextColor3 = THEME.text,
	TextSize = 20,
	AutoButtonColor = false,
}, header)
addCorner(closeButton, 10)
hoverColor(closeButton, THEME.panelSoft, Color3.fromRGB(48, 54, 70))

local headerLine = create("Frame", {
	Position = UDim2.new(0, 18, 1, -1),
	Size = UDim2.new(1, -36, 0, 1),
	BackgroundColor3 = THEME.strokeSoft,
	BorderSizePixel = 0,
}, header)

local body = create("Frame", {
	Position = UDim2.fromOffset(18, 66),
	Size = UDim2.new(1, -36, 1, -84),
	BackgroundTransparency = 1,
}, panel)
local bodyLayout = create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, body)

local leftColumn = create("ScrollingFrame", {
	Name = "PlayerColumn",
	LayoutOrder = 1,
	Size = UDim2.new(0, 248, 1, 0),
	BackgroundColor3 = THEME.panelAlt,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = THEME.mutedDark,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromOffset(0, 0),
}, body)
addCorner(leftColumn, 12)
addStroke(leftColumn, THEME.strokeSoft, 1)
addPadding(leftColumn, 12, 12, 12, 12)

local leftLayout = create("UIListLayout", {
	Padding = UDim.new(0, 9),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, leftColumn)

local playerTitle = create("TextLabel", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = player.DisplayName,
	TextColor3 = THEME.text,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
}, leftColumn)

local playerMeta = create("TextLabel", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 16),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "Lv. 1 • Race: -",
	TextColor3 = THEME.muted,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
}, leftColumn)

local expWrap = create("Frame", {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 20),
	BackgroundTransparency = 1,
}, leftColumn)
local expText = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 11),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "EXP 0 / 1",
	TextColor3 = THEME.muted,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Left,
}, expWrap)
local expBack = create("Frame", {
	Position = UDim2.fromOffset(0, 13),
	Size = UDim2.new(1, 0, 0, 6),
	BackgroundColor3 = Color3.fromRGB(42, 48, 61),
	BorderSizePixel = 0,
}, expWrap)
addCorner(expBack, 999)
local expFill = create("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = THEME.accent,
	BorderSizePixel = 0,
}, expBack)
addCorner(expFill, 999)

local viewportFrame = create("ViewportFrame", {
	Name = "CharacterPreview",
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 220),
	BackgroundColor3 = Color3.fromRGB(11, 14, 21),
	BorderSizePixel = 0,
	Ambient = Color3.fromRGB(170, 180, 205),
	LightColor = Color3.fromRGB(255, 244, 224),
	LightDirection = Vector3.new(-1, -1, -1),
}, leftColumn)
addCorner(viewportFrame, 10)
addStroke(viewportFrame, THEME.strokeSoft, 1)
local viewportGradient = create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 31, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 12, 18)),
	}),
	Rotation = 90,
}, viewportFrame)

local viewportHint = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -7),
	Size = UDim2.new(1, -14, 0, 14),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "Drag to rotate",
	TextColor3 = Color3.fromRGB(122, 135, 157),
	TextSize = 9,
}, viewportFrame)

local viewportWorld = create("WorldModel", { Name = "PreviewWorld" }, viewportFrame)
local viewportCamera = create("Camera", { FieldOfView = 34 }, viewportFrame)
viewportFrame.CurrentCamera = viewportCamera
local previewModel = nil
local previewPivotOffset = CFrame.new()
local previewSize = Vector3.new(4, 6, 2)
local previewYaw = math.rad(18)
local previewDragging = false
local previewLastX = 0

local statsCard = create("Frame", {
	LayoutOrder = 5,
	Size = UDim2.new(1, 0, 0, 118),
	BackgroundColor3 = Color3.fromRGB(17, 21, 30),
	BorderSizePixel = 0,
}, leftColumn)
addCorner(statsCard, 9)
addStroke(statsCard, THEME.strokeSoft, 1)
addPadding(statsCard, 9, 9, 8, 8)
local statsGrid = create("UIGridLayout", {
	CellSize = UDim2.new(0.5, -4, 0, 24),
	CellPadding = UDim2.fromOffset(8, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, statsCard)

local statLabels = {}
local STAT_DISPLAY = {
	{ "HP", "HP" },
	{ "ATK", "ATK" },
	{ "DEF", "DEF" },
	{ "CRIT_RATE", "Crit" },
	{ "CRIT_DMG", "Crit DMG" },
	{ "LIFESTEAL", "Lifesteal" },
	{ "SPD", "Speed" },
}
for index, spec in ipairs(STAT_DISPLAY) do
	local cell = create("Frame", {
		LayoutOrder = index,
		BackgroundTransparency = 1,
	}, statsCard)
	local key = spec[1]
	create("TextLabel", {
		Size = UDim2.new(0.56, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = spec[2],
		TextColor3 = THEME.muted,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, cell)
	statLabels[key] = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.44, 0, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "0",
		TextColor3 = THEME.text,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, cell)
end

local currencyCard = create("Frame", {
	LayoutOrder = 6,
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundColor3 = Color3.fromRGB(17, 21, 30),
	BorderSizePixel = 0,
}, leftColumn)
addCorner(currencyCard, 9)
addStroke(currencyCard, THEME.strokeSoft, 1)
addPadding(currencyCard, 9, 9, 6, 6)
local currencyText = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "Silver 0   Souls 0\nWP 0   Tickets 0",
	TextColor3 = THEME.muted,
	TextSize = 10,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
}, currencyCard)

local centerColumn = create("Frame", {
	Name = "ContentColumn",
	LayoutOrder = 2,
	Size = UDim2.new(1, -602, 1, 0),
	BackgroundTransparency = 1,
}, body)
local centerLayout = create("UIListLayout", {
	Padding = UDim.new(0, 9),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, centerColumn)

local tabBar = create("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 42),
	BackgroundTransparency = 1,
}, centerColumn)
local tabLayout = create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 7),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local toolbar = create("Frame", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
}, centerColumn)

local searchBox = create("TextBox", {
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, -284, 1, 0),
	BackgroundColor3 = THEME.panelAlt,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	PlaceholderText = "Search inventory...",
	PlaceholderColor3 = THEME.mutedDark,
	Text = "",
	TextColor3 = THEME.text,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
}, toolbar)
addCorner(searchBox, 9)
addStroke(searchBox, THEME.strokeSoft, 1)
addPadding(searchBox, 12, 12, 0, 0)

local sortButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(92, 40),
	BackgroundColor3 = THEME.panelAlt,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamMedium,
	Text = "Sort",
	TextColor3 = THEME.text,
	TextSize = 10,
	AutoButtonColor = false,
}, toolbar)
addCorner(sortButton, 9)
addStroke(sortButton, THEME.strokeSoft, 1)
hoverColor(sortButton, THEME.panelAlt, THEME.panelSoft)

local filterButtonB = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -99, 0, 0),
	Size = UDim2.fromOffset(88, 40),
	BackgroundColor3 = THEME.panelAlt,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamMedium,
	Text = "Filter B",
	TextColor3 = THEME.text,
	TextSize = 9,
	AutoButtonColor = false,
}, toolbar)
addCorner(filterButtonB, 9)
addStroke(filterButtonB, THEME.strokeSoft, 1)
hoverColor(filterButtonB, THEME.panelAlt, THEME.panelSoft)

local filterButtonA = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -194, 0, 0),
	Size = UDim2.fromOffset(88, 40),
	BackgroundColor3 = THEME.panelAlt,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamMedium,
	Text = "Filter A",
	TextColor3 = THEME.text,
	TextSize = 9,
	AutoButtonColor = false,
}, toolbar)
addCorner(filterButtonA, 9)
addStroke(filterButtonA, THEME.strokeSoft, 1)
hoverColor(filterButtonA, THEME.panelAlt, THEME.panelSoft)

local auxiliaryPanel = create("Frame", {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 0),
	BackgroundColor3 = THEME.panelAlt,
	BorderSizePixel = 0,
	Visible = false,
	ClipsDescendants = true,
}, centerColumn)
addCorner(auxiliaryPanel, 11)
addStroke(auxiliaryPanel, THEME.strokeSoft, 1)

local contentCard = create("Frame", {
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 1, -100),
	BackgroundColor3 = THEME.panelAlt,
	BorderSizePixel = 0,
}, centerColumn)
addCorner(contentCard, 12)
addStroke(contentCard, THEME.strokeSoft, 1)

local contentHeader = create("Frame", {
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundTransparency = 1,
}, contentCard)
local contentTitle = create("TextLabel", {
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -130, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "Weapons",
	TextColor3 = THEME.text,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
}, contentHeader)
local contentCount = create("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 9),
	Size = UDim2.new(0, 110, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "0 items",
	TextColor3 = THEME.muted,
	TextSize = 9,
	TextXAlignment = Enum.TextXAlignment.Right,
}, contentHeader)

local gridScroll = create("ScrollingFrame", {
	Name = "GridScroll",
	Position = UDim2.fromOffset(8, 38),
	Size = UDim2.new(1, -16, 1, -46),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = THEME.mutedDark,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromOffset(0, 0),
}, contentCard)
local gridLayout = create("UIGridLayout", {
	CellSize = UDim2.fromOffset(160, 176),
	CellPadding = UDim2.fromOffset(9, 9),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, gridScroll)

local emptyState = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -40, 0, 60),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Text = "No items match these filters.",
	TextColor3 = THEME.muted,
	TextSize = 12,
	TextWrapped = true,
	Visible = false,
	ZIndex = 5,
}, contentCard)

local rightColumn = create("Frame", {
	Name = "DetailsColumn",
	LayoutOrder = 3,
	Size = UDim2.new(0, 330, 1, 0),
	BackgroundColor3 = THEME.panelAlt,
	BorderSizePixel = 0,
}, body)
addCorner(rightColumn, 12)
local rightStroke = addStroke(rightColumn, THEME.strokeSoft, 1)

local detailsAccent = create("Frame", {
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundColor3 = THEME.accent,
	BorderSizePixel = 0,
}, rightColumn)
addCorner(detailsAccent, 11)

local detailHeader = create("Frame", {
	Position = UDim2.fromOffset(14, 14),
	Size = UDim2.new(1, -28, 0, 98),
	BackgroundTransparency = 1,
}, rightColumn)
local detailIcon = create("Frame", {
	Size = UDim2.fromOffset(82, 82),
	BackgroundColor3 = THEME.panelSoft,
	BorderSizePixel = 0,
}, detailHeader)
addCorner(detailIcon, 12)
local detailIconStroke = addStroke(detailIcon, THEME.stroke, 1)
local detailIconImage = create("ImageLabel", {
	Position = UDim2.fromOffset(7, 7),
	Size = UDim2.new(1, -14, 1, -14),
	BackgroundTransparency = 1,
	Image = "",
	ScaleType = Enum.ScaleType.Fit,
	Visible = false,
}, detailIcon)
local detailIconGlyph = create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "?",
	TextColor3 = THEME.text,
	TextSize = 24,
}, detailIcon)

local detailName = create("TextLabel", {
	Position = UDim2.fromOffset(94, 3),
	Size = UDim2.new(1, -94, 0, 44),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "Select an item",
	TextColor3 = THEME.text,
	TextSize = 15,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, detailHeader)
local detailMeta = create("TextLabel", {
	Position = UDim2.fromOffset(94, 50),
	Size = UDim2.new(1, -94, 0, 38),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "Choose an item to inspect it.",
	TextColor3 = THEME.muted,
	TextSize = 10,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, detailHeader)

local detailScroll = create("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 118),
	Size = UDim2.new(1, -28, 1, -180),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = THEME.mutedDark,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.fromOffset(0, 0),
}, rightColumn)
local detailList = create("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, detailScroll)

local actionBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -14),
	Size = UDim2.new(1, -28, 0, 48),
	BackgroundTransparency = 1,
}, rightColumn)
local actionLayout = create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	Padding = UDim.new(0, 7),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, actionBar)

local tabButtons = {}
local TAB_DEFS = {
	{ id = "Weapons", label = "Weapons", accent = THEME.accent },
	{ id = "Spells", label = "Spell Loadout", accent = THEME.purple },
	{ id = "Materials", label = "Materials", accent = THEME.green },
	{ id = "Codex", label = "Codex", accent = THEME.gold },
}
for index, tab in ipairs(TAB_DEFS) do
	local button = create("TextButton", {
		LayoutOrder = index,
		Size = UDim2.new(0.25, -6, 1, 0),
		BackgroundColor3 = THEME.panelAlt,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = tab.label,
		TextColor3 = THEME.muted,
		TextSize = 10,
		AutoButtonColor = false,
	}, tabBar)
	addCorner(button, 9)
	local accent = create("Frame", {
		Name = "Accent",
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = tab.accent,
		BorderSizePixel = 0,
		Visible = false,
	}, button)
	addCorner(accent, 9)
	tabButtons[tab.id] = button
end

local toast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(320, 38),
	BackgroundColor3 = Color3.fromRGB(20, 24, 32),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamMedium,
	Text = "",
	TextColor3 = THEME.text,
	TextSize = 11,
	Visible = false,
	ZIndex = 30,
}, panel)
addCorner(toast, 10)
local toastStroke = addStroke(toast, THEME.stroke, 1, 1)

local confirmOverlay = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(2, 3, 5),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 50,
}, panel)
local confirmBox = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(400, 210),
	BackgroundColor3 = THEME.panel,
	BorderSizePixel = 0,
	ZIndex = 51,
}, confirmOverlay)
addCorner(confirmBox, 14)
addStroke(confirmBox, THEME.stroke, 1)
local confirmTitle = create("TextLabel", {
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.new(1, -36, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "Sell weapon?",
	TextColor3 = THEME.text,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 52,
}, confirmBox)
local confirmBody = create("TextLabel", {
	Position = UDim2.fromOffset(18, 56),
	Size = UDim2.new(1, -36, 0, 80),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "This action cannot be undone.",
	TextColor3 = THEME.muted,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 52,
}, confirmBox)
local confirmCancel = create("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -142, 1, -18),
	Size = UDim2.fromOffset(110, 38),
	BackgroundColor3 = THEME.panelSoft,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "Cancel",
	TextColor3 = THEME.text,
	TextSize = 11,
	ZIndex = 52,
	AutoButtonColor = false,
}, confirmBox)
addCorner(confirmCancel, 9)
local confirmAccept = create("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -18, 1, -18),
	Size = UDim2.fromOffset(116, 38),
	BackgroundColor3 = THEME.red,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "Sell",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 11,
	ZIndex = 52,
	AutoButtonColor = false,
}, confirmBox)
addCorner(confirmAccept, 9)

local snapshot = {}
local weaponEntries = {}
local spellEntries = {}
local materialEntries = {}
local codexEntries = {}
local currentEntries = {}
local selectedIds = {}
local selectedEntry = nil
local currentTab = "Weapons"
local level = 1
local xp = 0
local nextXp = 1
local currencies = { Silver = 0, Souls = 0, WeaponPoints = 0, Tickets = 0 }
local equippedWeaponId = nil
local toastToken = 0
local pendingConfirm = nil
local lastClickById = {}

local filters = {
	Weapons = { a = "All", b = "All" },
	Spells = { a = "All", b = "All" },
	Materials = { a = "All", b = "All" },
	Codex = { a = "All", b = "All" },
}

local sortIndices = {
	Weapons = 1,
	Spells = 1,
	Materials = 1,
	Codex = 1,
}

local SORT_OPTIONS = {
	Weapons = { "Equipped", "Rarity", "Level", "ATK", "Name" },
	Spells = { "Equipped", "Element", "Damage", "Name" },
	Materials = { "Amount", "Rarity", "Name" },
	Codex = { "Discovered", "Category", "Name" },
}

local FILTER_OPTIONS = {
	Weapons = {
		aLabel = "Type",
		a = { "All", "Sword", "Scythe", "Halberd", "Bow", "Staff", "Pistol" },
		bLabel = "Rarity",
		b = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical" },
	},
	Spells = {
		aLabel = "Element",
		a = { "All", "Fire", "Electricity", "Air", "Water", "Earth", "Void", "Light", "Physical" },
		bLabel = "Status",
		b = { "All", "Equipped", "Unlocked", "Locked" },
	},
	Materials = {
		aLabel = "Source",
		a = { "All", "Mine", "Monster", "Forge" },
		bLabel = "Rarity",
		b = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" },
	},
	Codex = {
		aLabel = "Category",
		a = { "All", "Spells", "Combinations", "Enemies", "Elites", "Bosses", "Weapons", "Materials" },
		bLabel = "Status",
		b = { "All", "Discovered", "Undiscovered" },
	},
}

local function showToast(message, color)
	toastToken += 1
	local token = toastToken
	toast.Text = tostring(message or "")
	toast.BackgroundColor3 = blend(Color3.fromRGB(20, 24, 32), color or THEME.accent, 0.18)
	toastStroke.Color = color or THEME.accent
	toast.Visible = true
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toastStroke.Transparency = 1
	TweenService:Create(toast, TweenInfo.new(0.16), {
		BackgroundTransparency = 0.04,
		TextTransparency = 0,
	}):Play()
	TweenService:Create(toastStroke, TweenInfo.new(0.16), { Transparency = 0 }):Play()
	task.delay(2.2, function()
		if token ~= toastToken then return end
		local fade = TweenService:Create(toast, TweenInfo.new(0.2), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		TweenService:Create(toastStroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		fade:Play()
		fade.Completed:Wait()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

local function fireInventoryAction(actionType, payload)
	if not InventoryAction then
		showToast("Inventory service is unavailable.", THEME.red)
		return false
	end
	local message = payload or {}
	message.type = actionType
	InventoryAction:FireServer(message)
	return true
end

local function getEquippedWeapon()
	for _, entry in ipairs(weaponEntries) do
		if entry.id == equippedWeaponId then
			return entry
		end
	end
	return nil
end

local function computePlayerStats()
	local raceName = tostring(player:GetAttribute("Race") or "")
	local raceDef = Races.Defs and Races.Defs[raceName]
	local raceStats = (raceDef and raceDef.stats) or {}
	local weapon = getEquippedWeapon()
	local ws = weapon and weapon.stats or {}
	local function r(key) return tonumber(raceStats[key]) or 0 end
	local function w(key) return tonumber(ws[key]) or 0 end
	return {
		HP = r("HP") + w("HP"),
		ATK = w("ATK") + r("PhysicalPower") + r("MagicPower") + r("STR"),
		DEF = r("Armor") + w("DEF"),
		LIFESTEAL = r("LifeSteal") + w("LIFESTEAL"),
		CRIT_RATE = r("CritChance") + w("CRIT_RATE"),
		CRIT_DMG = r("CritDmg") + w("CRIT_DMG"),
		SPD = r("MoveSpeed") + w("SPD"),
	}
end

local function refreshPlayerPanel()
	local raceName = tostring(player:GetAttribute("Race") or "-")
	playerTitle.Text = string.format("%s  •  Lv. %d", player.DisplayName, level)
	playerMeta.Text = string.format("@%s  •  Race: %s", player.Name, raceName)
	expText.Text = string.format("EXP %s / %s", formatNumber(xp), formatNumber(math.max(1, nextXp)))
	local ratio = math.clamp(xp / math.max(1, nextXp), 0, 1)
	TweenService:Create(expFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()
	local stats = computePlayerStats()
	for key, label in pairs(statLabels) do
		local suffix = (key == "CRIT_RATE" or key == "CRIT_DMG" or key == "LIFESTEAL" or key == "SPD") and "%" or ""
		label.Text = formatNumber(stats[key] or 0) .. suffix
	end
	currencyText.Text = string.format(
		"Silver  %s    Souls  %s\nWP  %s    Tickets  %s",
		formatNumber(currencies.Silver),
		formatNumber(currencies.Souls),
		formatNumber(currencies.WeaponPoints),
		formatNumber(currencies.Tickets)
	)
end

local function refreshCharacterPreview()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end
	for _, child in ipairs(viewportWorld:GetChildren()) do
		child:Destroy()
	end
	local character = player.Character
	if not character then
		return
	end
	local oldArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function() return character:Clone() end)
	character.Archivable = oldArchivable
	if not ok or not clone then
		return
	end
	clone.Name = "PreviewCharacter"
	for _, object in ipairs(clone:GetDescendants()) do
		if object:IsA("BaseScript") then
			object:Destroy()
		elseif object:IsA("BasePart") then
			object.Anchored = true
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
		elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
			object.Enabled = false
		elseif object:IsA("Humanoid") then
			object.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			object.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end
	clone.Parent = viewportWorld
	previewModel = clone
	local boxCFrame, size = clone:GetBoundingBox()
	previewSize = size
	previewPivotOffset = boxCFrame:ToObjectSpace(clone:GetPivot())
	clone:PivotTo(CFrame.Angles(0, previewYaw, 0) * previewPivotOffset)
	local focus = Vector3.new(0, 0, 0)
	local distance = math.max(size.Y * 1.15, size.X * 1.8, 7)
	viewportCamera.CFrame = CFrame.new(Vector3.new(0, size.Y * 0.02, -distance), focus)
end

local function rotatePreview(deltaX)
	if not previewModel then return end
	previewYaw += deltaX * 0.012
	previewModel:PivotTo(CFrame.Angles(0, previewYaw, 0) * previewPivotOffset)
end

viewportFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		previewDragging = true
		previewLastX = input.Position.X
	end
end)
viewportFrame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		previewDragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not previewDragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Position.X - previewLastX
		previewLastX = input.Position.X
		rotatePreview(delta)
	end
end)

local detailOrderCounter = 0
local function nextDetailOrder()
	detailOrderCounter += 1
	return detailOrderCounter
end

local function makeActionButton(label, color, order)
	local button = create("TextButton", {
		LayoutOrder = order or 1,
		Size = UDim2.fromOffset(92, 40),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = label,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 10,
		AutoButtonColor = false,
	}, actionBar)
	addCorner(button, 9)
	hoverColor(button, color, blend(color, Color3.new(1, 1, 1), 0.12))
	return button
end

local function addDetailLabel(text, options)
	options = options or {}
	local label = create("TextLabel", {
		LayoutOrder = options.order or nextDetailOrder(),
		Size = UDim2.new(1, -4, 0, options.height or 18),
		AutomaticSize = options.auto and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		BackgroundTransparency = 1,
		Font = options.bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		Text = tostring(text or ""),
		TextColor3 = options.color or THEME.muted,
		TextSize = options.size or 10,
		TextWrapped = options.wrap ~= false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = options.y or Enum.TextYAlignment.Top,
	}, detailScroll)
	return label
end

local function addSectionTitle(text, color)
	return addDetailLabel(string.upper(text), {
		bold = true,
		color = color or THEME.text,
		size = 10,
		height = 18,
	})
end

local function addDivider()
	return create("Frame", {
		LayoutOrder = nextDetailOrder(),
		Size = UDim2.new(1, -4, 0, 1),
		BackgroundColor3 = THEME.strokeSoft,
		BorderSizePixel = 0,
	}, detailScroll)
end

local function addPillRow(values)
	local row = create("Frame", {
		LayoutOrder = nextDetailOrder(),
		Size = UDim2.new(1, -4, 0, 28),
		BackgroundTransparency = 1,
	}, detailScroll)
	local layout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
	}, row)
	for _, item in ipairs(values or {}) do
		local pill = create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			BackgroundColor3 = blend(THEME.panelSoft, item.color or THEME.accent, 0.18),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			Text = "  " .. tostring(item.text) .. "  ",
			TextColor3 = item.color or THEME.text,
			TextSize = 9,
		}, row)
		addCorner(pill, 7)
	end
	return row
end

local function setDetailIcon(imageRef, glyph, color)
	local accent = color or THEME.accent
	detailIcon.BackgroundColor3 = blend(THEME.panelSoft, accent, 0.18)
	detailIconStroke.Color = blend(THEME.stroke, accent, 0.6)
	if typeof(imageRef) == "string" and imageRef ~= "" then
		detailIconImage.Image = imageRef
		detailIconImage.Visible = true
		detailIconGlyph.Visible = false
	else
		detailIconImage.Visible = false
		detailIconGlyph.Visible = true
		detailIconGlyph.Text = tostring(glyph or "?")
		detailIconGlyph.TextColor3 = accent
	end
end

local function resetDetails()
	detailOrderCounter = 0
	clearChildren(detailScroll, { UIListLayout = true })
	clearChildren(actionBar, { UIListLayout = true })
	detailName.Text = "Select an item"
	detailName.TextColor3 = THEME.text
	detailMeta.Text = "Choose a card to inspect details and available actions."
	setDetailIcon(nil, "?", THEME.muted)
	detailsAccent.BackgroundColor3 = THEME.accent
	rightStroke.Color = THEME.strokeSoft
	selectedEntry = nil
end

local STAT_ORDER = {
	{ key = "ATK", label = "ATK", percent = false },
	{ key = "HP", label = "HP", percent = false },
	{ key = "DEF", label = "DEF", percent = false },
	{ key = "CRIT_RATE", label = "Crit Rate", percent = true },
	{ key = "CRIT_DMG", label = "Crit DMG", percent = true },
	{ key = "LIFESTEAL", label = "Lifesteal", percent = true },
	{ key = "SPD", label = "Speed", percent = true },
}

local function addWeaponStatRow(spec, selectedStats, equippedStats, comparing)
	local row = create("Frame", {
		LayoutOrder = nextDetailOrder(),
		Size = UDim2.new(1, -4, 0, 24),
		BackgroundColor3 = Color3.fromRGB(18, 22, 31),
		BorderSizePixel = 0,
	}, detailScroll)
	addCorner(row, 6)
	create("TextLabel", {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0.45, -8, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = spec.label,
		TextColor3 = THEME.muted,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local selectedValue = tonumber(selectedStats[spec.key]) or 0
	local equippedValue = tonumber(equippedStats[spec.key]) or 0
	local suffix = spec.percent and "%" or ""
	local text
	local color = THEME.text
	if comparing then
		local delta = selectedValue - equippedValue
		local sign = delta > 0 and "+" or ""
		text = string.format("%s → %s  (%s%s%s)", formatNumber(equippedValue), formatNumber(selectedValue), sign, formatNumber(delta), suffix)
		if delta > 0 then color = THEME.green elseif delta < 0 then color = THEME.red end
	else
		text = formatNumber(selectedValue) .. suffix
	end
	create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.55, -8, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = color,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
end

local loadSnapshot

local function renderWeaponDetails(entry)
	resetDetails()
	if not entry then return end
	selectedEntry = entry
	local color = getRarityColor(entry.rarity)
	detailsAccent.BackgroundColor3 = color
	rightStroke.Color = blend(THEME.strokeSoft, color, 0.45)
	detailName.Text = entry.displayName
	detailName.TextColor3 = color
	detailMeta.Text = string.format("%s • %s • Lv. %d/%d", entry.weaponType, entry.rarity, entry.level, entry.maxLevel)
	setDetailIcon(weaponImage(entry), string.upper(string.sub(entry.weaponType or "W", 1, 1)), color)

	addPillRow({
		{ text = entry.element or "Physical", color = getElementColor(entry.element) },
		{ text = entry.weaponType or "Weapon", color = color },
		{ text = entry.id == equippedWeaponId and "Equipped" or "Owned", color = entry.id == equippedWeaponId and THEME.green or THEME.muted },
	})
	if entry.description ~= "" then
		addDetailLabel(entry.description, { auto = true, size = 10, color = Color3.fromRGB(198, 207, 222) })
	end
	addDivider()
	local equipped = getEquippedWeapon()
	local comparing = equipped ~= nil and equipped.id ~= entry.id
	addSectionTitle(comparing and "Compare with equipped" or "Stats", color)
	for _, spec in ipairs(STAT_ORDER) do
		addWeaponStatRow(spec, entry.stats or {}, (equipped and equipped.stats) or {}, comparing)
	end

	local def = entry.def or {}
	if tostring(def.passiveName or "") ~= "" or tostring(def.passiveDescription or "") ~= "" then
		addDivider()
		addSectionTitle(def.passiveName ~= "" and def.passiveName or "Passive", THEME.gold)
		addDetailLabel(def.passiveDescription or "", { auto = true, size = 10, color = Color3.fromRGB(197, 205, 218) })
	end
	if tostring(def.abilityName or "") ~= "" or tostring(def.abilityDescription or "") ~= "" then
		addDivider()
		addSectionTitle(def.abilityName ~= "" and def.abilityName or "Ability", THEME.purple)
		addDetailLabel(def.abilityDescription or "", { auto = true, size = 10, color = Color3.fromRGB(197, 205, 218) })
	end

	local equip = makeActionButton(entry.id == equippedWeaponId and "Equipped" or "Equip", entry.id == equippedWeaponId and Color3.fromRGB(60, 78, 70) or THEME.accent, 1)
	equip.Active = entry.id ~= equippedWeaponId
	equip.TextTransparency = entry.id == equippedWeaponId and 0.35 or 0
	equip.MouseButton1Click:Connect(function()
		if entry.id == equippedWeaponId then return end
		fireInventoryAction("equip", { id = entry.id })
		equippedWeaponId = entry.id
		showToast("Equipped " .. entry.displayName, THEME.green)
		refreshPlayerPanel()
		refreshCharacterPreview()
		task.delay(0.2, function()
			if inventoryGui.Enabled and loadSnapshot then loadSnapshot(true) end
		end)
	end)

	local favorite = makeActionButton(entry.favorite and "★ Saved" or "☆ Favorite", Color3.fromRGB(123, 93, 43), 2)
	favorite.MouseButton1Click:Connect(function()
		entry.favorite = not entry.favorite
		fireInventoryAction("favorite", { id = entry.id, value = entry.favorite })
		showToast(entry.favorite and "Added to favorites" or "Removed from favorites", THEME.gold)
		favorite.Text = entry.favorite and "★ Saved" or "☆ Favorite"
	end)

	local sell = makeActionButton("Sell", Color3.fromRGB(138, 55, 59), 3)
	sell.MouseButton1Click:Connect(function()
		pendingConfirm = entry
		confirmTitle.Text = "Sell " .. entry.displayName .. "?"
		local valueText = entry.sellValue > 0 and ("\nEstimated value: " .. formatNumber(entry.sellValue) .. " Silver") or ""
		confirmBody.Text = "This permanently removes this weapon instance. Favorites do not protect a weapon from manual selling." .. valueText
		confirmOverlay.Visible = true
	end)
end

local function getSpellDamage(entry)
	for _, line in ipairs(entry.statLines or {}) do
		local value = string.match(tostring(line), "Damage%s+([%d%.]+)")
		if value then return tonumber(value) or 0 end
	end
	return 0
end

local inventoryFilterSorter = InventoryFilterSorter.new({
	RarityOrder = RARITY_ORDER,
	TextContains = textContains,
	GetSpellDamage = function(entry)
		return getSpellDamage(entry)
	end,
})

local function spellCombinationNames(entry)
	local names = {}
	for _, combo in ipairs(entry.combinations or {}) do
		local resultId = combo.resultId or combo.ResultId
		local result = resultId and SpellDefs.GetSpell and SpellDefs.GetSpell(resultId)
		table.insert(names, result and result.name or tostring(resultId or combo.id or "Combination"))
	end
	return names
end

local function renderSpellDetails(entry)
	resetDetails()
	if not entry then return end
	selectedEntry = entry
	local color = getElementColor(entry.element)
	detailsAccent.BackgroundColor3 = color
	rightStroke.Color = blend(THEME.strokeSoft, color, 0.48)
	detailName.Text = entry.displayName
	detailName.TextColor3 = color
	detailMeta.Text = string.format("%s • %s • %s", entry.element or "Spell", entry.spellType or "Magic", entry.attackType or "Attack")
	setDetailIcon(spellImage(entry), entry.iconGlyph, color)

	addPillRow({
		{ text = entry.equipped and ("Slot " .. tostring(entry.loadoutIndex or "?")) or (entry.unlocked and "Unlocked" or "Locked"), color = entry.equipped and THEME.green or (entry.unlocked and THEME.accent or THEME.muted) },
		{ text = entry.element or "Spell", color = color },
	})
	local lore = tostring(entry.loreDescription or "")
	if lore ~= "" then
		addDetailLabel(lore, { auto = true, size = 10, color = Color3.fromRGB(214, 219, 230) })
	end
	local gameplay = tostring(entry.gameplayDescription or entry.description or "")
	if gameplay ~= "" then
		addSectionTitle("Gameplay", color)
		addDetailLabel(gameplay, { auto = true, size = 10, color = THEME.muted })
	end
	if #(entry.statLines or {}) > 0 then
		addDivider()
		addSectionTitle("Stats", color)
		for _, line in ipairs(entry.statLines) do
			addDetailLabel("• " .. tostring(line), { height = 16, size = 9, color = Color3.fromRGB(196, 205, 220) })
		end
	end
	local comboNames = spellCombinationNames(entry)
	if #comboNames > 0 then
		addDivider()
		addSectionTitle("Possible combinations", THEME.gold)
		for _, name in ipairs(comboNames) do
			addDetailLabel("◇ " .. name, { height = 17, size = 9, color = Color3.fromRGB(239, 205, 132) })
		end
	end
	if tostring(entry.visualDirection or "") ~= "" then
		addDivider()
		addSectionTitle("Visual identity", THEME.purple)
		addDetailLabel(entry.visualDirection, { auto = true, size = 9, color = THEME.muted })
	end

	local maxSlots = tonumber(snapshot.spells and snapshot.spells.maxSlots) or 6
	local loadoutCount = #((snapshot.spells and snapshot.spells.loadout) or {})
	local actionText = entry.equipped and "Unequip" or "Equip"
	local actionColor = entry.equipped and Color3.fromRGB(132, 70, 86) or THEME.purple
	local equip = makeActionButton(actionText, actionColor, 1)
	equip.Active = entry.unlocked and (entry.equipped or loadoutCount < maxSlots)
	equip.TextTransparency = equip.Active and 0 or 0.45
	equip.MouseButton1Click:Connect(function()
		if not entry.unlocked then
			showToast("This spell is locked.", THEME.red)
			return
		end
		if not entry.equipped and loadoutCount >= maxSlots then
			showToast("Spell loadout is full.", THEME.red)
			return
		end
		fireInventoryAction(entry.equipped and "spellLoadoutUnequip" or "spellLoadoutEquip", {
			productId = entry.productId,
		})
		showToast(entry.equipped and "Spell removed from loadout" or "Spell added to loadout", color)
		task.delay(0.2, function()
			if inventoryGui.Enabled and loadSnapshot then loadSnapshot(true) end
		end)
	end)
	if entry.equipped then
		local up = makeActionButton("Move Up", THEME.panelSoft, 2)
		up.MouseButton1Click:Connect(function()
			fireInventoryAction("spellLoadoutMove", { productId = entry.productId, direction = -1 })
			showToast("Loadout order updated", color)
			task.delay(0.18, function() if inventoryGui.Enabled and loadSnapshot then loadSnapshot(true) end end)
		end)
		local down = makeActionButton("Move Down", THEME.panelSoft, 3)
		down.MouseButton1Click:Connect(function()
			fireInventoryAction("spellLoadoutMove", { productId = entry.productId, direction = 1 })
			showToast("Loadout order updated", color)
			task.delay(0.18, function() if inventoryGui.Enabled and loadSnapshot then loadSnapshot(true) end end)
		end)
	end
end

local function renderMaterialDetails(entry)
	resetDetails()
	if not entry then return end
	selectedEntry = entry
	local color = getRarityColor(entry.rarity)
	detailsAccent.BackgroundColor3 = color
	rightStroke.Color = blend(THEME.strokeSoft, color, 0.42)
	detailName.Text = entry.displayName
	detailName.TextColor3 = color
	detailMeta.Text = string.format("%s • %s • Stored %s", entry.bucket, entry.rarity, formatNumber(entry.amount))
	setDetailIcon(materialImage(entry), string.upper(string.sub(entry.displayName, 1, 1)), color)
	addPillRow({
		{ text = entry.rarity, color = color },
		{ text = entry.sourceLabel, color = THEME.green },
	})
	addDetailLabel(entry.description, { auto = true, size = 10, color = Color3.fromRGB(200, 208, 221) })
	addDivider()
	addSectionTitle("Source", THEME.green)
	addDetailLabel(entry.source or entry.sourceLabel, { auto = true, size = 10 })
	addDivider()
	addSectionTitle("Used for", THEME.gold)
	if #(entry.usedFor or {}) == 0 then
		addDetailLabel("No current recipe uses this material.", { auto = true, size = 10 })
	else
		for _, use in ipairs(entry.usedFor) do
			addDetailLabel("• " .. tostring(use), { height = 17, size = 9, color = Color3.fromRGB(226, 208, 167) })
		end
	end
end

local function renderCodexDetails(entry)
	resetDetails()
	if not entry then return end
	selectedEntry = entry
	local color = entry.element and getElementColor(entry.element) or getRarityColor(entry.rarity)
	detailsAccent.BackgroundColor3 = color
	rightStroke.Color = blend(THEME.strokeSoft, color, 0.42)
	detailName.Text = entry.displayName
	detailName.TextColor3 = entry.discovered and color or THEME.muted
	detailMeta.Text = string.format("%s • %s", entry.category or "Codex", entry.discovered and "Discovered" or "Undiscovered")
	setDetailIcon(codexImage(entry), entry.iconGlyph, color)
	addPillRow({
		{ text = entry.category or "Codex", color = color },
		{ text = entry.discovered and "Discovered" or "Undiscovered", color = entry.discovered and THEME.green or THEME.muted },
	})
	if not entry.discovered and entry.displayName == "???" then
		addDetailLabel("This entry is hidden until it is discovered during gameplay.", { auto = true, size = 10 })
		return
	end
	local lore = entry.loreDescription or entry.description
	if tostring(lore or "") ~= "" then
		addSectionTitle("Lore", THEME.gold)
		addDetailLabel(lore, { auto = true, size = 10, color = Color3.fromRGB(211, 215, 224) })
	end
	if tostring(entry.gameplayDescription or "") ~= "" then
		addDivider()
		addSectionTitle("Gameplay", color)
		addDetailLabel(entry.gameplayDescription, { auto = true, size = 10 })
	end
	if entry.ingredients and #entry.ingredients > 0 then
		addDivider()
		addSectionTitle("Ingredients", THEME.purple)
		for _, ingredient in ipairs(entry.ingredients) do
			local def = SpellDefs.GetSpell and SpellDefs.GetSpell(ingredient)
			addDetailLabel("• " .. ((def and def.name) or tostring(ingredient)), { height = 17, size = 9 })
		end
	end
	if tostring(entry.visualDirection or "") ~= "" then
		addDivider()
		addSectionTitle("Visual direction", THEME.purple)
		addDetailLabel(entry.visualDirection, { auto = true, size = 9 })
	end
end

local function renderDetails(entry)
	if currentTab == "Weapons" then
		renderWeaponDetails(entry)
	elseif currentTab == "Spells" then
		renderSpellDetails(entry)
	elseif currentTab == "Materials" then
		renderMaterialDetails(entry)
	elseif currentTab == "Codex" then
		renderCodexDetails(entry)
	end
end

local function currentTabAccent()
	for _, tab in ipairs(TAB_DEFS) do
		if tab.id == currentTab then return tab.accent end
	end
	return THEME.accent
end

local function tabSourceEntries()
	if currentTab == "Weapons" then return weaponEntries end
	if currentTab == "Spells" then return spellEntries end
	if currentTab == "Materials" then return materialEntries end
	return codexEntries
end

local function currentSort()
	local options = SORT_OPTIONS[currentTab]
	local index = math.clamp(sortIndices[currentTab] or 1, 1, #options)
	return options[index]
end

local function getFilteredEntries()
	return inventoryFilterSorter.GetFilteredEntries(
		tabSourceEntries(),
		currentTab,
		searchBox.Text,
		filters[currentTab],
		currentSort(),
		equippedWeaponId
	)
end

local function cardAccent(entry)
	if currentTab == "Weapons" or currentTab == "Materials" then
		return getRarityColor(entry.rarity)
	elseif currentTab == "Spells" then
		return getElementColor(entry.element)
	elseif entry.element then
		return getElementColor(entry.element)
	end
	return getRarityColor(entry.rarity)
end

local function cardImage(entry)
	if currentTab == "Weapons" then return weaponImage(entry) end
	if currentTab == "Spells" then return spellImage(entry) end
	if currentTab == "Materials" then return materialImage(entry) end
	return codexImage(entry)
end

local function cardGlyph(entry)
	if currentTab == "Weapons" then
		return string.upper(string.sub(entry.weaponType or "W", 1, 1))
	elseif currentTab == "Spells" then
		return entry.iconGlyph or string.upper(string.sub(entry.displayName, 1, 2))
	elseif currentTab == "Materials" then
		return string.upper(string.sub(entry.displayName, 1, 1))
	end
	return entry.iconGlyph or "?"
end

local function cardFooter(entry)
	if currentTab == "Weapons" then
		return string.format("Lv. %d   •   ATK %s", entry.level, formatNumber(entry.stats and entry.stats.ATK))
	elseif currentTab == "Spells" then
		if entry.equipped then return "Equipped • Slot " .. tostring(entry.loadoutIndex or "?") end
		return entry.unlocked and ((entry.statLines and entry.statLines[1]) or entry.attackType) or "Locked"
	elseif currentTab == "Materials" then
		return string.format("Stored %s", formatNumber(entry.amount))
	end
	return entry.discovered and "Discovered" or "Undiscovered"
end

local function createCard(entry, index)
	local accent = cardAccent(entry)
	local selected = selectedIds[currentTab] == entry.id
	local card = create("TextButton", {
		LayoutOrder = index,
		BackgroundColor3 = selected and blend(THEME.card, accent, 0.18) or THEME.card,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ClipsDescendants = true,
	}, gridScroll)
	addCorner(card, 10)
	local cardStroke = addStroke(card, selected and accent or blend(THEME.strokeSoft, accent, 0.18), selected and 2 or 1)
	local topAccent = create("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
	}, card)

	local iconWrap = create("Frame", {
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 86),
		BackgroundColor3 = blend(Color3.fromRGB(20, 24, 34), accent, 0.14),
		BorderSizePixel = 0,
	}, card)
	addCorner(iconWrap, 8)
	local imageRef = cardImage(entry)
	if imageRef then
		create("ImageLabel", {
			Position = UDim2.fromOffset(8, 7),
			Size = UDim2.new(1, -16, 1, -14),
			BackgroundTransparency = 1,
			Image = imageRef,
			ScaleType = Enum.ScaleType.Fit,
		}, iconWrap)
	else
		create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = cardGlyph(entry),
			TextColor3 = accent,
			TextSize = 24,
		}, iconWrap)
	end

	if currentTab == "Weapons" and entry.favorite then
		local star = create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -5, 0, 5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Color3.fromRGB(69, 53, 25),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = "★",
			TextColor3 = THEME.gold,
			TextSize = 12,
		}, card)
		addCorner(star, 7)
	end

	local equipped = (currentTab == "Weapons" and entry.id == equippedWeaponId) or (currentTab == "Spells" and entry.equipped)
	if equipped then
		local badge = create("TextLabel", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(62, 18),
			BackgroundColor3 = blend(Color3.fromRGB(19, 24, 31), accent, 0.35),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = currentTab == "Spells" and ("SLOT " .. tostring(entry.loadoutIndex or "?")) or "EQUIPPED",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 8,
		}, card)
		addCorner(badge, 6)
	end

	create("TextLabel", {
		Position = UDim2.fromOffset(10, 105),
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = entry.displayName,
		TextColor3 = currentTab == "Codex" and not entry.discovered and THEME.muted or accent,
		TextSize = 10,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, card)

	local metaText
	if currentTab == "Weapons" then
		metaText = string.format("%s • %s", entry.rarity, entry.weaponType)
	elseif currentTab == "Spells" then
		metaText = string.format("%s • %s", entry.element, entry.attackType)
	elseif currentTab == "Materials" then
		metaText = string.format("%s • %s", entry.rarity, entry.bucket)
	else
		metaText = entry.category or "Codex"
	end
	create("TextLabel", {
		Position = UDim2.fromOffset(10, 142),
		Size = UDim2.new(1, -20, 0, 13),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = metaText,
		TextColor3 = THEME.muted,
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	create("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.new(1, -20, 0, 13),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = cardFooter(entry),
		TextColor3 = Color3.fromRGB(188, 198, 215),
		TextSize = 8,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	hoverColor(card, card.BackgroundColor3, blend(THEME.cardHover, accent, 0.12))
	card.MouseButton1Click:Connect(function()
		selectedIds[currentTab] = entry.id
		selectedEntry = entry
		renderDetails(entry)
		local now = os.clock()
		local last = lastClickById[entry.id] or 0
		lastClickById[entry.id] = now
		if now - last <= 0.32 then
			if currentTab == "Weapons" and entry.id ~= equippedWeaponId then
				fireInventoryAction("equip", { id = entry.id })
				equippedWeaponId = entry.id
				showToast("Equipped " .. entry.displayName, THEME.green)
				task.delay(0.18, function() if inventoryGui.Enabled and loadSnapshot then loadSnapshot(true) end end)
			elseif currentTab == "Spells" and entry.unlocked then
				fireInventoryAction(entry.equipped and "spellLoadoutUnequip" or "spellLoadoutEquip", { productId = entry.productId })
				showToast(entry.equipped and "Spell removed" or "Spell equipped", accent)
				task.delay(0.18, function() if inventoryGui.Enabled and loadSnapshot then loadSnapshot(true) end end)
			end
		end
		-- refresh selection stroke without rebuilding everything later than one frame
		for _, other in ipairs(gridScroll:GetChildren()) do
			if other:IsA("TextButton") and other ~= card then
				local stroke = other:FindFirstChildOfClass("UIStroke")
				if stroke then stroke.Thickness = 1 end
			end
		end
		cardStroke.Color = accent
		cardStroke.Thickness = 2
	end)
	return card
end

local function loadoutFamilySet()
	local set = {}
	for _, productId in ipairs((snapshot.spells and snapshot.spells.loadout) or {}) do
		local product = SpellDefs.GetProduct and SpellDefs.GetProduct(productId)
		local familyId = product and product.familyId or (SpellDefs.ProductToSpellId and SpellDefs.ProductToSpellId(productId)) or productId
		set[familyId] = true
	end
	return set
end

local function renderAuxiliaryPanel()
	clearChildren(auxiliaryPanel, { UICorner = true, UIStroke = true })
	if currentTab == "Spells" then
		auxiliaryPanel.Visible = true
		auxiliaryPanel.Size = UDim2.new(1, 0, 0, 126)
		contentCard.Size = UDim2.new(1, 0, 1, -235)
		addPadding(auxiliaryPanel, 10, 10, 9, 9)
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = "EQUIPPED LOADOUT",
			TextColor3 = THEME.text,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, auxiliaryPanel)
		local slots = create("Frame", {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1,
		}, auxiliaryPanel)
		local slotLayout = create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
		}, slots)
		local maxSlots = tonumber(snapshot.spells and snapshot.spells.maxSlots) or 6
		local byFamily = {}
		for _, entry in ipairs(spellEntries) do byFamily[entry.familyId] = entry end
		for slotIndex = 1, maxSlots do
			local productId = snapshot.spells and snapshot.spells.loadout and snapshot.spells.loadout[slotIndex]
			local product = productId and SpellDefs.GetProduct and SpellDefs.GetProduct(productId)
			local familyId = product and product.familyId or (productId and SpellDefs.ProductToSpellId and SpellDefs.ProductToSpellId(productId))
			local entry = familyId and byFamily[familyId] or nil
			local color = entry and getElementColor(entry.element) or THEME.stroke
			local button = create("TextButton", {
				Size = UDim2.new(1 / maxSlots, -5, 1, 0),
				BackgroundColor3 = entry and blend(THEME.panelSoft, color, 0.16) or Color3.fromRGB(17, 21, 29),
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
			}, slots)
			addCorner(button, 8)
			addStroke(button, entry and blend(THEME.stroke, color, 0.5) or THEME.strokeSoft, 1)
			local imageRef = entry and spellImage(entry)
			if imageRef then
				create("ImageLabel", {
					Position = UDim2.fromOffset(6, 5),
					Size = UDim2.fromOffset(32, 32),
					BackgroundTransparency = 1,
					Image = imageRef,
					ScaleType = Enum.ScaleType.Fit,
				}, button)
			else
				create("TextLabel", {
					Position = UDim2.fromOffset(6, 5),
					Size = UDim2.fromOffset(32, 32),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Text = entry and entry.iconGlyph or tostring(slotIndex),
					TextColor3 = entry and color or THEME.mutedDark,
					TextSize = 12,
				}, button)
			end
			create("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.new(1, -6, 0, 12),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Text = entry and entry.displayName or ("Slot " .. slotIndex),
				TextColor3 = entry and THEME.text or THEME.mutedDark,
				TextSize = 7,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, button)
			if entry then
				button.MouseButton1Click:Connect(function()
					selectedIds.Spells = entry.id
					renderSpellDetails(entry)
				end)
			end
		end

		local summary = create("Frame", {
			Position = UDim2.fromOffset(0, 85),
			Size = UDim2.new(1, 0, 0, 29),
			BackgroundTransparency = 1,
		}, auxiliaryPanel)
		local summaryLayout = create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
		}, summary)
		local damageSummary = (snapshot.spells and snapshot.spells.damageSummary) or {}
		for _, bucket in ipairs(damageSummary) do
			local color = safeColor(bucket.color, getElementColor(bucket.element))
			local pill = create("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 24),
				BackgroundColor3 = blend(THEME.panelSoft, color, 0.18),
				BorderSizePixel = 0,
				Font = Enum.Font.GothamMedium,
				Text = string.format("  %s %s DMG  ", bucket.element, formatNumber(bucket.damage)),
				TextColor3 = color,
				TextSize = 8,
			}, summary)
			addCorner(pill, 7)
		end
		local familySet = loadoutFamilySet()
		local possibleCombos = 0
		for _, combo in ipairs((snapshot.spells and snapshot.spells.combinations) or {}) do
			local allPresent = true
			for _, ingredient in ipairs(combo.ingredients or {}) do
				if not familySet[ingredient] then allPresent = false break end
			end
			if allPresent then possibleCombos += 1 end
		end
		local comboPill = create("TextLabel", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			BackgroundColor3 = blend(THEME.panelSoft, THEME.gold, 0.18),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			Text = string.format("  %d possible combos  ", possibleCombos),
			TextColor3 = THEME.gold,
			TextSize = 8,
		}, summary)
		addCorner(comboPill, 7)
	elseif currentTab == "Codex" then
		auxiliaryPanel.Visible = true
		auxiliaryPanel.Size = UDim2.new(1, 0, 0, 54)
		contentCard.Size = UDim2.new(1, 0, 1, -163)
		addPadding(auxiliaryPanel, 12, 12, 9, 9)
		local discovered, total = 0, 0
		for _, entry in ipairs(codexEntries) do
			total += 1
			if entry.discovered then discovered += 1 end
		end
		create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = string.format("CODEX PROGRESS   %d / %d", discovered, total),
			TextColor3 = THEME.text,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, auxiliaryPanel)
		local back = create("Frame", {
			Position = UDim2.fromOffset(0, 25),
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = Color3.fromRGB(40, 46, 58),
			BorderSizePixel = 0,
		}, auxiliaryPanel)
		addCorner(back, 999)
		local fill = create("Frame", {
			Size = UDim2.new(total > 0 and discovered / total or 0, 0, 1, 0),
			BackgroundColor3 = THEME.gold,
			BorderSizePixel = 0,
		}, back)
		addCorner(fill, 999)
	else
		auxiliaryPanel.Visible = false
		auxiliaryPanel.Size = UDim2.new(1, 0, 0, 0)
		contentCard.Size = UDim2.new(1, 0, 1, -100)
	end
end

local function updateToolbarLabels()
	local options = FILTER_OPTIONS[currentTab]
	local f = filters[currentTab]
	filterButtonA.Text = string.format("%s: %s", options.aLabel, f.a)
	filterButtonB.Text = string.format("%s: %s", options.bLabel, f.b)
	sortButton.Text = "Sort: " .. currentSort()
	filterButtonA.TextSize = #filterButtonA.Text > 14 and 8 or 9
	filterButtonB.TextSize = #filterButtonB.Text > 14 and 8 or 9
	sortButton.TextSize = #sortButton.Text > 14 and 8 or 9
end

local function updateTabButtons()
	for _, tab in ipairs(TAB_DEFS) do
		local button = tabButtons[tab.id]
		local active = tab.id == currentTab
		button.BackgroundColor3 = active and blend(THEME.panelAlt, tab.accent, 0.16) or THEME.panelAlt
		button.TextColor3 = active and THEME.text or THEME.muted
		local accent = button:FindFirstChild("Accent")
		if accent then accent.Visible = active end
	end
end

local function updateGridCellSize()
	local width = gridScroll.AbsoluteSize.X
	if width <= 10 then return end
	local columns = width >= 710 and 4 or (width >= 510 and 3 or 2)
	local gap = 9
	local cellWidth = math.floor((width - gap * (columns - 1) - 2) / columns)
	gridLayout.CellSize = UDim2.fromOffset(math.max(136, cellWidth), 176)
end

gridScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGridCellSize)

local function rebuildGrid()
	clearChildren(gridScroll, { UIGridLayout = true })
	currentEntries = getFilteredEntries()
	contentTitle.Text = currentTab == "Spells" and "Spell Collection" or currentTab
	contentCount.Text = string.format("%d shown", #currentEntries)
	emptyState.Visible = #currentEntries == 0
	for index, entry in ipairs(currentEntries) do
		createCard(entry, index)
	end
	updateGridCellSize()
	renderAuxiliaryPanel()
	updateToolbarLabels()
	updateTabButtons()

	local selectedId = selectedIds[currentTab]
	local found = nil
	for _, entry in ipairs(currentEntries) do
		if entry.id == selectedId then found = entry break end
	end
	if not found then found = currentEntries[1] end
	if found then
		selectedIds[currentTab] = found.id
		renderDetails(found)
	else
		resetDetails()
	end
end

local function cycleFilter(which)
	local config = FILTER_OPTIONS[currentTab]
	local options = config[which]
	local current = filters[currentTab][which]
	local index = table.find(options, current) or 1
	index = index % #options + 1
	filters[currentTab][which] = options[index]
	rebuildGrid()
end

local function setActiveTab(tabId)
	if not FILTER_OPTIONS[tabId] then return end
	currentTab = tabId
	searchBox.Text = ""
	rebuildGrid()
end

local function applySnapshot(payload)
	snapshot = payload or {}
	local info = snapshot.playerInfo or {}
	level = tonumber(info.level) or level
	xp = tonumber(info.xp) or xp
	nextXp = tonumber(info.nextXp) or nextXp
	local incomingCurrencies = snapshot.currencies or {}
	currencies.Silver = tonumber(incomingCurrencies.Silver or incomingCurrencies.Coins) or currencies.Silver
	currencies.Souls = tonumber(incomingCurrencies.Souls) or currencies.Souls
	currencies.WeaponPoints = tonumber(incomingCurrencies.WeaponPoints) or currencies.WeaponPoints
	currencies.Tickets = tonumber(incomingCurrencies.Tickets) or currencies.Tickets
	equippedWeaponId = snapshot.equippedId
	weaponEntries = inventoryEntryBuilder.BuildWeaponEntries(snapshot.weapons or {})
	spellEntries = inventoryEntryBuilder.BuildSpellEntries((snapshot.spells and snapshot.spells.entries) or {}, snapshot.spells)
	materialEntries = inventoryEntryBuilder.BuildMaterialEntries(snapshot.resources or {})
	codexEntries = inventoryEntryBuilder.BuildCodexEntries((snapshot.codex and snapshot.codex.entries) or {})
	refreshPlayerPanel()
	refreshCharacterPreview()
	rebuildGrid()
end

loadSnapshot = function(silent)
	if not GetInventorySnapshot then
		if not silent then showToast("Inventory snapshot is unavailable.", THEME.red) end
		return false
	end
	local ok, payload = pcall(function()
		return GetInventorySnapshot:InvokeServer()
	end)
	if not ok or typeof(payload) ~= "table" then
		if not silent then showToast("Could not load inventory.", THEME.red) end
		return false
	end
	applySnapshot(payload)
	return true
end

for _, tab in ipairs(TAB_DEFS) do
	tabButtons[tab.id].MouseButton1Click:Connect(function()
		setActiveTab(tab.id)
	end)
end

filterButtonA.MouseButton1Click:Connect(function() cycleFilter("a") end)
filterButtonB.MouseButton1Click:Connect(function() cycleFilter("b") end)
sortButton.MouseButton1Click:Connect(function()
	local options = SORT_OPTIONS[currentTab]
	sortIndices[currentTab] = (sortIndices[currentTab] or 1) % #options + 1
	rebuildGrid()
end)

filters.searchDebounce = 0
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	filters.searchDebounce += 1
	local token = filters.searchDebounce
	task.delay(0.08, function()
		if token == filters.searchDebounce then rebuildGrid() end
	end)
end)

confirmCancel.MouseButton1Click:Connect(function()
	pendingConfirm = nil
	confirmOverlay.Visible = false
end)
confirmAccept.MouseButton1Click:Connect(function()
	local entry = pendingConfirm
	pendingConfirm = nil
	confirmOverlay.Visible = false
	if not entry then return end
	fireInventoryAction("sell", { id = entry.id })
	showToast("Sold " .. entry.displayName, THEME.orange)
	task.delay(0.22, function()
		if inventoryGui.Enabled then loadSnapshot(true) end
	end)
end)

filters.closeInventory = function()
	inventoryGui.Enabled = false
	confirmOverlay.Visible = false
	pendingConfirm = nil
	previewDragging = false
end

filters.openInventory = function()
	inventoryGui.Enabled = true
	loadSnapshot(false)
end

filters.toggleInventory = function()
	if inventoryGui.Enabled then
		filters.closeInventory()
	else
		filters.openInventory()
	end
end

closeButton.MouseButton1Click:Connect(filters.closeInventory)

filters.lastScreenButtonsNonce = nil
filters.handleScreenButtonsRequest = function()
	local nonce = inventoryGui:GetAttribute("ScreenButtonsNonce")
	if nonce == nil or nonce == filters.lastScreenButtonsNonce then return end
	filters.lastScreenButtonsNonce = nonce
	local action = inventoryGui:GetAttribute("ScreenButtonsAction")
	if action == "open" then filters.openInventory()
	elseif action == "close" then filters.closeInventory()
	elseif action == "toggle" then filters.toggleInventory() end
end
inventoryGui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(filters.handleScreenButtonsRequest)
filters.handleScreenButtonsRequest()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Escape and confirmOverlay.Visible then
		confirmOverlay.Visible = false
		pendingConfirm = nil
		return
	end

	-- Nie przechwytuj klawiszy używanych przez chat, TextBox lub Roblox CoreGui.
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	if input.KeyCode == Enum.KeyCode.F and inventoryGui.Enabled then
		searchBox:CaptureFocus()
	end
end)

-- Bind I through ContextActionService instead of relying on gameProcessedEvent.
-- This remains reliable even when Roblox CoreGui marks the key as processed.
filters.contextActionService = game:GetService("ContextActionService")
filters.inventoryToggleAction = "InventoryRemakeToggle"
filters.contextActionService:UnbindAction(filters.inventoryToggleAction)
filters.contextActionService:BindActionAtPriority(
	filters.inventoryToggleAction,
	function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		filters.toggleInventory()
		return Enum.ContextActionResult.Sink
	end,
	false,
	3000,
	Enum.KeyCode.I
)

if InventorySync then
	InventorySync.OnClientEvent:Connect(function()
		if inventoryGui.Enabled then
			task.delay(0.05, function() loadSnapshot(true) end)
		end
	end)
end

if PlayerProgressEvent then
	PlayerProgressEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or payload.type ~= "progress" then return end
		level = tonumber(payload.level) or level
		xp = tonumber(payload.xp) or xp
		nextXp = tonumber(payload.nextXp) or nextXp
		currencies.Silver = tonumber(payload.coins) or currencies.Silver
		if inventoryGui.Enabled then refreshPlayerPanel() end
	end)
end

player:GetAttributeChangedSignal("Race"):Connect(function()
	if inventoryGui.Enabled then refreshPlayerPanel() end
end)
player.CharacterAdded:Connect(function()
	if inventoryGui.Enabled then
		task.delay(0.5, refreshCharacterPreview)
	end
end)

updateToolbarLabels()
updateTabButtons()
resetDetails()
print("[InventoryController] Remake ready")
