local CraftingConfig = {}

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
	Rare = { silverBase = 80, silverPerLevel = 34, crystalsBase = 2, crystalsPer10 = 1 },
	Epic = { silverBase = 115, silverPerLevel = 48, crystalsBase = 3, crystalsPer10 = 1 },
	Legendary = { silverBase = 160, silverPerLevel = 64, crystalsBase = 4, crystalsPer10 = 2 },
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
		mobMaterials = {
			{ id = "Slime Gem", amount = 4 },
			{ id = "Bone Core", amount = 2 },
		},
		mineResources = {
			{ id = "Iron Ore", amount = 6 },
			{ id = "Coal Chunk", amount = 3 },
		},
	},
	{
		recipeId = "Hunter's Longbow",
		weaponId = "Hunter's Longbow",
		rarity = "Common",
		requiredLevel = 1,
		unlockSilverCost = 150,
		craftSilverCost = 120,
		mobMaterials = {
			{ id = "Raider Fang", amount = 4 },
			{ id = "Slime Gem", amount = 2 },
		},
		mineResources = {
			{ id = "Iron Ore", amount = 5 },
			{ id = "Emberstone", amount = 2 },
		},
	},
	{
		recipeId = "Warden's Halberd",
		weaponId = "Warden's Halberd",
		rarity = "Rare",
		requiredLevel = 5,
		unlockSilverCost = 300,
		craftSilverCost = 260,
		mobMaterials = {
			{ id = "Rotbone", amount = 5 },
			{ id = "Knight Emblem", amount = 3 },
		},
		mineResources = {
			{ id = "Iron Ore", amount = 6 },
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
		mobMaterials = {
			{ id = "Siren Feather", amount = 4 },
			{ id = "Bone Core", amount = 3 },
		},
		mineResources = {
			{ id = "Coal Chunk", amount = 4 },
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
		mobMaterials = {
			{ id = "Raider Fang", amount = 4 },
			{ id = "Burrow Fin", amount = 2 },
		},
		mineResources = {
			{ id = "Iron Ore", amount = 5 },
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
		mobMaterials = {
			{ id = "Moon Claw", amount = 5 },
			{ id = "Ancient Bark", amount = 3 },
		},
		mineResources = {
			{ id = "Moonsteel Ore", amount = 5 },
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
		mobMaterials = {
			{ id = "Inferno Shard", amount = 5 },
			{ id = "Golem Heart", amount = 2 },
		},
		mineResources = {
			{ id = "Moonsteel Ore", amount = 4 },
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
		mobMaterials = {
			{ id = "Siren Feather", amount = 5 },
			{ id = "Moon Claw", amount = 3 },
		},
		mineResources = {
			{ id = "Emberstone", amount = 5 },
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
		mobMaterials = {
			{ id = "Knight Emblem", amount = 6 },
			{ id = "Golem Heart", amount = 4 },
		},
		mineResources = {
			{ id = "Void Crystal", amount = 4 },
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
		mobMaterials = {
			{ id = "Ancient Bark", amount = 6 },
			{ id = "Moon Claw", amount = 4 },
		},
		mineResources = {
			{ id = "Moonsteel Ore", amount = 6 },
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
		mobMaterials = {
			{ id = "Inferno Shard", amount = 6 },
			{ id = "Burrow Fin", amount = 4 },
		},
		mineResources = {
			{ id = "Void Crystal", amount = 4 },
			{ id = "Astral Core", amount = 1 },
		},
	},
	{
		recipeId = "Archmage's Worldstaff",
		weaponId = "Archmage's Worldstaff",
		rarity = "Mythical",
		requiredLevel = 30,
		unlockSilverCost = 1400,
		craftSilverCost = 1300,
		mobMaterials = {
			{ id = "Inferno Shard", amount = 7 },
			{ id = "Golem Heart", amount = 5 },
			{ id = "Ancient Bark", amount = 5 },
		},
		mineResources = {
			{ id = "Void Crystal", amount = 6 },
			{ id = "Astral Core", amount = 2 },
		},
	},
}

local recipesById = {}
local mobMaterialsByMobType = {}
local mobMaterialsById = {}
local mineResourcesById = {}
local mineDefsById = {}
local materialDefsById = {}
local materialList = {}

for _, def in ipairs(CraftingConfig.MOB_MATERIAL_DEFS) do
	mobMaterialsByMobType[def.mobType] = def.id
	mobMaterialsById[def.id] = def
	materialDefsById[def.id] = {
		id = def.id,
		name = def.id,
		bucket = "mobMaterials",
		source = "Mob Drop",
		mobType = def.mobType,
		rarity = def.rarity,
	}
	table.insert(materialList, materialDefsById[def.id])
end

for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS) do
	mineResourcesById[def.id] = def
	materialDefsById[def.id] = {
		id = def.id,
		name = def.id,
		bucket = "mineResources",
		source = "Mining",
		rarity = def.rarity,
	}
	table.insert(materialList, materialDefsById[def.id])
end

for _, recipe in ipairs(recipeList) do
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
	return materialDefsById[materialId]
end

function CraftingConfig.GetMaterialBucket(materialId)
	local def = materialDefsById[materialId]
	return def and def.bucket or nil
end

function CraftingConfig.GetAllMaterials()
	return materialList
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
	return {
		unlockSilverCost = math.max(0, math.floor(tonumber(recipe.unlockSilverCost) or 0)),
		craftSilverCost = math.max(0, math.floor((tonumber(recipe.craftSilverCost) or 0) * multiplier + 0.5)),
		mobMaterials = scaleRequirementList(recipe.mobMaterials, multiplier),
		mineResources = scaleRequirementList(recipe.mineResources, multiplier),
	}
end

local function getRecipeDropWeight(rarity)
	if rarity == "Common" then
		return 55
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
	if rarity == "Mythical" then
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
