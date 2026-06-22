local GuildConfig = {}

GuildConfig.GUILD_PLACE_ID = 89635326813830

-- Four Peaks lobby place id. Update this if the lobby is republished under a different place.
GuildConfig.LOBBY_PLACE_ID = 88516424167732

-- Treasury resource mapping:
-- Silver -> player profile `silver`
-- Souls -> player profile `souls`
-- Tickets -> player profile `tickets`
-- WeaponPoints -> player profile `weaponPoints`
-- MobMaterial:<id> -> player profile `crafting.mobMaterials[id]`
-- UpgradeMaterial:<id> -> player profile `crafting.upgradeMaterials[id]`
-- MineResource:<id> -> player profile `crafting.mineResources[id]`
GuildConfig.TREASURY_CURRENCY_RESOURCES = {
	{
		id = "Silver",
		displayName = "Silver",
		profileKey = "silver",
		minAmount = 1,
		xpPerUnit = 0.1,
		contributionPerUnit = 1,
	},
	{
		id = "Souls",
		displayName = "Souls",
		profileKey = "souls",
		minAmount = 1,
		xpPerUnit = 2,
		contributionPerUnit = 5,
	},
	{
		id = "Tickets",
		displayName = "Tickets",
		profileKey = "tickets",
		minAmount = 1,
		xpPerUnit = 25,
		contributionPerUnit = 50,
	},
	{
		id = "WeaponPoints",
		displayName = "Weapon Points",
		profileKey = "weaponPoints",
		minAmount = 1,
		xpPerUnit = 1,
		contributionPerUnit = 2,
	},
}

GuildConfig.TREASURY_KEYS = {
	"Silver",
	"Souls",
	"Tickets",
	"WeaponPoints",
}

GuildConfig.TREASURY_MATERIAL_PREFIXES = {
	MobMaterial = {
		prefix = "MobMaterial:",
		displayPrefix = "Monster Material",
		craftingKey = "mobMaterials",
		xpPerUnit = 1,
		contributionPerUnit = 2,
	},
	UpgradeMaterial = {
		prefix = "UpgradeMaterial:",
		displayPrefix = "Upgrade Material",
		craftingKey = "upgradeMaterials",
		xpPerUnit = 2,
		contributionPerUnit = 4,
	},
	MineResource = {
		prefix = "MineResource:",
		displayPrefix = "Mine Resource",
		craftingKey = "mineResources",
		xpPerUnit = 1,
		contributionPerUnit = 2,
	},
}

GuildConfig.TREASURY_HISTORY_LIMIT = 25

GuildConfig.LEVEL_XP = {
	[1] = 0,
	[2] = 250,
	[3] = 650,
	[4] = 1250,
	[5] = 2100,
	[6] = 3300,
	[7] = 5000,
	[8] = 7400,
	[9] = 10400,
	[10] = 14000,
}

function GuildConfig.GetTreasuryCurrencyResource(resourceId)
	for _, resource in ipairs(GuildConfig.TREASURY_CURRENCY_RESOURCES) do
		if resource.id == resourceId then
			return resource
		end
	end
	return nil
end

function GuildConfig.GetTreasuryMaterialResource(resourceId)
	if typeof(resourceId) ~= "string" then
		return nil
	end
	for _, mapping in pairs(GuildConfig.TREASURY_MATERIAL_PREFIXES) do
		if string.sub(resourceId, 1, #mapping.prefix) == mapping.prefix then
			local materialId = string.sub(resourceId, #mapping.prefix + 1)
			if materialId ~= "" then
				return mapping, materialId
			end
		end
	end
	return nil
end

function GuildConfig.GetLevelFromXp(xp)
	local value = math.max(0, math.floor(tonumber(xp) or 0))
	local level = 1
	for nextLevel, requiredXp in pairs(GuildConfig.LEVEL_XP) do
		if value >= requiredXp and nextLevel > level then
			level = nextLevel
		end
	end
	return level
end

return GuildConfig
