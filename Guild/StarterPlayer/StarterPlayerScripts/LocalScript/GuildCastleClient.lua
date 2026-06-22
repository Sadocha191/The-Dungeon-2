local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions", 10)
local requestLobbyReturn = remoteEvents and remoteEvents:WaitForChild("RequestLobbyReturn", 10) or nil
local lobbyReturnStatus = remoteEvents and remoteEvents:WaitForChild("LobbyReturnStatus", 10) or nil
local guildLocationOpened = remoteEvents and remoteEvents:WaitForChild("GuildLocationOpened", 10) or nil
local guildTreasuryUpdated = remoteEvents and remoteEvents:WaitForChild("GuildTreasuryUpdated", 10) or nil
local getGuildCastleState = remoteFunctions and remoteFunctions:WaitForChild("GetGuildCastleState", 10) or nil
local getTreasury = remoteFunctions and remoteFunctions:WaitForChild("GetTreasury", 10) or nil
local depositToTreasury = remoteFunctions and remoteFunctions:WaitForChild("DepositToTreasury", 10) or nil
local spendFromTreasury = remoteFunctions and remoteFunctions:WaitForChild("SpendFromTreasury", 10) or nil

local THEME = {
	background = Color3.fromRGB(12, 15, 19),
	panel = Color3.fromRGB(27, 25, 23),
	panelSoft = Color3.fromRGB(37, 35, 32),
	panelDeep = Color3.fromRGB(18, 20, 23),
	gold = Color3.fromRGB(219, 170, 83),
	goldDark = Color3.fromRGB(143, 112, 61),
	text = Color3.fromRGB(238, 232, 216),
	muted = Color3.fromRGB(173, 163, 145),
	error = Color3.fromRGB(238, 116, 93),
}

local LOCATIONS = {
	"Dojo",
	"Skarbiec",
	"Sala chwały",
	"Farmy",
	"Kopalnia",
	"Łowiska",
	"Boss Raid",
}

local FALLBACK_LOCATIONS = {
	{
		Id = "Dojo",
		Name = "Dojo",
		Description = "Przyszłe ulepszenia bojowe gildii.",
		Hint = "zachodni dziedziniec",
		Status = "Coming soon",
	},
	{
		Id = "Treasury",
		Name = "Skarbiec",
		Description = "Przyszłe zarządzanie zasobami gildii.",
		Hint = "wschodnie skrzydło zamku",
		Status = "Coming soon",
	},
	{
		Id = "HallOfFame",
		Name = "Sala chwały",
		Description = "Przyszłe rankingi i contribution członków.",
		Hint = "północna aleja",
		Status = "Coming soon",
	},
	{
		Id = "Farms",
		Name = "Farmy",
		Description = "Przyszła produkcja zasobów gildii.",
		Hint = "południowo-zachodnie pola",
		Status = "Coming soon",
	},
	{
		Id = "Mine",
		Name = "Kopalnia",
		Description = "Przyszła produkcja materiałów gildii.",
		Hint = "południowo-wschodnie skały",
		Status = "Coming soon",
	},
	{
		Id = "Fishing",
		Name = "Łowiska",
		Description = "Przyszła produkcja specjalnych zasobów.",
		Hint = "północno-zachodni staw",
		Status = "Coming soon",
	},
	{
		Id = "BossRaid",
		Name = "Boss Raid",
		Description = "Przyszłe raidy gildyjne.",
		Hint = "północno-wschodni plac bojowy",
		Status = "Coming soon",
	},
}

local gui = playerGui:FindFirstChild("GuildCastleGui")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "GuildCastleGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = playerGui
end

for _, child in ipairs(gui:GetChildren()) do
	child:Destroy()
end

