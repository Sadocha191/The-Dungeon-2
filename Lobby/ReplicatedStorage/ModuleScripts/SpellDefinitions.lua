local SpellDefs = {}

SpellDefs.MAX_MAGIC_RUN_SPELLS = 8
SpellDefs.MAX_PHYSICAL_RUN_SPELLS = 4
SpellDefs.MAX_RUN_SPELLS = SpellDefs.MAX_MAGIC_RUN_SPELLS + SpellDefs.MAX_PHYSICAL_RUN_SPELLS

SpellDefs.RARITY_WEIGHTS = { Common = 0.52, Uncommon = 0.28, Rare = 0.14, Epic = 0.06 }
SpellDefs.COLOR_BASE = Color3.fromRGB(120, 190, 255)
SpellDefs.COLOR_SHOP = Color3.fromRGB(190, 120, 255)

SpellDefs.UPGRADE_QUALITIES = {
	Common = { id = "Common", label = "Common Upgrade", power = 1.00, cardColor = Color3.fromRGB(220, 220, 220), bonusText = "Steady scaling gain." },
	Uncommon = { id = "Uncommon", label = "Uncommon Upgrade", power = 1.40, cardColor = Color3.fromRGB(120, 255, 175), bonusText = "Better scaling and stronger utility." },
	Rare = { id = "Rare", label = "Rare Upgrade", power = 1.85, cardColor = Color3.fromRGB(120, 175, 255), bonusText = "Stronger bonuses and cleaner end effect." },
	Epic = { id = "Epic", label = "Epic Upgrade", power = 2.35, cardColor = Color3.fromRGB(255, 170, 120), bonusText = "High-impact upgrade spike for core builds." },
}

SpellDefs.BASE_VARIANT_QUALITIES = {
	Standard = { id = "Standard", label = "Standard Base", shortLabel = "Standard", cardQuality = "Common", costMultiplier = 1.00, baseMultiplier = 1.00, basePower = 0.00 },
	Amplified = { id = "Amplified", label = "Amplified Base", shortLabel = "Amplified", cardQuality = "Rare", costMultiplier = 1.85, baseMultiplier = 1.18, basePower = 0.85 },
}

SpellDefs.ELEMENTS = {
	Fire = { order = 1, color = Color3.fromRGB(255, 98, 54) },
	Electricity = { order = 2, color = Color3.fromRGB(255, 221, 84) },
	Air = { order = 3, color = Color3.fromRGB(232, 236, 240) },
	Water = { order = 4, color = Color3.fromRGB(70, 160, 255) },
	Earth = { order = 5, color = Color3.fromRGB(118, 168, 88) },
	Void = { order = 6, color = Color3.fromRGB(118, 78, 168) },
	Light = { order = 7, color = Color3.fromRGB(255, 236, 176) },
	Physical = { order = 8, color = Color3.fromRGB(138, 128, 132) },
}

SpellDefs.BASE_STARTER = {
	"FireBolt_Standard",
	"Tornado_Standard",
	"WaterShard_Standard",
	"StoneSpike_Standard",
	"AxeThrow_Standard",
}

SpellDefs.SPELLS = {}
SpellDefs.SHOP_PRODUCTS = {}
SpellDefs.SPELL_ORDER = {}
SpellDefs.SHOP_ORDER = {}
SpellDefs.SYNERGIES = {}

local BASE_VARIANT_ORDER = { "Standard", "Amplified" }
local QUALITY_ORDER = { "Common", "Uncommon", "Rare", "Epic" }

local EFFECTS = {
	Fire = { dot = { kind = "Burn", dps = 4.5, duration = 2.2 }, note = "Applies burn damage over time." },
	Electricity = { stun = { duration = 0.22 }, note = "Briefly shocks and interrupts enemies." },
	Air = { knockback = { force = 22 }, note = "Pushes enemies away from you." },
	Water = { slow = { pct = 0.30, duration = 1.3 }, note = "Slows targets and controls their approach." },
	Earth = { slow = { pct = 0.18, duration = 1.0 }, knockback = { force = 14 }, note = "Hits hard and staggers targets." },
	Void = { pull = { force = 16 }, vulnerability = { pct = 0.08, duration = 1.2 }, note = "Pulls enemies in and opens them for follow-up damage." },
	Light = { vulnerability = { pct = 0.12, duration = 1.5 }, pierceBonus = 1, note = "Marks enemies to take more damage." },
	Physical = { dot = { kind = "Bleed", dps = 4.0, duration = 2.0 }, note = "Uses weapon-style physical impact and bleed." },
}

