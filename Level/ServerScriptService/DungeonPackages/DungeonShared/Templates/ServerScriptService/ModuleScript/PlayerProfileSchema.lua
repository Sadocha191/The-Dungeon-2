-- PlayerProfileSchema.lua
-- Backward-compatible defaults and sanitization for GlobalPlayerProgress_v1.

local Schema = {}

Schema.CODEX_CATEGORIES = {
	"Spells",
	"Combinations",
	"Enemies",
	"Elites",
	"Bosses",
	"Weapons",
	"Materials",
}

function Schema.Clone(value)
	if typeof(value) ~= "table" then return value end
	local copy = {}
	for key, nested in pairs(value) do
		copy[Schema.Clone(key)] = Schema.Clone(nested)
	end
	return copy
end

local function clampInt(value, minimum)
	local number = math.floor(tonumber(value) or 0)
	if minimum ~= nil and number < minimum then return minimum end
	return math.max(0, number)
end
Schema.ClampInt = clampInt

function Schema.SanitizeStringList(raw)
	local out, seen = {}, {}
	if typeof(raw) ~= "table" then return out end
	for _, value in ipairs(raw) do
		if typeof(value) == "string" and value ~= "" and not seen[value] then
			seen[value] = true
			table.insert(out, value)
		end
	end
	return out
end

local function sanitizeCountMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then return out end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = clampInt(value)
			if amount > 0 then out[key] = amount end
		end
	end
	return out
end

local function sanitizeBoolMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then return out end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" and value == true then out[key] = true end
	end
	return out
end

local function defaultCraftingData()
	return {
		recipes = {},
		mineResources = {},
		mobMaterials = {},
		upgradeMaterials = {},
		miningSession = nil,
	}
end

local function defaultMissionsData()
	return {
		DailyKey = 0,
		WeeklyKey = 0,
		SelectedDaily = {},
		SelectedWeekly = {},
		ClaimCounts = {},
		CountersDaily = {},
		CountersWeekly = {},
		WeeklyWeaponRuns = {},
		WeeklyWinStreak = 0,
	}
end

local function defaultDailyLoginData()
	return { LastClaimDayUTC = 0, CurrentDay = 1, TotalClaims = 0 }
end

local function defaultEventsData()
	return { Progress = {} }
end

local function defaultGuildData()
	return { GuildId = nil, Role = nil, JoinedAt = 0, Contribution = 0 }
end

local function defaultCodexData()
	local discovered, seen = {}, {}
	for _, category in ipairs(Schema.CODEX_CATEGORIES) do
		discovered[category] = {}
		seen[category] = {}
	end
	return { Discovered = discovered, Seen = seen }
end

function Schema.Default()
	return {
		level = 1,
		xp = 0,
		nextXp = 120,
		silver = 0,
		souls = 0,
		weaponPoints = 0,
		tickets = 0,
		upgradePoints = 0,
		upgrades = { dmg = 0, speed = 0, jump = 0 },

		damage = 0,
		fireChance = 0,
		fireDps = 0,
		multiShot = 0,
		ricochet = 0,
		attackSpeed = 1,
		critChance = 0,
		critMult = 0,
		damageBonusPct = 0,
		lifesteal = 0,

		baseHP = 100,
		baseSpeed = 1,
		baseCritRate = 0.05,
		baseCritDmg = 1.5,
		baseDefense = 0,
		baseLifesteal = 0,

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

		unlockBow = true,
		unlockWand = true,
		Weapons = {},
		Pity = {},
		tutorialCompleted = false,
		spellbookUnlocked = false,
		spellsUnlocked = {},
		spellLoadout = {},
		spellLoadoutConfigured = false,
		Codex = defaultCodexData(),
		Loadout = {},
		levelRecords = {},
		crafting = defaultCraftingData(),
		Missions = defaultMissionsData(),
		DailyLogin = defaultDailyLoginData(),
		Events = defaultEventsData(),
		Guild = defaultGuildData(),
	}
end

local function sanitizeRecipes(raw)
	local out = {}
	if typeof(raw) ~= "table" then return out end
	for recipeId, state in pairs(raw) do
		if typeof(recipeId) == "string" and recipeId ~= "" then
			if state == true then
				out[recipeId] = { found = true, copies = 1, tier = 1, unlocked = false, lastFoundAt = 0 }
			elseif typeof(state) == "table" then
				local found = state.found == true or state.discovered == true or state.copies ~= nil
				if found then
					out[recipeId] = {
						found = true,
						copies = math.max(1, clampInt(state.copies or state.foundCount or state.duplicates)),
						tier = math.max(1, clampInt(state.tier, 1)),
						unlocked = state.unlocked == true,
						lastFoundAt = clampInt(state.lastFoundAt or state.discoveredAt),
					}
				end
			end
		end
	end
	return out
end

