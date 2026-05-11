local CraftingConfig = {}

local MaterialDefinitions = require(script.Parent:WaitForChild("MaterialDefinitions"))

CraftingConfig.RECIPE_DROP_CHANCE = 0.10
CraftingConfig.RECIPE_DUPLICATE_THRESHOLDS = { 1, 3, 6 }
CraftingConfig.RECIPE_TIER_MULTIPLIERS = { 1.00, 1.45, 1.90 }
CraftingConfig.RECIPE_TIER_STAT_BONUS = { 1.00, 1.12, 1.25 }
CraftingConfig.RECIPE_TIER_PREFIX = {
	"Forged",
	"Refined",
	"Mastercrafted",
}

CraftingConfig.SELL_REFUND_RATIO = 0.50
CraftingConfig.SELL_UPGRADE_SILVER_RATIO = 0.25

CraftingConfig.UPGRADE_CRYSTAL_ID = "Upgrade Crystal"
CraftingConfig.ELITE_SPECIAL_ID = "Elite Sigil"
CraftingConfig.BOSS_SPECIAL_ID = "Boss Core"

CraftingConfig.UPGRADE_COSTS = {
	Common = { silverBase = 50, silverPerLevel = 22, crystalsBase = 1, crystalsPer10 = 1 },
	Uncommon = { silverBase = 64, silverPerLevel = 28, crystalsBase = 1, crystalsPer10 = 1 },
	Rare = { silverBase = 80, silverPerLevel = 34, crystalsBase = 2, crystalsPer10 = 1 },
	Epic = { silverBase = 115, silverPerLevel = 48, crystalsBase = 3, crystalsPer10 = 1 },
	Legendary = { silverBase = 160, silverPerLevel = 64, crystalsBase = 4, crystalsPer10 = 2 },
	Mythic = { silverBase = 220, silverPerLevel = 86, crystalsBase = 5, crystalsPer10 = 2 },
	Mythical = { silverBase = 220, silverPerLevel = 86, crystalsBase = 5, crystalsPer10 = 2 },
}

CraftingConfig.UPGRADE_SPECIAL_THRESHOLDS = {
	[20] = { id = CraftingConfig.ELITE_SPECIAL_ID, amount = 1 },
	[40] = { id = CraftingConfig.ELITE_SPECIAL_ID, amount = 2 },
	[60] = { id = CraftingConfig.ELITE_SPECIAL_ID, amount = 3 },
	[80] = { id = CraftingConfig.ELITE_SPECIAL_ID, amount = 4 },
	[100] = { id = CraftingConfig.BOSS_SPECIAL_ID, amount = 1 },
}

CraftingConfig.MINE_DURATION_OPTIONS = {
	600,
	1800,
	3600,
	7200,
	14400,
	28800,
}

CraftingConfig.MINE_RESOURCE_DEFS = {
	{
		id = "Iron Ore",
		rarity = "Common",
		weight = 55,
		yieldMin = 1,
		yieldMax = 3,
		color = Color3.fromRGB(176, 186, 202),
	},
	{
		id = "Coal Chunk",
		rarity = "Common",
		weight = 42,
		yieldMin = 1,
		yieldMax = 3,
		color = Color3.fromRGB(112, 118, 132),
	},
	{
		id = "Emberstone",
		rarity = "Uncommon",
		weight = 24,
		yieldMin = 1,
		yieldMax = 2,
		color = Color3.fromRGB(236, 140, 96),
	},
	{
		id = "Moonsteel Ore",
		rarity = "Rare",
		weight = 12,
		yieldMin = 1,
		yieldMax = 2,
		color = Color3.fromRGB(118, 190, 255),
	},
	{
		id = "Void Crystal",
		rarity = "Epic",
		weight = 5,
		yieldMin = 1,
		yieldMax = 1,
		color = Color3.fromRGB(178, 118, 255),
	},
	{
		id = "Astral Core",
		rarity = "Legendary",
		weight = 2,
		yieldMin = 1,
		yieldMax = 1,
		color = Color3.fromRGB(255, 214, 126),
	},
}

