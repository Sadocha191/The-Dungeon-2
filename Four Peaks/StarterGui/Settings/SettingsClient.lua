local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local gui = script.Parent
local root = gui:WaitForChild("Frame")
local icon = root:FindFirstChild("Settings")
local originalRootPosition = root.Position
local originalRootSize = root.Size

local DEFAULTS = {
	ShowFPSCounter = false,
	ShowScreenButtons = true,
	CameraZoomPreset = "Medium",
}

local SETTINGS_REMOTE_FUNCTION = "RF_GetPlayerSettings"
local SETTINGS_REMOTE_EVENT = "PlayerSettingsEvent"

local CAMERA_PRESETS = {
	{ id = "Close", label = "Close (12)", distance = 12 },
	{ id = "Medium", label = "Medium (20)", distance = 20 },
	{ id = "Far", label = "Far (28)", distance = 28 },
}

local CAMERA_PRESET_IDS = {}
for _, preset in ipairs(CAMERA_PRESETS) do
	CAMERA_PRESET_IDS[preset.id] = true
end

local lastSentSettings = {}

local function getSettingsRemoteFunction(): RemoteFunction?
	local remoteFunctions = ReplicatedStorage:WaitForChild("RemoteFunctions", 5)
	if not remoteFunctions then
		return nil
	end

	local remote = remoteFunctions:WaitForChild(SETTINGS_REMOTE_FUNCTION, 5)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end

	return nil
end

local function getSettingsRemoteEvent(): RemoteEvent?
	local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
	if not remoteEvents then
		return nil
	end

	local remote = remoteEvents:WaitForChild(SETTINGS_REMOTE_EVENT, 5)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	return nil
end

local function sanitizeSetting(name: string, value: any)
	if name == "ShowFPSCounter" or name == "ShowScreenButtons" then
		if typeof(value) == "boolean" then
			return value
		end
	elseif name == "CameraZoomPreset" then
		if typeof(value) == "string" and CAMERA_PRESET_IDS[value] then
			return value
		end
	end

	return DEFAULTS[name]
end

local function getSavedSettings()
	local settings = {}
	for name, defaultValue in pairs(DEFAULTS) do
		local currentValue = playerGui:GetAttribute(name)
		settings[name] = currentValue ~= nil and sanitizeSetting(name, currentValue) or defaultValue
	end

	local remote = getSettingsRemoteFunction()
	if not remote then
		return settings
	end

	local ok, savedSettings = pcall(function()
		return remote:InvokeServer()
	end)

	if not ok then
		warn("[SettingsClient] Failed to load saved settings:", savedSettings)
		return settings
	end

	if typeof(savedSettings) == "table" then
		for name in pairs(DEFAULTS) do
			settings[name] = sanitizeSetting(name, savedSettings[name])
		end
	end

	return settings
end

local settingsRemoteEvent = getSettingsRemoteEvent()

local function sendSettings(values: {[string]: any})
	if not settingsRemoteEvent then
		settingsRemoteEvent = getSettingsRemoteEvent()
	end

	if settingsRemoteEvent then
		settingsRemoteEvent:FireServer({
			type = "set",
			values = values,
		})
	end
end

local function addCorner(inst: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
	return corner
end

local function addStroke(inst: Instance, color: Color3, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Parent = inst
	return stroke
end

local function getCameraPresetIndex(id: string?): number
	for index, preset in ipairs(CAMERA_PRESETS) do
		if preset.id == id then
			return index
		end
	end
	return 2
end

local function applyCameraZoom()
	local preset = CAMERA_PRESETS[getCameraPresetIndex(playerGui:GetAttribute("CameraZoomPreset"))]
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = preset.distance
end

for name, value in pairs(getSavedSettings()) do
	local sanitizedValue = sanitizeSetting(name, value)
	playerGui:SetAttribute(name, sanitizedValue)
	lastSentSettings[name] = sanitizedValue
end

gui.Enabled = false
gui:SetAttribute("Modal", true)
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
root.BackgroundTransparency = 0.35
root.BorderSizePixel = 0
root.Active = true

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = originalRootPosition
panel.Size = UDim2.new(0, 560, 0, 430)
panel.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
panel.BorderSizePixel = 0
panel.Parent = root
addCorner(panel, 22)
addStroke(panel, Color3.fromRGB(88, 102, 128), 0.15)

local panelGradient = Instance.new("UIGradient")
panelGradient.Rotation = 90
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 24, 37)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 13, 20)),
})
panelGradient.Parent = panel

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(560, 430)
sizeConstraint.Parent = panel

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 88)
header.BackgroundTransparency = 1
header.Parent = panel

