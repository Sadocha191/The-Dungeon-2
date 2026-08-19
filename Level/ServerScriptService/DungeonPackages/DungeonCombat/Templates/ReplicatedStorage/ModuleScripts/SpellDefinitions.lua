local SpellDefs = {}

SpellDefs.MAX_MAGIC_RUN_SPELLS = 8
SpellDefs.MAX_PHYSICAL_RUN_SPELLS = 4
SpellDefs.MAX_RUN_SPELLS = SpellDefs.MAX_MAGIC_RUN_SPELLS + SpellDefs.MAX_PHYSICAL_RUN_SPELLS
SpellDefs.SPELL_LOADOUT_MAX_SLOTS = 6
SpellDefs.CODEX_HIDE_UNDISCOVERED_COMBO_DETAILS = true

SpellDefs.RARITY_WEIGHTS = { Common = 0.52, Uncommon = 0.28, Rare = 0.14, Epic = 0.06 }
SpellDefs.COLOR_BASE = Color3.fromRGB(120, 190, 255)
SpellDefs.COLOR_SHOP = Color3.fromRGB(190, 120, 255)

SpellDefs.UPGRADE_QUALITIES = {
	Common = { id = "Common", label = "Common Upgrade", power = 0.95, cardColor = Color3.fromRGB(220, 220, 220), bonusText = "Reliable scaling bump" },
	Uncommon = { id = "Uncommon", label = "Uncommon Upgrade", power = 1.30, cardColor = Color3.fromRGB(120, 255, 175), bonusText = "Sharper growth and utility" },
	Rare = { id = "Rare", label = "Rare Upgrade", power = 1.75, cardColor = Color3.fromRGB(120, 175, 255), bonusText = "Heavy spike to core stats" },
	Epic = { id = "Epic", label = "Epic Upgrade", power = 2.20, cardColor = Color3.fromRGB(255, 170, 120), bonusText = "Run-defining power jump" },
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
SpellDefs.COMBINATIONS = {}
SpellDefs.LEGACY_SPELL_IDS = {
	GustBurst = "WindBlade",
}
SpellDefs.LEGACY_PRODUCT_IDS = {
	GustBurst_Standard = "WindBlade_Standard",
	GustBurst_Amplified = "WindBlade_Amplified",
}

local BASE_VARIANT_ORDER = { "Standard", "Amplified" }
local QUALITY_ORDER = { "Common", "Uncommon", "Rare", "Epic" }

local function normalizeSpellId(id)
	if typeof(id) ~= "string" or id == "" then
		return id
	end
	return SpellDefs.LEGACY_SPELL_IDS[id] or id
end

local function normalizeProductId(id)
	if typeof(id) ~= "string" or id == "" then
		return id
	end
	return SpellDefs.LEGACY_PRODUCT_IDS[id] or id
end

SpellDefs.NormalizeSpellId = normalizeSpellId
SpellDefs.NormalizeProductId = normalizeProductId

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

local ARCHETYPE_PROFILES = {
	Projectile = {
		damage = 1.00,
		cooldown = 1.00,
		range = 1.03,
		eliteMultiplier = 1.05,
		bossMultiplier = 1.00,
		breakpointCount = 1,
		breakpointPierce = 1,
	},
	Orbit = {
		damage = 0.68,
		hitCooldown = 1.18,
		radius = 0.95,
		eliteMultiplier = 0.90,
		bossMultiplier = 0.82,
		breakpointCount = 1,
		breakpointRadius = 0.08,
	},
	Nova = {
		damage = 1.08,
		cooldown = 1.06,
		eliteMultiplier = 1.00,
		bossMultiplier = 0.94,
		breakpointRadius = 0.14,
		breakpointDamage = 0.06,
	},
	Zone = {
		damage = 0.90,
		cooldown = 0.98,
		radius = 1.02,
		duration = 1.08,
		eliteMultiplier = 0.92,
		bossMultiplier = 0.86,
		breakpointRadius = 0.10,
		breakpointDuration = 0.12,
	},
	Beam = {
		damage = 1.16,
		cooldown = 0.94,
		duration = 1.06,
		width = 1.08,
		eliteMultiplier = 1.12,
		bossMultiplier = 1.18,
		breakpointDuration = 0.10,
		breakpointWidth = 0.12,
	},
}

local UPGRADE_COPY_BY_ELEMENT_AND_ATTACK = {
	Fire = {
		Projectile = "Bolts hit harder, fly faster, and stack nastier burns.",
		Orbit = "Orbiting embers sweep wider and keep nearby enemies burning.",
		Nova = "The blast expands and leaves a fiercer burn at the center.",
		Zone = "The fire zone spreads farther, lasts longer, and cooks trapped foes.",
		Beam = "The beam reaches farther, widens out, and sears targets harder.",
	},
	Electricity = {
		Projectile = "Needles fire faster, punch harder, and ramp into extra shots.",
		Orbit = "The halo spins faster, circles wider, and keeps enemies shocked.",
		Nova = "The burst hits a larger ring and delivers a nastier shock.",
		Zone = "The storm zone covers more ground and stuns enemies caught inside.",
		Beam = "The ray stretches farther, grows wider, and shocks through crowds.",
	},
	Air = {
		Projectile = "Knives fly faster, hit harder, and cut through more targets.",
		Orbit = "The ring spins faster, sweeps wider, and batters enemies back.",
		Nova = "The gust expands into a stronger knockback burst around you.",
		Zone = "The tornado grows wider, lasts longer, and drags foes deeper in.",
		Beam = "The jetstream reaches farther, widens out, and shoves harder.",
	},
	Water = {
		Projectile = "Shards hit harder, travel faster, and deepen their slow.",
		Orbit = "The tide ring circles wider and keeps nearby enemies slowed.",
		Nova = "The splash expands and leaves enemies slowed for longer.",
		Zone = "The pool spreads wider, lingers longer, and bogs enemies down.",
		Beam = "The beam reaches farther, grows wider, and strengthens its slow.",
	},
	Earth = {
		Projectile = "Stone spikes hit harder, fly faster, and land with heavier stagger.",
		Orbit = "The orbit swings wider and hammers nearby foes with stronger stagger.",
		Nova = "The quake erupts wider and smashes enemies with heavier force.",
		Zone = "The patch spreads wider, lasts longer, and punishes anything stuck inside.",
		Beam = "The fault line stretches farther, widens, and batters enemies harder.",
	},
	Void = {
		Projectile = "Shards hit harder, pierce cleaner, and pull enemies into follow-ups.",
		Orbit = "The halo widens, spins faster, and keeps nearby enemies off balance.",
		Nova = "The burst expands and leaves enemies more exposed to damage.",
		Zone = "The singularity grows wider, lasts longer, and drags whole packs inward.",
		Beam = "The ray reaches farther, widens out, and tears open bigger damage windows.",
	},
	Light = {
		Projectile = "Bolts fly faster, pierce deeper, and mark enemies for more damage.",
		Orbit = "The halo sweeps wider and keeps nearby enemies marked.",
		Nova = "The burst expands and brands a wider crowd for follow-up damage.",
		Zone = "The ground effect spreads wider, lasts longer, and amplifies all damage dealt.",
		Beam = "The beam reaches farther, grows wider, and marks enemies for longer.",
	},
	Physical = {
		Projectile = "Axes hit harder, spin faster, and ramp into extra throws.",
		Orbit = "Hammers sweep a wider ring and keep melee threats bleeding.",
		Nova = "The slam expands and crushes enemies in a heavier shockwave.",
		Zone = "The field spreads wider, lasts longer, and shreds anything crossing it.",
		Beam = "The whirlwind reaches wider, lasts longer, and carves through packs harder.",
	},
}

local UPGRADE_COPY_BY_SPELL = {
	FireTornado = "The inferno widens, pulls harder, and roasts everything trapped in the funnel.",
	StormSurge = "The surge spreads farther, lasts longer, and keeps whole lanes stunned and slowed.",
	MagmaCrash = "The impact radius grows and the eruption leaves a brutal burning stagger.",
	RadiantTempest = "The tempest covers more ground and keeps enemies marked while they are tossed around.",
	VoidFlood = "The flood widens, pulls harder, and leaves whole packs vulnerable in the current.",
	ThunderQuake = "The shockwave expands and slams enemies with heavier stun and stagger.",
	SolarFlare = "The flare reaches farther, burns brighter, and leaves enemies exposed to follow-up damage.",
}

SpellDefs.SPELL_PRESENTATION = {}

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

local function makeVisualDirection(presentation)
	local parts = {
		presentation.castVfx,
		presentation.travelVfx,
		presentation.impactVfx,
		presentation.lingeringVfx,
	}
	local out = {}
	for _, part in ipairs(parts) do
		if typeof(part) == "string" and part ~= "" then
			table.insert(out, part)
		end
	end
	return table.concat(out, " -> ")
end

local function makePresentation(def)
	local source = SpellDefs.SPELL_PRESENTATION[def.id] or {}
	local presentation = copyTable(source)
	local name = tostring(def.name or def.id or "Spell")
	local fallbackIcon = string.upper(string.sub((def.id or name), 1, 2))
	local element = tostring(def.element or "Spell")
	local attackType = tostring(def.attackType or "spell")

	presentation.iconGlyph = presentation.iconGlyph or fallbackIcon
	presentation.artMotif = presentation.artMotif or string.format("%s signature %s form", name, attackType)
	presentation.silhouette = presentation.silhouette or string.format("%s %s silhouette", name, attackType)
	presentation.motion = presentation.motion or tostring(ATTACK_NOTES[def.attackType] or "distinct spell motion")
	presentation.loreDescription = presentation.loreDescription or string.format("%s carries a distinct %s ritual mark.", name, string.lower(element))
	presentation.gameplayDescription = presentation.gameplayDescription or makeDescription(def)
	presentation.castVfx = presentation.castVfx or string.format("%s cast sigil", name)
	presentation.travelVfx = presentation.travelVfx or string.format("%s %s trail", name, string.lower(attackType))
	presentation.impactVfx = presentation.impactVfx or string.format("%s impact mark", name)
	presentation.lingeringVfx = presentation.lingeringVfx or string.format("%s afterimage", name)
	presentation.frameStyle = presentation.frameStyle or (def.isCombo and "fusion frame" or string.format("%s frame", string.lower(element)))
	presentation.codexCategory = presentation.codexCategory or (def.isCombo and "Fusion Spell" or def.category)
	presentation.witchbookAccent = presentation.witchbookAccent or element

	local motifs = presentation.motifs
	if typeof(motifs) ~= "table" or #motifs == 0 then
		motifs = { presentation.artMotif, presentation.silhouette }
	end
	presentation.motifs = motifs
	presentation.visualDirection = presentation.visualDirection or makeVisualDirection(presentation)

	local profile = presentation.visualProfile
	if typeof(profile) ~= "table" then
		profile = {}
	end
	profile.silhouette = profile.silhouette or presentation.silhouette
	profile.motion = profile.motion or presentation.motion
	profile.castShape = profile.castShape or presentation.castVfx
	profile.travelShape = profile.travelShape or presentation.travelVfx
	profile.impactShape = profile.impactShape or presentation.impactVfx
	profile.lingerShape = profile.lingerShape or presentation.lingeringVfx
	profile.frameStyle = profile.frameStyle or presentation.frameStyle
	profile.motifs = profile.motifs or copyTable(motifs)
	profile.accentCount = tonumber(profile.accentCount) or (def.isCombo and 4 or 2)
	profile.combo = def.isCombo == true
	presentation.visualProfile = profile

	if def.fusionIngredients and not presentation.fusionInfo then
		presentation.fusionInfo = {
			ingredients = copyTable(def.fusionIngredients),
			resultId = def.id,
		}
	end

	return presentation
end

local function makeUpgradeDescription(def)
	if not def then
		return "Improves damage, coverage, and the spell's signature effect."
	end

	if UPGRADE_COPY_BY_SPELL[def.id] then
		return UPGRADE_COPY_BY_SPELL[def.id]
	end

	local byElement = UPGRADE_COPY_BY_ELEMENT_AND_ATTACK[def.element]
	if byElement and byElement[def.attackType] then
		return byElement[def.attackType]
	end

	return "Improves damage, coverage, and the spell's signature effect."
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
		iconGlyph = def.iconGlyph,
		artMotif = def.artMotif,
		loreDescription = def.loreDescription,
		gameplayDescription = def.gameplayDescription,
		visualDirection = def.visualDirection,
		frameStyle = def.frameStyle,
		codexCategory = def.codexCategory,
		witchbookAccent = def.witchbookAccent,
		visualProfile = copyTable(def.visualProfile or {}),
		presentation = copyTable(def.presentation or {}),
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
	local presentation = makePresentation(def)
	def.presentation = presentation
	def.iconGlyph = presentation.iconGlyph
	def.artMotif = presentation.artMotif
	def.loreDescription = presentation.loreDescription
	def.gameplayDescription = presentation.gameplayDescription
	def.visualDirection = presentation.visualDirection
	def.frameStyle = presentation.frameStyle
	def.codexCategory = presentation.codexCategory
	def.witchbookAccent = presentation.witchbookAccent
	def.visualProfile = copyTable(presentation.visualProfile or {})
	def.maxLevel = def.maxLevel or 6
	SpellDefs.SPELLS[def.id] = def
	table.insert(SpellDefs.SPELL_ORDER, def.id)
	if def.shopAvailable ~= false then
		for _, variantId in ipairs(BASE_VARIANT_ORDER) do
			addProduct(def, variantId, SpellDefs.BASE_VARIANT_QUALITIES[variantId])
		end
	end
end

local function makeSynergyKey(ingredients)
	local sorted = {}
	for _, ingredient in ipairs(ingredients or {}) do
		if typeof(ingredient) == "string" and ingredient ~= "" then
			table.insert(sorted, normalizeSpellId(ingredient))
		end
	end
	table.sort(sorted)
	return table.concat(sorted, "|")
end

local function addSynergy(resultId, ...)
	local ingredients = {}
	local required = {}
	for _, ingredient in ipairs({ ... }) do
		local normalizedIngredient = normalizeSpellId(ingredient)
		if typeof(normalizedIngredient) == "string" and normalizedIngredient ~= "" then
			table.insert(ingredients, normalizedIngredient)
			required[normalizedIngredient] = "MAX"
		end
	end

	local normalizedResult = normalizeSpellId(resultId)
	local synergy = {
		id = normalizedResult,
		Id = normalizedResult,
		resultId = normalizedResult,
		ResultSpell = normalizedResult,
		resultSpell = normalizedResult,
		ingredients = ingredients,
		RequiredSpells = required,
		RequiredLevel = "MAX",
		ReplaceBaseSpells = true,
		HiddenUntilDiscovered = false,
		key = makeSynergyKey(ingredients),
	}
	table.insert(SpellDefs.SYNERGIES, synergy)
	table.insert(SpellDefs.COMBINATIONS, synergy)
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
		fusionIngredients = { spec[7], spec[8] },
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
	{ "WindBlade", "Wind Blade", "Magic", "Air", "Nova", 230, { archetype = "Nova", baseDamage = 22, cooldown = 2.8, baseRadius = 9.6 } },
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
local COMBINATION_BY_ID = {}
local COMBINATION_BY_RESULT = {}

for _, synergy in ipairs(SpellDefs.SYNERGIES) do
	SYNERGY_LOOKUP[synergy.key] = synergy
	COMBINATION_BY_ID[synergy.id] = synergy
	COMBINATION_BY_RESULT[synergy.resultId] = synergy
	for _, ingredient in ipairs(synergy.ingredients) do
		SYNERGY_BY_INGREDIENT[ingredient] = SYNERGY_BY_INGREDIENT[ingredient] or {}
		table.insert(SYNERGY_BY_INGREDIENT[ingredient], synergy)
	end
end

function SpellDefs.Get(id)
	local spellId = normalizeSpellId(id)
	if SpellDefs.SPELLS[spellId] then
		return SpellDefs.SPELLS[spellId]
	end
	return SpellDefs.SHOP_PRODUCTS[normalizeProductId(id)]
end

function SpellDefs.GetSpell(id)
	return SpellDefs.SPELLS[normalizeSpellId(id)]
end

function SpellDefs.GetProduct(id)
	return SpellDefs.SHOP_PRODUCTS[normalizeProductId(id)]
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

function SpellDefs.GetPresentation(spellIdOrDef)
	local def = typeof(spellIdOrDef) == "string" and (SpellDefs.GetSpell(spellIdOrDef) or SpellDefs.GetProduct(spellIdOrDef)) or spellIdOrDef
	return def and copyTable(def.presentation or {}) or {}
end

function SpellDefs.GetVisualProfile(spellIdOrDef)
	local def = typeof(spellIdOrDef) == "string" and (SpellDefs.GetSpell(spellIdOrDef) or SpellDefs.GetProduct(spellIdOrDef)) or spellIdOrDef
	return def and copyTable(def.visualProfile or (def.presentation and def.presentation.visualProfile) or {}) or {}
end

function SpellDefs.GetSpellArtData(spellIdOrDef)
	local def = typeof(spellIdOrDef) == "string" and (SpellDefs.GetSpell(spellIdOrDef) or SpellDefs.GetProduct(spellIdOrDef)) or spellIdOrDef
	if not def then
		return {}
	end
	local presentation = def.presentation or {}
	return {
		iconGlyph = def.iconGlyph or presentation.iconGlyph,
		artMotif = def.artMotif or presentation.artMotif,
		frameStyle = def.frameStyle or presentation.frameStyle,
		witchbookAccent = def.witchbookAccent or presentation.witchbookAccent,
		color = SpellDefs.GetSpellColor(def),
	}
end

function SpellDefs.DescribeVisualDirection(spellIdOrDef)
	local def = typeof(spellIdOrDef) == "string" and (SpellDefs.GetSpell(spellIdOrDef) or SpellDefs.GetProduct(spellIdOrDef)) or spellIdOrDef
	if not def then
		return ""
	end
	return def.visualDirection or (def.presentation and def.presentation.visualDirection) or ""
end

function SpellDefs.GetTypeLimit(spellType)
	return spellType == "Physical" and SpellDefs.MAX_PHYSICAL_RUN_SPELLS or SpellDefs.MAX_MAGIC_RUN_SPELLS
end

function SpellDefs.ResolveUnlockedProducts(unlockedIds)
	local strongest = {}
	for _, id in ipairs(unlockedIds or {}) do
		local product = SpellDefs.GetProduct(id)
		if not product and typeof(id) == "string" then
			product = SpellDefs.GetProduct(("%s_Standard"):format(normalizeSpellId(id)))
		end
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
	a = normalizeSpellId(a)
	b = normalizeSpellId(b)
	if typeof(a) ~= "string" or typeof(b) ~= "string" or a == "" or b == "" then
		return nil
	end
	local key = makeSynergyKey({ a, b })
	local synergy = SYNERGY_LOOKUP[key]
	return synergy and synergy.resultId or nil
end

function SpellDefs.GetSynergiesFor(spellId)
	spellId = normalizeSpellId(spellId)
	local out = {}
	for _, synergy in ipairs(SYNERGY_BY_INGREDIENT[spellId] or {}) do
		table.insert(out, synergy)
	end
	return out
end

function SpellDefs.IsIngredientBlockedByCombo(spellId, activeSet)
	spellId = normalizeSpellId(spellId)
	for _, synergy in ipairs(SYNERGY_BY_INGREDIENT[spellId] or {}) do
		if activeSet[synergy.resultId] then
			return true
		end
	end
	return false
end

function SpellDefs.GetSynergyHint(spellId, activeSet)
	spellId = normalizeSpellId(spellId)
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
	return string.format("%s\n%s\n%s\nVisual: %s\nStronger variants start with better baseline stats and build potential.", product.category, variant and variant.label or "Base Variant", product.gameplayDescription or product.description or "", product.visualDirection or "")
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
	return string.format("%s\n%s (+%.2f power)\nLv.%d: %s\nVisual: %s", def.category, quality.bonusText, quality.power, nextLevel, makeUpgradeDescription(def), def.visualDirection or "")
end

function SpellDefs.ComputeRuntimeStats(spellIdOrDef, state)
	local def = typeof(spellIdOrDef) == "string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	if not def then return nil end
	local runtime = copyTable(def.runtime or {})
	local level = math.max(1, math.floor(tonumber(state and state.level) or 1))
	local baseMultiplier = math.max(0.5, tonumber(state and state.baseMultiplier) or 1)
	local basePower = math.max(0, tonumber(state and state.basePower) or 0)
	local upgradePower = math.max(0, tonumber(state and state.upgradePower) or 0)
	local levelFactor = 1 + ((level - 1) * 0.15)
	local powerFactor = 1 + (basePower * 0.085) + (upgradePower * 0.062)
	local areaFactor = 1 + ((level - 1) * 0.045) + (basePower * 0.026) + (upgradePower * 0.017)
	local cooldownFactor = math.max(0.60, 1 - ((level - 1) * 0.020) - (upgradePower * 0.010) - (basePower * 0.009))
	runtime.damage = (runtime.baseDamage or 10) * baseMultiplier * levelFactor * powerFactor
	runtime.cooldown = (runtime.cooldown or 1) * cooldownFactor
	runtime.radius = (runtime.baseRadius or 0) * areaFactor
	runtime.duration = (runtime.duration or 0) * (1 + ((level - 1) * 0.055) + (upgradePower * 0.018))
	runtime.width = (runtime.width or 0) * areaFactor
	runtime.range = (runtime.range or 0) * (1 + ((level - 1) * 0.028) + (upgradePower * 0.009))
	runtime.projectileSpeed = (runtime.projectileSpeed or 0) * (1 + ((level - 1) * 0.018) + (upgradePower * 0.009))
	runtime.orbitSpeed = (runtime.orbitSpeed or 0) * (1 + ((level - 1) * 0.028) + (upgradePower * 0.009))
	runtime.hitCooldown = math.max(0.12, (runtime.hitCooldown or 0.35) * math.max(0.82, 1 - ((level - 1) * 0.008) - (upgradePower * 0.004)))
	runtime.count = math.max(1, math.floor((runtime.baseCount or 1) + math.floor((level - 1) / 5) * (runtime.countPerThreeLevels or 0) + math.floor(upgradePower / 6)))
	runtime.pierce = math.max(0, math.floor((runtime.pierce or 0) + (basePower >= 0.8 and 1 or 0) + math.floor(upgradePower / 8)))
	runtime.level = level
	runtime.baseMultiplier = baseMultiplier
	runtime.basePower = basePower
	runtime.upgradePower = upgradePower
	runtime.effectPower = 1 + ((level - 1) * 0.07) + (upgradePower * 0.050) + (basePower * 0.025)
	runtime.spellId = def.id
	runtime.spellName = def.name
	runtime.element = def.element
	runtime.secondaryElement = def.secondaryElement
	runtime.attackType = def.attackType
	runtime.spellType = def.spellType
	local archetype = tostring(runtime.archetype or def.attackType or "")
	local profile = ARCHETYPE_PROFILES[archetype]
	if profile then
		runtime.damage *= profile.damage or 1
		runtime.cooldown *= profile.cooldown or 1
		runtime.radius *= profile.radius or 1
		runtime.duration *= profile.duration or 1
		runtime.width *= profile.width or 1
		runtime.range *= profile.range or 1
		runtime.hitCooldown *= profile.hitCooldown or 1

		local breakpointTier = 0
		if upgradePower >= 2.2 then
			breakpointTier = 1
		end
		if upgradePower >= 4.8 then
			breakpointTier = 2
		end
		runtime.breakpointTier = breakpointTier

		if breakpointTier > 0 then
			runtime.count += math.floor((profile.breakpointCount or 0) * breakpointTier)
			runtime.pierce += math.floor((profile.breakpointPierce or 0) * breakpointTier)
			runtime.radius *= 1 + ((profile.breakpointRadius or 0) * breakpointTier)
			runtime.duration *= 1 + ((profile.breakpointDuration or 0) * breakpointTier)
			runtime.width *= 1 + ((profile.breakpointWidth or 0) * breakpointTier)
			runtime.damage *= 1 + ((profile.breakpointDamage or 0) * breakpointTier)
		end

		runtime.eliteDamageMultiplier = profile.eliteMultiplier or 1
		runtime.bossDamageMultiplier = profile.bossMultiplier or 1
	else
		runtime.breakpointTier = 0
		runtime.eliteDamageMultiplier = 1
		runtime.bossDamageMultiplier = 1
	end
	runtime.visualColor = SpellDefs.GetSpellColor(def)
	runtime.visualSecondaryColor = def.secondaryElement and SpellDefs.GetElementColor(def.secondaryElement) or blend(runtime.visualColor, Color3.new(1, 1, 1), def.spellType == "Physical" and 0.18 or 0.34)
	runtime.iconGlyph = def.iconGlyph
	runtime.artMotif = def.artMotif
	runtime.visualDirection = def.visualDirection
	runtime.visualProfile = copyTable(def.visualProfile or {})
	runtime.presentation = copyTable(def.presentation or {})
	runtime.isCombo = def.isCombo == true
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

function SpellDefs.GetLoadoutLimit()
	return SpellDefs.SPELL_LOADOUT_MAX_SLOTS
end

function SpellDefs.ProductToSpellId(productId)
	local product = SpellDefs.GetProduct(productId)
	if product then
		return product.familyId
	end
	return normalizeSpellId(productId)
end

function SpellDefs.NormalizeLoadoutProductId(id)
	if typeof(id) == "table" then
		id = id.id or id.productId or id.ProductId or id.spellId or id.SpellId
	end
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	local productId = normalizeProductId(id)
	if SpellDefs.GetProduct(productId) then
		return productId
	end
	local familyId = normalizeSpellId(productId)
	local standardId = ("%s_Standard"):format(familyId)
	if SpellDefs.GetProduct(standardId) then
		return standardId
	end
	return nil
end

local function unlockedContains(unlockedMap, productId)
	if typeof(unlockedMap) ~= "table" then
		return false
	end
	if unlockedMap[productId] == true then
		return true
	end
	local product = SpellDefs.GetProduct(productId)
	if product and unlockedMap[product.familyId] == true then
		return true
	end
	return false
end

function SpellDefs.ValidateSpellLoadout(rawLoadout, unlockedMap)
	local out = {}
	local seenFamilies = {}
	local limit = SpellDefs.GetLoadoutLimit()

	if typeof(rawLoadout) ~= "table" then
		return out
	end

	for _, rawId in ipairs(rawLoadout) do
		local productId = SpellDefs.NormalizeLoadoutProductId(rawId)
		local product = productId and SpellDefs.GetProduct(productId) or nil
		if product and unlockedContains(unlockedMap, productId) and not seenFamilies[product.familyId] then
			seenFamilies[product.familyId] = true
			table.insert(out, productId)
			if #out >= limit then
				break
			end
		end
	end

	return out
end

function SpellDefs.BuildDefaultLoadout(unlockedMap)
	local out = {}
	local seen = {}
	local limit = SpellDefs.GetLoadoutLimit()

	local function tryAdd(productId)
		local normalized = SpellDefs.NormalizeLoadoutProductId(productId)
		local product = normalized and SpellDefs.GetProduct(normalized) or nil
		if product and unlockedContains(unlockedMap, normalized) and not seen[product.familyId] then
			seen[product.familyId] = true
			table.insert(out, normalized)
		end
	end

	for _, productId in ipairs(SpellDefs.BASE_STARTER or {}) do
		tryAdd(productId)
		if #out >= limit then
			return out
		end
	end

	local unlockedList = {}
	if typeof(unlockedMap) == "table" then
		for id, value in pairs(unlockedMap) do
			if value == true and typeof(id) == "string" then
				table.insert(unlockedList, id)
			end
		end
	end
	table.sort(unlockedList)
	for _, productId in ipairs(unlockedList) do
		tryAdd(productId)
		if #out >= limit then
			break
		end
	end

	return out
end

local function fmtNumber(value, decimals)
	local n = tonumber(value) or 0
	if math.abs(n - math.floor(n + 0.5)) < 0.01 then
		return tostring(math.floor(n + 0.5))
	end
	return string.format("%." .. tostring(decimals or 1) .. "f", n)
end

function SpellDefs.GetSpellStatLines(spellIdOrDef, state)
	local def = typeof(spellIdOrDef) == "string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	local stats = SpellDefs.ComputeRuntimeStats(def, state or { level = 1 })
	if not def or not stats then
		return {}
	end

	local lines = {
		("Damage %s"):format(fmtNumber(stats.damage, 1)),
		("Cooldown %ss"):format(fmtNumber(stats.cooldown, 2)),
	}
	if stats.count and stats.count > 1 then
		table.insert(lines, ("Count %d"):format(stats.count))
	end
	if stats.pierce and stats.pierce > 0 then
		table.insert(lines, ("Pierce %d"):format(stats.pierce))
	end
	if stats.radius and stats.radius > 0 then
		table.insert(lines, ("Radius %s"):format(fmtNumber(stats.radius, 1)))
	end
	if stats.range and stats.range > 0 then
		table.insert(lines, ("Range %s"):format(fmtNumber(stats.range, 1)))
	end
	if stats.duration and stats.duration > 0 then
		table.insert(lines, ("Duration %ss"):format(fmtNumber(stats.duration, 1)))
	end
	return lines
end

function SpellDefs.GetSpellUpgradeLevels(spellId)
	local def = SpellDefs.GetSpell(spellId)
	local out = {}
	if not def then
		return out
	end
	for level = 1, tonumber(def.maxLevel) or 6 do
		table.insert(out, {
			level = level,
			statLines = SpellDefs.GetSpellStatLines(def, { level = level }),
		})
	end
	return out
end

function SpellDefs.GetCombinationList()
	local out = {}
	for _, combo in ipairs(SpellDefs.COMBINATIONS) do
		table.insert(out, combo)
	end
	return out
end

function SpellDefs.GetCombinationById(comboId)
	return COMBINATION_BY_ID[normalizeSpellId(comboId)]
end

function SpellDefs.GetCombinationForResult(resultId)
	return COMBINATION_BY_RESULT[normalizeSpellId(resultId)]
end

local function readLevel(levelSource, spellId)
	if type(levelSource) == "function" then
		return tonumber(levelSource(spellId)) or 0
	end
	if typeof(levelSource) == "table" then
		return tonumber(levelSource[spellId]) or 0
	end
	return 0
end

function SpellDefs.CanOfferCombination(comboOrId, levelSource, hasResult)
	local combo = typeof(comboOrId) == "table" and comboOrId or SpellDefs.GetCombinationById(comboOrId)
	if not combo then
		return false
	end

	local resultId = combo.resultId
	if type(hasResult) == "function" and hasResult(resultId) then
		return false
	elseif typeof(hasResult) == "table" and hasResult[resultId] == true then
		return false
	elseif getmetatable(hasResult) == nil and hasResult == true then
		return false
	end

	for _, ingredient in ipairs(combo.ingredients or {}) do
		local def = SpellDefs.GetSpell(ingredient)
		local maxLevel = tonumber(def and def.maxLevel) or 6
		if readLevel(levelSource, ingredient) < maxLevel then
			return false
		end
	end
	return true
end

function SpellDefs.DescribeCombination(comboOrId)
	local combo = typeof(comboOrId) == "table" and comboOrId or SpellDefs.GetCombinationById(comboOrId)
	if not combo then
		return ""
	end
	local resultDef = SpellDefs.GetSpell(combo.resultId)
	local parts = {}
	for _, ingredient in ipairs(combo.ingredients or {}) do
		local def = SpellDefs.GetSpell(ingredient)
		local maxLevel = tonumber(def and def.maxLevel) or 6
		table.insert(parts, ("%s Lv.%d"):format(def and def.name or ingredient, maxLevel))
	end
	local resultName = resultDef and resultDef.name or combo.resultId
	local replaceText = combo.ReplaceBaseSpells ~= false and "Replaces its base spells when chosen." or "Keeps its base spells when chosen."
	return ("Requires %s.\nResult: %s.\n%s"):format(table.concat(parts, " + "), resultName, replaceText)
end

function SpellDefs.GetCombinationStatus(comboOrId, levelSource, discoveredMap)
	local combo = typeof(comboOrId) == "table" and comboOrId or SpellDefs.GetCombinationById(comboOrId)
	if not combo then
		return "unknown"
	end
	if typeof(discoveredMap) == "table" and discoveredMap[combo.id] == true then
		return "discovered"
	end
	if SpellDefs.CanOfferCombination(combo, levelSource, false) then
		return "ready"
	end
	return "locked"
end

function SpellDefs.SummarizeDamageByElement(productIds)
	local totals = {}
	for _, rawId in ipairs(productIds or {}) do
		local productId = SpellDefs.NormalizeLoadoutProductId(rawId)
		local product = productId and SpellDefs.GetProduct(productId) or nil
		local def = product and SpellDefs.GetSpell(product.familyId) or nil
		if product and def then
			local stats = SpellDefs.ComputeRuntimeStats(def, {
				level = 1,
				baseMultiplier = product.baseMultiplier,
				basePower = product.basePower,
			})
			local element = def.element or "Physical"
			totals[element] = (totals[element] or 0) + math.max(0, tonumber(stats and stats.damage) or 0)
		end
	end

	local out = {}
	for element, damage in pairs(totals) do
		table.insert(out, {
			element = element,
			damage = math.floor(damage * 10 + 0.5) / 10,
			color = SpellDefs.GetElementColor(element),
		})
	end
	table.sort(out, function(a, b)
		local oa = SpellDefs.ELEMENTS[a.element] and SpellDefs.ELEMENTS[a.element].order or 99
		local ob = SpellDefs.ELEMENTS[b.element] and SpellDefs.ELEMENTS[b.element].order or 99
		return oa < ob
	end)
	return out
end

return SpellDefs
