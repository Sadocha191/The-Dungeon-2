-- MODULE: PlayerData.lua
-- GDZIE: ServerScriptService/PlayerData.lua (ModuleScript)  [W LOBBY]
-- CO: globalny progres (level/xp/coins) wspólny dla lobby i dungeon

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "GlobalPlayerProgress_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)

local PlayerData = {}
PlayerData._cache = {} :: {[number]: any}
PlayerData._dirty = {} :: {[number]: boolean}
PlayerData._saving = {} :: {[number]: boolean}

local function defaultData()
	return {
		level = 1,
		xp = 0,
		nextXp = 120,
		coins = 0,
		upgradePoints = 0,
		upgrades = { dmg = 0, speed = 0, jump = 0 },

		Currencies = {
			Coins = 0,
			WeaponPoints = 0,
			Tickets = 0,
		},
		Pity = {},
		Weapons = {},

		-- Combat stats (dla dungeona; trzymamy wspólny zapis)
		damage = 18,
		fireChance = 0.00,
		fireDps = 0,
		multiShot = 0,
		ricochet = 0,
		attackSpeed = 1.00,

		-- Unlocks (weapon)
		unlockBow = true,
		unlockWand = true,
	}
end

local function clampInt(x)
	x = tonumber(x) or 0
	x = math.floor(x)
	if x < 0 then x = 0 end
	return x
end

function PlayerData.Get(plr: Player)
	local uid = plr.UserId
	local data = PlayerData._cache[uid]
	if data then return data end

	local loaded
	local ok = pcall(function()
		loaded = store:GetAsync(tostring(uid))
	end)

	data = defaultData()
	if ok and typeof(loaded) == "table" then
		data.level = clampInt(loaded.level)
		data.xp = clampInt(loaded.xp)
		data.nextXp = clampInt(loaded.nextXp)
		data.coins = clampInt(loaded.coins)
		data.upgradePoints = clampInt(loaded.upgradePoints)

		if typeof(loaded.Currencies) == "table" then
			data.Currencies.Coins = clampInt(loaded.Currencies.Coins)
			data.Currencies.WeaponPoints = clampInt(loaded.Currencies.WeaponPoints)
			data.Currencies.Tickets = clampInt(loaded.Currencies.Tickets)
		else
			data.Currencies.Coins = data.coins
		end
		data.coins = data.Currencies.Coins

		if typeof(loaded.Pity) == "table" then
			data.Pity = loaded.Pity
		end
		if typeof(loaded.Weapons) == "table" then
			data.Weapons = loaded.Weapons
		end

		if typeof(loaded.upgrades) == "table" then
			data.upgrades.dmg = clampInt(loaded.upgrades.dmg)
			data.upgrades.speed = clampInt(loaded.upgrades.speed)
			data.upgrades.jump = clampInt(loaded.upgrades.jump)
		end

		if loaded.damage ~= nil then
			data.damage = clampInt(loaded.damage)
		end
		if loaded.fireChance ~= nil then
			data.fireChance = math.clamp(tonumber(loaded.fireChance) or 0, 0, 0.9)
		end
		if loaded.fireDps ~= nil then
			data.fireDps = clampInt(loaded.fireDps)
		end
		if loaded.multiShot ~= nil then
			data.multiShot = math.clamp(math.floor(tonumber(loaded.multiShot) or 0), 0, 6)
		end
		if loaded.ricochet ~= nil then
			data.ricochet = math.clamp(math.floor(tonumber(loaded.ricochet) or 0), 0, 4)
		end
		if loaded.attackSpeed ~= nil then
			data.attackSpeed = math.clamp(tonumber(loaded.attackSpeed) or 1.0, 0.6, 2.0)
		end

		if loaded.unlockBow ~= nil then
			data.unlockBow = loaded.unlockBow ~= false
		end
		if loaded.unlockWand ~= nil then
			data.unlockWand = loaded.unlockWand ~= false
		end

		if data.level < 1 then data.level = 1 end
		if data.nextXp < 50 then data.nextXp = 120 end
	end

	PlayerData._cache[uid] = data
	PlayerData._dirty[uid] = false
	return data
end

function PlayerData.MarkDirty(plr: Player)
	PlayerData._dirty[plr.UserId] = true
end

function PlayerData.Save(plr: Player)
	local uid = plr.UserId
	if PlayerData._saving[uid] then return end
	if not PlayerData._cache[uid] then return end
	if not PlayerData._dirty[uid] then return end

	PlayerData._saving[uid] = true
	local data = PlayerData._cache[uid]

	data.Currencies = data.Currencies or { Coins = 0, WeaponPoints = 0, Tickets = 0 }
	data.Currencies.Coins = clampInt(data.coins)

	local payload = {
		level = data.level,
		xp = data.xp,
		nextXp = data.nextXp,
		coins = data.Currencies.Coins,
		upgradePoints = data.upgradePoints,
		upgrades = data.upgrades,
		Currencies = data.Currencies,
		Pity = data.Pity,
		Weapons = data.Weapons,

		damage = data.damage,
		fireChance = data.fireChance,
		fireDps = data.fireDps,
		multiShot = data.multiShot,
		ricochet = data.ricochet,
		attackSpeed = data.attackSpeed,
		unlockBow = data.unlockBow,
		unlockWand = data.unlockWand,
	}

	local ok = pcall(function()
		store:SetAsync(tostring(uid), payload)
	end)

	PlayerData._saving[uid] = false
	if ok then
		PlayerData._dirty[uid] = false
	end
end

function PlayerData.SaveAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		PlayerData.Save(plr)
	end
end

function PlayerData.Reset(plr: Player)
	PlayerData._cache[plr.UserId] = defaultData()
	PlayerData._dirty[plr.UserId] = true
end

function PlayerData.RollNextXp(level: number)
	return 120 + (level - 1) * 70
end

return PlayerData
