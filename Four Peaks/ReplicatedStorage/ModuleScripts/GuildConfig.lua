local GuildConfig = {}

-- Guild castle place id. Update this if the Guild place is republished under a different place.
GuildConfig.GUILD_PLACE_ID = 89635326813830

GuildConfig.MAX_MEMBERS = 50
GuildConfig.MIN_NAME_LENGTH = 3
GuildConfig.MAX_NAME_LENGTH = 24
GuildConfig.MAX_DESCRIPTION_LENGTH = 240

GuildConfig.ROLES = {
	Owner = "Owner",
	Officer = "Officer",
	Member = "Member",
}

GuildConfig.DONATION_RESOURCES = {
	{
		id = "Silver",
		displayName = "Silver",
		minAmount = 1,
		xpPerUnit = 0.1,
		contributionPerUnit = 1,
	},
	{
		id = "Souls",
		displayName = "Souls",
		minAmount = 1,
		xpPerUnit = 2,
		contributionPerUnit = 5,
	},
	{
		id = "Tickets",
		displayName = "Tickets",
		minAmount = 1,
		xpPerUnit = 25,
		contributionPerUnit = 50,
	},
	{
		id = "WeaponPoints",
		displayName = "Weapon Points",
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

GuildConfig.UPGRADES = {
	Dojo = {
		id = "Dojo",
		displayName = "Dojo",
		maxLevel = 10,
		baseCost = 150,
		costGrowth = 1.45,
		description = "Improves guild training bonuses.",
	},
	Farms = {
		id = "Farms",
		displayName = "Farms",
		maxLevel = 10,
		baseCost = 120,
		costGrowth = 1.4,
		description = "Improves future farm output.",
	},
	Mine = {
		id = "Mine",
		displayName = "Mine",
		maxLevel = 10,
		baseCost = 140,
		costGrowth = 1.42,
		description = "Improves future mine output.",
	},
	Fishery = {
		id = "Fishery",
		displayName = "Fishery",
		maxLevel = 10,
		baseCost = 120,
		costGrowth = 1.4,
		description = "Improves future fishing output.",
	},
}

GuildConfig.TASKS = {
	{
		id = "donate_any",
		displayName = "Guild Offering",
		description = "Donate any resource to the guild treasury.",
		target = 100,
	},
	{
		id = "donate_silver",
		displayName = "Silver Reserve",
		description = "Donate Silver to the guild.",
		target = 500,
	},
	{
		id = "upgrade_any",
		displayName = "Raise the Castle",
		description = "Buy any guild upgrade.",
		target = 1,
	},
	{
		id = "recruit_members",
		displayName = "Gather the Banner",
		description = "Reach 3 guild members.",
		target = 3,
	},
	{
		id = "visit_castle",
		displayName = "Enter the Castle",
		description = "Teleport to the guild castle.",
		target = 1,
	},
}

function GuildConfig.GetDonationResource(resourceId)
	for _, resource in ipairs(GuildConfig.DONATION_RESOURCES) do
		if resource.id == resourceId then
			return resource
		end
	end
	return nil
end

function GuildConfig.GetUpgrade(upgradeId)
	return GuildConfig.UPGRADES[upgradeId]
end

function GuildConfig.GetUpgradeCost(upgradeId, currentLevel)
	local upgrade = GuildConfig.GetUpgrade(upgradeId)
	if not upgrade then
		return nil
	end
	local level = math.max(0, math.floor(tonumber(currentLevel) or 0))
	if level >= upgrade.maxLevel then
		return nil
	end
	return math.max(1, math.floor(upgrade.baseCost * (upgrade.costGrowth ^ level) + 0.5))
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
