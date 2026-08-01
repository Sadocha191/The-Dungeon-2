local ChestItemConfig = {}

ChestItemConfig.RarityOrder = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
}

ChestItemConfig.RarityWeights = {
	Common = 60,
	Uncommon = 25,
	Rare = 10,
	Epic = 4,
	Legendary = 1,
}

ChestItemConfig.RarityColors = {
	Common = Color3.fromRGB(226, 229, 235),
	Uncommon = Color3.fromRGB(98, 203, 110),
	Rare = Color3.fromRGB(87, 161, 255),
	Epic = Color3.fromRGB(173, 106, 255),
	Legendary = Color3.fromRGB(246, 194, 84),
}

-- Keep chest items on stats that the current Level runtime actually consumes.
-- This prevents future rewards from silently doing nothing because a stat exists
-- in StatsConfig but has no gameplay consumer.
ChestItemConfig.SupportedModifiers = {
	MaxHP = true,
	Shield = true,
	Armor = true,
	Evasion = true,
	Lifesteal = true,
	Thorns = true,
	Damage = true,
	CritDamage = true,
	AttackSpeed = true,
	DamageToElites = true,
	Knockback = true,
	Duration = true,
	Difficulty = true,
	PickupRange = true,
}

ChestItemConfig.FallbackRewards = {
	{ Id = "fallback_xp", Name = "Ancient Notes", Kind = "XP", Amount = 140, Description = "Gain a meaningful burst of run XP immediately." },
	{ Id = "fallback_gold", Name = "Dungeon Gold", Kind = "Gold", Amount = 120, Description = "Gain a useful amount of run gold immediately." },
	{ Id = "fallback_silver", Name = "Silver Dust", Kind = "Silver", Amount = 55, Description = "Gain persistent silver immediately." },
}

local items = {}
local itemsById = {}
local itemsByRarity = {
	Common = {},
	Uncommon = {},
	Rare = {},
	Epic = {},
	Legendary = {},
}

