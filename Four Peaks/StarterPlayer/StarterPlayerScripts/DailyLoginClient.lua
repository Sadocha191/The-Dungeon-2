local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local moduleRoot = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local UiResponsive = require(moduleRoot:WaitForChild("UiResponsive"))

local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local GetDailyLoginState = remoteFunctions:WaitForChild("GetDailyLoginState")
local ClaimDailyLoginReward = remoteFunctions:WaitForChild("ClaimDailyLoginReward")

local DESIGN_SIZE = Vector2.new(980, 640)
local SECONDS_PER_DAY = 24 * 60 * 60
local AUTO_OPEN_DELAY_SECONDS = 1.25

local THEME = {
	overlay = Color3.fromRGB(3, 5, 10),
	panelTop = Color3.fromRGB(25, 27, 39),
	panelBottom = Color3.fromRGB(12, 14, 22),
	surface = Color3.fromRGB(24, 27, 38),
	surfaceSoft = Color3.fromRGB(19, 22, 31),
	text = Color3.fromRGB(247, 244, 235),
	muted = Color3.fromRGB(166, 171, 187),
	mutedDark = Color3.fromRGB(111, 116, 130),
	gold = Color3.fromRGB(239, 187, 79),
	goldBright = Color3.fromRGB(255, 218, 132),
	goldSoft = Color3.fromRGB(68, 50, 20),
	green = Color3.fromRGB(76, 171, 109),
	greenSoft = Color3.fromRGB(22, 55, 38),
	locked = Color3.fromRGB(68, 73, 88),
	lockedSoft = Color3.fromRGB(25, 28, 37),
	danger = Color3.fromRGB(209, 100, 91),
	button = Color3.fromRGB(195, 132, 45),
	buttonHover = Color3.fromRGB(216, 154, 57),
	buttonDisabled = Color3.fromRGB(61, 64, 74),
}

local REWARD_COLORS = {
	Ticket = Color3.fromRGB(239, 187, 79),
	Souls = Color3.fromRGB(150, 102, 226),
	MaterialBundle = Color3.fromRGB(97, 172, 121),
	Booster = Color3.fromRGB(89, 153, 222),
}

local REWARD_GLYPHS = {
	Ticket = "◆",
	Souls = "◈",
	MaterialBundle = "▦",
	Booster = "XP",
}

local currentState = nil
local isBusy = false
local hasAutoOpenChecked = false
local resetRefreshPending = false
local uiTransitionToken = 0
local tiles = {}
local progressSegments = {}

local function create(className, props, parent)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or 10),
	}, parent)
end

local function addStroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, parent)
end

local function addGradient(parent, topColor, bottomColor, rotation)
	return create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, topColor),
			ColorSequenceKeypoint.new(1, bottomColor),
		}),
		Rotation = rotation or 90,
	}, parent)
end

local function tween(instance, duration, properties, easingStyle, easingDirection)
	local handle = TweenService:Create(
		instance,
		TweenInfo.new(
			duration,
			easingStyle or Enum.EasingStyle.Quad,
			easingDirection or Enum.EasingDirection.Out
		),
		properties
	)
	handle:Play()
	return handle
end

local function formatInteger(value)
	local number = math.max(0, math.floor(tonumber(value) or 0))
	return tostring(number):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function formatCountdown(totalSeconds)
	local seconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, remainingSeconds)
end

local function getRewardColor(reward)
	local rewardType = tostring((reward and reward.RewardType) or "")
	return REWARD_COLORS[rewardType] or THEME.gold
end

local function getRewardGlyph(reward)
	local rewardType = tostring((reward and reward.RewardType) or "")
	return REWARD_GLYPHS[rewardType] or "?"
end

local function getImageFromInstance(instance)
	if not instance then
		return nil
	end
	if instance:IsA("StringValue") then
		return instance.Value
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		return instance.Image
	elseif instance:IsA("Decal") or instance:IsA("Texture") then
		return instance.Texture
	end

	local attribute = instance:GetAttribute("Image") or instance:GetAttribute("Texture")
	if typeof(attribute) == "string" then
		return attribute
	end
	return nil
end

