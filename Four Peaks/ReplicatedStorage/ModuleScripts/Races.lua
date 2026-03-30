-- MODULE: Races.lua
-- GDZIE: ReplicatedStorage/Races.lua (ModuleScript)
-- CO: System ras z tierami (Zwykłe/Rzadkie/Epickie/Legendarne/Mityczne)
--     + lepsze rasy = lepsze staty
--     + SZANSE ZALEŻNE OD KLASY (Mage częściej magiczne, Warrior częściej tank/brutal itd.)
--     + RollForClass(className) -> zwraca nazwę rasy

local Races = {}

-- Staty wspólne:
-- HP, Mana, STR, DEX, INT, Armor, CritChance, CritDmg, MoveSpeed, AttackSpeed, LifeSteal, CDR, MagicPower, PhysicalPower

Races.Tiers = {
	Common = {name = "Common",     mult = 1.00},
	Rare = {name = "Rare",      mult = 1.25},
	Epic = {name = "Epic",      mult = 1.55},
	Legendary = {name = "Legendary", mult = 1.90},
	Mythic = {name = "Mythic",  mult = 2.30},
}

-- Uwaga: "stats" są już wpisane jako docelowe (nie mnożymy ich dodatkowo automatem),
-- a "tier" to kategoria + do UI/rozszerzeń. Dzięki temu masz pełną kontrolę.

Races.Defs = {
	-- ===== ZWYKŁE =====
	Human = {
		tier = "Common",
		desc = "Balanced start.",
		roleTags = {"any"},
		stats = {HP = 10, Mana = 10, STR = 1, DEX = 1, INT = 1},
		buffs = {"Adaptation: +3% to all damage"},
	},
	Forester = {
		tier = "Common",
		desc = "Forest hunter. Mobility and accuracy.",
		roleTags = {"dex","ranged"},
		stats = {DEX = 4, MoveSpeed = 4, CritChance = 2},
		buffs = {"Tracker: +5% damage to the first target hit"},
	},
	Miner = {
		tier = "Common",
		desc = "Hard worker. Some armor and HP.",
		roleTags = {"tank","str"},
		stats = {HP = 18, Armor = 3, STR = 2},
		buffs = {"Fortitude: -2% damage taken"},
	},
	Acolyte = {
		tier = "Common",
		desc = "Magic apprentice. Mana and cooldown reduction.",
		roleTags = {"int","magic"},
		stats = {Mana = 22, INT = 3, CDR = 3},
		buffs = {"Focus: +3% Magic Power"},
	},

	-- ===== RZADKIE =====
	Elf = {
		tier = "Rare",
		desc = "High mana, strong magic.",
		roleTags = {"int","magic"},
		stats = {Mana = 40, INT = 5, CDR = 5, MagicPower = 6},
		buffs = {"Mana Scaling: +0.20% damage per 10 mana"},
	},
	Dwarf = {
		tier = "Rare",
		desc = "Defender. Armor and damage reduction.",
		roleTags = {"tank","str"},
		stats = {HP = 25, Armor = 7, STR = 3},
		buffs = {"Stone Skin: -5% damage taken"},
	},
	Goblin = {
		tier = "Rare",
		desc = "Speed and crits.",
		roleTags = {"dex"},
		stats = {DEX = 6, MoveSpeed = 6, CritChance = 4, AttackSpeed = 3},
		buffs = {"Greed: +10% coins from drops"},
	},
	Undead = {
		tier = "Rare",
		desc = "Survival through sustain.",
		roleTags = {"any"},
		stats = {HP = 18, LifeSteal = 4, Armor = 2},
		buffs = {"Devour: +2% Lifesteal when you hit (cap 6%)"},
	},

	-- ===== EPICKIE =====
	Orc = {
		tier = "Epic",
		desc = "Strong physical power and HP.",
		roleTags = {"str"},
		stats = {HP = 35, STR = 8, Armor = 3, PhysicalPower = 10},
		buffs = {"Rage: when HP < 40% you gain +12% Physical Power"},
	},
	Shadowborn = {
		tier = "Epic",
		desc = "Ambushes and high crits.",
		roleTags = {"dex"},
		stats = {DEX = 7, CritChance = 7, CritDmg = 18, MoveSpeed = 4},
		buffs = {"Ambush: first hit on an enemy +15% damage"},
	},
	Dragonkin = {
		tier = "Epic",
		desc = "Hybrid. Solid stats on both sides.",
		roleTags = {"str","int"},
		stats = {HP = 30, STR = 4, INT = 4, Armor = 3, PhysicalPower = 6, MagicPower = 6},
		buffs = {"Dragon Blood: +5% to all damage"},
	},

	-- ===== LEGENDARNE =====
	Vampire = {
		tier = "Legendary",
		desc = "High sustain and crit.",
		roleTags = {"dex","any"},
		stats = {HP = 20, LifeSteal = 9, CritChance = 5, CritDmg = 15, MoveSpeed = 2},
		buffs = {"Hunger: +1% Lifesteal for every 20% missing HP (cap 5%)"},
	},
	Golem = {
		tier = "Legendary",
		desc = "Toughest tank (at the cost of mobility).",
		roleTags = {"tank"},
		stats = {HP = 55, Armor = 14, MoveSpeed = -5},
		buffs = {"Fortress: -10% damage taken"},
	},
	Archmage = {
		tier = "Legendary",
		desc = "Pure magic and CDR.",
		roleTags = {"int","magic"},
		stats = {Mana = 70, INT = 10, CDR = 12, MagicPower = 14, HP = -5},
		buffs = {"Arcana: +8% Magic Power"},
	},

	-- ===== MITYCZNE =====
	Angel = {
		tier = "Mythic",
		desc = "Very strong and versatile. Best base bonuses.",
		roleTags = {"any","magic"},
		stats = {HP = 35, Mana = 55, STR = 4, DEX = 4, INT = 8, Armor = 6, CDR = 10, MagicPower = 12},
		buffs = {"Blessing: -6% damage taken and +6% damage dealt"},
	},
	Demon = {
		tier = "Mythic",
		desc = "Massive damage, risky defense.",
		roleTags = {"any"},
		stats = {PhysicalPower = 18, MagicPower = 18, CritDmg = 25, Armor = -4, HP = 10},
		buffs = {"Pact: +12% damage but +8% damage taken"},
	},
}

