local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local GetEventsState = remoteFunctions:WaitForChild("GetEventsState")
local ClaimEventReward = remoteFunctions:WaitForChild("ClaimEventReward")
local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts")
local EventUtil = require(moduleFolder:WaitForChild("EventUtil"))

local COLORS = {
	bg = Color3.fromRGB(10, 8, 12),
	panel = Color3.fromRGB(22, 18, 25),
	panel2 = Color3.fromRGB(31, 25, 34),
	stroke = Color3.fromRGB(120, 86, 45),
	gold = Color3.fromRGB(224, 177, 86),
	gold2 = Color3.fromRGB(146, 98, 38),
	text = Color3.fromRGB(244, 232, 210),
	muted = Color3.fromRGB(166, 151, 134),
	green = Color3.fromRGB(70, 166, 94),
	red = Color3.fromRGB(184, 72, 72),
	gray = Color3.fromRGB(87, 84, 88),
}

local gui = playerGui:FindFirstChild("EventsGui")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "EventsGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 62
	gui.Parent = playerGui
end

gui.Enabled = false
gui:SetAttribute("Modal", true)

for _, child in ipairs(gui:GetChildren()) do
	child:Destroy()
end

local state = nil
local selectedEventId = nil
local isFetching = false
local isClaiming = false
local serverNowAtSync = 0
local localClockAtSync = os.clock()
local timerBindings = {}

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

local function addCorner(inst, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, inst)
end

local function addStroke(inst, color, thickness, transparency)
	create("UIStroke", {
		Color = color or COLORS.stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, inst)
end

local function addPadding(inst, left, right, top, bottom)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, left or 0),
		PaddingRight = UDim.new(0, right or 0),
		PaddingTop = UDim.new(0, top or 0),
		PaddingBottom = UDim.new(0, bottom or 0),
	}, inst)
end

local function clearDynamic(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local overlay = create("Frame", {
	Name = "Overlay",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, gui)

local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.84, 0.78),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
}, overlay)
addCorner(panel, 8)
addStroke(panel, COLORS.stroke, 2, 0.05)
create("UISizeConstraint", {
	MinSize = Vector2.new(720, 430),
	MaxSize = Vector2.new(1080, 660),
}, panel)

create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 24, 0, 15),
	Size = UDim2.new(1, -76, 0, 36),
	Font = Enum.Font.GothamBold,
	Text = "Limited Events",
	TextColor3 = COLORS.gold,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local closeButton = create("TextButton", {
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(54, 35, 38),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "X",
	TextColor3 = COLORS.text,
	TextSize = 18,
	AutoButtonColor = true,
}, panel)
addCorner(closeButton, 6)
addStroke(closeButton, Color3.fromRGB(134, 83, 78), 1, 0.15)

local body = create("Frame", {
	Name = "Body",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 20, 0, 64),
	Size = UDim2.new(1, -40, 1, -88),
}, panel)

local left = create("Frame", {
	Name = "EventTabs",
	BackgroundColor3 = COLORS.panel2,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.new(0, 230, 1, 0),
}, body)
addCorner(left, 7)
addStroke(left, Color3.fromRGB(83, 68, 56), 1, 0.2)
addPadding(left, 10, 10, 10, 10)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, left)

local right = create("Frame", {
	Name = "Details",
	BackgroundColor3 = Color3.fromRGB(17, 15, 20),
	BorderSizePixel = 0,
	Position = UDim2.new(0, 244, 0, 0),
	Size = UDim2.new(1, -244, 1, 0),
}, body)
addCorner(right, 7)
addStroke(right, Color3.fromRGB(83, 68, 56), 1, 0.18)

local content = create("ScrollingFrame", {
	Name = "Content",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromScale(1, 1),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.gold2,
	CanvasSize = UDim2.fromOffset(0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, right)
addPadding(content, 18, 18, 18, 18)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 12),
}, content)

