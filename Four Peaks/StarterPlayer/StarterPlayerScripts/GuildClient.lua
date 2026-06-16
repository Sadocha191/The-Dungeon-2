local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
local GetGuildState = remoteFunctions:WaitForChild("GetGuildState")
local SearchGuilds = remoteFunctions:WaitForChild("SearchGuilds")
local GuildAction = remoteFunctions:WaitForChild("GuildAction")
local GuildUpdated = remoteEvents and remoteEvents:WaitForChild("GuildUpdated", 5)

local COLORS = {
	bg = Color3.fromRGB(11, 13, 16),
	overlay = Color3.fromRGB(0, 0, 0),
	panel = Color3.fromRGB(26, 23, 21),
	panel2 = Color3.fromRGB(35, 31, 27),
	panel3 = Color3.fromRGB(20, 22, 24),
	stroke = Color3.fromRGB(124, 93, 52),
	gold = Color3.fromRGB(228, 180, 92),
	green = Color3.fromRGB(80, 168, 104),
	red = Color3.fromRGB(188, 70, 72),
	text = Color3.fromRGB(240, 232, 213),
	muted = Color3.fromRGB(166, 153, 134),
	blue = Color3.fromRGB(75, 127, 182),
}

local TAB_ORDER = {
	{ id = "Description", label = "Opis" },
	{ id = "Requests", label = "Requests" },
	{ id = "Invites", label = "Invites" },
	{ id = "Tasks", label = "Pod zadania" },
	{ id = "Donate", label = "Donate" },
	{ id = "Dojo", label = "Dojo" },
	{ id = "Treasury", label = "Skarbiec" },
	{ id = "Economy", label = "Farmy, kopalnia i łowiska" },
	{ id = "Hall", label = "Sala chwały" },
}

local gui = playerGui:FindFirstChild("GuildGui")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "GuildGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 63
	gui.Parent = playerGui
end

gui.Enabled = false
gui:SetAttribute("Modal", true)

for _, child in ipairs(gui:GetChildren()) do
	child:Destroy()
end

local state = nil
local selectedTab = "Description"
local selectedDonationResource = "Silver"
local searchResults = {}
local lastSearchQuery = nil
local busy = false
local pendingStateRefresh = false

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
	BackgroundColor3 = COLORS.overlay,
	BackgroundTransparency = 0.38,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
}, gui)

local panel = create("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.86, 0.8),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
}, overlay)
addCorner(panel, 8)
addStroke(panel, COLORS.stroke, 2, 0.05)
create("UISizeConstraint", {
	MinSize = Vector2.new(740, 440),
	MaxSize = Vector2.new(1120, 700),
}, panel)

create("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 24, 0, 15),
	Size = UDim2.new(1, -88, 0, 34),
	Font = Enum.Font.GothamBold,
	Text = "Guild",
	TextColor3 = COLORS.gold,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local closeButton = create("TextButton", {
	Name = "CloseButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(58, 37, 38),
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	Text = "X",
	TextColor3 = COLORS.text,
	TextSize = 18,
}, panel)
addCorner(closeButton, 6)
addStroke(closeButton, Color3.fromRGB(140, 78, 76), 1, 0.15)

local body = create("Frame", {
	Name = "Body",
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 20, 0, 62),
	Size = UDim2.new(1, -40, 1, -92),
}, panel)

local left = create("Frame", {
	Name = "Tabs",
	BackgroundColor3 = COLORS.panel2,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.new(0, 230, 1, 0),
}, body)
addCorner(left, 7)
addStroke(left, Color3.fromRGB(80, 68, 55), 1, 0.18)
addPadding(left, 10, 10, 10, 10)
create("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 7),
}, left)

local right = create("Frame", {
	Name = "Details",
	BackgroundColor3 = COLORS.panel3,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 244, 0, 0),
	Size = UDim2.new(1, -244, 1, 0),
}, body)
addCorner(right, 7)
addStroke(right, Color3.fromRGB(80, 68, 55), 1, 0.18)

