local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = script.Parent
local frame = screenGui:WaitForChild("Frame")

local CONTROL_GUIS = {
	"MissionsGui",
	"PartyGui",
	"InventoryGui",
}

local requestCounters = {}
local hotkeyBindings = {}
local isPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled

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
		return targetGui:GetAttribute("Modal") == true
	end

	return targetGui.Enabled
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
			return
		end
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

local missionsButtons = findButtons({ "Events", "Missions" })
setHotKeyVisibility(missionsButtons)
connectButtons(missionsButtons, function()
	openExclusive("MissionsGui")
end)
registerHotKey(missionsButtons, function()
	openExclusive("MissionsGui")
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
	-- Placeholder until profile UI exists.
end)
registerHotKey(profileButtons, function()
	-- Placeholder until profile UI exists.
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