local mineList = {
	{
		id = "Ironvein Quarry",
		displayName = "Ironvein Quarry",
		subtitle = "Starter mineral route",
		description = "Reliable starter shafts with dense iron seams and cheap fuel veins.",
		tone = "Best for early swords, bows and blackpowder recipes.",
		colors = {
			primary = Color3.fromRGB(94, 157, 255),
			secondary = Color3.fromRGB(34, 50, 86),
			accent = Color3.fromRGB(214, 232, 255),
		},
		drops = {
			{ id = "Iron Ore", weight = 52, yieldMin = 2, yieldMax = 4 },
			{ id = "Coal Chunk", weight = 30, yieldMin = 1, yieldMax = 3 },
			{ id = "Emberstone", weight = 14, yieldMin = 1, yieldMax = 2 },
			{ id = "Moonsteel Ore", weight = 4, yieldMin = 1, yieldMax = 1 },
		},
	},
	{
		id = "Cinder Excavation",
		displayName = "Cinder Excavation",
		subtitle = "Heat-cracked galleries",
		description = "Charred tunnels stacked with coal pockets and emberstone blooms.",
		tone = "Best for halberds, pistols and bows that need emberstone fast.",
		colors = {
			primary = Color3.fromRGB(255, 134, 80),
			secondary = Color3.fromRGB(102, 44, 34),
			accent = Color3.fromRGB(255, 224, 206),
		},
		drops = {
			{ id = "Emberstone", weight = 34, yieldMin = 1, yieldMax = 2 },
			{ id = "Coal Chunk", weight = 30, yieldMin = 1, yieldMax = 3 },
			{ id = "Iron Ore", weight = 22, yieldMin = 1, yieldMax = 3 },
			{ id = "Moonsteel Ore", weight = 10, yieldMin = 1, yieldMax = 1 },
			{ id = "Void Crystal", weight = 4, yieldMin = 1, yieldMax = 1 },
		},
	},
	{
		id = "Moonsteel Gallery",
		displayName = "Moonsteel Gallery",
		subtitle = "Cold lunar veins",
		description = "Deep silver caverns tuned for rare alloys and disciplined routes.",
		tone = "Best for staves, recurve bows and elite polearms.",
		colors = {
			primary = Color3.fromRGB(110, 198, 255),
			secondary = Color3.fromRGB(29, 69, 102),
			accent = Color3.fromRGB(214, 245, 255),
		},
		drops = {
			{ id = "Moonsteel Ore", weight = 24, yieldMin = 1, yieldMax = 2 },
			{ id = "Emberstone", weight = 26, yieldMin = 1, yieldMax = 2 },
			{ id = "Coal Chunk", weight = 22, yieldMin = 1, yieldMax = 2 },
			{ id = "Iron Ore", weight = 12, yieldMin = 1, yieldMax = 2 },
			{ id = "Void Crystal", weight = 12, yieldMin = 1, yieldMax = 1 },
			{ id = "Astral Core", weight = 4, yieldMin = 1, yieldMax = 1 },
		},
	},
	{
		id = "Voidscar Hollow",
		displayName = "Voidscar Hollow",
		subtitle = "Shattered crystal fault",
		description = "A dangerous breach with excellent void output and steady moonsteel.",
		tone = "Best for epic and legendary weapons that hinge on void crystal.",
		colors = {
			primary = Color3.fromRGB(166, 104, 255),
			secondary = Color3.fromRGB(60, 34, 96),
			accent = Color3.fromRGB(240, 225, 255),
		},
		drops = {
			{ id = "Void Crystal", weight = 20, yieldMin = 1, yieldMax = 1 },
			{ id = "Moonsteel Ore", weight = 24, yieldMin = 1, yieldMax = 2 },
			{ id = "Emberstone", weight = 20, yieldMin = 1, yieldMax = 2 },
			{ id = "Coal Chunk", weight = 14, yieldMin = 1, yieldMax = 2 },
			{ id = "Iron Ore", weight = 14, yieldMin = 1, yieldMax = 2 },
			{ id = "Astral Core", weight = 8, yieldMin = 1, yieldMax = 1 },
		},
	},
	{
		id = "Astral Sanctum",
		displayName = "Astral Sanctum",
		subtitle = "Celestial breach",
		description = "A slow but premium route for endgame alloy and astral core pulls.",
		tone = "Best for legendary and mythical finishers.",
		colors = {
			primary = Color3.fromRGB(255, 198, 94),
			secondary = Color3.fromRGB(112, 70, 24),
			accent = Color3.fromRGB(255, 242, 202),
		},
		drops = {
			{ id = "Astral Core", weight = 5, yieldMin = 1, yieldMax = 1 },
			{ id = "Void Crystal", weight = 22, yieldMin = 1, yieldMax = 1 },
			{ id = "Moonsteel Ore", weight = 28, yieldMin = 1, yieldMax = 2 },
			{ id = "Emberstone", weight = 18, yieldMin = 1, yieldMax = 2 },
			{ id = "Coal Chunk", weight = 15, yieldMin = 1, yieldMax = 2 },
			{ id = "Iron Ore", weight = 12, yieldMin = 1, yieldMax = 2 },
		},
	},
}

CraftingConfig.MINE_DEFS = mineList

