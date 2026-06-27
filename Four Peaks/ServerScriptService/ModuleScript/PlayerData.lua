-- PlayerData (ServerScriptService) - globalny profil (bez armora)
-- Used for: silver, XP/level, gacha (Weapons/Pity), tickets, weaponPoints.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local store = DataStoreService:GetDataStore("GlobalPlayerProgress_v1")
local legacyStore = DataStoreService:GetDataStore("GlobalProfile_v4")

local PlayerData = {}
PlayerData._cache = {}
PlayerData._dirty = {}
PlayerData._saving = {}

local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = nil
if replicatedModules and replicatedModules:FindFirstChild("SpellDefinitions") then
	local ok, result = pcall(require, replicatedModules.SpellDefinitions)
	if ok then
		SpellDefs = result
	end
end

local CODEX_CATEGORIES = {
	"Spells",
	"Combinations",
	"Enemies",
	"Elites",
	"Bosses",
	"Weapons",
	"Materials",
}

local function defaultCraftingData()
	return {
		recipes = {},
		mineResources = {},
		mobMaterials = {},
		upgradeMaterials = {},
		miningSession = nil,
	}
end

local function defaultDailyLoginData()
	return {
		LastClaimDayUTC = 0,
		CurrentDay = 1,
		TotalClaims = 0,
	}
end

local function defaultEventsData()
	return {
		Progress = {},
	}
end

local function defaultGuildData()
	return {
		GuildId = nil,
		Role = nil,
		JoinedAt = 0,
		Contribution = 0,
	}
end

local function defaultCodexData()
	local discovered = {}
	local seen = {}
	for _, category in ipairs(CODEX_CATEGORIES) do
		discovered[category] = {}
		seen[category] = {}
	end
	return {
		Discovered = discovered,
		Seen = seen,
	}
end

local function defaultProfile()
	return {
		level = 1,
		xp = 0,
		nextXp = 120,

		-- currencies
		silver = 0, -- SILVER (lobby currency)
		souls = 0, -- purple currency (witch)
		weaponPoints = 0, -- premium
		tickets = 0,      -- gacha tickets

		upgradePoints = 0,
		upgrades = { dmg = 0, speed = 0, jump = 0 },

		-- Combat stats
		damage = 0,
		fireChance = 0.00,
		fireDps = 0,
		multiShot = 0,
		ricochet = 0,
		attackSpeed = 1.00,
		critChance = 0,
		critMult = 0,
		damageBonusPct = 0,
		lifesteal = 0,

		-- Base player stats (always active)
		baseHP = 100,
		baseSpeed = 1.0,
		baseCritRate = 0.05,
		baseCritDmg = 1.5,
		baseDefense = 0,
		baseLifesteal = 0,

		-- Run buffs
		rangeBonus = 0,
		battleFocusBonus = 0,
		momentumBonus = 0,
		cleaveBonus = 0,
		riposteBonus = 0,
		bladeDanceEvery = 0,
		parryReduction = 0,
		staggerDuration = 0,
		executeBonus = 0,
		overchargeBonus = 0,
		sweepBonus = 0,
		thrustBonus = 0,
		pierceBonus = 0,
		slamRadiusBonus = 0,
		aftershockMultiplier = 0,
		eagleEyeBonus = 0,
		quickDrawBonus = 0,
		arrowPierce = 0,
		elementalPowerBonus = 0,
		arcaneOverflowHeal = 0,
		manaSurgeEvery = 0,
		deadeyeDelay = 0,

		-- Unlock weapons
		unlockBow = true,
		unlockWand = true,

		-- Gacha state
		Weapons = {}, -- lista weaponId z rolli (opcjonalnie)
		Pity = {},

		-- Tutorial / Spells
		tutorialCompleted = false,
		spellbookUnlocked = false,
		spellsUnlocked = {}, -- [spellId] = true
		spellLoadout = {},
		spellLoadoutConfigured = false,
		Codex = defaultCodexData(),

		-- Loadout (weapon entries: { id, level, rarity, stats })
		Loadout = {},
		levelRecords = {},

		crafting = defaultCraftingData(),
		DailyLogin = defaultDailyLoginData(),
		Events = defaultEventsData(),
		Guild = defaultGuildData(),
	}
end

local function clampInt(x)
	x = tonumber(x) or 0
	x = math.floor(x)
	if x < 0 then x = 0 end
	return x
end

