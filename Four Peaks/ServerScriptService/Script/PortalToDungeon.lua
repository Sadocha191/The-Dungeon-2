-- PortalToDungeon.server.lua (Lobby)
-- Teleports selected players from lobby to a dungeon level.
-- TeleportData contains per-player loadout so each player keeps own weapon.

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = (
	ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
)

local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))
local CraftingService = require(serverModules:WaitForChild("CraftingService"))
local Levels = require(replicatedModules:WaitForChild("Levels"))

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemote(name: string): RemoteEvent
	local ev = remoteEvents:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then
		return ev
	end
	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remoteEvents
	return ev
end

local OpenLevelSelect = ensureRemote("OpenLevelSelect")
local RequestLevelTeleport = ensureRemote("RequestLevelTeleport")
local TeleportStatus = ensureRemote("TeleportStatus")

local function resolvePortalPart(): BasePart?
	local ws = workspace
	local portalModel = ws:FindFirstChild("Portal") or ws:FindFirstChild("PortalModel")
	if portalModel and portalModel:IsA("Model") then
		local part = portalModel:FindFirstChild("PortalTeleport")
		if part and part:IsA("BasePart") then
			return part
		end
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
		if part and part:IsA("BasePart") then
			return part
		end
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
	prompt.Parent = portalPart
end
prompt.Name = "PortalPrompt"
prompt.ObjectText = "Portal"
prompt.ActionText = "Select level"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = false
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
prompt.Style = Enum.ProximityPromptStyle.Default
prompt.Enabled = true

print(string.format(
	"[PortalToDungeon] Prompt ready part=%s prompt=%s enabled=%s action=%s object=%s maxDistance=%.1f hold=%.1f",
	portalPart:GetFullName(),
	prompt:GetFullName(),
	tostring(prompt.Enabled),
	tostring(prompt.ActionText),
	tostring(prompt.ObjectText),
	prompt.MaxActivationDistance,
	prompt.HoldDuration
))

local lastOpen: {[number]: number} = {}
local lastTp: {[number]: number} = {}
local OPEN_COOLDOWN = 0.6
local TP_COOLDOWN = 2.0

local function distanceOk(player: Player): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	return (hrp.Position - portalPart.Position).Magnitude <= 14
end

local function tutorialComplete(player: Player): boolean
	local attr = player:GetAttribute("TutorialComplete")
	if attr ~= nil then
		return attr == true
	end
	local ok, state = pcall(function()
		return PlayerStateStore.GetTutorialState(player)
	end)
	return ok and state and state.Complete == true or false
end

local function canOpen(player: Player): boolean
	local now = os.clock()
	local last = lastOpen[player.UserId] or 0
	if (now - last) < OPEN_COOLDOWN then
		return false
	end
	lastOpen[player.UserId] = now
	return true
end

local function canTeleport(player: Player): boolean
	local now = os.clock()
	local last = lastTp[player.UserId] or 0
	if (now - last) < TP_COOLDOWN then
		return false
	end
	lastTp[player.UserId] = now
	return true
end

local function hasActiveMiningSession(player: Player): boolean
	local ok, snapshot = pcall(function()
		return CraftingService.GetMiningSnapshot(player)
	end)
	return ok
		and typeof(snapshot) == "table"
		and typeof(snapshot.session) == "table"
		and snapshot.session.active == true
end

local function getMiningBlockReason(players: {Player}, requester: Player): string?
	for _, candidate in ipairs(players) do
		if candidate and candidate.Parent and hasActiveMiningSession(candidate) then
			if candidate == requester then
				return "mining_active"
			end
			return "party_member_mining"
		end
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

local function cloneNumberMap(src: any): {[string]: number}?
	if typeof(src) ~= "table" then
		return nil
	end
	local out: {[string]: number} = {}
	for k, v in pairs(src) do
		if typeof(k) == "string" and typeof(v) == "number" then
			out[k] = v
		end
	end
	return (next(out) ~= nil) and out or nil
end