local content = create("ScrollingFrame", {
	Name = "Content",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromScale(1, 1),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = COLORS.gold,
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

local function setFeedback(message, isError)
	feedback.Text = tostring(message or "")
	feedback.TextColor3 = isError and COLORS.red or COLORS.muted
end

local function getGuild()
	return typeof(state) == "table" and state.Guild or nil
end

local function getMembership()
	return typeof(state) == "table" and state.Membership or nil
end

local function getConfig()
	return typeof(state) == "table" and state.Config or {}
end

local function canManageJoin()
	return typeof(state) == "table" and state.CanManageJoin == true
end

local function formatAmount(value)
	local n = math.floor(tonumber(value) or 0)
	local text = tostring(n)
	local left, num, right = string.match(text, "^([^%d]*%d)(%d*)(.-)$")
	if not left then
		return text
	end
	return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local render
local fetchState

local function queueOpenStateRefresh()
	if not gui.Enabled then
		return
	end
	if busy then
		pendingStateRefresh = true
		return
	end
	task.spawn(function()
		fetchState({ silent = true })
	end)
end

local function runPendingStateRefresh()
	if not pendingStateRefresh then
		return
	end
	pendingStateRefresh = false
	task.defer(queueOpenStateRefresh)
end

local function invokeAction(action, payload)
	if busy then
		return nil
	end
	busy = true
	setFeedback("Working...")
	local ok, response = pcall(function()
		return GuildAction:InvokeServer(action, payload or {})
	end)
	busy = false
	if not ok then
		warn("[GuildClient] GuildAction failed:", response)
		setFeedback("Guild action failed.", true)
		runPendingStateRefresh()
		return nil
	end
	if typeof(response) ~= "table" then
		setFeedback("Invalid server response.", true)
		runPendingStateRefresh()
		return nil
	end
	state = response
	if not state.Guild then
		selectedTab = "Description"
	end
	setFeedback(response.Message or "", response.Success == false)
	render()
	runPendingStateRefresh()
	return response
end

fetchState = function(options)
	if busy then
		pendingStateRefresh = true
		return
	end
	local silent = typeof(options) == "table" and options.silent == true
	busy = true
	if not silent then
		setFeedback("Loading guild...")
	end
	local ok, response = pcall(function()
		return GetGuildState:InvokeServer()
	end)
	busy = false
	if not ok then
		warn("[GuildClient] GetGuildState failed:", response)
		if not silent then
			setFeedback("Could not load guild.", true)
		end
		runPendingStateRefresh()
		return
	end
	if typeof(response) ~= "table" then
		if not silent then
			setFeedback("Invalid server response.", true)
		end
		runPendingStateRefresh()
		return
	end
	state = response
	if not silent or response.Success == false then
		setFeedback(response.Message or "", response.Success == false)
	end
	render()
	runPendingStateRefresh()
end

local function searchGuilds(query)
	if busy then
		return
	end
	lastSearchQuery = query or ""
	busy = true
	setFeedback("Searching guilds...")
	local ok, response = pcall(function()
		return SearchGuilds:InvokeServer(query or "")
	end)
	busy = false
	if not ok then
		warn("[GuildClient] SearchGuilds failed:", response)
		setFeedback("Guild search failed.", true)
		return
	end
	if typeof(response) ~= "table" then
		setFeedback("Invalid search response.", true)
		return
	end
	state = response
	searchResults = typeof(response.SearchResults) == "table" and response.SearchResults or {}
	setFeedback(response.Message or "")
	render()
end

local function section(title)
	local holder = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 29, 30),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 46),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, content)
	addCorner(holder, 6)
	addStroke(holder, Color3.fromRGB(75, 66, 56), 1, 0.2)
	addPadding(holder, 14, 14, 12, 12)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, holder)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		Text = tostring(title or ""),
		TextColor3 = COLORS.gold,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
	return holder
