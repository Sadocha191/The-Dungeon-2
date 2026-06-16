local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local moduleRoot = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local UiResponsive = require(moduleRoot:WaitForChild("UiResponsive"))
local CraftingConfig = require(moduleRoot:WaitForChild("CraftingConfig"))

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenMineUI = remoteEvents:WaitForChild("OpenMineUI")
local MineSync = remoteEvents:WaitForChild("MineSync")
local MineAction = remoteEvents:WaitForChild("MineAction")

local gui = playerGui:WaitForChild("MineGui")
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)

local overlay = gui:WaitForChild("overlay")
local panel = overlay:WaitForChild("panel")

for _, child in ipairs(overlay:GetChildren()) do
	if child ~= panel then
		child:Destroy()
	end
end

for _, child in ipairs(panel:GetChildren()) do
	child:Destroy()
end

local PANEL_SIZE = Vector2.new(1140, 680)

local rarityColors = {
	Common = Color3.fromRGB(176, 184, 198),
	Rare = Color3.fromRGB(108, 170, 255),
	Epic = Color3.fromRGB(188, 126, 255),
	Legendary = Color3.fromRGB(255, 198, 96),
	Mythical = Color3.fromRGB(255, 116, 122),
}

local reasonLabels = {
	MiningActive = "A mining route is already running.",
	NoMiningSession = "No active mining route to stop.",
	BadDuration = "Pick one of the offered durations.",
	BadMine = "Select a mining route first.",
	UnknownAction = "Unknown mining action.",
}

local function create(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(instance, radius)
	create("UICorner", {
		CornerRadius = UDim.new(0, radius or 12),
	}, instance)
end

local function addStroke(instance, color, thickness, transparency)
	create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, instance)
end

local function addGradient(instance, colorA, colorB, rotation)
	local gradient = create("UIGradient", {
		Rotation = rotation or 0,
	}, instance)
	gradient.Color = ColorSequence.new(colorA, colorB)
	return gradient
end

local function blendColor(fromColor, toColor, alpha)
	return Color3.new(
		fromColor.R + (toColor.R - fromColor.R) * alpha,
		fromColor.G + (toColor.G - fromColor.G) * alpha,
		fromColor.B + (toColor.B - fromColor.B) * alpha
	)
end

local function clampInt(value, minimum)
	value = math.floor(tonumber(value) or 0)
	if minimum ~= nil and value < minimum then
		return minimum
	end
	return value
end

local function getRarityColor(rarity)
	return rarityColors[tostring(rarity or "")] or rarityColors.Common
end

local function getMineById(mineId)
	if typeof(CraftingConfig.GetMine) == "function" then
		return CraftingConfig.GetMine(mineId)
	end
	for _, mine in ipairs(CraftingConfig.MINE_DEFS or {}) do
		if mine.id == mineId then
			return mine
		end
	end
	return nil
end

local function getAllMines()
	if typeof(CraftingConfig.GetAllMines) == "function" then
		return CraftingConfig.GetAllMines()
	end
	return CraftingConfig.MINE_DEFS or {}
end

local function getDefaultMineId()
	if typeof(CraftingConfig.GetDefaultMineId) == "function" then
		return CraftingConfig.GetDefaultMineId()
	end
	local mines = getAllMines()
	return mines[1] and mines[1].id or nil
end

local function getMineDrops(mineId)
	if typeof(CraftingConfig.GetMineDropChanceList) == "function" then
		local drops = CraftingConfig.GetMineDropChanceList(mineId)
		if typeof(drops) == "table" and #drops > 0 then
			return drops
		end
	end

	local mine = getMineById(mineId)
	if not mine or typeof(mine.drops) ~= "table" then
		return {}
	end

	local totalWeight = 0
	for _, entry in ipairs(mine.drops) do
		totalWeight += math.max(0, clampInt(entry.weight, 0))
	end
	if totalWeight <= 0 then
		return {}
	end

	local out = {}
	for _, entry in ipairs(mine.drops) do
		local weight = math.max(0, clampInt(entry.weight, 0))
		if typeof(entry.id) == "string" and entry.id ~= "" and weight > 0 then
			table.insert(out, {
				id = entry.id,
				weight = weight,
				chance = weight / totalWeight,
				yieldMin = clampInt(entry.yieldMin, 1),
				yieldMax = math.max(clampInt(entry.yieldMin, 1), clampInt(entry.yieldMax, clampInt(entry.yieldMin, 1))),
			})
		end
	end
	return out
end

local function getMineTheme(mine)
	local colors = mine and mine.colors or nil
	local primary = colors and colors.primary or Color3.fromRGB(108, 170, 255)
	local secondary = colors and colors.secondary or Color3.fromRGB(35, 48, 75)
	local accent = colors and colors.accent or Color3.fromRGB(222, 234, 255)
	return primary, secondary, accent
end