local function resolveRewardImage(reward)
	if typeof(reward) ~= "table" then
		return nil
	end

	local configuredIcon = tostring(reward.Icon or "")
	if configuredIcon:match("^rbxassetid://") or configuredIcon:match("^https?://") then
		return configuredIcon
	end

	local candidateNames = {
		configuredIcon,
		tostring(reward.RewardType or ""),
		tostring(reward.DisplayName or ""),
	}
	local containerNames = {
		"DailyLoginIcons",
		"CurrencyIcons",
		"MaterialIcons",
	}

	for _, containerName in ipairs(containerNames) do
		local container = ReplicatedStorage:FindFirstChild(containerName)
		if container then
			for _, candidateName in ipairs(candidateNames) do
				if candidateName ~= "" then
					local image = getImageFromInstance(container:FindFirstChild(candidateName))
					if image and image ~= "" then
						return image
					end
				end
			end
		end
	end

	return nil
end

local function getRewardAmountText(reward)
	if typeof(reward) ~= "table" then
		return ""
	end

	if reward.RewardType == "MaterialBundle" then
		local count = 0
		for _, entry in ipairs(reward.Materials or {}) do
			if (tonumber(entry.Amount) or 0) > 0 then
				count += 1
			end
		end
		return count == 1 and "1 material" or tostring(count) .. " materials"
	end

	local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
	if amount <= 0 then
		return ""
	end
	return "x" .. formatInteger(amount)
end

local function getRewardSummary(reward)
	if typeof(reward) ~= "table" then
		return "Reward unavailable"
	end

	if reward.RewardType == "MaterialBundle" then
		local parts = {}
		for _, entry in ipairs(reward.Materials or {}) do
			local amount = math.max(0, math.floor(tonumber(entry.Amount) or 0))
			if amount > 0 then
				table.insert(parts, tostring(amount) .. " " .. tostring(entry.Id or "Material"))
			end
		end
		if #parts > 0 then
			return table.concat(parts, "  •  ")
		end
		return tostring(reward.DisplayName or "Materials")
	end

	local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
	local name = tostring(reward.DisplayName or reward.RewardType or "Reward")
	return "x" .. formatInteger(amount) .. " " .. name
end

local function findReward(state, day)
	for _, reward in ipairs((state and state.Rewards) or {}) do
		if tonumber(reward.Day) == day then
			return reward
		end
	end
	return nil
end

local function findDayStatus(state, day)
	for _, entry in ipairs((state and state.Days) or {}) do
		if tonumber(entry.Day) == day then
			return entry
		end
	end
	return nil
end

local gui = playerGui:FindFirstChild("DailyLoginGui")
if not (gui and gui:IsA("ScreenGui")) then
	gui = Instance.new("ScreenGui")
	gui.Name = "DailyLoginGui"
	gui.Parent = playerGui
end

gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
gui.DisplayOrder = 65
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("Modal", true)

for _, child in ipairs(gui:GetChildren()) do
	child:Destroy()
end

local overlay = create("Frame", {
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.overlay,
	BackgroundTransparency = 0.16,
	BorderSizePixel = 0,
	Active = true,
}, gui)

local backdropButton = create("TextButton", {
	Name = "BackdropButton",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 1,
}, overlay)

local panel = create("CanvasGroup", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(DESIGN_SIZE.X, DESIGN_SIZE.Y),
	BackgroundColor3 = THEME.panelBottom,
	BorderSizePixel = 0,
	GroupTransparency = 0,
	Active = true,
	ZIndex = 2,
}, overlay)
addCorner(panel, 22)
addStroke(panel, Color3.fromRGB(57, 63, 82), 1, 0.05)
addGradient(panel, THEME.panelTop, THEME.panelBottom, 90)
UiResponsive.attachCenteredPanel(panel, DESIGN_SIZE, {
	margin = 18,
})

create("Frame", {
	Name = "TopAccent",
	Position = UDim2.fromOffset(24, 0),
	Size = UDim2.new(1, -48, 0, 4),
	BackgroundColor3 = THEME.gold,
	BorderSizePixel = 0,
	ZIndex = 3,
}, panel)

local title = create("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(30, 24),
	Size = UDim2.new(1, -100, 0, 36),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	Text = "DAILY REWARDS",
	TextColor3 = THEME.text,
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 3,
}, panel)