local function sanitizeMiningSession(raw)
	if typeof(raw) ~= "table" then return nil end
	local startedAt = clampInt(raw.startedAt or raw.StartedAt)
	local endsAt = clampInt(raw.endsAt or raw.EndsAt)
	local durationSec = clampInt(raw.durationSec or raw.DurationSec)
	if startedAt <= 0 or endsAt <= startedAt or durationSec <= 0 then return nil end
	local mineId = raw.mineId or raw.MineId
	if typeof(mineId) ~= "string" or mineId == "" then mineId = nil end
	local focusRecipeId = raw.focusRecipeId or raw.FocusRecipeId
	if typeof(focusRecipeId) ~= "string" or focusRecipeId == "" then focusRecipeId = nil end
	return {
		startedAt = startedAt,
		endsAt = endsAt,
		durationSec = durationSec,
		priority = Schema.SanitizeStringList(raw.priority or raw.Priority),
		mineId = mineId,
		focusRecipeId = focusRecipeId,
	}
end

function Schema.SanitizeLevelRecords(raw)
	local out = {}
	if typeof(raw) ~= "table" then return out end
	for levelKey, record in pairs(raw) do
		if typeof(levelKey) == "string" and levelKey ~= "" and typeof(record) == "table" then
			local highscore = clampInt(record.highscore or record.kills or record.killHighscore)
			local speedrun = tonumber(record.speedrun or record.bestTime or record.bestSeconds or record.fastestClear)
			if speedrun and speedrun <= 0 then speedrun = nil end
			if highscore > 0 or speedrun then out[levelKey] = { highscore = highscore, speedrun = speedrun } end
		end
	end
	return out
end

function Schema.SanitizeCodex(raw)
	local out = defaultCodexData()
	if typeof(raw) ~= "table" then return out end
	local discovered = typeof(raw.Discovered) == "table" and raw.Discovered or raw.discovered
	local seen = typeof(raw.Seen) == "table" and raw.Seen or raw.seen
	for _, category in ipairs(Schema.CODEX_CATEGORIES) do
		out.Discovered[category] = sanitizeBoolMap(typeof(discovered) == "table" and discovered[category] or nil)
		out.Seen[category] = sanitizeBoolMap(typeof(seen) == "table" and seen[category] or nil)
	end
	return out
end

local function sanitizeEvents(raw)
	local out = defaultEventsData()
	local progress = typeof(raw) == "table" and raw.Progress or nil
	if typeof(progress) ~= "table" then return out end
	for eventId, state in pairs(progress) do
		if typeof(eventId) == "string" and eventId ~= "" and typeof(state) == "table" then
			out.Progress[eventId] = {
				Stats = sanitizeCountMap(state.Stats),
				ClaimedTasks = sanitizeBoolMap(state.ClaimedTasks),
				ClaimedMilestones = sanitizeBoolMap(state.ClaimedMilestones),
				ClaimedFinalRewards = state.ClaimedFinalRewards == true,
			}
		end
	end
	return out
end

local function sanitizeGuild(raw)
	local out = defaultGuildData()
	if typeof(raw) ~= "table" then return out end
	local guildId = raw.GuildId or raw.guildId
	if typeof(guildId) == "string" and guildId ~= "" then out.GuildId = guildId end
	local role = raw.Role or raw.role
	if role == "Owner" or role == "Officer" or role == "Member" then out.Role = role end
	out.JoinedAt = clampInt(raw.JoinedAt or raw.joinedAt)
	out.Contribution = clampInt(raw.Contribution or raw.contribution)
	if not out.GuildId then
		out.Role = nil
		out.JoinedAt = 0
		out.Contribution = 0
	end
	return out
end

local function sanitizeMissions(raw)
	local out = defaultMissionsData()
	if typeof(raw) ~= "table" then return out end
	out.DailyKey = tonumber(raw.DailyKey) or 0
	out.WeeklyKey = tonumber(raw.WeeklyKey) or 0
	out.SelectedDaily = Schema.SanitizeStringList(raw.SelectedDaily)
	out.SelectedWeekly = Schema.SanitizeStringList(raw.SelectedWeekly)
	out.ClaimCounts = sanitizeCountMap(raw.ClaimCounts)
	out.CountersDaily = sanitizeCountMap(raw.CountersDaily)
	out.CountersWeekly = sanitizeCountMap(raw.CountersWeekly)
	out.WeeklyWeaponRuns = sanitizeCountMap(raw.WeeklyWeaponRuns)
	out.WeeklyWinStreak = clampInt(raw.WeeklyWinStreak)
	return out
end