local function formatDuration(seconds)
	seconds = math.max(0, clampInt(seconds, 0))
	if seconds >= 3600 then
		local hours = seconds / 3600
		if hours == math.floor(hours) then
			return string.format("%dh", hours)
		end
		return string.format("%.1fh", hours)
	end
	return string.format("%dm", math.floor(seconds / 60))
end

local function formatChance(value)
	return math.floor((tonumber(value) or 0) * 100 + 0.5)
end

local function formatResourceList(list, maxItems)
	if typeof(list) ~= "table" or #list == 0 then
		return "-"
	end

	local parts = {}
	local limit = math.max(1, clampInt(maxItems, 1))
	for index, entry in ipairs(list) do
		if index > limit then
			break
		end
		parts[#parts + 1] = string.format("%s x%d", tostring(entry.id), clampInt(entry.amount, 0))
	end
	if #list > limit then
		parts[#parts + 1] = string.format("+%d more", #list - limit)
	end
	return table.concat(parts, ", ")
end

local function formatProgressLines(list)
	if typeof(list) ~= "table" or #list == 0 then
		return "- None"
	end

	local lines = {}
	for _, entry in ipairs(list) do
		local owned = clampInt(entry.owned, 0)
		local required = clampInt(entry.amount, 0)
		local missing = math.max(0, clampInt(entry.missing, 0))
		local status = missing > 0 and string.format("missing %d", missing) or "ready"
		lines[#lines + 1] = string.format("- %s: %d / %d (%s)", tostring(entry.id), math.min(owned, required), required, status)
	end
	return table.concat(lines, "\n")
end

local function sumAmounts(list)
	local total = 0
	for _, entry in ipairs(list or {}) do
		total += clampInt(entry.amount, 0)
	end
	return total
end

local function formatDropPreview(drops, maxItems)
	if typeof(drops) ~= "table" or #drops == 0 then
		return "-"
	end

	local parts = {}
	local limit = math.max(1, clampInt(maxItems, 1))
	for index, drop in ipairs(drops) do
		if index > limit then
			break
		end
		parts[#parts + 1] = string.format("%s %d%%", tostring(drop.id), formatChance(drop.chance))
	end
	if #drops > limit then
		parts[#parts + 1] = string.format("+%d more", #drops - limit)
	end
	return table.concat(parts, ", ")
end

local function getRecipeMineFocus(mineId, recipeEntry)
	local drops = getMineDrops(mineId)
	local dropMap = {}
	local totalWeight = 0

	for _, drop in ipairs(drops) do
		local weight = tonumber(drop.weight) or 0
		if weight > 0 then
			dropMap[drop.id] = drop
			totalWeight += weight
		end
	end

	local matched = {}
	local missingMatched = {}
	local fullWeight = 0
	local missingWeight = 0

	if recipeEntry and typeof(recipeEntry.mineResourceProgress) == "table" then
		for _, need in ipairs(recipeEntry.mineResourceProgress) do
			local drop = dropMap[need.id]
			if drop then
				local weight = tonumber(drop.weight) or 0
				fullWeight += weight
				matched[#matched + 1] = need.id
				if clampInt(need.missing, 0) > 0 then
					missingWeight += weight
					missingMatched[#missingMatched + 1] = need.id
				end
			end
		end
	end

	local effectiveWeight = missingWeight > 0 and missingWeight or fullWeight
	local coverage = totalWeight > 0 and (effectiveWeight / totalWeight) or 0
	local score = coverage + (#missingMatched * 0.025) + (#matched * 0.005)

	return {
		drops = drops,
		matched = matched,
		missingMatched = missingMatched,
		coverage = coverage,
		percentage = math.floor(coverage * 100 + 0.5),
		score = score,
	}
end

local snapshot = nil
local selectedDuration = 600
local selectedMineId = nil
local selectedRecipeId = nil
local manualMineSelection = false
local autoRefreshQueued = false
local durationButtons = {}

overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(3, 5, 10)
overlay.BackgroundTransparency = 0.28
overlay.BorderSizePixel = 0
overlay.Parent = gui
addGradient(overlay, Color3.fromRGB(8, 12, 22), Color3.fromRGB(1, 3, 6), 90)

panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.96, 0.92)
panel.BackgroundColor3 = Color3.fromRGB(13, 18, 28)
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = overlay
addCorner(panel, 22)
addStroke(panel, Color3.fromRGB(44, 57, 84), 1)
addGradient(panel, Color3.fromRGB(18, 24, 37), Color3.fromRGB(10, 14, 22), 90)
create("UISizeConstraint", {
	MaxSize = PANEL_SIZE,
}, panel)
create("UIAspectRatioConstraint", {
	AspectRatio = PANEL_SIZE.X / PANEL_SIZE.Y,
	DominantAxis = Enum.DominantAxis.Height,
}, panel)
UiResponsive.attachCenteredPanel(panel, PANEL_SIZE)

local topAccent = create("Frame", {
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundColor3 = Color3.fromRGB(107, 171, 255),
	BorderSizePixel = 0,
}, panel)
addGradient(topAccent, Color3.fromRGB(255, 164, 102), Color3.fromRGB(111, 173, 255), 0)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 16),
	Size = UDim2.fromOffset(420, 28),
	Font = Enum.Font.GothamBlack,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(245, 246, 252),
	Text = "Mining Routes",
}, panel)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 46),
	Size = UDim2.fromOffset(720, 22),
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(180, 190, 210),
	Text = "Match owned schematics to the route that closes your remaining craft materials fastest.",
}, panel)

local closeBtn = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 18),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Color3.fromRGB(30, 36, 48),
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Color3.fromRGB(238, 241, 248),
	Text = "X",
}, panel)
addCorner(closeBtn, 12)
addStroke(closeBtn, Color3.fromRGB(60, 76, 106), 1)

