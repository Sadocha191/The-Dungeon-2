local StatsConfig = {}

StatsConfig.Types = {
	Flat = "Flat",
	Percent = "Percent",
	Multiplier = "Multiplier",
}

StatsConfig.GroupOrder = {
	"Survival",
	"Combat",
	"Projectile",
	"Movement",
	"Economy / Progress",
}

StatsConfig.DisplayOrder = {
	"MaxHP",
	"HPRegen",
	"Overheal",
	"Shield",
	"Armor",
	"Evasion",
	"Lifesteal",
	"Thorns",
	"Damage",
	"CritChance",
	"CritDamage",
	"AttackSpeed",
	"DamageToElites",
	"Knockback",
	"ProjectileCount",
	"ProjectileBounces",
	"ProjectileSpeed",
	"Size",
	"Duration",
	"MovementSpeed",
	"ExtraJumps",
	"JumpHeight",
	"Luck",
	"Difficulty",
	"PickupRange",
	"XPGain",
	"GoldGain",
	"SilverGain",
	"EliteSpawnIncrease",
	"PowerupMultiplier",
	"PowerupDropChance",
}

StatsConfig.Stats = {
	MaxHP = { Label = "Max HP", Group = "Survival", Type = StatsConfig.Types.Flat, Default = 47, Min = 1, Format = "flat", Decimals = 0 },
	HPRegen = { Label = "HP Regen", Group = "Survival", Type = StatsConfig.Types.Flat, Default = 0, Min = 0, Format = "flat", Decimals = 1 },
	Overheal = { Label = "Overheal", Group = "Survival", Type = StatsConfig.Types.Flat, Default = 0, Min = 0, Format = "flat", Decimals = 0 },
	Shield = { Label = "Shield", Group = "Survival", Type = StatsConfig.Types.Flat, Default = 0, Min = 0, Format = "flat", Decimals = 0 },
	Armor = { Label = "Armor", Group = "Survival", Type = StatsConfig.Types.Percent, Default = 0, Min = 0, Max = 0.80, Format = "percent", Decimals = 0 },
	Evasion = { Label = "Evasion", Group = "Survival", Type = StatsConfig.Types.Percent, Default = 0, Min = 0, Max = 0.75, Format = "percent", Decimals = 0 },
	Lifesteal = { Label = "Lifesteal", Group = "Survival", Type = StatsConfig.Types.Percent, Default = 0, Min = 0, Max = 1, Format = "percent", Decimals = 0 },
	Thorns = { Label = "Thorns", Group = "Survival", Type = StatsConfig.Types.Flat, Default = 0, Min = 0, Format = "flat", Decimals = 0 },

	Damage = { Label = "Damage", Group = "Combat", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },
	CritChance = { Label = "Crit Chance", Group = "Combat", Type = StatsConfig.Types.Percent, Default = 0.05, Min = 0, Max = 1, Format = "percent", Decimals = 0 },
	CritDamage = { Label = "Crit Damage", Group = "Combat", Type = StatsConfig.Types.Multiplier, Default = 2, Min = 1, Format = "multiplier", Decimals = 2 },
	AttackSpeed = { Label = "Attack Speed", Group = "Combat", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.25, Format = "multiplier", Decimals = 2 },
	DamageToElites = { Label = "Elite Damage", Group = "Combat", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },
	Knockback = { Label = "Knockback", Group = "Combat", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0, Format = "multiplier", Decimals = 2 },

	ProjectileCount = { Label = "Projectile Count", Group = "Projectile", Type = StatsConfig.Types.Flat, Default = 0, Min = 0, Format = "flat", Decimals = 0 },
	ProjectileBounces = { Label = "Projectile Bounces", Group = "Projectile", Type = StatsConfig.Types.Flat, Default = 0, Min = 0, Format = "flat", Decimals = 0 },
	ProjectileSpeed = { Label = "Projectile Speed", Group = "Projectile", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },
	Size = { Label = "Size", Group = "Projectile", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },
	Duration = { Label = "Duration", Group = "Projectile", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },

	MovementSpeed = { Label = "Move Speed", Group = "Movement", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.25, Format = "multiplier", Decimals = 2 },
	ExtraJumps = { Label = "Extra Jumps", Group = "Movement", Type = StatsConfig.Types.Flat, Default = 0, Min = 0, Format = "flat", Decimals = 0 },
	JumpHeight = { Label = "Jump Height", Group = "Movement", Type = StatsConfig.Types.Flat, Default = 1, Min = 0.10, Format = "flat", Decimals = 2 },

	Luck = { Label = "Luck", Group = "Economy / Progress", Type = StatsConfig.Types.Percent, Default = 0, Min = 0, Format = "percent", Decimals = 0 },
	Difficulty = { Label = "Difficulty", Group = "Economy / Progress", Type = StatsConfig.Types.Percent, Default = 0, Min = 0, Format = "percent", Decimals = 0 },
	PickupRange = { Label = "Pickup Range", Group = "Economy / Progress", Type = StatsConfig.Types.Flat, Default = 8, Min = 0, Format = "flat", Decimals = 0 },
	XPGain = { Label = "XP Gain", Group = "Economy / Progress", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },
	GoldGain = { Label = "Gold Gain", Group = "Economy / Progress", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },
	SilverGain = { Label = "Silver Gain", Group = "Economy / Progress", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },
	EliteSpawnIncrease = { Label = "Elite Spawn", Group = "Economy / Progress", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Max = 1.75, Format = "multiplier", Decimals = 2 },
	PowerupMultiplier = { Label = "Powerup Power", Group = "Economy / Progress", Type = StatsConfig.Types.Multiplier, Default = 1, Min = 0.10, Format = "multiplier", Decimals = 2 },
	PowerupDropChance = { Label = "Powerup Drop", Group = "Economy / Progress", Type = StatsConfig.Types.Percent, Default = 0, Min = 0, Max = 1, Format = "percent", Decimals = 0 },
}

function StatsConfig.Get(statName)
	return StatsConfig.Stats[statName]
end

function StatsConfig.CloneDefaults()
	local defaults = {}
	for statName, definition in pairs(StatsConfig.Stats) do
		defaults[statName] = definition.Default
	end
	return defaults
end

function StatsConfig.Clamp(statName, value)
	local definition = StatsConfig.Stats[statName]
	if not definition then
		return value
	end

	local numericValue = tonumber(value) or definition.Default
	if definition.Min ~= nil then
		numericValue = math.max(definition.Min, numericValue)
	end
	if definition.Max ~= nil then
		numericValue = math.min(definition.Max, numericValue)
	end
	return numericValue
end

function StatsConfig.FormatValue(statName, value)
	local definition = StatsConfig.Stats[statName]
	if not definition then
		return tostring(value)
	end

	local numericValue = tonumber(value) or definition.Default
	local decimals = math.max(0, math.floor(tonumber(definition.Decimals) or 0))
	if definition.Format == "percent" then
		local percentValue = numericValue * 100
		return string.format("%." .. decimals .. "f%%", percentValue)
	end
	if definition.Format == "multiplier" then
		return string.format("%." .. decimals .. "fx", numericValue)
	end
	return string.format("%." .. decimals .. "f", numericValue)
end

return StatsConfig
