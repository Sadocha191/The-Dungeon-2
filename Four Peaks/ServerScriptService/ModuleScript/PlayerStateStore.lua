-- PlayerStateStore.lua
-- Persistent weapon-instance/profile state with safe loading, session ownership, and confirmed saves.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local SaveScheduler = require(script.Parent:WaitForChild("SaveScheduler"))
local ProfileLease = require(script.Parent:WaitForChild("ProfileLease"))

local DS = DataStoreService:GetDataStore("PlayerState_v2")
local lease = ProfileLease.new(DS, {
	name = "PlayerState_v2",
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
local volatileByUserId = {}
local releasingByUserId = {}
local pendingReleases = {}
local closing = false

local OFFLINE_RELEASE_ATTEMPTS = 6

local function dsKey(userId: number): string
	return "u:" .. tostring(userId)
end

local function deepCopy(value)
	if typeof(value) ~= "table" then return value end
	local copy = {}
	for key, nested in pairs(value) do
		copy[deepCopy(key)] = deepCopy(nested)
	end
	return copy
end

local function clampInt(value, minimum)
	local number = math.floor(tonumber(value) or 0)
	if minimum ~= nil and number < minimum then return minimum end
	return number
end

local function newWeaponInstance(weaponId: string, rarity: string?, level: number?, prefix: string?, rollStats: any?)
	return {
		instanceId = HttpService:GenerateGUID(false),
		weaponId = weaponId,
		rarity = tostring(rarity or ""),
		level = clampInt(level or 1, 1),
		prefix = tostring(prefix or "Standard"),
		rollStats = typeof(rollStats) == "table" and deepCopy(rollStats) or {},
		createdAt = os.time(),
	}
end

local function ensureUniqueOwnedWeapons(instances)
	local seen = {}
	local out = {}
	for _, instance in ipairs(instances or {}) do
		local weaponId = instance and instance.weaponId
		if typeof(weaponId) == "string" and weaponId ~= "" and not seen[weaponId] then
			seen[weaponId] = true
			table.insert(out, weaponId)
		end
	end
	return out
end

local function defaultState()
	return {
		CreatedOnce = false,
		Profile = nil,
		StarterWeaponClaimed = false,
		StarterWeaponName = nil,
		OwnedWeapons = {},
		FavoriteWeapons = {},
		OwnedSpells = {},
		SpellLoadout = {},
		Codex = { Discovered = {}, Seen = {} },
		WeaponInstances = {},
		EquippedWeaponInstanceId = nil,
		Missions = {
			DailyKey = 0,
			WeeklyKey = 0,
			SelectedDaily = {},
			SelectedWeekly = {},
			ClaimCounts = {},
			CountersDaily = {},
			CountersWeekly = {},
			WeeklyWeaponRuns = {},
		},
		Tutorial = { Active = true, Step = 1, Complete = false },
	}
end

local function ensureSchema(raw)
	local data = defaultState()
	if typeof(raw) == "table" then
		for key, value in pairs(raw) do data[key] = value end
	end

	if typeof(data.OwnedWeapons) ~= "table" then data.OwnedWeapons = {} end
	if typeof(data.FavoriteWeapons) ~= "table" then data.FavoriteWeapons = {} end
	if typeof(data.OwnedSpells) ~= "table" then data.OwnedSpells = {} end
	if typeof(data.SpellLoadout) ~= "table" then data.SpellLoadout = {} end
	if typeof(data.Codex) ~= "table" then data.Codex = { Discovered = {}, Seen = {} } end
	if typeof(data.Codex.Discovered) ~= "table" then data.Codex.Discovered = {} end
	if typeof(data.Codex.Seen) ~= "table" then data.Codex.Seen = {} end

	data.CreatedOnce = data.CreatedOnce == true
	data.StarterWeaponClaimed = data.StarterWeaponClaimed == true
	if data.StarterWeaponName ~= nil then data.StarterWeaponName = tostring(data.StarterWeaponName) end
	if typeof(data.WeaponInstances) ~= "table" then data.WeaponInstances = {} end
	if typeof(data.EquippedWeaponInstanceId) ~= "string" then data.EquippedWeaponInstanceId = nil end

	if typeof(data.Missions) ~= "table" then data.Missions = defaultState().Missions end
	local missions = data.Missions
	if typeof(missions.SelectedDaily) ~= "table" then missions.SelectedDaily = {} end
	if typeof(missions.SelectedWeekly) ~= "table" then missions.SelectedWeekly = {} end
	if typeof(missions.ClaimCounts) ~= "table" then missions.ClaimCounts = {} end
	if typeof(missions.CountersDaily) ~= "table" then missions.CountersDaily = {} end
	if typeof(missions.CountersWeekly) ~= "table" then missions.CountersWeekly = {} end
	if typeof(missions.WeeklyWeaponRuns) ~= "table" then missions.WeeklyWeaponRuns = {} end
	missions.DailyKey = tonumber(missions.DailyKey) or 0
	missions.WeeklyKey = tonumber(missions.WeeklyKey) or 0

	if typeof(data.Tutorial) ~= "table" then
		data.Tutorial = defaultState().Tutorial
	else
		data.Tutorial.Active = data.Tutorial.Active ~= false
		data.Tutorial.Step = math.max(1, math.floor(tonumber(data.Tutorial.Step) or 1))
		data.Tutorial.Complete = data.Tutorial.Complete == true
	end

	if #data.WeaponInstances == 0 and #data.OwnedWeapons > 0 then
		for _, weaponId in ipairs(data.OwnedWeapons) do
			if typeof(weaponId) == "string" and weaponId ~= "" then
				table.insert(data.WeaponInstances, newWeaponInstance(weaponId, "", 1, "Standard", {}))
			end
		end
	end

	local cleanInstances = {}
	for _, instance in ipairs(data.WeaponInstances) do
		if typeof(instance) == "table" then
			instance.instanceId = typeof(instance.instanceId) == "string" and instance.instanceId ~= ""
				and instance.instanceId or HttpService:GenerateGUID(false)
			instance.weaponId = tostring(instance.weaponId or "")
			instance.rarity = tostring(instance.rarity or "")
			instance.level = math.max(1, math.floor(tonumber(instance.level) or 1))
			instance.prefix = tostring(instance.prefix or "Standard")
			if typeof(instance.rollStats) ~= "table" then instance.rollStats = {} end
			instance.createdAt = tonumber(instance.createdAt) or os.time()
			if instance.weaponId ~= "" then table.insert(cleanInstances, instance) end
		end
	end
	data.WeaponInstances = cleanInstances
	data.OwnedWeapons = ensureUniqueOwnedWeapons(data.WeaponInstances)

	local equippedOk = false
	if typeof(data.EquippedWeaponInstanceId) == "string" and data.EquippedWeaponInstanceId ~= "" then
		for _, instance in ipairs(data.WeaponInstances) do
			if instance.instanceId == data.EquippedWeaponInstanceId then equippedOk = true break end
		end
	end
	if not equippedOk then
		local selected = nil
		if typeof(data.StarterWeaponName) == "string" and data.StarterWeaponName ~= "" then
			for _, instance in ipairs(data.WeaponInstances) do
				if instance.weaponId == data.StarterWeaponName then selected = instance.instanceId break end
			end
		end
		if not selected and data.WeaponInstances[1] then selected = data.WeaponInstances[1].instanceId end
		data.EquippedWeaponInstanceId = selected
	end
	return data
end

local function setReadyAttributes(player: Player, ready: boolean, reason: string?)
	if player.Parent then
		player:SetAttribute("PlayerStateReady", ready)
		player:SetAttribute("PlayerStateLoadError", reason)
	end
end

local function failLoad(player: Player, reason)
	local uid = player.UserId
	local message = tostring(reason or "UnknownLoadFailure")
	loadingByUserId[uid] = nil
	loadErrors[uid] = message
	setReadyAttributes(player, false, message)

	if RunService:IsStudio() then
		local data = ensureSchema(defaultState())
		cache[uid] = data
		volatileByUserId[uid] = true
		loadErrors[uid] = nil
		setReadyAttributes(player, true, "VolatileStudioProfile")
		warn("[PlayerStateStore] DataStore unavailable in Studio; using non-persistent state:", player.Name, message)
		return data
	end

	task.defer(function()
		if player.Parent then
			local kickMessage = message == "ProfileLocked"
				and "Your inventory is still active on another server. Rejoin in a moment."
				or "Your inventory could not be loaded safely. Please rejoin."
			player:Kick(kickMessage)
		end
	end)
	return nil
end

function Store.Load(player: Player)
	local uid = player.UserId
	if cache[uid] then return cache[uid] end
	if loadErrors[uid] and not RunService:IsStudio() then return nil, loadErrors[uid] end

	while loadingByUserId[uid] do
		task.wait(0.05)
		if cache[uid] then return cache[uid] end
		if loadErrors[uid] and not RunService:IsStudio() then return nil, loadErrors[uid] end
	end
	loadingByUserId[uid] = true
	setReadyAttributes(player, false, nil)

	local readOk, currentOrError = lease:Read(DS, dsKey(uid))
	if not readOk then return failLoad(player, currentOrError) end
	local acquired, stateOrError = lease:Acquire(dsKey(uid), currentOrError or defaultState())
	if not acquired then return failLoad(player, stateOrError) end

	local data = ensureSchema(stateOrError)
	if player.Parent ~= Players then
		loadingByUserId[uid] = nil
		lease:Release(dsKey(uid), data)
		return nil, "PlayerLeftDuringLoad"
	end
	cache[uid] = data
	loadErrors[uid] = nil
	volatileByUserId[uid] = nil
	loadingByUserId[uid] = nil
	setReadyAttributes(player, true, nil)
	return data
end

function Store.Get(player: Player)
	return cache[player.UserId]
end

function Store.IsReady(player: Player): boolean
	return cache[player.UserId] ~= nil
end

function Store.MarkDirty(player: Player, reason: string?)
	if cache[player.UserId] then SaveScheduler.MarkDirty(player, reason or "state") end
end

function Store:_RawSave(player: Player, reason: string)
	local uid = player.UserId
	if volatileByUserId[uid] then return true, "VolatileStudioProfile" end
	local data = cache[uid]
	if not data then return false, "ProfileMissing" end
	local ok, persistedOrError = lease:Save(dsKey(uid), deepCopy(data))
	if not ok then
		warn("[PlayerStateStore] Save failed:", player.Name, reason, persistedOrError)
		return false, persistedOrError
	end
	if typeof(persistedOrError) == "table" and typeof(persistedOrError._profileMeta) == "table" then
		data._profileMeta = deepCopy(persistedOrError._profileMeta)
	end
	return true
end

function Store.ForceSave(player: Player, reason: string?)
	return SaveScheduler.ForceSave(player, reason or "force")
end

function Store.Flush(player: Player, reason: string?)
	return SaveScheduler.Flush(player, reason or "flush")
end

function Store.Save(player: Player, _force: boolean?)
	return Store.ForceSave(player, "save")
end

function Store.SaveBarrier(player: Player, reason: string?)
	local deadline = os.clock() + 12
	repeat
		local ok, err = Store.ForceSave(player, reason or "barrier")
		if ok then return true end
		if err ~= "SaveInProgress" then return false, err end
		task.wait(0.05)
	until os.clock() >= deadline
	return false, "SaveWaitTimeout"
end

local function queueOfflineRelease(userId: number, snapshot)
	pendingReleases[userId] = snapshot
	task.spawn(function()
		for attempt = 1, OFFLINE_RELEASE_ATTEMPTS do
			local current = pendingReleases[userId]
			if not current then return end
			local ok = lease:Release(dsKey(userId), current)
			if ok then pendingReleases[userId] = nil return end
			task.wait(math.min(attempt * 0.75, 4))
		end
		warn("[PlayerStateStore] Offline release exhausted retries for user", userId)
	end)
end

function Store.Release(player: Player)
	local uid = player.UserId
	if releasingByUserId[uid] then return false, "ReleaseInProgress" end
	releasingByUserId[uid] = true
	local data = cache[uid]
	if not data then
		releasingByUserId[uid] = nil
		SaveScheduler.Release(player, true)
		return true
	end

	local ok, err = true, nil
	if not volatileByUserId[uid] then
		local snapshot = deepCopy(data)
		ok, err = lease:Release(dsKey(uid), snapshot)
		if not ok then
			queueOfflineRelease(uid, snapshot)
			warn("[PlayerStateStore] Release deferred after save failure:", player.Name, err)
		end
	end

	cache[uid] = nil
	loadingByUserId[uid] = nil
	loadErrors[uid] = nil
	volatileByUserId[uid] = nil
	SaveScheduler.Release(player, true)
	releasingByUserId[uid] = nil
	return ok, err
end

function Store.SetCreated(player: Player, profileLite: any)
	local data = Store.Get(player) or Store.Load(player)
	data.CreatedOnce = true
	data.Profile = profileLite
	Store.MarkDirty(player, "profile_created")
end

function Store.GetTutorialState(player: Player)
	local data = Store.Get(player) or Store.Load(player)
	return data.Tutorial
end

function Store.SetTutorialState(player: Player, payload)
	local data = Store.Get(player) or Store.Load(player)
	data.Tutorial = data.Tutorial or { Active = true, Step = 1, Complete = false }
	if payload.Active ~= nil then data.Tutorial.Active = payload.Active == true end
	if payload.Step ~= nil then data.Tutorial.Step = math.max(1, math.floor(tonumber(payload.Step) or 1)) end
	if payload.Complete ~= nil then data.Tutorial.Complete = payload.Complete == true end
	if typeof(data.Profile) == "table" then
		data.Profile.Tutorial = deepCopy(data.Tutorial)
	end
	Store.MarkDirty(player, "tutorial")
end

function Store.EnsureOwnedSpell(player: Player, spellId: string)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(spellId) ~= "string" or spellId == "" then return end
	for _, current in ipairs(data.OwnedSpells) do if current == spellId then return end end
	table.insert(data.OwnedSpells, spellId)
	if typeof(data.Profile) == "table" then data.Profile.OwnedSpells = data.OwnedSpells end
	Store.MarkDirty(player, "spell")
end

function Store.GetSpellLoadout(player: Player)
	local data = Store.Get(player) or Store.Load(player)
	local out = {}
	for _, id in ipairs(data.SpellLoadout or {}) do
		if typeof(id) == "string" and id ~= "" then table.insert(out, id) end
	end
	return out
end

function Store.SetSpellLoadout(player: Player, loadout)
	local data = Store.Get(player) or Store.Load(player)
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
	local data = Store.Get(player) or Store.Load(player)
	data.StarterWeaponClaimed = true
	data.StarterWeaponName = weaponName
	Store.MarkDirty(player, "starter_weapon")
end

function Store.SetEquippedWeaponName(player: Player, weaponName: string?)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(weaponName) == "string" and weaponName ~= "" then
		data.StarterWeaponClaimed = true
		data.StarterWeaponName = weaponName
		for _, instance in ipairs(data.WeaponInstances) do
			if instance.weaponId == weaponName then data.EquippedWeaponInstanceId = instance.instanceId break end
		end
	else
		data.StarterWeaponClaimed = false
		data.StarterWeaponName = nil
		data.EquippedWeaponInstanceId = nil
	end
	Store.MarkDirty(player, "equip_name")
end

function Store.ListWeaponInstances(player: Player)
	return (Store.Get(player) or Store.Load(player)).WeaponInstances
end

function Store.GetWeaponInstance(player: Player, instanceId: string)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(instanceId) ~= "string" or instanceId == "" then return nil, nil end
	for index, instance in ipairs(data.WeaponInstances) do
		if instance.instanceId == instanceId then return instance, index end
	end
	return nil, nil
end

function Store.AddWeaponInstance(player: Player, weaponId: string, rarity: string?, level: number?, prefix: string?, rollStats: any?)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(weaponId) ~= "string" or weaponId == "" then return nil end
	local instance = newWeaponInstance(weaponId, rarity, level, prefix, rollStats)
	table.insert(data.WeaponInstances, instance)
	data.OwnedWeapons = ensureUniqueOwnedWeapons(data.WeaponInstances)
	Store.MarkDirty(player, "weapon_add")
	return instance
end

function Store.EnsureOwnedWeapon(player: Player, weaponId: string)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(weaponId) ~= "string" or weaponId == "" then return nil end
	for _, instance in ipairs(data.WeaponInstances) do
		if instance.weaponId == weaponId then return instance end
	end
	local created = newWeaponInstance(weaponId, "", 1, "Standard", {})
	table.insert(data.WeaponInstances, created)
	data.OwnedWeapons = ensureUniqueOwnedWeapons(data.WeaponInstances)
	if typeof(data.EquippedWeaponInstanceId) ~= "string" or data.EquippedWeaponInstanceId == "" then
		data.EquippedWeaponInstanceId = created.instanceId
	end
	data.StarterWeaponClaimed = true
	data.StarterWeaponName = weaponId
	Store.MarkDirty(player, "ensure_weapon")
	return created
end

function Store.RemoveWeaponInstance(player: Player, instanceId: string)
	local data = Store.Get(player) or Store.Load(player)
	local _, index = Store.GetWeaponInstance(player, instanceId)
	if not index then return false end
	table.remove(data.WeaponInstances, index)
	data.OwnedWeapons = ensureUniqueOwnedWeapons(data.WeaponInstances)
	if data.EquippedWeaponInstanceId == instanceId then
		data.EquippedWeaponInstanceId = data.WeaponInstances[1] and data.WeaponInstances[1].instanceId or nil
	end
	Store.MarkDirty(player, "weapon_remove")
	return true
end

function Store.SetEquippedWeaponInstance(player: Player, instanceId: string)
	local data = Store.Get(player) or Store.Load(player)
	local instance = Store.GetWeaponInstance(player, instanceId)
	if not instance then return false end
	data.EquippedWeaponInstanceId = instance.instanceId
	data.StarterWeaponClaimed = true
	data.StarterWeaponName = instance.weaponId
	Store.MarkDirty(player, "equip_instance")
	return true
end

function Store.GetEquippedWeaponInstance(player: Player)
	local data = Store.Get(player) or Store.Load(player)
	local id = data.EquippedWeaponInstanceId
	if typeof(id) ~= "string" or id == "" then return nil end
	return Store.GetWeaponInstance(player, id)
end

function Store.SetFavoriteWeapon(player: Player, weaponId: string, isFavorite: boolean)
	local data = Store.Get(player) or Store.Load(player)
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
	local data = Store.Get(player) or Store.Load(player)
	data.Missions = data.Missions or defaultState().Missions
	return data.Missions
end

SaveScheduler.Bind(Store)

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		local ok, err = pcall(Store.Load, player)
		if not ok then
			warn("[PlayerStateStore] Unexpected load exception:", player.Name, err)
			failLoad(player, err)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	Store.Release(player)
end)

task.spawn(function()
	while not closing do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			if cache[player.UserId] and not volatileByUserId[player.UserId] then
				task.spawn(function()
					if SaveScheduler.IsDirty(player) then
						Store.Flush(player, "autosave")
					else
						local ok, err = lease:Renew(dsKey(player.UserId))
						if not ok then
							warn("[PlayerStateStore] Lease renewal failed:", player.Name, err)
							if err == "SessionLost" and player.Parent == Players then
								player:Kick("Your inventory session changed unexpectedly. Please rejoin.")
							end
						end
					end
				end)
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
			Store.Release(player)
			remaining -= 1
		end)
	end
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		if remaining <= 0 and next(pendingReleases) == nil then break end
		task.wait(0.05)
	end
end)

return Store
