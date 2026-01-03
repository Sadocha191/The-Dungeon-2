-- MODULE: PlayerStateStore.lua
-- GDZIE: ServerScriptService/PlayerStateStore.lua (ModuleScript)
-- ZMIANA: dodaj StarterWeaponName + SetStarterWeaponClaimed(player, weaponName)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DS = DataStoreService:GetDataStore("PlayerState_v1")

local Store = {}
local cache: {[number]: any} = {}
local lastSave: {[number]: number} = {}
local pendingSave: {[number]: boolean} = {}

local SAVE_COOLDOWN = 2.0

local function key(userId: number): string
	return "u:" .. tostring(userId)
end

function Store.Load(player: Player)
	local uid = player.UserId
	local data

	local ok, err = pcall(function()
		data = DS:GetAsync(key(uid))
	end)
	if not ok then
		warn("[PlayerStateStore] GetAsync failed:", err)
		data = nil
	end

	if typeof(data) ~= "table" then
		data = {
			CreatedOnce = false,
			StarterWeaponClaimed = false,
			StarterWeaponName = nil, -- ✅
			OwnedWeapons = {},
			FavoriteWeapons = {},
			Profile = nil,
		}
	end

	-- kompatybilność wstecz (jeśli stary zapis)
	if data.StarterWeaponName == nil then
		data.StarterWeaponName = nil
	end
	if typeof(data.OwnedWeapons) ~= "table" then
		data.OwnedWeapons = {}
	end
	if typeof(data.FavoriteWeapons) ~= "table" then
		data.FavoriteWeapons = {}
	end

	cache[uid] = data
	return data
end

function Store.Get(player: Player)
	return cache[player.UserId]
end

local function doSave(player: Player)
	local uid = player.UserId
	local data = cache[uid]
	if not data then return end

	local ok, err = pcall(function()
		DS:SetAsync(key(uid), data)
	end)
	if not ok then
		warn("[PlayerStateStore] SetAsync failed:", err)
	end
	lastSave[uid] = os.clock()
	pendingSave[uid] = nil
end

function Store.Save(player: Player, force: boolean?)
	local uid = player.UserId
	if force then
		doSave(player)
		return
	end

	local now = os.clock()
	local last = lastSave[uid] or 0
	local elapsed = now - last
	if elapsed >= SAVE_COOLDOWN then
		doSave(player)
		return
	end

	if pendingSave[uid] then
		return
	end

	pendingSave[uid] = true
	task.delay(SAVE_COOLDOWN - elapsed, function()
		if player.Parent == nil then
			pendingSave[uid] = nil
			return
		end
		doSave(player)
	end)
end

function Store.SetCreated(player: Player, profileLite: any)
	local data = cache[player.UserId] or Store.Load(player)
	data.CreatedOnce = true
	data.Profile = profileLite
	Store.Save(player)
end

function Store.SetStarterWeaponClaimed(player: Player, weaponName: string)
	local data = cache[player.UserId] or Store.Load(player)
	data.StarterWeaponClaimed = true
	data.StarterWeaponName = weaponName -- ✅
	Store.Save(player)
end

function Store.SetEquippedWeaponName(player: Player, weaponName: string?)
	local data = cache[player.UserId] or Store.Load(player)
	if typeof(weaponName) == "string" and weaponName ~= "" then
		data.StarterWeaponClaimed = true
		data.StarterWeaponName = weaponName
	else
		data.StarterWeaponClaimed = false
		data.StarterWeaponName = nil
	end
	Store.Save(player)
end

function Store.EnsureOwnedWeapon(player: Player, weaponName: string)
	local data = cache[player.UserId] or Store.Load(player)
	if typeof(weaponName) ~= "string" or weaponName == "" then return end
	data.OwnedWeapons = data.OwnedWeapons or {}
	for _, name in ipairs(data.OwnedWeapons) do
		if name == weaponName then
			return
		end
	end
	table.insert(data.OwnedWeapons, weaponName)
	Store.Save(player)
end

function Store.RemoveOwnedWeapon(player: Player, weaponName: string)
	local data = cache[player.UserId] or Store.Load(player)
	if typeof(weaponName) ~= "string" or weaponName == "" then return end
	data.OwnedWeapons = data.OwnedWeapons or {}
	for index, name in ipairs(data.OwnedWeapons) do
		if name == weaponName then
			table.remove(data.OwnedWeapons, index)
			break
		end
	end
	Store.Save(player)
end

function Store.SetFavoriteWeapon(player: Player, weaponName: string, isFavorite: boolean)
	local data = cache[player.UserId] or Store.Load(player)
	if typeof(weaponName) ~= "string" or weaponName == "" then return end
	data.FavoriteWeapons = data.FavoriteWeapons or {}
	for index, name in ipairs(data.FavoriteWeapons) do
		if name == weaponName then
			if not isFavorite then
				table.remove(data.FavoriteWeapons, index)
				Store.Save(player)
			end
			return
		end
	end
	if isFavorite then
		table.insert(data.FavoriteWeapons, weaponName)
		Store.Save(player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	Store.Save(player, true)
	cache[player.UserId] = nil
end)

return Store