local ATTACK_NOTES = {
	Projectile = "Auto-fires at the nearest enemy.",
	Orbit = "Rotates around the player and damages on contact.",
	Nova = "Triggers a burst around the player.",
	Zone = "Creates an area that punishes enemies standing inside.",
	Beam = "Fires a sustained line attack through nearby enemies.",
}

local function copyTable(src)
	local out = {}
	for key, value in pairs(src or {}) do
		out[key] = typeof(value) == "table" and copyTable(value) or value
	end
	return out
end

local function blend(a, b, alpha)
	return Color3.new(
		a.R + ((b.R - a.R) * alpha),
		a.G + ((b.G - a.G) * alpha),
		a.B + ((b.B - a.B) * alpha)
	)
end

local function makeCategory(def)
	return string.format("%s / %s / %s", def.spellType, def.element, def.attackType)
end

local function makeDescription(def)
	local effect = EFFECTS[def.element] or EFFECTS.Physical
	return string.format("%s %s", ATTACK_NOTES[def.attackType] or "Basic spell effect.", effect.note or "")
end

local function addProduct(def, variantId, variant)
	local productId = string.format("%s_%s", def.id, variantId)
	local cost = math.floor((def.shopCost or 200) * (variant.costMultiplier or 1))
	SpellDefs.SHOP_PRODUCTS[productId] = {
		id = productId,
		familyId = def.id,
		name = def.name,
		displayName = string.format("%s (%s)", def.name, variant.shortLabel),
		element = def.element,
		attackType = def.attackType,
		spellType = def.spellType,
		category = def.category,
		description = def.description,
		baseQuality = variantId,
		cardQuality = variant.cardQuality,
		baseMultiplier = variant.baseMultiplier,
		basePower = variant.basePower,
		costCoins = cost,
		costSouls = cost,
		color = def.color,
	}
	table.insert(SpellDefs.SHOP_ORDER, productId)
end

local function registerSpell(def)
	local primaryColor = (SpellDefs.ELEMENTS[def.element] and SpellDefs.ELEMENTS[def.element].color) or SpellDefs.COLOR_BASE
	local secondaryColor = def.secondaryElement and SpellDefs.ELEMENTS[def.secondaryElement] and SpellDefs.ELEMENTS[def.secondaryElement].color or primaryColor
	def.color = primaryColor
	def.displayColor = def.secondaryElement and blend(primaryColor, secondaryColor, 0.45) or primaryColor
	def.category = def.category or makeCategory(def)
	def.description = def.description or makeDescription(def)
	def.maxLevel = def.maxLevel or 6
	SpellDefs.SPELLS[def.id] = def
	table.insert(SpellDefs.SPELL_ORDER, def.id)
	if def.shopAvailable ~= false then
		for _, variantId in ipairs(BASE_VARIANT_ORDER) do
			addProduct(def, variantId, SpellDefs.BASE_VARIANT_QUALITIES[variantId])
		end
	end
end

local function addSynergy(resultId, a, b)
	table.insert(SpellDefs.SYNERGIES, {
		resultId = resultId,
		ingredients = { a, b },
		key = (a < b) and (a .. "|" .. b) or (b .. "|" .. a),
	})
end

local function addBaseSpell(spec)
	registerSpell({
		id = spec[1],
		name = spec[2],
		spellType = spec[3],
		element = spec[4],
		attackType = spec[5],
		shopCost = spec[6],
		runtime = spec[7],
		base = true,
	})
end

local function addComboSpell(spec)
	registerSpell({
		id = spec[1],
		name = spec[2],
		spellType = "Magic",
		element = spec[3],
		secondaryElement = spec[4],
		attackType = spec[5],
		shopAvailable = false,
		runtime = spec[6],
		base = false,
		isCombo = true,
		description = string.format("Synergy spell created by merging %s and %s. %s", spec[7], spec[8], ATTACK_NOTES[spec[5]] or ""),
	})
	addSynergy(spec[1], spec[7], spec[8])
end

