-- WeaponConfigs.lua (ReplicatedStorage)
-- Global weapon metadata used by UI and server equip logic.

local WeaponConfigs = {}

local defs: {[string]: any} = {}
local list = {}

local RARITY_COLORS = {
	Common = "#B0B0B0",
	Uncommon = "#5C9C62",
	Rare = "#4DA6FF",
	Epic = "#B266FF",
	Legendary = "#FF9F1A",
	Mythic = "#FF3B3B",
	Mythical = "#FF3B3B",
}

local RARITY_ATK_PER_LEVEL = {
	Common = 0.08,
	Uncommon = 0.09,
	Rare = 0.10,
	Epic = 0.12,
	Legendary = 0.14,
	Mythic = 0.16,
	Mythical = 0.16,
}

local function add(def)
	def.rarityColor = def.rarityColor or RARITY_COLORS[def.rarity]
	def.combat = def.combat or {}
	if def.combat.atkPerLevel == nil then
		local scaling = RARITY_ATK_PER_LEVEL[def.rarity] or 0.08
		local baseAtk = def.combat.baseAtk or def.baseDamage or 0
		def.combat.atkPerLevel = baseAtk * scaling
	end
	defs[def.id] = def
	table.insert(list, def)
end

add({
	id = "Knight's Oath",
	name = "Knight's Oath",
	weaponType = "Sword",
	rarity = "Common",
	element = "Physical",
	maxLevel = 20,
	baseDamage = 11,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 0,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 8,
	},
	combat = {
		baseAtk = 11,
		attackCooldown = 0.56,
		range = 10,
		cleaveTargets = 2,
		cleaveRadius = 6,
		cleaveFalloff = 0.55,
		bonusDefense = 8,
	},
	description = "A reliable knightly blade carried by oathbound guards of the old kingdoms. Simple, balanced, and built for steady combat rather than flashy strikes.",
	passiveName = "Light Cleave",
	passiveDescription = "Basic attacks cleave 1 nearby enemy.\nSecondary hit deals 55% damage.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Excalion, Blade of Kings",
	name = "Excalion, Blade of Kings",
	weaponType = "Sword",
	rarity = "Legendary",
	element = "Light",
	maxLevel = 80,
	baseDamage = 15,
	stats = {
		HP = 120,
		SPD = 0,
		CRIT_RATE = 10,
		CRIT_DMG = 45,
		LIFESTEAL = 0,
		DEF = 18,
	},
	combat = {
		baseAtk = 15,
		attackCooldown = 0.52,
		range = 10.5,
		cleaveTargets = 3,
		cleaveRadius = 6.8,
		cleaveFalloff = 0.62,
		shockwaveEvery = 5,
		shockwaveMultiplier = 1.10,
		shockwaveRadius = 8.0,
		shockwaveMaxTargets = 6,
		bonusHP = 120,
		bonusCritRate = 0.10,
		bonusCritDmg = 0.45,
		bonusDefense = 18,
	},
	description = "A legendary royal blade said to answer only to those worthy of command. Its edge carries a golden light that cuts through darkness and fear.",
	passiveName = "",
	passiveDescription = "",
	abilityName = "Royal Shockwave",
	abilityDescription = "Every 5th hit releases a shockwave.\nShockwave deals 110% ATK in a wide AoE.",
})

