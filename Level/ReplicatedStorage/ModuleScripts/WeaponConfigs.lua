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
	baseDamage = 10,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 0,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 8,
	},
	combat = {
		baseAtk = 10,
		bonusDefense = 8,
	},
	passiveName = "Light Cleave",
	passiveDescription = "Basic attacks hit up to 2 enemies in a small forward arc.\nSecondary hit deals 60% damage.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Excalion, Blade of Kings",
	name = "Excalion, Blade of Kings",
	weaponType = "Sword",
	rarity = "Legendary",
	maxLevel = 80,
	baseDamage = 16,
	stats = {
		HP = 120,
		SPD = 0,
		CRIT_RATE = 10,
		CRIT_DMG = 45,
		LIFESTEAL = 0,
		DEF = 18,
	},
	combat = {
		baseAtk = 16,
		bonusHP = 120,
		bonusCritRate = 0.10,
		bonusCritDmg = 0.45,
		bonusDefense = 18,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "Royal Shockwave",
	abilityDescription = "Every 5th hit releases a shockwave.\nShockwave deals 120% ATK as AoE damage.\nStaggers non-boss enemies.",
})

add({
	id = "Reaper's Crescent",
	name = "Reaper's Crescent",
	weaponType = "Scythe",
	rarity = "Epic",
	maxLevel = 60,
	baseDamage = 19,
	stats = {
		HP = 90,
		SPD = 4,
		CRIT_RATE = 0,
		CRIT_DMG = 0,
		LIFESTEAL = 3,
		DEF = 0,
	},
	combat = {
		baseAtk = 19,
		bonusHP = 90,
		bonusSpeed = 0.04,
		bonusLifesteal = 0.03,
	},
	passiveName = "Bleed on Hit",
	passiveDescription = "Applies Bleed for 3s, stacks up to 5.\nEach stack deals 12% ATK damage per second.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Harvest of the End",
	name = "Harvest of the End",
	weaponType = "Scythe",
	rarity = "Legendary",
	maxLevel = 80,
	baseDamage = 22,
	stats = {
		HP = 140,
		SPD = 0,
		CRIT_RATE = 8,
		CRIT_DMG = 55,
		LIFESTEAL = 5,
		DEF = 0,
	},
	combat = {
		baseAtk = 22,
		bonusHP = 140,
		bonusCritRate = 0.08,
		bonusCritDmg = 0.55,
		bonusLifesteal = 0.05,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "Feast on Death",
	abilityDescription = "On kill: gain +6% damage for 4s.\nStacks up to 10.\nDuration refreshes on kill.",
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
		bonusDefense = 14,
		bonusCritRate = 0.06,
	},
	passiveName = "Pierce",
	passiveDescription = "Attacks pierce up to 2 enemies in a straight line.",
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
		bonusHP = 80,
		bonusDefense = 18,
		bonusCritDmg = 0.35,
	},
	passiveName = "Armor Break",
	passiveDescription = "Hits reduce enemy DEF by 12% for 3s.\nBosses receive 50% reduced effect.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Hunter's Longbow",
	name = "Hunter's Longbow",
	weaponType = "Bow",
	rarity = "Common",
	maxLevel = 20,
	baseDamage = 9,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 5,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 9,
		bonusCritRate = 0.05,
	},
	passiveName = "Steady Aim",
	passiveDescription = "+20% projectile speed.\nImproved accuracy (no damage bonus).",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Stormwind Recurve",
	name = "Stormwind Recurve",
	weaponType = "Bow",
	rarity = "Epic",
	maxLevel = 60,
	baseDamage = 12,
	stats = {
		HP = 0,
		SPD = 6,
		CRIT_RATE = 10,
		CRIT_DMG = 35,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 12,
		bonusSpeed = 0.06,
		bonusCritRate = 0.10,
		bonusCritDmg = 0.35,
	},
	passiveName = "Split Shot",
	passiveDescription = "25% chance for arrows to split into 2.\nSecondary arrows seek nearby enemies.\nSecondary arrows deal 45% damage.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Apprentice Arcstaff",
	name = "Apprentice Arcstaff",
	weaponType = "Staff",
	rarity = "Rare",
	maxLevel = 40,
	baseDamage = 9,
	stats = {
		HP = 70,
		SPD = 0,
		CRIT_RATE = 7,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 9,
		bonusHP = 70,
		bonusCritRate = 0.07,
	},
	passiveName = "Arc Charge",
	passiveDescription = "Every 4th hit deals +50% ATK magic damage.\nChains to 1 nearby enemy for 30% damage.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Archmage's Worldstaff",
	name = "Archmage's Worldstaff",
	weaponType = "Staff",
	rarity = "Mythical",
	maxLevel = 100,
	baseDamage = 15,
	stats = {
		HP = 150,
		SPD = 8,
		CRIT_RATE = 12,
		CRIT_DMG = 70,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 15,
		bonusHP = 150,
		bonusSpeed = 0.08,
		bonusCritRate = 0.12,
		bonusCritDmg = 0.70,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "Reality Bend",
	abilityDescription = "Every spell gains a random elemental modifier.\nBurn / Freeze / Shock.\nBosses receive 50% reduced duration.",
})

add({
	id = "Blackpowder Flintlock",
	name = "Blackpowder Flintlock",
	weaponType = "Pistol",
	rarity = "Rare",
	maxLevel = 40,
	baseDamage = 18,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 8,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 10,
	},
	combat = {
		baseAtk = 18,
		bonusCritRate = 0.08,
		bonusDefense = 10,
	},
	passiveName = "Armor Crack",
	passiveDescription = "Hits reduce enemy DEF by 8% for 2.5s.\nBosses receive 50% reduced effect.",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Kingslayer Handcannon",
	name = "Kingslayer Handcannon",
	weaponType = "Pistol",
	rarity = "Legendary",
	maxLevel = 80,
	baseDamage = 26,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 6,
		CRIT_DMG = 90,
		LIFESTEAL = 3,
		DEF = 12,
	},
	combat = {
		baseAtk = 26,
		bonusCritRate = 0.06,
		bonusCritDmg = 0.90,
		bonusLifesteal = 0.03,
		bonusDefense = 12,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "Execution Round",
	abilityDescription = "First shot after reload (or 2s no-shot cooldown) always crits.\nThat shot deals +25% bonus damage (separate multiplier).",
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
