-- PlayerStateStore.lua
-- Compatibility API for inventory/profile state embedded in GlobalPlayerProgress_v1.
-- PlayerState_v2 is read only during one-time migration and remains as a rollback backup.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local ProfileLease = require(script.Parent:WaitForChild("ProfileLease"))
local StateSchema = require(script.Parent:WaitForChild("PlayerStateSchema"))

local LEGACY_STORE = DataStoreService:GetDataStore("PlayerState_v2")
local legacyLease = ProfileLease.new(LEGACY_STORE, {
	name = "PlayerState_v2_migration",
	schemaVersion = 2,
	leaseSeconds = 180,
	acquireTimeoutSeconds = 30,
	readAttempts = 5,
	updateAttempts = 5,
})

local Store = {}
local cache = {}
local loadingByUserId = {}
local loadErrors = {}

local MIGRATION_VERSION = 1

local function legacyKey(userId: number): string
	return "u:" .. tostring(userId)
end

local function generateInstanceId(): string
	return HttpService:GenerateGUID(false)
end

local function newWeaponInstance(weaponId: string, rarity: string?, level: number?, prefix: string?, rollStats: any?)
	return {
		instanceId = generateInstanceId(),
		weaponId = weaponId,
		rarity = tostring(rarity or ""),
		level = math.max(1, math.floor(tonumber(level) or 1)),
		prefix = tostring(prefix or "Standard"),
		rollStats = typeof(rollStats) == "table" and StateSchema.Clone(rollStats) or {},
		createdAt = os.time(),
		upgradeSilverSpent = 0,
		upgradeMaterialsSpent = {},
	}
end

local function setReadyAttributes(player: Player, ready: boolean, reason: string?)
	if player.Parent == Players then
		player:SetAttribute("PlayerStateReady", ready)
		player:SetAttribute("PlayerStateLoadError", reason)
	end
end

local function failLoad(player: Player, reason)
	local userId = player.UserId
	local message = tostring(reason or "PlayerStateLoadFailed")
	loadingByUserId[userId] = nil
	loadErrors[userId] = message
	setReadyAttributes(player, false, message)
	warn(string.format("[PlayerStateStore] Failed to prepare embedded state for %s (%d): %s", player.Name, userId, message))

	if not RunService:IsStudio() and player.Parent == Players then
		task.defer(function()
			if player.Parent == Players then
				player:Kick("Your inventory could not be loaded safely. Please rejoin in a moment.")
			end
		end)
	end
	return nil, message
end

local function releaseLegacyLease(userId: number, snapshot)
	if typeof(snapshot) ~= "table" then return end
	task.spawn(function()
		local ok, err = legacyLease:Release(legacyKey(userId), snapshot)
		if not ok then
			warn("[PlayerStateStore] Legacy migration lease release failed:", userId, err)
		end
	end)
end

local function migrateLegacyState(player: Player, profile)
	local userId = player.UserId
	local existing = typeof(profile.PlayerState) == "table" and profile.PlayerState or nil
	local readOk, legacyOrError = legacyLease:Read(LEGACY_STORE, legacyKey(userId))
	if not readOk then
		if RunService:IsStudio() then
			warn("[PlayerStateStore] Legacy store unavailable in Studio; using embedded/default state:", legacyOrError)
			legacyOrError = nil
		else
			return nil, legacyOrError
		end
	end
	if legacyOrError ~= nil and typeof(legacyOrError) ~= "table" then
		return nil, "CorruptLegacyPlayerState"
	end

	local acquiredLegacy = nil
	local migrationSeed = existing or StateSchema.Default()
	if typeof(legacyOrError) == "table" then
		local acquired, stateOrError = legacyLease:Acquire(legacyKey(userId), legacyOrError)
		if not acquired then return nil, stateOrError end
		acquiredLegacy = stateOrError
		migrationSeed = stateOrError
	end

	local state = StateSchema.Sanitize(migrationSeed, generateInstanceId)
	profile.PlayerState = state
	profile.PlayerStateMigrationVersion = MIGRATION_VERSION
	profile.PlayerStateMigratedAt = os.time()
	profile.PlayerStateLegacyBackupAvailable = acquiredLegacy ~= nil
	PlayerData.MarkDirty(player)

	local saved, saveError = PlayerData.SaveBarrier(player, "player_state_migration")
	-- Keep the rollback backup aligned with the exact instance IDs embedded in the main profile.
	if acquiredLegacy then releaseLegacyLease(userId, StateSchema.Clone(state)) end
	if not saved then return nil, saveError or "MigrationSaveFailed" end
	return state
end

