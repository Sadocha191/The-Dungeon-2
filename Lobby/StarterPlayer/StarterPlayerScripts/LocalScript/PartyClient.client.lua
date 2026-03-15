-- PartyClient.client.lua (Lobby)
-- Centered party UI styled to match the rest of the lobby menus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local plr = Players.LocalPlayer

local folder = ReplicatedStorage:WaitForChild("RemoteEvents")
local PartyAction = folder:WaitForChild("PartyAction")
local PartyUpdated = folder:WaitForChild("PartyUpdated")
local PartyInvite = folder:WaitForChild("PartyInvite")
local PartyQuery = folder:WaitForChild("PartyQuery")

local function safeCall(f, ...)
	local ok, res = pcall(f, ...)
	if ok then
		return res
	end
	return nil
end

local function addCorner(inst: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
end

local function addStroke(inst: Instance, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Parent = inst
	return stroke
end

local function addHover(button: GuiObject, normalColor: Color3, hoverColor: Color3)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = hoverColor,
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = normalColor,
		}):Play()
	end)
end

local function styleCard(frame: Frame)
	frame.BorderSizePixel = 0
	addCorner(frame, 12)
	addStroke(frame, Color3.fromRGB(40, 40, 48))
end

local function makeActionButton(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	backgroundColor: Color3,
	hoverColor: Color3
)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BorderSizePixel = 0
	button.BackgroundColor3 = backgroundColor
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.Parent = parent
	addCorner(button, 12)
	addHover(button, backgroundColor, hoverColor)
	return button
end

local gui = plr:WaitForChild("PlayerGui"):WaitForChild("PartyGui")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui:SetAttribute("Modal", false)

local overlay = gui:WaitForChild("overlay")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Active = true
overlay.Parent = gui