end

local function text(parent, value, size, color, bold)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, size and size + 8 or 24),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		Text = tostring(value or ""),
		TextColor3 = color or COLORS.text,
		TextSize = size or 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, parent)
end

local function button(parent, label, color)
	local btn = create("TextButton", {
		BackgroundColor3 = color or Color3.fromRGB(82, 61, 36),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 150, 0, 34),
		Font = Enum.Font.GothamBold,
		Text = tostring(label or "Button"),
		TextColor3 = COLORS.text,
		TextSize = 13,
		TextWrapped = true,
		AutoButtonColor = true,
	}, parent)
	addCorner(btn, 5)
	addStroke(btn, Color3.fromRGB(120, 92, 58), 1, 0.25)
	return btn
end

local function inputBox(parent, placeholder, defaultText)
	local box = create("TextBox", {
		BackgroundColor3 = Color3.fromRGB(18, 19, 21),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 36),
		ClearTextOnFocus = false,
		Font = Enum.Font.Gotham,
		PlaceholderText = tostring(placeholder or ""),
		Text = tostring(defaultText or ""),
		TextColor3 = COLORS.text,
		PlaceholderColor3 = COLORS.muted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	addCorner(box, 5)
	addStroke(box, Color3.fromRGB(77, 67, 56), 1, 0.25)
	addPadding(box, 10, 10, 0, 0)
	return box
end

local function row(parent, height)
	local frame = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 38),
	}, parent)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, frame)
	return frame
end

local function progressBar(parent, current, target)
	local maxValue = math.max(1, tonumber(target) or 1)
	local value = math.clamp((tonumber(current) or 0) / maxValue, 0, 1)
	local back = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(45, 42, 39),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 8),
	}, parent)
	addCorner(back, 4)
	local fill = create("Frame", {
		BackgroundColor3 = COLORS.gold,
		BorderSizePixel = 0,
		Size = UDim2.new(value, 0, 1, 0),
	}, back)
	addCorner(fill, 4)
	return back
end

local function renderTabs()
	clearDynamic(left)
	local guild = getGuild()
	local completed = guild and tonumber(guild.CompletedTasks) or 0
	local total = guild and tonumber(guild.TotalTasks) or 5
	for index, tab in ipairs(TAB_ORDER) do
		local isSelected = selectedTab == tab.id
		local label = tab.label
		if tab.id == "Tasks" then
			label = ("Pod zadania %d/%d"):format(completed, total)
		end
		local tabButton = create("TextButton", {
			Name = "Tab_" .. tab.id,
			BackgroundColor3 = isSelected and Color3.fromRGB(75, 54, 32) or Color3.fromRGB(28, 27, 29),
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 48),
			Font = Enum.Font.GothamBold,
			Text = label,
			TextColor3 = isSelected and COLORS.gold or COLORS.text,
			TextSize = 14,
			TextWrapped = true,
			AutoButtonColor = true,
		}, left)
		addCorner(tabButton, 5)
		addStroke(tabButton, isSelected and COLORS.gold or Color3.fromRGB(70, 62, 54), isSelected and 2 or 1, 0.15)
		tabButton.Activated:Connect(function()
			selectedTab = tab.id
			render()
		end)
	end
end