add({
	id = "Reaper's Crescent",
	name = "Reaper's Crescent",
	weaponType = "Scythe",
	rarity = "Epic",
	element = "Void",
	maxLevel = 60,
	baseDamage = 17,
	stats = {
		HP = 90,
		SPD = 4,
		CRIT_RATE = 0,
		CRIT_DMG = 0,
		LIFESTEAL = 3,
		DEF = 0,
	},
	combat = {
		baseAtk = 17,
		attackCooldown = 0.82,
		range = 11,
		aoeRadius = 7.2,
		aoeMaxTargets = 6,
		aoeFalloff = 0.72,
		bleedDpsMultiplier = 0.14,
		bleedDuration = 2.8,
		bleedMaxStacks = 3,
		healOnKillPct = 0.02,
		bonusHP = 90,
		bonusSpeed = 0.04,
		bonusLifesteal = 0.03,
	},
	description = "A cursed scythe forged from blackened steel and the bones of forgotten dead. Its crescent blade feeds on fading souls, turning every kill into stolen strength.",
	passiveName = "Bleed on Hit",
	passiveDescription = "Hits bleed nearby enemies for 2.8s.\nBleed stacks up to 3 and scales with ATK.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Harvest of the End",
	name = "Harvest of the End",
	weaponType = "Scythe",
	rarity = "Legendary",
	element = "Void",
	maxLevel = 80,
	baseDamage = 20,
	stats = {
		HP = 140,
		SPD = 0,
		CRIT_RATE = 8,
		CRIT_DMG = 55,
		LIFESTEAL = 5,
		DEF = 0,
	},
	combat = {
		baseAtk = 20,
		attackCooldown = 0.78,
		range = 11.4,
		aoeRadius = 7.5,
		aoeMaxTargets = 7,
		aoeFalloff = 0.78,
		bleedDpsMultiplier = 0.16,
		bleedDuration = 3.2,
		bleedMaxStacks = 4,
		killChainPerKill = 0.04,
		killChainMaxStacks = 6,
		killChainDuration = 4.5,
		healOnKillPct = 0.03,
		bonusHP = 140,
		bonusCritRate = 0.08,
		bonusCritDmg = 0.55,
		bonusLifesteal = 0.05,
	},
	description = "An ancient scythe whispered to appear before doomed kingdoms fall. Every swing feels like the final toll of a forgotten bell.",
	passiveName = "",
	passiveDescription = "",
	abilityName = "Feast on Death",
	abilityDescription = "On kill: gain +4% damage for 4.5s.\nStacks up to 6.\nDuration refreshes on kill.",
})

add({
	id = "Warden's Halberd",
	name = "Warden's Halberd",
	weaponType = "Halberd",
	rarity = "Rare",
	element = "Earth",
	maxLevel = 40,
	baseDamage = 15,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 6,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 14,
	},
	combat = {
		baseAtk = 15,
		attackCooldown = 0.80,
		range = 13.5,
		pierceTargets = 3,
		lineWidth = 3.3,
		eliteDamageBonus = 0.12,
		bonusDefense = 14,
		bonusCritRate = 0.06,
	},
	description = "A heavy polearm once used by gate wardens to hold back monsters at the walls. Its wide swings are made to control space and keep enemies away.",
	passiveName = "Pierce",
	passiveDescription = "Attacks pierce up to 3 enemies in a straight line.\nDeals bonus damage to elites and bosses.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Dragonspear Halberd",
	name = "Dragonspear Halberd",
	weaponType = "Halberd",
	rarity = "Epic",
	element = "Fire",
	maxLevel = 60,
	baseDamage = 18,
	stats = {
		HP = 80,
		SPD = 0,
		CRIT_RATE = 0,
		CRIT_DMG = 35,
		LIFESTEAL = 0,
		DEF = 18,
	},
	combat = {
		baseAtk = 18,
		attackCooldown = 0.76,
		range = 14,
		pierceTargets = 4,
		lineWidth = 3.7,
		eliteDamageBonus = 0.18,
		armorBreakPct = 0.10,
		armorBreakDuration = 3.0,
		bonusHP = 80,
		bonusDefense = 18,
		bonusCritDmg = 0.35,
	},
	description = "A war-forged halberd tempered in dragonfire and carried by champions who broke siege lines. Its thrusts hit with crushing force and leave armor in ruins.",
	passiveName = "Armor Break",
	passiveDescription = "Piercing hits weaken armored targets for 3s.\nElite and boss targets take extra damage.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Hunter's Longbow",
	name = "Hunter's Longbow",
	weaponType = "Bow",
	rarity = "Common",
	element = "Air",
	maxLevel = 20,
	baseDamage = 11,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 5,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 11,
		attackCooldown = 0.70,
		range = 72,
		focusEvery = 3,
		focusMultiplier = 1.22,
		bonusCritRate = 0.05,
	},
	description = "A worn longbow used by forest hunters who learned to strike before danger could get close. Its arrows are light, fast, and deadly from a distance.",
	passiveName = "Steady Aim",
	passiveDescription = "Every 3rd shot is a focused arrow.\nFocused arrows deal 22% bonus damage.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Stormwind Recurve",
	name = "Stormwind Recurve",
	weaponType = "Bow",
	rarity = "Epic",
	element = "Air",
	maxLevel = 60,
	baseDamage = 13,
	stats = {
		HP = 0,
		SPD = 6,
		CRIT_RATE = 10,
		CRIT_DMG = 35,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 13,
		attackCooldown = 0.66,
		range = 74,
		focusEvery = 3,
		focusMultiplier = 1.28,
		splitChance = 0.28,
		splitCount = 2,
		splitDamageMultiplier = 0.45,
		splitRadius = 14,
		bonusSpeed = 0.06,
		bonusCritRate = 0.10,
		bonusCritDmg = 0.35,
	},
	description = "A recurved bow shaped for storm-chasers and skirmishers of the high cliffs. Its arrows ride the wind with uncanny speed before splitting into lethal follow-up shots.",
	passiveName = "Split Shot",
	passiveDescription = "28% chance for arrows to split into 2.\nSecondary arrows seek nearby enemies for 45% damage.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Apprentice Arcstaff",
	name = "Apprentice Arcstaff",
	weaponType = "Staff",
	rarity = "Rare",
	element = "Electricity",
	maxLevel = 40,
	baseDamage = 10,
	stats = {
		HP = 70,
		SPD = 0,
		CRIT_RATE = 7,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 10,
		attackCooldown = 0.74,
		range = 52,
		arcChargeEvery = 4,
		arcChargeMultiplier = 0.55,
		arcChainCount = 1,
		arcChainRadius = 15,
		arcChainMultiplier = 0.30,
		spellDamageBonus = 0.16,
		spellCooldownBonus = 0.06,
		bonusHP = 70,
		bonusCritRate = 0.07,
	},
	description = "A training staff once used in arcane halls where students learned to shape unstable lightning. It hums with restrained power, eager to leap from target to target.",
	passiveName = "Arc Charge",
	passiveDescription = "Every 4th hit bursts for +55% ATK magic damage.\nChains to 1 nearby enemy for 30% damage.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Archmage's Worldstaff",
	name = "Archmage's Worldstaff",
	weaponType = "Staff",
	rarity = "Mythical",
	element = "Fire",
	maxLevel = 100,
	baseDamage = 13,
	stats = {
		HP = 150,
		SPD = 8,
		CRIT_RATE = 12,
		CRIT_DMG = 70,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 13,
		attackCooldown = 0.68,
		range = 54,
		arcChargeEvery = 4,
		arcChargeMultiplier = 0.65,
		arcChainCount = 2,
		arcChainRadius = 16,
		arcChainMultiplier = 0.36,
		spellDamageBonus = 0.30,
		spellCooldownBonus = 0.10,
		spellEffectBonus = 0.08,
		bonusHP = 150,
		bonusSpeed = 0.08,
		bonusCritRate = 0.12,
		bonusCritDmg = 0.70,
	},
	description = "A staff carved from starwood and sealed with ancient runes. It bends raw magic into wide, devastating arcs of elemental power.",
	passiveName = "",
	passiveDescription = "",
	abilityName = "Reality Bend",
	abilityDescription = "Empowers all spells with bonus damage, haste, and effect power.\nEvery 4th hit chains through 2 enemies.",
})