local summaryStrip = create("Frame", {
	Position = UDim2.fromOffset(24, 86),
	Size = UDim2.fromOffset(758, 88),
	BackgroundTransparency = 1,
}, panel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 12),
}, summaryStrip)

local function createSummaryCard(headerText)
	local card = create("Frame", {
		Size = UDim2.fromOffset(244, 88),
		BackgroundColor3 = Color3.fromRGB(20, 26, 38),
		BorderSizePixel = 0,
	}, summaryStrip)
	addCorner(card, 16)
	addStroke(card, Color3.fromRGB(46, 58, 84), 1)
	addGradient(card, Color3.fromRGB(28, 35, 51), Color3.fromRGB(17, 22, 34), 90)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.fromOffset(180, 14),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(156, 170, 196),
		Text = headerText,
	}, card)

	local value = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.fromOffset(212, 28),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(246, 248, 252),
		Text = "-",
	}, card)

	local meta = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.fromOffset(216, 18),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(191, 198, 214),
		Text = "-",
	}, card)

	return {
		value = value,
		meta = meta,
	}
end

local silverCard = createSummaryCard("Silver")
local stashCard = createSummaryCard("Mine Stash")
local routeCard = createSummaryCard("Route")

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 188),
	Size = UDim2.fromOffset(220, 18),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(234, 238, 244),
	Text = "Duration",
}, panel)

local durationBar = create("Frame", {
	Position = UDim2.fromOffset(24, 212),
	Size = UDim2.fromOffset(758, 42),
	BackgroundTransparency = 1,
}, panel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
}, durationBar)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 258),
	Size = UDim2.fromOffset(320, 18),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(236, 239, 244),
	Text = "Owned Schematics",
}, panel)

local recipeListFrame = create("ScrollingFrame", {
	Position = UDim2.fromOffset(24, 282),
	Size = UDim2.fromOffset(320, 370),
	BackgroundColor3 = Color3.fromRGB(21, 27, 39),
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Color3.fromRGB(92, 112, 146),
}, panel)
addCorner(recipeListFrame, 16)
addStroke(recipeListFrame, Color3.fromRGB(42, 56, 82), 1)
addGradient(recipeListFrame, Color3.fromRGB(26, 34, 49), Color3.fromRGB(16, 22, 33), 90)

local recipeLayout = create("UIListLayout", {
	Padding = UDim.new(0, 10),
}, recipeListFrame)

local recipeEmptyLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 16),
	Size = UDim2.new(1, -36, 1, -32),
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(150, 160, 180),
	Text = "No weapon schematics found yet. Open the blacksmith first or secure more drops.",
	Visible = false,
}, recipeListFrame)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(360, 258),
	Size = UDim2.fromOffset(420, 18),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(236, 239, 244),
	Text = "Mine Routes",
}, panel)

local mineListFrame = create("ScrollingFrame", {
	Position = UDim2.fromOffset(360, 282),
	Size = UDim2.fromOffset(422, 370),
	BackgroundColor3 = Color3.fromRGB(21, 27, 39),
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Color3.fromRGB(92, 112, 146),
}, panel)
addCorner(mineListFrame, 16)
addStroke(mineListFrame, Color3.fromRGB(42, 56, 82), 1)
addGradient(mineListFrame, Color3.fromRGB(26, 34, 49), Color3.fromRGB(16, 22, 33), 90)

local mineLayout = create("UIListLayout", {
	Padding = UDim.new(0, 10),
}, mineListFrame)

local detailFrame = create("Frame", {
	Position = UDim2.fromOffset(798, 86),
	Size = UDim2.fromOffset(318, 566),
	BackgroundColor3 = Color3.fromRGB(22, 27, 40),
	BorderSizePixel = 0,
}, panel)
addCorner(detailFrame, 18)
addStroke(detailFrame, Color3.fromRGB(48, 60, 88), 1)
addGradient(detailFrame, Color3.fromRGB(28, 35, 51), Color3.fromRGB(17, 21, 31), 90)