CraftingConfig.MOB_MATERIAL_DEFS = {
	{ id = "Slime Gem", mobType = "Slime" },
	{ id = "Rotbone", mobType = "Zombie" },
	{ id = "Bone Core", mobType = "Skeleton" },
	{ id = "Raider Fang", mobType = "Goblin" },
	{ id = "Moon Claw", mobType = "Warewolf" },
	{ id = "Siren Feather", mobType = "Harp" },
	{ id = "Inferno Shard", mobType = "Demon" },
	{ id = "Burrow Fin", mobType = "LandShark" },
	{ id = "Golem Heart", mobType = "Golem" },
	{ id = "Knight Emblem", mobType = "Knight" },
	{ id = "Ancient Bark", mobType = "Ent" },
}

CraftingConfig.NORMAL_MOB_UPGRADE_CRYSTAL_CHANCE = 0.22
CraftingConfig.ELITE_UPGRADE_CRYSTAL_RANGE = { min = 3, max = 5 }
CraftingConfig.BOSS_UPGRADE_CRYSTAL_RANGE = { min = 8, max = 12 }

local recipeList = {
	{
		recipeId = "Knight's Oath",
		weaponId = "Knight's Oath",
		rarity = "Common",
		requiredLevel = 1,
		unlockSilverCost = 150,
		craftSilverCost = 120,
		unique = true,
		materials = {
			{ id = "Slime Gem", amount = 4 },
			{ id = "Bone Core", amount = 2 },
			{ id = "Iron Ore", amount = 6 },
		},
	},
	{
		recipeId = "Hunter's Longbow",
		weaponId = "Hunter's Longbow",
		rarity = "Common",
		requiredLevel = 1,
		unlockSilverCost = 150,
		craftSilverCost = 120,
		unique = true,
		materials = {
			{ id = "Raider Fang", amount = 4 },
			{ id = "Slime Gem", amount = 2 },
			{ id = "Iron Ore", amount = 5 },
		},
	},
	{
		recipeId = "Warden's Halberd",
		weaponId = "Warden's Halberd",
		rarity = "Rare",
		requiredLevel = 5,
		unlockSilverCost = 300,
		craftSilverCost = 260,
		unique = true,
		materials = {
			{ id = "Rotbone", amount = 5 },
			{ id = "Knight Emblem", amount = 3 },
			{ id = "Emberstone", amount = 4 },
		},
	},
	{
		recipeId = "Apprentice Arcstaff",
		weaponId = "Apprentice Arcstaff",
		rarity = "Rare",
		requiredLevel = 7,
		unlockSilverCost = 340,
		craftSilverCost = 280,
		unique = true,
		materials = {
			{ id = "Siren Feather", amount = 4 },
			{ id = "Bone Core", amount = 3 },
			{ id = "Moonsteel Ore", amount = 3 },
		},
	},
	{
		recipeId = "Blackpowder Flintlock",
		weaponId = "Blackpowder Flintlock",
		rarity = "Rare",
		requiredLevel = 9,
		unlockSilverCost = 360,
		craftSilverCost = 320,
		unique = true,
		materials = {
			{ id = "Raider Fang", amount = 4 },
			{ id = "Burrow Fin", amount = 2 },
			{ id = "Emberstone", amount = 5 },
		},
	},
	{
		recipeId = "Reaper's Crescent",
		weaponId = "Reaper's Crescent",
		rarity = "Epic",
		requiredLevel = 12,
		unlockSilverCost = 520,
		craftSilverCost = 480,
		unique = true,
		materials = {
			{ id = "Moon Claw", amount = 5 },
			{ id = "Ancient Bark", amount = 3 },
			{ id = "Void Crystal", amount = 2 },
		},
	},
	{
		recipeId = "Dragonspear Halberd",
		weaponId = "Dragonspear Halberd",
		rarity = "Epic",
		requiredLevel = 14,
		unlockSilverCost = 560,
		craftSilverCost = 520,
		unique = true,
		materials = {
			{ id = "Inferno Shard", amount = 5 },
			{ id = "Golem Heart", amount = 2 },
			{ id = "Void Crystal", amount = 3 },
		},
	},
	{
		recipeId = "Stormwind Recurve",
		weaponId = "Stormwind Recurve",
		rarity = "Epic",
		requiredLevel = 15,
		unlockSilverCost = 580,
		craftSilverCost = 540,
		unique = true,
		materials = {
			{ id = "Siren Feather", amount = 5 },
			{ id = "Moon Claw", amount = 3 },
			{ id = "Moonsteel Ore", amount = 4 },
		},
	},
	{
		recipeId = "Excalion, Blade of Kings",
		weaponId = "Excalion, Blade of Kings",
		rarity = "Legendary",
		requiredLevel = 20,
		unlockSilverCost = 850,
		craftSilverCost = 800,
		unique = true,
		materials = {
			{ id = "Knight Emblem", amount = 6 },
			{ id = "Golem Heart", amount = 4 },
			{ id = "Astral Core", amount = 1 },
		},
	},
	{
		recipeId = "Harvest of the End",
		weaponId = "Harvest of the End",
		rarity = "Legendary",
		requiredLevel = 22,
		unlockSilverCost = 900,
		craftSilverCost = 860,
		unique = true,
		materials = {
			{ id = "Ancient Bark", amount = 6 },
			{ id = "Moon Claw", amount = 4 },
			{ id = "Astral Core", amount = 1 },
		},
	},
	{
		recipeId = "Kingslayer Handcannon",
		weaponId = "Kingslayer Handcannon",
		rarity = "Legendary",
		requiredLevel = 24,
		unlockSilverCost = 940,
		craftSilverCost = 900,
		unique = true,
		materials = {
			{ id = "Inferno Shard", amount = 6 },
			{ id = "Burrow Fin", amount = 4 },
			{ id = "Void Crystal", amount = 4 },
		},
	},
	{
		recipeId = "Archmage's Worldstaff",
		weaponId = "Archmage's Worldstaff",
		rarity = "Mythical",
		requiredLevel = 30,
		unlockSilverCost = 1400,
		craftSilverCost = 1300,
		unique = true,
		materials = {
			{ id = "Inferno Shard", amount = 7 },
			{ id = "Golem Heart", amount = 5 },
			{ id = "Astral Core", amount = 2 },
		},
	},
}

