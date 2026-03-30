local WeaponConfigs = require(script.Parent:WaitForChild("WeaponConfigs"))
local BannerSchedule = require(script.Parent:WaitForChild("BannerSchedule"))

local BannerConfigs = {}

local BASE_BANNER = {
	DisplayName = "Weapon Banner",
	Description = "Increased chance for featured weapons.",
	Icon = "",
	Active = true,
	Cost = {
		Currency = "Tickets",
		Amount = 1,
	},
	RarityRates = {
		Common = 0.70,
		Rare = 0.20,
		Epic = 0.08,
		Legendary = 0.02,
		Mythical = 0.00,
	},
	Pool = {
		{ WeaponId = "Knight's Oath", Rarity = "Common", Weight = 50 },
		{ WeaponId = "Hunter's Longbow", Rarity = "Common", Weight = 50 },
		{ WeaponId = "Warden's Halberd", Rarity = "Rare", Weight = 40 },
		{ WeaponId = "Apprentice Arcstaff", Rarity = "Rare", Weight = 40 },
		{ WeaponId = "Blackpowder Flintlock", Rarity = "Rare", Weight = 40 },
		{ WeaponId = "Reaper's Crescent", Rarity = "Epic", Weight = 35 },
		{ WeaponId = "Dragonspear Halberd", Rarity = "Epic", Weight = 35 },
		{ WeaponId = "Stormwind Recurve", Rarity = "Epic", Weight = 35 },
		{ WeaponId = "Excalion, Blade of Kings", Rarity = "Legendary", Weight = 25 },
		{ WeaponId = "Harvest of the End", Rarity = "Legendary", Weight = 25 },
		{ WeaponId = "Kingslayer Handcannon", Rarity = "Legendary", Weight = 25 },
		{ WeaponId = "Archmage's Worldstaff", Rarity = "Mythical", Weight = 10 },
	},
	FeaturedWeaponIds = { "Excalion, Blade of Kings" },
	FeaturedRate = 0.50,
	Pity = {
		TargetRarity = "Legendary",
		SoftPityStart = 60,
		SoftPityStep = 0.015,
		HardPity = 80,
	},
}

local DEFAULT_TARGET_RATE = {
	Common = 0.70,
	Rare = 0.20,
	Epic = 0.08,
	Legendary = 0.02,
	Mythical = 0.01,
}

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, nested in pairs(value) do
		copy[key] = deepCopy(nested)
	end
	return copy
end

local function normalizeFeatured(entry)
	if typeof(entry.FeaturedWeaponIds) == "table" then
		local featured = {}
		for _, weaponId in ipairs(entry.FeaturedWeaponIds) do
			if typeof(weaponId) == "string" and weaponId ~= "" then
				table.insert(featured, weaponId)
			end
		end
		if #featured > 0 then
			return featured
		end
	end

	if typeof(entry.FeaturedWeaponId) == "string" and entry.FeaturedWeaponId ~= "" then
		return { entry.FeaturedWeaponId }
	end

	return deepCopy(BASE_BANNER.FeaturedWeaponIds)
end

local function getTargetRarity(featuredWeaponIds, entry)
	if typeof(entry.TargetRarity) == "string" and entry.TargetRarity ~= "" then
		return entry.TargetRarity
	end

	for _, weaponId in ipairs(featuredWeaponIds) do
		local def = WeaponConfigs.Get and WeaponConfigs.Get(weaponId)
		if def and typeof(def.rarity) == "string" and def.rarity ~= "" then
			return def.rarity
		end
	end

	return BASE_BANNER.Pity.TargetRarity
end

local function buildRates(targetRarity, entry)
	if typeof(entry.RarityRates) == "table" then
		return deepCopy(entry.RarityRates)
	end

	local rates = deepCopy(BASE_BANNER.RarityRates)
	local targetRate = tonumber(entry.TargetRate)
	if not targetRate or targetRate <= 0 then
		targetRate = tonumber(rates[targetRarity])
	end
	if not targetRate or targetRate <= 0 then
		targetRate = DEFAULT_TARGET_RATE[targetRarity] or 0.02
	end
	targetRate = math.clamp(targetRate, 0, 1)

	local otherTotal = 0
	for rarity, rate in pairs(rates) do
		if rarity ~= targetRarity then
			otherTotal += tonumber(rate) or 0
		end
	end

	if otherTotal <= 0 then
		for rarity in pairs(rates) do
			rates[rarity] = rarity == targetRarity and 1 or 0
		end
		return rates
	end

	local scale = (1 - targetRate) / otherTotal
	for rarity, rate in pairs(rates) do
		if rarity == targetRarity then
			rates[rarity] = targetRate
		else
			rates[rarity] = math.max(0, (tonumber(rate) or 0) * scale)
		end
	end

	return rates