add({
	id = "Blackpowder Flintlock",
	name = "Blackpowder Flintlock",
	weaponType = "Pistol",
	rarity = "Rare",
	element = "Physical",
	maxLevel = 40,
	baseDamage = 14,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 8,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 10,
	},
	combat = {
		baseAtk = 14,
		attackCooldown = 0.50,
		range = 52,
		executionEvery = 4,
		executionBonusMultiplier = 1.20,
		eliteDamageBonus = 0.08,
		executeThreshold = 0.30,
		executeThresholdMultiplier = 1.12,
		bonusCritRate = 0.08,
		bonusDefense = 10,
	},
	description = "A smoke-stained flintlock favored by mercenaries who ended fights with a single decisive shot. Loud, brutal, and unforgiving, it rewards patience over panic.",
	passiveName = "Armor Crack",
	passiveDescription = "Every 4th shot is an execution round.\nDeals bonus damage to wounded elites and bosses.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Kingslayer Handcannon",
	name = "Kingslayer Handcannon",
	weaponType = "Pistol",
	rarity = "Legendary",
	element = "Physical",
	maxLevel = 80,
	baseDamage = 18,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 6,
		CRIT_DMG = 90,
		LIFESTEAL = 3,
		DEF = 12,
	},
	combat = {
		baseAtk = 18,
		attackCooldown = 0.52,
		range = 54,
		executionEvery = 4,
		executionBonusMultiplier = 1.25,
		executionAlwaysCrit = true,
		eliteDamageBonus = 0.12,
		executeThreshold = 0.35,
		executeThresholdMultiplier = 1.18,
		bonusCritRate = 0.06,
		bonusCritDmg = 0.90,
		bonusLifesteal = 0.03,
		bonusDefense = 12,
	},
	description = "A brutal handcannon built to shatter armor, crowns, and monsters alike. Slow to fire, but each shot lands like a royal execution.",
	passiveName = "",
	passiveDescription = "",
	abilityName = "Execution Round",
	abilityDescription = "Every 4th shot is a guaranteed crit.\nExecution rounds deal bonus damage to low-health elites and bosses.",
})

