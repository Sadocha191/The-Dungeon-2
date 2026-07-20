-- PlayerData.lua
-- Session-owned persistence for GlobalPlayerProgress_v1.
-- This file is intentionally identical in Four Peaks and Level.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileLease = require(script.Parent:WaitForChild("ProfileLease"))
local Schema = require(script.Parent:WaitForChild("PlayerProfileSchema"))

local store = DataStoreService:GetDataStore("GlobalPlayerProgress_v1")
local legacyStore = DataStoreService:GetDataStore("GlobalProfile_v4")
local lease = ProfileLease.new(store, {
	name = "GlobalPlayerProgress",
	schemaVersion = 2,
	leaseSeconds = 180,
	acquireTimeoutSeconds = 30,
})

local PlayerData = {}
PlayerData._cache = {}
PlayerData._dirty = {}
PlayerData._saving = {}
PlayerData._revision = {}
PlayerData._volatile = {}
PlayerData._loadErrors = {}
PlayerData._loading = {}

local SAVE_WAIT_TIMEOUT_SECONDS = 12
local RELEASE_SAVE_ATTEMPTS = 3
local MAINTENANCE_INTERVAL_SECONDS = 60
local SHUTDOWN_TIMEOUT_SECONDS = 25
local closing = false

local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = nil
if replicatedModules and replicatedModules:FindFirstChild("SpellDefinitions") then
	local ok, result = pcall(require, replicatedModules.SpellDefinitions)
	if ok then SpellDefs = result end
end

local function keyFor(userId: number): string
	return tostring(userId)
end

local function waitForConcurrentLoad(userId: number)
	while PlayerData._loading[userId] do
		task.wait()
	end
end

local function failLoad(player: Player, reason: any)
	local userId = player.UserId
	local message = tostring(reason or "ProfileLoadFailed")
	PlayerData._loadErrors[userId] = message
	warn(string.format("[PlayerData] Failed to load profile for %s (%d): %s", player.Name, userId, message))
	if not RunService:IsStudio() and player.Parent == Players then
		task.defer(function()
			if player.Parent == Players then
				player:Kick("Your data could not be loaded safely. Please rejoin in a moment.")
			end
		end)
	end
	return nil, message
end

local function loadSeed(userId: number)
	local key = keyFor(userId)
	local mainOk, mainValue = lease:Read(store, key)
	if not mainOk then
		return false, nil, mainValue
	end
	if mainValue ~= nil then
		if typeof(mainValue) ~= "table" then
			return false, nil, "CorruptProfileValue"
		end
		return true, mainValue, nil
	end

	-- Legacy is consulted only after a successful main-store read confirms no profile.
	local legacyOk, legacyValue = lease:Read(legacyStore, key)
	if not legacyOk then
		return false, nil, legacyValue
	end
	if legacyValue ~= nil and typeof(legacyValue) ~= "table" then
		return false, nil, "CorruptLegacyProfileValue"
	end
	return true, legacyValue or Schema.Default(), nil
end

function PlayerData.Load(player: Player)
	local userId = player.UserId
	if PlayerData._cache[userId] then
		return PlayerData._cache[userId]
	end
	if PlayerData._loadErrors[userId] then
		return nil, PlayerData._loadErrors[userId]
	end

	waitForConcurrentLoad(userId)
	if PlayerData._cache[userId] then
		return PlayerData._cache[userId]
	end
	if PlayerData._loadErrors[userId] then
		return nil, PlayerData._loadErrors[userId]
	end

	PlayerData._loading[userId] = true
	local seedOk, seed, seedError = loadSeed(userId)
	if not seedOk then
		PlayerData._loading[userId] = nil
		if RunService:IsStudio() then
			local volatile = Schema.Sanitize(Schema.Default())
			PlayerData._cache[userId] = volatile
			PlayerData._volatile[userId] = true
			PlayerData._dirty[userId] = false
			PlayerData._revision[userId] = 0
			warn("[PlayerData] DataStore unavailable in Studio; using non-persistent profile:", seedError)
			return volatile
		end
		return failLoad(player, seedError)
	end

	local acquired, profileOrError = lease:Acquire(keyFor(userId), Schema.Sanitize(seed))
	PlayerData._loading[userId] = nil
	if not acquired then
		if RunService:IsStudio() then
			local volatile = Schema.Sanitize(seed)
			PlayerData._cache[userId] = volatile
			PlayerData._volatile[userId] = true
			PlayerData._dirty[userId] = false
			PlayerData._revision[userId] = 0
			warn("[PlayerData] Profile lease unavailable in Studio; using non-persistent profile:", profileOrError)
			return volatile
		end
		return failLoad(player, profileOrError)
	end

	local profile = Schema.Sanitize(profileOrError)
	if player.Parent == Players then
		PlayerData._cache[userId] = profile
		PlayerData._dirty[userId] = false
		PlayerData._revision[userId] = 0
		PlayerData._volatile[userId] = nil
		PlayerData._loadErrors[userId] = nil
		return profile
	end

	-- The player left while loading. Release the acquired lease immediately.
	lease:Release(keyFor(userId), profile)
	return nil, "PlayerLeftDuringLoad"