function Store.Load(player: Player)
	local userId = player.UserId
	if cache[userId] then return cache[userId] end
	if loadErrors[userId] and not RunService:IsStudio() then return nil, loadErrors[userId] end

	while loadingByUserId[userId] do
		task.wait(0.05)
		if cache[userId] then return cache[userId] end
		if loadErrors[userId] and not RunService:IsStudio() then return nil, loadErrors[userId] end
	end
	loadingByUserId[userId] = true
	setReadyAttributes(player, false, nil)

	local profileOk, profileOrError = pcall(PlayerData.Get, player)
	if not profileOk or typeof(profileOrError) ~= "table" then
		return failLoad(player, profileOk and "GlobalProfileMissing" or profileOrError)
	end
	local profile = profileOrError

	local state, stateError
	if math.floor(tonumber(profile.PlayerStateMigrationVersion) or 0) >= MIGRATION_VERSION
		and typeof(profile.PlayerState) == "table"
	then
		state = StateSchema.Sanitize(profile.PlayerState, generateInstanceId)
		profile.PlayerState = state
		PlayerData.MarkDirty(player)
	else
		state, stateError = migrateLegacyState(player, profile)
	end

	loadingByUserId[userId] = nil
	if not state then return failLoad(player, stateError) end
	if player.Parent ~= Players then return nil, "PlayerLeftDuringLoad" end

	cache[userId] = state
	loadErrors[userId] = nil
	setReadyAttributes(player, true, nil)
	return state
end

function Store.Get(player: Player)
	return cache[player.UserId]
end

function Store.IsReady(player: Player): boolean
	return cache[player.UserId] ~= nil and loadErrors[player.UserId] == nil
end

function Store.GetLoadError(player: Player): string?
	return loadErrors[player.UserId]
end

local function getState(player: Player)
	local state = cache[player.UserId]
	if state then return state end
	local loaded, err = Store.Load(player)
	if loaded then return loaded end
	error(string.format("[PlayerStateStore] State unavailable for %s: %s", player.Name, tostring(err)), 2)
end

function Store.MarkDirty(player: Player, _reason: string?)
	if cache[player.UserId] then PlayerData.MarkDirty(player) end
end

function Store:_RawSave(player: Player, reason: string?)
	return PlayerData.Save(player, true, reason or "player_state_raw_save")
end

function Store.ForceSave(player: Player, reason: string?)
	return PlayerData.SaveBarrier(player, reason or "player_state_force")
end

function Store.Flush(player: Player, reason: string?)
	return PlayerData.SaveBarrier(player, reason or "player_state_flush")
end

function Store.Save(player: Player, _force: boolean?)
	return PlayerData.SaveBarrier(player, "player_state_save")
end

function Store.SaveBarrier(player: Player, reason: string?)
	return PlayerData.SaveBarrier(player, reason or "player_state_barrier")
end

function Store.Release(player: Player)
	local userId = player.UserId
	cache[userId] = nil
	loadingByUserId[userId] = nil
	loadErrors[userId] = nil
	return true
end

function Store.SetCreated(player: Player, profileLite: any)
	local data = getState(player)
	data.CreatedOnce = true
	data.Profile = typeof(profileLite) == "table" and StateSchema.Clone(profileLite) or profileLite
	Store.MarkDirty(player, "profile_created")
end

function Store.GetTutorialState(player: Player)
	return getState(player).Tutorial
end

function Store.SetTutorialState(player: Player, payload)
	local data = getState(player)
	data.Tutorial = data.Tutorial or { Active = true, Step = 1, Complete = false }
	if payload.Active ~= nil then data.Tutorial.Active = payload.Active == true end
	if payload.Step ~= nil then data.Tutorial.Step = math.max(1, math.floor(tonumber(payload.Step) or 1)) end
	if payload.Complete ~= nil then data.Tutorial.Complete = payload.Complete == true end
	if typeof(data.Profile) == "table" then data.Profile.Tutorial = StateSchema.Clone(data.Tutorial) end
	Store.MarkDirty(player, "tutorial")
end

function Store.EnsureOwnedSpell(player: Player, spellId: string)
	local data = getState(player)
	if typeof(spellId) ~= "string" or spellId == "" then return end
	for _, current in ipairs(data.OwnedSpells) do if current == spellId then return end end
	table.insert(data.OwnedSpells, spellId)
	if typeof(data.Profile) == "table" then data.Profile.OwnedSpells = data.OwnedSpells end
	Store.MarkDirty(player, "spell")
end

function Store.GetSpellLoadout(player: Player)
	local out = {}
	for _, id in ipairs(getState(player).SpellLoadout or {}) do
		if typeof(id) == "string" and id ~= "" then table.insert(out, id) end
	end
	return out
end

function Store.SetSpellLoadout(player: Player, loadout)
	local data = getState(player)
	local out, seen = {}, {}
	for _, id in ipairs(loadout or {}) do
		if typeof(id) == "string" and id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	data.SpellLoadout = out
	if typeof(data.Profile) == "table" then data.Profile.SpellLoadout = out end
	Store.MarkDirty(player, "spell_loadout")
end