local function addRecipe(def)
	table.insert(recipeList, def)
end

local function mat(id, amount)
	return { id = id, amount = amount }
end

local function addWeaponRecipe(name, rarity, requiredLevel, unlockSilverCost, craftSilverCost, materials)
	addRecipe({
		recipeId = name,
		weaponId = name,
		rarity = rarity,
		requiredLevel = requiredLevel,
		unlockSilverCost = unlockSilverCost,
		craftSilverCost = craftSilverCost,
		unique = true,
		materials = materials,
	})
end

-- Bow catalog additions
addWeaponRecipe("Dawnfeather Bow", "Uncommon", 4, 220, 180, { mat("Material_39", 3), mat("Material_21", 4), mat("Material_05", 1) })
addWeaponRecipe("Emberthorn Bow", "Rare", 8, 340, 300, { mat("Material_08", 4), mat("Material_22", 4), mat("Material_02", 2) })
addWeaponRecipe("Forestbone Bow", "Common", 2, 160, 130, { mat("Material_21", 3), mat("Material_09", 3), mat("Material_20", 2) })
addWeaponRecipe("Frostbranch Bow", "Rare", 10, 380, 330, { mat("Material_03", 3), mat("Material_21", 5), mat("Material_43", 2) })
addWeaponRecipe("Mossfang Bow", "Uncommon", 6, 260, 220, { mat("Material_12", 3), mat("Material_23", 4), mat("Material_04", 2) })
addWeaponRecipe("Shadowcurve Bow", "Epic", 16, 600, 560, { mat("Material_10", 4), mat("Material_32", 3), mat("Material_45", 2) })
addWeaponRecipe("Sunpiercer", "Legendary", 24, 980, 920, { mat("Material_05", 4), mat("Material_37", 2), mat("Material_47", 1) })
addWeaponRecipe("Voidstring Bow", "Epic", 18, 660, 620, { mat("Material_06", 3), mat("Material_28", 3), mat("Material_45", 3) })

-- Halberd catalog additions
addWeaponRecipe("Earthsplitter Halberd", "Epic", 16, 620, 580, { mat("Material_36", 3), mat("Material_14", 8), mat("Material_04", 3) })
addWeaponRecipe("Glacier Halberd", "Rare", 11, 400, 360, { mat("Material_03", 4), mat("Material_16", 4), mat("Material_30", 3) })
addWeaponRecipe("Grovekeeper Halberd", "Rare", 9, 360, 320, { mat("Material_21", 5), mat("Material_22", 5), mat("Material_04", 2) })
addWeaponRecipe("Infernal Halberd", "Epic", 17, 640, 600, { mat("Material_40", 3), mat("Material_08", 5), mat("Material_44", 2) })
addWeaponRecipe("Iron Halberd", "Common", 3, 180, 150, { mat("Material_14", 8), mat("Material_20", 2), mat("Material_34", 3) })
addWeaponRecipe("Nightfang Halberd", "Epic", 18, 680, 630, { mat("Material_10", 4), mat("Material_12", 5), mat("Material_38", 2) })
addWeaponRecipe("Royal Halberd", "Legendary", 23, 940, 880, { mat("Material_46", 3), mat("Material_15", 4), mat("Material_37", 1) })
addWeaponRecipe("Voidguard Halberd", "Epic", 20, 720, 680, { mat("Material_06", 4), mat("Material_45", 3), mat("Material_16", 5) })

