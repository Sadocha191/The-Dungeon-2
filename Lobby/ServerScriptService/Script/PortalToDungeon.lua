-- PortalToDungeon.server.lua (Lobby)
-- Fix: TeleportData wysyła poprawny loadout broni + listę kupionych spelli (UnlockedSpells)
-- Wymagane do losowania spelli po level-up w Level1.

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = (ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript") or ReplicatedStorage:WaitForChild("ModuleScripts", 5) or ReplicatedStorage:WaitForChild("ModuleScript", 5))

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
local TeleportStatus = ensureRemote("TeleportStatus") -- optional client overlay

-- Portal part
local function resolvePortalPart(): BasePart?
	local ws = workspace
	local portalModel = ws:FindFirstChild("Portal") or ws:FindFirstChild("PortalModel")
	if portalModel and portalModel:IsA("Model") then
		local part = portalModel:FindFirstChild("PortalTeleport")
		if part and part:IsA("BasePart") then return part end
	end
	for _, d in ipairs(ws:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "PortalTeleport" then
			return d
		end
	end
	local stored = ServerStorage:FindFirstChild("Portal")
	if stored and stored:IsA("Model") then
		local clone = stored:Clone()
		clone.Parent = ws
		local part = clone:FindFirstChild("PortalTeleport")
		if part and part:IsA("BasePart") then return part end
	end
	return nil
end

local portalPart = resolvePortalPart()
if not portalPart then
	warn("[PortalToDungeon] PortalTeleport not found.")
	return
end

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

local lastOpen, lastTp = {}, {}
local OPEN_COOLDOWN, TP_COOLDOWN = 0.6, 2.0

local function distanceOk(player: Player): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	return (hrp.Position - portalPart.Position).Magnitude <= 14
end

local function tutorialComplete(player: Player): boolean
	local attr = player:GetAttribute("TutorialComplete")
	if attr ~= nil then return attr == true end
	local ok, state = pcall(function() return PlayerStateStore.GetTutorialState(player) end)
	return ok and state and state.Complete == true or false
end

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

local function getProfileSafe(player: Player)
	if ProfilesManager.GetActiveProfile then
		local p = ProfilesManager.GetActiveProfile(player)
		if p then return p end
	end
	if ProfilesManager.LoadIfAny then
		pcall(function() ProfilesManager.LoadIfAny(player) end)
		if ProfilesManager.GetActiveProfile then
			return ProfilesManager.GetActiveProfile(player)
		end
	end
	if ProfilesManager.GetProfile then
		return ProfilesManager.GetProfile(player)
	end
	return nil
end

local function buildUnlockedSpells(player: Player): {string}
	local out = {}
	local d = PlayerData.Get(player)
	if typeof(d) == "table" and typeof(d.spellsUnlocked) == "table" then
		for spellId, v in pairs(d.spellsUnlocked) do
			if v == true and typeof(spellId) == "string" and spellId ~= "" then
				table.insert(out, spellId)
			end
		end
	end
	table.sort(out)
	return out
end

-- TeleportData is based on the leader's profile/loadout; run-mode is included for Level1 logic.
local function buildTeleportDataForLeader(leader: Player, runMode: string, partyId: string?, leaderUserId: number?)
	local st = PlayerStateStore.Get(leader) or PlayerStateStore.Load(leader)
	local profile = getProfileSafe(leader)

	local weaponEntry = nil
	local weaponName = st and st.StarterWeaponName or nil

	if PlayerStateStore.GetEquippedWeaponInstance then
		weaponEntry = PlayerStateStore.GetEquippedWeaponInstance(leader)
	elseif st and typeof(st.EquippedWeaponInstanceId) == "string" and PlayerStateStore.GetWeaponInstance then
		local inst = PlayerStateStore.GetWeaponInstance(leader, st.EquippedWeaponInstanceId)
		if typeof(inst) == "table" then weaponEntry = inst end
	end

	if typeof(weaponEntry) == "table" and typeof(weaponEntry.weaponId) == "string" then
		weaponName = weaponEntry.weaponId
	end

	return {
		Profile = profile,
		StarterWeaponName = weaponName,
		StarterWeaponEntry = weaponEntry,
		EquippedWeaponInstanceId = st and st.EquippedWeaponInstanceId or nil,
		UnlockedSpells = buildUnlockedSpells(leader),
		RunMode = runMode,
		PartyId = partyId,
		PartyLeaderUserId = leaderUserId,
	}
end

local function tryTeleport(players: {Player}, placeId: number, tpData: any)
	if #players == 0 then return end
	local leader = players[1]
	if not canTeleport(leader) then return end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(tpData)
	-- Always use a reserved server so Single really means "only me",
	-- and party runs don't mix with randoms.
	local okReserve, code = pcall(function()
		return TeleportService:ReserveServer(placeId)
	end)
	if okReserve and typeof(code) == "string" then
		options.ReservedServerAccessCode = code
	end

	for _, plr in ipairs(players) do
		TeleportStatus:FireClient(plr, { type = "teleporting" })
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, players, options)
	end)
	if not ok then
		warn("[PortalToDungeon] TeleportAsync failed:", err)
		for _, plr in ipairs(players) do
			TeleportStatus:FireClient(plr, { type = "failed" })
		end
	end
end

prompt.Triggered:Connect(function(player: Player)
	if not player or not player.Parent then return end
	if not distanceOk(player) then return end
	if not canOpen(player) then return end
	if not tutorialComplete(player) then return end
	OpenLevelSelect:FireClient(player)
end)

-- levelKey: string
-- mode: "Single" | "Multi" (optional; defaults to Single)
RequestLevelTeleport.OnServerEvent:Connect(function(player: Player, levelKey: any, mode: any)
	if not player or not player.Parent then return end
	if typeof(levelKey) ~= "string" then return end
	if not tutorialComplete(player) then return end
	if not distanceOk(player) then return end

	local runMode = (typeof(mode) == "string" and (mode == "Multi" or mode == "Single")) and mode or "Single"

	local entry = Levels.GetByKey(levelKey)
	if not entry or typeof(entry.placeId) ~= "number" then
		warn("[PortalToDungeon] Unknown level key:", levelKey)
		return
	end

	-- Party support (optional): PartyService module can exist even if client UI isn't yet in place.
	local partyId, leaderUserId = nil, nil
	local group = { player }
	if runMode == "Multi" then
		local partyServiceMod = serverModules:FindFirstChild("PartyService")
		if partyServiceMod and partyServiceMod:IsA("ModuleScript") then
			local PartyService = require(partyServiceMod)
			local party = PartyService.GetPartyForPlayer(player)
			if not party then
				TeleportStatus:FireClient(player, { type = "failed", reason = "no_party" })
				return
			end
			if party.leaderUserId ~= player.UserId then
				TeleportStatus:FireClient(player, { type = "failed", reason = "not_leader" })
				return
			end
			group = PartyService.GetOnlinePartyPlayers(party)
			if #group < 2 then
				TeleportStatus:FireClient(player, { type = "failed", reason = "party_too_small" })
				return
			end
			partyId = party.id
			leaderUserId = party.leaderUserId
		else
			TeleportStatus:FireClient(player, { type = "failed", reason = "party_missing" })
			return
		end
	end

	local tpData = buildTeleportDataForLeader(player, runMode, partyId, leaderUserId)
	tryTeleport(group, entry.placeId, tpData)
end)

print("[PortalToDungeon] Ready (spells+loadout)")
