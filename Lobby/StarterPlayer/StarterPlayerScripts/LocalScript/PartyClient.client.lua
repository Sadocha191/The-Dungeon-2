-- PartyClient.client.lua (Lobby)
-- Minimal party UI: button + list of online players to invite + party roster.
-- Expects ReplicatedStorage.RemoteEvents.PartyAction, PartyQuery, PartyUpdated, PartyInvite.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer

local folder = ReplicatedStorage:WaitForChild("RemoteEvents")
local PartyAction = folder:WaitForChild("PartyAction")
local PartyUpdated = folder:WaitForChild("PartyUpdated")
local PartyInvite = folder:WaitForChild("PartyInvite")
local PartyQuery = folder:WaitForChild("PartyQuery")

local function safeCall(f, ...)
	local ok, res = pcall(f, ...)
	if ok then return res end
	return nil
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "PartyGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui:SetAttribute("Modal", false)
gui.Parent = plr:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Name = "PartyButton"
btn.Text = "Party"
btn.AnchorPoint = Vector2.new(1, 0)
btn.Position = UDim2.new(1, -20, 0, 20)
btn.Size = UDim2.new(0, 120, 0, 36)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 18
btn.BackgroundTransparency = 0.15
btn.Visible = false
btn.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -20, 0, 64)
panel.Size = UDim2.new(0, 360, 0, 420)
panel.BackgroundTransparency = 0.15
panel.Visible = false
panel.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -16, 0, 28)
title.Position = UDim2.new(0, 8, 0, 8)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Party"
title.Parent = panel

local close = Instance.new("TextButton")
close.Text = "X"
close.Size = UDim2.new(0, 28, 0, 28)
close.Position = UDim2.new(1, -36, 0, 6)
close.Font = Enum.Font.GothamBold
close.TextSize = 18
close.BackgroundTransparency = 0.2
close.Parent = panel

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Size = UDim2.new(1, -16, 0, 20)
status.Position = UDim2.new(0, 8, 0, 40)
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextColor3 = Color3.fromRGB(220,220,220)
status.Text = ""
status.Parent = panel

local search = Instance.new("TextBox")
search.PlaceholderText = "Search players..."
search.ClearTextOnFocus = false
search.Size = UDim2.new(1, -16, 0, 28)
search.Position = UDim2.new(0, 8, 0, 68)
search.Font = Enum.Font.Gotham
search.TextSize = 14
search.Text = ""
search.BackgroundTransparency = 0.2
search.Parent = panel

local onlineLabel = Instance.new("TextLabel")
onlineLabel.BackgroundTransparency = 1
onlineLabel.Size = UDim2.new(1, -16, 0, 20)
onlineLabel.Position = UDim2.new(0, 8, 0, 104)
onlineLabel.Font = Enum.Font.GothamBold
onlineLabel.TextSize = 14
onlineLabel.TextXAlignment = Enum.TextXAlignment.Left
onlineLabel.Text = "Online"
onlineLabel.Parent = panel

local onlineList = Instance.new("ScrollingFrame")
onlineList.Size = UDim2.new(1, -16, 0, 150)
onlineList.Position = UDim2.new(0, 8, 0, 126)
onlineList.BackgroundTransparency = 0.25
onlineList.BorderSizePixel = 0
onlineList.CanvasSize = UDim2.new(0,0,0,0)
onlineList.ScrollBarThickness = 6
onlineList.Parent = panel

local partyLabel = Instance.new("TextLabel")
partyLabel.BackgroundTransparency = 1
partyLabel.Size = UDim2.new(1, -16, 0, 20)
partyLabel.Position = UDim2.new(0, 8, 0, 284)
partyLabel.Font = Enum.Font.GothamBold
partyLabel.TextSize = 14
partyLabel.TextXAlignment = Enum.TextXAlignment.Left
partyLabel.Text = "Your party"
partyLabel.Parent = panel