local panel = overlay:WaitForChild("panel")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromScale(0.88, 0.88)
panel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
panel.BorderSizePixel = 0
panel.Parent = overlay
addCorner(panel, 16)
local panelSizeConstraint = Instance.new("UISizeConstraint", panel)
panelSizeConstraint.MaxSize = Vector2.new(980, 560)
local panelAspect = Instance.new("UIAspectRatioConstraint", panel)
panelAspect.AspectRatio = 980 / 560
panelAspect.DominantAxis = Enum.DominantAxis.Height
addStroke(panel, Color3.fromRGB(40, 40, 48))

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 16)
title.Size = UDim2.new(1, -160, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Party"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(24, 44)
subtitle.Size = UDim2.new(1, -180, 0, 18)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = Color3.fromRGB(190, 190, 190)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "Invite players, manage your roster and accept incoming invites."
subtitle.Parent = panel

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
closeBtn.Parent = panel
addCorner(closeBtn, 10)
addHover(closeBtn, closeBtn.BackgroundColor3, Color3.fromRGB(38, 38, 48))

local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(20, 76)
body.Size = UDim2.new(1, -40, 1, -96)
body.BackgroundTransparency = 1
body.Parent = panel

local bodyLayout = Instance.new("UIListLayout")
bodyLayout.FillDirection = Enum.FillDirection.Horizontal
bodyLayout.Padding = UDim.new(0, 16)
bodyLayout.Parent = body

local onlinePanel = Instance.new("Frame")
onlinePanel.Size = UDim2.new(0.52, -8, 1, 0)
onlinePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
onlinePanel.BackgroundTransparency = 0.08
onlinePanel.Parent = body
styleCard(onlinePanel)

local onlineTitle = Instance.new("TextLabel")
onlineTitle.BackgroundTransparency = 1
onlineTitle.Position = UDim2.fromOffset(16, 16)
onlineTitle.Size = UDim2.new(1, -32, 0, 20)
onlineTitle.Font = Enum.Font.GothamBold
onlineTitle.TextSize = 16
onlineTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
onlineTitle.TextXAlignment = Enum.TextXAlignment.Left
onlineTitle.Text = "Online Players"
onlineTitle.Parent = onlinePanel

local onlineHint = Instance.new("TextLabel")
onlineHint.BackgroundTransparency = 1
onlineHint.Position = UDim2.fromOffset(16, 38)
onlineHint.Size = UDim2.new(1, -32, 0, 16)
onlineHint.Font = Enum.Font.Gotham
onlineHint.TextSize = 12
onlineHint.TextColor3 = Color3.fromRGB(190, 190, 190)
onlineHint.TextXAlignment = Enum.TextXAlignment.Left
onlineHint.Text = "Invite someone to create a party. The inviter becomes leader."
onlineHint.Parent = onlinePanel

local search = Instance.new("TextBox")
search.PlaceholderText = "Search players..."
search.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
search.ClearTextOnFocus = false
search.Position = UDim2.fromOffset(16, 66)
search.Size = UDim2.new(1, -32, 0, 36)
search.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
search.BorderSizePixel = 0
search.Font = Enum.Font.Gotham
search.TextSize = 14
search.TextColor3 = Color3.fromRGB(235, 235, 235)
search.TextXAlignment = Enum.TextXAlignment.Left
search.Text = ""
search.Parent = onlinePanel
addCorner(search, 10)
addStroke(search, Color3.fromRGB(45, 45, 55))

local searchPadding = Instance.new("UIPadding")
searchPadding.PaddingLeft = UDim.new(0, 12)
searchPadding.PaddingRight = UDim.new(0, 12)
searchPadding.Parent = search

local onlineList = Instance.new("ScrollingFrame")
onlineList.Position = UDim2.fromOffset(16, 114)
onlineList.Size = UDim2.new(1, -32, 1, -130)
onlineList.BackgroundTransparency = 1
onlineList.BorderSizePixel = 0
onlineList.ScrollBarThickness = 6
onlineList.AutomaticCanvasSize = Enum.AutomaticSize.Y
onlineList.CanvasSize = UDim2.fromOffset(0, 0)
onlineList.Parent = onlinePanel

local onlineLayout = Instance.new("UIListLayout")
onlineLayout.Padding = UDim.new(0, 10)
onlineLayout.Parent = onlineList

local partyPanel = Instance.new("Frame")
partyPanel.Size = UDim2.new(0.48, -8, 1, 0)
partyPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
partyPanel.BackgroundTransparency = 0.08
partyPanel.Parent = body
styleCard(partyPanel)

local partyTitle = Instance.new("TextLabel")
partyTitle.BackgroundTransparency = 1
partyTitle.Position = UDim2.fromOffset(16, 16)
partyTitle.Size = UDim2.new(1, -32, 0, 20)
partyTitle.Font = Enum.Font.GothamBold
partyTitle.TextSize = 16
partyTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
partyTitle.TextXAlignment = Enum.TextXAlignment.Left
partyTitle.Text = "Your Party"
partyTitle.Parent = partyPanel

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(16, 40)
status.Size = UDim2.new(1, -32, 0, 32)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = ""
status.Parent = partyPanel

local partyList = Instance.new("ScrollingFrame")
partyList.Position = UDim2.fromOffset(16, 84)
partyList.Size = UDim2.new(1, -32, 1, -152)
partyList.BackgroundTransparency = 1
partyList.BorderSizePixel = 0
partyList.ScrollBarThickness = 6
partyList.AutomaticCanvasSize = Enum.AutomaticSize.Y
partyList.CanvasSize = UDim2.fromOffset(0, 0)
partyList.Parent = partyPanel

local partyLayout = Instance.new("UIListLayout")
partyLayout.Padding = UDim.new(0, 10)
partyLayout.Parent = partyList

local footer = Instance.new("Frame")
footer.Position = UDim2.new(0, 16, 1, -52)
footer.Size = UDim2.new(1, -32, 0, 36)
footer.BackgroundTransparency = 1
footer.Parent = partyPanel

local leave = makeActionButton(
	footer,
	"Leave",
	UDim2.new(0.5, -8, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(28, 28, 36),
	Color3.fromRGB(38, 38, 48)
)

local disband = makeActionButton(
	footer,
	"Disband",
	UDim2.new(0.5, -8, 1, 0),
	UDim2.new(0.5, 8, 0, 0),
	Color3.fromRGB(112, 44, 44),
	Color3.fromRGB(132, 56, 56)
)

local currentParty = { id = nil, leaderUserId = nil, members = {}, maxMembers = 5 }
local activeInviteModal = nil

local function refreshModalState()
	gui:SetAttribute("Modal", overlay.Visible or (activeInviteModal ~= nil and activeInviteModal.Parent ~= nil))
end

local function clearChildren(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local function getLeaderName()
	local leaderId = currentParty.leaderUserId
	for _, member in ipairs(currentParty.members or {}) do
		if member.userId == leaderId then
			return member.name or tostring(leaderId)
		end
	end
	return leaderId and tostring(leaderId) or "-"
end

local function isLeader()
	return currentParty.id ~= nil and currentParty.leaderUserId == plr.UserId
end

local function fetchPartyState()
	local party = safeCall(function()
		return PartyQuery:InvokeServer("GetParty")
	end)

	if typeof(party) == "table" then
		currentParty = party
	else
		currentParty = { id = nil, leaderUserId = nil, members = {}, maxMembers = 5 }
	end
end

local function makeEmptyState(parent: Instance, titleText: string, descText: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 96)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	row.BackgroundTransparency = 0.08
	row.Parent = parent
	styleCard(row)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(16, 16)
	titleLabel.Size = UDim2.new(1, -32, 0, 20)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 14
	titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = titleText
	titleLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.BackgroundTransparency = 1
	descLabel.Position = UDim2.fromOffset(16, 40)
	descLabel.Size = UDim2.new(1, -32, 0, 40)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 12
	descLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Text = descText
	descLabel.Parent = row
end

local function passesFilter(name: string): boolean
	local filterText = string.lower(search.Text or "")
	if filterText == "" then
		return true
	end
	return string.find(string.lower(name), filterText, 1, true) ~= nil
end

local function renderOnline()
	clearChildren(onlineList)

	local shown = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= plr and passesFilter(player.Name) then
			shown += 1

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 56)
			row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
			row.BackgroundTransparency = 0.08
			row.Parent = onlineList
			styleCard(row)

			local displayName = player.DisplayName
			local primaryText = displayName
			if displayName ~= player.Name then
				primaryText = ("%s (@%s)"):format(displayName, player.Name)
			end

			local nameLabel = Instance.new("TextLabel")
			nameLabel.BackgroundTransparency = 1
			nameLabel.Position = UDim2.fromOffset(16, 10)
			nameLabel.Size = UDim2.new(1, -132, 0, 18)
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 14
			nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Text = primaryText
			nameLabel.Parent = row

			local descLabel = Instance.new("TextLabel")
			descLabel.BackgroundTransparency = 1
			descLabel.Position = UDim2.fromOffset(16, 30)
			descLabel.Size = UDim2.new(1, -132, 0, 14)
			descLabel.Font = Enum.Font.Gotham
			descLabel.TextSize = 12
			descLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
			descLabel.Text = "Online"
			descLabel.Parent = row

			local invite = makeActionButton(
				row,
				"Invite",
				UDim2.fromOffset(96, 34),
				UDim2.new(1, -112, 0.5, -17),
				Color3.fromRGB(60, 140, 255),
				Color3.fromRGB(82, 157, 255)
			)
			invite.MouseButton1Click:Connect(function()
				PartyAction:FireServer("Invite", player.UserId)
			end)
		end
	end

	if shown == 0 then
		if (search.Text or "") == "" then
			makeEmptyState(onlineList, "Nobody else is online.", "When another player joins the lobby, you can invite them from here.")
		else
			makeEmptyState(onlineList, "No players found.", "Try a different search term or clear the filter.")
		end
	end
end

local function renderParty()
	clearChildren(partyList)

	local hasParty = currentParty.id ~= nil
	local count = #currentParty.members
	local maxMembers = currentParty.maxMembers or 5

	if hasParty then
		status.Text = ("Party %d/%d  |  Leader: %s"):format(count, maxMembers, getLeaderName())
	else
		status.Text = "You are not in a party yet. Invite someone from the list to create one."
	end

	if not hasParty or count == 0 then
		makeEmptyState(partyList, "No active party.", "Your current party members will appear here after you create or join a group.")
	else
		for _, member in ipairs(currentParty.members or {}) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 60)
			row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
			row.BackgroundTransparency = 0.08
			row.Parent = partyList
			styleCard(row)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.BackgroundTransparency = 1
			nameLabel.Position = UDim2.fromOffset(16, 10)
			nameLabel.Size = UDim2.new(1, -150, 0, 18)
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextSize = 14
			nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Text = member.name or tostring(member.userId)
			nameLabel.Parent = row

			local roleLabel = Instance.new("TextLabel")
			roleLabel.BackgroundTransparency = 1
			roleLabel.Position = UDim2.fromOffset(16, 30)
			roleLabel.Size = UDim2.new(1, -150, 0, 14)
			roleLabel.Font = Enum.Font.Gotham
			roleLabel.TextSize = 12
			roleLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			roleLabel.TextXAlignment = Enum.TextXAlignment.Left
			roleLabel.Text = member.userId == currentParty.leaderUserId and "Leader" or "Member"
			roleLabel.Parent = row

			if isLeader() and member.userId ~= plr.UserId then
				local kick = makeActionButton(
					row,
					"Kick",
					UDim2.fromOffset(88, 34),
					UDim2.new(1, -104, 0.5, -17),
					Color3.fromRGB(112, 44, 44),
					Color3.fromRGB(132, 56, 56)
				)
				kick.MouseButton1Click:Connect(function()
					PartyAction:FireServer("Kick", member.userId)
				end)
			end
		end
	end

	leave.Visible = hasParty
	disband.Visible = hasParty and isLeader()
end

local function openUI()
	overlay.Visible = true
	refreshModalState()
	fetchPartyState()
	renderParty()
	renderOnline()
end

local function closeUI()
	overlay.Visible = false
	refreshModalState()
end

local function toggleUI()
	if overlay.Visible then
		closeUI()
	else
		openUI()
	end
end

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
		toggleUI()
	end
end

local function closeInviteModal()
	if activeInviteModal and activeInviteModal.Parent then
		activeInviteModal:Destroy()
	end
	activeInviteModal = nil
	refreshModalState()
end

local function showInviteModal(fromName: string, fromUserId: number, expiresIn: number)
	closeInviteModal()

	local modalOverlay = Instance.new("Frame")
	modalOverlay.Size = UDim2.fromScale(1, 1)
	modalOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	modalOverlay.BackgroundTransparency = 0.35
	modalOverlay.BorderSizePixel = 0
	modalOverlay.Active = true
	modalOverlay.Parent = gui
	activeInviteModal = modalOverlay
	refreshModalState()

	local modalPanel = Instance.new("Frame")
	modalPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	modalPanel.Position = UDim2.fromScale(0.5, 0.5)
	modalPanel.Size = UDim2.fromScale(0.46, 0.34)
	modalPanel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	modalPanel.BorderSizePixel = 0
	modalPanel.Parent = modalOverlay
	addCorner(modalPanel, 16)
	local modalPanelSizeConstraint = Instance.new("UISizeConstraint", modalPanel)
	modalPanelSizeConstraint.MaxSize = Vector2.new(420, 220)
	local modalPanelAspect = Instance.new("UIAspectRatioConstraint", modalPanel)
	modalPanelAspect.AspectRatio = 420 / 220
	modalPanelAspect.DominantAxis = Enum.DominantAxis.Height
	addStroke(modalPanel, Color3.fromRGB(40, 40, 48))

	local modalTitle = Instance.new("TextLabel")
	modalTitle.BackgroundTransparency = 1
	modalTitle.Position = UDim2.fromOffset(20, 16)
	modalTitle.Size = UDim2.new(1, -64, 0, 24)
	modalTitle.Font = Enum.Font.GothamBold
	modalTitle.TextSize = 18
	modalTitle.TextColor3 = Color3.fromRGB(245, 245, 245)
	modalTitle.TextXAlignment = Enum.TextXAlignment.Left
	modalTitle.Text = "Party Invite"
	modalTitle.Parent = modalPanel

	local modalClose = Instance.new("TextButton")
	modalClose.AnchorPoint = Vector2.new(1, 0)
	modalClose.Position = UDim2.new(1, -16, 0, 16)
	modalClose.Size = UDim2.fromOffset(28, 28)
	modalClose.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	modalClose.BorderSizePixel = 0
	modalClose.Font = Enum.Font.GothamBold
	modalClose.TextSize = 14
	modalClose.TextColor3 = Color3.fromRGB(210, 210, 210)
	modalClose.Text = "X"
	modalClose.Parent = modalPanel
	addCorner(modalClose, 10)
	addHover(modalClose, modalClose.BackgroundColor3, Color3.fromRGB(38, 38, 48))

	local modalMessage = Instance.new("TextLabel")
	modalMessage.BackgroundTransparency = 1
	modalMessage.Position = UDim2.fromOffset(20, 56)
	modalMessage.Size = UDim2.new(1, -40, 0, 72)
	modalMessage.Font = Enum.Font.Gotham
	modalMessage.TextSize = 14
	modalMessage.TextWrapped = true
	modalMessage.TextColor3 = Color3.fromRGB(220, 220, 220)
	modalMessage.TextXAlignment = Enum.TextXAlignment.Left
	modalMessage.TextYAlignment = Enum.TextYAlignment.Top
	modalMessage.Text = ("Party invite from %s"):format(fromName)
	modalMessage.Parent = modalPanel

	local modalHint = Instance.new("TextLabel")
	modalHint.BackgroundTransparency = 1
	modalHint.Position = UDim2.fromOffset(20, 122)
	modalHint.Size = UDim2.new(1, -40, 0, 18)
	modalHint.Font = Enum.Font.Gotham
	modalHint.TextSize = 12
	modalHint.TextColor3 = Color3.fromRGB(180, 180, 180)
	modalHint.TextXAlignment = Enum.TextXAlignment.Left
	modalHint.Text = "Accept to join immediately, or decline to ignore the request."
	modalHint.Parent = modalPanel

	local accept = makeActionButton(
		modalPanel,
		"Accept",
		UDim2.new(0.5, -10, 0, 38),
		UDim2.new(0, 20, 1, -58),
		Color3.fromRGB(60, 140, 255),
		Color3.fromRGB(82, 157, 255)
	)

	local decline = makeActionButton(
		modalPanel,
		"Decline",
		UDim2.new(0.5, -10, 0, 38),
		UDim2.new(0.5, -10, 1, -58),
		Color3.fromRGB(28, 28, 36),
		Color3.fromRGB(38, 38, 48)
	)

	modalClose.MouseButton1Click:Connect(closeInviteModal)
	accept.MouseButton1Click:Connect(function()
		PartyAction:FireServer("Accept", fromUserId)
		closeInviteModal()
	end)
	decline.MouseButton1Click:Connect(function()
		PartyAction:FireServer("Decline", fromUserId)
		closeInviteModal()
	end)

	task.delay(expiresIn, function()
		if activeInviteModal == modalOverlay and modalOverlay.Parent then
			closeInviteModal()
		end
	end)
end

closeBtn.MouseButton1Click:Connect(closeUI)

search:GetPropertyChangedSignal("Text"):Connect(function()
	if overlay.Visible then
		renderOnline()
	end
end)

Players.PlayerAdded:Connect(function()
	if overlay.Visible then
		renderOnline()
	end
end)

Players.PlayerRemoving:Connect(function()
	if overlay.Visible then
		renderOnline()
	end
end)

PartyUpdated.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	currentParty = payload

	if overlay.Visible then
		renderParty()
		renderOnline()
	end
end)

PartyInvite.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "invite" then
		return
	end

	local fromUserId = tonumber(payload.fromUserId)
	if not fromUserId then
		return
	end

	showInviteModal(
		tostring(payload.fromName or "?"),
		fromUserId,
		tonumber(payload.expiresIn) or 20
	)
end)

leave.MouseButton1Click:Connect(function()
	PartyAction:FireServer("Leave")
end)

disband.MouseButton1Click:Connect(function()
	PartyAction:FireServer("Disband")
end)

gui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(handleScreenButtonsRequest)
handleScreenButtonsRequest()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		if activeInviteModal then
			closeInviteModal()
		elseif overlay.Visible then
			closeUI()
		end
	end
end)
