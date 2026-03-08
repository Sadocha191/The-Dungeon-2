-- LOCALSCRIPT: LevelSelectUI.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/LevelSelectUI (LocalScript)
-- CO: centralne okno wyboru poziomu w stylu lobby party UI

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenLevelSelect = remoteEvents:WaitForChild("OpenLevelSelect")
local RequestLevelTeleport = remoteEvents:WaitForChild("RequestLevelTeleport")
local TeleportStatus = remoteEvents:FindFirstChild("TeleportStatus")

local moduleFolder = (
	ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
)
local Levels = require(moduleFolder:WaitForChild("Levels"))

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

local gui = Instance.new("ScreenGui")
gui.Name = "LevelSelectUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = pg

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.35
overlay.BorderSizePixel = 0
overlay.Active = true
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(980, 560)
panel.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
panel.BorderSizePixel = 0
panel.Parent = overlay
addCorner(panel, 16)
addStroke(panel, Color3.fromRGB(40, 40, 48))

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(24, 16)
title.Size = UDim2.new(1, -160, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(245, 245, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Select Level"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(24, 44)
subtitle.Size = UDim2.new(1, -180, 0, 18)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = Color3.fromRGB(190, 190, 190)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Text = "Choose a dungeon and decide whether you want to play solo or with your party."
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

local listPanel = Instance.new("Frame")
listPanel.Size = UDim2.new(0.52, -8, 1, 0)
listPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
listPanel.BackgroundTransparency = 0.08
listPanel.Parent = body
styleCard(listPanel)

local listTitle = Instance.new("TextLabel")
listTitle.BackgroundTransparency = 1
listTitle.Position = UDim2.fromOffset(16, 16)
listTitle.Size = UDim2.new(1, -32, 0, 20)
listTitle.Font = Enum.Font.GothamBold
listTitle.TextSize = 16
listTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
listTitle.TextXAlignment = Enum.TextXAlignment.Left
listTitle.Text = "Available Levels"
listTitle.Parent = listPanel

local listHint = Instance.new("TextLabel")
listHint.BackgroundTransparency = 1
listHint.Position = UDim2.fromOffset(16, 38)
listHint.Size = UDim2.new(1, -32, 0, 16)
listHint.Font = Enum.Font.Gotham
listHint.TextSize = 12
listHint.TextColor3 = Color3.fromRGB(190, 190, 190)
listHint.TextXAlignment = Enum.TextXAlignment.Left
listHint.Text = "Select the dungeon you want to enter."
listHint.Parent = listPanel

local levelList = Instance.new("ScrollingFrame")
levelList.Position = UDim2.fromOffset(16, 66)
levelList.Size = UDim2.new(1, -32, 1, -82)
levelList.BackgroundTransparency = 1
levelList.BorderSizePixel = 0
levelList.ScrollBarThickness = 6
levelList.AutomaticCanvasSize = Enum.AutomaticSize.Y
levelList.CanvasSize = UDim2.fromOffset(0, 0)
levelList.Parent = listPanel

local levelLayout = Instance.new("UIListLayout")
levelLayout.Padding = UDim.new(0, 10)
levelLayout.Parent = levelList

local detailsPanel = Instance.new("Frame")
detailsPanel.Size = UDim2.new(0.48, -8, 1, 0)
detailsPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
detailsPanel.BackgroundTransparency = 0.08
detailsPanel.Parent = body
styleCard(detailsPanel)

local detailsTitle = Instance.new("TextLabel")
detailsTitle.BackgroundTransparency = 1
detailsTitle.Position = UDim2.fromOffset(16, 16)
detailsTitle.Size = UDim2.new(1, -32, 0, 20)
detailsTitle.Font = Enum.Font.GothamBold
detailsTitle.TextSize = 16
detailsTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
detailsTitle.TextXAlignment = Enum.TextXAlignment.Left
detailsTitle.Text = "Level Details"
detailsTitle.Parent = detailsPanel

local selectedName = Instance.new("TextLabel")
selectedName.BackgroundTransparency = 1
selectedName.Position = UDim2.fromOffset(16, 48)
selectedName.Size = UDim2.new(1, -32, 0, 24)
selectedName.Font = Enum.Font.GothamBold
selectedName.TextSize = 18
selectedName.TextColor3 = Color3.fromRGB(245, 245, 245)
selectedName.TextXAlignment = Enum.TextXAlignment.Left
selectedName.Text = "No level selected"
selectedName.Parent = detailsPanel

local selectedMeta = Instance.new("TextLabel")
selectedMeta.BackgroundTransparency = 1
selectedMeta.Position = UDim2.fromOffset(16, 76)
selectedMeta.Size = UDim2.new(1, -32, 0, 16)
selectedMeta.Font = Enum.Font.Gotham
selectedMeta.TextSize = 12
selectedMeta.TextColor3 = Color3.fromRGB(190, 190, 190)
selectedMeta.TextXAlignment = Enum.TextXAlignment.Left
selectedMeta.Text = "Level key: -"
selectedMeta.Parent = detailsPanel

local selectedDesc = Instance.new("TextLabel")
selectedDesc.BackgroundTransparency = 1
selectedDesc.Position = UDim2.fromOffset(16, 108)
selectedDesc.Size = UDim2.new(1, -32, 0, 72)
selectedDesc.Font = Enum.Font.Gotham
selectedDesc.TextSize = 13
selectedDesc.TextColor3 = Color3.fromRGB(210, 210, 210)
selectedDesc.TextWrapped = true
selectedDesc.TextXAlignment = Enum.TextXAlignment.Left
selectedDesc.TextYAlignment = Enum.TextYAlignment.Top
selectedDesc.Text = "Choose a level on the left, then launch it in singleplayer or multiplayer mode."
selectedDesc.Parent = detailsPanel

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(16, 194)
status.Size = UDim2.new(1, -32, 0, 48)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(190, 190, 190)
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = "Single starts a solo run. Multiplayer requires you to be the party leader."
status.Parent = detailsPanel

local footer = Instance.new("Frame")
footer.Position = UDim2.new(0, 16, 1, -52)
footer.Size = UDim2.new(1, -32, 0, 36)
footer.BackgroundTransparency = 1
footer.Parent = detailsPanel

local singleBtn = makeActionButton(
	footer,
	"Single",
	UDim2.new(0.5, -8, 1, 0),
	UDim2.new(0, 0, 0, 0),
	Color3.fromRGB(60, 140, 255),
	Color3.fromRGB(82, 157, 255)
)

local multiBtn = makeActionButton(
	footer,
	"Multiplayer",
	UDim2.new(0.5, -8, 1, 0),
	UDim2.new(0.5, 8, 0, 0),
	Color3.fromRGB(28, 28, 36),
	Color3.fromRGB(38, 38, 48)
)

local selectedEntry = nil
local selectedButton: TextButton? = nil
local levelButtons = {}

local function clearList()
	for _, child in ipairs(levelList:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
	levelButtons = {}
	selectedButton = nil
end

local function setStatus(message: string, color: Color3?)
	status.Text = message
	status.TextColor3 = color or Color3.fromRGB(190, 190, 190)
end

local function applySelectedState()
	for button, stroke in pairs(levelButtons) do
		local isSelected = button == selectedButton
		stroke.Color = isSelected and Color3.fromRGB(96, 165, 250) or Color3.fromRGB(40, 40, 48)
		stroke.Thickness = isSelected and 2 or 1
	end
end

local function selectEntry(entry, button)
	selectedEntry = entry
	selectedButton = button
	selectedName.Text = tostring(entry.name or entry.key or "Level")
	selectedMeta.Text = ("Level key: %s"):format(tostring(entry.key or "-"))
	selectedDesc.Text = "Choose how you want to enter this dungeon. Single teleports only you. Multiplayer teleports your whole online party."
	setStatus("Single starts a solo run. Multiplayer requires you to be the party leader.")
	applySelectedState()
end

local function makeEmptyState(titleText: string, descText: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 96)
	row.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	row.BackgroundTransparency = 0.08
	row.Parent = levelList
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

local function rebuildList()
	clearList()
	selectedEntry = nil
	selectedName.Text = "No level selected"
	selectedMeta.Text = "Level key: -"
	selectedDesc.Text = "Choose a level on the left, then launch it in singleplayer or multiplayer mode."

	local entries = Levels.GetAll()
	if #entries == 0 then
		makeEmptyState("No levels available.", "Add entries in ReplicatedStorage.ModuleScripts.Levels to populate this menu.")
		setStatus("No levels are available right now.", Color3.fromRGB(220, 180, 120))
		return
	end

	for _, entry in ipairs(entries) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, 0, 0, 64)
		button.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
		button.BackgroundTransparency = 0.08
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = levelList
		addCorner(button, 12)

		local stroke = addStroke(button, Color3.fromRGB(40, 40, 48))
		levelButtons[button] = stroke

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.fromOffset(16, 12)
		nameLabel.Size = UDim2.new(1, -32, 0, 20)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 14
		nameLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = tostring(entry.name or entry.key or "Level")
		nameLabel.Parent = button

		local keyLabel = Instance.new("TextLabel")
		keyLabel.BackgroundTransparency = 1
		keyLabel.Position = UDim2.fromOffset(16, 34)
		keyLabel.Size = UDim2.new(1, -32, 0, 14)
		keyLabel.Font = Enum.Font.Gotham
		keyLabel.TextSize = 12
		keyLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
		keyLabel.TextXAlignment = Enum.TextXAlignment.Left
		keyLabel.Text = ("Key: %s"):format(tostring(entry.key or "-"))
		keyLabel.Parent = button

		addHover(button, button.BackgroundColor3, Color3.fromRGB(28, 28, 36))
		button.MouseButton1Click:Connect(function()
			selectEntry(entry, button)
		end)
	end

	local firstButton = next(levelButtons)
	if firstButton then
		selectEntry(entries[1], firstButton)
	end
end

local function closeUI()
	gui.Enabled = false
end

local function requestTeleport(mode: string)
	if not selectedEntry or typeof(selectedEntry.key) ~= "string" then
		setStatus("Select a level first.", Color3.fromRGB(220, 180, 120))
		return
	end

	RequestLevelTeleport:FireServer(selectedEntry.key, mode)
	closeUI()
end

local function openUI()
	rebuildList()
	gui.Enabled = true
end

closeBtn.MouseButton1Click:Connect(closeUI)
singleBtn.MouseButton1Click:Connect(function()
	requestTeleport("Single")
end)
multiBtn.MouseButton1Click:Connect(function()
	requestTeleport("Multi")
end)

OpenLevelSelect.OnClientEvent:Connect(openUI)

if TeleportStatus and TeleportStatus:IsA("RemoteEvent") then
	TeleportStatus.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end

		if payload.type == "failed" then
			gui.Enabled = true

			local reason = tostring(payload.reason or "")
			local message = "Teleport failed. Try again."
			if reason == "no_party" then
				message = "Teleport failed: you need a party for multiplayer."
			elseif reason == "not_leader" then
				message = "Teleport failed: only the party leader can start multiplayer."
			elseif reason == "party_too_small" then
				message = "Teleport failed: your party needs at least 2 online players."
			elseif reason == "party_missing" then
				message = "Teleport failed: party service is unavailable."
			end

			setStatus(message, Color3.fromRGB(220, 140, 140))
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)

print("[LevelSelectUI] Ready")