local currentState = nil
local returning = false
local selectedLocationId = nil
local refreshing = false
local statLabels = {}
local locationButtons = {}
local treasuryPanelOpen = false
local treasuryRefreshing = false
local selectedTreasuryResourceId = "Silver"
local refreshFromServer = nil

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props or {}) do
		inst[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function formatNumber(value)
	local text = tostring(math.floor(tonumber(value) or 0))
	local formatted = text
	local count = 0
	repeat
		formatted, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return formatted
end

local function normalizeLocationDefinition(location)
	if typeof(location) ~= "table" then
		return nil
	end
	local id = tostring(location.Id or location.LocationId or "")
	local name = tostring(location.Name or "")
	if id == "" or name == "" then
		return nil
	end
	return {
		Id = id,
		Name = name,
		Description = tostring(location.Description or ""),
		Hint = tostring(location.Hint or ""),
		Status = tostring(location.Status or "Coming soon"),
	}
end

local function getLocationDefinitions(state)
	local source = typeof(state) == "table" and typeof(state.Locations) == "table" and state.Locations or FALLBACK_LOCATIONS
	local locations = {}
	for _, location in ipairs(source) do
		local normalized = normalizeLocationDefinition(location)
		if normalized then
			table.insert(locations, normalized)
		end
	end
	if #locations == 0 and source ~= FALLBACK_LOCATIONS then
		return getLocationDefinitions({ Locations = FALLBACK_LOCATIONS })
	end
	return locations
end

local function formatLocationButtonText(location)
	if location.Hint ~= "" then
		return location.Name .. "\n" .. location.Hint
	end
	return location.Name
end

local root = create("Frame", {
	BackgroundColor3 = THEME.background,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, gui)

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = THEME.panel,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -32, 1, -32),
}, root)
create("UISizeConstraint", {
	MaxSize = Vector2.new(980, 660),
	MinSize = Vector2.new(360, 420),
}, panel)
create("UICorner", { CornerRadius = UDim.new(0, 8) }, panel)
create("UIStroke", {
	Color = THEME.gold,
	Thickness = 2,
	Transparency = 0.08,
}, panel)

local header = create("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 16),
	Size = UDim2.new(1, -36, 0, 76),
}, panel)

local title = create("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, -190, 0, 36),
	Text = "Guild Castle",
	TextColor3 = THEME.gold,
	TextSize = 28,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local meta = create("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.fromOffset(2, 39),
	Size = UDim2.new(1, -190, 0, 28),
	Text = "Loading guild data...",
	TextColor3 = THEME.muted,
	TextSize = 14,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local returnButton = create("TextButton", {
	Name = "ReturnToLobbyButton",
	AnchorPoint = Vector2.new(1, 0),
	AutoButtonColor = true,
	BackgroundColor3 = THEME.gold,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(1, 0, 0, 6),
	Size = UDim2.fromOffset(170, 42),
	Text = "Return to Four Peaks",
	TextColor3 = Color3.fromRGB(24, 21, 18),
	TextSize = 14,
	TextWrapped = true,
}, header)
create("UICorner", { CornerRadius = UDim.new(0, 6) }, returnButton)

local content = create("ScrollingFrame", {
	Active = true,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(18, 100),
	ScrollBarImageColor3 = THEME.goldDark,
	ScrollBarThickness = 6,
	Size = UDim2.new(1, -36, 1, -158),
}, panel)

local contentLayout = create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, content)
create("UIPadding", {
	PaddingBottom = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 8),
}, content)

local errorPanel = create("TextLabel", {
	BackgroundColor3 = THEME.panelSoft,
	BorderSizePixel = 0,
	Font = Enum.Font.Gotham,
	LayoutOrder = 1,
	Size = UDim2.new(1, -8, 0, 86),
	Text = "Loading guild data...",
	TextColor3 = THEME.muted,
	TextSize = 15,
	TextWrapped = true,
	Visible = false,
}, content)
create("UICorner", { CornerRadius = UDim.new(0, 6) }, errorPanel)

local guildContent = create("Frame", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Size = UDim2.new(1, -8, 0, 0),
	Visible = false,
}, content)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, guildContent)

local function makeSection(parent, titleText, order)
	local frame = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)
	create("UIPadding", {
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 12),
	}, frame)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Text = titleText,
		TextColor3 = THEME.gold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)

	return frame
end