local function sanitizeWeaponEntry(rawEntry: any, fallbackWeaponName: string?): {[string]: any}?
	if typeof(rawEntry) ~= "table" then
		return nil
	end

	local id = rawEntry.id or rawEntry.weaponId or rawEntry.weaponName or fallbackWeaponName
	if typeof(id) ~= "string" or id == "" then
		return nil
	end

	local clean: {[string]: any} = {
		id = id,
		weaponId = id,
		level = math.max(1, math.floor(tonumber(rawEntry.level or rawEntry.Level) or 1)),
	}

	local instanceId = rawEntry.instanceId or rawEntry.InstanceId
	if typeof(instanceId) == "string" and instanceId ~= "" then
		clean.instanceId = instanceId
	end

	local rarity = rawEntry.rarity or rawEntry.Rarity
	if typeof(rarity) == "string" and rarity ~= "" then
		clean.rarity = rarity
	end

	local prefix = rawEntry.prefix or rawEntry.Prefix
	if typeof(prefix) == "string" and prefix ~= "" then
		clean.prefix = prefix
	end

	local rollStats = cloneNumberMap(rawEntry.rollStats or rawEntry.RollStats)
	if rollStats then
		clean.rollStats = rollStats
	end

	local stats = cloneNumberMap(rawEntry.stats or rawEntry.Stats)
	if stats then
		clean.stats = stats
	end

	return clean
end

local function getProfileLoadoutEntry(player: Player): {[string]: any}?
	local profile = PlayerData.Get(player)
	if typeof(profile) ~= "table" or typeof(profile.Loadout) ~= "table" then
		return nil
	end

	local first = profile.Loadout[1]
	if typeof(first) == "string" and first ~= "" then
		return {
			id = first,
			weaponId = first,
			level = 1,
		}
	end

	return sanitizeWeaponEntry(first, nil)
end

local function resolveWeaponSelection(player: Player, state: any): (string?, {[string]: any}?)
	local weaponName = state and state.StarterWeaponName or nil
	local weaponEntry = nil

	if PlayerStateStore.GetEquippedWeaponInstance then
		weaponEntry = PlayerStateStore.GetEquippedWeaponInstance(player)
	elseif state and typeof(state.EquippedWeaponInstanceId) == "string" and PlayerStateStore.GetWeaponInstance then
		local inst = PlayerStateStore.GetWeaponInstance(player, state.EquippedWeaponInstanceId)
		if typeof(inst) == "table" then
			weaponEntry = inst
		end
	end

	weaponEntry = sanitizeWeaponEntry(weaponEntry, weaponName)
	if weaponEntry and typeof(weaponEntry.id) == "string" and weaponEntry.id ~= "" then
		weaponName = weaponEntry.id
	end

	if (typeof(weaponName) ~= "string" or weaponName == "")
		and state
		and typeof(state.WeaponInstances) == "table"
		and typeof(state.WeaponInstances[1]) == "table"
		and typeof(state.WeaponInstances[1].weaponId) == "string"
	then
		weaponEntry = sanitizeWeaponEntry(state.WeaponInstances[1], state.WeaponInstances[1].weaponId)
		weaponName = state.WeaponInstances[1].weaponId
	end

	if not weaponEntry then
		local profileEntry = getProfileLoadoutEntry(player)
		if profileEntry then
			weaponEntry = profileEntry
			weaponName = profileEntry.id
		end
	end

	return weaponName, weaponEntry
end

local function compactWeaponEntry(entry: any): {[string]: any}?
	if typeof(entry) ~= "table" then
		return nil
	end
	local id = entry.id or entry.weaponId or entry.weaponName
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	local out: {[string]: any} = {
		id = id,
		weaponId = id,
		level = math.max(1, math.floor(tonumber(entry.level) or 1)),
	}
	if typeof(entry.rarity) == "string" and entry.rarity ~= "" then
		out.rarity = entry.rarity
	end
	if typeof(entry.prefix) == "string" and entry.prefix ~= "" then
		out.prefix = entry.prefix
	end
	if typeof(entry.rollStats) == "table" then
		local roll = cloneNumberMap(entry.rollStats)
		if roll then
			out.rollStats = roll
		end
	end
	return out
end

local function numberMapsEqual(a: any, b: any): boolean
	if a == nil and b == nil then
		return true
	end
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return false
	end

	for key, value in pairs(a) do
		if typeof(key) == "string" and typeof(value) == "number" then
			if b[key] ~= value then
				return false
			end
		end
	end

	for key, value in pairs(b) do
		if typeof(key) == "string" and typeof(value) == "number" then
			if a[key] ~= value then
				return false
			end
		end
	end

	return true
end

local function weaponEntriesEqual(a: any, b: any): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return false
	end

	return tostring(a.id or a.weaponId or "") == tostring(b.id or b.weaponId or "")
		and math.max(1, math.floor(tonumber(a.level) or 1)) == math.max(1, math.floor(tonumber(b.level) or 1))
		and tostring(a.rarity or "") == tostring(b.rarity or "")
		and tostring(a.prefix or "") == tostring(b.prefix or "")
		and numberMapsEqual(a.rollStats, b.rollStats)