end

function PlayerData.Get(player: Player)
	local profile = PlayerData._cache[player.UserId]
	if profile then return profile end
	local loaded, err = PlayerData.Load(player)
	if loaded then return loaded end
	error(string.format("[PlayerData] Profile unavailable for %s: %s", player.Name, tostring(err)), 2)
end

function PlayerData.IsReady(player: Player): boolean
	return PlayerData._cache[player.UserId] ~= nil and PlayerData._loadErrors[player.UserId] == nil
end

function PlayerData.GetLoadError(player: Player): string?
	return PlayerData._loadErrors[player.UserId]
end

function PlayerData.RollNextXp(level: number): number
	return 120 + (level - 1) * 70
end

function PlayerData.MarkDirty(player: Player)
	local userId = player.UserId
	if not PlayerData._cache[userId] then return end
	PlayerData._revision[userId] = (PlayerData._revision[userId] or 0) + 1
	PlayerData._dirty[userId] = true
end

local function waitForSave(userId: number): boolean
	local deadline = os.clock() + SAVE_WAIT_TIMEOUT_SECONDS
	while PlayerData._saving[userId] and os.clock() < deadline do
		task.wait(0.05)
	end
	return PlayerData._saving[userId] ~= true
end

function PlayerData.Save(player: Player, force: boolean?, reason: string?)
	local userId = player.UserId
	if PlayerData._volatile[userId] then return true, "VolatileStudioProfile" end
	if PlayerData._loadErrors[userId] then return false, "ProfileLoadFailed" end

	if PlayerData._saving[userId] then
		if force ~= true then return false, "SaveInProgress" end
		if not waitForSave(userId) then return false, "SaveWaitTimeout" end
	end

	local profile = PlayerData._cache[userId]
	if not profile then return false, "ProfileMissing" end
	if force ~= true and PlayerData._dirty[userId] ~= true then return true end

	local revision = PlayerData._revision[userId] or 0
	local snapshot = Schema.Clone(profile)
	PlayerData._saving[userId] = true
	local ok, savedOrError = lease:Save(keyFor(userId), snapshot)
	PlayerData._saving[userId] = nil

	if ok then
		if typeof(savedOrError) == "table" and PlayerData._cache[userId] == profile then
			profile._profileMeta = Schema.Clone(savedOrError._profileMeta)
		end
		if (PlayerData._revision[userId] or 0) == revision then
			PlayerData._dirty[userId] = false
		else
			PlayerData._dirty[userId] = true
		end
		return true
	end

	PlayerData._dirty[userId] = true
	warn(string.format("[PlayerData] Save failed for %s (%d), reason=%s: %s", player.Name, userId, tostring(reason or "save"), tostring(savedOrError)))
	return false, savedOrError
end

function PlayerData.SaveBarrier(player: Player, reason: string?)
	return PlayerData.Save(player, true, reason or "barrier")
end

local function retryOfflineRelease(userId: number, snapshot)
	task.spawn(function()
		for attempt = 1, RELEASE_SAVE_ATTEMPTS do
			local ok, err = lease:Release(keyFor(userId), snapshot)
			if ok then return end
			warn(string.format("[PlayerData] Offline release retry %d failed for %d: %s", attempt, userId, tostring(err)))
			if attempt < RELEASE_SAVE_ATTEMPTS then task.wait(attempt) end
		end
	end)
end

function PlayerData.Release(player: Player, force: boolean?)
	if not player then return false, "InvalidPlayer" end
	local userId = player.UserId
	waitForConcurrentLoad(userId)
	if PlayerData._saving[userId] then waitForSave(userId) end

	local profile = PlayerData._cache[userId]
	if not profile then
		PlayerData._loadErrors[userId] = nil
		return true
	end

	local ok, err = true, nil
	if not PlayerData._volatile[userId] then
		local snapshot = Schema.Clone(profile)
		ok, err = lease:Release(keyFor(userId), snapshot)
		if not ok and force == true then
			retryOfflineRelease(userId, snapshot)
		end
	end

	PlayerData._cache[userId] = nil
	PlayerData._dirty[userId] = nil
	PlayerData._saving[userId] = nil
	PlayerData._revision[userId] = nil
	PlayerData._volatile[userId] = nil
	PlayerData._loadErrors[userId] = nil
	PlayerData._loading[userId] = nil
	return ok, err
end

function PlayerData.Reset(player: Player)
	local userId = player.UserId
	PlayerData._cache[userId] = Schema.Sanitize(Schema.Default())
	PlayerData._revision[userId] = (PlayerData._revision[userId] or 0) + 1
	PlayerData._dirty[userId] = true
end

local function validateSpellLoadout(rawLoadout, unlocked)
	if SpellDefs and SpellDefs.ValidateSpellLoadout then
		return SpellDefs.ValidateSpellLoadout(rawLoadout, unlocked)
	end
	return Schema.SanitizeStringList(rawLoadout)
end

function PlayerData.GetSpellLoadout(player: Player)
	local data = PlayerData.Get(player)
	data.spellLoadout = validateSpellLoadout(data.spellLoadout, data.spellsUnlocked)
	return Schema.SanitizeStringList(data.spellLoadout)