create("TextLabel", {
	Name = "Subtitle",
	Position = UDim2.fromOffset(31, 61),
	Size = UDim2.new(1, -110, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "Log in each day to advance the seven-day reward cycle.",
	TextColor3 = THEME.muted,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 3,
}, panel)

local closeButton = create("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -24, 0, 22),
	Size = UDim2.fromOffset(42, 42),
	BackgroundColor3 = Color3.fromRGB(37, 40, 52),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "X",
	TextColor3 = Color3.fromRGB(235, 237, 244),
	TextSize = 17,
	AutoButtonColor = false,
	ZIndex = 4,
}, panel)
addCorner(closeButton, 13)
local closeStroke = addStroke(closeButton, Color3.fromRGB(73, 78, 97), 1, 0.1)

local summaryBar = create("Frame", {
	Name = "SummaryBar",
	Position = UDim2.fromOffset(30, 98),
	Size = UDim2.new(1, -60, 0, 54),
	BackgroundColor3 = THEME.surfaceSoft,
	BorderSizePixel = 0,
	ZIndex = 3,
}, panel)
addCorner(summaryBar, 14)
addStroke(summaryBar, Color3.fromRGB(48, 54, 71), 1, 0.15)

local cycleLabel = create("TextLabel", {
	Name = "CycleLabel",
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(0.5, -16, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "CYCLE DAY 1 / 7",
	TextColor3 = THEME.goldBright,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
}, summaryBar)

local totalClaimsLabel = create("TextLabel", {
	Name = "TotalClaimsLabel",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 8),
	Size = UDim2.new(0.5, -16, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Text = "TOTAL CLAIMED: 0",
	TextColor3 = THEME.muted,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 4,
}, summaryBar)

local progressHolder = create("Frame", {
	Name = "ProgressHolder",
	Position = UDim2.fromOffset(16, 33),
	Size = UDim2.new(1, -32, 0, 9),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, summaryBar)

local progressLayout = create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, progressHolder)
progressLayout.Parent = progressHolder

for day = 1, 7 do
	local segment = create("Frame", {
		Name = "Day" .. tostring(day),
		Size = UDim2.new(1 / 7, -6, 1, 0),
		BackgroundColor3 = THEME.locked,
		BorderSizePixel = 0,
		LayoutOrder = day,
		ZIndex = 4,
	}, progressHolder)
	addCorner(segment, 5)
	progressSegments[day] = segment
end

create("TextLabel", {
	Name = "RewardsLabel",
	Position = UDim2.fromOffset(31, 172),
	Size = UDim2.new(1, -62, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "REWARD CALENDAR",
	TextColor3 = THEME.muted,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 3,
}, panel)

local cardsHolder = create("Frame", {
	Name = "CardsHolder",
	Position = UDim2.fromOffset(30, 202),
	Size = UDim2.new(1, -60, 0, 310),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, panel)

local firstRow = create("Frame", {
	Name = "FirstRow",
	Size = UDim2.new(1, 0, 0, 149),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, cardsHolder)

create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, firstRow)

local secondRow = create("Frame", {
	Name = "SecondRow",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 161),
	Size = UDim2.fromOffset(690, 149),
	BackgroundTransparency = 1,
	ZIndex = 3,
}, cardsHolder)

create("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, secondRow)

local function makeTile(day, parent)
	local tile = create("Frame", {
		Name = "Day" .. tostring(day),
		Size = UDim2.fromOffset(222, 149),
		BackgroundColor3 = THEME.lockedSoft,
		BorderSizePixel = 0,
		LayoutOrder = day,
		ZIndex = 3,
	}, parent)
	addCorner(tile, 16)
	local stroke = addStroke(tile, THEME.locked, 1, 0.15)
	local backgroundGradient = addGradient(
		tile,
		Color3.fromRGB(33, 36, 48),
		Color3.fromRGB(20, 23, 31),
		90
	)

	local accent = create("Frame", {
		Name = "Accent",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = THEME.locked,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, tile)
	addCorner(accent, 3)

	local dayLabel = create("TextLabel", {
		Name = "DayLabel",
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.new(1, -92, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = day == 7 and "DAY 7  •  FINALE" or "DAY " .. tostring(day),
		TextColor3 = THEME.text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	}, tile)

	local status = create("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 9),
		Size = UDim2.fromOffset(70, 22),
		BackgroundColor3 = THEME.locked,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "LOCKED",
		TextColor3 = Color3.fromRGB(226, 228, 234),
		TextSize = 10,
		ZIndex = 5,
	}, tile)
	addCorner(status, 8)

	local iconBack = create("Frame", {
		Name = "IconBack",
		Position = UDim2.fromOffset(14, 43),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = Color3.fromRGB(14, 16, 23),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, tile)
	addCorner(iconBack, 16)
	local iconBackStroke = addStroke(iconBack, THEME.locked, 1, 0.25)

	local iconImage = create("ImageLabel", {
		Name = "IconImage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		Image = "",
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		ZIndex = 5,
	}, iconBack)

	local iconGlyph = create("TextLabel", {
		Name = "IconGlyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "?",
		TextColor3 = THEME.gold,
		TextSize = 29,
		ZIndex = 5,
	}, iconBack)

	local rewardName = create("TextLabel", {
		Name = "RewardName",
		Position = UDim2.fromOffset(98, 48),
		Size = UDim2.new(1, -110, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Reward",
		TextColor3 = THEME.text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	}, tile)

	local amount = create("TextLabel", {
		Name = "Amount",
		Position = UDim2.fromOffset(98, 74),
		Size = UDim2.new(1, -110, 0, 25),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Text = "",
		TextColor3 = THEME.goldBright,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	}, tile)

	local detail = create("TextLabel", {
		Name = "Detail",
		Position = UDim2.fromOffset(98, 103),
		Size = UDim2.new(1, -110, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Daily reward",
		TextColor3 = THEME.muted,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
	}, tile)

	local claimedMark = create("TextLabel", {
		Name = "ClaimedMark",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -9),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = THEME.green,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "✓",
		TextColor3 = Color3.fromRGB(245, 255, 247),
		TextSize = 15,
		Visible = false,
		ZIndex = 6,
	}, tile)
	addCorner(claimedMark, 13)

	local claimScale = create("UIScale", {
		Name = "ClaimScale",
		Scale = 1,
	}, tile)

	tiles[day] = {
		root = tile,
		stroke = stroke,
		backgroundGradient = backgroundGradient,
		accent = accent,
		dayLabel = dayLabel,
		status = status,
		iconBack = iconBack,
		iconBackStroke = iconBackStroke,
		iconImage = iconImage,
		iconGlyph = iconGlyph,
		rewardName = rewardName,
		amount = amount,
		detail = detail,
		claimedMark = claimedMark,
		claimScale = claimScale,
	}
end

for day = 1, 4 do
	makeTile(day, firstRow)
end
for day = 5, 7 do
	makeTile(day, secondRow)
end

local footer = create("Frame", {
	Name = "Footer",
	Position = UDim2.fromOffset(30, 534),
	Size = UDim2.new(1, -60, 0, 78),
	BackgroundColor3 = THEME.surfaceSoft,
	BorderSizePixel = 0,
	ZIndex = 3,
}, panel)
addCorner(footer, 15)
addStroke(footer, Color3.fromRGB(47, 53, 69), 1, 0.15)

local currentRewardLabel = create("TextLabel", {
	Name = "CurrentRewardLabel",
	Position = UDim2.fromOffset(16, 11),
	Size = UDim2.new(1, -356, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "TODAY'S REWARD: Loading...",
	TextColor3 = THEME.text,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 4,
}, footer)

local resetLabel = create("TextLabel", {
	Name = "ResetLabel",
	Position = UDim2.fromOffset(16, 36),
	Size = UDim2.new(1, -356, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Text = "Checking availability...",
	TextColor3 = THEME.goldBright,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 4,
}, footer)

local feedback = create("TextLabel", {
	Name = "Feedback",
	Position = UDim2.fromOffset(16, 55),
	Size = UDim2.new(1, -356, 0, 16),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = THEME.muted,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 4,
}, footer)

local claimButton = create("TextButton", {
	Name = "Claim",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(322, 50),
	BackgroundColor3 = THEME.buttonDisabled,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBlack,
	Text = "LOADING...",
	TextColor3 = Color3.fromRGB(175, 178, 187),
	TextSize = 15,
	AutoButtonColor = false,
	ZIndex = 4,
}, footer)
addCorner(claimButton, 14)
local claimStroke = addStroke(claimButton, Color3.fromRGB(92, 95, 108), 1, 0.15)
local claimGradient = addGradient(
	claimButton,
	Color3.fromRGB(204, 145, 52),
	Color3.fromRGB(161, 101, 31),
	90
)

local function setFeedback(text, color)
	feedback.Text = tostring(text or "")
	feedback.TextColor3 = color or THEME.muted
end

local function setButtonEnabled(enabled, text)
	claimButton.Active = enabled
	claimButton.Selectable = enabled
	claimButton.Text = text
	claimButton.BackgroundColor3 = enabled and THEME.button or THEME.buttonDisabled
	claimButton.TextColor3 = enabled and Color3.fromRGB(255, 250, 235) or Color3.fromRGB(175, 178, 187)
	claimStroke.Color = enabled and THEME.goldBright or Color3.fromRGB(92, 95, 108)
	claimStroke.Transparency = enabled and 0.1 or 0.35
	claimGradient.Enabled = enabled
end

local function setTileReward(tile, reward)
	local rewardColor = getRewardColor(reward)
	local image = resolveRewardImage(reward)

	tile.rewardName.Text = tostring((reward and reward.DisplayName) or "Reward")
	tile.amount.Text = getRewardAmountText(reward)
	tile.amount.TextColor3 = rewardColor
	tile.iconBackStroke.Color = rewardColor
	tile.iconGlyph.Text = getRewardGlyph(reward)
	tile.iconGlyph.TextColor3 = rewardColor

	if image and image ~= "" then
		tile.iconImage.Image = image
		tile.iconImage.ImageColor3 = Color3.fromRGB(255, 255, 255)
		tile.iconImage.Visible = true
		tile.iconGlyph.Visible = false
	else
		tile.iconImage.Visible = false
		tile.iconGlyph.Visible = true
	end

	if reward and reward.RewardType == "MaterialBundle" then
		tile.detail.Text = "Crafting bundle"
	elseif reward and reward.RewardType == "Ticket" then
		tile.detail.Text = "Weapon banner currency"
	elseif reward and reward.RewardType == "Souls" then
		tile.detail.Text = "Account progression"
	else
		tile.detail.Text = "Daily reward"
	end
end

local function applyTileStyle(tile, status, canClaim, day)
	local isClaimed = status == "ClaimedInCurrentCycle"
	local isCurrent = status == "Current"
	local isLocked = not isClaimed and not isCurrent

	tile.claimedMark.Visible = isClaimed

	if isClaimed then
		tile.root.BackgroundColor3 = THEME.greenSoft
		tile.stroke.Color = THEME.green
		tile.stroke.Thickness = 1
		tile.stroke.Transparency = 0.1
		tile.accent.BackgroundColor3 = THEME.green
		tile.status.BackgroundColor3 = THEME.green
		tile.status.Text = "CLAIMED"
		tile.dayLabel.TextColor3 = Color3.fromRGB(192, 235, 205)
		tile.backgroundGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 58, 42)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 38, 29)),
		})
	elseif isCurrent then
		tile.root.BackgroundColor3 = THEME.goldSoft
		tile.stroke.Color = THEME.gold
		tile.stroke.Thickness = 2
		tile.stroke.Transparency = 0
		tile.accent.BackgroundColor3 = THEME.gold
		tile.status.BackgroundColor3 = canClaim and THEME.gold or Color3.fromRGB(104, 83, 43)
		tile.status.Text = canClaim and "READY" or "NEXT"
		tile.status.TextColor3 = canClaim and Color3.fromRGB(45, 31, 9) or Color3.fromRGB(236, 226, 202)
		tile.dayLabel.TextColor3 = THEME.goldBright
		tile.backgroundGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 53, 24)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 30, 20)),
		})
	else
		tile.root.BackgroundColor3 = THEME.lockedSoft
		tile.stroke.Color = day == 7 and Color3.fromRGB(92, 75, 46) or THEME.locked
		tile.stroke.Thickness = 1
		tile.stroke.Transparency = 0.25
		tile.accent.BackgroundColor3 = day == 7 and Color3.fromRGB(112, 87, 47) or THEME.locked
		tile.status.BackgroundColor3 = THEME.locked
		tile.status.Text = "LOCKED"
		tile.status.TextColor3 = Color3.fromRGB(206, 209, 218)
		tile.dayLabel.TextColor3 = day == 7 and Color3.fromRGB(190, 166, 112) or THEME.muted
		tile.backgroundGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(31, 34, 45)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 23, 31)),
		})
	end

	local transparency = isLocked and 0.38 or 0
	tile.iconBack.BackgroundTransparency = isLocked and 0.15 or 0
	tile.iconImage.ImageTransparency = transparency
	tile.iconGlyph.TextTransparency = transparency
	tile.rewardName.TextTransparency = transparency
	tile.amount.TextTransparency = transparency
	tile.detail.TextTransparency = isLocked and 0.5 or 0
