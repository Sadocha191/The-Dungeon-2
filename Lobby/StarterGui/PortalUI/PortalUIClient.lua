local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local screenGui = script:FindFirstAncestorOfClass("ScreenGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenLevelSelect = remoteEvents:WaitForChild("OpenLevelSelect")
local RequestLevelTeleport = remoteEvents:WaitForChild("RequestLevelTeleport")
local TeleportStatus = remoteEvents:FindFirstChild("TeleportStatus")
local PlayerProgressEvent = remoteEvents:FindFirstChild("PlayerProgressEvent") or remoteEvents:WaitForChild("PlayerProgressEvent", 5)

local moduleFolder = (
	ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
)

if not screenGui then
	warn("[PortalUIClient] ScreenGui ancestor not found.")
	return
end

if not moduleFolder then
	warn("[PortalUIClient] ModuleScripts folder not found in ReplicatedStorage.")
	return
end

local Levels = require(moduleFolder:WaitForChild("Levels"))

local IDLE_STROKE = Color3.fromRGB(92, 92, 92)
local SELECTED_STROKE = Color3.fromRGB(245, 245, 245)
local ERROR_PREFIX = "[Unavailable] "

local refs = nil
local selectedEntry = nil
local selectedButton = nil
local activeStatusMessage = nil
local playerLevelRecords = {}
local entryLookup = {}
local buttonEntries = {}
local buttonConnections = {}

local function normalize(value)
	if typeof(value) ~= "string" then
		return ""
	end

	return string.lower((value:gsub("[%s%p_]+", "")))
end

local function registerLookup(rawValue, entry)
	local key = normalize(rawValue)
	if key ~= "" then
		entryLookup[key] = entry
	end
end

local function buildEntryLookup()
	table.clear(entryLookup)

	for _, entry in ipairs(Levels.GetAll()) do
		registerLookup(entry.key, entry)
		registerLookup(entry.instanceName, entry)
		registerLookup(entry.name, entry)

		if typeof(entry.aliases) == "table" then
			for _, alias in ipairs(entry.aliases) do
				registerLookup(alias, entry)
			end
		end
	end
end

local function waitForGuiObject(parent, name)
	local child = parent:FindFirstChild(name) or parent:WaitForChild(name, 5)
	if child and child:IsA("GuiObject") then
		return child
	end
	return nil
end

local function waitForScrollingFrame(parent, name)
	local child = parent:FindFirstChild(name) or parent:WaitForChild(name, 5)
	if child and child:IsA("ScrollingFrame") then
		return child
	end
	return nil
end

local function waitForTextLabel(parent, name)
	local child = parent:FindFirstChild(name) or parent:WaitForChild(name, 5)
	if child and child:IsA("TextLabel") then
		return child
	end
	return nil
end

local function waitForGuiButton(parent, name)
	local child = parent:FindFirstChild(name) or parent:WaitForChild(name, 5)
	if child and child:IsA("GuiButton") then
		return child
	end
	return nil
end

local function setInteractable(guiObject, isInteractable)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return
	end

	pcall(function()
		guiObject.Active = isInteractable
	end)

	pcall(function()
		guiObject.Interactable = isInteractable
	end)
end

local function ensureDescriptionLabel(descriptionFrame)
	local label = descriptionFrame:FindFirstChild("LevelDescription")
	if label and label:IsA("TextLabel") then
		return label
	end

	local fallback = descriptionFrame:FindFirstChild("LevelDescriptionRuntime")
	if fallback and fallback:IsA("TextLabel") then
		return fallback
	end

	local runtime = Instance.new("TextLabel")
	runtime.Name = "LevelDescriptionRuntime"
	runtime.BackgroundTransparency = 1
	runtime.BorderSizePixel = 0
	runtime.Position = UDim2.fromOffset(8, 8)
	runtime.Size = UDim2.new(1, -16, 1, -16)
	runtime.TextWrapped = true
	runtime.TextXAlignment = Enum.TextXAlignment.Left
	runtime.TextYAlignment = Enum.TextYAlignment.Top
	runtime.TextColor3 = Color3.fromRGB(255, 255, 255)
	runtime.Font = Enum.Font.Arcade
	runtime.TextSize = 24
	runtime.ZIndex = 10
	runtime.Parent = descriptionFrame
	return runtime
end

local function resolveRefs()
	if refs and refs.gui.Parent == player:WaitForChild("PlayerGui") then
		return refs
	end

	local root = waitForGuiObject(screenGui, "UI")
	local background = root and waitForGuiObject(root, "Background") or nil
	local levelSelection = background and waitForGuiObject(background, "LevelSelection") or nil
	local levelList = levelSelection and waitForScrollingFrame(levelSelection, "ScrollingFrame") or nil
	local infoFrame = background and waitForGuiObject(background, "LevelInfo") or nil
	local descriptionFrame = infoFrame and waitForScrollingFrame(infoFrame, "ScrollingFrame") or nil
	local descriptionLabel = descriptionFrame and ensureDescriptionLabel(descriptionFrame) or nil
	local levelName = infoFrame and waitForTextLabel(infoFrame, "LevelName") or nil
	local highscoreCounter = infoFrame and waitForTextLabel(infoFrame, "HighscoreCounter") or nil
	local speedrunCounter = infoFrame and waitForTextLabel(infoFrame, "SpeedrunCounter") or nil
	local singleButton = infoFrame and waitForGuiButton(infoFrame, "Single") or nil
	local partyButton = infoFrame and waitForGuiButton(infoFrame, "Party") or nil
	local closeButton = background and waitForGuiButton(background, "CloseButton") or nil

	if not (root and background and levelList and infoFrame and descriptionFrame and descriptionLabel and levelName and highscoreCounter and speedrunCounter and singleButton and partyButton and closeButton) then
		warn("[PortalUIClient] PortalUI hierarchy is incomplete.")
		return nil
	end

	screenGui.Enabled = true
	screenGui.ResetOnSpawn = false
	screenGui:SetAttribute("Modal", false)
	root.Visible = false
	background.Visible = false

	if root:IsA("CanvasGroup") then
		root.GroupTransparency = 1
	end

	if background:IsA("CanvasGroup") then
		background.GroupTransparency = 1
	end

	setInteractable(root, true)
	setInteractable(background, true)
	setInteractable(levelSelection, true)
	setInteractable(levelList, true)
	setInteractable(infoFrame, true)
	setInteractable(descriptionFrame, true)
	setInteractable(descriptionLabel, false)
	setInteractable(levelName, false)
	setInteractable(highscoreCounter, false)
	setInteractable(speedrunCounter, false)
	setInteractable(singleButton, true)
	setInteractable(partyButton, true)
	setInteractable(closeButton, true)

	descriptionLabel.TextWrapped = true
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top

	refs = {
		gui = screenGui,
		root = root,
		background = background,
		levelList = levelList,
		infoFrame = infoFrame,
		descriptionFrame = descriptionFrame,
		descriptionLabel = descriptionLabel,
		levelName = levelName,
		highscoreCounter = highscoreCounter,
		speedrunCounter = speedrunCounter,
		singleButton = singleButton,
		partyButton = partyButton,
		closeButton = closeButton,
	}

	return refs
end

local function setPortalVisible(isVisible)
	local currentRefs = resolveRefs()
	if not currentRefs then
		return
	end

	currentRefs.gui.Enabled = true
	currentRefs.gui.DisplayOrder = 100
	currentRefs.gui:SetAttribute("Modal", isVisible)
	currentRefs.root.Visible = isVisible
	currentRefs.background.Visible = isVisible

	if currentRefs.root:IsA("CanvasGroup") then
		currentRefs.root.GroupTransparency = isVisible and 0 or 1
	end

	if currentRefs.background:IsA("CanvasGroup") then
		currentRefs.background.GroupTransparency = isVisible and 0 or 1
	end
end

local function resetScreenGuiState()
	setPortalVisible(false)
end

local function cacheLevelRecords(raw)
	table.clear(playerLevelRecords)
	if typeof(raw) ~= "table" then
		return
	end

	for levelKey, record in pairs(raw) do
		if typeof(levelKey) == "string" and typeof(record) == "table" then
			local highscore = math.max(0, math.floor(tonumber(record.highscore) or 0))
			local speedrun = tonumber(record.speedrun)
			playerLevelRecords[levelKey] = {
				highscore = highscore,
				speedrun = (speedrun and speedrun > 0) and speedrun or nil,
			}
			playerLevelRecords[normalize(levelKey)] = playerLevelRecords[levelKey]
		end
	end
end

local function getLevelRecord(entry)
	if typeof(entry) ~= "table" then
		return nil
	end

	local candidates = {
		entry.key,
		entry.instanceName,
		entry.name,
	}

	if typeof(entry.aliases) == "table" then
		for _, alias in ipairs(entry.aliases) do
			table.insert(candidates, alias)
		end
	end

	for _, candidate in ipairs(candidates) do
		if typeof(candidate) == "string" and candidate ~= "" then
			local direct = playerLevelRecords[candidate]
			if direct then
				return direct
			end

			local normalized = playerLevelRecords[normalize(candidate)]
			if normalized then
				return normalized
			end
		end
	end

	return nil
end

local function formatHighscore(entry)
	if typeof(entry) ~= "table" then
		return "0"
	end

	local value = entry.highscore
	if typeof(value) == "number" then
		return tostring(math.floor(value))
	end
	if typeof(value) == "string" and value ~= "" then
		return value
	end

	return "0"
end

local function formatSpeedrun(entry)
	if typeof(entry) ~= "table" then
		return "00:00.00"
	end

	local value = entry.speedrun
	if typeof(value) == "number" then
		local total = math.max(0, value)
		local whole = math.floor(total)
		local minutes = math.floor(whole / 60)
		local seconds = whole % 60
		local hundredths = math.floor((total - whole) * 100 + 0.5)
		if hundredths >= 100 then
			hundredths = 0
			seconds += 1
		end
		if seconds >= 60 then
			seconds -= 60
			minutes += 1
		end
		return string.format("%02d:%02d.%02d", minutes, seconds, hundredths)
	end
	if typeof(value) == "string" and value ~= "" then
		return value
	end

	return "00:00.00"
end

local function getDescription(entry, statusMessage)
	local description = "Select a level to see its details."
	if typeof(entry) == "table" and typeof(entry.description) == "string" and entry.description ~= "" then
		description = entry.description
	end

	if typeof(statusMessage) == "string" and statusMessage ~= "" then
		return string.format("%s\n\n%s", statusMessage, description)
	end

	if typeof(entry) == "table" and typeof(entry.placeId) ~= "number" then
		return string.format("%s%s\n\n%s", ERROR_PREFIX, "This level is not available yet.", description)
	end

	return description
end

local function updateDescriptionCanvas()
	local currentRefs = resolveRefs()
	if not currentRefs then
		return
	end

	task.defer(function()
		local label = currentRefs.descriptionLabel
		local frame = currentRefs.descriptionFrame
		if not label or not label.Parent or not frame or not frame.Parent then
			return
		end

		local horizontalPadding = math.max(8, label.Position.X.Offset * 2)
		local targetHeight = math.max(label.TextBounds.Y, frame.AbsoluteSize.Y - 8)
		label.Size = UDim2.new(1, -horizontalPadding, 0, targetHeight)
		frame.CanvasSize = UDim2.fromOffset(0, math.max(label.TextBounds.Y + 8, frame.AbsoluteSize.Y))
	end)
end

local function ensureSelectionStroke(button)
	local stroke = button:FindFirstChild("PortalSelectionStroke")
	if stroke and stroke:IsA("UIStroke") then
		return stroke
	end

	stroke = Instance.new("UIStroke")
	stroke.Name = "PortalSelectionStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = IDLE_STROKE
	stroke.Thickness = 2
	stroke.Transparency = 0.05
	stroke.Parent = button
	return stroke
end

local function applySelectionVisuals()
	for button in pairs(buttonEntries) do
		if button and button.Parent then
			local stroke = ensureSelectionStroke(button)
			if button == selectedButton then
				stroke.Color = SELECTED_STROKE
				stroke.Thickness = 4
			else
				stroke.Color = IDLE_STROKE
				stroke.Thickness = 2
			end
		end
	end
end

local function renderSelectedEntry(statusMessage)
	local currentRefs = resolveRefs()
	if not currentRefs then
		return
	end

	if typeof(selectedEntry) ~= "table" then
		currentRefs.levelName.Text = "Level Name"
		currentRefs.highscoreCounter.Text = "0"
		currentRefs.speedrunCounter.Text = "00:00.00"
		currentRefs.descriptionLabel.Text = "Select a level to see its details."
		updateDescriptionCanvas()
		return
	end

	local record = getLevelRecord(selectedEntry)
	currentRefs.levelName.Text = tostring(selectedEntry.name or selectedEntry.key or "Level")
	currentRefs.highscoreCounter.Text = formatHighscore((record and record.highscore ~= nil) and record or selectedEntry)
	currentRefs.speedrunCounter.Text = formatSpeedrun((record and record.speedrun ~= nil) and record or selectedEntry)
	currentRefs.descriptionLabel.Text = getDescription(selectedEntry, statusMessage)
	updateDescriptionCanvas()
end

local function resolveEntryForButton(button)
	local byName = entryLookup[normalize(button.Name)]
	if byName then
		return byName
	end

	local textLabel = button:FindFirstChild("LevelName")
	if textLabel and textLabel:IsA("TextLabel") then
		return entryLookup[normalize(textLabel.Text)]
	end

	if button:IsA("TextButton") then
		return entryLookup[normalize(button.Text)]
	end

	return nil
end

local function selectEntry(entry, button)
	selectedEntry = entry
	selectedButton = button
	activeStatusMessage = nil
	applySelectionVisuals()
	renderSelectedEntry(nil)
end

local function bindLevelButton(button, entry)
	buttonEntries[button] = entry
	button.AutoButtonColor = true
	setInteractable(button, true)

	local childLabel = button:FindFirstChild("LevelName")
	if childLabel and childLabel:IsA("TextLabel") and typeof(entry.name) == "string" then
		childLabel.Text = entry.name
	end

	if buttonConnections[button] then
		return
	end

	buttonConnections[button] = true
	button.Activated:Connect(function()
		print("[PortalUIClient] Level selected:", tostring(entry.key))
		selectEntry(entry, button)
	end)
end

local function refreshLevelButtons()
	local currentRefs = resolveRefs()
	if not currentRefs then
		return
	end

	table.clear(buttonEntries)

	local fallbackEntry = nil
	local fallbackButton = nil

	for _, child in ipairs(currentRefs.levelList:GetChildren()) do
		if not child:IsA("GuiButton") then
			continue
		end

		local entry = resolveEntryForButton(child)
		if not entry then
			continue
		end

		bindLevelButton(child, entry)

		if not fallbackEntry then
			fallbackEntry = entry
			fallbackButton = child
		end

		if selectedEntry == entry then
			fallbackEntry = entry
			fallbackButton = child
		end
	end

	if fallbackEntry and fallbackButton then
		selectEntry(fallbackEntry, fallbackButton)
	else
		selectedEntry = nil
		selectedButton = nil
		renderSelectedEntry(nil)
	end
end

local function messageForFailure(reason)
	if reason == "no_party" then
		return "Party mode requires an active party."
	elseif reason == "not_leader" then
		return "Only the party leader can start a party run."
	elseif reason == "party_too_small" then
		return "Your party needs at least two online players."
	elseif reason == "party_missing" then
		return "Party service is unavailable right now."
	elseif reason == "level_unavailable" then
		return ERROR_PREFIX .. "This level does not have a placeId yet."
	elseif reason == "unknown_level" then
		return "The selected level could not be found."
	end

	return "Teleport failed. Try again."
end

local function closeUI()
	setPortalVisible(false)
end

local function requestTeleport(mode)
	if typeof(selectedEntry) ~= "table" then
		activeStatusMessage = "Select a level first."
		renderSelectedEntry(activeStatusMessage)
		return
	end

	if typeof(selectedEntry.placeId) ~= "number" then
		activeStatusMessage = ERROR_PREFIX .. "This level is not available yet."
		renderSelectedEntry(activeStatusMessage)
		return
	end

	activeStatusMessage = nil
	RequestLevelTeleport:FireServer(selectedEntry.key, mode)
	closeUI()
end

local fixedControlsBound = false
local function bindFixedControls()
	local currentRefs = resolveRefs()
	if not currentRefs or fixedControlsBound then
		return
	end

	fixedControlsBound = true

	currentRefs.closeButton.Activated:Connect(function()
		print("[PortalUIClient] Close button")
		closeUI()
	end)

	currentRefs.singleButton.Activated:Connect(function()
		print("[PortalUIClient] Single button")
		requestTeleport("Single")
	end)

	currentRefs.partyButton.Activated:Connect(function()
		print("[PortalUIClient] Party button")
		requestTeleport("Multi")
	end)

	currentRefs.descriptionFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateDescriptionCanvas)
	currentRefs.descriptionLabel:GetPropertyChangedSignal("Text"):Connect(updateDescriptionCanvas)