-- Pistol / handcannon catalog additions
addWeaponRecipe("Royal Handcannon", "Epic", 18, 680, 630, { mat("Material_46", 2), mat("Material_15", 4), mat("Material_34", 5) })
addWeaponRecipe("Rustlock Pistol", "Common", 4, 200, 160, { mat("Material_33", 5), mat("Material_14", 5), mat("Material_34", 4) })
addWeaponRecipe("Voidlock Handcannon", "Epic", 20, 740, 700, { mat("Material_45", 4), mat("Material_28", 3), mat("Material_34", 6) })

-- Scythe catalog additions
addWeaponRecipe("Bloodfire Scythe", "Epic", 17, 650, 610, { mat("Material_27", 4), mat("Material_40", 3), mat("Material_02", 3) })
addWeaponRecipe("Farmer's Scythe", "Common", 2, 150, 120, { mat("Material_14", 4), mat("Material_21", 3), mat("Material_20", 2) })
addWeaponRecipe("Frost Reaper", "Rare", 12, 430, 390, { mat("Material_03", 4), mat("Material_43", 3), mat("Material_16", 4) })
addWeaponRecipe("Golden Crescent", "Legendary", 22, 900, 850, { mat("Material_15", 5), mat("Material_37", 2), mat("Material_05", 2) })
addWeaponRecipe("Pale Harvest", "Rare", 10, 390, 350, { mat("Material_09", 5), mat("Material_19", 4), mat("Material_30", 3) })
addWeaponRecipe("Plague Crescent", "Epic", 16, 610, 570, { mat("Material_25", 3), mat("Material_23", 5), mat("Material_38", 2) })
addWeaponRecipe("Thorn Reaper", "Rare", 9, 360, 320, { mat("Material_22", 5), mat("Material_13", 3), mat("Material_04", 2) })
addWeaponRecipe("Void Reaper", "Epic", 19, 700, 660, { mat("Material_06", 4), mat("Material_45", 3), mat("Material_48", 1) })

-- Staff / wand catalog additions
addWeaponRecipe("Apprentice Staff", "Common", 3, 180, 150, { mat("Material_26", 3), mat("Material_21", 3), mat("Material_35", 1) })
addWeaponRecipe("Bonecaller Staff", "Rare", 9, 360, 320, { mat("Material_09", 6), mat("Material_38", 2), mat("Material_35", 2) })
addWeaponRecipe("Eclipse Staff", "Epic", 17, 650, 610, { mat("Material_32", 4), mat("Material_05", 2), mat("Material_45", 3) })
addWeaponRecipe("Emerald Staff", "Rare", 8, 330, 290, { mat("Material_04", 4), mat("Material_25", 3), mat("Material_21", 4) })
addWeaponRecipe("Flamecore Staff", "Rare", 11, 420, 380, { mat("Material_08", 4), mat("Material_40", 2), mat("Material_02", 3) })
addWeaponRecipe("Frostgem Wand", "Rare", 10, 390, 350, { mat("Material_03", 4), mat("Material_43", 2), mat("Material_26", 3) })
addWeaponRecipe("Inferno Warstaff", "Epic", 18, 680, 640, { mat("Material_40", 4), mat("Material_44", 2), mat("Material_08", 5) })
addWeaponRecipe("Ironwood Wand", "Uncommon", 5, 240, 200, { mat("Material_21", 4), mat("Material_14", 4), mat("Material_26", 2) })
addWeaponRecipe("Nature's Grasp Staff", "Epic", 16, 600, 560, { mat("Material_24", 4), mat("Material_22", 5), mat("Material_04", 3) })
addWeaponRecipe("Solar Mace Staff", "Legendary", 24, 960, 900, { mat("Material_05", 4), mat("Material_47", 1), mat("Material_15", 5) })
addWeaponRecipe("Void Crescent Staff", "Epic", 19, 700, 660, { mat("Material_06", 4), mat("Material_28", 3), mat("Material_45", 3) })
addWeaponRecipe("Void Crystal Staff", "Epic", 20, 740, 700, { mat("Material_45", 5), mat("Material_48", 1), mat("Material_35", 3) })