local function renderNoGuild()
	local createSection = section("Create guild")
	local nameBox = inputBox(createSection, "Guild name", "")
	local createButton = button(createSection, "Create Guild", COLORS.green)
	createButton.Activated:Connect(function()
		invokeAction("CreateGuild", { name = nameBox.Text })
	end)

	local myInvites = typeof(state) == "table" and typeof(state.Invites) == "table" and state.Invites or {}
	if #myInvites > 0 then
		local inviteSection = section("Invites")
		text(inviteSection, ("You have %d pending invite(s). Open the Invites tab to respond."):format(#myInvites), 14, COLORS.gold, true)
	end

	local searchSection = section("Find guild")
	local queryBox = inputBox(searchSection, "Search by name", "")
	local searchRow = row(searchSection, 36)
	local searchButton = button(searchRow, "Search", COLORS.blue)
	searchButton.Activated:Connect(function()
		searchGuilds(queryBox.Text)
	end)

	if #searchResults > 0 then
		for _, result in ipairs(searchResults) do
			local privacy = tostring(result.Privacy or "Public")
			local requestPending = result.RequestPending == true
			local invitePending = result.InvitePending == true
			local resultRow = create("Frame", {
				BackgroundColor3 = Color3.fromRGB(24, 25, 27),
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 66),
			}, searchSection)
			addCorner(resultRow, 5)
			addStroke(resultRow, Color3.fromRGB(68, 61, 54), 1, 0.25)
			create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 8),
				Size = UDim2.new(1, -150, 0, 22),
				Font = Enum.Font.GothamBold,
				Text = tostring(result.Name or "Guild"),
				TextColor3 = COLORS.text,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, resultRow)
			create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 31),
				Size = UDim2.new(1, -156, 0, 30),
				Font = Enum.Font.Gotham,
				Text = ("%s  Level %d  Members %d/%d"):format(privacy, tonumber(result.Level) or 1, tonumber(result.MemberCount) or 0, tonumber(result.MaxMembers) or 50),
				TextColor3 = privacy == "Private" and COLORS.gold or COLORS.muted,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, resultRow)
			local label = privacy == "Private" and "Request to Join" or "Join"
			local active = true
			if requestPending then
				label = "Requested"
				active = false
			elseif invitePending then
				label = "Invited"
				active = false
			end
			local join = button(resultRow, label, active and COLORS.green or Color3.fromRGB(75, 75, 75))
			join.AnchorPoint = Vector2.new(1, 0.5)
			join.Position = UDim2.new(1, -12, 0.5, 0)
			join.Size = UDim2.fromOffset(118, 34)
			join.Active = active
			join.AutoButtonColor = active
			join.Activated:Connect(function()
				if join.Active then
					invokeAction(privacy == "Private" and "RequestJoin" or "JoinGuild", { guildId = result.GuildId })
				end
			end)
		end
	else
		text(searchSection, "No search results yet.", 13, COLORS.muted)
	end
end