end

local function updateProgress(state)
	for day = 1, 7 do
		local dayStatus = findDayStatus(state, day)
		local status = (dayStatus and dayStatus.Status) or "Locked"
		local canClaim = dayStatus and dayStatus.CanClaim == true
		local segment = progressSegments[day]
		if status == "ClaimedInCurrentCycle" then
			segment.BackgroundColor3 = THEME.green
		elseif status == "Current" then
			segment.BackgroundColor3 = canClaim and THEME.goldBright or THEME.gold
		else
			segment.BackgroundColor3 = THEME.locked
		end
	end
end

local renderState

local function updateCountdown()
	local state = currentState
	if typeof(state) ~= "table" then
		resetLabel.Text = "Checking availability..."
		return
	end

	if state.CanClaim == true then
		resetLabel.Text = "REWARD READY NOW"
		resetLabel.TextColor3 = THEME.goldBright
		return
	end

	local nextClaimDayUTC = tonumber(state.NextClaimDayUTC)
	if not nextClaimDayUTC then
		resetLabel.Text = "Come back tomorrow"
		resetLabel.TextColor3 = THEME.muted
		return
	end

	local remaining = (nextClaimDayUTC * SECONDS_PER_DAY) - os.time()
	if remaining <= 0 then
		resetLabel.Text = "Refreshing reward availability..."
		resetLabel.TextColor3 = THEME.goldBright
		if not resetRefreshPending then
			resetRefreshPending = true
			task.defer(function()
				local ok, payload = pcall(function()
					return GetDailyLoginState:InvokeServer()
				end)
				resetRefreshPending = false
				if ok and typeof(payload) == "table" then
					renderState(payload)
				end
			end)
		end
		return
	end

	resetLabel.Text = "NEXT REWARD IN  " .. formatCountdown(remaining) .. "  •  UTC RESET"
	resetLabel.TextColor3 = THEME.muted