local partyList = Instance.new("Frame")
partyList.Size = UDim2.new(1, -16, 0, 96)
partyList.Position = UDim2.new(0, 8, 0, 306)
partyList.BackgroundTransparency = 0.25
partyList.BorderSizePixel = 0
partyList.Parent = panel

local leave = Instance.new("TextButton")
leave.Text = "Leave"
leave.Size = UDim2.new(0.5, -12, 0, 32)
leave.Position = UDim2.new(0, 8, 1, -40)
leave.AnchorPoint = Vector2.new(0, 1)
leave.Font = Enum.Font.GothamBold
leave.TextSize = 16
leave.BackgroundTransparency = 0.2
leave.Parent = panel

local disband = Instance.new("TextButton")
disband.Text = "Disband"
disband.Size = UDim2.new(0.5, -12, 0, 32)
disband.Position = UDim2.new(0.5, 4, 1, -40)
disband.AnchorPoint = Vector2.new(0, 1)
disband.Font = Enum.Font.GothamBold
disband.TextSize = 16
disband.BackgroundTransparency = 0.2
disband.Parent = panel

local function clearChildren(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local currentParty = { id = nil, leaderUserId = nil, members = {}, maxMembers = 5 }
local activeInviteModal = nil
local renderParty
local renderOnline

local function refreshModalState()
	gui:SetAttribute("Modal", panel.Visible or (activeInviteModal ~= nil and activeInviteModal.Parent ~= nil))
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

local function openUI()
	panel.Visible = true
	refreshModalState()
	fetchPartyState()
	renderParty()
	renderOnline()
end

local function closeUI()
	panel.Visible = false
	refreshModalState()
end

local function toggleUI()
	if panel.Visible then
		closeUI()
	else
		openUI()
	end
end

local function isLeader()
	return currentParty.id ~= nil and currentParty.leaderUserId == plr.UserId
end

renderParty = function()
	clearChildren(partyList)

	local y = 8
	if currentParty.id == nil then
		status.Text = "Not in a party. Invite someone to create one (you become leader)."
	else
		local count = #currentParty.members
		status.Text = string.format("Party %d/%d  |  Leader: %s", count, currentParty.maxMembers or 5, tostring(currentParty.leaderUserId))
	end

	for _, m in ipairs(currentParty.members or {}) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -16, 0, 22)
		row.Position = UDim2.new(0, 8, 0, y)
		row.Parent = partyList

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -70, 1, 0)
		label.Font = Enum.Font.Gotham
		label.TextSize = 14
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = (m.userId == currentParty.leaderUserId and "★ " or "") .. (m.name or tostring(m.userId))
		label.Parent = row

		if isLeader() and m.userId ~= plr.UserId then
			local kick = Instance.new("TextButton")
			kick.Text = "Kick"
			kick.Size = UDim2.new(0, 56, 1, 0)
			kick.Position = UDim2.new(1, -56, 0, 0)
			kick.Font = Enum.Font.GothamBold
			kick.TextSize = 12
			kick.BackgroundTransparency = 0.2
			kick.Parent = row
			kick.MouseButton1Click:Connect(function()
				PartyAction:FireServer("Kick", m.userId)
			end)
		end

		y += 24
	end

	leave.Visible = currentParty.id ~= nil
	disband.Visible = isLeader() and currentParty.id ~= nil
end

local function passesFilter(name)
	local f = string.lower(search.Text or "")
	if f == "" then return true end
	return string.find(string.lower(name), f, 1, true) ~= nil
end

