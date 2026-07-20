-- PortalToDungeon.server.lua
-- Builds per-player teleport data and blocks the teleport unless the unified profile confirms a save.

local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))
local CraftingService = require(serverModules:WaitForChild("CraftingService"))
local Levels = require(replicatedModules:WaitForChild("Levels"))
local SpellDefs = require(replicatedModules:WaitForChild("SpellDefinitions"))

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemote(name: string): RemoteEvent
	local remote = remoteEvents:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then return remote end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteEvents
	return remote
end

local OpenLevelSelect = ensureRemote("OpenLevelSelect")
local RequestLevelTeleport = ensureRemote("RequestLevelTeleport")
local TeleportStatus = ensureRemote("TeleportStatus")

local OPEN_COOLDOWN = 0.6
local TELEPORT_COOLDOWN = 2
local SAVE_BARRIER_TIMEOUT_SECONDS = 20
local TELEPORT_ATTEMPT_ATTRIBUTE = "DungeonTeleportAttemptId"

local lastOpen = {}
local lastTeleport = {}
local teleporting = {}
local nextAttemptId = 0

local function resolvePortalPart(): BasePart?
	local portalModel = workspace:FindFirstChild("Portal") or workspace:FindFirstChild("PortalModel")
	if portalModel and portalModel:IsA("Model") then
		local part = portalModel:FindFirstChild("PortalTeleport")
		if part and part:IsA("BasePart") then return part end
	end
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "PortalTeleport" then return descendant end
	end
	local stored = ServerStorage:FindFirstChild("Portal")
	if stored and stored:IsA("Model") then
		local clone = stored:Clone()
		clone.Parent = workspace
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

local prompt = portalPart:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
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
prompt.Parent = portalPart

local function fireStatus(players, payload)
	for _, player in ipairs(players) do
		if player.Parent == Players then TeleportStatus:FireClient(player, payload) end
	end
end

local function distanceOk(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - portalPart.Position).Magnitude <= 14
end

local function takeCooldown(map, userId: number, duration: number): boolean
	local current = os.clock()
	local previous = map[userId] or 0
	if current - previous < duration then return false end
	map[userId] = current
	return true
end

local function tutorialComplete(player: Player): boolean
	local attribute = player:GetAttribute("TutorialComplete")
	if attribute ~= nil then return attribute == true end
	local ok, state = pcall(PlayerStateStore.GetTutorialState, player)
	return ok and state and state.Complete == true or false
end

local function hasActiveMiningSession(player: Player): boolean
	local ok, snapshot = pcall(CraftingService.GetMiningSnapshot, player)
	return ok and typeof(snapshot) == "table" and typeof(snapshot.session) == "table" and snapshot.session.active == true
end

local function getMiningBlockReason(group, requester: Player)
	for _, player in ipairs(group) do
		if player.Parent == Players and hasActiveMiningSession(player) then
			return player == requester and "mining_active" or "party_member_mining"
		end
	end
	return nil
end

local function cloneNumberMap(raw)
	if typeof(raw) ~= "table" then return nil end
	local out = {}
	for key, value in pairs(raw) do
		if typeof(key) == "string" and typeof(value) == "number" then out[key] = value end
	end
	return next(out) and out or nil
end

local function compactWeaponEntry(raw, fallbackName)
	if typeof(raw) ~= "table" and (typeof(fallbackName) ~= "string" or fallbackName == "") then return nil end
	local id = typeof(raw) == "table" and (raw.id or raw.weaponId or raw.weaponName) or fallbackName
	id = id or fallbackName
	if typeof(id) ~= "string" or id == "" then return nil end
	local out = {
		id = id,
		weaponId = id,
		level = math.max(1, math.floor(tonumber(typeof(raw) == "table" and (raw.level or raw.Level) or 1) or 1)),
	}
	if typeof(raw) == "table" then
		local instanceId = raw.instanceId or raw.InstanceId
		if typeof(instanceId) == "string" and instanceId ~= "" then out.instanceId = instanceId end
		local rarity = raw.rarity or raw.Rarity
		if typeof(rarity) == "string" and rarity ~= "" then out.rarity = rarity end
		local prefix = raw.prefix or raw.Prefix
		if typeof(prefix) == "string" and prefix ~= "" then out.prefix = prefix end
		local rollStats = cloneNumberMap(raw.rollStats or raw.RollStats)
		if rollStats then out.rollStats = rollStats end
	end
	return out
end

local function getProfileLoadoutEntry(player: Player)
	local profile = PlayerData.Get(player)
	local first = typeof(profile.Loadout) == "table" and profile.Loadout[1] or nil
	if typeof(first) == "string" and first ~= "" then return compactWeaponEntry(nil, first) end
	return compactWeaponEntry(first, nil)
end

