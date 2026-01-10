-- MODULE: Items.lua
-- GDZIE: ReplicatedStorage/ModuleScripts/Items.lua
-- CO: Trzymamy tu definicje "klas" i ich bazowe staty (zamiast osobnego Modulescriptu Classes).

local Items = {}

local CLASSES = {
	Warrior = {
		DisplayName = "Warrior",
		Desc = "High HP and Armor. Good melee baseline.",
		BaseStats = {
			HP = 130,
			Mana = 20,
			STR = 8,
			DEX = 4,
			INT = 2,
			Armor = 8,
			CritChance = 3,
			CritDmg = 25,
			MoveSpeed = 16,
			AttackSpeed = 1.00,
			LifeSteal = 0,
			CDR = 0,
			MagicPower = 0,
			PhysicalPower = 6,
		},
	},

	Mage = {
		DisplayName = "Mage",
		Desc = "High Mana and INT. Strong magic scaling.",
		BaseStats = {
			HP = 90,
			Mana = 60,
			STR = 2,
			DEX = 4,
			INT = 9,
			Armor = 2,
			CritChance = 4,
			CritDmg = 30,
			MoveSpeed = 16,
			AttackSpeed = 1.00,
			LifeSteal = 0,
			CDR = 4,
			MagicPower = 8,
			PhysicalPower = 0,
		},
	},

	Rogue = {
		DisplayName = "Rogue",
		Desc = "Fast, high crit. Glassier than Warrior.",
		BaseStats = {
			HP = 100,
			Mana = 25,
			STR = 4,
			DEX = 9,
			INT = 2,
			Armor = 3,
			CritChance = 7,
			CritDmg = 40,
			MoveSpeed = 17,
			AttackSpeed = 1.10,
			LifeSteal = 0,
			CDR = 1,
			MagicPower = 0,
			PhysicalPower = 5,
		},
	},

	Ranger = {
		DisplayName = "Ranger",
		Desc = "Ranged DPS. Balanced DEX + crit.",
		BaseStats = {
			HP = 105,
			Mana = 25,
			STR = 3,
			DEX = 8,
			INT = 3,
			Armor = 3,
			CritChance = 6,
			CritDmg = 35,
			MoveSpeed = 16,
			AttackSpeed = 1.05,
			LifeSteal = 0,
			CDR = 1,
			MagicPower = 0,
			PhysicalPower = 5,
		},
	},

	Cleric = {
		DisplayName = "Cleric",
		Desc = "Tankier support-mage hybrid. Good CDR/Mana.",
		BaseStats = {
			HP = 115,
			Mana = 45,
			STR = 3,
			DEX = 3,
			INT = 6,
			Armor = 5,
			CritChance = 3,
			CritDmg = 25,
			MoveSpeed = 16,
			AttackSpeed = 1.00,
			LifeSteal = 0,
			CDR = 3,
			MagicPower = 5,
			PhysicalPower = 2,
		},
	},
}

local function deepCopy(t)
	local out = {}
	for k, v in pairs(t) do
		if typeof(v) == "table" then
			out[k] = deepCopy(v)
		else
			out[k] = v
		end
	end
	return out
end

function Items.IsValidClass(className: string): boolean
	return typeof(className) == "string" and CLASSES[className] ~= nil
end

function Items.GetDefaultClass(): string
	return "Warrior"
end

function Items.GetAllClasses()
	local list = {}
	for name, def in pairs(CLASSES) do
		table.insert(list, {
			Name = name,
			DisplayName = def.DisplayName,
			Desc = def.Desc,
		})
	end
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end

function Items.GetBaseStats(className: string)
	local def = CLASSES[className]
	if not def then
		def = CLASSES[Items.GetDefaultClass()]
	end
	return deepCopy(def.BaseStats)
end

return Items