local descriptionSection = makeSection(guildContent, "Opis gildii", 1)
local descriptionLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 58),
	Text = "",
	TextColor3 = THEME.text,
	TextSize = 14,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
}, descriptionSection)

local statsSection = makeSection(guildContent, "Status", 2)
local statsGrid = create("Frame", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 0),
}, statsSection)
create("UIGridLayout", {
	CellPadding = UDim2.fromOffset(8, 8),
	CellSize = UDim2.new(0.5, -4, 0, 48),
	FillDirectionMaxCells = 2,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, statsGrid)

local function makeStat(key, label, order)
	local frame = create("Frame", {
		BackgroundColor3 = THEME.panelDeep,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, statsGrid)
	create("UICorner", { CornerRadius = UDim.new(0, 5) }, frame)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 16),
		Text = label,
		TextColor3 = THEME.muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
	statLabels[key] = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(10, 23),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "-",
		TextColor3 = THEME.text,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)
end

makeStat("Level", "Level", 1)
makeStat("XP", "XP", 2)
makeStat("Members", "Members", 3)
makeStat("Online", "Online", 4)
makeStat("Role", "Your role", 5)
makeStat("Privacy", "Privacy", 6)

local treasurySection = makeSection(guildContent, "Skarbiec", 3)
local treasuryGrid = create("Frame", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 0),
}, treasurySection)
create("UIGridLayout", {
	CellPadding = UDim2.fromOffset(8, 8),
	CellSize = UDim2.new(0.5, -4, 0, 38),
	FillDirectionMaxCells = 2,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, treasuryGrid)

local locationsSection = makeSection(guildContent, "Lokacje gildii", 4)
local locationsGrid = create("Frame", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 0),
}, locationsSection)
create("UIGridLayout", {
	CellPadding = UDim2.fromOffset(8, 8),
	CellSize = UDim2.new(0.5, -4, 0, 58),
	FillDirectionMaxCells = 2,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, locationsGrid)

local status = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.new(0, 18, 1, -12),
	Size = UDim2.new(1, -36, 0, 34),
	Text = "Loading guild data...",
	TextColor3 = THEME.muted,
	TextSize = 14,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
}, panel)

local locationOverlay = create("Frame", {
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 30,
}, root)

local locationPanel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = THEME.panel,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -48, 0, 250),
	ZIndex = 31,
}, locationOverlay)
create("UISizeConstraint", {
	MaxSize = Vector2.new(520, 250),
	MinSize = Vector2.new(300, 220),
}, locationPanel)
create("UICorner", { CornerRadius = UDim.new(0, 8) }, locationPanel)
create("UIStroke", {
	Color = THEME.gold,
	Thickness = 2,
	Transparency = 0.08,
}, locationPanel)
create("UIPadding", {
	PaddingBottom = UDim.new(0, 18),
	PaddingLeft = UDim.new(0, 18),
	PaddingRight = UDim.new(0, 18),
	PaddingTop = UDim.new(0, 18),
}, locationPanel)

local locationTitle = create("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, -52, 0, 34),
	Text = "Guild location",
	TextColor3 = THEME.gold,
	TextSize = 24,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 32,
}, locationPanel)

local locationCloseButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	AutoButtonColor = true,
	BackgroundColor3 = THEME.panelDeep,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(42, 34),
	Text = "X",
	TextColor3 = THEME.text,
	TextSize = 18,
	ZIndex = 32,
}, locationPanel)
create("UICorner", { CornerRadius = UDim.new(0, 6) }, locationCloseButton)

local locationDescription = create("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.fromOffset(0, 50),
	Size = UDim2.new(1, 0, 0, 84),
	Text = "",
	TextColor3 = THEME.text,
	TextSize = 16,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 32,
}, locationPanel)

local locationStatus = create("TextLabel", {
	BackgroundColor3 = THEME.panelDeep,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(0, 0, 1, -58),
	Size = UDim2.new(1, 0, 0, 42),
	Text = "Coming soon",
	TextColor3 = THEME.gold,
	TextSize = 16,
	TextWrapped = true,
	ZIndex = 32,
}, locationPanel)
create("UICorner", { CornerRadius = UDim.new(0, 6) }, locationStatus)