local function renderDescription()
	local guild = getGuild()
	if not guild then
		renderNoGuild()
		return
	end

	local membership = getMembership() or {}
	local header = section(tostring(guild.Name or "Guild"))
	local privacy = tostring(guild.Privacy or "Public")
	text(header, ("Level %d  XP %s  Members %d/%d  %s"):format(tonumber(guild.Level) or 1, formatAmount(guild.XP), tonumber(guild.MemberCount) or 0, tonumber(guild.MaxMembers) or 50, privacy), 15, COLORS.text, true)
	text(header, tostring(guild.Description or "No description."), 14, COLORS.muted)
	text(header, "Your role: " .. tostring(membership.Role or "Member"), 14, COLORS.gold)
	local actions = row(header, 38)
	local castle = button(actions, "Enter Castle", COLORS.blue)
	castle.Activated:Connect(function()
		invokeAction("TeleportToCastle")
	end)
	local leave = button(actions, "Leave Guild", COLORS.red)
	leave.Activated:Connect(function()
		invokeAction("LeaveGuild")
	end)

	if canManageJoin() then
		local joinControls = section("Join controls")
		text(joinControls, "Guild privacy: " .. privacy, 14, privacy == "Private" and COLORS.gold or COLORS.green, true)
		local toggle = button(joinControls, privacy == "Private" and "Make Public" or "Make Private", COLORS.blue)
		toggle.Activated:Connect(function()
			invokeAction("SetPrivacy", { privacy = privacy == "Private" and "Public" or "Private" })
		end)
	end

	if state and state.CanManage == true then
		local manage = section("Owner actions")
		local descBox = inputBox(manage, "Description", tostring(guild.Description or ""))
		descBox.Size = UDim2.new(1, 0, 0, 72)
		descBox.TextWrapped = true
		descBox.TextYAlignment = Enum.TextYAlignment.Top
		local save = button(manage, "Save Description", COLORS.green)
		save.Activated:Connect(function()
			invokeAction("EditDescription", { description = descBox.Text })
		end)
		local disband = button(manage, "Disband Guild", COLORS.red)
		disband.Activated:Connect(function()
			invokeAction("DisbandGuild")
		end)
	end

	local members = section("Members")
	for _, member in ipairs(guild.Members or {}) do
		local memberFrame = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(24, 25, 27),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, state and state.CanManage and member.Role ~= "Owner" and 76 or 54),
		}, members)
		addCorner(memberFrame, 5)
		addStroke(memberFrame, Color3.fromRGB(67, 61, 55), 1, 0.24)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 7),
			Size = UDim2.new(1, -24, 0, 22),
			Font = Enum.Font.GothamBold,
			Text = ("%s  [%s]"):format(tostring(member.Name or member.UserId), tostring(member.Role or "Member")),
			TextColor3 = member.Role == "Owner" and COLORS.gold or COLORS.text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, memberFrame)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 30),
			Size = UDim2.new(1, -24, 0, 18),
			Font = Enum.Font.Gotham,
			Text = "Contribution " .. formatAmount(member.Contribution),
			TextColor3 = COLORS.muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, memberFrame)

		if state and state.CanManage == true and member.Role ~= "Owner" then
			local actionFrame = create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 1, -34),
				Size = UDim2.new(1, -24, 0, 28),
			}, memberFrame)
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}, actionFrame)
			local roleButton = button(actionFrame, member.Role == "Officer" and "Demote" or "Promote", COLORS.blue)
			roleButton.Size = UDim2.fromOffset(92, 28)
			roleButton.Activated:Connect(function()
				invokeAction(member.Role == "Officer" and "DemoteMember" or "PromoteMember", { userId = member.UserId })
			end)
			local kickButton = button(actionFrame, "Kick", COLORS.red)
			kickButton.Size = UDim2.fromOffset(76, 28)
			kickButton.Activated:Connect(function()
				invokeAction("KickMember", { userId = member.UserId })
			end)
		end
	end
end

local function renderRequests()
	local guild = getGuild()
	if not guild then
		text(section("Requests"), "Create or join a guild first.", 15, COLORS.muted)
		return
	end
	if not canManageJoin() then
		text(section("Requests"), "Only the guild owner and officers can manage join requests.", 15, COLORS.muted)
		return
	end

	local holder = section("Join requests")
	local requests = guild.JoinRequests or {}
	if #requests == 0 then
		text(holder, "No pending requests.", 14, COLORS.muted)
		return
	end

	for _, request in ipairs(requests) do
		local requestFrame = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(24, 25, 27),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 58),
		}, holder)
		addCorner(requestFrame, 5)
		addStroke(requestFrame, Color3.fromRGB(67, 61, 55), 1, 0.24)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 8),
			Size = UDim2.new(1, -220, 0, 22),
			Font = Enum.Font.GothamBold,
			Text = tostring(request.Username or request.UserId),
			TextColor3 = COLORS.text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, requestFrame)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 31),
			Size = UDim2.new(1, -220, 0, 18),
			Font = Enum.Font.Gotham,
			Text = "UserId " .. tostring(request.UserId),
			TextColor3 = COLORS.muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, requestFrame)
		local accept = button(requestFrame, "Accept", COLORS.green)
		accept.AnchorPoint = Vector2.new(1, 0.5)
		accept.Position = UDim2.new(1, -104, 0.5, 0)
		accept.Size = UDim2.fromOffset(86, 30)
		accept.Activated:Connect(function()
			invokeAction("AcceptJoinRequest", { userId = request.UserId })
		end)
		local reject = button(requestFrame, "Reject", COLORS.red)
		reject.AnchorPoint = Vector2.new(1, 0.5)
		reject.Position = UDim2.new(1, -12, 0.5, 0)
		reject.Size = UDim2.fromOffset(86, 30)
		reject.Activated:Connect(function()
			invokeAction("RejectJoinRequest", { userId = request.UserId })
		end)
	end
