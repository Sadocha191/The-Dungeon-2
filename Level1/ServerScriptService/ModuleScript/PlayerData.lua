-- PlayerData (ServerScriptService) - globalny profil (bez armora)

local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("GlobalPlayerProgress_v1")
local legacyStore = DataStoreService:GetDataStore("GlobalProfile_v4")

local PlayerData = {}
PlayerData._cache = {}
PlayerData._dirty = {}
PlayerData._saving = {}

local function defaultProfile()
	return {
		level = 1,
		xp = 0,
		nextXp = 120,
		coins = 0,
		upgradePoints = 0,
		upgrades = { dmg = 0, speed = 0, jump = 0 },

		-- Combat stats
		damage = 0,           -- bonus dmg (% -> damage/100)
		fireChance = 0.00,    -- 0..1
		fireDps = 0,          -- dmg/sec (DoT)
		multiShot = 0,        -- dodatkowe pociski (0 = normal)
		ricochet = 0,         -- liczba odbić pocisku
		attackSpeed = 1.00,   -- mnożnik szybkości ataku
		critChance = 0,       -- bonus do crit chance
		critMult = 0,         -- bonus do crit dmg

		-- Base player stats (always active)
		baseHP = 100,
		baseSpeed = 1.0,
		baseCritRate = 0.05,
		baseCritDmg = 1.5,
		baseDefense = 0,
		baseLifesteal = 0,

		-- Unlock weapons
		unlockBow = true,
		unlockWand = true,

		-- Loadout (weapon entries: { id, level, rarity, stats })
		Loadout = {},
	}
end

local function clampInt(x)
	x = tonumber(x) or 0
	x = math.floor(x)
	if x < 0 then x = 0 end
	return x
end

function PlayerData.Get(plr)
	local uid = plr.UserId
	if PlayerData._cache[uid] then
		return PlayerData._cache[uid]
	end

	local data = defaultProfile()
	local ok, saved = pcall(function()
		return store:GetAsync(tostring(uid))
	end)

	if ok and typeof(saved) == "table" then
		for k,v in pairs(saved) do
			data[k] = v
		end
		if typeof(saved.upgrades) == "table" then
			data.upgrades = data.upgrades or { dmg = 0, speed = 0, jump = 0 }
			data.upgrades.dmg = clampInt(saved.upgrades.dmg)
			data.upgrades.speed = clampInt(saved.upgrades.speed)
			data.upgrades.jump = clampInt(saved.upgrades.jump)
		end
	else
		local legacyOk, legacySaved = pcall(function()
			return legacyStore:GetAsync(tostring(uid))
		end)
		if legacyOk and typeof(legacySaved) == "table" then
			for k,v in pairs(legacySaved) do
				data[k] = v
			end
			if typeof(legacySaved.upgrades) == "table" then
				data.upgrades = data.upgrades or { dmg = 0, speed = 0, jump = 0 }
				data.upgrades.dmg = clampInt(legacySaved.upgrades.dmg)
				data.upgrades.speed = clampInt(legacySaved.upgrades.speed)
				data.upgrades.jump = clampInt(legacySaved.upgrades.jump)
			end
			pcall(function()
				store:SetAsync(tostring(uid), data)
			end)
		end
	end

	-- sanity
	data.level = math.max(1, clampInt(data.level))
	data.xp = math.max(0, clampInt(data.xp))
	data.nextXp = math.max(50, clampInt(data.nextXp) or 120)
	data.coins = math.max(0, clampInt(data.coins))
	data.upgradePoints = clampInt(data.upgradePoints)
	if typeof(data.upgrades) ~= "table" then
		data.upgrades = { dmg = 0, speed = 0, jump = 0 }
	end

	data.damage = math.max(0, tonumber(data.damage) or 0)
	data.fireChance = math.clamp(tonumber(data.fireChance) or 0, 0, 0.9)
	data.fireDps = math.max(0, clampInt(data.fireDps) or 0)
	data.multiShot = math.clamp(clampInt(data.multiShot), 0, 6)
	data.ricochet = math.clamp(clampInt(data.ricochet), 0, 4)
	data.attackSpeed = math.clamp(tonumber(data.attackSpeed) or 1.0, 0.6, 2.0)
	data.critChance = math.clamp(tonumber(data.critChance) or 0, 0, 0.6)
	data.critMult = tonumber(data.critMult) or 0

	data.baseHP = math.max(1, clampInt(data.baseHP) or 100)
	data.baseSpeed = math.clamp(tonumber(data.baseSpeed) or 1.0, 0.5, 2.0)
	data.baseCritRate = math.clamp(tonumber(data.baseCritRate) or 0.05, 0, 0.6)
	data.baseCritDmg = math.max(1.0, tonumber(data.baseCritDmg) or 1.5)
	data.baseDefense = math.max(0, tonumber(data.baseDefense) or 0)
	data.baseLifesteal = math.clamp(tonumber(data.baseLifesteal) or 0, 0, 0.12)

	data.unlockBow = data.unlockBow ~= false
	data.unlockWand = data.unlockWand ~= false
	if typeof(data.Loadout) ~= "table" then
		data.Loadout = {}
	end

	PlayerData._cache[uid] = data
	PlayerData._dirty[uid] = false
	return data
end

function PlayerData.RollNextXp(level: number): number
	return 120 + (level - 1) * 70
end

function PlayerData.MarkDirty(plr)
	PlayerData._dirty[plr.UserId] = true
end

function PlayerData.Save(plr, force: boolean)
	local uid = plr.UserId
	if PlayerData._saving[uid] then return end
	local data = PlayerData._cache[uid]
	if not data then return end
	if (not force) and (not PlayerData._dirty[uid]) then return end

	PlayerData._saving[uid] = true
	pcall(function()
		store:SetAsync(tostring(uid), data)
	end)
	PlayerData._saving[uid] = false
	PlayerData._dirty[uid] = false
end

function PlayerData.Reset(plr)
	PlayerData._cache[plr.UserId] = defaultProfile()
	PlayerData._dirty[plr.UserId] = true
end

return PlayerData