function Store.SetStarterWeaponClaimed(player: Player, weaponName: string)
	local data = getState(player)
	data.StarterWeaponClaimed = true
	data.StarterWeaponName = weaponName
	Store.MarkDirty(player, "starter_weapon")
end

function Store.SetEquippedWeaponName(player: Player, weaponName: string?)
	local data = getState(player)
	if typeof(weaponName) == "string" and weaponName ~= "" then
		data.StarterWeaponClaimed = true
		data.StarterWeaponName = weaponName
		for _, instance in ipairs(data.WeaponInstances) do
			if instance.weaponId == weaponName then
				data.EquippedWeaponInstanceId = instance.instanceId
				break
			end
		end
	else
		data.StarterWeaponClaimed = false
		data.StarterWeaponName = nil
		data.EquippedWeaponInstanceId = nil
	end
	Store.MarkDirty(player, "equip_name")
end

function Store.ListWeaponInstances(player: Player)
	return getState(player).WeaponInstances
end

function Store.GetWeaponInstance(player: Player, instanceId: string)
	local data = getState(player)
	if typeof(instanceId) ~= "string" or instanceId == "" then return nil, nil end
	for index, instance in ipairs(data.WeaponInstances) do
		if instance.instanceId == instanceId then return instance, index end
	end
	return nil, nil
end

function Store.AddWeaponInstance(player: Player, weaponId: string, rarity: string?, level: number?, prefix: string?, rollStats: any?)
	local data = getState(player)
	if typeof(weaponId) ~= "string" or weaponId == "" then return nil end
	local instance = newWeaponInstance(weaponId, rarity, level, prefix, rollStats)
	table.insert(data.WeaponInstances, instance)
	data.OwnedWeapons = StateSchema.EnsureUniqueOwnedWeapons(data.WeaponInstances)
	Store.MarkDirty(player, "weapon_add")
	return instance
end

function Store.EnsureOwnedWeapon(player: Player, weaponId: string)
	local data = getState(player)
	if typeof(weaponId) ~= "string" or weaponId == "" then return nil end
	for _, instance in ipairs(data.WeaponInstances) do
		if instance.weaponId == weaponId then return instance end
	end
	local created = newWeaponInstance(weaponId, "", 1, "Standard", {})
	table.insert(data.WeaponInstances, created)
	data.OwnedWeapons = StateSchema.EnsureUniqueOwnedWeapons(data.WeaponInstances)
	if typeof(data.EquippedWeaponInstanceId) ~= "string" or data.EquippedWeaponInstanceId == "" then
		data.EquippedWeaponInstanceId = created.instanceId
	end
	data.StarterWeaponClaimed = true
	data.StarterWeaponName = weaponId
	Store.MarkDirty(player, "ensure_weapon")
	return created
end

function Store.RemoveWeaponInstance(player: Player, instanceId: string)
	local data = getState(player)
	local _, index = Store.GetWeaponInstance(player, instanceId)
	if not index then return false end
	table.remove(data.WeaponInstances, index)
	data.OwnedWeapons = StateSchema.EnsureUniqueOwnedWeapons(data.WeaponInstances)
	if data.EquippedWeaponInstanceId == instanceId then
		data.EquippedWeaponInstanceId = data.WeaponInstances[1] and data.WeaponInstances[1].instanceId or nil
	end
	Store.MarkDirty(player, "weapon_remove")
	return true
end

function Store.SetEquippedWeaponInstance(player: Player, instanceId: string)
	local data = getState(player)
	local instance = Store.GetWeaponInstance(player, instanceId)
	if not instance then return false end
	data.EquippedWeaponInstanceId = instance.instanceId
	data.StarterWeaponClaimed = true
	data.StarterWeaponName = instance.weaponId
	Store.MarkDirty(player, "equip_instance")
	return true
end

function Store.GetEquippedWeaponInstance(player: Player)
	local data = getState(player)
	local instanceId = data.EquippedWeaponInstanceId
	if typeof(instanceId) ~= "string" or instanceId == "" then return nil end
	return Store.GetWeaponInstance(player, instanceId)
end

function Store.SetFavoriteWeapon(player: Player, weaponId: string, isFavorite: boolean)
	local data = getState(player)
	if typeof(weaponId) ~= "string" or weaponId == "" then return end
	local out = {}
	for _, current in ipairs(data.FavoriteWeapons or {}) do
		if current ~= weaponId then table.insert(out, current) end
	end
	if isFavorite == true then table.insert(out, weaponId) end
	data.FavoriteWeapons = out
	Store.MarkDirty(player, "favorite")
end

function Store.GetMissionsState(player: Player)
	local data = getState(player)
	data.Missions = data.Missions or StateSchema.Default().Missions
	return data.Missions
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local ok, err = pcall(Store.Load, player)
		if not ok then failLoad(player, err) end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	Store.Release(player)
end)

return Store
