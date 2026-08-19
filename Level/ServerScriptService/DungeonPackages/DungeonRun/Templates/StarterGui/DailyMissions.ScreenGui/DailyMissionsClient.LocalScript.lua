local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local screenGui = script.Parent
local boardContainer = screenGui:WaitForChild("Tablica")
local boardContent = boardContainer:FindFirstChild("Tablica") or boardContainer
local notesContainer = boardContent:WaitForChild("Kartki")
local interactionZones = boardContent:WaitForChild("Interaction_zones")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local getDailyMissionsRemote = remotes:WaitForChild("GetDailyMissions", 10)
local dailyMissionsUpdatedRemote = remotes:WaitForChild("DailyMissionsUpdated", 10)
local pauseMenuEvent = remotes:WaitForChild("PauseMenuEvent", 10)
local PAUSE_SOURCE = "DailyMissions"

local BOARD_SHOWN_POSITION = UDim2.new(0.177, 0, 0.152, 0)
local BOARD_HIDDEN_POSITION = UDim2.new(-0.604, 0, 0.152, 0)

local BOARD_TWEEN_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local NOTE_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local MISSION_CONFIG = {
	{
		zoneName = "Frame",
		missionName = "Mission1",
		startPosition = UDim2.new(-0.048, 0, 0.083, 0),
		startRotation = -3,
		endPosition = UDim2.new(-0.048, 0, 0.083, 0),
		endRotation = 0,
	},
	{
		zoneName = "Frame1",
		missionName = "Mission2",
		startPosition = UDim2.new(0.105, 0, 0.007, 0),
		startRotation = 3,
		endPosition = UDim2.new(0.235, 0, 0.007, 0),
		endRotation = 0,
	},
	{
		zoneName = "Frame2",
		missionName = "Mission3",
		startPosition = UDim2.new(0.235, 0, 0.083, 0),
		startRotation = -3,
		endPosition = UDim2.new(0.38, 0, 0.083, 0),
		endRotation = 0,
	},
	{
		zoneName = "Frame3",
		missionName = "Mission4",
		startPosition = UDim2.new(0.402, 0, 0.007, 0),
		startRotation = -3,
		endPosition = UDim2.new(0.512, 0, 0.007, 0),
		endRotation = 0,
	},
	{
		zoneName = "Frame4",
		missionName = "Mission5",
		startPosition = UDim2.new(0.563, 0, 0.027, 0),
		startRotation = 3,
		endPosition = UDim2.new(0.672, 0, 0.027, 0),
		endRotation = 0,
	},
	{
		zoneName = "Frame5",
		missionName = "Mission6",
		startPosition = UDim2.new(0.701, 0, -0.024, 0),
		startRotation = -3,
		endPosition = UDim2.new(0.836, 0, -0.024, 0),
		endRotation = 0,
	},
}

screenGui.ResetOnSpawn = false
screenGui:SetAttribute("BoardShown", false)

local missionStates = {}
local activeMissionName = nil
local boardShown = false
local boardTween = nil
local boardPauseActive = false

local function setUiInput()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function setBoardPauseActive(active)
	if boardPauseActive == active then
		return
	end

	boardPauseActive = active

	if pauseMenuEvent and pauseMenuEvent:IsA("RemoteEvent") then
		pauseMenuEvent:FireServer({
			action = active and "pause" or "resume",
			source = PAUSE_SOURCE,
		})
	end
end

local function getMissionTextObject(note: Instance, sectionName: string): GuiObject?
	local section = note:FindFirstChild(sectionName)
	if not section then
		return nil
	end

	local textObject = section:FindFirstChild("TextBox")
	if not textObject or not (
		textObject:IsA("TextBox")
		or textObject:IsA("TextLabel")
		or textObject:IsA("TextButton")
	) then
		return nil
	end

	if textObject:IsA("TextBox") then
		textObject.ClearTextOnFocus = false
		pcall(function()
			textObject.TextEditable = false
		end)
	end

	return textObject
end

local function getMissionDescription(mission): string
	if typeof(mission) ~= "table" then
		return ""
	end

	local description = tostring(mission.Description or "")
	if description ~= "" then
		return description
	end

	return tostring(mission.Title or "")
end

local function getMissionProgressText(mission): string
	if typeof(mission) ~= "table" then
		return ""
	end

	local progress = mission.Progress
	if typeof(progress) ~= "table" then
		return ""
	end

	local current = math.max(0, math.floor(tonumber(progress.Current) or 0))
	local target = math.max(0, math.floor(tonumber(progress.Target) or 0))

	if target <= 0 then
		return tostring(current)
	end

	return ("%d / %d"):format(math.min(current, target), target)
end

local function stopMissionTween(state)
	if state.tween then
		state.tween:Cancel()
		state.tween = nil
	end
end

local function setMissionInstant(state, useEndState)
	stopMissionTween(state)
	state.note.Position = useEndState and state.config.endPosition or state.config.startPosition
	state.note.Rotation = useEndState and state.config.endRotation or state.config.startRotation
end