end

local function syncProfileLoadout(player: Player, weaponName: string?, weaponEntry: any)
	if typeof(weaponName) ~= "string" or weaponName == "" then
		return
	end

	local profile = PlayerData.Get(player)
	if typeof(profile) ~= "table" then
		return
	end

	local nextEntry = compactWeaponEntry(weaponEntry) or {
		id = weaponName,
		weaponId = weaponName,
		level = 1,
	}

	local currentEntry = nil
	if typeof(profile.Loadout) == "table" and typeof(profile.Loadout[1]) == "table" then
		currentEntry = compactWeaponEntry(profile.Loadout[1])
	end

	if currentEntry and weaponEntriesEqual(currentEntry, nextEntry) then
		return
	end

	profile.Loadout = { nextEntry }
	if PlayerData.MarkDirty then
		PlayerData.MarkDirty(player)
	end
end

local function buildTeleportDataForLeader(leader: Player, runMode: string, partyId: string?, leaderUserId: number?)
	local st = PlayerStateStore.Get(leader) or PlayerStateStore.Load(leader)
	local weaponName, weaponEntry = resolveWeaponSelection(leader, st)

	return {
		StarterWeaponName = weaponName,
		StarterWeaponEntry = compactWeaponEntry(weaponEntry),
		UnlockedSpells = buildUnlockedSpells(leader),
		RunMode = runMode,
		PartyId = partyId,
		PartyLeaderUserId = leaderUserId,
	}
end

local function tryTeleport(players: {Player}, placeId: number, tpData: any)
	if #players == 0 then
		return
	end

	local requester = players[1]
	if not canTeleport(requester) then
		return
	end

	local weaponByUserId: {[string]: any} = {}
	local weaponNameByUserId: {[string]: string} = {}
	for _, p in ipairs(players) do
		local st = PlayerStateStore.Get(p) or PlayerStateStore.Load(p)
		local weaponName, weaponEntry = resolveWeaponSelection(p, st)
		local uidKey = tostring(p.UserId)
		syncProfileLoadout(p, weaponName, weaponEntry)
		weaponByUserId[uidKey] = {
			StarterWeaponName = weaponName,
			StarterWeaponEntry = compactWeaponEntry(weaponEntry),
		}
		if typeof(weaponName) == "string" and weaponName ~= "" then
			weaponNameByUserId[uidKey] = weaponName
		end
	end
	tpData.WeaponByUserId = weaponByUserId
	tpData.WeaponNameByUserId = weaponNameByUserId

	for _, p in ipairs(players) do
		if PlayerData.Save then
			pcall(function()
				PlayerData.Save(p, false)
			end)
		end
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(tpData)

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
	if not player or not player.Parent then
		return
	end
	if not distanceOk(player) then
		return
	end
	if not canOpen(player) then
		return
	end
	if not tutorialComplete(player) then
		return
	end
	if hasActiveMiningSession(player) then
		TeleportStatus:FireClient(player, { type = "failed", reason = "mining_active" })
		return
	end
	OpenLevelSelect:FireClient(player)
end)

RequestLevelTeleport.OnServerEvent:Connect(function(player: Player, levelKey: any, mode: any)
	if not player or not player.Parent then
		return
	end
	if typeof(levelKey) ~= "string" then
		return
	end
	if not tutorialComplete(player) then
		return
	end
	if not distanceOk(player) then
		return
	end
	if hasActiveMiningSession(player) then
		TeleportStatus:FireClient(player, { type = "failed", reason = "mining_active" })
		return
	end

	local runMode = (typeof(mode) == "string" and (mode == "Multi" or mode == "Single")) and mode or "Single"

	local entry = Levels.GetByKey(levelKey)
	if not entry then
		warn("[PortalToDungeon] Unknown level key:", levelKey)
		TeleportStatus:FireClient(player, { type = "failed", reason = "unknown_level" })
		return
	end

	if typeof(entry.placeId) ~= "number" then
		TeleportStatus:FireClient(player, { type = "failed", reason = "level_unavailable" })
		return
	end

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

	local miningBlockReason = getMiningBlockReason(group, player)
	if miningBlockReason then
		TeleportStatus:FireClient(player, { type = "failed", reason = miningBlockReason })
		return
	end

	local tpData = buildTeleportDataForLeader(player, runMode, partyId, leaderUserId)
	tpData.LevelKey = entry.key
	tryTeleport(group, entry.placeId, tpData)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastOpen[player.UserId] = nil
	lastTp[player.UserId] = nil
end)

print("[PortalToDungeon] Ready (spells+loadout)")
