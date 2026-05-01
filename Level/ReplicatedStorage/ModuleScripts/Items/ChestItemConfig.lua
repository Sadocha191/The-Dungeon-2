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

ChestItemConfig.FallbackRewards = {
	{ Id = "fallback_xp", Name = "Ancient Notes", Kind = "XP", Amount = 38, Description = "Gain run XP immediately." },
	{ Id = "fallback_gold", Name = "Dungeon Gold", Kind = "Gold", Amount = 55, Description = "Gain run gold immediately." },
	{ Id = "fallback_silver", Name = "Silver Dust", Kind = "Silver", Amount = 24, Description = "Gain silver immediately." },
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

local function add(definition)
	assert(type(definition.Id) == "string" and definition.Id ~= "", "Chest item requires Id")
	assert(type(definition.Name) == "string" and definition.Name ~= "", "Chest item requires Name")
	assert(type(definition.Rarity) == "string" and itemsByRarity[definition.Rarity], "Chest item requires supported Rarity")

	local entry = table.clone(definition)
	entry.Icon = entry.Icon or "placeholder"
	entry.MaxStacks = math.max(1, math.floor(tonumber(entry.MaxStacks) or 1))
	entry.Modifiers = table.clone(entry.Modifiers or {})
	items[#items + 1] = entry
	itemsById[entry.Id] = entry
	itemsByRarity[entry.Rarity][#itemsByRarity[entry.Rarity] + 1] = entry
end

add({ Id = "cracked_heartstone", Name = "Cracked Heartstone", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Adds a small amount of maximum HP.", Modifiers = { MaxHP = 12 } })
add({ Id = "rusty_buckler", Name = "Rusty Buckler", Rarity = "Common", MaxStacks = 8, Icon = "placeholder", Description = "Adds a small shield.", Modifiers = { Shield = 8 } })
add({ Id = "bent_dagger", Name = "Bent Dagger", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Slightly increases damage.", Modifiers = { Damage = 0.06 } })
add({ Id = "training_gloves", Name = "Training Gloves", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Slightly increases attack speed.", Modifiers = { AttackSpeed = 0.05 } })
add({ Id = "runners_laces", Name = "Runner's Laces", Rarity = "Common", MaxStacks = 8, Icon = "placeholder", Description = "Slightly increases movement speed.", Modifiers = { MovementSpeed = 0.04 } })
add({ Id = "old_magnet", Name = "Old Magnet", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Increases pickup range.", Modifiers = { PickupRange = 2 } })
add({ Id = "lucky_pebble", Name = "Lucky Pebble", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Slightly increases luck.", Modifiers = { Luck = 0.03 } })
add({ Id = "sharp_splinter", Name = "Sharp Splinter", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Slightly increases crit chance.", Modifiers = { CritChance = 0.03 } })
add({ Id = "heavy_pebble", Name = "Heavy Pebble", Rarity = "Common", MaxStacks = 8, Icon = "placeholder", Description = "Slightly increases knockback.", Modifiers = { Knockback = 0.08 } })
add({ Id = "tin_coin", Name = "Tin Coin", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Increases gold gain.", Modifiers = { GoldGain = 0.08 } })
add({ Id = "silver_shaving", Name = "Silver Shaving", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Increases silver gain.", Modifiers = { SilverGain = 0.08 } })
add({ Id = "torn_page", Name = "Torn Page", Rarity = "Common", MaxStacks = 10, Icon = "placeholder", Description = "Increases XP gain.", Modifiers = { XPGain = 0.07 } })

add({ Id = "bloodcap_mushroom", Name = "Bloodcap Mushroom", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Adds lifesteal but slightly lowers max HP.", Modifiers = { Lifesteal = 0.05, MaxHP = -5 } })
add({ Id = "moonthread_cloak", Name = "Moonthread Cloak", Rarity = "Uncommon", MaxStacks = 6, Icon = "placeholder", Description = "Increases evasion.", Modifiers = { Evasion = 0.06 } })
add({ Id = "iron_rib", Name = "Iron Rib", Rarity = "Uncommon", MaxStacks = 6, Icon = "placeholder", Description = "Increases armor and max HP.", Modifiers = { Armor = 0.04, MaxHP = 8 } })
add({ Id = "glass_needle", Name = "Glass Needle", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Increases crit chance but lowers shield.", Modifiers = { CritChance = 0.08, Shield = -5 } })
add({ Id = "goblin_springboots", Name = "Goblin Springboots", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Improves jumping and movement speed.", Modifiers = { JumpHeight = 0.08, MovementSpeed = 0.04 } })
add({ Id = "echo_marble", Name = "Echo Marble", Rarity = "Uncommon", MaxStacks = 3, Icon = "placeholder", Description = "Adds projectile bounces.", Modifiers = { ProjectileBounces = 1 } })
add({ Id = "candlewick_charm", Name = "Candlewick Charm", Rarity = "Uncommon", MaxStacks = 6, Icon = "placeholder", Description = "Increases duration of spells and effects.", Modifiers = { Duration = 0.12 } })
add({ Id = "fat_ember", Name = "Fat Ember", Rarity = "Uncommon", MaxStacks = 6, Icon = "placeholder", Description = "Increases spell and attack size.", Modifiers = { Size = 0.10 } })
add({ Id = "jagged_horseshoe", Name = "Jagged Horseshoe", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Increases damage to elites and bosses.", Modifiers = { DamageToElites = 0.15 } })
add({ Id = "hunters_chalk", Name = "Hunter's Chalk", Rarity = "Uncommon", MaxStacks = 6, Icon = "placeholder", Description = "Increases damage and pickup range.", Modifiers = { Damage = 0.08, PickupRange = 1 } })
add({ Id = "vulture_token", Name = "Vulture Token", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Increases chance for powerups to drop.", Modifiers = { PowerupDropChance = 0.04 } })
add({ Id = "blue_beetle_shell", Name = "Blue Beetle Shell", Rarity = "Uncommon", MaxStacks = 5, Icon = "placeholder", Description = "Adds shield and armor.", Modifiers = { Shield = 12, Armor = 0.03 } })

add({ Id = "ashen_crown", Name = "Ashen Crown", Rarity = "Rare", MaxStacks = 5, Icon = "placeholder", Description = "Increases damage, but also increases difficulty.", Modifiers = { Damage = 0.18, Difficulty = 0.05 } })
add({ Id = "bone_compass", Name = "Bone Compass", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Increases elite spawn rate and rewards.", Modifiers = { EliteSpawnIncrease = 0.15, XPGain = 0.10, GoldGain = 0.10 } })
add({ Id = "sanguine_ring", Name = "Sanguine Ring", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Strong lifesteal item.", Modifiers = { Lifesteal = 0.10, Damage = 0.05 } })
add({ Id = "thunder_drum", Name = "Thunder Drum", Rarity = "Rare", MaxStacks = 5, Icon = "placeholder", Description = "Increases attack speed and projectile speed.", Modifiers = { AttackSpeed = 0.12, ProjectileSpeed = 0.15 } })
add({ Id = "ogre_tooth", Name = "Ogre Tooth", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Big damage and knockback, but lower attack speed.", Modifiers = { Damage = 0.25, Knockback = 0.20, AttackSpeed = -0.08 } })
add({ Id = "phantom_feather", Name = "Phantom Feather", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Increases evasion and movement speed.", Modifiers = { Evasion = 0.09, MovementSpeed = 0.07 } })
add({ Id = "star_lens", Name = "Star Lens", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Crit-focused item.", Modifiers = { CritChance = 0.10, CritDamage = 0.20 } })
add({ Id = "runic_battery", Name = "Runic Battery", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Improves powerups.", Modifiers = { PowerupMultiplier = 0.20, PowerupDropChance = 0.03 } })
add({ Id = "giants_button", Name = "Giant's Button", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Makes attacks bigger and stronger, but slightly slows movement.", Modifiers = { Size = 0.18, Damage = 0.10, MovementSpeed = -0.03 } })
add({ Id = "silver_saint_medal", Name = "Silver Saint Medal", Rarity = "Rare", MaxStacks = 4, Icon = "placeholder", Description = "Strong silver economy item.", Modifiers = { SilverGain = 0.25, Luck = 0.05 } })
add({ Id = "rotten_banner", Name = "Rotten Banner", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "More elites, more danger, better scaling.", Modifiers = { EliteSpawnIncrease = 0.25, Difficulty = 0.08, DamageToElites = 0.20 } })
add({ Id = "mirror_shard", Name = "Mirror Shard", Rarity = "Rare", MaxStacks = 3, Icon = "placeholder", Description = "Adds projectile count but reduces damage slightly.", Modifiers = { ProjectileCount = 1, Damage = -0.08 } })

add({ Id = "black_sun_pendant", Name = "Black Sun Pendant", Rarity = "Epic", MaxStacks = 3, Icon = "placeholder", Description = "High damage, higher difficulty.", Modifiers = { Damage = 0.35, Difficulty = 0.12 } })
add({ Id = "kings_leech", Name = "King's Leech", Rarity = "Epic", MaxStacks = 3, Icon = "placeholder", Description = "Strong lifesteal and max HP.", Modifiers = { Lifesteal = 0.15, MaxHP = 20 } })
add({ Id = "dragon_scale_plate", Name = "Dragon Scale Plate", Rarity = "Epic", MaxStacks = 3, Icon = "placeholder", Description = "Huge defensive item but slightly slows movement.", Modifiers = { Armor = 0.10, Shield = 35, MovementSpeed = -0.05 } })
add({ Id = "serpent_dice", Name = "Serpent Dice", Rarity = "Epic", MaxStacks = 3, Icon = "placeholder", Description = "Strong luck and crit chance.", Modifiers = { Luck = 0.15, CritChance = 0.12 } })
add({ Id = "warlock_hourglass", Name = "Warlock Hourglass", Rarity = "Epic", MaxStacks = 3, Icon = "placeholder", Description = "Great duration and size.", Modifiers = { Duration = 0.30, Size = 0.20 } })
add({ Id = "executioners_hook", Name = "Executioner's Hook", Rarity = "Epic", MaxStacks = 3, Icon = "placeholder", Description = "Massive elite and boss damage.", Modifiers = { DamageToElites = 0.50, CritDamage = 0.25 } })
add({ Id = "storm_needle", Name = "Storm Needle", Rarity = "Epic", MaxStacks = 3, Icon = "placeholder", Description = "Attack speed and projectile speed burst.", Modifiers = { AttackSpeed = 0.25, ProjectileSpeed = 0.30 } })
add({ Id = "greedy_relic", Name = "Greedy Relic", Rarity = "Epic", MaxStacks = 3, Icon = "placeholder", Description = "Better economy but harder run.", Modifiers = { GoldGain = 0.40, SilverGain = 0.40, Difficulty = 0.10 } })
add({ Id = "twin_fang_totem", Name = "Twin Fang Totem", Rarity = "Epic", MaxStacks = 2, Icon = "placeholder", Description = "Adds projectile count and crit damage.", Modifiers = { ProjectileCount = 1, CritDamage = 0.35 } })
add({ Id = "thorn_idol", Name = "Thorn Idol", Rarity = "Epic", MaxStacks = 4, Icon = "placeholder", Description = "Adds thorns and armor.", Modifiers = { Thorns = 15, Armor = 0.06 } })

add({ Id = "heart_of_the_dungeon", Name = "Heart of the Dungeon", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Huge all-around survival boost.", Modifiers = { MaxHP = 60, Shield = 60, HPRegen = 3, Armor = 0.08 } })
add({ Id = "crown_of_bad_decisions", Name = "Crown of Bad Decisions", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Great rewards, much harder run.", Modifiers = { Luck = 0.25, GoldGain = 0.50, SilverGain = 0.50, XPGain = 0.35, Difficulty = 0.20, EliteSpawnIncrease = 0.35 } })
add({ Id = "meteor_spine", Name = "Meteor Spine", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Massive damage and size, but slower attacks.", Modifiers = { Damage = 0.60, Size = 0.35, AttackSpeed = -0.10 } })
add({
	Id = "angels_debt",
	Name = "Angel's Debt",
	Rarity = "Legendary",
	MaxStacks = 1,
	Icon = "placeholder",
	Description = "Prevents death once, then breaks.",
	Modifiers = { MaxHP = 20 },
	SpecialEffect = { Type = "AngelDebt" },
})
add({ Id = "void_duplicator", Name = "Void Duplicator", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Adds extra projectile count with a damage penalty.", Modifiers = { ProjectileCount = 2, Damage = -0.20 } })
add({
	Id = "blood_moon_contract",
	Name = "Blood Moon Contract",
	Rarity = "Legendary",
	MaxStacks = 1,
	Icon = "placeholder",
	Description = "Huge lifesteal and damage, but removes shield.",
	Modifiers = { Lifesteal = 0.30, Damage = 0.30, Shield = -9999 },
	SpecialEffect = { Type = "BloodMoonContract", BlockShieldGain = true },
})
add({ Id = "saints_magnet", Name = "Saint's Magnet", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Massive pickup range and XP gain.", Modifiers = { PickupRange = 20, XPGain = 0.50, Luck = 0.10 } })
add({ Id = "titans_ankle", Name = "Titan's Ankle", Rarity = "Legendary", MaxStacks = 1, Icon = "placeholder", Description = "Huge knockback, armor and size, but slower movement.", Modifiers = { Knockback = 0.75, Armor = 0.12, Size = 0.25, MovementSpeed = -0.12 } })

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