local treasuryOverlay = create("Frame", {
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.32,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 40,
}, root)

local treasuryPanel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = THEME.panel,
	BorderSizePixel = 0,
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -42, 1, -54),
	ZIndex = 41,
}, treasuryOverlay)
create("UISizeConstraint", {
	MaxSize = Vector2.new(760, 620),
	MinSize = Vector2.new(330, 440),
}, treasuryPanel)
create("UICorner", { CornerRadius = UDim.new(0, 8) }, treasuryPanel)
create("UIStroke", {
	Color = THEME.gold,
	Thickness = 2,
	Transparency = 0.08,
}, treasuryPanel)
create("UIPadding", {
	PaddingBottom = UDim.new(0, 14),
	PaddingLeft = UDim.new(0, 16),
	PaddingRight = UDim.new(0, 16),
	PaddingTop = UDim.new(0, 14),
}, treasuryPanel)

local treasuryTitle = create("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(1, -52, 0, 34),
	Text = "Skarbiec",
	TextColor3 = THEME.gold,
	TextSize = 24,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 42,
}, treasuryPanel)

local treasuryCloseButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	AutoButtonColor = true,
	BackgroundColor3 = THEME.panelDeep,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.fromOffset(42, 34),
	Text = "X",
	TextColor3 = THEME.text,
	TextSize = 18,
	ZIndex = 42,
}, treasuryPanel)
create("UICorner", { CornerRadius = UDim.new(0, 6) }, treasuryCloseButton)

local treasuryBody = create("ScrollingFrame", {
	Active = true,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.fromOffset(0, 0),
	Position = UDim2.fromOffset(0, 44),
	ScrollBarImageColor3 = THEME.goldDark,
	ScrollBarThickness = 6,
	Size = UDim2.new(1, 0, 1, -92),
	ZIndex = 42,
}, treasuryPanel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, treasuryBody)
create("UIPadding", {
	PaddingBottom = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
}, treasuryBody)

local function makeTreasurySection(titleText, order)
	local frame = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.panelSoft,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		ZIndex = 42,
	}, treasuryBody)
	create("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)
	create("UIPadding", {
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 10),
	}, frame)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Text = titleText,
		TextColor3 = THEME.gold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 43,
	}, frame)
	return frame
end

local treasuryGuildSection = makeTreasurySection("Guild resources", 1)
local treasuryGuildList = create("Frame", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 0),
	ZIndex = 43,
}, treasuryGuildSection)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, treasuryGuildList)

local treasuryPlayerSection = makeTreasurySection("Your resources", 2)
local treasuryPlayerList = create("Frame", {
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 0),
	ZIndex = 43,
}, treasuryPlayerSection)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 5),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, treasuryPlayerList)

local treasuryDonateSection = makeTreasurySection("Donate", 3)
local treasuryContributionLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 22),
	Text = "Contribution: -",
	TextColor3 = THEME.text,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 43,
}, treasuryDonateSection)
local treasuryAmountBox = create("TextBox", {
	BackgroundColor3 = THEME.panelDeep,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	LayoutOrder = 3,
	PlaceholderText = "Amount",
	Size = UDim2.new(1, 0, 0, 34),
	Text = "",
	TextColor3 = THEME.text,
	TextSize = 15,
	ZIndex = 43,
}, treasuryDonateSection)
create("UICorner", { CornerRadius = UDim.new(0, 5) }, treasuryAmountBox)
local treasuryDonateButton = create("TextButton", {
	AutoButtonColor = true,
	BackgroundColor3 = THEME.gold,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 36),
	Text = "Donate",
	TextColor3 = Color3.fromRGB(24, 21, 18),
	TextSize = 15,
	ZIndex = 43,
}, treasuryDonateSection)
create("UICorner", { CornerRadius = UDim.new(0, 5) }, treasuryDonateButton)