end

renderState = function(state)
	if typeof(state) ~= "table" then
		return
	end

	currentState = state
	local currentDay = math.clamp(math.floor(tonumber(state.CurrentDay) or 1), 1, 7)
	cycleLabel.Text = "CYCLE DAY " .. tostring(currentDay) .. " / 7"
	totalClaimsLabel.Text = "TOTAL CLAIMED: " .. formatInteger(state.TotalClaims)

	for day = 1, 7 do
		local tile = tiles[day]
		local reward = findReward(state, day)
		local dayStatus = findDayStatus(state, day)
		local status = (dayStatus and dayStatus.Status) or "Locked"
		local canClaim = dayStatus and dayStatus.CanClaim == true

		setTileReward(tile, reward)
		applyTileStyle(tile, status, canClaim, day)
	end

	updateProgress(state)
	local currentReward = findReward(state, currentDay)
	local rewardPrefix = state.CanClaim == true and "TODAY'S REWARD:  " or "NEXT REWARD:  "
	currentRewardLabel.Text = rewardPrefix .. getRewardSummary(currentReward)
	updateCountdown()

	if isBusy then
		setButtonEnabled(false, "CLAIMING REWARD...")
	elseif state.CanClaim == true then
		setButtonEnabled(true, "CLAIM DAY " .. tostring(currentDay) .. " REWARD")
	else
		setButtonEnabled(false, "REWARD CLAIMED TODAY")
	end