-- Sword catalog additions
addWeaponRecipe("Dawnwarden Sword", "Uncommon", 5, 240, 200, { mat("Material_05", 2), mat("Material_14", 5), mat("Material_46", 1) })
addWeaponRecipe("Emberfang Blade", "Rare", 9, 360, 320, { mat("Material_08", 4), mat("Material_12", 4), mat("Material_02", 2) })
addWeaponRecipe("Frostbite Blade", "Rare", 10, 390, 350, { mat("Material_03", 4), mat("Material_16", 4), mat("Material_43", 2) })
addWeaponRecipe("Knights Oath", "Common", 1, 150, 120, { mat("Material_14", 6), mat("Material_09", 2), mat("Material_46", 1) })
addWeaponRecipe("Shadowthorn Sword", "Epic", 16, 620, 580, { mat("Material_10", 4), mat("Material_22", 4), mat("Material_38", 2) })
addWeaponRecipe("Verdant Saber", "Rare", 8, 330, 290, { mat("Material_04", 4), mat("Material_23", 4), mat("Material_14", 5) })
addWeaponRecipe("Voidpiercer", "Epic", 18, 680, 640, { mat("Material_06", 4), mat("Material_45", 3), mat("Material_16", 4) })
addWeaponRecipe("Windglass Blade", "Rare", 11, 410, 360, { mat("Material_07", 2), mat("Material_39", 3), mat("Material_16", 4) })

local recipesById = {}
local mobMaterialsByMobType = {}
local mobMaterialsById = {}
local mineResourcesById = {}
local mineDefsById = {}
local materialDefsById = {}
local materialList = {}
local materialListById = {}

for _, def in ipairs(CraftingConfig.MOB_MATERIAL_DEFS) do
	mobMaterialsByMobType[def.mobType] = def.id
	mobMaterialsById[def.id] = def
	local canonicalId = MaterialDefinitions.ResolveId(def.id)
	materialDefsById[def.id] = {
		id = canonicalId,
		name = (MaterialDefinitions.Get(canonicalId) and MaterialDefinitions.Get(canonicalId).displayName) or def.id,
		bucket = "mobMaterials",
		source = "Mob Drop",
		mobType = def.mobType,
		rarity = def.rarity,
		legacyId = def.id,
	}
end

for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS) do
	mineResourcesById[def.id] = def
	local canonicalId = MaterialDefinitions.ResolveId(def.id)
	materialDefsById[def.id] = {
		id = canonicalId,
		name = (MaterialDefinitions.Get(canonicalId) and MaterialDefinitions.Get(canonicalId).displayName) or def.id,
		bucket = "mineResources",
		source = "Mining",
		rarity = def.rarity,
		legacyId = def.id,
	}
end

local MINE_MATERIAL_IDS = {
	Material_01 = true,
	Material_02 = true,
	Material_03 = true,
	Material_04 = true,
	Material_05 = true,
	Material_06 = true,
	Material_07 = true,
	Material_08 = true,
	Material_14 = true,
	Material_15 = true,
	Material_16 = true,
	Material_29 = true,
	Material_33 = true,
	Material_34 = true,
	Material_35 = true,
	Material_36 = true,
	Material_37 = true,
	Material_38 = true,
	Material_45 = true,
}

for _, def in ipairs(MaterialDefinitions.GetAll()) do
	if def.id ~= "Materials" then
		local bucket = MINE_MATERIAL_IDS[def.id] and "mineResources" or "mobMaterials"
		local entry = {
			id = def.id,
			name = def.displayName,
			displayName = def.displayName,
			filename = def.filename,
			icon = def.icon,
			bucket = bucket,
			source = bucket == "mineResources" and "Mining" or "Material Drop",
			rarity = def.rarity,
			legacyAliases = def.legacyAliases,
		}
		materialDefsById[def.id] = entry
		materialListById[def.id] = entry
		for _, alias in ipairs(def.legacyAliases or {}) do
			materialDefsById[alias] = entry
		end
	end
end

for _, def in ipairs(MaterialDefinitions.GetAll()) do
	if materialListById[def.id] then
		table.insert(materialList, materialListById[def.id])
	end
end

for _, recipe in ipairs(recipeList) do
	local normalizedMaterials = {}
	for _, entry in ipairs(recipe.materials or {}) do
		local materialId = MaterialDefinitions.ResolveId(entry.id)
		local materialDef = materialDefsById[materialId] or materialDefsById[entry.id]
		local amount = math.max(1, math.floor(tonumber(entry.amount) or 0))
		if materialDef and amount > 0 then
			table.insert(normalizedMaterials, {
				id = materialId,
				name = entry.name or materialDef.name or materialDef.displayName or materialId,
				amount = amount,
			})
		end
	end
	recipe.unique = recipe.unique ~= false
	recipe.materials = normalizedMaterials
	recipe.mobMaterials = {}
	recipe.mineResources = {}
	for _, entry in ipairs(recipe.materials) do
		local materialDef = materialDefsById[entry.id]
		local bucket = materialDef and materialDef.bucket or nil
		if bucket == "mineResources" then
			table.insert(recipe.mineResources, {
				id = entry.id,
				name = entry.name,
				amount = entry.amount,
			})
		else
			table.insert(recipe.mobMaterials, {
				id = entry.id,
				name = entry.name,
				amount = entry.amount,
			})
		end
	end
	recipesById[recipe.recipeId] = recipe