for _, spec in ipairs({
	{ "FireBolt", "Fire Bolt", "Magic", "Fire", "Projectile", 180, { archetype = "Projectile", baseDamage = 19, cooldown = 1.05, projectileSpeed = 98, range = 66, baseCount = 1, countPerThreeLevels = 1, pierce = 0 } },
	{ "EmberOrbit", "Ember Orbit", "Magic", "Fire", "Orbit", 220, { archetype = "Orbit", baseDamage = 12, hitCooldown = 0.35, baseRadius = 5.0, baseCount = 2, countPerThreeLevels = 1, orbitSpeed = 2.8 } },
	{ "FlameBurst", "Flame Burst", "Magic", "Fire", "Nova", 230, { archetype = "Nova", baseDamage = 28, cooldown = 3.2, baseRadius = 8.5 } },
	{ "ScorchField", "Scorch Field", "Magic", "Fire", "Zone", 250, { archetype = "Zone", baseDamage = 9.2, cooldown = 4.1, baseRadius = 6.6, duration = 3.4, tickRate = 0.45, spawnAtEnemy = true } },
	{ "InfernoBeam", "Inferno Beam", "Magic", "Fire", "Beam", 280, { archetype = "Beam", baseDamage = 8.4, cooldown = 5.0, duration = 1.6, tickRate = 0.18, range = 56, width = 4.4 } },
	{ "VoltNeedle", "Volt Needle", "Magic", "Electricity", "Projectile", 180, { archetype = "Projectile", baseDamage = 18, cooldown = 1.00, projectileSpeed = 108, range = 68, baseCount = 1, countPerThreeLevels = 1, pierce = 0 } },
	{ "StaticHalo", "Static Halo", "Magic", "Electricity", "Orbit", 220, { archetype = "Orbit", baseDamage = 11, hitCooldown = 0.34, baseRadius = 5.8, baseCount = 2, countPerThreeLevels = 1, orbitSpeed = 3.0 } },
	{ "ShockBurst", "Shock Burst", "Magic", "Electricity", "Nova", 230, { archetype = "Nova", baseDamage = 24, cooldown = 2.8, baseRadius = 9.0 } },
	{ "StormField", "Storm Field", "Magic", "Electricity", "Zone", 250, { archetype = "Zone", baseDamage = 8.7, cooldown = 4.0, baseRadius = 6.4, duration = 3.8, tickRate = 0.40, spawnAtEnemy = true } },
	{ "ThunderRay", "Thunder Ray", "Magic", "Electricity", "Beam", 280, { archetype = "Beam", baseDamage = 8.0, cooldown = 4.9, duration = 1.45, tickRate = 0.16, range = 54, width = 4.0 } },
	{ "GaleKnife", "Gale Knife", "Magic", "Air", "Projectile", 180, { archetype = "Projectile", baseDamage = 16, cooldown = 1.00, projectileSpeed = 102, range = 70, baseCount = 1, countPerThreeLevels = 1, pierce = 1 } },
	{ "WindRing", "Wind Ring", "Magic", "Air", "Orbit", 220, { archetype = "Orbit", baseDamage = 10, hitCooldown = 0.32, baseRadius = 6.2, baseCount = 2, countPerThreeLevels = 1, orbitSpeed = 3.2 } },
	{ "GustBurst", "Gust Burst", "Magic", "Air", "Nova", 230, { archetype = "Nova", baseDamage = 22, cooldown = 2.8, baseRadius = 9.6 } },
	{ "Tornado", "Tornado", "Magic", "Air", "Zone", 260, { archetype = "Zone", baseDamage = 7.8, cooldown = 4.2, baseRadius = 6.8, duration = 4.2, tickRate = 0.42, spawnAtEnemy = true, pullStrength = 1.1 } },
	{ "Jetstream", "Jetstream", "Magic", "Air", "Beam", 280, { archetype = "Beam", baseDamage = 7.6, cooldown = 4.6, duration = 1.7, tickRate = 0.17, range = 58, width = 4.6 } },
	{ "WaterShard", "Water Shard", "Magic", "Water", "Projectile", 180, { archetype = "Projectile", baseDamage = 17, cooldown = 1.08, projectileSpeed = 92, range = 67, baseCount = 1, countPerThreeLevels = 1, pierce = 0 } },
	{ "TideOrbit", "Tide Orbit", "Magic", "Water", "Orbit", 220, { archetype = "Orbit", baseDamage = 10, hitCooldown = 0.36, baseRadius = 5.7, baseCount = 2, countPerThreeLevels = 1, orbitSpeed = 2.7 } },
	{ "FrostSplash", "Frost Splash", "Magic", "Water", "Nova", 230, { archetype = "Nova", baseDamage = 23, cooldown = 3.0, baseRadius = 8.8 } },
	{ "RiptidePool", "Riptide Pool", "Magic", "Water", "Zone", 250, { archetype = "Zone", baseDamage = 8.2, cooldown = 4.2, baseRadius = 6.9, duration = 3.8, tickRate = 0.45, spawnAtEnemy = true } },
	{ "TidalBeam", "Tidal Beam", "Magic", "Water", "Beam", 280, { archetype = "Beam", baseDamage = 7.8, cooldown = 5.0, duration = 1.6, tickRate = 0.18, range = 54, width = 4.4 } },
	{ "StoneSpike", "Stone Spike", "Magic", "Earth", "Projectile", 190, { archetype = "Projectile", baseDamage = 21, cooldown = 1.18, projectileSpeed = 84, range = 62, baseCount = 1, countPerThreeLevels = 1, pierce = 0 } },
	{ "RockOrbit", "Rock Orbit", "Magic", "Earth", "Orbit", 220, { archetype = "Orbit", baseDamage = 13, hitCooldown = 0.40, baseRadius = 5.4, baseCount = 2, countPerThreeLevels = 1, orbitSpeed = 2.3 } },
	{ "QuakeBurst", "Quake Burst", "Magic", "Earth", "Nova", 235, { archetype = "Nova", baseDamage = 30, cooldown = 3.2, baseRadius = 8.6 } },
	{ "BramblePatch", "Bramble Patch", "Magic", "Earth", "Zone", 255, { archetype = "Zone", baseDamage = 8.6, cooldown = 4.3, baseRadius = 6.7, duration = 4.2, tickRate = 0.46, spawnAtEnemy = true } },
	{ "FaultLine", "Fault Line", "Magic", "Earth", "Beam", 285, { archetype = "Beam", baseDamage = 8.2, cooldown = 5.2, duration = 1.4, tickRate = 0.20, range = 50, width = 4.8 } },
	{ "VoidShard", "Void Shard", "Magic", "Void", "Projectile", 185, { archetype = "Projectile", baseDamage = 18, cooldown = 1.10, projectileSpeed = 90, range = 66, baseCount = 1, countPerThreeLevels = 1, pierce = 1 } },
	{ "AbyssHalo", "Abyss Halo", "Magic", "Void", "Orbit", 220, { archetype = "Orbit", baseDamage = 11, hitCooldown = 0.36, baseRadius = 5.6, baseCount = 2, countPerThreeLevels = 1, orbitSpeed = 2.4 } },
	{ "NullBurst", "Null Burst", "Magic", "Void", "Nova", 230, { archetype = "Nova", baseDamage = 25, cooldown = 3.0, baseRadius = 8.8 } },
	{ "Singularity", "Singularity", "Magic", "Void", "Zone", 260, { archetype = "Zone", baseDamage = 8.4, cooldown = 4.4, baseRadius = 6.3, duration = 4.0, tickRate = 0.38, spawnAtEnemy = true, pullStrength = 1.3 } },
	{ "EntropyRay", "Entropy Ray", "Magic", "Void", "Beam", 285, { archetype = "Beam", baseDamage = 8.1, cooldown = 5.1, duration = 1.55, tickRate = 0.18, range = 55, width = 4.2 } },
	{ "RadiantBolt", "Radiant Bolt", "Magic", "Light", "Projectile", 185, { archetype = "Projectile", baseDamage = 19, cooldown = 1.08, projectileSpeed = 100, range = 68, baseCount = 1, countPerThreeLevels = 1, pierce = 1 } },
	{ "HaloOrbit", "Halo Orbit", "Magic", "Light", "Orbit", 220, { archetype = "Orbit", baseDamage = 11, hitCooldown = 0.34, baseRadius = 5.8, baseCount = 2, countPerThreeLevels = 1, orbitSpeed = 2.7 } },
	{ "Sunburst", "Sunburst", "Magic", "Light", "Nova", 235, { archetype = "Nova", baseDamage = 27, cooldown = 3.1, baseRadius = 8.7 } },
	{ "ConsecratedGround", "Consecrated Ground", "Magic", "Light", "Zone", 255, { archetype = "Zone", baseDamage = 8.6, cooldown = 4.2, baseRadius = 6.9, duration = 3.8, tickRate = 0.42, spawnAtEnemy = true } },
	{ "SolarBeam", "Solar Beam", "Magic", "Light", "Beam", 285, { archetype = "Beam", baseDamage = 8.6, cooldown = 5.0, duration = 1.6, tickRate = 0.17, range = 57, width = 4.4 } },
	{ "AxeThrow", "Axe Throw", "Physical", "Physical", "Projectile", 210, { archetype = "Projectile", baseDamage = 23, cooldown = 1.18, projectileSpeed = 86, range = 58, baseCount = 1, countPerThreeLevels = 1, pierce = 0 } },
	{ "GuardHammers", "Guard Hammers", "Physical", "Physical", "Orbit", 235, { archetype = "Orbit", baseDamage = 14, hitCooldown = 0.38, baseRadius = 5.8, baseCount = 2, countPerThreeLevels = 1, orbitSpeed = 2.4 } },
	{ "GroundSlam", "Ground Slam", "Physical", "Physical", "Nova", 245, { archetype = "Nova", baseDamage = 31, cooldown = 3.4, baseRadius = 8.4 } },
	{ "CaltropField", "Caltrop Field", "Physical", "Physical", "Zone", 250, { archetype = "Zone", baseDamage = 9.4, cooldown = 4.0, baseRadius = 6.2, duration = 4.0, tickRate = 0.42, spawnAtEnemy = true } },
	{ "WhirlwindSlash", "Whirlwind Slash", "Physical", "Physical", "Beam", 265, { archetype = "Beam", baseDamage = 8.8, cooldown = 4.7, duration = 1.2, tickRate = 0.16, range = 18, width = 9.0, arcBeam = true } },
}) do
	addBaseSpell(spec)
