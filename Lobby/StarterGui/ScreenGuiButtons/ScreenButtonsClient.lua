local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent
local frame = screenGui:WaitForChild("Frame")
local SETTINGS_BUTTON_IMAGE = "rbxassetid://116594278084498"
local SETTINGS_BUTTON_HOTKEY = "L"

local CONTROL_GUIS = {
	"ProfileStats",
	"MissionsGui",
	"PartyGui",
	"InventoryGui",
	"Settings",
}

local requestCounters = {}
local hotkeyBindings = {}
local isPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
local getSettingsButtonLayout

local function findButtons(names)
	local buttons = {}

	for _, name in ipairs(names) do
		local candidate = frame:FindFirstChild(name)
		if candidate and candidate:IsA("GuiButton") then
			table.insert(buttons, candidate)
		end
	end

	return buttons
end

-- Settings button stays outside the shortcut grid so it can live on the left side.
local function ensureSettingsButton()
	local existing = screenGui:FindFirstChild("Settings") or frame:FindFirstChild("Settings")
	if existing and existing:IsA("GuiButton") then
		local anchorPoint, position, size = getSettingsButtonLayout()
		existing.Image = SETTINGS_BUTTON_IMAGE
		existing.Parent = screenGui
		existing.AnchorPoint = anchorPoint
		existing.Position = position
		existing.Size = size
		existing.LayoutOrder = 0

		local existingPlayerIcon = existing:FindFirstChild("PlayerIcon", true)
		if existingPlayerIcon then
			existingPlayerIcon:Destroy()
		end

		local existingHotKeyLabel = existing:FindFirstChild("HotKey", true)
		if existingHotKeyLabel and (existingHotKeyLabel:IsA("TextLabel") or existingHotKeyLabel:IsA("TextButton") or existingHotKeyLabel:IsA("TextBox")) then
			existingHotKeyLabel.Text = SETTINGS_BUTTON_HOTKEY
		end

		return existing
	end

	local template = findButtons({ "Events", "Inventory", "Missions", "Party" })[1]
	if not template then
		return nil
	end

	local anchorPoint, position, size = getSettingsButtonLayout()
	local button = template:Clone()
	button.Name = "Settings"
	button.LayoutOrder = 0
	button.Image = SETTINGS_BUTTON_IMAGE
	button.AnchorPoint = anchorPoint
	button.Position = position
	button.Size = size
	button.Parent = screenGui

	local playerIcon = button:FindFirstChild("PlayerIcon", true)
	if playerIcon then
		playerIcon:Destroy()
	end

	local hotKeyLabel = button:FindFirstChild("HotKey", true)
	if hotKeyLabel and (hotKeyLabel:IsA("TextLabel") or hotKeyLabel:IsA("TextButton") or hotKeyLabel:IsA("TextBox")) then
		hotKeyLabel.Text = SETTINGS_BUTTON_HOTKEY
	end

	return button
end

local function resolveGui(guiName, timeoutSeconds)
	local existing = playerGui:FindFirstChild(guiName)
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	if timeoutSeconds and timeoutSeconds > 0 then
		local waited = playerGui:WaitForChild(guiName, timeoutSeconds)
		if waited and waited:IsA("ScreenGui") then
			return waited
		end
	end

	return nil
end

getSettingsButtonLayout = function()
	local settingsGui = resolveGui("Settings", 0) or playerGui:WaitForChild("Settings", 2)
	if settingsGui and settingsGui:IsA("ScreenGui") then
		local settingsFrame = settingsGui:FindFirstChild("Frame")
		if settingsFrame and settingsFrame:IsA("Frame") then
			return settingsFrame.AnchorPoint, settingsFrame.Position, settingsFrame.Size
		end
	end

	return Vector2.new(0, 0), UDim2.new(0, 0, 0, 0), UDim2.fromOffset(72, 72)
end

local function sendRequest(guiName, action, timeoutSeconds)
	local targetGui = resolveGui(guiName, timeoutSeconds)
	if not targetGui then
		return
	end

	local nextCounter = (requestCounters[guiName] or 0) + 1
	requestCounters[guiName] = nextCounter

	targetGui:SetAttribute("ScreenButtonsAction", action)
	targetGui:SetAttribute("ScreenButtonsNonce", nextCounter)
end

local function isGuiOpen(guiName)
	local targetGui = resolveGui(guiName, 0)
	if not targetGui then
		return false
	end

	if guiName == "PartyGui" then
		local overlay = targetGui:FindFirstChild("overlay")
		return overlay and overlay:IsA("GuiObject") and overlay.Visible or false
	end

	return targetGui.Enabled
end

local function shouldHideButtons()
	if playerGui:GetAttribute("ShowScreenButtons") == false then
		return true
	end

	for _, inst in ipairs(playerGui:GetChildren()) do
		if inst ~= screenGui and inst:IsA("ScreenGui") and inst.Enabled then
			if inst:GetAttribute("Modal") == true then
				return true
			end

			if inst.Name == "PartyGui" then
				local overlay = inst:FindFirstChild("overlay")
				if overlay and overlay:IsA("GuiObject") and overlay.Visible then
					return true
				end
			end
		end
	end

	return false