local detailAccent = create("Frame", {
	Size = UDim2.new(1, 0, 0, 4),
	BackgroundColor3 = Color3.fromRGB(107, 171, 255),
	BorderSizePixel = 0,
}, detailFrame)
addGradient(detailAccent, Color3.fromRGB(255, 170, 97), Color3.fromRGB(107, 171, 255), 0)

local detailTitle = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 18),
	Size = UDim2.new(1, -36, 0, 24),
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(245, 247, 252),
	Text = "Pick A Route",
}, detailFrame)

local detailMeta = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 46),
	Size = UDim2.new(1, -36, 0, 18),
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(176, 188, 208),
	Text = "Select a schematic to see the best route and what is still missing for craft.",
}, detailFrame)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 78),
	Size = UDim2.fromOffset(160, 16),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(234, 238, 244),
	Text = "Selected Route",
}, detailFrame)

local routeBody = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 98),
	Size = UDim2.new(1, -36, 0, 124),
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(218, 224, 236),
	Text = "",
}, detailFrame)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 230),
	Size = UDim2.fromOffset(180, 16),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(234, 238, 244),
	Text = "Craft Progress",
}, detailFrame)

local needsBody = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 250),
	Size = UDim2.new(1, -36, 0, 164),
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(218, 224, 236),
	Text = "",
}, detailFrame)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 422),
	Size = UDim2.fromOffset(160, 16),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(234, 238, 244),
	Text = "Current Session",
}, detailFrame)

local sessionBody = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 442),
	Size = UDim2.new(1, -36, 0, 54),
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(218, 224, 236),
	Text = "",
}, detailFrame)

local statusLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 502),
	Size = UDim2.new(1, -36, 0, 20),
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(164, 176, 198),
	Text = "",
}, detailFrame)

local function createActionButton(text, x)
	local button = create("TextButton", {
		Position = UDim2.fromOffset(x, 526),
		Size = UDim2.fromOffset(134, 34),
		BackgroundColor3 = Color3.fromRGB(37, 44, 58),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(240, 244, 248),
		Text = text,
	}, detailFrame)
	addCorner(button, 12)
	addStroke(button, Color3.fromRGB(61, 76, 104), 1)
	return button
end

local startBtn = createActionButton("Start Route", 18)
local stopBtn = createActionButton("Stop And Claim", 166)

local function setButtonState(button, enabled, text, accent)
	local color = accent or Color3.fromRGB(107, 171, 255)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundColor3 = enabled
		and blendColor(Color3.fromRGB(38, 46, 62), color, 0.45)
		or Color3.fromRGB(37, 44, 58)
	button.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(148, 158, 176)
	button.Text = text
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = enabled
			and blendColor(Color3.fromRGB(61, 76, 104), color, 0.65)
			or Color3.fromRGB(61, 76, 104)
	end
end

local function updateCanvas(scrollFrame, layout, extraPadding)
	task.defer(function()
		scrollFrame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + (extraPadding or 16))
	end)
end

local function getRecipeEntries()
	return snapshot and snapshot.craftEntries or {}
end

local function findRecipeEntry(recipeId)
	for _, entry in ipairs(getRecipeEntries()) do
		if entry.recipeId == recipeId then
			return entry
		end
	end
	return nil
end

local function getSelectedRecipe()
	return findRecipeEntry(selectedRecipeId)
end

local function getSelectedMine()
	return getMineById(selectedMineId)
end

local function getRecommendedMineId(recipeEntry)
	local mines = getAllMines()
	if not recipeEntry then
		return getDefaultMineId()
	end

	local bestMineId = getDefaultMineId()
	local bestScore = -1
	for _, mine in ipairs(mines) do
		local focus = getRecipeMineFocus(mine.id, recipeEntry)
		if focus.score > bestScore then
			bestScore = focus.score
			bestMineId = mine.id
		end
	end
	return bestMineId
end

local function ensureSelections()
	local recipes = getRecipeEntries()
	local stillValidRecipe = selectedRecipeId and findRecipeEntry(selectedRecipeId)
	if not stillValidRecipe then
		selectedRecipeId = recipes[1] and recipes[1].recipeId or nil
		manualMineSelection = false
	end

	local session = snapshot and snapshot.session or nil
	if session and session.active then
		if session.focusRecipeId and findRecipeEntry(session.focusRecipeId) then
			selectedRecipeId = session.focusRecipeId
		end
		if not manualMineSelection or not selectedMineId then
			selectedMineId = session.mineId or selectedMineId or getDefaultMineId()
		end
	else
		if selectedRecipeId and not manualMineSelection then
			selectedMineId = getRecommendedMineId(findRecipeEntry(selectedRecipeId)) or selectedMineId
		end
	end

	if not getMineById(selectedMineId) then
		selectedMineId = getDefaultMineId()
	end
end

