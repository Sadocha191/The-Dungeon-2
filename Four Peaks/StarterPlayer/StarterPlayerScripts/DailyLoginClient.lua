local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local GetDailyLoginState = remoteFunctions:WaitForChild("GetDailyLoginState")
local ClaimDailyLoginReward = remoteFunctions:WaitForChild("ClaimDailyLoginReward")

local THEME = {
	overlay = Color3.fromRGB(3, 4, 8),
	panel = Color3.fromRGB(19, 16, 24),
	panelSoft = Color3.fromRGB(28, 24, 35),
	text = Color3.fromRGB(244, 235, 214),
	muted = Color3.fromRGB(171, 159, 139),
	gold = Color3.fromRGB(255, 203, 86),
	goldSoft = Color3.fromRGB(71, 52, 18),
	claimed = Color3.fromRGB(40, 115, 72),
	claimedSoft = Color3.fromRGB(22, 51, 36),
	locked = Color3.fromRGB(69, 69, 76),
	lockedSoft = Color3.fromRGB(29, 29, 35),
	danger = Color3.fromRGB(158, 70, 66),
	button = Color3.fromRGB(176, 124, 48),
	buttonDisabled = Color3.fromRGB(70, 68, 72),
}

local currentState = nil
local isBusy = false
local tiles = {}
local hasAutoOpenChecked = false
local AUTO_OPEN_DELAY_SECONDS = 1.25

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props or {}) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function addCorner(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
	}, parent)
end

local function addStroke(parent, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, parent)
end

local function setButtonEnabled(button, enabled, text)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.Selectable = enabled
	button.Text = text
	button.BackgroundColor3 = enabled and THEME.button or THEME.buttonDisabled
	button.TextColor3 = enabled and Color3.fromRGB(255, 248, 225) or Color3.fromRGB(178, 174, 166)
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
gui:SetAttribute("Modal", true)

for _, child in ipairs(gui:GetChildren()) do
	child:Destroy()
end

local overlay = create("Frame", {
	Name = "overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = THEME.overlay,
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
}, gui)

local panel = create("Frame", {
	Name = "panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.86, 0.74),
	BackgroundColor3 = THEME.panel,
	BorderSizePixel = 0,
}, overlay)
addCorner(panel, 10)
addStroke(panel, Color3.fromRGB(129, 97, 44), 2, 0.1)
create("UISizeConstraint", {
	MaxSize = Vector2.new(760, 540),
	MinSize = Vector2.new(320, 360),
}, panel)
create("UIPadding", {
	PaddingTop = UDim.new(0, 18),
	PaddingBottom = UDim.new(0, 18),
	PaddingLeft = UDim.new(0, 18),
	PaddingRight = UDim.new(0, 18),
}, panel)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 12),
}, panel)

local header = create("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 42),
	BackgroundTransparency = 1,
	LayoutOrder = 1,
}, panel)

