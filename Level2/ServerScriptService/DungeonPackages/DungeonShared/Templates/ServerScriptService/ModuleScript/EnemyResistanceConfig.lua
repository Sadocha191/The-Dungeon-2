--!strict

local EnemyResistanceConfig = {}

local ELEMENT_ALIASES = {
	Electric = "Electricity",
	Lightning = "Electricity",
	Wind = "Air",
	Nature = "Earth",
	Holy = "Light",
	Dark = "Void",
	Shadow = "Void",
}

local VALID_ELEMENTS = {
	Physical = true,
	Fire = true,
	Electricity = true,
	Air = true,
	Water = true,
	Earth = true,
	Void = true,
	Light = true,
}

EnemyResistanceConfig.Profiles = table.freeze({
	Neutral = table.freeze({}),
	Slime = table.freeze({ Physical = 0.80, Fire = 0.90, Electricity = 1.35, Water = 0.70 }),
	FlyingBeast = table.freeze({ Electricity = 1.20, Light = 1.20, Air = 0.80 }),
	MetalConstruct = table.freeze({ Physical = 0.75, Fire = 0.65, Electricity = 1.35, Earth = 1.15 }),
	Wood = table.freeze({ Fire = 1.50, Water = 0.80, Earth = 0.80 }),
	Fungus = table.freeze({ Fire = 1.35, Water = 0.80, Earth = 0.90 }),
	Stone = table.freeze({ Physical = 0.75, Fire = 0.75, Electricity = 0.80, Water = 1.20, Earth = 0.60 }),
})

local MOB_PROFILE_FALLBACKS = table.freeze({
	Slime = "Slime",
	Bat = "FlyingBeast",
	Goblin = "Neutral",
	Cauldron = "MetalConstruct",
	Stump = "Wood",
	Ent_Fat = "Wood",
	Ent = "Wood",
	Grzyb = "Fungus",
	Golem = "Stone",
})

function EnemyResistanceConfig.NormalizeElement(value: any): string
	local element = tostring(value or "Physical")
	element = ELEMENT_ALIASES[element] or element
	if VALID_ELEMENTS[element] then
		return element
	end
	return "Physical"
end

function EnemyResistanceConfig.ResolveProfile(model: Model): string
	local configured = model:GetAttribute("ResistanceProfile")
	if typeof(configured) == "string" and EnemyResistanceConfig.Profiles[configured] then
		return configured
	end
	local mobType = tostring(model:GetAttribute("MobType") or model.Name)
	return MOB_PROFILE_FALLBACKS[mobType] or "Neutral"
end

function EnemyResistanceConfig.GetElementMultiplier(model: Model, elementValue: any): number
	local profileName = EnemyResistanceConfig.ResolveProfile(model)
	local profile = EnemyResistanceConfig.Profiles[profileName] or EnemyResistanceConfig.Profiles.Neutral
	local element = EnemyResistanceConfig.NormalizeElement(elementValue)
	return math.clamp(tonumber(profile[element]) or 1, 0.10, 3)
end

function EnemyResistanceConfig.GetDamageMultiplier(model: Model, primaryElement: any, secondaryElement: any): number
	local primary = EnemyResistanceConfig.GetElementMultiplier(model, primaryElement)
	if secondaryElement == nil then
		return primary
	end
	local primaryName = EnemyResistanceConfig.NormalizeElement(primaryElement)
	local secondaryName = EnemyResistanceConfig.NormalizeElement(secondaryElement)
	if primaryName == secondaryName then
		return primary
	end
	local secondary = EnemyResistanceConfig.GetElementMultiplier(model, secondaryElement)
	return (primary + secondary) * 0.5
end

return table.freeze(EnemyResistanceConfig)