local function buildRecipeNeedSummary(entry)
	if not entry then
		return "Choose a schematic."
	end
	if entry.canCraft then
		return "Craft ready."
	end

	local chunks = {}
	if not entry.unlocked then
		local unlockMissing = clampInt(entry.unlockSilverMissing, 0)
		if unlockMissing > 0 then
			chunks[#chunks + 1] = string.format("unlock %d Silver", unlockMissing)
		else
			chunks[#chunks + 1] = "unlock recipe"
		end
	end

	local mineMissing = entry.mineProgressSummary and clampInt(entry.mineProgressSummary.missing, 0) or 0
	if mineMissing > 0 then
		chunks[#chunks + 1] = string.format("%d mine mats", mineMissing)
	end

	local mobMissing = entry.mobProgressSummary and clampInt(entry.mobProgressSummary.missing, 0) or 0
	if mobMissing > 0 then
		chunks[#chunks + 1] = string.format("%d mob mats", mobMissing)
	end

	if entry.unlocked then
		local craftSilverMissing = clampInt(entry.craftSilverMissing, 0)
		if craftSilverMissing > 0 then
			chunks[#chunks + 1] = string.format("%d Silver", craftSilverMissing)
		end
	end

	if #chunks == 0 then
		return "Route planning ready."
	end
	return "Need " .. table.concat(chunks, ", ")
end

local function buildRouteText(mine, recipeEntry)
	if not mine then
		return "Select one of the available routes."
	end

	local focus = getRecipeMineFocus(mine.id, recipeEntry)
	local lines = {
		tostring(mine.description or ""),
		tostring(mine.tone or ""),
		"",
	}

	if recipeEntry then
		local missingMineCount = recipeEntry.mineProgressSummary and clampInt(recipeEntry.mineProgressSummary.missing, 0) or 0
		if #focus.missingMatched > 0 then
			lines[#lines + 1] = string.format("Focus fit: %d%% of your missing mine materials.", focus.percentage)
			lines[#lines + 1] = "Feeds: " .. table.concat(focus.missingMatched, ", ")
			lines[#lines + 1] = ""
		elseif missingMineCount <= 0 then
			lines[#lines + 1] = "Mine resources for this schematic are already ready."
			lines[#lines + 1] = ""
		else
			lines[#lines + 1] = "This route does not directly cover the missing mine materials."
			lines[#lines + 1] = ""
		end
	end

	lines[#lines + 1] = "Drop table:"
	local shown = 0
	for _, drop in ipairs(focus.drops) do
		if shown >= 4 then
			break
		end
		shown += 1
		lines[#lines + 1] = string.format(
			"- %s %d%% (x%d-x%d)",
			tostring(drop.id),
			formatChance(drop.chance),
			clampInt(drop.yieldMin, 1),
			clampInt(drop.yieldMax, clampInt(drop.yieldMin, 1))
		)
	end
	if #focus.drops > shown then
		lines[#lines + 1] = string.format("- plus %d more drops", #focus.drops - shown)
	end

	return table.concat(lines, "\n")
end

local function buildNeedsText(recipeEntry)
	if not recipeEntry then
		return "Choose one of your owned schematics to see what is still missing before craft."
	end

	local levelState = recipeEntry.levelMet and "ready" or string.format("reach account level %d", clampInt(recipeEntry.requiredLevel, 1))
	local unlockText
	if recipeEntry.unlocked then
		unlockText = "Recipe unlock: ready"
	else
		local unlockMissing = clampInt(recipeEntry.unlockSilverMissing, 0)
		if unlockMissing > 0 then
			unlockText = string.format("Recipe unlock: %d Silver (%d missing)", clampInt(recipeEntry.unlockSilverCost, 0), unlockMissing)
		else
			unlockText = string.format("Recipe unlock: %d Silver (ready)", clampInt(recipeEntry.unlockSilverCost, 0))
		end
	end

	local craftSilverMissing = clampInt(recipeEntry.craftSilverMissing, 0)
	local craftSilverText
	if craftSilverMissing > 0 then
		craftSilverText = string.format("Craft Silver: %d (%d missing)", clampInt(recipeEntry.craftSilverCost, 0), craftSilverMissing)
	else
		craftSilverText = string.format("Craft Silver: %d (ready)", clampInt(recipeEntry.craftSilverCost, 0))
	end

	local lines = {
		string.format("Status: %s", tostring(recipeEntry.status)),
		string.format("Required level: %s", levelState),
		string.format("Tier %d | Copies %d", clampInt(recipeEntry.tier, 1), clampInt(recipeEntry.copies, 0)),
		unlockText,
		craftSilverText,
		"",
		"Mine materials:",
		formatProgressLines(recipeEntry.mineResourceProgress),
		"",
		"Mob materials:",
		formatProgressLines(recipeEntry.mobMaterialProgress),
	}

	return table.concat(lines, "\n")
end

local function buildSessionText()
	local session = snapshot and snapshot.session or nil
	if not session or session.active ~= true then
		local lines = {
			"Idle. Start a route to keep stockpiling ore online or offline.",
		}
		if session and typeof(session.recentClaim) == "table" and #session.recentClaim > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "Last claim: " .. formatResourceList(session.recentClaim, 4)
		end
		return table.concat(lines, "\n")
	end

	local remaining = math.max(0, clampInt(session.endsAt, 0) - os.time())
	local lines = {
		string.format("Route: %s", tostring(session.mineName or session.mineId or "-")),
		string.format("Duration: %s", formatDuration(session.durationSec)),
		string.format("Remaining: %s", formatDuration(remaining)),
	}
	if session.focusRecipeName then
		lines[#lines + 1] = string.format("Focus: %s", tostring(session.focusRecipeName))
	end
	return table.concat(lines, "\n")
end

local function buildActionMessage(lastResult)
	if typeof(lastResult) ~= "table" then
		return nil, nil
	end

	if lastResult.ok == true then
		if lastResult.type == "start" then
			local details = lastResult.details or {}
			local routeName = details.mineName or (snapshot and snapshot.session and snapshot.session.mineName) or selectedMineId or "route"
			return true, "Route started: " .. tostring(routeName)
		end
		if lastResult.type == "stop" then
			local details = lastResult.details or {}
			local yield = details.yield
			if typeof(yield) == "table" and #yield > 0 then
				return true, "Claimed: " .. formatResourceList(yield, 3)
			end
			return true, "Route stopped and haul claimed."
		end
		return true, "Action completed."
	end

	local reason = tostring(lastResult.reason or "Unknown")
	return false, reasonLabels[reason] or ("Action failed: " .. reason)
end

local refresh

local function buildDurationButtons(options)
	for _, button in pairs(durationButtons) do
		button:Destroy()
	end
	durationButtons = {}

	for _, durationSec in ipairs(options or {}) do
		local button = create("TextButton", {
			Size = UDim2.fromOffset(120, 40),
			BackgroundColor3 = Color3.fromRGB(33, 40, 56),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(228, 232, 238),
			Text = formatDuration(durationSec),
		}, durationBar)
		addCorner(button, 12)
		addStroke(button, Color3.fromRGB(60, 74, 102), 1)

		button.MouseButton1Click:Connect(function()
			selectedDuration = durationSec
			refresh()
		end)

		durationButtons[durationSec] = button
	end
end

local function refreshSummary()
	if not snapshot then
		silverCard.value.Text = "-"
		silverCard.meta.Text = "Waiting for server snapshot."
		stashCard.value.Text = "-"
		stashCard.meta.Text = "-"
		routeCard.value.Text = "Idle"
		routeCard.meta.Text = "Pick a schematic and a route."
		return
	end

	local selectedRecipe = getSelectedRecipe()
	local selectedMine = getSelectedMine()
	local activeSession = snapshot.session

	silverCard.value.Text = tostring(clampInt(snapshot.silver, 0))
	silverCard.meta.Text = string.format("Account level %d", clampInt(snapshot.accountLevel, 1))

	stashCard.value.Text = tostring(sumAmounts(snapshot.mineResources))
	stashCard.meta.Text = formatResourceList(snapshot.mineResources, 3)

	if activeSession and activeSession.active then
		routeCard.value.Text = tostring(activeSession.mineName or activeSession.mineId or "Active")
		routeCard.meta.Text = string.format("Ends in %s", formatDuration(math.max(0, clampInt(activeSession.endsAt, 0) - os.time())))
	elseif selectedMine then
		routeCard.value.Text = tostring(selectedMine.displayName or selectedMine.id)
		if selectedRecipe then
			local recommendedMineId = getRecommendedMineId(selectedRecipe)
			if recommendedMineId == selectedMine.id then
				routeCard.meta.Text = "Recommended for the selected schematic."
			else
				routeCard.meta.Text = "Manual route selection."
			end
		else
			routeCard.meta.Text = tostring(selectedMine.subtitle or "Route ready.")
		end
	else
		routeCard.value.Text = "Idle"
		routeCard.meta.Text = "Pick a route."
	end
end

local function rebuildRecipeList()
	for _, child in ipairs(recipeListFrame:GetChildren()) do
		if child:IsA("GuiObject") and child ~= recipeEmptyLabel and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local entries = getRecipeEntries()
	recipeEmptyLabel.Visible = #entries == 0

	for _, entry in ipairs(entries) do
		local accent = getRarityColor(entry.rarity)
		local selected = entry.recipeId == selectedRecipeId
		local recommendedMineId = getRecommendedMineId(entry)
		local recommendedMine = getMineById(recommendedMineId)

		local button = create("TextButton", {
			Size = UDim2.new(1, -16, 0, 86),
			Position = UDim2.fromOffset(8, 0),
			BackgroundColor3 = blendColor(Color3.fromRGB(28, 34, 47), accent, selected and 0.20 or 0.10),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
		}, recipeListFrame)
		addCorner(button, 14)
		addStroke(button, selected and accent or blendColor(Color3.fromRGB(58, 70, 96), accent, 0.45), selected and 2 or 1)

		local accentBar = create("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(4, 66),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		}, button)
		addCorner(accentBar, 8)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(24, 10),
			Size = UDim2.new(1, -40, 0, 18),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = accent,
			Text = string.format("%s [%s]", tostring(entry.name), tostring(entry.status)),
		}, button)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(24, 30),
			Size = UDim2.new(1, -40, 0, 16),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(214, 222, 236),
			Text = string.format("Tier %d | Copies %d", clampInt(entry.tier, 1), clampInt(entry.copies, 0)),
		}, button)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(24, 48),
			Size = UDim2.new(1, -40, 0, 14),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(180, 189, 206),
			Text = buildRecipeNeedSummary(entry),
		}, button)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(24, 64),
			Size = UDim2.new(1, -40, 0, 14),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(152, 196, 255),
			Text = recommendedMine and ("Best route: " .. tostring(recommendedMine.displayName or recommendedMine.id)) or "Best route: -",
		}, button)

		button.MouseButton1Click:Connect(function()
			selectedRecipeId = entry.recipeId
			selectedMineId = recommendedMineId or selectedMineId or getDefaultMineId()
			manualMineSelection = false
			refresh()
		end)
	end

	updateCanvas(recipeListFrame, recipeLayout, 18)
end

local function rebuildMineList()
	for _, child in ipairs(mineListFrame:GetChildren()) do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local selectedRecipe = getSelectedRecipe()
	local activeRouteId = snapshot and snapshot.session and snapshot.session.active and snapshot.session.mineId or nil

	for _, mine in ipairs(getAllMines()) do
		local focus = getRecipeMineFocus(mine.id, selectedRecipe)
		local selected = mine.id == selectedMineId
		local isActive = activeRouteId == mine.id
		local primary, secondary, accent = getMineTheme(mine)

		local button = create("TextButton", {
			Size = UDim2.new(1, -16, 0, 108),
			Position = UDim2.fromOffset(8, 0),
			BackgroundColor3 = blendColor(Color3.fromRGB(24, 30, 43), primary, selected and 0.22 or 0.14),
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
		}, mineListFrame)
		addCorner(button, 16)
		addStroke(button, selected and primary or blendColor(Color3.fromRGB(58, 70, 96), primary, 0.42), selected and 2 or 1)
		addGradient(button, blendColor(secondary, primary, 0.20), Color3.fromRGB(18, 24, 34), 0)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 12),
			Size = UDim2.new(1, -32, 0, 18),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = accent,
			Text = tostring(mine.displayName or mine.id),
		}, button)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 30),
			Size = UDim2.new(1, -32, 0, 16),
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(201, 211, 226),
			Text = tostring(mine.subtitle or mine.description or ""),
		}, button)

		local focusLine
		local missingCount = selectedRecipe and selectedRecipe.mineProgressSummary and clampInt(selectedRecipe.mineProgressSummary.missing, 0) or 0
		if selectedRecipe then
			if #focus.missingMatched > 0 then
				focusLine = string.format("Focus %d%% | Feeds %s", focus.percentage, table.concat(focus.missingMatched, ", "))
			elseif missingCount <= 0 then
				focusLine = "Mine resources already ready for the selected schematic."
			else
				focusLine = "No direct fit for the missing mine materials."
			end
		else
			focusLine = tostring(mine.tone or mine.description or "")
		end

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 50),
			Size = UDim2.new(1, -32, 0, 16),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(180, 192, 212),
			Text = focusLine,
		}, button)

		local dropPreview = formatDropPreview(focus.drops, 4)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 74),
			Size = UDim2.new(1, -32, 0, 16),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(220, 226, 238),
			Text = "Drops: " .. dropPreview,
		}, button)

		local badgeText = isActive and "ACTIVE" or (selected and "SELECTED" or "")
		if badgeText ~= "" then
			local badge = create("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 12),
				Size = UDim2.fromOffset(74, 18),
				BackgroundColor3 = isActive and blendColor(primary, Color3.fromRGB(255, 190, 110), 0.24) or blendColor(primary, secondary, 0.32),
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Text = badgeText,
			}, button)
			addCorner(badge, 999)
		end

		button.MouseButton1Click:Connect(function()
			selectedMineId = mine.id
			manualMineSelection = true
			refresh()
		end)
	end

	updateCanvas(mineListFrame, mineLayout, 18)