local function isFiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function add(definition)
	assert(type(definition.Id) == "string" and definition.Id ~= "", "Chest item requires Id")
	assert(type(definition.Name) == "string" and definition.Name ~= "", "Chest item requires Name")
	assert(type(definition.Rarity) == "string" and itemsByRarity[definition.Rarity], "Chest item requires supported Rarity")
	assert(itemsById[definition.Id] == nil, string.format("Duplicate chest item Id: %s", definition.Id))

	local entry = table.clone(definition)
	entry.Icon = entry.Icon or "placeholder"
	entry.MaxStacks = math.max(1, math.floor(tonumber(entry.MaxStacks) or 1))
	entry.Modifiers = table.clone(entry.Modifiers or {})

	for statName, delta in pairs(entry.Modifiers) do
		assert(
			ChestItemConfig.SupportedModifiers[statName] == true,
			string.format("Chest item %s uses unsupported modifier %s", entry.Id, tostring(statName))
		)
		assert(
			isFiniteNumber(delta),
			string.format("Chest item %s has invalid modifier value for %s", entry.Id, tostring(statName))
		)
	end

	items[#items + 1] = entry
	itemsById[entry.Id] = entry
	itemsByRarity[entry.Rarity][#itemsByRarity[entry.Rarity] + 1] = entry
end

-- Common items: one clear, immediately noticeable benefit.
add({ Id = "cracked_heartstone", Name = "Cracked Heartstone", Rarity = "Common", MaxStacks = 8, Icon = "placeholder", Description = "Adds a solid amount of maximum HP.", Modifiers = { MaxHP = 16 } })
add({ Id = "rusty_buckler", Name = "Rusty Buckler", Rarity = "Common", MaxStacks = 8, Icon = "placeholder", Description = "Adds a reliable shield layer.", Modifiers = { Shield = 14 } })
add({ Id = "bent_dagger", Name = "Bent Dagger", Rarity = "Common", MaxStacks = 8, Icon = "placeholder", Description = "Increases all weapon and spell damage.", Modifiers = { Damage = 0.08 } })
add({ Id = "training_gloves", Name = "Training Gloves", Rarity = "Common", MaxStacks = 8, Icon = "placeholder", Description = "Makes weapon attacks noticeably faster.", Modifiers = { AttackSpeed = 0.08 } })
add({ Id = "runners_laces", Name = "Runner's Laces", Rarity = "Common", MaxStacks = 6, Icon = "placeholder", Description = "Improves footwork and the chance to evade damage.", Modifiers = { Evasion = 0.04 } })
add({ Id = "old_magnet", Name = "Old Magnet", Rarity = "Common", MaxStacks = 6, Icon = "placeholder", Description = "Pulls drops in from farther away.", Modifiers = { PickupRange = 3 } })
add({ Id = "lucky_pebble", Name = "Lucky Pebble", Rarity = "Common", MaxStacks = 6, Icon = "placeholder", Description = "Turns near misses into lucky escapes.", Modifiers = { Evasion = 0.05 } })
add({ Id = "sharp_splinter", Name = "Sharp Splinter", Rarity = "Common", MaxStacks = 8, Icon = "placeholder", Description = "Makes critical hits deal more damage.", Modifiers = { CritDamage = 0.18 } })
add({ Id = "heavy_pebble", Name = "Heavy Pebble", Rarity = "Common", MaxStacks = 6, Icon = "placeholder", Description = "Greatly improves knockback.", Modifiers = { Knockback = 0.16 } })
add({ Id = "tin_coin", Name = "Tin Coin", Rarity = "Common", MaxStacks = 6, Icon = "placeholder", Description = "A small combat charm that improves damage and pickup reach.", Modifiers = { Damage = 0.06, PickupRange = 1 } })
add({ Id = "silver_shaving", Name = "Silver Shaving", Rarity = "Common", MaxStacks = 6, Icon = "placeholder", Description = "Hardens into a thin layer of shield and armor.", Modifiers = { Shield = 10, Armor = 0.02 } })
add({ Id = "torn_page", Name = "Torn Page", Rarity = "Common", MaxStacks = 6, Icon = "placeholder", Description = "Extends spell and effect duration.", Modifiers = { Duration = 0.14 } })

-- Uncommon items: stronger bonuses or focused two-stat packages.
add({ Id = "bloodcap_mushroom", Name = "Bloodcap Mushroom", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Adds strong lifesteal at a small maximum HP cost.", Modifiers = { Lifesteal = 0.06, MaxHP = -4 } })
add({ Id = "moonthread_cloak", Name = "Moonthread Cloak", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Substantially increases evasion.", Modifiers = { Evasion = 0.09 } })
add({ Id = "iron_rib", Name = "Iron Rib", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Increases armor and maximum HP.", Modifiers = { Armor = 0.05, MaxHP = 12 } })
add({ Id = "glass_needle", Name = "Glass Needle", Rarity = "Uncommon", MaxStacks = 4, Icon = "placeholder", Description = "Greatly increases critical damage but lowers maximum HP.", Modifiers = { CritDamage = 0.32, MaxHP = -6 } })
add({ Id = "goblin_springboots", Name = "Goblin Springboots", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Improves evasive movement and pickup reach.", Modifiers = { Evasion = 0.06, PickupRange = 2 } })
add({ Id = "echo_marble", Name = "Echo Marble", Rarity = "Uncommon", MaxStacks = 4, Icon = "placeholder", Description = "Keeps spells and lingering effects active longer.", Modifiers = { Duration = 0.22 } })
add({ Id = "candlewick_charm", Name = "Candlewick Charm", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Extends effects and adds a small shield.", Modifiers = { Duration = 0.18, Shield = 10 } })
add({ Id = "fat_ember", Name = "Fat Ember", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Increases damage and effect duration.", Modifiers = { Damage = 0.12, Duration = 0.10 } })
add({ Id = "jagged_horseshoe", Name = "Jagged Horseshoe", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Deals much more damage to elites and bosses.", Modifiers = { DamageToElites = 0.22 } })
add({ Id = "hunters_chalk", Name = "Hunter's Chalk", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Increases damage and pickup reach.", Modifiers = { Damage = 0.10, PickupRange = 2 } })
add({ Id = "vulture_token", Name = "Vulture Token", Rarity = "Uncommon", MaxStacks = 4, Icon = "placeholder", Description = "Rewards aggressive elite hunting with lifesteal and elite damage.", Modifiers = { Lifesteal = 0.04, DamageToElites = 0.12 } })
add({ Id = "blue_beetle_shell", Name = "Blue Beetle Shell", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Adds a strong shield and armor.", Modifiers = { Shield = 20, Armor = 0.04 } })

-- Rare items: build-defining boosts with meaningful trade-offs where appropriate.
add({ Id = "ashen_crown", Name = "Ashen Crown", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Greatly increases damage while making incoming damage more dangerous.", Modifiers = { Damage = 0.24, Difficulty = 0.05 } })
add({ Id = "bone_compass", Name = "Bone Compass", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Guides you toward elites and makes their rewards easier to collect.", Modifiers = { DamageToElites = 0.28, PickupRange = 4 } })
add({ Id = "sanguine_ring", Name = "Sanguine Ring", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Combines strong lifesteal with extra damage.", Modifiers = { Lifesteal = 0.12, Damage = 0.08 } })
add({ Id = "thunder_drum", Name = "Thunder Drum", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Increases attack speed and damage.", Modifiers = { AttackSpeed = 0.18, Damage = 0.08 } })
add({ Id = "ogre_tooth", Name = "Ogre Tooth", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Massively increases damage and knockback, but slows attacks.", Modifiers = { Damage = 0.30, Knockback = 0.25, AttackSpeed = -0.08 } })
add({ Id = "phantom_feather", Name = "Phantom Feather", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Greatly increases evasion and grants a shield.", Modifiers = { Evasion = 0.13, Shield = 16 } })
add({ Id = "star_lens", Name = "Star Lens", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Makes critical hits devastating while increasing base damage.", Modifiers = { CritDamage = 0.48, Damage = 0.10 } })
add({ Id = "runic_battery", Name = "Runic Battery", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Extends spell effects and speeds up weapon attacks.", Modifiers = { Duration = 0.32, AttackSpeed = 0.10 } })
add({ Id = "giants_button", Name = "Giant's Button", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Adds maximum HP and damage at a small attack speed cost.", Modifiers = { MaxHP = 28, Damage = 0.12, AttackSpeed = -0.05 } })
add({ Id = "silver_saint_medal", Name = "Silver Saint Medal", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Provides a large shield and strong armor.", Modifiers = { Shield = 28, Armor = 0.08 } })
add({ Id = "rotten_banner", Name = "Rotten Banner", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Massively improves elite damage and base damage, but raises danger.", Modifiers = { DamageToElites = 0.38, Damage = 0.12, Difficulty = 0.08 } })
add({ Id = "mirror_shard", Name = "Mirror Shard", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Accelerates attacks and empowers critical hits.", Modifiers = { AttackSpeed = 0.16, CritDamage = 0.28 } })

-- Epic items: major power spikes that should always feel worth taking.
add({ Id = "black_sun_pendant", Name = "Black Sun Pendant", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Grants enormous damage at the cost of a much more dangerous run.", Modifiers = { Damage = 0.42, Difficulty = 0.12 } })
add({ Id = "kings_leech", Name = "King's Leech", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Grants huge lifesteal and maximum HP.", Modifiers = { Lifesteal = 0.18, MaxHP = 32 } })
add({ Id = "dragon_scale_plate", Name = "Dragon Scale Plate", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Provides massive armor and shield, but slightly slows attacks.", Modifiers = { Armor = 0.15, Shield = 50, AttackSpeed = -0.06 } })
add({ Id = "serpent_dice", Name = "Serpent Dice", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Combines extreme evasion with stronger critical hits.", Modifiers = { Evasion = 0.16, CritDamage = 0.35 } })
add({ Id = "warlock_hourglass", Name = "Warlock Hourglass", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Greatly extends effects and increases damage.", Modifiers = { Duration = 0.50, Damage = 0.16 } })
add({ Id = "executioners_hook", Name = "Executioner's Hook", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Deals overwhelming damage to elites and bosses and empowers critical hits.", Modifiers = { DamageToElites = 0.70, CritDamage = 0.40 } })
add({ Id = "storm_needle", Name = "Storm Needle", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Massively increases attack speed and damage.", Modifiers = { AttackSpeed = 0.32, Damage = 0.16 } })
add({ Id = "greedy_relic", Name = "Greedy Relic", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Grants high damage and lifesteal while making the run harder.", Modifiers = { Damage = 0.28, Lifesteal = 0.08, Difficulty = 0.10 } })
add({ Id = "twin_fang_totem", Name = "Twin Fang Totem", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Greatly increases attack speed and critical damage.", Modifiers = { AttackSpeed = 0.22, CritDamage = 0.50 } })
add({ Id = "thorn_idol", Name = "Thorn Idol", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Reflects heavy damage and adds armor and shield.", Modifiers = { Thorns = 28, Armor = 0.10, Shield = 20 } })

-- Legendary items: unique, run-changing rewards.
add({ Id = "heart_of_the_dungeon", Name = "Heart of the Dungeon", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "A huge all-around survival boost.", Modifiers = { MaxHP = 90, Shield = 90, Armor = 0.14 } })
add({ Id = "crown_of_bad_decisions", Name = "Crown of Bad Decisions", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Grants absurd offensive power and lifesteal, but makes the run much more dangerous.", Modifiers = { Damage = 0.50, CritDamage = 0.55, Lifesteal = 0.10, Difficulty = 0.20 } })
add({ Id = "meteor_spine", Name = "Meteor Spine", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Grants colossal damage and knockback at a small attack speed cost.", Modifiers = { Damage = 0.75, Knockback = 0.60, AttackSpeed = -0.10 } })
add({
	Id = "angels_debt",
	Name = "Angel's Debt",
	Rarity = "Legendary",
	MaxStacks = 1,
	Icon = "placeholder",
	Description = "Prevents death once, restores half health, and grants a temporary shield.",
	Modifiers = { MaxHP = 35 },
	SpecialEffect = { Type = "AngelDebt" },
})
add({ Id = "void_duplicator", Name = "Void Engine", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Violently accelerates attacks while increasing all damage.", Modifiers = { AttackSpeed = 0.40, Damage = 0.30 } })
add({
	Id = "blood_moon_contract",
	Name = "Blood Moon Contract",
	Rarity = "Legendary",
	MaxStacks = 1,
	Icon = "placeholder",
	Description = "Grants enormous lifesteal and damage, but permanently disables shield gain.",
	Modifiers = { Lifesteal = 0.30, Damage = 0.35, Shield = -9999 },
	SpecialEffect = { Type = "BloodMoonContract", BlockShieldGain = true },
})
add({ Id = "saints_magnet", Name = "Saint's Magnet", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Pulls in drops from extreme range while extending effects and improving elite damage.", Modifiers = { PickupRange = 32, Duration = 0.30, DamageToElites = 0.25 } })
add({ Id = "titans_ankle", Name = "Titan's Ankle", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Grants immense knockback, armor, and maximum HP at a small attack speed cost.", Modifiers = { Knockback = 1.00, Armor = 0.16, MaxHP = 45, AttackSpeed = -0.10 } })

ChestItemConfig.Items = items
ChestItemConfig.ItemsById = itemsById
ChestItemConfig.ItemsByRarity = itemsByRarity

function ChestItemConfig.GetItem(itemId)
	return itemsById[itemId]
end

function ChestItemConfig.GetItemsForRarity(rarity)
	return itemsByRarity[rarity] or {}
end

return ChestItemConfig
