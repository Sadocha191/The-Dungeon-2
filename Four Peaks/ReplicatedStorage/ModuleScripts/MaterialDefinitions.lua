local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MaterialDefinitions = {}

local GENERIC_MATERIAL_ICON = "rbxassetid://131919779963114"
local ICON_FOLDER_NAME = "MaterialIcons"

local rawMaterials = {
	{
		id = "Material_01",
		iconName = "Material_01",
		filename = "Material_01.jpg",
		displayName = "Violet Crystal",
		rarity = "Rare",
		description = "Arcane crystal pulsing with violet light.",
		source = "Deep mine veins, arcane chests, void-touched elites.",
	},
	{
		id = "Material_02",
		iconName = "Material_02",
		filename = "Material_02.jpg",
		displayName = "Crimson Crystal",
		rarity = "Rare",
		description = "Blood-warm crystal used for fire-forged weapons.",
		source = "Lava seams, scorched chests, fire beasts.",
	},
	{
		id = "Material_03",
		iconName = "Material_03",
		filename = "Material_03.jpg",
		displayName = "Frost Crystal",
		rarity = "Rare",
		description = "Frozen shard that holds winter magic.",
		source = "Ice caves, frozen chests, frost enemies.",
	},
	{
		id = "Material_04",
		iconName = "Material_04",
		filename = "Material_04.jpg",
		displayName = "Verdant Crystal",
		rarity = "Rare",
		description = "Living crystal wrapped in old forest energy.",
		source = "Forest nodes, nature shrines, wild guardians.",
	},
	{
		id = "Material_05",
		iconName = "Material_05",
		filename = "Material_05.jpg",
		displayName = "Sun Crystal",
		rarity = "Epic",
		description = "Radiant crystal tempered by daylight.",
		source = "Sunlit ruins, elite chests, holy enemies.",
	},
	{
		id = "Material_06",
		iconName = "Material_06",
		filename = "Material_06.jpg",
		displayName = "Void Orb",
		rarity = "Epic",
		description = "Dense orb of collapsing void matter.",
		source = "Void rifts, cursed chests, abyssal elites.",
	},
	{
		id = "Material_07",
		iconName = "Material_07",
		filename = "Material_07.jpg",
		displayName = "Moonshard Crystal",
		rarity = "Epic",
		description = "Pale crystal cut from moonlit stone.",
		source = "Night events, silver chests, lunar beasts.",
	},
	{
		id = "Material_08",
		iconName = "Material_08",
		filename = "Material_08.jpg",
		displayName = "Ember Core",
		rarity = "Uncommon",
		description = "Smoldering core from creatures of flame.",
		source = "Fire enemies, ember nests, hot caverns.",
		legacyAliases = { "Emberstone" },
	},
	{
		id = "Material_09",
		iconName = "Material_09",
		filename = "Material_09.jpg",
		displayName = "Ancient Bone",
		rarity = "Common",
		description = "Weathered bone still heavy with old power.",
		source = "Skeletons, burial chests, grave halls.",
		legacyAliases = { "Rotbone", "Bone Core" },
	},
	{
		id = "Material_10",
		iconName = "Material_10",
		filename = "Material_10.jpg",
		displayName = "Shadow Claw",
		rarity = "Rare",
		description = "Predator claw steeped in shadow.",
		source = "Night stalkers, cursed woods, shadow elites.",
		legacyAliases = { "Moon Claw" },
	},
	{
		id = "Material_11",
		iconName = "Material_11",
		filename = "Material_11.jpg",
		displayName = "Beast Horn",
		rarity = "Common",
		description = "Hardened horn prized for sturdy weaponwork.",
		source = "Beasts, hunting grounds, beast dens.",
	},
	{
		id = "Material_12",
		iconName = "Material_12",
		filename = "Material_12.jpg",
		displayName = "Ivory Fang",
		rarity = "Common",
		description = "Sharp fang taken from savage hunters.",
		source = "Predators, hunter packs, bone chests.",
		legacyAliases = { "Raider Fang" },
	},
	{
		id = "Material_13",
		iconName = "Material_13",
		filename = "Material_13.jpg",
		displayName = "Spiked Scale",
		rarity = "Uncommon",
		description = "Jagged scale that hardens crafted edges.",
		source = "Scaled enemies, marsh beasts, guarded chests.",
	},
	{
		id = "Material_14",
		iconName = "Material_14",
		filename = "Material_14.jpg",
		displayName = "Iron Ore",
		rarity = "Common",
		description = "Basic metal used in weapon crafting.",
		source = "Mine, chests, armored enemies.",
		legacyAliases = { "Iron Ore" },
	},
	{
		id = "Material_15",
		iconName = "Material_15",
		filename = "Material_15.jpg",
		displayName = "Gold Ingot",
		rarity = "Rare",
		description = "Refined gold bar used in noble weaponwork.",
		source = "Treasure rooms, vault chests, royal enemies.",
	},
	{
		id = "Material_16",
		iconName = "Material_16",
		filename = "Material_16.jpg",
		displayName = "Silver Ingot",
		rarity = "Uncommon",
		description = "Bright ingot favored for balanced forging.",
		source = "Mines, merchant chests, knight enemies.",
		legacyAliases = { "Moonsteel Ore" },
	},
	{
		id = "Material_17",
		iconName = "Material_17",
		filename = "Material_17.jpg",
		displayName = "Tanned Leather",
		rarity = "Common",
		description = "Worked leather for grips, wraps, and straps.",
		source = "Crafting drops, beast hides, supply chests.",
	},
	{
		id = "Material_18",
		iconName = "Material_18",
		filename = "Material_18.jpg",
		displayName = "Worn Hide",
		rarity = "Common",
		description = "Rough hide stripped from hardy creatures.",
		source = "Beasts, camps, hunter caches.",
	},
	{
		id = "Material_19",
		iconName = "Material_19",
		filename = "Material_19.jpg",
		displayName = "Torn Cloth",
		rarity = "Common",
		description = "Frayed cloth useful for bindings and charms.",
		source = "Bandits, crates, old chests.",
	},
	{
		id = "Material_20",
		iconName = "Material_20",
		filename = "Material_20.jpg",
		displayName = "Rope",
		rarity = "Common",
		description = "Braided rope used for bowstrings and rigging.",
		source = "Supply crates, docks, camps.",
	},
	{
		id = "Material_21",
		iconName = "Material_21",
		filename = "Material_21.jpg",
		displayName = "Ancient Wood",
		rarity = "Uncommon",
		description = "Old-growth timber fit for enchanted shafts.",
		source = "Forest guardians, ancient groves, hidden chests.",
		legacyAliases = { "Ancient Bark" },
	},
	{
		id = "Material_22",
		iconName = "Material_22",
		filename = "Material_22.jpg",
		displayName = "Root Fragment",
		rarity = "Common",
		description = "Knotted root piece rich with earth magic.",
		source = "Forest floors, root enemies, grove chests.",
	},
	{
		id = "Material_23",
		iconName = "Material_23",
		filename = "Material_23.jpg",
		displayName = "Wild Herb",
		rarity = "Common",
		description = "Common herb used in basic brews and binding paste.",
		source = "Fields, herb nodes, nature enemies.",
	},
	{
		id = "Material_24",
		iconName = "Material_24",
		filename = "Material_24.jpg",
		displayName = "Nature Wisp",
		rarity = "Uncommon",
		description = "Flickering mote of living forest essence.",
		source = "Spirit groves, druid enemies, green chests.",
		legacyAliases = { "Slime Gem" },
	},
	{
		id = "Material_25",
		iconName = "Material_25",
		filename = "Material_25.jpg",
		displayName = "Green Elixir",
		rarity = "Uncommon",
		description = "Restorative elixir mixed for druidic craft.",
		source = "Alchemy drops, herb caches, support enemies.",
	},
	{
		id = "Material_26",
		iconName = "Material_26",
		filename = "Material_26.jpg",
		displayName = "Mana Potion",
		rarity = "Uncommon",
		description = "Concentrated potion that feeds arcane tools.",
		source = "Mage enemies, study chests, potion racks.",
	},
	{
		id = "Material_27",
		iconName = "Material_27",
		filename = "Material_27.jpg",
		displayName = "Blood Vial",
		rarity = "Rare",
		description = "Sealed vial of potent monster blood.",
		source = "Vampiric foes, ritual chests, butcher rooms.",
	},
	{
		id = "Material_28",
		iconName = "Material_28",
		filename = "Material_28.jpg",
		displayName = "Void Flask",
		rarity = "Epic",
		description = "Glass vessel holding unstable void residue.",
		source = "Void priests, abyss chests, rift events.",
	},
	{
		id = "Material_29",
		iconName = "Material_29",
		filename = "Material_29.jpg",
		displayName = "Coin Pouch",
		rarity = "Common",
		description = "A pouch of mixed coin and trade scrap.",
		source = "Chests, thieves, roadside loot.",
	},
	{
		id = "Material_30",
		iconName = "Material_30",
		filename = "Material_30.jpg",
		displayName = "Pure Water",
		rarity = "Common",
		description = "Clear water used to temper and cleanse materials.",
		source = "Wells, river caches, shrine basins.",
	},
	{
		id = "Material_31",
		iconName = "Material_31",
		filename = "Material_31.jpg",
		displayName = "Tide Core",
		rarity = "Rare",
		description = "Waterlogged core carrying tidal force.",
		source = "Water enemies, flooded ruins, tide chests.",
		legacyAliases = { "Burrow Fin" },
	},
	{
		id = "Material_32",
		iconName = "Material_32",
		filename = "Material_32.jpg",
		displayName = "Dark Droplet",
		rarity = "Rare",
		description = "A heavy droplet condensed from darkness.",
		source = "Shadow enemies, cursed pools, black chests.",
	},
	{
		id = "Material_33",
		iconName = "Material_33",
		filename = "Material_33.jpg",
		displayName = "Rusted Gear",
		rarity = "Common",
		description = "Broken gear salvaged from old machines.",
		source = "Constructs, workshops, ruin chests.",
		legacyAliases = { "Golem Heart" },
	},
	{
		id = "Material_34",
		iconName = "Material_34",
		filename = "Material_34.jpg",
		displayName = "Coal Chunk",
		rarity = "Common",
		description = "Common fuel stone for any serious forge.",
		source = "Mine, chests, furnace enemies.",
		legacyAliases = { "Coal Chunk" },
	},
	{
		id = "Material_35",
		iconName = "Material_35",
		filename = "Material_35.jpg",
		displayName = "Rune Stone",
		rarity = "Rare",
		description = "Engraved stone that anchors enchantments.",
		source = "Ruins, rune shrines, caster elites.",
		legacyAliases = { "Astral Core", "Upgrade Crystal" },
	},
	{
		id = "Material_36",
		iconName = "Material_36",
		filename = "Material_36.jpg",
		displayName = "Stone Tablet",
		rarity = "Rare",
		description = "Fragment of an ancient inscribed tablet.",
		source = "Ruins, puzzle rooms, guardian enemies.",
	},
	{
		id = "Material_37",
		iconName = "Material_37",
		filename = "Material_37.jpg",
		displayName = "Golden Compass",
		rarity = "Epic",
		description = "Relic compass that points toward hidden power.",
		source = "Treasure vaults, elite chests, expedition bosses.",
	},
	{
		id = "Material_38",
		iconName = "Material_38",
		filename = "Material_38.jpg",
		displayName = "Cursed Sigil",
		rarity = "Epic",
		description = "Dark sigil marked with forbidden vows.",
		source = "Cursed elites, ritual circles, haunted chests.",
		legacyAliases = { "Elite Sigil" },
	},
	{
		id = "Material_39",
		iconName = "Material_39",
		filename = "Material_39.jpg",
		displayName = "Silver Feather",
		rarity = "Rare",
		description = "Lustrous feather used in light and wind craft.",
		source = "Flying enemies, moonlit chests, avian elites.",
		legacyAliases = { "Siren Feather" },
	},
	{
		id = "Material_40",
		iconName = "Material_40",
		filename = "Material_40.jpg",
		displayName = "Shadow Flame",
		rarity = "Epic",
		description = "Cold fire harvested from cursed infernos.",
		source = "Demon fires, void elites, infernal rooms.",
		legacyAliases = { "Inferno Shard" },
	},
	{
		id = "Material_41",
		iconName = "Material_41",
		filename = "Material_41.jpg",
		displayName = "Dragon Scale",
		rarity = "Legendary",
		description = "Massive scale from an ancient drake.",
		source = "Dragon foes, boss chests, volcanic lairs.",
		legacyAliases = { "Boss Core" },
	},
	{
		id = "Material_42",
		iconName = "Material_42",
		filename = "Material_42.jpg",
		displayName = "Bat Wing",
		rarity = "Common",
		description = "Thin wing membrane used in dark bindings.",
		source = "Bats, cave swarms, night chests.",
	},
	{
		id = "Material_43",
		iconName = "Material_43",
		filename = "Material_43.jpg",
		displayName = "Frost Feather",
		rarity = "Rare",
		description = "Icy feather that keeps a chill edge.",
		source = "Frost birds, ice nests, frozen chests.",
	},
	{
		id = "Material_44",
		iconName = "Material_44",
		filename = "Material_44.jpg",
		displayName = "Demon Horn",
		rarity = "Epic",
		description = "Warped horn humming with infernal heat.",
		source = "Demons, boss arenas, cursed vaults.",
	},
	{
		id = "Material_45",
		iconName = "Material_45",
		filename = "Material_45.jpg",
		displayName = "Void Crystal",
		rarity = "Epic",
		description = "Crystal shard saturated with abyssal energy.",
		source = "Void events, rift bosses, abyss chests.",
		legacyAliases = { "Void Crystal" },
	},
	{
		id = "Material_46",
		iconName = "Material_46",
		filename = "Material_46.jpg",
		displayName = "Royal Crest",
		rarity = "Legendary",
		description = "Noble insignia salvaged from fallen rulers.",
		source = "Knights, royal vaults, palace elites.",
		legacyAliases = { "Knight Emblem" },
	},
	{
		id = "Material_47",
		iconName = "Material_47",
		filename = "Material_47.jpg",
		displayName = "Angel Wing",
		rarity = "Legendary",
		description = "Sacred wing fragment bright with celestial grace.",
		source = "Holy enemies, shrine chests, radiant bosses.",
	},
	{
		id = "Material_48",
		iconName = "Material_48",
		filename = "Material_48.jpg",
		displayName = "Void Eye",
		rarity = "Mythic",
		description = "Watching eye from the deepest void.",
		source = "Void lords, final chests, abyss bosses.",
	},
	{
		id = "Materials",
		iconName = "materials_icon",
		filename = "materials icon.png",
		displayName = "Materials",
		rarity = "Common",
		description = "Shared material symbol used in crafting summaries.",
		source = "Blacksmith UI summary icon.",
		legacyAliases = { "materials_icon", "materials icon.png" },
	},
}

