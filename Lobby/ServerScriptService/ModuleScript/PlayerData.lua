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

		if typeof(loaded.upgrades) == "table" then
			data.upgrades.dmg = clampInt(loaded.upgrades.dmg)
			data.upgrades.speed = clampInt(loaded.upgrades.speed)
			data.upgrades.jump = clampInt(loaded.upgrades.jump)
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

	local payload = {
		level = data.level,
		xp = data.xp,
		nextXp = data.nextXp,
		coins = data.coins,
		upgradePoints = data.upgradePoints,
		upgrades = data.upgrades,
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
	return 110 + (level - 1) * 55
end

return PlayerData
