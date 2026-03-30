-- PlayerStateStore.lua
-- Jedyny writer do DataStore. Reszta systemów: tylko modyfikuje state + MarkDirty.
-- Uwaga: nie wywołuj w innych modułach DataStoreService bezpośrednio.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local SaveScheduler = require(script.Parent:WaitForChild("SaveScheduler"))

local DS = DataStoreService:GetDataStore("PlayerState_v2")

local Store = {}
local cache: {[number]: any} = {}

local function dsKey(userId: number): string
	return "u:" .. tostring(userId)
end

local function clampInt(x, minVal)
	x = tonumber(x) or 0
	x = math.floor(x)
	if minVal ~= nil and x < minVal then x = minVal end
	return x
end

local function newWeaponInstance(weaponId: string, rarity: string?, level: number?, prefix: string?, rollStats: any?)
	return {
		instanceId = HttpService:GenerateGUID(false),
		weaponId = weaponId,
		rarity = tostring(rarity or ""),
		level = clampInt(level or 1, 1),
		prefix = tostring(prefix or "Standard"),
		rollStats = (typeof(rollStats) == "table") and rollStats or {},
		createdAt = os.time(),
	}
end

local function ensureUniqueOwnedWeapons(instances: {any})
	local set = {}
	local out = {}
	for _, inst in ipairs(instances) do
		local wid = inst and inst.weaponId
		if typeof(wid) == "string" and wid ~= "" and not set[wid] then
			set[wid] = true
			table.insert(out, wid)
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

		Tutorial = {
			Active = true,
			Step = 1,
			Complete = false,
		},
	}
end

local function ensureSchema(data: any)
	if typeof(data) ~= "table" then
		data = defaultState()
	end

	if typeof(data.OwnedWeapons) ~= "table" then data.OwnedWeapons = {} end
	if typeof(data.FavoriteWeapons) ~= "table" then data.FavoriteWeapons = {} end
	if typeof(data.OwnedSpells) ~= "table" then data.OwnedSpells = {} end

	data.StarterWeaponClaimed = data.StarterWeaponClaimed == true
	if data.StarterWeaponName ~= nil then data.StarterWeaponName = tostring(data.StarterWeaponName) end

	if typeof(data.WeaponInstances) ~= "table" then data.WeaponInstances = {} end
	if typeof(data.EquippedWeaponInstanceId) ~= "string" then data.EquippedWeaponInstanceId = nil end

	if typeof(data.Missions) ~= "table" then data.Missions = defaultState().Missions end
	local m = data.Missions
	if typeof(m.SelectedDaily) ~= "table" then m.SelectedDaily = {} end
	if typeof(m.SelectedWeekly) ~= "table" then m.SelectedWeekly = {} end
	if typeof(m.ClaimCounts) ~= "table" then m.ClaimCounts = {} end
	if typeof(m.CountersDaily) ~= "table" then m.CountersDaily = {} end
	if typeof(m.CountersWeekly) ~= "table" then m.CountersWeekly = {} end
	if typeof(m.WeeklyWeaponRuns) ~= "table" then m.WeeklyWeaponRuns = {} end
	m.DailyKey = tonumber(m.DailyKey) or 0
	m.WeeklyKey = tonumber(m.WeeklyKey) or 0

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

	for _, inst in ipairs(data.WeaponInstances) do
		if typeof(inst) == "table" then
			if typeof(inst.instanceId) ~= "string" or inst.instanceId == "" then
				inst.instanceId = HttpService:GenerateGUID(false)
			end
			inst.weaponId = tostring(inst.weaponId or "")
			inst.rarity = tostring(inst.rarity or "")
			inst.level = math.max(1, math.floor(tonumber(inst.level) or 1))
			inst.prefix = tostring(inst.prefix or "Standard")
			if typeof(inst.rollStats) ~= "table" then inst.rollStats = {} end
			if inst.createdAt == nil then inst.createdAt = os.time() end
		end
	end

	data.OwnedWeapons = ensureUniqueOwnedWeapons(data.WeaponInstances)

	local eq = data.EquippedWeaponInstanceId
	local eqOk = false
	if typeof(eq) == "string" and eq ~= "" then
		for _, inst in ipairs(data.WeaponInstances) do
			if inst.instanceId == eq then eqOk = true break end
		end
	end
	if not eqOk then
		local chosen = nil
		if typeof(data.StarterWeaponName) == "string" and data.StarterWeaponName ~= "" then
			for _, inst in ipairs(data.WeaponInstances) do
				if inst.weaponId == data.StarterWeaponName then
					chosen = inst.instanceId
					break
				end
			end
		end
		if not chosen and data.WeaponInstances[1] then
			chosen = data.WeaponInstances[1].instanceId
		end
		data.EquippedWeaponInstanceId = chosen
	end

	return data
