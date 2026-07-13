local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local requestPortalOpen = remoteEvents:WaitForChild("RequestPortalOpen")

local OPEN_DISTANCE = 12
local CLOSE_DISTANCE = 16
local UPDATE_INTERVAL = 0.1

local portalPart = nil
local wasInside = false
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

local function getRootPart()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return rootPart and rootPart:IsA("BasePart") and rootPart or nil
end

local function setInside(nextInside)
	if nextInside == wasInside then
		return
	end

	wasInside = nextInside
	if nextInside then
		requestPortalOpen:FireServer()
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
end

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
