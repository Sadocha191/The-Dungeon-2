-- WeaponConfigs.lua (ReplicatedStorage)
-- Global weapon metadata used by UI and server equip logic.

local WeaponConfigs = {}

local defs: {[string]: any} = {}
local list = {}

local function add(def)
	defs[def.id] = def
	table.insert(list, def)
end

add({
	id = "Sword",
	name = "Sword",
	weaponType = "Sword",
	rarity = "Common",
	maxLevel = 20,
	baseDamage = 18,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 3,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 2,
	},
	combat = {
		baseAtk = 18,
		atkPerLevel = 2,
		bonusCritRate = 0.03,
		bonusDefense = 2,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Scythe",
	name = "Scythe",
	weaponType = "Scythe",
	rarity = "Common",
	maxLevel = 20,
	baseDamage = 22,
	stats = {
		HP = 40,
		SPD = 0,
		CRIT_RATE = 0,
		CRIT_DMG = 0,
		LIFESTEAL = 2,
		DEF = 0,
	},
	combat = {
		baseAtk = 22,
		atkPerLevel = 2.4,
		bonusHP = 40,
		bonusLifesteal = 0.02,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Halberd",
	name = "Halberd",
	weaponType = "Halberd",
	rarity = "Common",
	maxLevel = 20,
	baseDamage = 20,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 0,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 3,
	},
	combat = {
		baseAtk = 20,
		atkPerLevel = 2.2,
		bonusDefense = 3,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Bow",
	name = "Bow",
	weaponType = "Bow",
	rarity = "Common",
	maxLevel = 20,
	baseDamage = 16,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 5,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 16,
		atkPerLevel = 1.8,
		bonusCritRate = 0.05,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Staff",
	name = "Staff",
	weaponType = "Staff",
	rarity = "Common",
	maxLevel = 20,
	baseDamage = 17,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 0,
		CRIT_DMG = 10,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 17,
		atkPerLevel = 2.0,
		bonusCritDmg = 0.1,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Wand",
	name = "Wand",
	weaponType = "Staff",
	rarity = "Common",
	maxLevel = 20,
	baseDamage = 17,
	stats = {
		HP = 0,
		SPD = 0,
		CRIT_RATE = 0,
		CRIT_DMG = 10,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 17,
		atkPerLevel = 2.0,
		bonusCritDmg = 0.1,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "",
	abilityDescription = "",
})

add({
	id = "Pistol",
	name = "Pistol",
	weaponType = "Pistol",
	rarity = "Common",
	maxLevel = 20,
	baseDamage = 15,
	stats = {
		HP = 0,
		SPD = 3,
		CRIT_RATE = 4,
		CRIT_DMG = 0,
		LIFESTEAL = 0,
		DEF = 0,
	},
	combat = {
		baseAtk = 15,
		atkPerLevel = 1.6,
		bonusCritRate = 0.04,
		bonusSpeed = 0.03,
	},
	passiveName = "",
	passiveDescription = "",
	abilityName = "",
	abilityDescription = "",
})

function WeaponConfigs.Get(id: string)
	return defs[id]
end

function WeaponConfigs.GetAll()
	return list
end

WeaponConfigs.Defs = defs
WeaponConfigs.List = list

return WeaponConfigs