local feedback = create("TextLabel", {
	Name = "Feedback",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 24, 1, -8),
	Size = UDim2.new(1, -48, 0, 22),
	Font = Enum.Font.Gotham,
	Text = "",
	TextColor3 = COLORS.muted,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local function setFeedback(text, isError)
	feedback.Text = tostring(text or "")
	feedback.TextColor3 = isError and COLORS.red or COLORS.muted
end

local function getEvents()
	if typeof(state) ~= "table" or typeof(state.Events) ~= "table" then
		return {}
	end
	return state.Events
end

local function getSelectedEvent()
	for _, eventData in ipairs(getEvents()) do
		if eventData.Id == selectedEventId then
			return eventData
		end
	end
	return getEvents()[1]
end

local function estimateNow()
	if serverNowAtSync <= 0 then
		return os.time()
	end
	return serverNowAtSync + math.max(0, os.clock() - localClockAtSync)
end

local function timerText(eventData)
	if typeof(eventData) ~= "table" then
		return "Ended"
	end
	if eventData.Status == "Ended" then
		return "Ended"
	end
	local target = tonumber(eventData.TimeTargetUnix) or 0
	return EventUtil.FormatTimeRemaining(target - estimateNow())
end

local function formatReward(reward)
	if typeof(reward) ~= "table" then
		return "Reward"
	end
	local rewardType = tostring(reward.Type or "")
	local amount = math.floor(tonumber(reward.Amount) or 0)
	if rewardType == "Ticket" then
		return ("Ticket x%d"):format(amount)
	elseif rewardType == "WP" then
		return ("WP x%d"):format(amount)
	elseif rewardType == "Souls" then
		return ("Souls x%d"):format(amount)
	elseif rewardType == "Material" then
		return ("%s x%d"):format(tostring(reward.MaterialId or reward.Id or "Material"), amount)
	elseif rewardType == "MaterialBundle" then
		return tostring(reward.DisplayName or "Material Bundle")
	elseif rewardType == "Title" or rewardType == "CosmeticPlaceholder" or rewardType == "Booster" then
		return tostring(reward.DisplayName or reward.BackendId or rewardType)
	end
	return rewardType ~= "" and rewardType or "Reward"
end

local function formatRewards(rewards)
	local parts = {}
	for _, reward in ipairs(rewards or {}) do
		table.insert(parts, formatReward(reward))
	end
	if #parts == 0 then
		return "No reward"
	end
	return table.concat(parts, " + ")
end

local function styleButton(button, enabled, claimed)
	button.Active = enabled == true
	button.AutoButtonColor = enabled == true
	if claimed then
		button.BackgroundColor3 = COLORS.green
		button.TextColor3 = Color3.fromRGB(235, 255, 235)
	elseif enabled then
		button.BackgroundColor3 = COLORS.gold2
		button.TextColor3 = Color3.fromRGB(255, 244, 218)
	else
		button.BackgroundColor3 = COLORS.gray
		button.TextColor3 = Color3.fromRGB(205, 198, 190)
	end
end

local function addProgressBar(parent, percent)
	local back = create("Frame", {
		Name = "ProgressBack",
		BackgroundColor3 = Color3.fromRGB(45, 41, 48),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
	}, parent)
	addCorner(back, 4)
	local fill = create("Frame", {
		Name = "ProgressFill",
		BackgroundColor3 = COLORS.gold,
		BorderSizePixel = 0,
		Size = UDim2.new(math.clamp(tonumber(percent) or 0, 0, 1), 0, 1, 0),
	}, back)
	addCorner(fill, 4)
	return back
end

local render

local function claim(claimType, targetId)
	local selected = getSelectedEvent()
	if isClaiming or not selected then
		return
	end
	isClaiming = true
	setFeedback("Claiming...")

	local ok, response = pcall(function()
		return ClaimEventReward:InvokeServer(selected.Id, claimType, targetId)
	end)

	isClaiming = false
	if not ok then
		warn("[EventsClient] ClaimEventReward failed:", response)
		setFeedback("Claim failed.", true)
		return
	end
	if typeof(response) ~= "table" then
		setFeedback("Invalid server response.", true)
		return
	end

	if response.Success == true then
		setFeedback(response.Message or "Claimed.")
	else
		setFeedback(response.Message or "Reward is not ready.", true)
	end
	if typeof(response.State) == "table" then
		state = response.State
		serverNowAtSync = tonumber(state.ServerNowUnix) or serverNowAtSync
		localClockAtSync = os.clock()
	end

	task.defer(function()
		if gui.Enabled then
			render()
		end
	end)
end

render = function()
	timerBindings = {}
	clearDynamic(left)
	clearDynamic(content)

	local events = getEvents()
	if #events == 0 then
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 80),
			Font = Enum.Font.GothamBold,
			Text = "No events available",
			TextColor3 = COLORS.muted,
			TextSize = 18,
			TextWrapped = true,
		}, content)
		return
	end

	if not selectedEventId then
		selectedEventId = events[1].Id
	end

	for index, eventData in ipairs(events) do
		local selected = eventData.Id == selectedEventId
		local tab = create("TextButton", {
			Name = "EventTab_" .. tostring(eventData.Id),
			BackgroundColor3 = selected and Color3.fromRGB(68, 48, 31) or Color3.fromRGB(30, 27, 33),
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 70),
			Font = Enum.Font.GothamBold,
			Text = "",
			TextColor3 = COLORS.text,
			TextSize = 15,
			AutoButtonColor = true,
		}, left)
		addCorner(tab, 6)
		addStroke(tab, selected and COLORS.gold or Color3.fromRGB(73, 62, 54), selected and 2 or 1, 0.1)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 7),
			Size = UDim2.new(1, -20, 0, 22),
			Font = Enum.Font.GothamBold,
			Text = tostring(eventData.DisplayName or eventData.Id or "Event"),
			TextColor3 = eventData.Status == "Ended" and COLORS.muted or COLORS.text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, tab)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 32),
			Size = UDim2.new(1, -20, 0, 18),
			Font = Enum.Font.Gotham,
			Text = tostring(eventData.Status or "Ended"),
			TextColor3 = eventData.Status == "Active" and COLORS.green or (eventData.Status == "ComingSoon" and COLORS.gold or COLORS.muted),
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, tab)

		local timeLabel = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, 0, 49),
			Size = UDim2.new(1, -20, 0, 16),
			Font = Enum.Font.Gotham,
			Text = timerText(eventData),
			TextColor3 = COLORS.muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, tab)
		table.insert(timerBindings, { label = timeLabel, eventData = eventData })

		tab.Activated:Connect(function()
			selectedEventId = eventData.Id
			render()
		end)
	end

	local eventData = getSelectedEvent()
	if not eventData then
		return
	end

	local header = create("Frame", {
		Name = "Header",
		BackgroundColor3 = Color3.fromRGB(36, 25, 29),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 132),
	}, content)
	addCorner(header, 7)
	addStroke(header, COLORS.stroke, 1, 0.12)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(1, -32, 0, 28),
		Font = Enum.Font.GothamBold,
		Text = tostring(eventData.DisplayName or eventData.Id or "Event"),
		TextColor3 = COLORS.gold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 0, 43),
		Size = UDim2.new(1, -32, 0, 38),
		Font = Enum.Font.Gotham,
		Text = tostring(eventData.Description or ""),
		TextColor3 = COLORS.text,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, header)

	local timer = create("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(18, 15, 18),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 16, 1, -40),
		Size = UDim2.new(0, 190, 0, 28),
		Font = Enum.Font.GothamBold,
		Text = timerText(eventData),
		TextColor3 = COLORS.gold,
		TextSize = 17,
	}, header)
	addCorner(timer, 5)
	addStroke(timer, Color3.fromRGB(91, 70, 46), 1, 0.15)
	table.insert(timerBindings, { label = timer, eventData = eventData })

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 222, 1, -39),
		Size = UDim2.new(1, -238, 0, 26),
		Font = Enum.Font.GothamBold,
		Text = tostring(eventData.Status or "Ended"),
		TextColor3 = eventData.Status == "Active" and COLORS.green or (eventData.Status == "ComingSoon" and COLORS.gold or COLORS.muted),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		Text = "Tasks",
		TextColor3 = COLORS.text,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)

	for index, taskData in ipairs(eventData.Tasks or {}) do
		local row = create("Frame", {
			Name = "Task_" .. tostring(taskData.Id),
			BackgroundColor3 = Color3.fromRGB(28, 25, 31),
			BorderSizePixel = 0,
			LayoutOrder = 20 + index,
			Size = UDim2.new(1, 0, 0, 100),
		}, content)
		addCorner(row, 6)
		addStroke(row, Color3.fromRGB(70, 60, 55), 1, 0.2)
		addPadding(row, 12, 12, 10, 10)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -124, 0, 20),
			Font = Enum.Font.GothamBold,
			Text = tostring(taskData.DisplayName or taskData.Id or "Task"),
			TextColor3 = COLORS.text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 22),
			Size = UDim2.new(1, -124, 0, 32),
			Font = Enum.Font.Gotham,
			Text = tostring(taskData.Description or ""),
			TextColor3 = COLORS.muted,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, row)

		local progress = taskData.Progress or {}
		local current = math.floor(tonumber(progress.Current) or 0)
		local required = math.max(1, math.floor(tonumber(progress.Required) or taskData.RequiredAmount or 1))
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 58),
			Size = UDim2.new(1, -124, 0, 16),
			Font = Enum.Font.Gotham,
			Text = ("%d / %d"):format(current, required),
			TextColor3 = COLORS.gold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local barHolder = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 78),
			Size = UDim2.new(1, -124, 0, 8),
		}, row)
		addProgressBar(barHolder, progress.Percent or (current / required))

		create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -112, 0, 60),
			Size = UDim2.new(0, 108, 0, 28),
			Font = Enum.Font.Gotham,
			Text = formatRewards(taskData.Rewards),
			TextColor3 = COLORS.gold,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)

		local button = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(96, 34),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = taskData.Claimed and "Claimed" or "Claim",
			TextSize = 13,
		}, row)
		addCorner(button, 5)
		styleButton(button, taskData.Claimable == true and not isClaiming, taskData.Claimed == true)
		button.Activated:Connect(function()
			if taskData.Claimable == true and not isClaiming then
				claim("Task", taskData.Id)
			end
		end)
	end

	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		Text = "Milestones",
		TextColor3 = COLORS.text,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)

	for index, milestoneData in ipairs(eventData.Milestones or {}) do
		local row = create("Frame", {
			Name = "Milestone_" .. tostring(milestoneData.Id),
			BackgroundColor3 = Color3.fromRGB(26, 29, 32),
			BorderSizePixel = 0,
			LayoutOrder = 100 + index,
			Size = UDim2.new(1, 0, 0, 76),
		}, content)
		addCorner(row, 6)
		addStroke(row, Color3.fromRGB(68, 73, 60), 1, 0.2)
		addPadding(row, 12, 12, 10, 10)

		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -124, 0, 20),
			Font = Enum.Font.GothamBold,
			Text = tostring(milestoneData.DisplayName or milestoneData.Id or "Milestone"),
			TextColor3 = COLORS.text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, -124, 0, 20),
			Font = Enum.Font.Gotham,
			Text = ("Complete %d/%d tasks"):format(tonumber(milestoneData.CompletedTasks) or 0, tonumber(milestoneData.RequiredCompletedTasks) or 0),
			TextColor3 = COLORS.muted,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 48),
			Size = UDim2.new(1, -124, 0, 18),
			Font = Enum.Font.Gotham,
			Text = formatRewards(milestoneData.Rewards),
			TextColor3 = COLORS.gold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		local button = create("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(96, 34),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBold,
			Text = milestoneData.Claimed and "Claimed" or "Claim",
			TextSize = 13,
		}, row)
		addCorner(button, 5)
		styleButton(button, milestoneData.Claimable == true and not isClaiming, milestoneData.Claimed == true)
		button.Activated:Connect(function()
			if milestoneData.Claimable == true and not isClaiming then
				claim("Milestone", milestoneData.Id)
			end
		end)
	end

	local final = create("Frame", {
		Name = "FinalReward",
		BackgroundColor3 = Color3.fromRGB(42, 30, 24),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 88),
	}, content)
	addCorner(final, 7)
	addStroke(final, COLORS.gold, 1, 0.1)
	addPadding(final, 12, 12, 10, 10)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -150, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = "Final Reward",
		TextColor3 = COLORS.gold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, final)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, -150, 0, 36),
		Font = Enum.Font.Gotham,
		Text = formatRewards(eventData.FinalRewards),
		TextColor3 = COLORS.text,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, final)

	local finalButton = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(132, 38),
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		Text = eventData.FinalClaimed and "Claimed" or "Claim Final",
		TextSize = 13,
	}, final)
	addCorner(finalButton, 5)
	styleButton(finalButton, eventData.FinalClaimable == true and not isClaiming, eventData.FinalClaimed == true)
	finalButton.Activated:Connect(function()
		if eventData.FinalClaimable == true and not isClaiming then
			claim("Final", "Final")
		end
	end)