end

local function renderInvites()
	local guild = getGuild()
	if not guild then
		local holder = section("Invites")
		local invites = typeof(state) == "table" and typeof(state.Invites) == "table" and state.Invites or {}
		if #invites == 0 then
			text(holder, "No pending invites.", 14, COLORS.muted)
			return
		end
		for _, invite in ipairs(invites) do
			local inviteFrame = create("Frame", {
				BackgroundColor3 = Color3.fromRGB(24, 25, 27),
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 58),
			}, holder)
			addCorner(inviteFrame, 5)
			addStroke(inviteFrame, Color3.fromRGB(67, 61, 55), 1, 0.24)
			create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 8),
				Size = UDim2.new(1, -220, 0, 22),
				Font = Enum.Font.GothamBold,
				Text = tostring(invite.GuildName or "Guild"),
				TextColor3 = COLORS.text,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, inviteFrame)
			create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 12, 0, 31),
				Size = UDim2.new(1, -220, 0, 18),
				Font = Enum.Font.Gotham,
				Text = ("Level %d  Members %d/%d"):format(tonumber(invite.Level) or 1, tonumber(invite.MemberCount) or 0, tonumber(invite.MaxMembers) or 50),
				TextColor3 = COLORS.muted,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, inviteFrame)
			local accept = button(inviteFrame, "Accept", COLORS.green)
			accept.AnchorPoint = Vector2.new(1, 0.5)
			accept.Position = UDim2.new(1, -104, 0.5, 0)
			accept.Size = UDim2.fromOffset(86, 30)
			accept.Activated:Connect(function()
				invokeAction("AcceptInvite", { guildId = invite.GuildId })
			end)
			local decline = button(inviteFrame, "Decline", COLORS.red)
			decline.AnchorPoint = Vector2.new(1, 0.5)
			decline.Position = UDim2.new(1, -12, 0.5, 0)
			decline.Size = UDim2.fromOffset(86, 30)
			decline.Activated:Connect(function()
				invokeAction("DeclineInvite", { guildId = invite.GuildId })
			end)
		end
		return
	end

	if not canManageJoin() then
		text(section("Invites"), "Only the guild owner and officers can manage invites.", 15, COLORS.muted)
		return
	end

	local holder = section("Invites")
	local targetBox = inputBox(holder, "Username or userId", "")
	local send = button(holder, "Send Invite", COLORS.green)
	send.Activated:Connect(function()
		invokeAction("SendInvite", { target = targetBox.Text })
	end)

	local invites = guild.Invites or {}
	if #invites == 0 then
		text(holder, "No pending invites.", 14, COLORS.muted)
		return
	end
	for _, invite in ipairs(invites) do
		local inviteFrame = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(24, 25, 27),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 52),
		}, holder)
		addCorner(inviteFrame, 5)
		addStroke(inviteFrame, Color3.fromRGB(67, 61, 55), 1, 0.24)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 8),
			Size = UDim2.new(1, -150, 0, 22),
			Font = Enum.Font.GothamBold,
			Text = ("%s  UserId %s"):format(tostring(invite.Username or invite.UserId), tostring(invite.UserId)),
			TextColor3 = COLORS.text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, inviteFrame)
		local cancel = button(inviteFrame, "Cancel", COLORS.red)
		cancel.AnchorPoint = Vector2.new(1, 0.5)
		cancel.Position = UDim2.new(1, -12, 0.5, 0)
		cancel.Size = UDim2.fromOffset(92, 30)
		cancel.Activated:Connect(function()
			invokeAction("CancelInvite", { userId = invite.UserId })
		end)
	end