end

local function refreshDetail()
	local selectedRecipe = getSelectedRecipe()
	local selectedMine = getSelectedMine()

	if selectedRecipe then
		detailAccent.BackgroundColor3 = getRarityColor(selectedRecipe.rarity)
		detailTitle.Text = tostring(selectedRecipe.name)
		detailMeta.Text = string.format("%s schematic | %s", tostring(selectedRecipe.rarity), buildRecipeNeedSummary(selectedRecipe))
	else
		detailAccent.BackgroundColor3 = Color3.fromRGB(107, 171, 255)
		detailTitle.Text = selectedMine and tostring(selectedMine.displayName or selectedMine.id) or "Pick A Route"
		detailMeta.Text = selectedMine and "Select a schematic to see what this route solves." or "Select a route and optionally a schematic."
	end

	routeBody.Text = buildRouteText(selectedMine, selectedRecipe)
	needsBody.Text = buildNeedsText(selectedRecipe)
	sessionBody.Text = buildSessionText()

	local actionOk, actionMessage = buildActionMessage(snapshot and snapshot.lastResult)
	statusLabel.Text = actionMessage or ""
	if actionOk == true then
		statusLabel.TextColor3 = Color3.fromRGB(160, 224, 176)
	elseif actionOk == false then
		statusLabel.TextColor3 = Color3.fromRGB(236, 150, 150)
	else
		statusLabel.TextColor3 = Color3.fromRGB(164, 176, 198)
	end