local title = create("TextLabel", {
	Name = "Title",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.new(1, -52, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "Daily Login Rewards",
	TextColor3 = THEME.text,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, header)

local closeButton = create("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.fromOffset(38, 38),
	BackgroundColor3 = Color3.fromRGB(49, 38, 42),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "X",
	TextColor3 = Color3.fromRGB(255, 235, 220),
	TextSize = 20,
}, header)
addCorner(closeButton, 8)
addStroke(closeButton, Color3.fromRGB(117, 85, 77), 1, 0.25)

local gridHolder = create("Frame", {
	Name = "GridHolder",
	Size = UDim2.new(1, 0, 1, -126),
	BackgroundTransparency = 1,
	LayoutOrder = 2,
}, panel)

local grid = create("UIGridLayout", {
	CellPadding = UDim2.fromOffset(10, 10),
	CellSize = UDim2.new(0.25, -8, 0.5, -8),
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, gridHolder)

local footer = create("Frame", {
	Name = "Footer",
	Size = UDim2.new(1, 0, 0, 72),
	BackgroundTransparency = 1,
	LayoutOrder = 3,
}, panel)

local feedback = create("TextLabel", {
	Name = "Feedback",
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = THEME.muted,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, footer)

local claimButton = create("TextButton", {
	Name = "Claim",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 1),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = THEME.buttonDisabled,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "Loading...",
	TextColor3 = THEME.text,
	TextSize = 18,
}, footer)
addCorner(claimButton, 8)
addStroke(claimButton, Color3.fromRGB(255, 216, 121), 1, 0.35)

local function adjustGrid()
	local width = gridHolder.AbsoluteSize.X
	if width < 520 then
		grid.CellSize = UDim2.new(0.5, -8, 0.25, -8)
	else
		grid.CellSize = UDim2.new(0.25, -8, 0.5, -8)
	end
end

gridHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(adjustGrid)
adjustGrid()

local function makeTile(day)
	local tile = create("Frame", {
		Name = "Day" .. tostring(day),
		BackgroundColor3 = THEME.lockedSoft,
		BorderSizePixel = 0,
		LayoutOrder = day,
	}, gridHolder)
	addCorner(tile, 8)
	local stroke = addStroke(tile, THEME.locked, 1, 0.25)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, tile)

	local dayLabel = create("TextLabel", {
		Name = "DayLabel",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "Day " .. tostring(day),
		TextColor3 = THEME.text,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, tile)

	local icon = create("TextLabel", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(42, 30),
		BackgroundColor3 = Color3.fromRGB(14, 12, 18),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "?",
		TextColor3 = THEME.gold,
		TextSize = 20,
	}, tile)
	addCorner(icon, 8)

	local rewardName = create("TextLabel", {
		Name = "RewardName",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -25),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "Reward",
		TextColor3 = THEME.text,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, tile)

	local amount = create("TextLabel", {
		Name = "Amount",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = THEME.muted,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, tile)

	local status = create("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(70, 18),
		BackgroundColor3 = THEME.locked,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = "Locked",
		TextColor3 = Color3.fromRGB(230, 230, 230),
		TextSize = 11,
	}, tile)
	addCorner(status, 6)

	tiles[day] = {
		root = tile,
		stroke = stroke,
		dayLabel = dayLabel,
		icon = icon,
		rewardName = rewardName,
		amount = amount,
		status = status,
	}
end

for day = 1, 7 do
	makeTile(day)
end

local function getRewardIcon(reward)
	local rewardType = tostring((reward and reward.RewardType) or "")
	if rewardType == "Ticket" then
		return "T"
	elseif rewardType == "Souls" then
		return "S"
	elseif rewardType == "MaterialBundle" then
		return "M"
	elseif rewardType == "Booster" then
		return "XP"
	end
	return "?"
end

local function getRewardAmountText(reward)
	if typeof(reward) ~= "table" then
		return ""
	end

	if reward.RewardType == "MaterialBundle" then
		return "Bundle"
	end

	local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
	if amount <= 0 then
		return ""
	end

	return "x" .. tostring(amount)
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

local function applyTileStyle(tile, status, canClaim)
	if status == "ClaimedInCurrentCycle" then
		tile.root.BackgroundColor3 = THEME.claimedSoft
		tile.stroke.Color = THEME.claimed
		tile.status.BackgroundColor3 = THEME.claimed
		tile.status.Text = "Claimed"
		tile.icon.TextColor3 = Color3.fromRGB(169, 235, 181)
	elseif status == "Current" then
		tile.root.BackgroundColor3 = THEME.goldSoft
		tile.stroke.Color = THEME.gold
		tile.stroke.Thickness = 2
		tile.status.BackgroundColor3 = canClaim and THEME.gold or Color3.fromRGB(100, 86, 54)
		tile.status.Text = canClaim and "Current" or "Today"
		tile.icon.TextColor3 = THEME.gold
	else
		tile.root.BackgroundColor3 = THEME.lockedSoft
		tile.stroke.Color = THEME.locked
		tile.status.BackgroundColor3 = THEME.locked
		tile.status.Text = "Locked"
		tile.icon.TextColor3 = Color3.fromRGB(143, 143, 150)
	end

	if status ~= "Current" then
		tile.stroke.Thickness = 1
	end

	local alpha = status == "Locked" and 0.35 or 0
	tile.dayLabel.TextTransparency = alpha
	tile.icon.TextTransparency = alpha
	tile.rewardName.TextTransparency = alpha
	tile.amount.TextTransparency = alpha
end

local function renderState(state)
	currentState = state
	for day = 1, 7 do
		local tile = tiles[day]
		local reward = findReward(state, day)
		local dayStatus = findDayStatus(state, day)
		local status = (dayStatus and dayStatus.Status) or "Locked"
		local canClaim = dayStatus and dayStatus.CanClaim == true

		tile.icon.Text = getRewardIcon(reward)
		tile.rewardName.Text = tostring((reward and reward.DisplayName) or "Reward")
		tile.amount.Text = getRewardAmountText(reward)
		applyTileStyle(tile, status, canClaim)
	end

	if isBusy then
		setButtonEnabled(claimButton, false, "Claiming...")
	elseif state and state.CanClaim == true then
		setButtonEnabled(claimButton, true, "Claim")
	else
		setButtonEnabled(claimButton, false, "Come back tomorrow")
	end
end

local function fetchState()
	local ok, payload = pcall(function()
		return GetDailyLoginState:InvokeServer()
	end)

	if not ok then
		warn("[DailyLoginClient] GetDailyLoginState failed:", payload)
		feedback.Text = "Daily rewards are unavailable."
		setButtonEnabled(claimButton, false, "Unavailable")
		return nil
	end

	renderState(payload)
	return payload
end

local function openUI()
	gui.Enabled = true
	feedback.Text = ""
	fetchState()
end

local function closeUI()
	gui.Enabled = false
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
		gui.Enabled = true
		feedback.Text = ""
	end
end

local function claim()
	if isBusy or not currentState or currentState.CanClaim ~= true then
		return
	end

	isBusy = true
	renderState(currentState)
	feedback.Text = ""

	local ok, result = pcall(function()
		return ClaimDailyLoginReward:InvokeServer()
	end)

	isBusy = false

	if not ok then
		warn("[DailyLoginClient] ClaimDailyLoginReward failed:", result)
		feedback.Text = "Claim failed."
		setButtonEnabled(claimButton, false, "Unavailable")
		return
	end

	if typeof(result) ~= "table" then
		feedback.Text = "Claim failed."
		fetchState()
		return
	end

	feedback.Text = tostring(result.Message or (result.Success and "Claimed." or "Unable to claim."))
	if result.State then
		renderState(result.State)
	else
		fetchState()
	end
end

claimButton.Activated:Connect(claim)
closeButton.Activated:Connect(closeUI)

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

task.spawn(autoOpenIfClaimable)