renderOnline = function()
	clearChildren(onlineList)
	local y = 6
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= plr and passesFilter(p.Name) then
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, -12, 0, 24)
			row.Position = UDim2.new(0, 6, 0, y)
			row.Parent = onlineList

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, -90, 1, 0)
			label.Font = Enum.Font.Gotham
			label.TextSize = 14
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Text = p.Name
			label.Parent = row

			local invite = Instance.new("TextButton")
			invite.Text = "Invite"
			invite.Size = UDim2.new(0, 80, 1, 0)
			invite.Position = UDim2.new(1, -80, 0, 0)
			invite.Font = Enum.Font.GothamBold
			invite.TextSize = 12
			invite.BackgroundTransparency = 0.2
			invite.Parent = row

			invite.MouseButton1Click:Connect(function()
				PartyAction:FireServer("Invite", p.UserId)
			end)

			y += 26
		end
	end
	onlineList.CanvasSize = UDim2.new(0, 0, 0, y)
end

btn.MouseButton1Click:Connect(function()
	toggleUI()
end)

close.MouseButton1Click:Connect(function()
	closeUI()
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
		toggleUI()
	end
end

gui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(handleScreenButtonsRequest)
handleScreenButtonsRequest()

search:GetPropertyChangedSignal("Text"):Connect(function()
	if panel.Visible then renderOnline() end
end)

Players.PlayerAdded:Connect(function()
	if panel.Visible then renderOnline() end
end)

Players.PlayerRemoving:Connect(function()
	if panel.Visible then renderOnline() end
end)

PartyUpdated.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	currentParty = payload
	if panel.Visible then
		renderParty()
		renderOnline()
	end
end)

PartyInvite.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type ~= "invite" then return end

	-- simple prompt: accept / decline
	local fromName = tostring(payload.fromName or "?")
	local fromUserId = tonumber(payload.fromUserId)
	if not fromUserId then return end

	-- small modal
	local modal = Instance.new("Frame")
	modal.Size = UDim2.new(0, 320, 0, 140)
	modal.Position = UDim2.new(0.5, -160, 0.5, -70)
	modal.BackgroundTransparency = 0.1
	modal.Parent = gui
	activeInviteModal = modal
	refreshModalState()

	local msg = Instance.new("TextLabel")
	msg.BackgroundTransparency = 1
	msg.Size = UDim2.new(1, -16, 0, 60)
	msg.Position = UDim2.new(0, 8, 0, 10)
	msg.Font = Enum.Font.Gotham
	msg.TextSize = 14
	msg.TextWrapped = true
	msg.Text = string.format("Party invite from %s", fromName)
	msg.Parent = modal

	local accept = Instance.new("TextButton")
	accept.Text = "Accept"
	accept.Size = UDim2.new(0.5, -12, 0, 32)
	accept.Position = UDim2.new(0, 8, 1, -42)
	accept.AnchorPoint = Vector2.new(0, 1)
	accept.Font = Enum.Font.GothamBold
	accept.TextSize = 16
	accept.BackgroundTransparency = 0.2
	accept.Parent = modal

	local decline = Instance.new("TextButton")
	decline.Text = "Decline"
	decline.Size = UDim2.new(0.5, -12, 0, 32)
	decline.Position = UDim2.new(0.5, 4, 1, -42)
	decline.AnchorPoint = Vector2.new(0, 1)
	decline.Font = Enum.Font.GothamBold
	decline.TextSize = 16
	decline.BackgroundTransparency = 0.2
	decline.Parent = modal

	local function closeModal()
		if activeInviteModal == modal then
			activeInviteModal = nil
		end
		modal:Destroy()
		refreshModalState()
	end

	accept.MouseButton1Click:Connect(function()
		PartyAction:FireServer("Accept", fromUserId)
		closeModal()
	end)
	decline.MouseButton1Click:Connect(function()
		PartyAction:FireServer("Decline", fromUserId)
		closeModal()
	end)

	-- auto close
	task.delay(tonumber(payload.expiresIn) or 20, function()
		if modal.Parent then closeModal() end
	end)
end)

leave.MouseButton1Click:Connect(function()
	PartyAction:FireServer("Leave")
end)

disband.MouseButton1Click:Connect(function()
	PartyAction:FireServer("Disband")
end)