end

for _, spec in ipairs({
	{ "FireTornado", "Fire Tornado", "Fire", "Air", "Zone", { archetype = "Zone", baseDamage = 11.0, cooldown = 4.4, baseRadius = 7.4, duration = 4.6, tickRate = 0.34, spawnAtEnemy = true, pullStrength = 1.5 }, "Tornado", "FireBolt" },
	{ "StormSurge", "Storm Surge", "Electricity", "Water", "Zone", { archetype = "Zone", baseDamage = 10.4, cooldown = 4.2, baseRadius = 7.0, duration = 4.2, tickRate = 0.34, spawnAtEnemy = true }, "StormField", "WaterShard" },
	{ "MagmaCrash", "Magma Crash", "Fire", "Earth", "Nova", { archetype = "Nova", baseDamage = 35, cooldown = 3.4, baseRadius = 9.6 }, "FlameBurst", "QuakeBurst" },
	{ "RadiantTempest", "Radiant Tempest", "Light", "Air", "Zone", { archetype = "Zone", baseDamage = 10.0, cooldown = 4.2, baseRadius = 7.2, duration = 4.0, tickRate = 0.34, spawnAtEnemy = true }, "ConsecratedGround", "GaleKnife" },
	{ "VoidFlood", "Void Flood", "Void", "Water", "Zone", { archetype = "Zone", baseDamage = 10.1, cooldown = 4.4, baseRadius = 7.0, duration = 4.3, tickRate = 0.34, spawnAtEnemy = true, pullStrength = 1.4 }, "Singularity", "RiptidePool" },
	{ "ThunderQuake", "Thunder Quake", "Electricity", "Earth", "Nova", { archetype = "Nova", baseDamage = 34, cooldown = 3.3, baseRadius = 9.2 }, "ShockBurst", "QuakeBurst" },
	{ "SolarFlare", "Solar Flare", "Light", "Fire", "Beam", { archetype = "Beam", baseDamage = 9.6, cooldown = 5.2, duration = 1.8, tickRate = 0.16, range = 60, width = 4.8 }, "SolarBeam", "InfernoBeam" },
}) do
	addComboSpell(spec)
