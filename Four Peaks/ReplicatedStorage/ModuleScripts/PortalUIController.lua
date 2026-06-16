-- Portal level select client.
-- Drives the PortalUI built in StarterGui instead of generating the window in code.

local PortalUIController = {}
local started = false
local preferredGui: ScreenGui? = nil
local cachedPortalPart: BasePart? = nil

function PortalUIController.Start(options)
	if typeof(options) == "Instance" and options:IsA("ScreenGui") then
		preferredGui = options
	elseif typeof(options) == "table" then
		local gui = options.gui
		if gui and gui:IsA("ScreenGui") then
			preferredGui = gui
		end
	end

	if started then
		return
	end
	started = true

	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TextService = game:GetService("TextService")
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

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
	local Levels = require(moduleFolder:WaitForChild("Levels"))

	local SELECTED_STROKE = Color3.fromRGB(240, 240, 240)
	local HOVER_STROKE = Color3.fromRGB(170, 170, 170)
	local IDLE_STROKE = Color3.fromRGB(92, 92, 92)
	local ERROR_PREFIX = "[Unavailable] "

	type PortalRefs = {
		gui: ScreenGui,
		root: GuiObject,
		background: GuiObject,
		levelList: ScrollingFrame,
		infoFrame: GuiObject,
		descriptionFrame: ScrollingFrame,
		descriptionLabel: TextLabel,
		levelName: TextLabel,
		highscoreCounter: TextLabel,
		speedrunCounter: TextLabel,
		singleButton: GuiButton,
		partyButton: GuiButton,
		closeButton: GuiButton,
	}

	type ButtonState = {
		stroke: UIStroke,
		scale: UIScale,
		baseBackgroundTransparency: number,
		baseImageTransparency: number?,
		baseImageColor3: Color3?,
	}

	local refs: PortalRefs? = nil
	local fixedControlsBound = false
	local buttonStates: { [GuiButton]: ButtonState } = {}
	local buttonEntries: { [GuiButton]: any } = {}
	local buttonConnections: { [GuiButton]: boolean } = {}
	local entryLookup: { [string]: any } = {}
	local playerLevelRecords: { [string]: any } = {}
	local selectedEntry = nil
	local selectedButton: GuiButton? = nil
	local activeStatusMessage: string? = nil

	local function setPortalVisible(currentRefs: PortalRefs, isVisible: boolean)
		currentRefs.gui.Enabled = true
		currentRefs.gui:SetAttribute("Modal", isVisible)
		currentRefs.root.Visible = isVisible
		currentRefs.background.Visible = isVisible

		if currentRefs.root:IsA("CanvasGroup") then
			currentRefs.root.GroupTransparency = isVisible and 0 or 1
		end

		if currentRefs.background:IsA("CanvasGroup") then
			currentRefs.background.GroupTransparency = isVisible and 0 or 1
		end

		print(string.format(
			"[PortalUI] setPortalVisible(%s) gui.Enabled=%s root.Visible=%s background.Visible=%s root.AbsPos=(%d,%d) root.AbsSize=(%d,%d)",
			tostring(isVisible),
			tostring(currentRefs.gui.Enabled),
			tostring(currentRefs.root.Visible),
			tostring(currentRefs.background.Visible),
			currentRefs.root.AbsolutePosition.X,
			currentRefs.root.AbsolutePosition.Y,
			currentRefs.root.AbsoluteSize.X,
			currentRefs.root.AbsoluteSize.Y
			))
	end

	local function normalize(value: string?): string
		if typeof(value) ~= "string" then
			return ""
		end

		return string.lower((value:gsub("[%s%p_]+", "")))
	end

	local function registerLookup(lookup: { [string]: any }, rawValue: string?, entry: any)
		local key = normalize(rawValue)
		if key ~= "" then
			lookup[key] = entry
		end
	end

	local function cacheLevelRecords(raw: any)
		table.clear(playerLevelRecords)
		if typeof(raw) ~= "table" then
			return
		end

		for levelKey, record in pairs(raw) do
			if typeof(levelKey) == "string" and levelKey ~= "" and typeof(record) == "table" then
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

	local function getLevelRecordForEntry(entry: any): any
		if typeof(entry) ~= "table" then
			return nil
		end

		local candidates = {
			entry.key,
			entry.instanceName,
			entry.name,
		}

		local aliases = entry.aliases
		if typeof(aliases) == "table" then
			for _, alias in ipairs(aliases) do
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

	local function buildEntryLookup()
		table.clear(entryLookup)

		for _, entry in ipairs(Levels.GetAll()) do
			registerLookup(entryLookup, entry.key, entry)
			registerLookup(entryLookup, entry.instanceName, entry)
			registerLookup(entryLookup, entry.name, entry)

			local aliases = entry.aliases
			if typeof(aliases) == "table" then
				for _, alias in ipairs(aliases) do
					registerLookup(entryLookup, alias, entry)
				end
			end
		end
	end

	local function getPortalGui(): ScreenGui?
		if preferredGui and preferredGui.Parent == playerGui then
			return preferredGui
		end

		local ancestorGui = script:FindFirstAncestorOfClass("ScreenGui")
		if ancestorGui and ancestorGui.Name == "PortalUI" then
			return ancestorGui
		end

		local gui = playerGui:FindFirstChild("PortalUI") or playerGui:WaitForChild("PortalUI", 5)
		if gui and gui:IsA("ScreenGui") then
			return gui
		end

		return nil
	end

	local function isPortalPrompt(prompt: ProximityPrompt, localPlayer: Player?): boolean
		if not prompt or not prompt:IsA("ProximityPrompt") then
			return false
		end

		if typeof(localPlayer) == "Instance" and localPlayer:IsA("Player") and localPlayer ~= player then
			return false
		end

		if prompt.Name == "PortalPrompt" then
			return true
		end

		local actionText = string.lower(tostring(prompt.ActionText or ""))
		local objectText = string.lower(tostring(prompt.ObjectText or ""))
		if objectText == "portal" and actionText == "select level" then
			return true
		end

		local current: Instance? = prompt.Parent
		while current do
			if current.Name == "PortalTeleport" or current.Name == "Portal" or current.Name == "PortalModel" then
				return true
			end
			current = current.Parent
		end

		return false
	end

	local function resolvePortalPart(): BasePart?
		if cachedPortalPart and cachedPortalPart:IsDescendantOf(Workspace) then
			return cachedPortalPart
		end

		local portalModel = Workspace:FindFirstChild("Portal") or Workspace:FindFirstChild("PortalModel")
		if portalModel and portalModel:IsA("Model") then
			local portalPart = portalModel:FindFirstChild("PortalTeleport", true)
			if portalPart and portalPart:IsA("BasePart") then
				cachedPortalPart = portalPart
				return portalPart
			end
		end

		for _, descendant in ipairs(Workspace:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name == "PortalTeleport" then
				cachedPortalPart = descendant
				return descendant
			end
		end

		return nil
	end

	function PortalUIController.MatchesPortalPrompt(prompt: ProximityPrompt, localPlayer: Player?): boolean
		if not prompt or not prompt:IsA("ProximityPrompt") then
			return false
		end

		local portalPart = resolvePortalPart()
		if portalPart and prompt:IsDescendantOf(portalPart) then
			return true
		end

		return isPortalPrompt(prompt, localPlayer)
	end

	local function waitForGuiObject(parent: Instance, name: string, timeout: number?): GuiObject?
		local child = parent:FindFirstChild(name) or parent:WaitForChild(name, timeout or 5)
		if child and child:IsA("GuiObject") then
			return child
		end
		return nil
	end

	local function waitForScrollingFrame(parent: Instance, name: string, timeout: number?): ScrollingFrame?
		local child = parent:FindFirstChild(name) or parent:WaitForChild(name, timeout or 5)
		if child and child:IsA("ScrollingFrame") then
			return child
		end
		return nil
	end

	local function waitForTextLabel(parent: Instance, name: string, timeout: number?): TextLabel?
		local child = parent:FindFirstChild(name) or parent:WaitForChild(name, timeout or 5)
		if child and child:IsA("TextLabel") then
			return child
		end
		return nil
	end

	local function waitForGuiButton(parent: Instance, name: string, timeout: number?): GuiButton?
		local child = parent:FindFirstChild(name) or parent:WaitForChild(name, timeout or 5)
		if child and child:IsA("GuiButton") then
			return child
		end
		return nil
	end

	local function resolveRefs(): PortalRefs?
		if refs and refs.gui.Parent == playerGui then
			return refs
		end

		local gui = getPortalGui()
		if not gui then
			warn("[LevelSelectUI] PortalUI ScreenGui not found in PlayerGui.")
			return nil
		end

		local root = waitForGuiObject(gui, "UI")
		if not root then
			warn("[LevelSelectUI] PortalUI.UI is missing.")
			return nil
		end

		local background = waitForGuiObject(root, "Background")
		if not background then
			warn("[LevelSelectUI] PortalUI.UI.Background is missing.")
			return nil
		end

		local levelSelection = waitForGuiObject(background, "LevelSelection")
		local levelList = levelSelection and waitForScrollingFrame(levelSelection, "ScrollingFrame") or nil
		local infoFrame = waitForGuiObject(background, "LevelInfo")
		local descriptionFrame = infoFrame and waitForScrollingFrame(infoFrame, "ScrollingFrame") or nil
		local descriptionLabel = descriptionFrame and waitForTextLabel(descriptionFrame, "LevelDescription") or nil

		local levelName = waitForTextLabel(background, "LevelName")
		local highscoreCounter = waitForTextLabel(background, "HighscoreCounter")
		local speedrunCounter = waitForTextLabel(background, "SpeedrunCounter")
		local singleButton = waitForGuiButton(background, "Single")
		local partyButton = waitForGuiButton(background, "Party")
		local closeButton = waitForGuiButton(background, "CloseButton")

		if not (levelList and infoFrame and descriptionFrame and descriptionLabel and levelName and highscoreCounter and speedrunCounter and singleButton and partyButton and closeButton) then
			warn("[LevelSelectUI] PortalUI hierarchy is incomplete.")
			return nil
		end

		descriptionLabel.TextWrapped = true
		descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
		gui.Enabled = true
		gui:SetAttribute("Modal", false)
		root.Visible = false

		refs = {
			gui = gui,
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

	local function formatHighscore(entry: any): string
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

	local function formatSpeedrun(entry: any): string
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

	local function getDescription(entry: any, statusMessage: string?): string
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

		local descriptionLabel = currentRefs.descriptionLabel
		local descriptionFrame = currentRefs.descriptionFrame
		local horizontalPadding = math.max(8, descriptionLabel.Position.X.Offset * 2)
		local availableWidth = math.max(120, descriptionFrame.AbsoluteSize.X - horizontalPadding)

		local textBounds = TextService:GetTextSize(
			descriptionLabel.Text or "",
			descriptionLabel.TextSize,
			descriptionLabel.Font,
			Vector2.new(availableWidth, 10000)
		)

		descriptionLabel.Size = UDim2.new(1, -horizontalPadding, 0, math.max(textBounds.Y, descriptionFrame.AbsoluteSize.Y - 8))
		descriptionFrame.CanvasSize = UDim2.fromOffset(0, math.max(textBounds.Y + 8, descriptionFrame.AbsoluteSize.Y))
	end

	local function getButtonState(button: GuiButton): ButtonState
		local existing = buttonStates[button]
		if existing then
			return existing
		end

		local stroke = button:FindFirstChild("PortalSelectionStroke")
		if not (stroke and stroke:IsA("UIStroke")) then
			stroke = Instance.new("UIStroke")
			stroke.Name = "PortalSelectionStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = IDLE_STROKE
			stroke.Thickness = 2
			stroke.Transparency = 0.1
			stroke.Parent = button
		end

		local scale = button:FindFirstChild("PortalSelectionScale")
		if not (scale and scale:IsA("UIScale")) then
			scale = Instance.new("UIScale")
			scale.Name = "PortalSelectionScale"
			scale.Scale = 1
			scale.Parent = button
		end

		local state: ButtonState = {
			stroke = stroke,
			scale = scale,
			baseBackgroundTransparency = button.BackgroundTransparency,
			baseImageTransparency = nil,
			baseImageColor3 = nil,
		}

		if button:IsA("ImageButton") then
			state.baseImageTransparency = button.ImageTransparency
			state.baseImageColor3 = button.ImageColor3
		end

		buttonStates[button] = state
		return state
	end

	local function tweenInstance(instance: Instance, properties: { [string]: any })
		TweenService:Create(instance, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties):Play()
	end

	local function updateLevelButtonVisual(button: GuiButton, isHovering: boolean)
		local state = getButtonState(button)
		local isSelected = button == selectedButton

		state.stroke.Color = if isSelected then SELECTED_STROKE else if isHovering then HOVER_STROKE else IDLE_STROKE
		state.stroke.Thickness = if isSelected then 4 else if isHovering then 3 else 2

		local targetScale = 1
		if isSelected then
			targetScale = 1.025
		elseif isHovering then
			targetScale = 1.01
		end
		tweenInstance(state.scale, { Scale = targetScale })

		if button:IsA("ImageButton") then
			local targetImageTransparency = state.baseImageTransparency or 0
			if isSelected then
				targetImageTransparency = math.max(0, targetImageTransparency - 0.08)
			elseif isHovering then
				targetImageTransparency = math.max(0, targetImageTransparency - 0.04)
			end

			tweenInstance(button, {
				BackgroundTransparency = if isSelected then math.max(0, state.baseBackgroundTransparency - 0.06) else state.baseBackgroundTransparency,
				ImageTransparency = targetImageTransparency,
			})

			if state.baseImageColor3 then
				button.ImageColor3 = state.baseImageColor3
			end
		else
			local targetBackgroundTransparency = state.baseBackgroundTransparency
			if isSelected then
				targetBackgroundTransparency = math.max(0, state.baseBackgroundTransparency - 0.06)
			elseif isHovering then
				targetBackgroundTransparency = math.max(0, state.baseBackgroundTransparency - 0.03)
			end

			tweenInstance(button, {
				BackgroundTransparency = targetBackgroundTransparency,
			})
		end
	end

	local function applySelectionVisuals()
		for button in pairs(buttonEntries) do
			if button.Parent then
				updateLevelButtonVisual(button, false)
			end
		end
	end

	local function renderSelectedEntry(statusMessage: string?)
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

		local record = getLevelRecordForEntry(selectedEntry)
		currentRefs.levelName.Text = tostring(selectedEntry.name or selectedEntry.key or "Level")
		currentRefs.highscoreCounter.Text = formatHighscore((record and record.highscore ~= nil) and record or selectedEntry)
		currentRefs.speedrunCounter.Text = formatSpeedrun((record and record.speedrun ~= nil) and record or selectedEntry)
		currentRefs.descriptionLabel.Text = getDescription(selectedEntry, statusMessage)
		updateDescriptionCanvas()
	end

	local function resolveEntryForButton(button: GuiButton): any
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

	local function selectEntry(entry: any, button: GuiButton?)
		selectedEntry = entry
		selectedButton = button
		activeStatusMessage = nil
		applySelectionVisuals()
		renderSelectedEntry(nil)
	end

	local function bindLevelButton(button: GuiButton, entry: any)
		buttonEntries[button] = entry

		local childLabel = button:FindFirstChild("LevelName")
		if childLabel and childLabel:IsA("TextLabel") and typeof(entry.name) == "string" then
			childLabel.Text = entry.name
		elseif button:IsA("TextButton") and typeof(entry.name) == "string" and button.Text ~= "" then
			button.Text = entry.name
		end

		if buttonConnections[button] then
			return
		end
		buttonConnections[button] = true

		getButtonState(button)
		button.AutoButtonColor = false

		button.MouseEnter:Connect(function()
			updateLevelButtonVisual(button, true)
		end)

		button.MouseLeave:Connect(function()
			updateLevelButtonVisual(button, false)
		end)

		button.MouseButton1Click:Connect(function()
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
				warn(string.format("[LevelSelectUI] No level entry found for button '%s'.", child.Name))
				continue
			end

			if not fallbackEntry then
				fallbackEntry = entry
				fallbackButton = child
			end

			bindLevelButton(child, entry)

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

	local function closeUI()
		local currentRefs = resolveRefs()
		if not currentRefs then
			return
		end

		setPortalVisible(currentRefs, false)
	end

	local function requestTeleport(mode: string)
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

	local function bindFixedControls()
		local currentRefs = resolveRefs()
		if not currentRefs or fixedControlsBound then
			return
		end

		fixedControlsBound = true

		currentRefs.closeButton.MouseButton1Click:Connect(closeUI)
		currentRefs.singleButton.MouseButton1Click:Connect(function()
			requestTeleport("Single")
		end)
		currentRefs.partyButton.MouseButton1Click:Connect(function()
			requestTeleport("Multi")
		end)

		currentRefs.descriptionFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateDescriptionCanvas)
		currentRefs.descriptionLabel:GetPropertyChangedSignal("Text"):Connect(updateDescriptionCanvas)
	end

	local function openUI()
		local initialRefs = resolveRefs()
		if not initialRefs then
			return
		end

		print(string.format(
			"[PortalUI] openUI refs gui=%s root=%s background=%s rootClass=%s backgroundClass=%s",
			initialRefs.gui:GetFullName(),
			initialRefs.root:GetFullName(),
			initialRefs.background:GetFullName(),
			initialRefs.root.ClassName,
			initialRefs.background.ClassName
			))

		bindFixedControls()
		if PlayerProgressEvent and PlayerProgressEvent:IsA("RemoteEvent") then
			PlayerProgressEvent:FireServer({ type = "requestSync" })
		end
		activeStatusMessage = nil
		refreshLevelButtons()

		local currentRefs = resolveRefs()
		if currentRefs then
			setPortalVisible(currentRefs, true)
		end
	end

	function PortalUIController.Open()
		openUI()
	end

	function PortalUIController.Close()
		closeUI()
	end

	local function messageForFailure(reason: string): string
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
		elseif reason == "mining_active" then
			return "You cannot enter the portal right now because you are busy in the mine."
		elseif reason == "party_member_mining" then
			return "A party member is busy in the mine and cannot enter the portal yet."
		end

		return "Teleport failed. Try again."
	end

	buildEntryLookup()

	OpenLevelSelect.OnClientEvent:Connect(function()
		print("[PortalUI] Opening from OpenLevelSelect")
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

			local currentRefs = resolveRefs()
			if not currentRefs then
				return
			end

			setPortalVisible(currentRefs, true)
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

	print("[LevelSelectUI] Ready for PortalUI")
end

return PortalUIController