local function inferElement(name)
	local lower = string.lower(name)
	if lower:find("ember", 1, true) or lower:find("fire", 1, true) or lower:find("inferno", 1, true) or lower:find("flame", 1, true) then
		return "Fire"
	end
	if lower:find("frost", 1, true) or lower:find("glacier", 1, true) then
		return "Water"
	end
	if lower:find("storm", 1, true) or lower:find("wind", 1, true) or lower:find("feather", 1, true) then
		return "Air"
	end
	if lower:find("earth", 1, true) or lower:find("grove", 1, true) or lower:find("forest", 1, true) or lower:find("moss", 1, true) or lower:find("verdant", 1, true) or lower:find("nature", 1, true) or lower:find("thorn", 1, true) then
		return "Earth"
	end
	if lower:find("void", 1, true) or lower:find("shadow", 1, true) or lower:find("eclipse", 1, true) or lower:find("night", 1, true) then
		return "Void"
	end
	if lower:find("sun", 1, true) or lower:find("solar", 1, true) or lower:find("dawn", 1, true) or lower:find("gold", 1, true) or lower:find("royal", 1, true) or lower:find("angel", 1, true) then
		return "Light"
	end
	if lower:find("arc", 1, true) then
		return "Electric"
	end
	return "Physical"
end

local function rarityRank(rarity)
	return ({
		Common = 1,
		Uncommon = 2,
		Rare = 3,
		Epic = 4,
		Legendary = 5,
		Mythic = 6,
		Mythical = 6,
	})[rarity] or 1
end

local function generatedStats(weaponType, rarity)
	local rank = rarityRank(rarity)
	local baseByType = {
		Sword = 10,
		Scythe = 13,
		Halberd = 12,
		Bow = 9,
		Staff = 8,
		Pistol = 12,
	}
	local atk = (baseByType[weaponType] or 10) + (rank - 1) * 2
	local maxLevel = ({ 20, 30, 40, 60, 80, 100 })[rank] or 20
	local stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 0,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 0,
	}
	if weaponType == "Sword" then
		stats.DEF = 4 + rank * 3
		stats.CRIT_DMG = rank >= 4 and 20 + rank * 5 or 0
	elseif weaponType == "Scythe" then
		stats.LIFESTEAL = rank >= 3 and rank or 0
		stats.HP = rank >= 4 and rank * 20 or 0
	elseif weaponType == "Halberd" then
		stats.DEF = 6 + rank * 3
		stats.CRIT_RATE = rank >= 3 and 4 + rank or 0
	elseif weaponType == "Bow" then
		stats.CRIT_RATE = 4 + rank * 2
		stats.SPD = rank >= 3 and rank or 0
	elseif weaponType == "Staff" then
		stats.HP = rank * 18
		stats.CRIT_RATE = rank >= 3 and rank + 2 or 0
	elseif weaponType == "Pistol" then
		stats.CRIT_DMG = 12 + rank * 8
		stats.CRIT_RATE = rank >= 3 and 4 + rank or 0
	end
	return atk, maxLevel, stats
end

local function addGeneratedWeapon(name, weaponType, rarity)
	if defs[name] then
		return
	end
	local baseAtk, maxLevel, stats = generatedStats(weaponType, rarity)
	local element = inferElement(name)
	add({
		id = name,
		name = name,
		weaponType = weaponType,
		rarity = rarity,
		element = element,
		maxLevel = maxLevel,
		baseDamage = baseAtk,
		stats = stats,
		combat = {
			baseAtk = baseAtk,
			attackCooldown = ({
				Sword = 0.56,
				Scythe = 0.82,
				Halberd = 0.78,
				Bow = 0.68,
				Staff = 0.72,
				Pistol = 0.52,
			})[weaponType] or 0.65,
			range = ({
				Sword = 10,
				Scythe = 11,
				Halberd = 14,
				Bow = 72,
				Staff = 54,
				Pistol = 54,
			})[weaponType] or 10,
			bonusHP = stats.HP,
			bonusSpeed = stats.SPD / 100,
			bonusCritRate = stats.CRIT_RATE / 100,
			bonusCritDmg = stats.CRIT_DMG / 100,
			bonusLifesteal = stats.LIFESTEAL / 100,
			bonusDefense = stats.DEF,
		},
		description = string.format("A %s %s forged for hunters who survive the Four Peaks by turning scarce materials into reliable power.", string.lower(tostring(rarity)), string.lower(tostring(weaponType))),
		passiveName = string.format("%s Edge", element),
		passiveDescription = string.format("Attacks carry a %s-aspected bonus tuned for this weapon's category and rarity.", string.lower(element)),
		abilityName = "",
		abilityDescription = "",
	})