end

local SYNERGY_LOOKUP = {}
local SYNERGY_BY_INGREDIENT = {}

for _, synergy in ipairs(SpellDefs.SYNERGIES) do
	SYNERGY_LOOKUP[synergy.key] = synergy
	for _, ingredient in ipairs(synergy.ingredients) do
		SYNERGY_BY_INGREDIENT[ingredient] = SYNERGY_BY_INGREDIENT[ingredient] or {}
		table.insert(SYNERGY_BY_INGREDIENT[ingredient], synergy)
	end
end

function SpellDefs.Get(id)
	return SpellDefs.SPELLS[id] or SpellDefs.SHOP_PRODUCTS[id]
end

function SpellDefs.GetSpell(id)
	return SpellDefs.SPELLS[id]
end

function SpellDefs.GetProduct(id)
	return SpellDefs.SHOP_PRODUCTS[id]
end

function SpellDefs.IsValid(id)
	return SpellDefs.Get(id) ~= nil
end

function SpellDefs.GetShopList()
	local out = {}
	for _, id in ipairs(SpellDefs.SHOP_ORDER) do
		table.insert(out, id)
	end
	return out
end

function SpellDefs.GetSpellIds()
	local out = {}
	for _, id in ipairs(SpellDefs.SPELL_ORDER) do
		table.insert(out, id)
	end
	return out