end

local function renderRequiresGuild()
	text(section("Guild required"), "Create or join a guild first.", 15, COLORS.muted)
end

local function renderTasks()
	local guild = getGuild()
	if not guild then
		renderRequiresGuild()
		return
	end
	local holder = section(("Guild tasks %d/%d"):format(tonumber(guild.CompletedTasks) or 0, tonumber(guild.TotalTasks) or 5))
	for _, taskData in ipairs(guild.Tasks or {}) do
		local taskFrame = create("Frame", {
			BackgroundColor3 = Color3.fromRGB(24, 25, 27),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 86),
		}, holder)
		addCorner(taskFrame, 5)
		addStroke(taskFrame, Color3.fromRGB(67, 61, 55), 1, 0.24)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 8),
			Size = UDim2.new(1, -24, 0, 20),
			Font = Enum.Font.GothamBold,
			Text = tostring(taskData.DisplayName or taskData.Id),
			TextColor3 = taskData.Completed and COLORS.green or COLORS.text,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, taskFrame)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 31),
			Size = UDim2.new(1, -24, 0, 18),
			Font = Enum.Font.Gotham,
			Text = tostring(taskData.Description or ""),
			TextColor3 = COLORS.muted,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, taskFrame)
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 12, 0, 52),
			Size = UDim2.new(0, 120, 0, 18),
			Font = Enum.Font.Gotham,
			Text = ("%s / %s"):format(formatAmount(taskData.Current), formatAmount(taskData.Target)),
			TextColor3 = COLORS.gold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, taskFrame)
		local barHolder = create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 140, 0, 58),
			Size = UDim2.new(1, -154, 0, 8),
		}, taskFrame)
		progressBar(barHolder, taskData.Current, taskData.Target)
	end
end

local function renderDonate()
	local guild = getGuild()
	if not guild then
		renderRequiresGuild()
		return
	end
	local holder = section("Donate")
	local resources = getConfig().DonationResources or {}
	local balances = state and state.PlayerResources or {}
	text(holder, ("Silver %s  Souls %s  Tickets %s  WP %s"):format(formatAmount(balances.Silver), formatAmount(balances.Souls), formatAmount(balances.Tickets), formatAmount(balances.WeaponPoints)), 13, COLORS.muted)
	local resourceRow = row(holder, 36)
	for _, resource in ipairs(resources) do
		local resourceButton = button(resourceRow, resource.displayName or resource.id, selectedDonationResource == resource.id and COLORS.gold or COLORS.blue)
		resourceButton.Size = UDim2.fromOffset(116, 32)
		resourceButton.TextColor3 = selectedDonationResource == resource.id and Color3.fromRGB(25, 22, 18) or COLORS.text
		resourceButton.Activated:Connect(function()
			selectedDonationResource = resource.id
			render()
		end)
	end
	local amountBox = inputBox(holder, "Amount", "100")
	local donateButton = button(holder, "Donate", COLORS.green)
	donateButton.Activated:Connect(function()
		invokeAction("Donate", {
			resourceId = selectedDonationResource,
			amount = tonumber(amountBox.Text) or 0,
		})
	end)
end

local function getUpgrade(upgradeId)
	local guild = getGuild()
	for _, upgrade in ipairs(guild and guild.UpgradeList or {}) do
		if upgrade.Id == upgradeId then
			return upgrade
		end
	end
	return nil
end