local treasurySpendSection = makeTreasurySection("Spend / Use resources", 4)
local treasurySpendAmountBox = create("TextBox", {
	BackgroundColor3 = THEME.panelDeep,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	LayoutOrder = 2,
	PlaceholderText = "Amount to spend",
	Size = UDim2.new(1, 0, 0, 34),
	Text = "",
	TextColor3 = THEME.text,
	TextSize = 15,
	ZIndex = 43,
}, treasurySpendSection)
create("UICorner", { CornerRadius = UDim.new(0, 5) }, treasurySpendAmountBox)
local treasurySpendReasonBox = create("TextBox", {
	BackgroundColor3 = THEME.panelDeep,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	LayoutOrder = 3,
	PlaceholderText = "Reason",
	Size = UDim2.new(1, 0, 0, 34),
	Text = "Test spend",
	TextColor3 = THEME.text,
	TextSize = 15,
	ZIndex = 43,
}, treasurySpendSection)
create("UICorner", { CornerRadius = UDim.new(0, 5) }, treasurySpendReasonBox)
local treasurySpendButton = create("TextButton", {
	AutoButtonColor = true,
	BackgroundColor3 = THEME.goldDark,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	LayoutOrder = 4,
	Size = UDim2.new(1, 0, 0, 36),
	Text = "Spend selected resource",
	TextColor3 = THEME.text,
	TextSize = 15,
	ZIndex = 43,
}, treasurySpendSection)
create("UICorner", { CornerRadius = UDim.new(0, 5) }, treasurySpendButton)

local treasuryFeedback = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 40),
	Text = "",
	TextColor3 = THEME.muted,
	TextSize = 14,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	ZIndex = 42,
}, treasuryPanel)

local function setStatus(message, isError)
	status.Text = tostring(message or "")
	status.TextColor3 = isError and THEME.error or THEME.muted
end

local function setTreasuryFeedback(message, isError)
	treasuryFeedback.Text = tostring(message or "")
	treasuryFeedback.TextColor3 = isError and THEME.error or THEME.muted
end

local function clearGuiObjects(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function findResource(resources, resourceId)
	if typeof(resources) ~= "table" then
		return nil
	end
	for _, resource in ipairs(resources) do
		if typeof(resource) == "table" and tostring(resource.Id or "") == resourceId then
			return resource
		end
	end
	return nil
end

local function getResourceAmount(resources, resourceId)
	local resource = findResource(resources, resourceId)
	return resource and tonumber(resource.Amount) or 0
end

local function getFirstResourceId(resources)
	if typeof(resources) == "table" then
		for _, resource in ipairs(resources) do
			if typeof(resource) == "table" and tostring(resource.Id or "") ~= "" then
				return tostring(resource.Id)
			end
		end
	end
	return "Silver"
end

local function addTreasuryText(parent, textValue, order, color)
	create("TextLabel", {
		BackgroundColor3 = THEME.panelDeep,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 28),
		Text = tostring(textValue or ""),
		TextColor3 = color or THEME.text,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 44,
	}, parent)
end

local function updateTreasurySelectionButtons()
	for _, button in ipairs(treasuryPlayerList:GetChildren()) do
		if button:IsA("TextButton") then
			local selected = button:GetAttribute("ResourceId") == selectedTreasuryResourceId
			button.BackgroundColor3 = selected and THEME.goldDark or THEME.panelDeep
			button.TextColor3 = selected and Color3.fromRGB(255, 241, 204) or THEME.text
		end
	end
end

