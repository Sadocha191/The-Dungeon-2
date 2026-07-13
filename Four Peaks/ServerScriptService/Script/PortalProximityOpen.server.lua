local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local CraftingService = require(serverModules:WaitForChild("CraftingService"))

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local remote = remoteEvents:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if remote then
		remote:Destroy()
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteEvents
	return remote
end

local requestPortalOpen = ensureRemote("RequestPortalOpen")
local openLevelSelect = ensureRemote("OpenLevelSelect")

local OPEN_DISTANCE = 14
local OPEN_COOLDOWN = 0.4
local lastOpen = {}
local cachedPortalPart = nil

local function resolvePortalPart()
	if cachedPortalPart and cachedPortalPart:IsDescendantOf(Workspace) then
		return cachedPortalPart
	end

	local portalModel = Workspace:FindFirstChild("Portal") or Workspace:FindFirstChild("PortalModel")
	if portalModel and portalModel:IsA("Model") then
		local candidate = portalModel:FindFirstChild("PortalTeleport", true)
		if candidate and candidate:IsA("BasePart") then
			cachedPortalPart = candidate
			return cachedPortalPart
		end
	end

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "PortalTeleport" then
			cachedPortalPart = descendant
			return cachedPortalPart
		end
	end

	cachedPortalPart = nil
	return nil
end

local function isCloseEnough(player)
	local portalPart = resolvePortalPart()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not portalPart or not rootPart or not rootPart:IsA("BasePart") then
		return false
	end
	return (rootPart.Position - portalPart.Position).Magnitude <= OPEN_DISTANCE
end

local function tutorialComplete(player)
	local attribute = player:GetAttribute("TutorialComplete")
	if attribute ~= nil then
		return attribute == true
	end

	local ok, state = pcall(function()
		return PlayerStateStore.GetTutorialState(player)
	end)
	return ok and state and state.Complete == true or false
end

local function hasActiveMiningSession(player)
	local ok, snapshot = pcall(function()
		return CraftingService.GetMiningSnapshot(player)
	end)
	return ok
		and typeof(snapshot) == "table"
		and typeof(snapshot.session) == "table"
		and snapshot.session.active == true
end

requestPortalOpen.OnServerEvent:Connect(function(player)
	if not player or player.Parent ~= Players then
		return
	end

	local now = os.clock()
	local previous = lastOpen[player.UserId] or 0
	if now - previous < OPEN_COOLDOWN then
		return
	end
	lastOpen[player.UserId] = now

	if not isCloseEnough(player) then
		return
	end
	if not tutorialComplete(player) then
		return
	end
	if hasActiveMiningSession(player) then
		return
	end

	openLevelSelect:FireClient(player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastOpen[player.UserId] = nil
end)

Workspace.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "PortalTeleport" then
		cachedPortalPart = nil
	end
end)