end

local function refreshButtons()
	local session = snapshot and snapshot.session or nil
	local selectedMine = getSelectedMine()
	local primary = selectedMine and ({ getMineTheme(selectedMine) })[1] or Color3.fromRGB(107, 171, 255)
	local active = session and session.active == true

	setButtonState(startBtn, not active and selectedMine ~= nil, active and "Route Running" or "Start Route", primary)
	setButtonState(stopBtn, active, "Stop And Claim", Color3.fromRGB(255, 150, 110))
end

refresh = function()
	ensureSelections()
	buildDurationButtons(snapshot and snapshot.durationOptions or {})

	if snapshot and snapshot.durationOptions then
		local hasCurrent = false
		for _, durationSec in ipairs(snapshot.durationOptions) do
			if durationSec == selectedDuration then
				hasCurrent = true
				break
			end
		end
		if not hasCurrent then
			selectedDuration = snapshot.durationOptions[1] or selectedDuration
		end
	end

	for durationSec, button in pairs(durationButtons) do
		local active = durationSec == selectedDuration
		button.BackgroundColor3 = active and Color3.fromRGB(86, 132, 214) or Color3.fromRGB(33, 40, 56)
		button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(228, 232, 238)
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = active and Color3.fromRGB(168, 206, 255) or Color3.fromRGB(60, 74, 102)
		end
	end

	refreshSummary()
	rebuildRecipeList()
	rebuildMineList()
	refreshDetail()
	refreshButtons()