local function tweenMission(state, useEndState)
	local goal = {
		Position = useEndState and state.config.endPosition or state.config.startPosition,
		Rotation = useEndState and state.config.endRotation or state.config.startRotation,
	}

	if state.note.Position == goal.Position and state.note.Rotation == goal.Rotation then
		stopMissionTween(state)
		return
	end

	stopMissionTween(state)

	local tween = TweenService:Create(state.note, NOTE_TWEEN_INFO, goal)
	state.tween = tween
	tween.Completed:Connect(function()
		if state.tween == tween then
			state.tween = nil
		end
	end)
	tween:Play()
end

local function setActiveMission(missionName, force)
	if not force and activeMissionName == missionName then
		return
	end

	activeMissionName = missionName

	for name, state in pairs(missionStates) do
		tweenMission(state, name == missionName)
	end
end

local function setBoardShown(shown)
	screenGui:SetAttribute("BoardShown", shown)
	boardShown = shown
end

local function isPointInsideZone(zone, point)
	local position = zone.AbsolutePosition
	local size = zone.AbsoluteSize

	return point.X >= position.X
		and point.X <= position.X + size.X
		and point.Y >= position.Y
		and point.Y <= position.Y + size.Y
end

local function getHoveredMissionName()
	if not boardShown or boardTween then
		return nil
	end

	local mousePosition = UserInputService:GetMouseLocation()
	for _, config in ipairs(MISSION_CONFIG) do
		local state = missionStates[config.missionName]
		if state and state.hasMission and state.note.Visible and isPointInsideZone(state.zone, mousePosition) then
			return config.missionName
		end
	end

	return nil
end

local function updateHoveredMission(force)
	setActiveMission(getHoveredMissionName(), force)
end

local function applyMissionData(state, mission)
	local hasMission = typeof(mission) == "table"
	state.hasMission = hasMission
	state.note.Visible = hasMission
	state.zone.Active = hasMission

	if state.descriptionBox then
		state.descriptionBox.Text = hasMission and getMissionDescription(mission) or ""
	end
	if state.progressBox then
		state.progressBox.Text = hasMission and getMissionProgressText(mission) or ""
	end

	if not hasMission then
		setMissionInstant(state, false)
	end
end

local function renderMissionPayload(payload)
	local missions = {}
	if typeof(payload) == "table" and typeof(payload.missions) == "table" then
		missions = payload.missions
	end

	for index, config in ipairs(MISSION_CONFIG) do
		local state = missionStates[config.missionName]
		if state then
			applyMissionData(state, missions[index])
		end
	end

	if activeMissionName then
		local activeState = missionStates[activeMissionName]
		if activeState and not activeState.hasMission then
			setActiveMission(nil, true)
		end
	end

	updateHoveredMission(true)
end

local function requestMissionData()
	if not getDailyMissionsRemote or not getDailyMissionsRemote:IsA("RemoteFunction") then
		renderMissionPayload(nil)
		return
	end

	local ok, payload = pcall(function()
		return getDailyMissionsRemote:InvokeServer()
	end)

	if not ok then
		warn("[DailyMissionsClient] Failed to fetch daily missions:", payload)
		return
	end

	renderMissionPayload(payload)
end

local function toggleBoard()
	if boardTween then
		return
	end

	local nextShown = not boardShown
	if nextShown then
		setBoardShown(true)
		setBoardPauseActive(true)
		setUiInput()
		task.spawn(requestMissionData)
	else
		setActiveMission(nil, true)
	end

	local tween = TweenService:Create(boardContainer, BOARD_TWEEN_INFO, {
		Position = nextShown and BOARD_SHOWN_POSITION or BOARD_HIDDEN_POSITION,
	})

	boardTween = tween
	tween.Completed:Connect(function()
		if boardTween ~= tween then
			return
		end

		boardTween = nil

		if nextShown then
			updateHoveredMission(true)
		else
			setBoardPauseActive(false)
			setBoardShown(false)
			setActiveMission(nil, true)
		end
	end)
	tween:Play()
end

for _, config in ipairs(MISSION_CONFIG) do
	local note = notesContainer:WaitForChild(config.missionName)
	local zone = interactionZones:WaitForChild(config.zoneName)

	zone.Active = true

	local state = {
		config = config,
		note = note,
		zone = zone,
		descriptionBox = getMissionTextObject(note, "MissionDescription"),
		progressBox = getMissionTextObject(note, "Mission progress"),
		hasMission = false,
		tween = nil,
	}

	missionStates[config.missionName] = state
	setMissionInstant(state, false)
	applyMissionData(state, nil)
end

boardContainer.Position = BOARD_HIDDEN_POSITION
setBoardShown(false)
setActiveMission(nil, true)

if dailyMissionsUpdatedRemote and dailyMissionsUpdatedRemote:IsA("RemoteEvent") then
	dailyMissionsUpdatedRemote.OnClientEvent:Connect(function(payload)
		renderMissionPayload(payload)
	end)
end

script.Destroying:Connect(function()
	setBoardPauseActive(false)
end)

task.spawn(requestMissionData)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if input.KeyCode == Enum.KeyCode.J then
		toggleBoard()
	end
end)

RunService.RenderStepped:Connect(function()
	if boardShown or activeMissionName ~= nil then
		updateHoveredMission(false)
	end
end)