end

local function openExclusive(guiName)
	if isGuiOpen(guiName) then
		sendRequest(guiName, "close")
		return
	end

	for _, otherGuiName in ipairs(CONTROL_GUIS) do
		if otherGuiName ~= guiName then
			sendRequest(otherGuiName, "close", 0)
		end
	end

	sendRequest(guiName, "open", 2)
end

local function connectButton(button, callback)
	if not button then
		return
	end

	button.Activated:Connect(callback)
end

local function connectButtons(buttons, callback)
	for _, button in ipairs(buttons) do
		connectButton(button, callback)
	end
end

local function setHotKeyVisibility(buttons)
	for _, button in ipairs(buttons) do
		for _, descendant in ipairs(button:GetDescendants()) do
			if descendant.Name == "HotKey" and descendant:IsA("GuiObject") then
				descendant.Visible = isPC
			end
		end
	end
end

local function getButtonHotKey(button)
	local hotKeyLabel = button:FindFirstChild("HotKey", true)
	if not hotKeyLabel then
		return nil
	end

	if not (hotKeyLabel:IsA("TextLabel") or hotKeyLabel:IsA("TextButton") or hotKeyLabel:IsA("TextBox")) then
		return nil
	end

	local keyText = tostring(hotKeyLabel.Text or ""):match("[%w]")
	if not keyText then
		return nil
	end

	local ok, keyCode = pcall(function()
		return Enum.KeyCode[string.upper(keyText)]
	end)

	if ok then
		return keyCode
	end

	return nil
end

local function registerHotKey(buttons, callback)
	if not isPC then
		return
	end

	for _, button in ipairs(buttons) do
		local keyCode = getButtonHotKey(button)
		if keyCode then
			hotkeyBindings[keyCode] = callback
		end
	end
end

local function showNotification(title, text)
	local ok, err = pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 3,
		})
	end)

	if not ok then
		warn("[ScreenButtonsClient] Notification failed:", err)
	end
end

local function setStandaloneButtonsVisible(buttons, visible)
	for _, button in ipairs(buttons) do
		button.Visible = visible
	end
end

local function applyProfileIcon()
	local profileButton = findButtons({ "Profile" })[1]
	if not profileButton then
		return
	end

	local playerIcon = profileButton:FindFirstChild("PlayerIcon", true)
	if not (playerIcon and playerIcon:IsA("ImageLabel")) then
		return
	end

	local ok, content = pcall(function()
		return Players:GetUserThumbnailAsync(
			player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size150x150
		)
	end)

	if ok then
		playerIcon.Image = content
	end
end

local settingsButtons = {}
local createdSettingsButton = ensureSettingsButton()
if createdSettingsButton then
	settingsButtons = { createdSettingsButton }
end
setHotKeyVisibility(settingsButtons)
connectButtons(settingsButtons, function()
	openExclusive("Settings")
end)
registerHotKey(settingsButtons, function()
	openExclusive("Settings")
end)

local missionsButtons = findButtons({ "Missions" })
setHotKeyVisibility(missionsButtons)
connectButtons(missionsButtons, function()
	openExclusive("MissionsGui")
end)
registerHotKey(missionsButtons, function()
	openExclusive("MissionsGui")
end)

local eventsButtons = findButtons({ "Events" })
setHotKeyVisibility(eventsButtons)
connectButtons(eventsButtons, function()
	showNotification("Events", "Events are not available yet.")
end)
registerHotKey(eventsButtons, function()
	showNotification("Events", "Events are not available yet.")
end)

local partyButtons = findButtons({ "Party" })
setHotKeyVisibility(partyButtons)
connectButtons(partyButtons, function()
	openExclusive("PartyGui")
end)
registerHotKey(partyButtons, function()
	openExclusive("PartyGui")
end)

local inventoryButtons = findButtons({ "Inventory" })
setHotKeyVisibility(inventoryButtons)
connectButtons(inventoryButtons, function()
	openExclusive("InventoryGui")
end)
registerHotKey(inventoryButtons, function()
	openExclusive("InventoryGui")
end)

local profileButtons = findButtons({ "Profile" })
setHotKeyVisibility(profileButtons)
connectButtons(profileButtons, function()
	openExclusive("ProfileStats")
end)
registerHotKey(profileButtons, function()
	openExclusive("ProfileStats")
end)

local loginRewardsButtons = findButtons({ "Login Rewards" })
setHotKeyVisibility(loginRewardsButtons)
connectButtons(loginRewardsButtons, function()
	showNotification("Login Rewards", "Login rewards are not available yet.")
end)
registerHotKey(loginRewardsButtons, function()
	showNotification("Login Rewards", "Login rewards are not available yet.")
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not isPC or gameProcessed then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	local callback = hotkeyBindings[input.KeyCode]
	if callback then
		callback()
	end
end)

applyProfileIcon()

local lastHidden = false
RunService.RenderStepped:Connect(function()
	local hide = shouldHideButtons()
	if hide ~= lastHidden then
		frame.Visible = not hide
		setStandaloneButtonsVisible(settingsButtons, not hide)
		lastHidden = hide
	end
end)