if icon and icon:IsA("ImageLabel") then
	icon.Parent = root
	icon.AnchorPoint = Vector2.new(0, 0)
	icon.Position = originalRootPosition
	icon.Size = originalRootSize
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ImageTransparency = 0
	icon.ZIndex = 3
end

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(84, 16)
title.Size = UDim2.new(1, -154, 0, 28)
title.Font = Enum.Font.GothamBlack
title.TextSize = 26
title.TextColor3 = Color3.fromRGB(244, 247, 252)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Settings"
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.fromOffset(84, 44)
subtitle.Size = UDim2.new(1, -170, 0, 34)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextColor3 = Color3.fromRGB(183, 191, 204)
subtitle.TextWrapped = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.Text = "Basic client options for the lobby UI and local quality-of-life settings."
subtitle.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -18, 0, 16)
closeButton.Size = UDim2.fromOffset(34, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(28, 35, 49)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 16
closeButton.TextColor3 = Color3.fromRGB(237, 241, 247)
closeButton.Text = "X"
closeButton.Parent = panel
addCorner(closeButton, 12)
addStroke(closeButton, Color3.fromRGB(86, 98, 120), 0.2)

local content = Instance.new("Frame")
content.BackgroundTransparency = 1
content.Position = UDim2.fromOffset(18, 96)
content.Size = UDim2.new(1, -36, 1, -156)
content.Parent = panel

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 12)
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.Parent = content

local function makeRow(titleText: string, descriptionText: string)
	local row = Instance.new("Frame")
	row.BackgroundColor3 = Color3.fromRGB(17, 23, 34)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 82)
	row.Parent = content
	addCorner(row, 18)
	addStroke(row, Color3.fromRGB(72, 84, 104), 0.24)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(18, 14)
	titleLabel.Size = UDim2.new(1, -170, 0, 22)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.fromRGB(244, 247, 252)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = titleText
	titleLabel.Parent = row

	-- Secondary copy keeps the option purpose readable without crowding the action button.
	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Position = UDim2.fromOffset(18, 38)
	descriptionLabel.Size = UDim2.new(1, -180, 0, 28)
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.TextSize = 12
	descriptionLabel.TextColor3 = Color3.fromRGB(178, 188, 202)
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
	descriptionLabel.Text = descriptionText
	descriptionLabel.Parent = row

	return row
end

local function styleActionButton(button: TextButton)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -16, 0.5, 0)
	button.Size = UDim2.fromOffset(118, 42)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	addCorner(button, 14)
	return addStroke(button, Color3.fromRGB(80, 94, 118), 0.15)
end

local function makeToggleRow(titleText: string, descriptionText: string, attributeName: string)
	local row = makeRow(titleText, descriptionText)

	local button = Instance.new("TextButton")
	button.Parent = row
	styleActionButton(button)

	local function sync()
		local enabled = playerGui:GetAttribute(attributeName) == true
		button.Text = enabled and "Enabled" or "Disabled"
		button.BackgroundColor3 = enabled and Color3.fromRGB(78, 171, 108) or Color3.fromRGB(55, 64, 81)
	end

	button.Activated:Connect(function()
		playerGui:SetAttribute(attributeName, not (playerGui:GetAttribute(attributeName) == true))
	end)

	playerGui:GetAttributeChangedSignal(attributeName):Connect(sync)
	sync()
end