end

local function buildPity(targetRarity, entry)
	local pity = deepCopy(BASE_BANNER.Pity)
	pity.TargetRarity = targetRarity

	if typeof(entry.Pity) == "table" then
		for key, value in pairs(entry.Pity) do
			pity[key] = deepCopy(value)
		end
	end

	return pity
end

local function parseUtcTimestamp(value)
	if typeof(value) == "number" then
		return math.floor(value)
	end
	if typeof(value) ~= "string" then
		return nil
	end

	local year, month, day, hour, minute, second = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d):(%d%d)$")
	if not year then
		year, month, day, hour, minute = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d)$")
		second = 0
	end
	if not year then
		return nil
	end

	local ok, dateTime = pcall(function()
		return DateTime.fromUniversalTime(
			tonumber(year),
			tonumber(month),
			tonumber(day),
			tonumber(hour),
			tonumber(minute),
			tonumber(second) or 0
		)
	end)

	if ok and dateTime then
		return dateTime.UnixTimestamp
	end

	return nil
end

local function slugify(text)
	local slug = tostring(text or "banner"):lower()
	slug = slug:gsub("[^%w]+", "_")
	slug = slug:gsub("^_+", ""):gsub("_+$", "")
	if slug == "" then
		return "banner"
	end
	return slug
end

local function joinFeatured(featuredWeaponIds)
	return table.concat(featuredWeaponIds, ", ")
end

local function buildBannerId(entry, index, featuredWeaponIds)
	if typeof(entry.Id) == "string" and entry.Id ~= "" then
		return entry.Id
	end
	return string.format("WeaponFocus_%02d_%s", index, slugify(featuredWeaponIds[1] or "banner"))
end

local function buildBanner(entry, index)
	local featuredWeaponIds = normalizeFeatured(entry)
	local featuredLabel = joinFeatured(featuredWeaponIds)
	local targetRarity = getTargetRarity(featuredWeaponIds, entry)

	local banner = deepCopy(BASE_BANNER)
	banner.DisplayName = entry.DisplayName or ("Weapon Banner: " .. featuredLabel)
	banner.Description = entry.Description or ("Increased chance for " .. featuredLabel .. ".")
	banner.Icon = entry.Icon or banner.Icon
	banner.Active = entry.Active ~= false
	banner.Cost = typeof(entry.Cost) == "table" and deepCopy(entry.Cost) or banner.Cost
	banner.RarityRates = buildRates(targetRarity, entry)
	banner.Pool = typeof(entry.Pool) == "table" and deepCopy(entry.Pool) or banner.Pool
	banner.FeaturedWeaponIds = featuredWeaponIds
	banner.FeaturedRate = tonumber(entry.FeaturedRate) or banner.FeaturedRate
	banner.Pity = buildPity(targetRarity, entry)
	banner.StartTime = parseUtcTimestamp(entry.StartsAtUtc or entry.StartTimeUtc or entry.StartTime)
	banner.EndTime = parseUtcTimestamp(entry.EndsAtUtc or entry.EndTimeUtc or entry.EndTime)

	return {
		Id = buildBannerId(entry, index, featuredWeaponIds),
		StartTime = banner.StartTime,
		Banner = banner,
	}
end

local compiled = {}
for index, entry in ipairs(BannerSchedule.Rotation or {}) do
	if typeof(entry) == "table" then
		table.insert(compiled, buildBanner(entry, index))
	end
end

BannerConfigs.Banners = {}
for index, item in ipairs(compiled) do
	local nextItem = compiled[index + 1]
	if item.Banner.EndTime == nil and nextItem and nextItem.StartTime then
		item.Banner.EndTime = nextItem.StartTime - 1
	end
	BannerConfigs.Banners[item.Id] = item.Banner
end

return BannerConfigs