local function resolveWeaponSelection(player: Player, state)
	local weaponName = state and state.StarterWeaponName or nil
	local weaponEntry = PlayerStateStore.GetEquippedWeaponInstance(player)
	weaponEntry = compactWeaponEntry(weaponEntry, weaponName)
	if weaponEntry then weaponName = weaponEntry.id end
	if not weaponEntry and state and state.WeaponInstances and state.WeaponInstances[1] then
		weaponEntry = compactWeaponEntry(state.WeaponInstances[1], state.WeaponInstances[1].weaponId)
		weaponName = weaponEntry and weaponEntry.id or weaponName
	end
	if not weaponEntry then
		weaponEntry = getProfileLoadoutEntry(player)
		weaponName = weaponEntry and weaponEntry.id or weaponName
	end
	return weaponName, weaponEntry
end

local function numberMapsEqual(a, b): boolean
	if a == nil and b == nil then return true end
	if typeof(a) ~= "table" or typeof(b) ~= "table" then return false end
	for key, value in pairs(a) do if b[key] ~= value then return false end end
	for key, value in pairs(b) do if a[key] ~= value then return false end end
	return true
end

local function weaponEntriesEqual(a, b): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then return false end
	return tostring(a.id or a.weaponId or "") == tostring(b.id or b.weaponId or "")
		and math.max(1, math.floor(tonumber(a.level) or 1)) == math.max(1, math.floor(tonumber(b.level) or 1))
		and tostring(a.rarity or "") == tostring(b.rarity or "")
		and tostring(a.prefix or "") == tostring(b.prefix or "")
		and numberMapsEqual(a.rollStats, b.rollStats)
end

local function syncProfileLoadout(player: Player, weaponName, weaponEntry)
	if typeof(weaponName) ~= "string" or weaponName == "" then return end
	local profile = PlayerData.Get(player)
	local nextEntry = compactWeaponEntry(weaponEntry, weaponName)
	local current = typeof(profile.Loadout) == "table" and compactWeaponEntry(profile.Loadout[1], nil) or nil
	if current and weaponEntriesEqual(current, nextEntry) then return end
	profile.Loadout = { nextEntry }
	PlayerData.MarkDirty(player)
end

local function buildUnlockedSpells(player: Player)
	local out = {}
	local data = PlayerData.Get(player)
	for spellId, unlocked in pairs(data.spellsUnlocked or {}) do
		if unlocked == true and typeof(spellId) == "string" and spellId ~= "" then table.insert(out, spellId) end
	end
	table.sort(out)
	return out
end

local function buildSpellLoadout(player: Player)
	local resolved = PlayerData.ResolveSpellLoadout and PlayerData.ResolveSpellLoadout(player) or {}
	if #resolved > 0 then return resolved end
	return SpellDefs.BuildDefaultLoadout and SpellDefs.BuildDefaultLoadout(PlayerData.Get(player).spellsUnlocked or {}) or {}
end

local function buildTeleportPayload(group, baseData)
	local weaponByUserId = {}
	local weaponNameByUserId = {}
	local unlockedByUserId = {}
	local spellLoadoutByUserId = {}
	for _, player in ipairs(group) do
		local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
		local weaponName, weaponEntry = resolveWeaponSelection(player, state)
		syncProfileLoadout(player, weaponName, weaponEntry)
		local key = tostring(player.UserId)
		weaponByUserId[key] = { StarterWeaponName = weaponName, StarterWeaponEntry = compactWeaponEntry(weaponEntry, weaponName) }
		if typeof(weaponName) == "string" and weaponName ~= "" then weaponNameByUserId[key] = weaponName end
		unlockedByUserId[key] = buildUnlockedSpells(player)
		spellLoadoutByUserId[key] = buildSpellLoadout(player)
	end
	baseData.WeaponByUserId = weaponByUserId
	baseData.WeaponNameByUserId = weaponNameByUserId
	baseData.UnlockedSpellsByUserId = unlockedByUserId
	baseData.SpellLoadoutByUserId = spellLoadoutByUserId
	return baseData
end

local function persistGroup(group)
	local remaining = #group
	local failures = {}
	for _, player in ipairs(group) do
		task.spawn(function()
			local dataOk, dataErr = PlayerData.SaveBarrier(player, "dungeon_teleport")
			if not dataOk then
				failures[player.UserId] = tostring(dataErr or "save_failed")
			end
			remaining -= 1
		end)
	end
	local deadline = os.clock() + SAVE_BARRIER_TIMEOUT_SECONDS
	while remaining > 0 and os.clock() < deadline do task.wait(0.05) end
	if remaining > 0 then return false, "save_timeout" end
	if next(failures) then return false, "save_failed" end
	return true
end

local function lockGroup(group)
	for _, player in ipairs(group) do
		if teleporting[player.UserId] then return nil end
	end
	nextAttemptId += 1
	local attemptId = nextAttemptId
	for _, player in ipairs(group) do teleporting[player.UserId] = attemptId end
	return attemptId
end

local function unlockGroup(group, attemptId)
	for _, player in ipairs(group) do
		if teleporting[player.UserId] == attemptId then teleporting[player.UserId] = nil end
	end
end

