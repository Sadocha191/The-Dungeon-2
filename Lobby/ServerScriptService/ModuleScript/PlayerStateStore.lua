-- MODULE: PlayerStateStore.lua
-- GDZIE: ServerScriptService/PlayerStateStore.lua (ModuleScript)
-- ZMIANA: dodaj StarterWeaponName + SetStarterWeaponClaimed(player, weaponName)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DS = DataStoreService:GetDataStore("PlayerState_v1")

local Store = {}
local cache: {[number]: any} = {}

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
			Profile = nil,
		}
	end

	-- kompatybilność wstecz (jeśli stary zapis)
	if data.StarterWeaponName == nil then
		data.StarterWeaponName = nil
	end

	cache[uid] = data
	return data
end

function Store.Get(player: Player)
	return cache[player.UserId]
end

function Store.Save(player: Player)
	local uid = player.UserId
	local data = cache[uid]
	if not data then return end

	local ok, err = pcall(function()
		DS:SetAsync(key(uid), data)
	end)
	if not ok then
		warn("[PlayerStateStore] SetAsync failed:", err)
	end
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

Players.PlayerRemoving:Connect(function(player)
	Store.Save(player)
	cache[player.UserId] = nil
end)

return Store