local function renderTreasuryState(state)
	if typeof(state) ~= "table" then
		setTreasuryFeedback("Treasury data is not available.", true)
		return
	end

	local guildResources = typeof(state.GuildResources) == "table" and state.GuildResources or {}
	local playerResources = typeof(state.PlayerResources) == "table" and state.PlayerResources or {}
	if not findResource(playerResources, selectedTreasuryResourceId) then
		selectedTreasuryResourceId = getFirstResourceId(playerResources)
	end

	treasuryTitle.Text = ("Skarbiec  [%s]"):format(tostring(state.Role or "Member"))
	treasuryContributionLabel.Text = ("Your contribution: %s   Guild total: %s"):format(formatNumber(state.Contribution or 0), formatNumber(state.TotalContribution or 0))

	clearGuiObjects(treasuryGuildList)
	if #guildResources == 0 then
		addTreasuryText(treasuryGuildList, "No guild resources yet.", 1, THEME.muted)
	else
		for index, resource in ipairs(guildResources) do
			addTreasuryText(treasuryGuildList, ("%s: %s"):format(tostring(resource.DisplayName or resource.Id), formatNumber(resource.Amount or 0)), index, THEME.text)
		end
	end

	clearGuiObjects(treasuryPlayerList)
	if #playerResources == 0 then
		addTreasuryText(treasuryPlayerList, "No depositable resources in your profile.", 1, THEME.muted)
	else
		for index, resource in ipairs(playerResources) do
			local resourceId = tostring(resource.Id or "")
			local guildAmount = getResourceAmount(guildResources, resourceId)
			local row = create("TextButton", {
				AutoButtonColor = true,
				BackgroundColor3 = THEME.panelDeep,
				BorderSizePixel = 0,
				Font = Enum.Font.Gotham,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 34),
				Text = ("%s   You %s   Guild %s"):format(tostring(resource.DisplayName or resourceId), formatNumber(resource.Amount or 0), formatNumber(guildAmount)),
				TextColor3 = THEME.text,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 44,
			}, treasuryPlayerList)
			row:SetAttribute("ResourceId", resourceId)
			create("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
			row.Activated:Connect(function()
				selectedTreasuryResourceId = resourceId
				updateTreasurySelectionButtons()
			end)
		end
	end
	updateTreasurySelectionButtons()

	treasurySpendSection.Visible = state.CanSpend == true
	if not treasurySpendSection.Visible then
		treasurySpendAmountBox.Text = ""
	end

	local message = tostring(state.Message or "")
	if message ~= "" then
		setTreasuryFeedback(message, state.Success ~= true)
	end
end

local function refreshTreasuryPanel(message)
	if treasuryRefreshing then
		return
	end
	if not getTreasury then
		setTreasuryFeedback("Treasury service is not available.", true)
		return
	end
	treasuryRefreshing = true
	setTreasuryFeedback(message or "Loading treasury...", false)
	local ok, response = pcall(function()
		local guildId = currentState and currentState.Guild and currentState.Guild.GuildId or nil
		return getTreasury:InvokeServer(guildId)
	end)
	treasuryRefreshing = false
	if not ok then
		warn("[GuildCastleClient] GetTreasury failed:", response)
		setTreasuryFeedback("Treasury data could not be loaded.", true)
		return
	end
	renderTreasuryState(response)
end

local function openTreasuryPanel(initialState)
	treasuryPanelOpen = true
	locationOverlay.Visible = false
	treasuryOverlay.Visible = true
	if typeof(initialState) == "table" then
		renderTreasuryState(initialState)
	else
		refreshTreasuryPanel()
	end
end

local function closeTreasuryPanel()
	treasuryPanelOpen = false
	treasuryOverlay.Visible = false
end

local function setReturnButtonBusy(isBusy)
	returning = isBusy == true
	local available = requestLobbyReturn ~= nil
	returnButton.Active = available and not returning
	returnButton.AutoButtonColor = available and not returning
	if returning then
		returnButton.Text = "Returning..."
		returnButton.BackgroundColor3 = Color3.fromRGB(120, 104, 78)
	elseif available then
		returnButton.Text = "Return to Four Peaks"
		returnButton.BackgroundColor3 = THEME.gold
	else
		returnButton.Text = "Return unavailable"
		returnButton.BackgroundColor3 = Color3.fromRGB(83, 76, 67)
	end
end

local function updateLocationButtons()
	for locationId, button in pairs(locationButtons) do
		local selected = locationId == selectedLocationId
		button.BackgroundColor3 = selected and THEME.goldDark or THEME.panelDeep
		button.TextColor3 = selected and Color3.fromRGB(255, 241, 204) or THEME.text
	end
end

local function clearLocationButtons()
	for _, child in ipairs(locationsGrid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	table.clear(locationButtons)
end

local function renderLocationButtons(state)
	clearLocationButtons()
	for index, location in ipairs(getLocationDefinitions(state)) do
		local button = create("TextButton", {
			AutoButtonColor = true,
			BackgroundColor3 = THEME.panelDeep,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			LayoutOrder = index,
			Text = formatLocationButtonText(location),
			TextColor3 = THEME.text,
			TextSize = 12,
			TextWrapped = true,
		}, locationsGrid)
		create("UICorner", { CornerRadius = UDim.new(0, 5) }, button)
		locationButtons[location.Id] = button
		button.Activated:Connect(function()
			selectedLocationId = location.Id
			updateLocationButtons()
			if location.Hint ~= "" then
				setStatus(location.Name .. ": " .. location.Hint .. ". Użyj promptu przy wejściu.", false)
			else
				setStatus(location.Name .. ": użyj promptu przy wejściu.", false)
			end
		end)
	end
	updateLocationButtons()
end

local function hideLocationPanel()
	locationOverlay.Visible = false
end

local function showLocationPanel(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local location = typeof(payload.Location) == "table" and payload.Location or payload
	local success = payload.Success == true
	local locationId = tostring(location.Id or payload.LocationId or "")
	if locationId ~= "" then
		selectedLocationId = locationId
		updateLocationButtons()
	end

	locationTitle.Text = tostring(location.Name or payload.Name or "Guild location")
	if success then
		if location.Panel == "Treasury" then
			openTreasuryPanel(payload.Treasury)
			return
		end
		locationDescription.Text = tostring(location.Description or "")
		locationStatus.Text = tostring(location.Status or "Coming soon")
		locationStatus.TextColor3 = THEME.gold
		setStatus(locationTitle.Text .. ": " .. locationStatus.Text, false)
	else
		locationDescription.Text = tostring(payload.Message or "You must be a guild member to use this location.")
		locationStatus.Text = tostring(payload.Status or "Locked")
		locationStatus.TextColor3 = THEME.error
		setStatus(locationDescription.Text, true)
	end
	locationOverlay.Visible = true
end

locationCloseButton.Activated:Connect(hideLocationPanel)
treasuryCloseButton.Activated:Connect(closeTreasuryPanel)
treasuryDonateButton.Activated:Connect(function()
	if not depositToTreasury then
		setTreasuryFeedback("Deposit service is not available.", true)
		return
	end
	local amount = tonumber(treasuryAmountBox.Text)
	setTreasuryFeedback("Submitting donation...", false)
	local ok, response = pcall(function()
		return depositToTreasury:InvokeServer(selectedTreasuryResourceId, amount)
	end)
	if not ok then
		warn("[GuildCastleClient] DepositToTreasury failed:", response)
		setTreasuryFeedback("Donation failed.", true)
		return
	end
	renderTreasuryState(response)
	if refreshFromServer then
		task.defer(refreshFromServer)
	end
end)
treasurySpendButton.Activated:Connect(function()
	if not spendFromTreasury then
		setTreasuryFeedback("Spend service is not available.", true)
		return
	end
	local amount = tonumber(treasurySpendAmountBox.Text)
	setTreasuryFeedback("Submitting spend...", false)
	local ok, response = pcall(function()
		return spendFromTreasury:InvokeServer(selectedTreasuryResourceId, amount, treasurySpendReasonBox.Text)
	end)
	if not ok then
		warn("[GuildCastleClient] SpendFromTreasury failed:", response)
		setTreasuryFeedback("Spend failed.", true)
		return
	end
	renderTreasuryState(response)
	if refreshFromServer then
		task.defer(refreshFromServer)
	end
end)
if guildLocationOpened then
	guildLocationOpened.OnClientEvent:Connect(showLocationPanel)
end
if guildTreasuryUpdated then
	guildTreasuryUpdated.OnClientEvent:Connect(function(_payload)
		if refreshFromServer then
			task.defer(refreshFromServer)
		end
		if treasuryPanelOpen then
			task.defer(refreshTreasuryPanel)
		end
	end)
end
renderLocationButtons({ Locations = FALLBACK_LOCATIONS })

local function clearTreasury()
	for _, child in ipairs(treasuryGrid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addTreasuryItem(name, amount, order)
	local row = create("Frame", {
		BackgroundColor3 = THEME.panelDeep,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, treasuryGrid)
	create("UICorner", { CornerRadius = UDim.new(0, 5) }, row)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0.55, -10, 1, 0),
		Text = tostring(name),
		TextColor3 = THEME.muted,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.new(0.55, 0, 0, 0),
		Size = UDim2.new(0.45, -10, 1, 0),
		Text = formatNumber(amount),
		TextColor3 = THEME.text,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
end

local function renderError(message)
	currentState = nil
	guildContent.Visible = false
	errorPanel.Visible = true
	errorPanel.Text = tostring(message or "Guild data could not be loaded.")
	title.Text = "Guild Castle"
	meta.Text = "Guild data unavailable"
	setStatus(message or "Guild data could not be loaded.", true)
end

local function renderState(state)
	currentState = state
	errorPanel.Visible = false
	guildContent.Visible = true

	local guild = state.Guild or {}
	local membership = state.Membership or {}
	title.Text = tostring(guild.Name or "Guild Castle")
	meta.Text = tostring(guild.GuildId or "")
	descriptionLabel.Text = tostring(guild.Description or "")
	if descriptionLabel.Text == "" then
		descriptionLabel.Text = "No description set yet."
	end

	statLabels.Level.Text = formatNumber(guild.Level or 1)
	statLabels.XP.Text = formatNumber(guild.XP or 0)
	statLabels.Members.Text = formatNumber(guild.MemberCount or 0)
	statLabels.Online.Text = formatNumber(guild.OnlineMemberCount or 0)
	statLabels.Role.Text = tostring(membership.Role or "-")
	statLabels.Privacy.Text = tostring(guild.Privacy or "Public")

	clearTreasury()
	local treasury = typeof(guild.Treasury) == "table" and guild.Treasury or {}
	local keys = typeof(guild.TreasuryKeys) == "table" and guild.TreasuryKeys or {}
	if #keys == 0 then
		for key in pairs(treasury) do
			table.insert(keys, key)
		end
		table.sort(keys)
	end
	for index, key in ipairs(keys) do
		addTreasuryItem(key, treasury[key] or 0, index)
	end

	renderLocationButtons(state)
	setStatus("Guild data loaded.", false)
end

refreshFromServer = function()
	if refreshing then
		return
	end
	if not getGuildCastleState then
		renderError("Guild data service is not available.")
		return
	end

	refreshing = true
	setStatus("Loading guild data...", false)
	local ok, state = pcall(function()
		return getGuildCastleState:InvokeServer()
	end)
	refreshing = false

	if not ok then
		renderError("Guild data could not be loaded.")
		warn("[GuildCastleClient] GetGuildCastleState failed:", state)
		return
	end
	if typeof(state) ~= "table" or state.Success ~= true then
		renderError(typeof(state) == "table" and state.Message or "Guild data could not be loaded.")
		return
	end

	renderState(state)
end

returnButton.Activated:Connect(function()
	if returning then
		return
	end
	if not requestLobbyReturn then
		setStatus("Return to lobby is not available yet.", true)
		setReturnButtonBusy(false)
		return
	end

	setStatus("Returning to Four Peaks...", false)
	setReturnButtonBusy(true)
	requestLobbyReturn:FireServer()
end)

if lobbyReturnStatus then
	lobbyReturnStatus.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end

		local message = tostring(payload.Message or "")
		if message == "" then
			message = payload.Success == true and "Returning to Four Peaks..." or "Return to lobby failed."
		end
		setReturnButtonBusy(payload.Success == true)
		setStatus(message, payload.Success ~= true)
	end)
end

player:GetAttributeChangedSignal("GuildCastleReady"):Connect(function()
	if player:GetAttribute("GuildCastleReady") == true then
		refreshFromServer()
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(refreshFromServer)
end)

setReturnButtonBusy(false)
refreshFromServer()