end

for _, mineDef in ipairs(mineList) do
	mineDefsById[mineDef.id] = mineDef
end

local function clampTier(tier)
	tier = math.floor(tonumber(tier) or 1)
	if tier < 1 then
		return 1
	end
	if tier > #CraftingConfig.RECIPE_TIER_MULTIPLIERS then
		return #CraftingConfig.RECIPE_TIER_MULTIPLIERS
	end
	return tier
end

local function scaleRequirementList(list, multiplier)
	local out = {}
	for _, entry in ipairs(list or {}) do
		local amount = math.max(1, math.floor((tonumber(entry.amount) or 0) * multiplier + 0.5))
		table.insert(out, {
			id = entry.id,
			name = entry.name,
			amount = amount,
		})
	end
	return out
end

function CraftingConfig.GetAllRecipes()
	return recipeList
end

function CraftingConfig.GetRecipe(recipeId)
	return recipesById[recipeId]
end

function CraftingConfig.GetMobMaterialForMob(mobType)
	return mobMaterialsByMobType[mobType]
end

function CraftingConfig.GetDefaultMinePriority(mineId)
	local priority = {}
	local seen = {}
	local defaultMine = CraftingConfig.GetMine(mineId) or mineList[1]
	if defaultMine and typeof(defaultMine.drops) == "table" then
		for _, entry in ipairs(defaultMine.drops) do
			if typeof(entry.id) == "string" and entry.id ~= "" and not seen[entry.id] then
				seen[entry.id] = true
				table.insert(priority, entry.id)
			end
		end
	end
	for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS) do
		if not seen[def.id] then
			table.insert(priority, def.id)
		end
	end
	return priority
end

function CraftingConfig.GetAllMines()
	return mineList
end

function CraftingConfig.GetDefaultMineId()
	return mineList[1] and mineList[1].id or nil
end

function CraftingConfig.GetMine(mineId)
	if typeof(mineId) ~= "string" or mineId == "" then
		return nil
	end
	return mineDefsById[mineId]
end

function CraftingConfig.GetMineDropChanceList(mineId)
	local mine = CraftingConfig.GetMine(mineId) or mineList[1]
	if not mine or typeof(mine.drops) ~= "table" then
		return {}
	end

	local totalWeight = 0
	for _, entry in ipairs(mine.drops) do
		totalWeight += math.max(0, math.floor(tonumber(entry.weight) or 0))
	end
	if totalWeight <= 0 then
		return {}
	end

	local out = {}
	for _, entry in ipairs(mine.drops) do
		local weight = math.max(0, math.floor(tonumber(entry.weight) or 0))
		if typeof(entry.id) == "string" and entry.id ~= "" and weight > 0 then
			local baseDef = CraftingConfig.GetMineResource(entry.id) or {}
			local yieldMin = math.max(1, math.floor(tonumber(entry.yieldMin or baseDef.yieldMin) or 1))
			local yieldMax = math.max(yieldMin, math.floor(tonumber(entry.yieldMax or baseDef.yieldMax or yieldMin) or yieldMin))
			table.insert(out, {
				id = entry.id,
				weight = weight,
				chance = weight / totalWeight,
				yieldMin = yieldMin,
				yieldMax = yieldMax,
				rarity = baseDef.rarity,
				color = baseDef.color,
			})
		end
	end
	return out
end

function CraftingConfig.GetMineResource(resourceId)
	return mineResourcesById[resourceId]
end

function CraftingConfig.GetMobMaterial(materialId)
	return mobMaterialsById[materialId]
end

function CraftingConfig.GetMaterialDef(materialId)
	local canonicalId = MaterialDefinitions.ResolveId(materialId)
	return materialDefsById[canonicalId] or materialDefsById[materialId]
end

function CraftingConfig.GetMaterialBucket(materialId)
	local def = CraftingConfig.GetMaterialDef(materialId)
	return def and def.bucket or nil
end

function CraftingConfig.GetAllMaterials()
	return materialList
end

function CraftingConfig.ResolveMaterialId(materialId)
	return MaterialDefinitions.ResolveId(materialId)
end

function CraftingConfig.GetMaterialAliases(materialId)
	local def = MaterialDefinitions.Get(materialId)
	return def and def.legacyAliases or {}