local function renderUpgradeCard(parent, upgradeId)
	local upgrade = getUpgrade(upgradeId)
	if not upgrade then
		return
	end
	local card = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(24, 25, 27),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 92),
	}, parent)
	addCorner(card, 5)
	addStroke(card, Color3.fromRGB(67, 61, 55), 1, 0.24)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 8),
		Size = UDim2.new(1, -150, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = ("%s Lv. %d/%d"):format(tostring(upgrade.DisplayName), tonumber(upgrade.Level) or 0, tonumber(upgrade.MaxLevel) or 0),
		TextColor3 = COLORS.text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 34),
		Size = UDim2.new(1, -150, 0, 38),
		Font = Enum.Font.Gotham,
		Text = tostring(upgrade.Description or ""),
		TextColor3 = COLORS.muted,
		TextWrapped = true,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, card)
	local label = upgrade.CostSilver and ("Upgrade\n" .. formatAmount(upgrade.CostSilver) .. " Silver") or "Maxed"
	local canUpgrade = state ~= nil and state.CanManage == true and upgrade.CostSilver ~= nil
	local upgradeButton = button(card, label, canUpgrade and COLORS.green or Color3.fromRGB(75, 75, 75))
	upgradeButton.AnchorPoint = Vector2.new(1, 0.5)
	upgradeButton.Position = UDim2.new(1, -12, 0.5, 0)
	upgradeButton.Size = UDim2.fromOffset(126, 48)
	upgradeButton.Active = canUpgrade
	upgradeButton.AutoButtonColor = upgradeButton.Active
	upgradeButton.Activated:Connect(function()
		if upgradeButton.Active then
			invokeAction("Upgrade", { upgradeId = upgradeId })
		end
	end)
end

local function renderDojo()
	local guild = getGuild()
	if not guild then
		renderRequiresGuild()
		return
	end
	local holder = section("Dojo")
	text(holder, ("Guild level %d  XP %s  Treasury Silver %s"):format(tonumber(guild.Level) or 1, formatAmount(guild.XP), formatAmount(guild.Treasury and guild.Treasury.Silver)), 14, COLORS.muted)
	renderUpgradeCard(holder, "Dojo")
end

local function renderTreasury()
	local guild = getGuild()
	if not guild then
		renderRequiresGuild()
		return
	end
	local holder = section("Guild treasury")
	for _, key in ipairs((state and state.Config and state.Config.TreasuryKeys) or { "Silver", "Souls", "Tickets", "WeaponPoints" }) do
		text(holder, ("%s: %s"):format(tostring(key), formatAmount(guild.Treasury and guild.Treasury[key])), 15, COLORS.text, true)
	end
end

local function renderEconomy()
	local guild = getGuild()
	if not guild then
		renderRequiresGuild()
		return
	end
	local holder = section("Farms, mine, and fishing")
	renderUpgradeCard(holder, "Farms")
	renderUpgradeCard(holder, "Mine")
	renderUpgradeCard(holder, "Fishery")
end

local function renderHall()
	local guild = getGuild()
	if not guild then
		renderRequiresGuild()
		return
	end
	local holder = section("Hall of Fame")
	for index, member in ipairs(guild.Members or {}) do
		text(holder, ("%d. %s  [%s]  %s contribution"):format(index, tostring(member.Name or member.UserId), tostring(member.Role or "Member"), formatAmount(member.Contribution)), 14, index == 1 and COLORS.gold or COLORS.text, index <= 3)
	end
end

render = function()
	renderTabs()
	clearDynamic(content)
	if selectedTab == "Description" then
		renderDescription()
	elseif selectedTab == "Requests" then
		renderRequests()
	elseif selectedTab == "Invites" then
		renderInvites()
	elseif selectedTab == "Tasks" then
		renderTasks()
	elseif selectedTab == "Donate" then
		renderDonate()
	elseif selectedTab == "Dojo" then
		renderDojo()
	elseif selectedTab == "Treasury" then
		renderTreasury()
	elseif selectedTab == "Economy" then
		renderEconomy()
	elseif selectedTab == "Hall" then
		renderHall()
	end
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

if GuildUpdated then
	GuildUpdated.OnClientEvent:Connect(function(_payload)
		if gui.Enabled and lastSearchQuery ~= nil and not getGuild() then
			task.spawn(function()
				searchGuilds(lastSearchQuery)
			end)
			return
		end
		queueOpenStateRefresh()
	end)
end

render()