end

local function fetchState()
	local ok, payload = pcall(function()
		return GetDailyLoginState:InvokeServer()
	end)

	if not ok or typeof(payload) ~= "table" then
		warn("[DailyLoginClient] GetDailyLoginState failed:", payload)
		setFeedback("Daily rewards are currently unavailable.", THEME.danger)
		setButtonEnabled(false, "UNAVAILABLE")
		return nil
	end

	renderState(payload)
	return payload
end

local function playClaimAnimation(day)
	local tile = tiles[day]
	if not tile then
		return
	end

	tile.claimScale.Scale = 1
	local grow = tween(tile.claimScale, 0.14, { Scale = 1.045 }, Enum.EasingStyle.Back)
	grow.Completed:Wait()
	tween(tile.claimScale, 0.16, { Scale = 1 }, Enum.EasingStyle.Quad).Completed:Wait()
end

local function openUI(skipFetch)
	uiTransitionToken += 1
	local token = uiTransitionToken
	gui.Enabled = true
	overlay.BackgroundTransparency = 1
	panel.GroupTransparency = 1
	setFeedback("")

	tween(overlay, 0.16, { BackgroundTransparency = 0.16 })
	local reveal = tween(panel, 0.2, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
	reveal.Completed:Connect(function()
		if token ~= uiTransitionToken then
			return
		end
	end)

	if not skipFetch then
		task.defer(fetchState)
	end
end

local function closeUI()
	if not gui.Enabled then
		return
	end

	uiTransitionToken += 1
	local token = uiTransitionToken
	tween(overlay, 0.12, { BackgroundTransparency = 1 })
	local hide = tween(panel, 0.12, { GroupTransparency = 1 })
	hide.Completed:Connect(function()
		if token == uiTransitionToken then
			gui.Enabled = false
		end
	end)
end

local function autoOpenIfClaimable()
	if hasAutoOpenChecked then
		return
	end

	hasAutoOpenChecked = true
	task.wait(AUTO_OPEN_DELAY_SECONDS)
	if gui.Enabled then
		return
	end

	local state = fetchState()
	if state and state.CanClaim == true then
		openUI(true)
	end
end

local function claim()
	if isBusy or not currentState or currentState.CanClaim ~= true then
		return
	end

	local claimedDay = math.clamp(math.floor(tonumber(currentState.CurrentDay) or 1), 1, 7)
	isBusy = true
	renderState(currentState)
	setFeedback("")

	local ok, result = pcall(function()
		return ClaimDailyLoginReward:InvokeServer()
	end)

	isBusy = false
	if not ok then
		warn("[DailyLoginClient] ClaimDailyLoginReward failed:", result)
		setFeedback("Claim failed. Try again in a moment.", THEME.danger)
		setButtonEnabled(false, "UNAVAILABLE")
		return
	end

	if typeof(result) ~= "table" then
		setFeedback("Claim failed. The server returned an invalid response.", THEME.danger)
		fetchState()
		return
	end

	if result.Success == true then
		setFeedback(tostring(result.Message or "Reward claimed."), THEME.green)
		playClaimAnimation(claimedDay)
	else
		setFeedback(tostring(result.Message or "Unable to claim reward."), THEME.danger)
	end

	if result.State then
		renderState(result.State)
	else
		fetchState()
	end
end

claimButton.Activated:Connect(claim)
closeButton.Activated:Connect(closeUI)
backdropButton.Activated:Connect(closeUI)

claimButton.MouseEnter:Connect(function()
	if claimButton.Active then
		claimGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(224, 166, 67)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(182, 117, 36)),
		})
	end