end

-- ==== LOAD / GET ====

function Store.Load(player: Player)
	local uid = player.UserId
	local data

	local ok, err = pcall(function()
		data = DS:GetAsync(dsKey(uid))
	end)
	if not ok then
		warn("[PlayerStateStore] GetAsync failed:", err)
		data = nil
	end

	data = ensureSchema(data)
	cache[uid] = data
	return data
end

function Store.Get(player: Player)
	return cache[player.UserId]
end

-- ==== DIRTY / SAVE ====

function Store.MarkDirty(player: Player, reason: string?)
	SaveScheduler.MarkDirty(player, reason or "state")
end

function Store:_RawSave(player: Player, reason: string)
	local uid = player.UserId
	local data = cache[uid]
	if not data then return end

	local ok, err = pcall(function()
		DS:UpdateAsync(dsKey(uid), function(_old)
			return data
		end)
	end)
	if not ok then
		warn("[PlayerStateStore] UpdateAsync failed:", reason, err)
		SaveScheduler.MarkDirty(player, "retry")
	end
end

function Store.ForceSave(player: Player, reason: string?)
	SaveScheduler.ForceSave(player, reason or "force")
end

-- kompat: stare skrypty wołają Save(player, true)
function Store.Save(player: Player, _force: boolean?)
	Store.ForceSave(player, "save")
end

-- ==== API: Profile ====

function Store.SetCreated(player: Player, profileLite: any)
	local data = Store.Get(player) or Store.Load(player)
	data.CreatedOnce = true
	data.Profile = profileLite
	Store.MarkDirty(player, "profile_created")
end

-- ==== API: Tutorial ====

function Store.GetTutorialState(player: Player)
	local data = Store.Get(player) or Store.Load(player)
	return data.Tutorial
end

function Store.SetTutorialState(player: Player, payload: {Active: boolean?, Step: number?, Complete: boolean?})
	local data = Store.Get(player) or Store.Load(player)
	data.Tutorial = data.Tutorial or { Active = true, Step = 1, Complete = false }

	if payload.Active ~= nil then data.Tutorial.Active = payload.Active == true end
	if payload.Step ~= nil then data.Tutorial.Step = math.max(1, math.floor(tonumber(payload.Step) or 1)) end
	if payload.Complete ~= nil then data.Tutorial.Complete = payload.Complete == true end

	if typeof(data.Profile) == "table" then
		data.Profile.Tutorial = {
			Active = data.Tutorial.Active,
			Step = data.Tutorial.Step,
			Complete = data.Tutorial.Complete,
		}
	end

	Store.MarkDirty(player, "tutorial")
end

-- ==== API: Spells ====

function Store.EnsureOwnedSpell(player: Player, spellId: string)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(spellId) ~= "string" or spellId == "" then return end

	for _, s in ipairs(data.OwnedSpells) do
		if s == spellId then return end
	end
	table.insert(data.OwnedSpells, spellId)

	if typeof(data.Profile) == "table" then
		data.Profile.OwnedSpells = data.OwnedSpells
	end

	Store.MarkDirty(player, "spell")
end

-- ==== API: Starter weapon (kompat) ====

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

		for _, inst in ipairs(data.WeaponInstances) do
			if inst.weaponId == weaponName then
				data.EquippedWeaponInstanceId = inst.instanceId
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

-- ==== API: Weapons ====

function Store.ListWeaponInstances(player: Player)
	local data = Store.Get(player) or Store.Load(player)
	return data.WeaponInstances
end

function Store.GetWeaponInstance(player: Player, instanceId: string)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(instanceId) ~= "string" or instanceId == "" then return nil, nil end
	for i, inst in ipairs(data.WeaponInstances) do
		if inst.instanceId == instanceId then return inst, i end
	end
	return nil, nil