function Schema.Sanitize(raw)
	local data = Schema.Default()
	if typeof(raw) == "table" then
		for key, value in pairs(raw) do data[key] = value end
	end

	if typeof(raw) == "table" and raw.silver == nil and raw.coins ~= nil then
		data.silver = tonumber(raw.coins) or 0
	end
	data.coins = nil
	data.level = math.max(1, clampInt(data.level, 1))
	data.xp = clampInt(data.xp)
	data.nextXp = math.max(50, clampInt(data.nextXp, 120))
	data.silver = clampInt(data.silver)
	data.souls = clampInt(data.souls)
	data.weaponPoints = clampInt(data.weaponPoints)
	data.tickets = clampInt(data.tickets)
	data.upgradePoints = clampInt(data.upgradePoints)

	if typeof(data.upgrades) ~= "table" then data.upgrades = {} end
	data.upgrades.dmg = clampInt(data.upgrades.dmg)
	data.upgrades.speed = clampInt(data.upgrades.speed)
	data.upgrades.jump = clampInt(data.upgrades.jump)

	data.damage = math.max(0, tonumber(data.damage) or 0)
	data.fireChance = math.clamp(tonumber(data.fireChance) or 0, 0, 0.9)
	data.fireDps = clampInt(data.fireDps)
	data.multiShot = math.clamp(clampInt(data.multiShot), 0, 6)
	data.ricochet = math.clamp(clampInt(data.ricochet), 0, 4)
	data.attackSpeed = math.clamp(tonumber(data.attackSpeed) or 1, 0.6, 2)
	data.critChance = math.clamp(tonumber(data.critChance) or 0, 0, 0.6)
	data.critMult = tonumber(data.critMult) or 0
	data.damageBonusPct = math.max(0, tonumber(data.damageBonusPct) or 0)
	data.lifesteal = math.clamp(tonumber(data.lifesteal) or 0, 0, 0.12)

	data.baseHP = math.max(1, clampInt(data.baseHP))
	data.baseSpeed = math.clamp(tonumber(data.baseSpeed) or 1, 0.5, 2)
	data.baseCritRate = math.clamp(tonumber(data.baseCritRate) or 0.05, 0, 0.6)
	data.baseCritDmg = math.max(1, tonumber(data.baseCritDmg) or 1.5)
	data.baseDefense = math.max(0, tonumber(data.baseDefense) or 0)
	data.baseLifesteal = math.clamp(tonumber(data.baseLifesteal) or 0, 0, 0.12)

	for _, key in ipairs({
		"rangeBonus", "battleFocusBonus", "momentumBonus", "riposteBonus", "staggerDuration",
		"executeBonus", "overchargeBonus", "sweepBonus", "thrustBonus", "slamRadiusBonus",
		"aftershockMultiplier", "eagleEyeBonus", "quickDrawBonus", "elementalPowerBonus",
		"arcaneOverflowHeal", "deadeyeDelay",
	}) do
		data[key] = math.max(0, tonumber(data[key]) or 0)
	end
	for _, key in ipairs({ "cleaveBonus", "bladeDanceEvery", "pierceBonus", "arrowPierce", "manaSurgeEvery" }) do
		data[key] = clampInt(data[key])
	end
	data.parryReduction = math.clamp(tonumber(data.parryReduction) or 0, 0, 0.6)

	data.unlockBow = data.unlockBow ~= false
	data.unlockWand = data.unlockWand ~= false
	if typeof(data.Weapons) ~= "table" then data.Weapons = {} end
	if typeof(data.Pity) ~= "table" then data.Pity = {} end
	if typeof(data.Loadout) ~= "table" then data.Loadout = {} end
	if typeof(data.spellsUnlocked) ~= "table" then data.spellsUnlocked = {} end
	data.tutorialCompleted = data.tutorialCompleted == true
	data.spellbookUnlocked = data.spellbookUnlocked == true
	data.spellLoadout = Schema.SanitizeStringList(data.spellLoadout)
	data.spellLoadoutConfigured = data.spellLoadoutConfigured == true
	data.Codex = Schema.SanitizeCodex(data.Codex)
	data.levelRecords = Schema.SanitizeLevelRecords(data.levelRecords)

	if typeof(data.crafting) ~= "table" then data.crafting = defaultCraftingData() end
	data.crafting.recipes = sanitizeRecipes(data.crafting.recipes)
	data.crafting.mineResources = sanitizeCountMap(data.crafting.mineResources)
	data.crafting.mobMaterials = sanitizeCountMap(data.crafting.mobMaterials)
	data.crafting.upgradeMaterials = sanitizeCountMap(data.crafting.upgradeMaterials)
	data.crafting.miningSession = sanitizeMiningSession(data.crafting.miningSession)
	data.Missions = sanitizeMissions(data.Missions)
	data.DailyLogin = typeof(data.DailyLogin) == "table" and data.DailyLogin or defaultDailyLoginData()
	data.DailyLogin.LastClaimDayUTC = clampInt(data.DailyLogin.LastClaimDayUTC or data.DailyLogin.lastClaimDayUTC)
	data.DailyLogin.CurrentDay = math.clamp(clampInt(data.DailyLogin.CurrentDay or data.DailyLogin.currentDay, 1), 1, 7)
	data.DailyLogin.TotalClaims = clampInt(data.DailyLogin.TotalClaims or data.DailyLogin.totalClaims)
	data.Events = sanitizeEvents(data.Events)
	data.Guild = sanitizeGuild(data.Guild)
	return data
end

return Schema