local list = {}
local byId = {}
local aliasToId = {}
local iconFolderCache = nil

local function trimExtension(value)
	if typeof(value) ~= "string" or value == "" then
		return nil
	end
	return (value:gsub("%.[%w]+$", ""))
end

local function normalizeIconKey(value)
	if typeof(value) ~= "string" or value == "" then
		return nil
	end
	local normalized = trimExtension(value) or value
	normalized = normalized:gsub("%s+", "_")
	return normalized ~= "" and normalized or nil
end

local function addAlias(alias, materialId)
	if typeof(alias) ~= "string" or alias == "" then
		return
	end
	aliasToId[alias] = materialId
end

local function getIconFolder()
	if iconFolderCache and iconFolderCache.Parent then
		return iconFolderCache
	end
	iconFolderCache = ReplicatedStorage:FindFirstChild(ICON_FOLDER_NAME)
	return iconFolderCache
end

local function readAssetReference(iconObject)
	if not iconObject then
		return nil
	end

	local value = nil
	if iconObject:IsA("StringValue") then
		value = iconObject.Value
	elseif iconObject:IsA("ImageLabel") or iconObject:IsA("ImageButton") then
		value = iconObject.Image
	elseif iconObject:IsA("Decal") or iconObject:IsA("Texture") then
		value = iconObject.Texture
	end

	if typeof(value) == "string" and value ~= "" then
		return value
	end

	return nil
