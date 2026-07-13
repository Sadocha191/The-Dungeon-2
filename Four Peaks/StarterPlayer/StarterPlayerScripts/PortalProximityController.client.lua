local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local requestPortalOpen = remoteEvents:WaitForChild("RequestPortalOpen")
local openLevelSelect = remoteEvents:WaitForChild("OpenLevelSelect")

local OPEN_DISTANCE = 12
local CLOSE_DISTANCE = 16
local UPDATE_INTERVAL = 0.1
local RETRY_INTERVAL = 1

local portalPart = nil
local wasInside = false
local openAccepted = false
local lastOpenRequest = 0
local accumulator = 0

local function resolvePortalPart()
	if portalPart and portalPart:IsDescendantOf(Workspace) then
		return portalPart
	end

	local portalModel = Workspace:FindFirstChild("Portal") or Workspace:FindFirstChild("PortalModel")
	if portalModel and portalModel:IsA("Model") then
		local candidate = portalModel:FindFirstChild("PortalTeleport", true)
		if candidate and candidate:IsA("BasePart") then
			portalPart = candidate
			return portalPart
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "PortalTeleport" then
			portalPart = descendant
			return portalPart
		end
	end

	portalPart = nil
	return nil
end

local function hideLegacyPrompt(part)
	local prompt = part and part:FindFirstChildOfClass("ProximityPrompt")
	if prompt and prompt.Name == "PortalPrompt" then
		prompt.Enabled = false
	end
end

local function closePortalUi()
	local gui = playerGui:FindFirstChild("PortalUI")
	if gui and gui:IsA("ScreenGui") then
		gui:SetAttribute("Modal", false)
		gui.Enabled = false
	end
end

local function keepProximityUiNonModal()
	if not wasInside or not openAccepted then
		return
	end

	local gui = playerGui:FindFirstChild("PortalUI")
	if gui and gui:IsA("ScreenGui") and gui.Enabled then
		gui:SetAttribute("Modal", false)
	end
end

local function getRootPart()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return rootPart and rootPart:IsA("BasePart") and rootPart or nil
end

local function isWithinCloseRadius()
	if player:GetAttribute("TutorialComplete") ~= true then
		return false
	end

	local part = resolvePortalPart()
	local rootPart = getRootPart()
	if not part or not rootPart then
		return false
	end

	return (rootPart.Position - part.Position).Magnitude <= CLOSE_DISTANCE
end

local function requestOpenIfNeeded()
	if not wasInside or openAccepted then
		return
	end

	local now = os.clock()
	if now - lastOpenRequest < RETRY_INTERVAL then
		return
	end
	lastOpenRequest = now
	requestPortalOpen:FireServer()
end

local function setInside(nextInside)
	if nextInside == wasInside then
		return
	end

	wasInside = nextInside
	openAccepted = false
	lastOpenRequest = 0
	if nextInside then
		requestOpenIfNeeded()
	else
		closePortalUi()
	end
end

local function updatePortalState()
	if player:GetAttribute("TutorialComplete") ~= true then
		setInside(false)
		return
	end

	local part = resolvePortalPart()
	local rootPart = getRootPart()
	if not part or not rootPart then
		setInside(false)
		return
	end

	hideLegacyPrompt(part)

	local distance = (rootPart.Position - part.Position).Magnitude
	local threshold = wasInside and CLOSE_DISTANCE or OPEN_DISTANCE
	setInside(distance <= threshold)
	requestOpenIfNeeded()
	keepProximityUiNonModal()
end

openLevelSelect.OnClientEvent:Connect(function()
	if not isWithinCloseRadius() then
		openAccepted = false
		closePortalUi()
		-- PortalUIClient listens to the same remote and may run after this callback.
		-- Close once more after all current event listeners have had a chance to run.
		task.defer(closePortalUi)
		return
	end

	if wasInside then
		openAccepted = true
		task.defer(keepProximityUiNonModal)
	end
end)

player.CharacterRemoving:Connect(function()
	setInside(false)
end)

player:GetAttributeChangedSignal("TutorialComplete"):Connect(updatePortalState)
Workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "PortalTeleport" or descendant.Name == "PortalPrompt" then
		portalPart = nil
		task.defer(updatePortalState)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < UPDATE_INTERVAL then
		return
	end
	accumulator = 0
	updatePortalState()
end)

updatePortalState()
