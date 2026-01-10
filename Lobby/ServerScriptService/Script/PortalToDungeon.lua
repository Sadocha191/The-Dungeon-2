-- SCRIPT: PortalToLevel1.server.lua
-- GDZIE: Lobby/ServerScriptService/Script/PortalToDungeon.lua
-- CO: ProximityPrompt na portalu + otwieranie LevelSelectUI + teleport z TeleportData.

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = ReplicatedStorage:WaitForChild("ModuleScripts")

local ProfilesManager = require(serverModules:WaitForChild("ProfilesManager"))
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local Levels = require(replicatedModules:WaitForChild("Levels"))

-- Remotes
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemote(name: string): RemoteEvent
	local ev = remoteEvents:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remoteEvents
	return ev
end

local OpenLevelSelect = ensureRemote("OpenLevelSelect")
local RequestLevelTeleport = ensureRemote("RequestLevelTeleport")

-- Portal może być w Workspace albo w ServerStorage. Nie używamy WaitForChild, żeby nie zawieszać skryptu.
local function resolvePortalPart(): BasePart?
	local ws = workspace

	-- 1) Workspace: Model "Portal" / "PortalModel" + part "PortalTeleport"
	local portalModel = ws:FindFirstChild("Portal") or ws:FindFirstChild("PortalModel")
	if portalModel and portalModel:IsA("Model") then
		local part = portalModel:FindFirstChild("PortalTeleport")
		if part and part:IsA("BasePart") then return part end
	end

	-- 2) ServerStorage: "Portal" -> clone do Workspace
	local stored = ServerStorage:FindFirstChild("Portal")
	if stored and stored:IsA("Model") then
		local clone = stored:Clone()
		clone.Parent = ws
		local part = clone:FindFirstChild("PortalTeleport")
		if part and part:IsA("BasePart") then return part end
	end

	-- 3) Ostatni fallback: szukaj partu o nazwie PortalTeleport w całym Workspace
	for _, d in ipairs(ws:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "PortalTeleport" then
			return d
		end
	end

	return nil
end

local portalPart = resolvePortalPart()
if not portalPart then
	warn("[PortalToLevel1] PortalTeleport not found (Workspace/ServerStorage). Prompt will not be created.")
	return
end

-- Prompt
local prompt = portalPart:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Portal"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = portalPart
end
prompt.ActionText = "Select level"

local lastOpen: {[number]: number} = {}
local lastTp: {[number]: number} = {}
local OPEN_COOLDOWN = 0.6
local TP_COOLDOWN = 2.0

local function canOpen(player: Player): boolean
	local now = os.clock()
	local last = lastOpen[player.UserId] or 0
	if (now - last) < OPEN_COOLDOWN then return false end
	lastOpen[player.UserId] = now
	return true
end

local function canTeleport(player: Player): boolean
	local now = os.clock()
	local last = lastTp[player.UserId] or 0
	if (now - last) < TP_COOLDOWN then return false end
	lastTp[player.UserId] = now
	return true
end

local function distanceOk(player: Player): boolean
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	return (hrp.Position - portalPart.Position).Magnitude <= 14
end

local function tutorialComplete(player: Player): boolean
	-- Twój “gate” na tutorial (jeśli chcesz blokować portal przed ukończeniem tutoriala)
	local attr = player:GetAttribute("TutorialComplete")
	if attr ~= nil then
		return attr == true
	end

	-- fallback: jeśli atrybutu nie ma, patrzymy w store
	local ok, state = pcall(function()
		return PlayerStateStore.GetTutorialState(player)
	end)
	if ok and state and state.Complete == true then
		return true
	end

	return false
end

local function tryTeleport(player: Player, placeId: number)
	if not canTeleport(player) then return end

	-- profile do teleportdata
	local profile = ProfilesManager.GetProfile(player)
	local st = PlayerStateStore.Get(player)

	local tpData = {
		Profile = profile,
		StarterWeaponName = st and st.StarterWeaponName or nil,
		EquippedWeaponInstanceId = st and st.EquippedWeaponInstanceId or nil,
	}

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, { player }, tpData)
	end)
	if not ok then
		warn("[PortalToLevel1] TeleportAsync failed:", err)
	end
end

-- Otwieranie UI
prompt.Triggered:Connect(function(player: Player)
	if not player or not player.Parent then return end
	if not distanceOk(player) then return end
	if not canOpen(player) then return end

	if not tutorialComplete(player) then
		-- jak chcesz, możesz tu wysłać jakiś komunikat; na razie po prostu blokada
		return
	end

	OpenLevelSelect:FireClient(player)
end)

-- Wybór poziomu z UI
RequestLevelTeleport.OnServerEvent:Connect(function(player: Player, levelKey: any)
	if not player or not player.Parent then return end
	if typeof(levelKey) ~= "string" then return end
	if not tutorialComplete(player) then return end
	if not distanceOk(player) then return end

	local entry = Levels.GetByKey(levelKey)
	if not entry or typeof(entry.placeId) ~= "number" then
		warn("[PortalToLevel1] Unknown level key:", levelKey)
		return
	end

	tryTeleport(player, entry.placeId)
end)

print("[PortalToLevel1] Ready -> Level selector")