-- ===== SZANSE WG KLASY =====
-- Wagi tierów zależne od klasy. Wyższa waga = częściej.
-- Uwaga: to są WAGI, nie procenty 1:1. Finalnie liczymy losowanie wagowe.
Races.ClassTierWeights = {
	Warrior =   {Common = 62, Rare = 28, Epic = 9,  Legendary = 0.9, Mythic = 0.1},
	Mage =      {Common = 58, Rare = 30, Epic = 10, Legendary = 1.6, Mythic = 0.4},
	Rogue =     {Common = 60, Rare = 28, Epic = 10, Legendary = 1.6, Mythic = 0.4},
	Ranger =    {Common = 60, Rare = 30, Epic = 8,  Legendary = 1.6, Mythic = 0.4},
	Cleric =    {Common = 56, Rare = 30, Epic = 11, Legendary = 2.2, Mythic = 0.8},
	Default =   {Common = 60, Rare = 30, Epic = 9,  Legendary = 0.9, Mythic = 0.1},
}

-- Dodatkowe preferencje ras wg klasy (multiplikator wagi konkretnej rasy)
Races.ClassRaceBias = {
	Warrior = {Dwarf = 1.25, Golem = 1.25, Orc = 1.15, Elf = 0.85, Archmage = 0.8},
	Mage = {Elf = 1.25, Archmage = 1.35, Acolyte = 1.10, Golem = 0.85, Orc = 0.9},
	Rogue = {Goblin = 1.20, Shadowborn = 1.25, Vampire = 1.15, Golem = 0.8},
	Ranger = {Forester = 1.20, Goblin = 1.10, Shadowborn = 1.10, Golem = 0.85},
	Cleric = {Acolyte = 1.20, Angel = 1.30, Elf = 1.10, Demon = 0.85},
}

function Races.GetAllNames(): {string}
	local t = {}
	for name in pairs(Races.Defs) do
		table.insert(t, name)
	end
	table.sort(t)
	return t
end

function Races.IsValid(raceName: string): boolean
	return Races.Defs[raceName] ~= nil
end

function Races.GetTierName(tierKey: string): string
	return (Races.Tiers[tierKey] and Races.Tiers[tierKey].name) or tierKey
end

local function getTierWeightsForClass(className: string)
	return Races.ClassTierWeights[className] or Races.ClassTierWeights.Default
end

local function getRaceBiasForClass(className: string)
	return Races.ClassRaceBias[className] or {}
end

-- Losowanie rasy zależne od klasy: najpierw tier wg klasy, potem rasa w tierze (z biasem)
function Races.RollForClass(className: string): string
	local tierWeights = getTierWeightsForClass(className)
	local bias = getRaceBiasForClass(className)

	-- 1) roll tier
	local tierTotal = 0
	for tierKey, w in pairs(tierWeights) do
		tierTotal += w
	end
	local pickTier = math.random() * tierTotal
	local accTier = 0
	local chosenTier = "Common"
	for tierKey, w in pairs(tierWeights) do
		accTier += w
		if pickTier <= accTier then
			chosenTier = tierKey
			break
		end
	end

	-- 2) collect races in tier
	local candidates = {}
	local total = 0
	for raceName, def in pairs(Races.Defs) do
		if def.tier == chosenTier then
			local w = 1.0
			if bias[raceName] then
				w *= bias[raceName]
			end
			total += w
			table.insert(candidates, {name = raceName, w = w})
		end
	end

	-- fallback: jeśli w tierze nic nie ma (gdybyś usunął wszystkie)
	if #candidates == 0 then
		local names = Races.GetAllNames()
		return names[math.random(1, #names)]
	end

	local pick = math.random() * total
	local acc = 0
	for _, c in ipairs(candidates) do
		acc += c.w
		if pick <= acc then
			return c.name
		end
	end

	return candidates[1].name
end

-- kompatybilność: jak ktoś gdzieś woła RollRandom()
function Races.RollRandom(): string
	return Races.RollForClass("Default")
end

return Races