end

local function openUI()
	gui.Enabled = true
	MineAction:FireServer({ type = "request" })
end

local function closeUI()
	gui.Enabled = false
end

local function isMinePrompt(prompt)
	local current = prompt and prompt.Parent
	while current do
		if current.Name == "LobbyMine" then
			return true
		end
		current = current.Parent
	end
	return false
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

startBtn.MouseButton1Click:Connect(function()
	if not selectedMineId then
		return
	end
	MineAction:FireServer({
		type = "start",
		durationSec = selectedDuration,
		mineId = selectedMineId,
		focusRecipeId = selectedRecipeId,
	})
end)

stopBtn.MouseButton1Click:Connect(function()
	MineAction:FireServer({ type = "stop" })
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, localPlayer)
	if localPlayer ~= player or gui.Enabled then
		return
	end
	if isMinePrompt(prompt) then
		openUI()
	end
end)

OpenMineUI.OnClientEvent:Connect(function()
	if gui.Enabled then
		MineAction:FireServer({ type = "request" })
		return
	end
	openUI()
end)

MineSync.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	snapshot = data
	autoRefreshQueued = false

	if data.durationOptions then
		if data.session and data.session.active then
			selectedDuration = clampInt(data.session.durationSec, 600)
		elseif data.durationOptions[1] and not durationButtons[selectedDuration] then
			selectedDuration = data.durationOptions[1]
		end
	end

	if data.session and data.session.active then
		selectedMineId = data.session.mineId or selectedMineId
		if data.session.focusRecipeId then
			selectedRecipeId = data.session.focusRecipeId
		end
		manualMineSelection = false
	end

	refresh()
end)

local heartbeatAccum = 0
RunService.Heartbeat:Connect(function(dt)
	heartbeatAccum += dt
	if heartbeatAccum < 0.25 then
		return
	end
	heartbeatAccum = 0

	if not gui.Enabled or not snapshot or not snapshot.session or snapshot.session.active ~= true then
		return
	end

	sessionBody.Text = buildSessionText()
	refreshSummary()

	if math.max(0, clampInt(snapshot.session.endsAt, 0) - os.time()) <= 0 and not autoRefreshQueued then
		autoRefreshQueued = true
		MineAction:FireServer({ type = "request" })
	end
end)
