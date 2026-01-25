-- PortalToDungeon.server.lua
-- Lobby/ServerScriptService/Script/PortalToDungeon.lua
-- FIX:
-- 1) ProfilesManager: używaj GetActiveProfile + LoadIfAny (GetProfile nie istnieje)
-- 2) WeaponInstances to lista -> pobieraj instancję przez PlayerStateStore.GetWeaponInstance
-- 3) TeleportData niesie: Profile, StarterWeaponEntry, EquippedWeaponInstanceId, UnlockedSpells
-- 4) Dodaje RemoteEvent "TeleportStatus" do komunikatu "Teleporting..."

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = ReplicatedStorage:WaitForChild("ModuleScripts")

local ProfilesManager = require(serverModules:WaitForChild("ProfilesManager"))
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))
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
local TeleportStatus = ensureRemote("TeleportStatus") -- client shows "Teleporting..."

-- Portal resolver (nie używamy WaitForChild, żeby nie wieszać)
local function resolvePortalPart(): BasePart?
	local ws = workspace
	local portalModel = ws:FindFirstChild("Portal") or ws:FindFirstChild("PortalModel")
	if portalModel and portalModel:IsA("Model") then
		local part = portalModel:FindFirstChild("PortalTeleport")
		if part and part:IsA("BasePart") then return part end
	end

	local stored = ServerStorage:FindFirstChild("Portal")
	if stored and stored:IsA("Model") then
		local clone = stored:Clone()
		clone.Parent = ws
		local part = clone:FindFirstChild("PortalTeleport")
		if part and part:IsA("BasePart") then return part end
	end

	for _, d in ipairs(ws:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "PortalTeleport" then
			return d
		end
	end
	return nil
end

local portalPart = resolvePortalPart()
if not portalPart then
	warn("[PortalToDungeon] PortalTeleport not found (Workspace/ServerStorage).")
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
	local attr = player:GetAttribute("TutorialComplete")
	if attr ~= nil then return attr == true end
	local ok, state = pcall(function() return PlayerStateStore.GetTutorialState(player) end)
	return (ok and state and state.Complete == true) or false
end

local function getProfileSafe(player: Player)
	if ProfilesManager.LoadIfAny then
		pcall(function() ProfilesManager.LoadIfAny(player) end)
	end
	if ProfilesManager.GetActiveProfile then
		return ProfilesManager.GetActiveProfile(player)
	end
	return nil
end

local function buildUnlockedSpellsList(player: Player): {string}
	local out = {}
	local d = PlayerData.Get(player)
	if typeof(d.spellsUnlocked) == "table" then
		for id, v in pairs(d.spellsUnlocked) do
			if v == true and typeof(id) == "string" and id ~= "" then
				table.insert(out, id)
			end
		end
	end
	table.sort(out)
	return out
end

local function tryTeleport(player: Player, placeId: number)
	if not canTeleport(player) then return end

	local st = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	local profile = getProfileSafe(player)

	-- FIX: WeaponInstances to lista -> GetWeaponInstance
	local weaponEntry = nil
	if st and typeof(st.EquippedWeaponInstanceId) == "string" and st.EquippedWeaponInstanceId ~= "" then
		local inst = PlayerStateStore.GetWeaponInstance(player, st.EquippedWeaponInstanceId)
		if typeof(inst) == "table" then
			weaponEntry = inst
		end
	end

	local tpData = {
		Profile = profile,
		StarterWeaponName = st and st.StarterWeaponName or nil,
		StarterWeaponEntry = weaponEntry,
		EquippedWeaponInstanceId = st and st.EquippedWeaponInstanceId or nil,
		UnlockedSpells = buildUnlockedSpellsList(player),
	}

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(tpData)

	TeleportStatus:FireClient(player, { type = "teleporting" })

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, { player }, options)
	end)
	if not ok then
		warn("[PortalToDungeon] TeleportAsync failed:", err)
		TeleportStatus:FireClient(player, { type = "failed" })
	end
end

prompt.Triggered:Connect(function(player: Player)
	if not player or not player.Parent then return end
	if not distanceOk(player) then return end
	if not canOpen(player) then return end
	if not tutorialComplete(player) then return end
	OpenLevelSelect:FireClient(player)
end)

RequestLevelTeleport.OnServerEvent:Connect(function(player: Player, levelKey: any)
	if not player or not player.Parent then return end
	if typeof(levelKey) ~= "string" then return end
	if not tutorialComplete(player) then return end
	if not distanceOk(player) then return end

	local entry = Levels.GetByKey(levelKey)
	if not entry or typeof(entry.placeId) ~= "number" then
		warn("[PortalToDungeon] Unknown level key:", levelKey)
		return
	end

	tryTeleport(player, entry.placeId)
end)

print("[PortalToDungeon] Ready")