end

function PlayerData.ResolveSpellLoadout(player: Player)
	local data = PlayerData.Get(player)
	local loadout = validateSpellLoadout(data.spellLoadout, data.spellsUnlocked)
	if #loadout > 0 or data.spellLoadoutConfigured == true then return loadout end
	if SpellDefs and SpellDefs.BuildDefaultLoadout then
		return SpellDefs.BuildDefaultLoadout(data.spellsUnlocked)
	end
	return {}
end

function PlayerData.SetSpellLoadout(player: Player, rawLoadout)
	local data = PlayerData.Get(player)
	local nextLoadout = validateSpellLoadout(rawLoadout, data.spellsUnlocked)
	local current = validateSpellLoadout(data.spellLoadout, data.spellsUnlocked)
	local changed = #nextLoadout ~= #current
	if not changed then
		for index, id in ipairs(nextLoadout) do
			if current[index] ~= id then changed = true break end
		end
	end
	if changed then data.spellLoadout = nextLoadout end
	if data.spellLoadoutConfigured ~= true then changed = true end
	data.spellLoadoutConfigured = true
	if changed then PlayerData.MarkDirty(player) end
	return nextLoadout, changed
end

local function normalizeCodexCategory(category)
	local requested = tostring(category or "")
	for _, known in ipairs(Schema.CODEX_CATEGORIES) do
		if string.lower(known) == string.lower(requested) then return known end
	end
	return nil
end

function PlayerData.DiscoverCodex(player: Player, category, id, _reason)
	category = normalizeCodexCategory(category)
	if not category or typeof(id) ~= "string" or id == "" then return false end
	local data = PlayerData.Get(player)
	data.Codex = Schema.SanitizeCodex(data.Codex)
	if data.Codex.Discovered[category][id] == true then return false end
	data.Codex.Discovered[category][id] = true
	PlayerData.MarkDirty(player)
	return true
end

function PlayerData.MarkCodexSeen(player: Player, category, id)
	category = normalizeCodexCategory(category)
	if not category or typeof(id) ~= "string" or id == "" then return false end
	local data = PlayerData.Get(player)
	data.Codex = Schema.SanitizeCodex(data.Codex)
	if data.Codex.Seen[category][id] == true then return false end
	data.Codex.Seen[category][id] = true
	PlayerData.MarkDirty(player)
	return true
end

function PlayerData.GetCodexSnapshot(player: Player)
	local data = PlayerData.Get(player)
	data.Codex = Schema.SanitizeCodex(data.Codex)
	return Schema.Clone(data.Codex)
end

function PlayerData.GetLevelRecordsSnapshot(player: Player)
	return Schema.Clone(Schema.SanitizeLevelRecords(PlayerData.Get(player).levelRecords))
end

function PlayerData.UpdateLevelRecord(player: Player, levelKey: string, kills: number?, completionSeconds: number?, completed: boolean?)
	local data = PlayerData.Get(player)
	if typeof(levelKey) ~= "string" or levelKey == "" then return nil, false end
	data.levelRecords = Schema.SanitizeLevelRecords(data.levelRecords)
	local current = data.levelRecords[levelKey]
	if typeof(current) ~= "table" then
		current = { highscore = 0, speedrun = nil }
		data.levelRecords[levelKey] = current
	end
	local changed = false
	local killCount = math.max(0, Schema.ClampInt(kills))
	if killCount > math.max(0, Schema.ClampInt(current.highscore)) then
		current.highscore = killCount
		changed = true
	end
	local clearTime = tonumber(completionSeconds)
	if completed == true and clearTime and clearTime > 0 then
		local best = tonumber(current.speedrun)
		if not best or clearTime < best then
			current.speedrun = clearTime
			changed = true
		end
	end
	if changed then PlayerData.MarkDirty(player) end
	return current, changed
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		PlayerData.Load(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player, true)
end)

task.spawn(function()
	while not closing do
		task.wait(MAINTENANCE_INTERVAL_SECONDS)
		if closing then break end
		for _, player in ipairs(Players:GetPlayers()) do
			local userId = player.UserId
			if PlayerData._cache[userId] and not PlayerData._volatile[userId] then
				if PlayerData._dirty[userId] then
					PlayerData.Save(player, false, "autosave")
				else
					local ok, err = lease:Renew(keyFor(userId))
					if not ok then
						warn("[PlayerData] Lease renewal failed:", player.Name, err)
						if err == "SessionLost" and player.Parent == Players then
							player:Kick("Your data session changed unexpectedly. Please rejoin.")
						end
					end
				end
			end
		end
	end
end)

game:BindToClose(function()
	closing = true
	local remaining = 0
	for _, player in ipairs(Players:GetPlayers()) do
		remaining += 1
		task.spawn(function()
			PlayerData.Release(player, true)
			remaining -= 1
		end)
	end
	local deadline = os.clock() + SHUTDOWN_TIMEOUT_SECONDS
	while remaining > 0 and os.clock() < deadline do task.wait(0.05) end
end)

return PlayerData