local function unlockAttempt(attemptId, notifyFailure: boolean?)
	for userId, activeAttemptId in pairs(teleporting) do
		if activeAttemptId == attemptId then
			teleporting[userId] = nil
			if notifyFailure == true then
				local player = Players:GetPlayerByUserId(userId)
				if player then TeleportStatus:FireClient(player, { type = "failed", reason = "teleport_failed" }) end
			end
		end
	end
end

local function tryTeleport(group, placeId: number, teleportData)
	local requester = group[1]
	if not requester or not takeCooldown(lastTeleport, requester.UserId, TELEPORT_COOLDOWN) then return end
	local attemptId = lockGroup(group)
	if not attemptId then return end

	local payloadOk, payloadOrError = pcall(buildTeleportPayload, group, teleportData)
	if not payloadOk then
		unlockGroup(group, attemptId)
		warn("[PortalToDungeon] Failed to build teleport payload:", payloadOrError)
		fireStatus(group, { type = "failed", reason = "payload_failed" })
		return
	end

	fireStatus(group, { type = "saving" })
	local saved, saveReason = persistGroup(group)
	if not saved then
		unlockGroup(group, attemptId)
		warn("[PortalToDungeon] Save barrier blocked teleport:", saveReason)
		fireStatus(group, { type = "failed", reason = saveReason })
		return
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(payloadOrError)
	options:SetAttribute(TELEPORT_ATTEMPT_ATTRIBUTE, attemptId)
	local reserveOk, accessCode = pcall(TeleportService.ReserveServer, TeleportService, placeId)
	if reserveOk and typeof(accessCode) == "string" then options.ReservedServerAccessCode = accessCode end

	fireStatus(group, { type = "teleporting" })
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, placeId, group, options)
	if not ok then
		unlockGroup(group, attemptId)
		warn("[PortalToDungeon] TeleportAsync failed:", err)
		fireStatus(group, { type = "failed", reason = "teleport_failed" })
	end
end

prompt.Triggered:Connect(function(player)
	if player.Parent ~= Players or not distanceOk(player) then return end
	if not takeCooldown(lastOpen, player.UserId, OPEN_COOLDOWN) then return end
	if not tutorialComplete(player) then return end
	if hasActiveMiningSession(player) then
		TeleportStatus:FireClient(player, { type = "failed", reason = "mining_active" })
		return
	end
	OpenLevelSelect:FireClient(player)
end)

RequestLevelTeleport.OnServerEvent:Connect(function(player, levelKey, mode)
	if player.Parent ~= Players or typeof(levelKey) ~= "string" then return end
	if not tutorialComplete(player) or not distanceOk(player) then return end
	if hasActiveMiningSession(player) then
		TeleportStatus:FireClient(player, { type = "failed", reason = "mining_active" })
		return
	end

	local entry = Levels.GetByKey(levelKey)
	if not entry or typeof(entry.placeId) ~= "number" then
		TeleportStatus:FireClient(player, { type = "failed", reason = entry and "level_unavailable" or "unknown_level" })
		return
	end

	local runMode = mode == "Multi" and "Multi" or "Single"
	local group = { player }
	local partyId, leaderUserId = nil, nil
	if runMode == "Multi" then
		local module = serverModules:FindFirstChild("PartyService")
		if not (module and module:IsA("ModuleScript")) then
			TeleportStatus:FireClient(player, { type = "failed", reason = "party_missing" })
			return
		end
		local PartyService = require(module)
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
	end

	local miningReason = getMiningBlockReason(group, player)
	if miningReason then
		TeleportStatus:FireClient(player, { type = "failed", reason = miningReason })
		return
	end

	local leaderState = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	local leaderWeaponName, leaderWeaponEntry = resolveWeaponSelection(player, leaderState)
	local teleportData = {
		StarterWeaponName = leaderWeaponName,
		StarterWeaponEntry = compactWeaponEntry(leaderWeaponEntry, leaderWeaponName),
		UnlockedSpells = buildUnlockedSpells(player),
		SpellLoadout = buildSpellLoadout(player),
		RunMode = runMode,
		PartyId = partyId,
		PartyLeaderUserId = leaderUserId,
		LevelKey = entry.key,
	}
	tryTeleport(group, entry.placeId, teleportData)
end)

TeleportService.TeleportInitFailed:Connect(function(player, _result, errorMessage, _placeId, options)
	local attemptId = options and tonumber(options:GetAttribute(TELEPORT_ATTEMPT_ATTRIBUTE))
	if not attemptId or teleporting[player.UserId] ~= attemptId then return end
	warn("[PortalToDungeon] Teleport initialization failed:", player.Name, errorMessage)
	unlockAttempt(attemptId, true)
end)

Players.PlayerRemoving:Connect(function(player)
	lastOpen[player.UserId] = nil
	lastTeleport[player.UserId] = nil
	teleporting[player.UserId] = nil
end)

print("[PortalToDungeon] Ready (save barrier + per-player loadout)")
