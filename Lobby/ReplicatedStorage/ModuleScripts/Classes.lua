-- MODULE: Classes.lua
-- GDZIE: ReplicatedStorage/Classes.lua (ModuleScript)
-- CO: 5 klas + bazowe staty startowe + krótki opis roli

local Classes = {}

-- Staty bazowe startowe (lvl 1). Później rozbudujesz o growth per level.
Classes.Defs = {
	Warrior = {
		desc = "Melee tank/bruiser",
		baseStats = {Level = 1, XP = 0, HP = 140, Mana = 25, STR = 10, DEX = 4, INT = 2, Armor = 4, CritChance = 2, CritDmg = 0, MoveSpeed = 0, AttackSpeed = 0},
	},
	Mage = {
		desc = "Caster DPS",
		baseStats = {Level = 1, XP = 0, HP = 90, Mana = 95, STR = 2, DEX = 4, INT = 12, Armor = 1, CritChance = 2, CritDmg = 0, CDR = 5, MagicPower = 5},
	},
	Rogue = {
		desc = "Crit/Speed assassin",
		baseStats = {Level = 1, XP = 0, HP = 105, Mana = 35, STR = 5, DEX = 12, INT = 3, Armor = 2, CritChance = 6, CritDmg = 10, MoveSpeed = 4, AttackSpeed = 4},
	},
	Ranger = {
		desc = "Ranged sustained DPS",
		baseStats = {Level = 1, XP = 0, HP = 110, Mana = 40, STR = 6, DEX = 10, INT = 3, Armor = 2, CritChance = 4, CritDmg = 5, AttackSpeed = 6, MoveSpeed = 2},
	},
	Cleric = {
		desc = "Support/heal + holy magic",
		baseStats = {Level = 1, XP = 0, HP = 115, Mana = 70, STR = 3, DEX = 3, INT = 9, Armor = 3, CDR = 6, MagicPower = 3},
	},
}

function Classes.IsValid(className: string): boolean
	return Classes.Defs[className] ~= nil
end

function Classes.GetBaseStats(className: string): {[string]: number}
	local def = Classes.Defs[className]
	if not def then return {} end
	local copy = {}
	for k, v in pairs(def.baseStats) do
		copy[k] = v
	end
	return copy
end

function Classes.GetAllNames(): {string}
	local t = {}
	for name in pairs(Classes.Defs) do
		table.insert(t, name)
	end
	table.sort(t)
	return t
end

return Classes
