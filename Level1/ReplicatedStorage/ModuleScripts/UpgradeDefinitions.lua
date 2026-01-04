-- UpgradeDefinitions.lua (ReplicatedStorage)

local UpDefs = {}

local RARITIES = {
	{ name = "Common", weight = 60, mult = 1.0, color = Color3.fromRGB(200, 200, 200) },
	{ name = "Rare", weight = 25, mult = 1.4, color = Color3.fromRGB(96, 165, 250) },
	{ name = "Epic", weight = 12, mult = 2.0, color = Color3.fromRGB(168, 85, 247) },
	{ name = "Legendary", weight = 3, mult = 2.6, color = Color3.fromRGB(245, 158, 11) },
}

local function hasWeaponType(entry, weaponType: string)
	local wTypes = entry.weaponTypes
	if not wTypes or wTypes == "ALL" then
		return true
	end
	if typeof(wTypes) == "string" then
		return wTypes == weaponType
	end
	for _, wType in ipairs(wTypes) do
		if wType == weaponType then
			return true
		end
	end
	return false
end

UpDefs.POOL = {
	-- Global buffs
	{ id = "SHARPENED_EDGE", name = "Sharpened Edge", desc = "+%d%% ATK", stat = "damageBonusPct", base = 8, mode = "percent", applyScale = 0.01, weaponTypes = "ALL" },
	{ id = "RAPID_STRIKES", name = "Rapid Strikes", desc = "+%d%% attack speed", stat = "attackSpeed", base = 6, mode = "percent", applyScale = 0.01, weaponTypes = "ALL" },
	{ id = "KILLER_INSTINCT", name = "Killer Instinct", desc = "+%d%% Crit Rate", stat = "critChance", base = 4, mode = "percent", applyScale = 0.01, weaponTypes = "ALL" },
	{ id = "EXECUTIONER", name = "Executioner", desc = "+%d%% Crit DMG", stat = "critMult", base = 10, mode = "percent", applyScale = 0.01, weaponTypes = "ALL" },
	{ id = "BLOODTHIRST", name = "Bloodthirst", desc = "+%d%% Lifesteal", stat = "lifesteal", base = 2, mode = "percent", applyScale = 0.01, weaponTypes = "ALL" },
	{ id = "BATTLE_FOCUS", name = "Battle Focus", desc = "On kill: +%d%% damage (short) ", stat = "battleFocusBonus", base = 12, mode = "percent", applyScale = 0.01, weaponTypes = "ALL" },
	{ id = "REACH", name = "Reach", desc = "+%.1f range", stat = "rangeBonus", base = 0.5, mode = "flat", applyScale = 1, weaponTypes = "ALL" },
	{ id = "MOMENTUM", name = "Momentum", desc = "+%d%% damage per hit (stacking)", stat = "momentumBonus", base = 4, mode = "percent", applyScale = 0.01, weaponTypes = "ALL" },

	-- Sword buffs
	{ id = "CLEAVE_MASTERY", name = "Cleave Mastery", desc = "Cleave hits +%d enemy", stat = "cleaveBonus", base = 1, mode = "count", applyScale = 1, weaponTypes = { "Sword" } },
	{ id = "RIPOSTE", name = "Riposte", desc = "After taking damage, next hit +%d%% dmg", stat = "riposteBonus", base = 12, mode = "percent", applyScale = 0.01, weaponTypes = { "Sword" } },
	{ id = "BLADE_DANCE", name = "Blade Dance", desc = "Every %d hits: extra free swing", stat = "bladeDanceEvery", base = 6, mode = "count", applyScale = 1, weaponTypes = { "Sword" } },
	{ id = "PARRY_WINDOW", name = "Parry Window", desc = "After attack: %d%% damage reduction", stat = "parryReduction", base = 15, mode = "percent", applyScale = 0.01, weaponTypes = { "Sword" } },

	-- Claymore buffs
	{ id = "HEAVY_SWING", name = "Heavy Swing", desc = "+%d%% damage, -%d%% attack speed", stat = "damageBonusPct", base = 12, mode = "percent", applyScale = 0.01, weaponTypes = { "Claymore" }, secondaryStat = "attackSpeed", secondaryScale = -0.01 },
	{ id = "CRUSHING_BLOWS", name = "Crushing Blows", desc = "Stagger enemies for %.2fs", stat = "staggerDuration", base = 0.35, mode = "flat", applyScale = 1, weaponTypes = { "Claymore" } },
	{ id = "EXECUTION_THRESHOLD", name = "Execution Threshold", desc = "+%d%% dmg vs low HP", stat = "executeBonus", base = 20, mode = "percent", applyScale = 0.01, weaponTypes = { "Claymore" } },
	{ id = "OVERCHARGE", name = "Overcharge", desc = "Hold attack: +%d%% dmg & AoE (cap)", stat = "overchargeBonus", base = 15, mode = "percent", applyScale = 0.01, weaponTypes = { "Claymore" } },

	-- Scythe buffs
	{ id = "DEEP_BLEED", name = "Deep Bleed", desc = "Bleed damage +%d%%", stat = "bleedBonus", base = 20, mode = "percent", applyScale = 0.01, weaponTypes = { "Scythe" } },
	{ id = "HARVEST", name = "Harvest", desc = "Killing bleeding enemies heals +%d%%", stat = "harvestBonus", base = 2, mode = "percent", applyScale = 0.01, weaponTypes = { "Scythe" } },
	{ id = "WIDE_SWEEP", name = "Wide Sweep", desc = "+%d° sweep", stat = "sweepBonus", base = 20, mode = "flat", applyScale = 1, weaponTypes = { "Scythe" } },
	{ id = "SOUL_REAP", name = "Soul Reap", desc = "Multi-kill grants +%d%% damage", stat = "soulReapBonus", base = 12, mode = "percent", applyScale = 0.01, weaponTypes = { "Scythe" } },

	-- Halberd buffs
	{ id = "EXTENDED_THRUST", name = "Extended Thrust", desc = "+%.1f line length", stat = "thrustBonus", base = 1.0, mode = "flat", applyScale = 1, weaponTypes = { "Halberd" } },
	{ id = "PIERCING_LINE", name = "Piercing Line", desc = "+%d pierced enemy", stat = "pierceBonus", base = 1, mode = "count", applyScale = 1, weaponTypes = { "Halberd" } },
	{ id = "DISARM", name = "Disarm", desc = "Hit enemies deal %d%% less damage", stat = "disarmBonus", base = 15, mode = "percent", applyScale = 0.01, weaponTypes = { "Halberd" } },
	{ id = "FORMATION_BREAKER", name = "Formation Breaker", desc = "+%d%% dmg vs elites/bosses", stat = "formationBonus", base = 15, mode = "percent", applyScale = 0.01, weaponTypes = { "Halberd" } },

	-- Greataxe buffs
	{ id = "EARTHSHATTER", name = "Earthshatter", desc = "+%.1f slam radius", stat = "slamRadiusBonus", base = 1.2, mode = "flat", applyScale = 1, weaponTypes = { "Greataxe" } },
	{ id = "AFTERSHOCK", name = "Aftershock", desc = "Secondary AoE: %.0f%% dmg", stat = "aftershockMultiplier", base = 60, mode = "percent", applyScale = 0.01, weaponTypes = { "Greataxe" } },
	{ id = "BONE_CRUSHER", name = "Bone Crusher", desc = "Chance to reduce enemy DEF", stat = "boneCrusher", base = 20, mode = "percent", applyScale = 0.01, weaponTypes = { "Greataxe" } },
	{ id = "MOMENTUM_SLAM", name = "Momentum Slam", desc = "Moving before attack: +%d%% dmg", stat = "momentumSlamBonus", base = 15, mode = "percent", applyScale = 0.01, weaponTypes = { "Greataxe" } },

	-- Bow buffs
	{ id = "MULTISHOT", name = "Multishot", desc = "+%d arrow", stat = "multiShot", base = 1, mode = "count", applyScale = 1, weaponTypes = { "Bow" } },
	{ id = "SPLIT_ARROW", name = "Split Arrow", desc = "Arrows split on hit", stat = "splitArrow", base = 1, mode = "count", applyScale = 1, weaponTypes = { "Bow" } },
	{ id = "EAGLE_EYE", name = "Eagle Eye", desc = "+%d%% crit per 10 studs", stat = "eagleEyeBonus", base = 4, mode = "percent", applyScale = 0.01, weaponTypes = { "Bow" } },
	{ id = "QUICK_DRAW", name = "Quick Draw", desc = "After crit: +%d%% attack speed", stat = "quickDrawBonus", base = 6, mode = "percent", applyScale = 0.01, weaponTypes = { "Bow" } },
	{ id = "PIERCING_ARROW", name = "Piercing Arrow", desc = "Arrows pierce +%d", stat = "arrowPierce", base = 1, mode = "count", applyScale = 1, weaponTypes = { "Bow" } },

	-- Staff buffs
	{ id = "ELEMENTAL_POWER", name = "Elemental Power", desc = "+%d%% status dmg", stat = "elementalPowerBonus", base = 12, mode = "percent", applyScale = 0.01, weaponTypes = { "Staff" } },
	{ id = "CHAIN_MAGIC", name = "Chain Magic", desc = "Spells jump +%d", stat = "chainMagic", base = 1, mode = "count", applyScale = 1, weaponTypes = { "Staff" } },
	{ id = "ARCANE_OVERFLOW", name = "Arcane Overflow", desc = "Casting heals +%d", stat = "arcaneOverflowHeal", base = 3, mode = "flat", applyScale = 1, weaponTypes = { "Staff" } },
	{ id = "ELEMENTAL_MASTERY", name = "Elemental Mastery", desc = "+%d%% status chance", stat = "fireChance", base = 4, mode = "percent", applyScale = 0.01, weaponTypes = { "Staff" } },
	{ id = "MANA_SURGE", name = "Mana Surge", desc = "Every %d casts: empowered", stat = "manaSurgeEvery", base = 6, mode = "count", applyScale = 1, weaponTypes = { "Staff" } },

	-- Pistol buffs
	{ id = "DEADEYE", name = "Deadeye", desc = "After %.1fs no shots: guaranteed crit", stat = "deadeyeDelay", base = 2.5, mode = "flat", applyScale = 1, weaponTypes = { "Pistol" } },
	{ id = "ARMOR_PIERCING", name = "Armor Piercing Rounds", desc = "Ignore %d%% DEF", stat = "armorPiercing", base = 20, mode = "percent", applyScale = 0.01, weaponTypes = { "Pistol" } },
	{ id = "QUICK_RELOAD", name = "Quick Reload", desc = "+%d%% fire rate", stat = "attackSpeed", base = 6, mode = "percent", applyScale = 0.01, weaponTypes = { "Pistol" } },
	{ id = "EXECUTION_SHOT", name = "Execution Shot", desc = "+%d%% dmg vs low HP", stat = "executeBonus", base = 20, mode = "percent", applyScale = 0.01, weaponTypes = { "Pistol" } },
	{ id = "RICOCHET", name = "Ricochet", desc = "Bullets bounce +%d", stat = "ricochet", base = 1, mode = "count", applyScale = 1, weaponTypes = { "Pistol" } },
}

function UpDefs.RollRarity()
	local total = 0
	for _, entry in ipairs(RARITIES) do
		total += entry.weight
	end
	local roll = math.random() * total
	local acc = 0
	for _, entry in ipairs(RARITIES) do
		acc += entry.weight
		if roll <= acc then
			return entry.name, entry.color, entry.mult
		end
	end
	local fallback = RARITIES[1]
	return fallback.name, fallback.color, fallback.mult
end

function UpDefs.GetPool(weaponType: string?)
	local wType = weaponType or ""
	local pool = {}
	for _, entry in ipairs(UpDefs.POOL) do
		if hasWeaponType(entry, wType) then
			table.insert(pool, entry)
		end
	end
	return pool
end

return UpDefs