end

local function updateTimers()
	for _, binding in ipairs(timerBindings) do
		if binding.label and binding.label.Parent then
			binding.label.Text = timerText(binding.eventData)
		end
	end
end

local function fetchState()
	if isFetching then
		return
	end
	isFetching = true
	setFeedback("Loading events...")
	local ok, response = pcall(function()
		return GetEventsState:InvokeServer()
	end)
	isFetching = false

	if not ok then
		warn("[EventsClient] GetEventsState failed:", response)
		setFeedback("Could not load events.", true)
		return
	end
	if typeof(response) ~= "table" then
		setFeedback("Invalid server response.", true)
		return
	end

	state = response
	serverNowAtSync = tonumber(response.ServerNowUnix) or os.time()
	localClockAtSync = os.clock()

	local selectedStillExists = false
	for _, eventData in ipairs(getEvents()) do
		if eventData.Id == selectedEventId then
			selectedStillExists = true
			break
		end
	end
	if not selectedStillExists then
		selectedEventId = getEvents()[1] and getEvents()[1].Id or nil
	end

	setFeedback(response.Success == false and (response.Message or "Events unavailable.") or "")
	render()
end

local function openUI()
	gui.Enabled = true
	task.spawn(fetchState)
end

local function closeUI()
	gui.Enabled = false
end

closeButton.Activated:Connect(closeUI)
overlay.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local pos = input.Position
		local abs = panel.AbsolutePosition
		local size = panel.AbsoluteSize
		if pos.X < abs.X or pos.X > abs.X + size.X or pos.Y < abs.Y or pos.Y > abs.Y + size.Y then
			closeUI()
		end
	end
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
			updateTimers()
		end
		task.wait(1)
	end
end)