end

function SpellDefs.GetElementColor(element)
	local info = element and SpellDefs.ELEMENTS[element] or nil
	return info and info.color or SpellDefs.COLOR_BASE
end

function SpellDefs.GetSpellColor(spellIdOrDef)
	local def = typeof(spellIdOrDef) == "string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	return (def and def.displayColor) or (def and def.color) or SpellDefs.COLOR_BASE
end

function SpellDefs.GetTypeLimit(spellType)
	return spellType == "Physical" and SpellDefs.MAX_PHYSICAL_RUN_SPELLS or SpellDefs.MAX_MAGIC_RUN_SPELLS
end

function SpellDefs.ResolveUnlockedProducts(unlockedIds)
	local strongest = {}
	for _, id in ipairs(unlockedIds or {}) do
		local product = SpellDefs.SHOP_PRODUCTS[id]
		if product then
			local current = strongest[product.familyId]
			if not current or (SpellDefs.BASE_VARIANT_QUALITIES[product.baseQuality].basePower > SpellDefs.BASE_VARIANT_QUALITIES[current.baseQuality].basePower) then
				strongest[product.familyId] = product
			end
		end
	end
	return strongest
end

function SpellDefs.GetSynergyResult(a, b)
	if typeof(a) ~= "string" or typeof(b) ~= "string" or a == "" or b == "" then
		return nil
	end
	local key = (a < b) and (a .. "|" .. b) or (b .. "|" .. a)
	local synergy = SYNERGY_LOOKUP[key]
	return synergy and synergy.resultId or nil
end

function SpellDefs.GetSynergiesFor(spellId)
	local out = {}
	for _, synergy in ipairs(SYNERGY_BY_INGREDIENT[spellId] or {}) do
		table.insert(out, synergy)
	end
	return out
end

function SpellDefs.IsIngredientBlockedByCombo(spellId, activeSet)
	for _, synergy in ipairs(SYNERGY_BY_INGREDIENT[spellId] or {}) do
		if activeSet[synergy.resultId] then
			return true
		end
	end
	return false
end

function SpellDefs.GetSynergyHint(spellId, activeSet)
	for _, synergy in ipairs(SYNERGY_BY_INGREDIENT[spellId] or {}) do
		local other = synergy.ingredients[1] == spellId and synergy.ingredients[2] or synergy.ingredients[1]
		if activeSet[other] then
			return synergy.resultId, other
		end
	end
	return nil, nil
end

function SpellDefs.DescribeShopProduct(productIdOrDef)
	local product = typeof(productIdOrDef) == "string" and SpellDefs.GetProduct(productIdOrDef) or productIdOrDef
	if not product then return "" end
	local variant = SpellDefs.BASE_VARIANT_QUALITIES[product.baseQuality]
	return string.format("%s\n%s\n%s\nStronger variants start with better baseline stats and build potential.", product.category, variant and variant.label or "Base Variant", product.description or "")
end

function SpellDefs.DescribeNewOffer(productIdOrDef)
	local product = typeof(productIdOrDef) == "string" and SpellDefs.GetProduct(productIdOrDef) or productIdOrDef
	if not product then return "" end
	local variant = SpellDefs.BASE_VARIANT_QUALITIES[product.baseQuality]
	return string.format("%s\n%s\nUnlocks %s with %s values from the start.", product.category, variant and variant.label or "Base Variant", product.name, string.lower((variant and variant.shortLabel) or "standard"))
end