end)
claimButton.MouseLeave:Connect(function()
	if claimButton.Active then
		claimGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(204, 145, 52)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(161, 101, 31)),
		})
	end
end)

closeButton.MouseEnter:Connect(function()
	tween(closeButton, 0.1, { BackgroundColor3 = Color3.fromRGB(58, 43, 48) })
	closeStroke.Color = Color3.fromRGB(133, 89, 91)
end)
closeButton.MouseLeave:Connect(function()
	tween(closeButton, 0.1, { BackgroundColor3 = Color3.fromRGB(37, 40, 52) })
	closeStroke.Color = Color3.fromRGB(73, 78, 97)
end)

local lastScreenButtonsNonce = nil

local function handleScreenButtonsRequest()
	local nonce = gui:GetAttribute("ScreenButtonsNonce")
	if nonce == nil or nonce == lastScreenButtonsNonce then
		return
	end

	lastScreenButtonsNonce = nonce
	local action = gui:GetAttribute("ScreenButtonsAction")
	if action == "open" then
		openUI()
	elseif action == "close" then
		closeUI()
	elseif action == "toggle" then
		if gui.Enabled then
			closeUI()
		else
			openUI()
		end
	end
end

gui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(handleScreenButtonsRequest)
handleScreenButtonsRequest()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)

task.spawn(function()
	while gui.Parent do
		if gui.Enabled then
			updateCountdown()
		end
		task.wait(1)
	end
end)

task.spawn(autoOpenIfClaimable)