end

function CraftingConfig.GetRecipeTierFromCopies(copies)
	copies = math.max(0, math.floor(tonumber(copies) or 0))
	local tier = 1
	for index, threshold in ipairs(CraftingConfig.RECIPE_DUPLICATE_THRESHOLDS) do
		if copies >= threshold then
			tier = index
		end
	end
	return clampTier(tier)
end

function CraftingConfig.GetNextTierCopyTarget(tier)
	tier = clampTier(tier)
	return CraftingConfig.RECIPE_DUPLICATE_THRESHOLDS[tier + 1]
end

function CraftingConfig.GetRecipeTierMultiplier(tier)
	return CraftingConfig.RECIPE_TIER_MULTIPLIERS[clampTier(tier)] or 1
end

function CraftingConfig.GetRecipeTierStatBonus(tier)
	return CraftingConfig.RECIPE_TIER_STAT_BONUS[clampTier(tier)] or 1
end

function CraftingConfig.GetRecipeTierPrefix(tier)
	return CraftingConfig.RECIPE_TIER_PREFIX[clampTier(tier)] or CraftingConfig.RECIPE_TIER_PREFIX[1]
end

function CraftingConfig.BuildRecipeRequirements(recipeId, tier)
	local recipe = CraftingConfig.GetRecipe(recipeId)
	if not recipe then
		return nil
	end

	local multiplier = CraftingConfig.GetRecipeTierMultiplier(tier)
	local materials = scaleRequirementList(recipe.materials, multiplier)
	local mineResources = {}
	local mobMaterials = {}
	for _, entry in ipairs(materials) do
		local bucket = CraftingConfig.GetMaterialBucket(entry.id)
		if bucket == "mineResources" then
			table.insert(mineResources, entry)
		else
			table.insert(mobMaterials, entry)
		end
	end
	return {
		unlockSilverCost = math.max(0, math.floor(tonumber(recipe.unlockSilverCost) or 0)),
		craftSilverCost = math.max(0, math.floor((tonumber(recipe.craftSilverCost) or 0) * multiplier + 0.5)),
		materials = materials,
		mobMaterials = mobMaterials,
		mineResources = mineResources,
		unique = recipe.unique == true,
	}
end

local function getRecipeDropWeight(rarity)
	if rarity == "Common" then
		return 55
	end
	if rarity == "Uncommon" then
		return 36
	end
	if rarity == "Rare" then
		return 25
	end
	if rarity == "Epic" then
		return 12
	end
	if rarity == "Legendary" then
		return 6
	end
	if rarity == "Mythical" or rarity == "Mythic" then
		return 2
	end
	return 1
end

function CraftingConfig.RollRecipeId(randomSource)
	local rng = randomSource or Random.new()
	local total = 0
	for _, recipe in ipairs(recipeList) do
		total += getRecipeDropWeight(recipe.rarity)
	end
	if total <= 0 then
		return nil
	end

	local pick = rng:NextNumber(0, total)
	local acc = 0
	for _, recipe in ipairs(recipeList) do
		acc += getRecipeDropWeight(recipe.rarity)
		if pick <= acc then
			return recipe.recipeId
		end
	end
	return recipeList[#recipeList] and recipeList[#recipeList].recipeId or nil
end

function CraftingConfig.GetUpgradeCost(rarity, currentLevel, maxLevel)
	local cfg = CraftingConfig.UPGRADE_COSTS[rarity] or CraftingConfig.UPGRADE_COSTS.Common
	local level = math.max(1, math.floor(tonumber(currentLevel) or 1))
	local silver = math.max(1, math.floor((cfg.silverBase or 0) + (cfg.silverPerLevel or 0) * level))
	local crystals = math.max(1, math.floor((cfg.crystalsBase or 1) + math.floor(level / 10) * (cfg.crystalsPer10 or 0)))
	local nextLevel = math.min(math.max(level + 1, 1), math.max(1, math.floor(tonumber(maxLevel) or level + 1)))
	local special = CraftingConfig.UPGRADE_SPECIAL_THRESHOLDS[nextLevel]

	return {
		silver = silver,
		crystals = crystals,
		special = special and {
			id = special.id,
			amount = special.amount,
		} or nil,
	}
end

CraftingConfig.Recipes = recipeList
CraftingConfig.RecipesById = recipesById
CraftingConfig.MobMaterialsByMobType = mobMaterialsByMobType
CraftingConfig.MobMaterialsById = mobMaterialsById
CraftingConfig.MineResourcesById = mineResourcesById
CraftingConfig.MineDefsById = mineDefsById
CraftingConfig.MaterialDefsById = materialDefsById

return CraftingConfig
