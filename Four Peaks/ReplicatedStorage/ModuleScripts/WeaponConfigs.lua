-- WeaponConfigs.lua (ReplicatedStorage)
-- Global weapon metadata used by UI and server equip logic.

local WeaponConfigs = {}

local defs: {[string]: any} = {}
local list = {}

local RARITY_COLORS = {
	Common = "#B0B0B0",
	Rare = "#4DA6FF",
	Epic = "#B266FF",
	Legendary = "#FF9F1A",
	Mythical = "#FF3B3B",
}

local RARITY_ATK_PER_LEVEL = {
	Common = 0.08,
	Rare = 0.10,
	Epic = 0.12,
	Legendary = 0.14,
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
	passiveName = "",
	passiveDescription = "",
	abilityName = "Execution Round",
	abilityDescription = "Every 4th shot is a guaranteed crit.\nExecution rounds deal bonus damage to low-health elites and bosses.",
})

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