end

local generatedCatalog = {
	{ "Dawnfeather Bow", "Bow", "Uncommon" },
	{ "Emberthorn Bow", "Bow", "Rare" },
	{ "Forestbone Bow", "Bow", "Common" },
	{ "Frostbranch Bow", "Bow", "Rare" },
	{ "Mossfang Bow", "Bow", "Uncommon" },
	{ "Shadowcurve Bow", "Bow", "Epic" },
	{ "Sunpiercer", "Bow", "Legendary" },
	{ "Voidstring Bow", "Bow", "Epic" },
	{ "Earthsplitter Halberd", "Halberd", "Epic" },
	{ "Glacier Halberd", "Halberd", "Rare" },
	{ "Grovekeeper Halberd", "Halberd", "Rare" },
	{ "Infernal Halberd", "Halberd", "Epic" },
	{ "Iron Halberd", "Halberd", "Common" },
	{ "Nightfang Halberd", "Halberd", "Epic" },
	{ "Royal Halberd", "Halberd", "Legendary" },
	{ "Voidguard Halberd", "Halberd", "Epic" },
	{ "Royal Handcannon", "Pistol", "Epic" },
	{ "Rustlock Pistol", "Pistol", "Common" },
	{ "Voidlock Handcannon", "Pistol", "Epic" },
	{ "Bloodfire Scythe", "Scythe", "Epic" },
	{ "Farmer's Scythe", "Scythe", "Common" },
	{ "Frost Reaper", "Scythe", "Rare" },
	{ "Golden Crescent", "Scythe", "Legendary" },
	{ "Pale Harvest", "Scythe", "Rare" },
	{ "Plague Crescent", "Scythe", "Epic" },
	{ "Thorn Reaper", "Scythe", "Rare" },
	{ "Void Reaper", "Scythe", "Epic" },
	{ "Apprentice Staff", "Staff", "Common" },
	{ "Bonecaller Staff", "Staff", "Rare" },
	{ "Eclipse Staff", "Staff", "Epic" },
	{ "Emerald Staff", "Staff", "Rare" },
	{ "Flamecore Staff", "Staff", "Rare" },
	{ "Frostgem Wand", "Staff", "Rare" },
	{ "Inferno Warstaff", "Staff", "Epic" },
	{ "Ironwood Wand", "Staff", "Uncommon" },
	{ "Nature's Grasp Staff", "Staff", "Epic" },
	{ "Solar Mace Staff", "Staff", "Legendary" },
	{ "Void Crescent Staff", "Staff", "Epic" },
	{ "Void Crystal Staff", "Staff", "Epic" },
	{ "Dawnwarden Sword", "Sword", "Uncommon" },
	{ "Emberfang Blade", "Sword", "Rare" },
	{ "Frostbite Blade", "Sword", "Rare" },
	{ "Knights Oath", "Sword", "Common" },
	{ "Shadowthorn Sword", "Sword", "Epic" },
	{ "Verdant Saber", "Sword", "Rare" },
	{ "Voidpiercer", "Sword", "Epic" },
	{ "Windglass Blade", "Sword", "Rare" },
}

for _, entry in ipairs(generatedCatalog) do
	addGeneratedWeapon(entry[1], entry[2], entry[3])
end

function WeaponConfigs.Get(id: string)
	return defs[id]
end

function WeaponConfigs.GetAll()
	return list
end

WeaponConfigs.Defs = defs
WeaponConfigs.List = list
WeaponConfigs.RarityColors = RARITY_COLORS
WeaponConfigs.RarityAtkPerLevel = RARITY_ATK_PER_LEVEL

return WeaponConfigs