end

local function getIconCandidates(def)
	local candidates = {}
	local seen = {}

	local function push(value)
		if typeof(value) ~= "string" or value == "" or seen[value] then
			return
		end
		seen[value] = true
		table.insert(candidates, value)
	end

	push(def.iconName)
	push(def.filename)
	push(trimExtension(def.filename))
	push(normalizeIconKey(def.filename))
	push(normalizeIconKey(def.iconName))

	return candidates
end

local function resolveAssetRef(def)
	if typeof(def.assetRef) == "string" and def.assetRef ~= "" then
		return def.assetRef
	end

	local folder = getIconFolder()
	if folder then
		for _, candidate in ipairs(getIconCandidates(def)) do
			local iconObject = folder:FindFirstChild(candidate)
			local assetRef = readAssetReference(iconObject)
			if assetRef then
				def.assetRef = assetRef
				def._missingIconWarned = nil
				return assetRef
			end
		end
	end

	if def.id == "Materials" then
		def.assetRef = GENERIC_MATERIAL_ICON
		return def.assetRef
	end

	if not def._missingIconWarned then
		warn("Missing material icon:", def.id, def.iconName)
		def._missingIconWarned = true
	end

	def.assetRef = nil
	return nil
end

for _, entry in ipairs(rawMaterials) do
	local def = {
		id = entry.id,
		iconName = entry.iconName,
		filename = entry.filename,
		displayName = entry.displayName,
		name = entry.displayName,
		rarity = entry.rarity,
		description = entry.description,
		source = entry.source,
		legacyAliases = entry.legacyAliases or {},
		assetRef = nil,
	}
	table.insert(list, def)
	byId[def.id] = def

	addAlias(def.id, def.id)
	addAlias(def.displayName, def.id)
	addAlias(def.filename, def.id)
	addAlias(def.iconName, def.id)
	addAlias(trimExtension(def.filename), def.id)
	addAlias(normalizeIconKey(def.filename), def.id)

	for _, alias in ipairs(def.legacyAliases) do
		addAlias(alias, def.id)
	end
end

function MaterialDefinitions.ResolveId(materialId)
	if typeof(materialId) ~= "string" or materialId == "" then
		return materialId
	end
	return aliasToId[materialId] or materialId
end

function MaterialDefinitions.Get(materialId)
	local def = byId[MaterialDefinitions.ResolveId(materialId)]
	if def then
		resolveAssetRef(def)
	end
	return def
end

function MaterialDefinitions.GetAll()
	return list
end

function MaterialDefinitions.GetAssetRef(materialId)
	local def = MaterialDefinitions.Get(materialId)
	return def and resolveAssetRef(def) or nil
end

function MaterialDefinitions.GetSummaryIcon()
	return MaterialDefinitions.GetAssetRef("Materials") or GENERIC_MATERIAL_ICON
end

function MaterialDefinitions.GetGenericIcon()
	return GENERIC_MATERIAL_ICON
end

function MaterialDefinitions.RefreshAssetRefs()
	iconFolderCache = nil
	for _, def in ipairs(list) do
		def.assetRef = nil
		def._missingIconWarned = nil
	end
end

MaterialDefinitions.List = list
MaterialDefinitions.ById = byId
MaterialDefinitions.AliasToId = aliasToId

return MaterialDefinitions