end

function Store.AddWeaponInstance(player: Player, weaponId: string, rarity: string?, level: number?, prefix: string?, rollStats: any?)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(weaponId) ~= "string" or weaponId == "" then return nil end

	local inst = newWeaponInstance(weaponId, rarity, level, prefix, rollStats)
	table.insert(data.WeaponInstances, inst)
	data.OwnedWeapons = ensureUniqueOwnedWeapons(data.WeaponInstances)

	Store.MarkDirty(player, "weapon_add")
	return inst
end

-- kompat: stare skrypty wołają EnsureOwnedWeapon(player, weaponId)
function Store.EnsureOwnedWeapon(player: Player, weaponId: string)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(weaponId) ~= "string" or weaponId == "" then return nil end

	for _, inst in ipairs(data.WeaponInstances) do
		if inst.weaponId == weaponId then
			return inst
		end
	end

	local created = newWeaponInstance(weaponId, "", 1, "Standard", {})
	table.insert(data.WeaponInstances, created)
	data.OwnedWeapons = ensureUniqueOwnedWeapons(data.WeaponInstances)

	-- jeśli nie ma equip, ustaw na nową
	if not (typeof(data.EquippedWeaponInstanceId) == "string" and data.EquippedWeaponInstanceId ~= "") then
		data.EquippedWeaponInstanceId = created.instanceId
	end

	data.StarterWeaponClaimed = true
	data.StarterWeaponName = weaponId

	Store.MarkDirty(player, "ensure_weapon")
	return created
end

function Store.RemoveWeaponInstance(player: Player, instanceId: string)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(instanceId) ~= "string" or instanceId == "" then return false end

	local idx = nil
	for i, inst in ipairs(data.WeaponInstances) do
		if inst.instanceId == instanceId then idx = i break end
	end
	if not idx then return false end

	table.remove(data.WeaponInstances, idx)
	data.OwnedWeapons = ensureUniqueOwnedWeapons(data.WeaponInstances)

	if data.EquippedWeaponInstanceId == instanceId then
		data.EquippedWeaponInstanceId = data.WeaponInstances[1] and data.WeaponInstances[1].instanceId or nil
	end

	Store.MarkDirty(player, "weapon_remove")
	return true
end

function Store.SetEquippedWeaponInstance(player: Player, instanceId: string)
	local data = Store.Get(player) or Store.Load(player)
	local inst = Store.GetWeaponInstance(player, instanceId)
	if not inst then return false end

	data.EquippedWeaponInstanceId = inst.instanceId
	data.StarterWeaponClaimed = true
	data.StarterWeaponName = inst.weaponId

	Store.MarkDirty(player, "equip_instance")
	return true
end

function Store.GetEquippedWeaponInstance(player: Player)
	local data = Store.Get(player) or Store.Load(player)
	local id = data.EquippedWeaponInstanceId
	if typeof(id) ~= "string" or id == "" then return nil end
	local inst = Store.GetWeaponInstance(player, id)
	return inst
end

-- kompat: InventoryService
function Store.SetFavoriteWeapon(player: Player, weaponId: string, isFav: boolean)
	local data = Store.Get(player) or Store.Load(player)
	if typeof(weaponId) ~= "string" or weaponId == "" then return end

	isFav = isFav == true
	data.FavoriteWeapons = (typeof(data.FavoriteWeapons) == "table") and data.FavoriteWeapons or {}

	-- remove if exists
	local out = {}
	for _, w in ipairs(data.FavoriteWeapons) do
		if w ~= weaponId then
			table.insert(out, w)
		end
	end
	if isFav then
		table.insert(out, weaponId)
	end
	data.FavoriteWeapons = out

	Store.MarkDirty(player, "favorite")
end

-- ==== API: Missions state ====

function Store.GetMissionsState(player: Player)
	local data = Store.Get(player) or Store.Load(player)
	data.Missions = data.Missions or defaultState().Missions
	return data.Missions
end

-- ==== Lifecycle ====

SaveScheduler.Bind(Store)

Players.PlayerAdded:Connect(function(player)
	Store.Load(player)
end)

Players.PlayerRemoving:Connect(function(player)
	Store.ForceSave(player, "leave")
	cache[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		Store.ForceSave(player, "shutdown")
	end
end)

return Store