function SpellDefs.DescribeUpgradeOffer(spellIdOrDef, qualityId, currentLevel)
	local def = typeof(spellIdOrDef) == "string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	if not def then return "" end
	local quality = SpellDefs.UPGRADE_QUALITIES[qualityId] or SpellDefs.UPGRADE_QUALITIES.Common
	local nextLevel = math.clamp((currentLevel or 0) + 1, 1, def.maxLevel or 6)
	return string.format("%s\n%s\nUpgrade to Lv.%d. +%.2f upgrade power improves damage, size and effect scaling.", def.category, quality.bonusText, nextLevel, quality.power)
end

function SpellDefs.ComputeRuntimeStats(spellIdOrDef, state)
	local def = typeof(spellIdOrDef) == "string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	if not def then return nil end
	local runtime = copyTable(def.runtime or {})
	local level = math.max(1, math.floor(tonumber(state and state.level) or 1))
	local baseMultiplier = math.max(0.5, tonumber(state and state.baseMultiplier) or 1)
	local basePower = math.max(0, tonumber(state and state.basePower) or 0)
	local upgradePower = math.max(0, tonumber(state and state.upgradePower) or 0)
	local levelFactor = 1 + ((level - 1) * 0.18)
	local powerFactor = 1 + (basePower * 0.10) + (upgradePower * 0.08)
	local areaFactor = 1 + ((level - 1) * 0.05) + (basePower * 0.03) + (upgradePower * 0.02)
	local cooldownFactor = math.max(0.55, 1 - ((level - 1) * 0.025) - (upgradePower * 0.012) - (basePower * 0.01))
	runtime.damage = (runtime.baseDamage or 10) * baseMultiplier * levelFactor * powerFactor
	runtime.cooldown = (runtime.cooldown or 1) * cooldownFactor
	runtime.radius = (runtime.baseRadius or 0) * areaFactor
	runtime.duration = (runtime.duration or 0) * (1 + ((level - 1) * 0.06) + (upgradePower * 0.02))
	runtime.width = (runtime.width or 0) * areaFactor
	runtime.range = (runtime.range or 0) * (1 + ((level - 1) * 0.03) + (upgradePower * 0.01))
	runtime.projectileSpeed = (runtime.projectileSpeed or 0) * (1 + ((level - 1) * 0.02) + (upgradePower * 0.01))
	runtime.orbitSpeed = (runtime.orbitSpeed or 0) * (1 + ((level - 1) * 0.03) + (upgradePower * 0.01))
	runtime.count = math.max(1, math.floor((runtime.baseCount or 1) + math.floor((level - 1) / 3) * (runtime.countPerThreeLevels or 0) + math.floor(upgradePower / 4)))
	runtime.pierce = math.max(0, math.floor((runtime.pierce or 0) + (basePower >= 0.8 and 1 or 0) + math.floor(upgradePower / 6)))
	runtime.level = level
	runtime.baseMultiplier = baseMultiplier
	runtime.basePower = basePower
	runtime.upgradePower = upgradePower
	runtime.effectPower = 1 + ((level - 1) * 0.08) + (upgradePower * 0.06) + (basePower * 0.03)
	runtime.visualColor = SpellDefs.GetSpellColor(def)
	local effects = copyTable(EFFECTS[def.element] or {})
	if def.secondaryElement then
		for key, value in pairs(EFFECTS[def.secondaryElement] or {}) do
			if key ~= "note" and effects[key] == nil then
				effects[key] = value
			end
		end
	end
	runtime.effects = effects
	return runtime
end

function SpellDefs.SortSpellIds(ids)
	table.sort(ids, function(a, b)
		local da, db = SpellDefs.GetSpell(a), SpellDefs.GetSpell(b)
		if not da or not db then return tostring(a) < tostring(b) end
		if da.spellType ~= db.spellType then return da.spellType == "Magic" end
		local oa = SpellDefs.ELEMENTS[da.element] and SpellDefs.ELEMENTS[da.element].order or 99
		local ob = SpellDefs.ELEMENTS[db.element] and SpellDefs.ELEMENTS[db.element].order or 99
		if oa ~= ob then return oa < ob end
		if da.attackType ~= db.attackType then return tostring(da.attackType) < tostring(db.attackType) end
		return tostring(da.name) < tostring(db.name)
	end)
	return ids
end

function SpellDefs.GetQualityOrder()
	local out = {}
	for _, id in ipairs(QUALITY_ORDER) do
		table.insert(out, id)
	end
	return out
end

return SpellDefs