local function sanitizeCountMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = clampInt(value)
			if amount > 0 then
				out[key] = amount
			end
		end
	end
	return out
end

local function sanitizeStringList(raw)
	local out = {}
	local seen = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for _, value in ipairs(raw) do
		if typeof(value) == "string" and value ~= "" and not seen[value] then
			seen[value] = true
			table.insert(out, value)
		end
	end
	return out
end

local function sanitizeRecipes(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for recipeId, state in pairs(raw) do
		if typeof(recipeId) == "string" and recipeId ~= "" then
			if state == true then
				out[recipeId] = {
					found = true,
					copies = 1,
					tier = 1,
					unlocked = false,
					lastFoundAt = 0,
				}
			elseif typeof(state) == "table" then
				local found = state.found == true or state.discovered == true or state.copies ~= nil
				local copies = clampInt(state.copies or state.foundCount or state.duplicates or 0)
				if found and copies <= 0 then
					copies = 1
				end
				if found then
					out[recipeId] = {
						found = true,
						copies = copies,
						tier = math.max(1, clampInt(state.tier or 1)),
						unlocked = state.unlocked == true,
						lastFoundAt = clampInt(state.lastFoundAt or state.discoveredAt or 0),
					}
				end
			end
		end
	end
	return out
end

local function sanitizeMiningSession(raw)
	if typeof(raw) ~= "table" then
		return nil
	end

	local startedAt = clampInt(raw.startedAt or raw.StartedAt)
	local endsAt = clampInt(raw.endsAt or raw.EndsAt)
	local durationSec = clampInt(raw.durationSec or raw.DurationSec)
	if startedAt <= 0 or endsAt <= startedAt or durationSec <= 0 then
		return nil
	end

	local mineId = raw.mineId or raw.MineId
	if typeof(mineId) ~= "string" or mineId == "" then
		mineId = nil
	end

	local focusRecipeId = raw.focusRecipeId or raw.FocusRecipeId
	if typeof(focusRecipeId) ~= "string" or focusRecipeId == "" then
		focusRecipeId = nil
	end

	return {
		startedAt = startedAt,
		endsAt = endsAt,
		durationSec = durationSec,
		priority = sanitizeStringList(raw.priority or raw.Priority),
		mineId = mineId,
		focusRecipeId = focusRecipeId,
	}
end

local function sanitizeLevelRecords(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end

	for levelKey, record in pairs(raw) do
		if typeof(levelKey) == "string" and levelKey ~= "" and typeof(record) == "table" then
			local highscore = math.max(0, clampInt(record.highscore or record.kills or record.killHighscore))
			local speedrun = tonumber(record.speedrun or record.bestTime or record.bestSeconds or record.fastestClear)
			if speedrun ~= nil then
				speedrun = math.max(0, speedrun)
				if speedrun <= 0 then
					speedrun = nil
				end
			end

			if highscore > 0 or speedrun ~= nil then
				out[levelKey] = {
					highscore = highscore,
					speedrun = speedrun,
				}
			end
		end
	end

	return out
end

local function sanitizeDailyLogin(raw)
	local out = defaultDailyLoginData()
	if typeof(raw) ~= "table" then
		return out
	end

	out.LastClaimDayUTC = clampInt(raw.LastClaimDayUTC or raw.lastClaimDayUTC)
	out.CurrentDay = math.clamp(clampInt(raw.CurrentDay or raw.currentDay), 1, 7)
	out.TotalClaims = clampInt(raw.TotalClaims or raw.totalClaims)
	return out
end

local function sanitizeEventStats(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = clampInt(value)
			if amount > 0 then
				out[key] = amount
			end
		end
	end
	return out
end

local function sanitizeBoolIdMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" and value == true then
			out[key] = true
		end
	end
	return out
end

local function sanitizeCodex(raw)
	local out = defaultCodexData()
	if typeof(raw) ~= "table" then
		return out
	end

	local discovered = typeof(raw.Discovered) == "table" and raw.Discovered or raw.discovered
	local seen = typeof(raw.Seen) == "table" and raw.Seen or raw.seen

	for _, category in ipairs(CODEX_CATEGORIES) do
		if typeof(discovered) == "table" then
			out.Discovered[category] = sanitizeBoolIdMap(discovered[category])
		end
		if typeof(seen) == "table" then
			out.Seen[category] = sanitizeBoolIdMap(seen[category])
		end
	end

	return out
end

local function sanitizeEventBoolMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" and value == true then
			out[key] = true
		end
	end
	return out
end

local function sanitizeEvents(raw)
	local out = defaultEventsData()
	if typeof(raw) ~= "table" then
		return out
	end

	local progress = raw.Progress
	if typeof(progress) ~= "table" then
		return out
	end

	for eventId, eventState in pairs(progress) do
		if typeof(eventId) == "string" and eventId ~= "" and typeof(eventState) == "table" then
			out.Progress[eventId] = {
				Stats = sanitizeEventStats(eventState.Stats),
				ClaimedTasks = sanitizeEventBoolMap(eventState.ClaimedTasks),
				ClaimedMilestones = sanitizeEventBoolMap(eventState.ClaimedMilestones),
				ClaimedFinalRewards = eventState.ClaimedFinalRewards == true,
			}
		end
	end

	return out
end

local function sanitizeGuild(raw)
	local out = defaultGuildData()
	if typeof(raw) ~= "table" then
		return out
	end

	local guildId = raw.GuildId or raw.guildId
	if typeof(guildId) == "string" and guildId ~= "" then
		out.GuildId = guildId
	end

	local role = raw.Role or raw.role
	if role == "Owner" or role == "Officer" or role == "Member" then
		out.Role = role
	end

	out.JoinedAt = clampInt(raw.JoinedAt or raw.joinedAt)
	out.Contribution = clampInt(raw.Contribution or raw.contribution)

	if not out.GuildId then
		out.Role = nil
		out.JoinedAt = 0
		out.Contribution = 0
	end

	return out
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
		for k, v in pairs(saved) do
			data[k] = v
		end
		
		-- MIGRATE_COINS_TO_SILVER
		if data.silver == nil and data.coins ~= nil then
			data.silver = tonumber(data.coins) or 0
		end
		data.coins = nil

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
			for k, v in pairs(legacySaved) do
				data[k] = v
			end
			
			-- MIGRATE_LEGACY_COINS_TO_SILVER
			if data.silver == nil and data.coins ~= nil then
				data.silver = tonumber(data.coins) or 0
			end
			data.coins = nil

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

	data.silver = math.max(0, clampInt(data.silver))
	data.souls = math.max(0, clampInt(data.souls))
	data.weaponPoints = math.max(0, clampInt(data.weaponPoints))
	data.tickets = math.max(0, clampInt(data.tickets))

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
	data.damageBonusPct = math.max(0, tonumber(data.damageBonusPct) or 0)
	data.lifesteal = math.clamp(tonumber(data.lifesteal) or 0, 0, 0.12)

	data.baseHP = math.max(1, clampInt(data.baseHP) or 100)
	data.baseSpeed = math.clamp(tonumber(data.baseSpeed) or 1.0, 0.5, 2.0)
	data.baseCritRate = math.clamp(tonumber(data.baseCritRate) or 0.05, 0, 0.6)
	data.baseCritDmg = math.max(1.0, tonumber(data.baseCritDmg) or 1.5)
	data.baseDefense = math.max(0, tonumber(data.baseDefense) or 0)
	data.baseLifesteal = math.clamp(tonumber(data.baseLifesteal) or 0, 0, 0.12)

	data.rangeBonus = math.max(0, tonumber(data.rangeBonus) or 0)
	data.battleFocusBonus = math.max(0, tonumber(data.battleFocusBonus) or 0)
	data.momentumBonus = math.max(0, tonumber(data.momentumBonus) or 0)
	data.cleaveBonus = math.max(0, clampInt(data.cleaveBonus))
	data.riposteBonus = math.max(0, tonumber(data.riposteBonus) or 0)
	data.bladeDanceEvery = math.max(0, clampInt(data.bladeDanceEvery))
	data.parryReduction = math.clamp(tonumber(data.parryReduction) or 0, 0, 0.6)
	data.staggerDuration = math.max(0, tonumber(data.staggerDuration) or 0)
	data.executeBonus = math.max(0, tonumber(data.executeBonus) or 0)
	data.overchargeBonus = math.max(0, tonumber(data.overchargeBonus) or 0)
	data.sweepBonus = math.max(0, tonumber(data.sweepBonus) or 0)
	data.thrustBonus = math.max(0, tonumber(data.thrustBonus) or 0)
	data.pierceBonus = math.max(0, clampInt(data.pierceBonus))
	data.slamRadiusBonus = math.max(0, tonumber(data.slamRadiusBonus) or 0)
	data.aftershockMultiplier = math.max(0, tonumber(data.aftershockMultiplier) or 0)
	data.eagleEyeBonus = math.max(0, tonumber(data.eagleEyeBonus) or 0)
	data.quickDrawBonus = math.max(0, tonumber(data.quickDrawBonus) or 0)
	data.arrowPierce = math.max(0, clampInt(data.arrowPierce))
	data.elementalPowerBonus = math.max(0, tonumber(data.elementalPowerBonus) or 0)
	data.arcaneOverflowHeal = math.max(0, tonumber(data.arcaneOverflowHeal) or 0)
	data.manaSurgeEvery = math.max(0, clampInt(data.manaSurgeEvery))
	data.deadeyeDelay = math.max(0, tonumber(data.deadeyeDelay) or 0)

	data.unlockBow = data.unlockBow ~= false
	data.unlockWand = data.unlockWand ~= false

	if typeof(data.Weapons) ~= "table" then data.Weapons = {} end
	if typeof(data.Pity) ~= "table" then data.Pity = {} end
	if typeof(data.Loadout) ~= "table" then data.Loadout = {} end
	data.levelRecords = sanitizeLevelRecords(data.levelRecords)
	if typeof(data.crafting) ~= "table" then
		data.crafting = defaultCraftingData()
	end
	data.crafting.recipes = sanitizeRecipes(data.crafting.recipes)
	data.crafting.mineResources = sanitizeCountMap(data.crafting.mineResources)
	data.crafting.mobMaterials = sanitizeCountMap(data.crafting.mobMaterials)
	data.crafting.upgradeMaterials = sanitizeCountMap(data.crafting.upgradeMaterials)
	data.crafting.miningSession = sanitizeMiningSession(data.crafting.miningSession)
	data.DailyLogin = sanitizeDailyLogin(data.DailyLogin)
	data.Events = sanitizeEvents(data.Events)
	data.Guild = sanitizeGuild(data.Guild)

	-- tutorial/spells sanity
	data.tutorialCompleted = data.tutorialCompleted == true
	data.spellbookUnlocked = data.spellbookUnlocked == true
	if typeof(data.spellsUnlocked) ~= "table" then
		data.spellsUnlocked = {}
	end
	data.spellLoadout = sanitizeStringList(data.spellLoadout)
	data.spellLoadoutConfigured = data.spellLoadoutConfigured == true
	data.Codex = sanitizeCodex(data.Codex)

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

local function validateSpellLoadout(rawLoadout, unlocked)
	if SpellDefs and SpellDefs.ValidateSpellLoadout then
		return SpellDefs.ValidateSpellLoadout(rawLoadout, unlocked)
	end
	return sanitizeStringList(rawLoadout)
end

function PlayerData.GetSpellLoadout(plr)
	local data = PlayerData.Get(plr)
	data.spellLoadout = validateSpellLoadout(data.spellLoadout, data.spellsUnlocked)
	return sanitizeStringList(data.spellLoadout)
end

function PlayerData.ResolveSpellLoadout(plr)
	local data = PlayerData.Get(plr)
	local loadout = validateSpellLoadout(data.spellLoadout, data.spellsUnlocked)
	if #loadout > 0 or data.spellLoadoutConfigured == true then
		return loadout
	end
	if SpellDefs and SpellDefs.BuildDefaultLoadout then
		return SpellDefs.BuildDefaultLoadout(data.spellsUnlocked)
	end
	return {}
end

function PlayerData.SetSpellLoadout(plr, rawLoadout)
	local data = PlayerData.Get(plr)
	local nextLoadout = validateSpellLoadout(rawLoadout, data.spellsUnlocked)
	local current = validateSpellLoadout(data.spellLoadout, data.spellsUnlocked)

	local changed = #nextLoadout ~= #current
	if not changed then
		for index, id in ipairs(nextLoadout) do
			if current[index] ~= id then
				changed = true
				break
			end
		end
	end

	if changed then
		data.spellLoadout = nextLoadout
	end
	if data.spellLoadoutConfigured ~= true then
		changed = true
	end
	data.spellLoadoutConfigured = true
	if changed then
		PlayerData.MarkDirty(plr)
	end
	return nextLoadout, changed
end

local function normalizeCodexCategory(category)
	category = tostring(category or "")
	for _, known in ipairs(CODEX_CATEGORIES) do
		if string.lower(known) == string.lower(category) then
			return known
		end
	end
	return nil
end

function PlayerData.DiscoverCodex(plr, category, id, _reason)
	category = normalizeCodexCategory(category)
	if not category or typeof(id) ~= "string" or id == "" then
		return false
	end
	local data = PlayerData.Get(plr)
	data.Codex = sanitizeCodex(data.Codex)
	local bucket = data.Codex.Discovered[category]
	if bucket[id] == true then
		return false
	end
	bucket[id] = true
	PlayerData.MarkDirty(plr)
	return true
end

function PlayerData.MarkCodexSeen(plr, category, id)
	category = normalizeCodexCategory(category)
	if not category or typeof(id) ~= "string" or id == "" then
		return false
	end
	local data = PlayerData.Get(plr)
	data.Codex = sanitizeCodex(data.Codex)
	local bucket = data.Codex.Seen[category]
	if bucket[id] == true then
		return false
	end
	bucket[id] = true
	PlayerData.MarkDirty(plr)
	return true
end

function PlayerData.GetCodexSnapshot(plr)
	local data = PlayerData.Get(plr)
	data.Codex = sanitizeCodex(data.Codex)
	local snapshot = defaultCodexData()
	for _, category in ipairs(CODEX_CATEGORIES) do
		for id, value in pairs(data.Codex.Discovered[category] or {}) do
			if value == true then
				snapshot.Discovered[category][id] = true
			end
		end
		for id, value in pairs(data.Codex.Seen[category] or {}) do
			if value == true then
				snapshot.Seen[category][id] = true
			end
		end
	end
	return snapshot
end

function PlayerData.GetLevelRecordsSnapshot(plr): {[string]: any}
	local data = PlayerData.Get(plr)
	local snapshot = {}
	local raw = data.levelRecords
	if typeof(raw) ~= "table" then
		return snapshot
	end

	for levelKey, record in pairs(raw) do
		if typeof(levelKey) == "string" and levelKey ~= "" and typeof(record) == "table" then
			local entry = {
				highscore = math.max(0, clampInt(record.highscore)),
			}
			local speedrun = tonumber(record.speedrun)
			if speedrun and speedrun > 0 then
				entry.speedrun = speedrun
			end
			snapshot[levelKey] = entry
		end
	end

	return snapshot
end

function PlayerData.UpdateLevelRecord(plr, levelKey: string, kills: number?, completionSeconds: number?, completed: boolean?): (any, boolean)
	local data = PlayerData.Get(plr)
	if typeof(levelKey) ~= "string" or levelKey == "" then
		return nil, false
	end

	data.levelRecords = sanitizeLevelRecords(data.levelRecords)
	local current = data.levelRecords[levelKey]
	if typeof(current) ~= "table" then
		current = {
			highscore = 0,
			speedrun = nil,
		}
		data.levelRecords[levelKey] = current
	end

	local changed = false
	local killCount = math.max(0, clampInt(kills))
	if killCount > math.max(0, clampInt(current.highscore)) then
		current.highscore = killCount
		changed = true
	end

	local clearTime = tonumber(completionSeconds)
	if completed == true and clearTime and clearTime > 0 then
		local bestTime = tonumber(current.speedrun)
		if bestTime == nil or clearTime < bestTime then
			current.speedrun = clearTime
			changed = true
		end
	end

	if changed then
		PlayerData.MarkDirty(plr)
	end

	return current, changed
end

function PlayerData.Save(plr, force: boolean)
	local uid = plr.UserId
	if PlayerData._saving[uid] then return end
	local data = PlayerData._cache[uid]
	if not data then return end
	if (not force) and (not PlayerData._dirty[uid]) then return end

	PlayerData._saving[uid] = true
	local ok = pcall(function()
		store:SetAsync(tostring(uid), data)
	end)
	PlayerData._saving[uid] = false
	if ok then
		PlayerData._dirty[uid] = false
	else
		PlayerData._dirty[uid] = true
	end
end

function PlayerData.Release(plr, force: boolean?)
	if not plr then
		return
	end

	local uid = plr.UserId
	PlayerData.Save(plr, force == true)
	PlayerData._cache[uid] = nil
	PlayerData._dirty[uid] = nil
	PlayerData._saving[uid] = nil
end

function PlayerData.Reset(plr)
	PlayerData._cache[plr.UserId] = defaultProfile()
	PlayerData._dirty[plr.UserId] = true
end

Players.PlayerRemoving:Connect(function(plr)
	PlayerData.Release(plr, true)
end)

game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		PlayerData.Save(plr, true)
	end
end)

return PlayerData