local function makeChoiceRow(titleText: string, descriptionText: string, attributeName: string)
	local row = makeRow(titleText, descriptionText)

	local button = Instance.new("TextButton")
	button.Parent = row
	styleActionButton(button)
	button.BackgroundColor3 = Color3.fromRGB(56, 93, 156)

	local function sync()
		local preset = CAMERA_PRESETS[getCameraPresetIndex(playerGui:GetAttribute(attributeName))]
		button.Text = preset.label
	end

	button.Activated:Connect(function()
		local currentIndex = getCameraPresetIndex(playerGui:GetAttribute(attributeName))
		local nextIndex = currentIndex + 1
		if nextIndex > #CAMERA_PRESETS then
			nextIndex = 1
		end
		playerGui:SetAttribute(attributeName, CAMERA_PRESETS[nextIndex].id)
	end)

	playerGui:GetAttributeChangedSignal(attributeName):Connect(sync)
	sync()
end

makeToggleRow(
	"FPS Counter",
	"Show a live FPS readout in the top-right corner.",
	"ShowFPSCounter"
)

makeToggleRow(
	"Shortcut Buttons",
	"Show or hide the lobby shortcut bar without disabling keyboard hotkeys.",
	"ShowScreenButtons"
)

makeChoiceRow(
	"Camera Zoom",
	"Cycle the maximum zoom distance used in the lobby.",
	"CameraZoomPreset"
)

local footer = Instance.new("Frame")
footer.BackgroundTransparency = 1
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.Position = UDim2.new(0.5, 0, 1, -18)
footer.Size = UDim2.new(1, -36, 0, 44)
footer.Parent = panel

local resetButton = Instance.new("TextButton")
resetButton.Size = UDim2.fromOffset(138, 38)
resetButton.BackgroundColor3 = Color3.fromRGB(38, 47, 63)
resetButton.BorderSizePixel = 0
resetButton.Font = Enum.Font.GothamBold
resetButton.TextSize = 13
resetButton.TextColor3 = Color3.fromRGB(236, 240, 247)
resetButton.Text = "Reset Defaults"
resetButton.Parent = footer
addCorner(resetButton, 14)
addStroke(resetButton, Color3.fromRGB(93, 106, 128), 0.18)

local footerHint = Instance.new("TextLabel")
footerHint.BackgroundTransparency = 1
footerHint.AnchorPoint = Vector2.new(1, 0.5)
footerHint.Position = UDim2.new(1, 0, 0.5, 0)
footerHint.Size = UDim2.new(1, -156, 1, 0)
footerHint.Font = Enum.Font.Gotham
footerHint.TextSize = 12
footerHint.TextColor3 = Color3.fromRGB(155, 166, 183)
footerHint.TextXAlignment = Enum.TextXAlignment.Right
footerHint.Text = "Press Esc to close."
footerHint.Parent = footer

local function applyDefaults()
	for name, value in pairs(DEFAULTS) do
		playerGui:SetAttribute(name, value)
	end
end

local function persistSetting(name: string)
	local value = sanitizeSetting(name, playerGui:GetAttribute(name))
	if lastSentSettings[name] == value then
		return
	end

	lastSentSettings[name] = value
	sendSettings({
		[name] = value,
	})
end

local function openUI()
	gui.Enabled = true
	applyCameraZoom()
end

local function closeUI()
	gui.Enabled = false
end

local function toggleUI()
	if gui.Enabled then
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

closeButton.Activated:Connect(closeUI)
resetButton.Activated:Connect(applyDefaults)
root.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local x = input.Position.X
	local y = input.Position.Y
	local panelMin = panel.AbsolutePosition
	local panelMax = panelMin + panel.AbsoluteSize
	local clickedInsidePanel = x >= panelMin.X and x <= panelMax.X and y >= panelMin.Y and y <= panelMax.Y
	if not clickedInsidePanel then
		closeUI()
	end
end)

for name in pairs(DEFAULTS) do
	playerGui:GetAttributeChangedSignal(name):Connect(function()
		persistSetting(name)
	end)
end

playerGui:GetAttributeChangedSignal("CameraZoomPreset"):Connect(applyCameraZoom)
player.CharacterAdded:Connect(function()
	task.defer(applyCameraZoom)
end)

gui:GetAttributeChangedSignal("ScreenButtonsNonce"):Connect(handleScreenButtonsRequest)
handleScreenButtonsRequest()
applyCameraZoom()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape and gui.Enabled then
		closeUI()
	end
end)