end

local function openUI()
	if not resolveRefs() then
		return
	end

	bindFixedControls()
	if PlayerProgressEvent and PlayerProgressEvent:IsA("RemoteEvent") then
		PlayerProgressEvent:FireServer({ type = "requestSync" })
	end
	activeStatusMessage = nil
	refreshLevelButtons()
	setPortalVisible(true)
end

local function resolvePortalPart()
	local ws = workspace
	local portalModel = ws:FindFirstChild("Portal") or ws:FindFirstChild("PortalModel")
	if portalModel and portalModel:IsA("Model") then
		local portalPart = portalModel:FindFirstChild("PortalTeleport", true)
		if portalPart and portalPart:IsA("BasePart") then
			return portalPart
		end
	end

	for _, descendant in ipairs(ws:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "PortalTeleport" then
			return descendant
		end
	end

	return nil
end

local function isPortalPrompt(prompt, triggeredPlayer)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end

	if typeof(triggeredPlayer) == "Instance" and triggeredPlayer:IsA("Player") and triggeredPlayer ~= player then
		return false
	end

	local portalPart = resolvePortalPart()
	if portalPart and prompt:IsDescendantOf(portalPart) then
		return true
	end

	if prompt.Name == "PortalPrompt" then
		return true
	end

	local actionText = string.lower(tostring(prompt.ActionText or ""))
	local objectText = string.lower(tostring(prompt.ObjectText or ""))
	if objectText == "portal" and actionText == "select level" then
		return true
	end

	return false
end

buildEntryLookup()
resetScreenGuiState()
resolveRefs()

ProximityPromptService.PromptShown:Connect(function(prompt)
	if not isPortalPrompt(prompt, nil) then
		return
	end

	print("[PortalUIClient] Portal prompt shown:", prompt:GetFullName())
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
	if not isPortalPrompt(prompt, triggeredPlayer) then
		return
	end

	print("[PortalUIClient] Opening from local portal prompt:", prompt:GetFullName())
	openUI()
end)

OpenLevelSelect.OnClientEvent:Connect(function()
	print("[PortalUIClient] Opening from OpenLevelSelect")
	openUI()
end)

if PlayerProgressEvent and PlayerProgressEvent:IsA("RemoteEvent") then
	PlayerProgressEvent.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or payload.type ~= "progress" then
			return
		end

		cacheLevelRecords(payload.levelRecords)
		if selectedEntry ~= nil then
			renderSelectedEntry(activeStatusMessage)
		end
	end)
end

if TeleportStatus and TeleportStatus:IsA("RemoteEvent") then
	TeleportStatus.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or payload.type ~= "failed" then
			return
		end

		openUI()
		activeStatusMessage = messageForFailure(tostring(payload.reason or ""))
		renderSelectedEntry(activeStatusMessage)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.KeyCode ~= Enum.KeyCode.Escape then
		return
	end

	local currentRefs = resolveRefs()
	if currentRefs and currentRefs.root.Visible then
		closeUI()
	end
end)

print("[PortalUIClient] Ready")
