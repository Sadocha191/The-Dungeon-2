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
	Common = { id = "Common", label = "Common Upgrade", power = 1.00, cardColor = Color3.fromRGB(220, 220, 220), bonusText = "Reliable scaling bump" },
	Uncommon = { id = "Uncommon", label = "Uncommon Upgrade", power = 1.40, cardColor = Color3.fromRGB(120, 255, 175), bonusText = "Sharper growth and utility" },
	Rare = { id = "Rare", label = "Rare Upgrade", power = 1.85, cardColor = Color3.fromRGB(120, 175, 255), bonusText = "Heavy spike to core stats" },
	Epic = { id = "Epic", label = "Epic Upgrade", power = 2.35, cardColor = Color3.fromRGB(255, 170, 120), bonusText = "Run-defining power jump" },
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

SpellDefs.SPELL_PRESENTATION = {
	FireBolt = {
		iconGlyph = "FB",
		artMotif = "forked ember comet",
		silhouette = "comet",
		motion = "quick arcing shot with twin ember tails",
		loreDescription = "A candle-flame curse compressed into a fast hunting spark.",
		gameplayDescription = "Single-target opener that fires quickly and applies burn pressure.",
		castVfx = "palm spark and ember snap",
		travelVfx = "forked comet with two coal tails",
		impactVfx = "white-hot pop with falling embers",
		lingeringVfx = "short smoke bite on the target",
		frameStyle = "charred brass",
		codexCategory = "Elemental Projectile",
		witchbookAccent = "ember ink",
		motifs = { "split tail", "coal flecks" },
	},
	EmberOrbit = {
		iconGlyph = "EO",
		artMotif = "two lantern embers in a guardian loop",
		silhouette = "lantern orbit",
		motion = "steady orbit with bobbing coal cores",
		loreDescription = "Old watch-lights that circle their keeper and nip at anything too close.",
		gameplayDescription = "Close-range defensive orbit that keeps nearby enemies burning.",
		castVfx = "small ring of lantern sparks",
		travelVfx = "embers circling like tiny watch lamps",
		impactVfx = "coal kiss and red ash spray",
		lingeringVfx = "thin ember trail around the player",
		frameStyle = "smoked glass",
		codexCategory = "Elemental Orbit",
		witchbookAccent = "lantern red",
		motifs = { "lantern core", "ash loop" },
	},
	FlameBurst = {
		iconGlyph = "FL",
		artMotif = "opened furnace flower",
		silhouette = "petal blast",
		motion = "short inhale followed by a petal-shaped flare",
		loreDescription = "A furnace bloom that opens for one violent heartbeat.",
		gameplayDescription = "Point-blank burst that clears space and leaves burning enemies behind.",
		castVfx = "heat shimmer ring under the caster",
		travelVfx = "expanding fire petals",
		impactVfx = "flower-shaped blast and ash plume",
		lingeringVfx = "scorched petal marks on the ground",
		frameStyle = "furnace iron",
		codexCategory = "Elemental Nova",
		witchbookAccent = "molten orange",
		motifs = { "furnace flower", "petal flare" },
	},
	ScorchField = {
		iconGlyph = "SC",
		artMotif = "cracked kiln circle",
		silhouette = "burning field",
		motion = "ground cracks glow outward in an uneven circle",
		loreDescription = "A witch-mark that turns the floor into a patient kiln.",
		gameplayDescription = "Enemy-targeted zone that rewards holding packs inside sustained burn damage.",
		castVfx = "charcoal sigil under the target",
		travelVfx = "rising heat ribbons",
		impactVfx = "kiln cracks opening in the floor",
		lingeringVfx = "low fire licking along cracked seams",
		frameStyle = "blackened stone",
		codexCategory = "Elemental Zone",
		witchbookAccent = "kiln glow",
		motifs = { "cracked kiln", "heat ribbons" },
	},
	InfernoBeam = {
		iconGlyph = "IB",
		artMotif = "dragon-breath lance",
		silhouette = "flame lance",
		motion = "narrow ignition that fattens into a roaring line",
		loreDescription = "A stolen breath from the first furnace, shaped into a lance.",
		gameplayDescription = "Sustained line attack for burning a lane through dense enemies.",
		castVfx = "bright throat of flame at the caster",
		travelVfx = "braided flame lance",
		impactVfx = "searing bead at the beam tip",
		lingeringVfx = "floating soot sparks along the lane",
		frameStyle = "molten spine",
		codexCategory = "Elemental Beam",
		witchbookAccent = "furnace gold",
		motifs = { "braided flame", "soot sparks" },
	},
	VoltNeedle = {
		iconGlyph = "VN",
		artMotif = "tailor needle of lightning",
		silhouette = "needle",
		motion = "needle-straight shot with jittering side arcs",
		loreDescription = "A storm-thread pulled tight enough to pierce armor.",
		gameplayDescription = "Fast projectile with brief shock control on contact.",
		castVfx = "static pinch between two points",
		travelVfx = "thin needle with sawtooth arcs",
		impactVfx = "pinpoint flash and split fork",
		lingeringVfx = "tiny static stitches on the enemy",
		frameStyle = "etched copper",
		codexCategory = "Elemental Projectile",
		witchbookAccent = "storm yellow",
		motifs = { "sawtooth arcs", "static stitches" },
	},
	StaticHalo = {
		iconGlyph = "SH",
		artMotif = "broken crown of charged teeth",
		silhouette = "jagged halo",
		motion = "quick orbit with snapping electrical gaps",
		loreDescription = "A cracked crown that refuses to sit still.",
		gameplayDescription = "Orbiting shock ring that interrupts close threats.",
		castVfx = "crown teeth blink around the player",
		travelVfx = "jagged halo segments",
		impactVfx = "short stun spark between halo teeth",
		lingeringVfx = "blue-white static ticks",
		frameStyle = "copper crown",
		codexCategory = "Elemental Orbit",
		witchbookAccent = "charged copper",
		motifs = { "crown teeth", "static ticks" },
	},
	ShockBurst = {
		iconGlyph = "SB",
		artMotif = "shattered bell of thunder",
		silhouette = "bell shockwave",
		motion = "compressed pulse that rings outward",
		loreDescription = "A silent bell that only enemies hear.",
		gameplayDescription = "Radial shock burst for interrupting a surrounding pack.",
		castVfx = "small bell outline underfoot",
		travelVfx = "flat ringing wave",
		impactVfx = "bell-crack lightning spokes",
		lingeringVfx = "fading vibration bars",
		frameStyle = "storm bronze",
		codexCategory = "Elemental Nova",
		witchbookAccent = "bell gold",
		motifs = { "bell crack", "vibration bars" },
	},
	StormField = {
		iconGlyph = "ST",
		artMotif = "square storm grid",
		silhouette = "storm grid",
		motion = "cells flicker on and off inside the zone",
		loreDescription = "A storm caged into a grid so it can be placed like a trap.",
		gameplayDescription = "Targeted zone that repeatedly shocks and controls enemies.",
		castVfx = "grid tile snaps into place",
		travelVfx = "rain of small electric ticks",
		impactVfx = "cell-by-cell lightning strikes",
		lingeringVfx = "crackling storm lattice",
		frameStyle = "black copper lattice",
		codexCategory = "Elemental Zone",
		witchbookAccent = "storm grid",
		motifs = { "storm lattice", "cell sparks" },
	},
	ThunderRay = {
		iconGlyph = "TR",
		artMotif = "forked tuning rod",
		silhouette = "forked ray",
		motion = "rigid beam with forked side lashes",
		loreDescription = "A tuning rod aimed at the heart of a storm.",
		gameplayDescription = "Sustained lightning ray that drills through a lane and shocks targets.",
		castVfx = "forked rod flash at the hand",
		travelVfx = "straight ray with side lashes",
		impactVfx = "branching tip split",
		lingeringVfx = "fading ozone beads",
		frameStyle = "polished copper",
		codexCategory = "Elemental Beam",
		witchbookAccent = "ozone blue",
		motifs = { "forked rod", "side lashes" },
	},
	GaleKnife = {
		iconGlyph = "GK",
		artMotif = "glass-thin wind dagger",
		silhouette = "knife",
		motion = "fast slicing shot with feathered wake",
		loreDescription = "A blade made from the edge of a mountain gust.",
		gameplayDescription = "Piercing projectile that cuts through early lines of enemies.",
		castVfx = "thin cut in the air",
		travelVfx = "white knife with feather wake",
		impactVfx = "clean slash mark and air pop",
		lingeringVfx = "brief feather motes",
		frameStyle = "pale bone",
		codexCategory = "Elemental Projectile",
		witchbookAccent = "high wind",
		motifs = { "feather wake", "air cut" },
	},
	WindRing = {
		iconGlyph = "WR",
		artMotif = "paper fan circle",
		silhouette = "fan ring",
		motion = "folded gusts rotate like a paper fan",
		loreDescription = "A folded wind charm that opens only when danger crowds in.",
		gameplayDescription = "Orbit that knocks enemies back while sweeping a wider perimeter.",
		castVfx = "fan ribs unfold around the player",
		travelVfx = "rotating paper-fan gusts",
		impactVfx = "soft shove and pale slash",
		lingeringVfx = "curling air ribbons",
		frameStyle = "white lacquer",
		codexCategory = "Elemental Orbit",
		witchbookAccent = "wind white",
		motifs = { "fan ribs", "air ribbons" },
	},
	WindBlade = {
		iconGlyph = "WB",
		artMotif = "crescent cutter",
		silhouette = "crescent",
		motion = "visible wind slash sweeps forward from the caster",
		loreDescription = "A crescent of pressure sharpened by a practiced wrist.",
		gameplayDescription = "Directional nova slash that gives the air family a stronger cast feel.",
		castVfx = "drawn crescent before release",
		travelVfx = "wide pale blade arc",
		impactVfx = "gust impact with slice particles",
		lingeringVfx = "thin crescent afterimage",
		frameStyle = "silver reed",
		codexCategory = "Elemental Nova",
		witchbookAccent = "blade wind",
		motifs = { "crescent arc", "slash motes" },
	},
	Tornado = {
		iconGlyph = "TO",
		artMotif = "rope funnel",
		silhouette = "funnel",
		motion = "spiral column that tugs inward",
		loreDescription = "A wandering rope of sky tied to the battlefield.",
		gameplayDescription = "Pulling zone that groups enemies while dealing repeated air damage.",
		castVfx = "small dust knot at target point",
		travelVfx = "stacked funnel rings",
		impactVfx = "dust lift and spiral pull",
		lingeringVfx = "visible funnel boundary",
		frameStyle = "storm cloth",
		codexCategory = "Elemental Zone",
		witchbookAccent = "dust white",
		motifs = { "funnel rings", "dust knot" },
	},
	Jetstream = {
		iconGlyph = "JS",
		artMotif = "racing wind corridor",
		silhouette = "wind lane",
		motion = "flat high-speed corridor with streak lines",
		loreDescription = "The straight road a storm takes when it is late.",
		gameplayDescription = "Long beam-like gust that pushes and damages enemies in a lane.",
		castVfx = "compressed air gate",
		travelVfx = "streaked wind corridor",
		impactVfx = "white pressure burst at the front",
		lingeringVfx = "speed lines fading down the lane",
		frameStyle = "brushed silver",
		codexCategory = "Elemental Beam",
		witchbookAccent = "jet white",
		motifs = { "speed lines", "air gate" },
	},
	WaterShard = {
		iconGlyph = "WS",
		artMotif = "blue glass shard",
		silhouette = "water shard",
		motion = "heavy droplet shard with a curved wake",
		loreDescription = "A splinter of river glass, cold enough to slow a heartbeat.",
		gameplayDescription = "Reliable projectile that slows targets on hit.",
		castVfx = "droplet gathers into a shard",
		travelVfx = "blue shard with curved wake",
		impactVfx = "splash chip and frost mist",
		lingeringVfx = "wet glimmer on the target",
		frameStyle = "river glass",
		codexCategory = "Elemental Projectile",
		witchbookAccent = "river blue",
		motifs = { "curved wake", "frost mist" },
	},
	TideOrbit = {
		iconGlyph = "TI",
		artMotif = "moon-tide droplets",
		silhouette = "droplet orbit",
		motion = "two droplets rise and fall like a tide chart",
		loreDescription = "A pocket tide that keeps returning to its witch.",
		gameplayDescription = "Orbiting water that slows enemies crossing its ring.",
		castVfx = "small moon ripple around feet",
		travelVfx = "droplets on a rising tide path",
		impactVfx = "soft splash and chill mark",
		lingeringVfx = "ripple ring around the player",
		frameStyle = "moonlit silver",
		codexCategory = "Elemental Orbit",
		witchbookAccent = "moon tide",
		motifs = { "moon ripple", "tide droplets" },
	},
	FrostSplash = {
		iconGlyph = "FS",
		artMotif = "bursting ice lily",
		silhouette = "ice splash",
		motion = "cold splash blooms outward in pointed petals",
		loreDescription = "A pond flower frozen at the exact moment it breaks.",
		gameplayDescription = "Burst control spell that slows enemies around the player.",
		castVfx = "cold ring and small vapor breath",
		travelVfx = "ice-lily splash",
		impactVfx = "pointed frost petals",
		lingeringVfx = "low freezing mist",
		frameStyle = "frosted silver",
		codexCategory = "Elemental Nova",
		witchbookAccent = "ice lily",
		motifs = { "ice petals", "freezing mist" },
	},
	RiptidePool = {
		iconGlyph = "RP",
		artMotif = "spiral current pool",
		silhouette = "whirlpool",
		motion = "flat spiral current with moving inner bands",
		loreDescription = "A small ocean argument placed under an enemy's feet.",
		gameplayDescription = "Targeted water zone that slows and chips enemies over time.",
		castVfx = "pool spiral opens",
		travelVfx = "rotating current bands",
		impactVfx = "inward splash line",
		lingeringVfx = "visible whirlpool edge",
		frameStyle = "dark pearl",
		codexCategory = "Elemental Zone",
		witchbookAccent = "deep current",
		motifs = { "current bands", "whirlpool edge" },
	},
	TidalBeam = {
		iconGlyph = "TB",
		artMotif = "pressurized wave column",
		silhouette = "wave beam",
		motion = "streaming column with crest marks along the top",
		loreDescription = "A tide forced through the eye of a needle.",
		gameplayDescription = "Sustained water beam that slows enemies caught in its line.",
		castVfx = "crest curls at the caster",
		travelVfx = "wave column with white crests",
		impactVfx = "spray burst at the tip",
		lingeringVfx = "falling droplets down the lane",
		frameStyle = "blue enamel",
		codexCategory = "Elemental Beam",
		witchbookAccent = "wave crest",
		motifs = { "white crests", "falling droplets" },
	},
	StoneSpike = {
		iconGlyph = "SK",
		artMotif = "chiseled green stone lance",
		silhouette = "stone lance",
		motion = "heavy straight shot with tumbling grit",
		loreDescription = "A mountain tooth broken loose and taught to fly.",
		gameplayDescription = "Heavier projectile that hits hard and staggers enemies.",
		castVfx = "stone chip lifts from the ground",
		travelVfx = "rough stone lance with grit wake",
		impactVfx = "rock chip burst",
		lingeringVfx = "small cracked mark",
		frameStyle = "moss stone",
		codexCategory = "Elemental Projectile",
		witchbookAccent = "moss green",
		motifs = { "grit wake", "mountain tooth" },
	},
	RockOrbit = {
		iconGlyph = "RO",
		artMotif = "two moon rocks on iron paths",
		silhouette = "boulder orbit",
		motion = "weighty orbit with slow rolling spin",
		loreDescription = "Little boulders that remember the hill they rolled down.",
		gameplayDescription = "Slower orbit with heavier hits and stagger value.",
		castVfx = "stones pull up into orbit",
		travelVfx = "rolling rocks with dust halos",
		impactVfx = "blunt chip and dust puff",
		lingeringVfx = "dust ring around the caster",
		frameStyle = "ironstone",
		codexCategory = "Elemental Orbit",
		witchbookAccent = "dust green",
		motifs = { "dust halos", "rolling stone" },
	},
	QuakeBurst = {
		iconGlyph = "QB",
		artMotif = "broken tectonic plate",
		silhouette = "quake plate",
		motion = "ground plate snaps upward then settles",
		loreDescription = "A borrowed shrug from the deep rock below.",
		gameplayDescription = "High-impact nova that staggers enemies around the player.",
		castVfx = "fault seam draws underfoot",
		travelVfx = "radial plate lift",
		impactVfx = "chunk burst and dust wall",
		lingeringVfx = "short ground crack",
		frameStyle = "basalt rim",
		codexCategory = "Elemental Nova",
		witchbookAccent = "basalt green",
		motifs = { "fault seam", "dust wall" },
	},
	BramblePatch = {
		iconGlyph = "BP",
		artMotif = "thorned root snare",
		silhouette = "bramble snare",
		motion = "roots crawl outward in crooked lanes",
		loreDescription = "A hungry patch of roots that mistakes monsters for rain.",
		gameplayDescription = "Zone that punishes enemies standing in a thorny patch.",
		castVfx = "seed mark splits open",
		travelVfx = "crooked root lanes",
		impactVfx = "thorn snap and leaf dust",
		lingeringVfx = "visible bramble boundary",
		frameStyle = "thornwood",
		codexCategory = "Elemental Zone",
		witchbookAccent = "root green",
		motifs = { "root lanes", "thorn snap" },
	},
	FaultLine = {
		iconGlyph = "FX",
		artMotif = "straight cracked ridge",
		silhouette = "fault beam",
		motion = "ground line splits forward in hard segments",
		loreDescription = "A map of where the earth would rather break.",
		gameplayDescription = "Wide line attack that batters enemies along the crack.",
		castVfx = "stone ridge rises at the caster",
		travelVfx = "segmented crack racing forward",
		impactVfx = "rock teeth at the line end",
		lingeringVfx = "fading fracture glow",
		frameStyle = "split slate",
		codexCategory = "Elemental Beam",
		witchbookAccent = "fault green",
		motifs = { "segmented crack", "rock teeth" },
	},
	VoidShard = {
		iconGlyph = "VS",
		artMotif = "missing-piece crystal",
		silhouette = "void shard",
		motion = "dark shard slides forward with delayed purple echo",
		loreDescription = "A fragment shaped like the space left after something was taken.",
		gameplayDescription = "Piercing projectile that pulls and exposes enemies for follow-up damage.",
		castVfx = "small absence opens in the hand",
		travelVfx = "black shard with purple echo",
		impactVfx = "inward pop and violet tear",
		lingeringVfx = "short vulnerability mark",
		frameStyle = "obsidian violet",
		codexCategory = "Elemental Projectile",
		witchbookAccent = "void violet",
		motifs = { "delayed echo", "violet tear" },
	},
	AbyssHalo = {
		iconGlyph = "AH",
		artMotif = "eclipse ring",
		silhouette = "eclipse orbit",
		motion = "dark orbit with a bright rim chasing it",
		loreDescription = "An eclipse small enough to be worn as protection.",
		gameplayDescription = "Orbit that destabilizes nearby enemies and sets up burst damage.",
		castVfx = "eclipse rim closes around the player",
		travelVfx = "dark halo with bright rim",
		impactVfx = "soft implosion touch",
		lingeringVfx = "purple orbit smear",
		frameStyle = "eclipse metal",
		codexCategory = "Elemental Orbit",
		witchbookAccent = "eclipse violet",
		motifs = { "bright rim", "implosion touch" },
	},
	NullBurst = {
		iconGlyph = "NB",
		artMotif = "inverted star collapse",
		silhouette = "collapse star",
		motion = "draws inward for a beat, then snaps outward",
		loreDescription = "A star that learned how to fall in every direction.",
		gameplayDescription = "Void nova that exposes surrounding enemies to more damage.",
		castVfx = "inward star lines",
		travelVfx = "negative-space pulse",
		impactVfx = "collapse snap and purple spikes",
		lingeringVfx = "thin vulnerability ring",
		frameStyle = "black star",
		codexCategory = "Elemental Nova",
		witchbookAccent = "null purple",
		motifs = { "inward star", "purple spikes" },
	},
	Singularity = {
		iconGlyph = "SG",
		artMotif = "black well with silver rim",
		silhouette = "gravity well",
		motion = "flat well pulls particles inward",
		loreDescription = "A tiny argument with gravity that gravity usually wins.",
		gameplayDescription = "Pulling zone that groups enemies and increases follow-up damage windows.",
		castVfx = "silver rim circles the target",
		travelVfx = "particles dragged inward",
		impactVfx = "well opens with a dark pulse",
		lingeringVfx = "visible inward pull bands",
		frameStyle = "silver void rim",
		codexCategory = "Elemental Zone",
		witchbookAccent = "gravity violet",
		motifs = { "inward bands", "silver rim" },
	},
	EntropyRay = {
		iconGlyph = "ER",
		artMotif = "unraveling thread beam",
		silhouette = "unravel ray",
		motion = "beam frays at the edges as it travels",
		loreDescription = "A line of undoing, pulled loose from the edge of a spell.",
		gameplayDescription = "Void beam that opens enemies to heavier follow-up damage.",
		castVfx = "thread knot pulls tight",
		travelVfx = "dark ray with frayed edges",
		impactVfx = "unraveling thread burst",
		lingeringVfx = "loose violet threads",
		frameStyle = "frayed obsidian",
		codexCategory = "Elemental Beam",
		witchbookAccent = "thread violet",
		motifs = { "frayed edges", "thread knot" },
	},
	RadiantBolt = {
		iconGlyph = "RB",
		artMotif = "sun nail",
		silhouette = "radiant nail",
		motion = "straight golden nail with small halo wake",
		loreDescription = "A nail of daylight hammered through shadow.",
		gameplayDescription = "Piercing projectile that marks enemies to take more damage.",
		castVfx = "small halo stamp",
		travelVfx = "gold nail with halo wake",
		impactVfx = "bright nail-head flash",
		lingeringVfx = "mark glyph on the enemy",
		frameStyle = "sun gilt",
		codexCategory = "Elemental Projectile",
		witchbookAccent = "day gold",
		motifs = { "halo wake", "mark glyph" },
	},
	HaloOrbit = {
		iconGlyph = "HO",
		artMotif = "saint ring with twin sparks",
		silhouette = "clean halo",
		motion = "smooth orbit with measured holy ticks",
		loreDescription = "A small oath of light that keeps circling back.",
		gameplayDescription = "Orbit that repeatedly marks close enemies for more damage.",
		castVfx = "halo locks above the player",
		travelVfx = "clean ring with twin sparks",
		impactVfx = "soft gold brand",
		lingeringVfx = "thin aureole trail",
		frameStyle = "gilded ivory",
		codexCategory = "Elemental Orbit",
		witchbookAccent = "aureole gold",
		motifs = { "aureole trail", "gold brand" },
	},
	Sunburst = {
		iconGlyph = "SU",
		artMotif = "many-point sun seal",
		silhouette = "sun seal",
		motion = "gold spokes snap outward from a bright center",
		loreDescription = "A sunrise folded into a seal and released all at once.",
		gameplayDescription = "Radial light burst that brands a crowd for follow-up damage.",
		castVfx = "sun seal ignites underfoot",
		travelVfx = "many-point gold spokes",
		impactVfx = "bright corona pop",
		lingeringVfx = "small sun marks",
		frameStyle = "sun ivory",
		codexCategory = "Elemental Nova",
		witchbookAccent = "corona gold",
		motifs = { "gold spokes", "sun marks" },
	},
	ConsecratedGround = {
		iconGlyph = "CG",
		artMotif = "cathedral floor seal",
		silhouette = "sanctuary seal",
		motion = "geometric floor lines fill with gold",
		loreDescription = "A borrowed square of sanctuary drawn under hostile feet.",
		gameplayDescription = "Light zone that deals damage and amplifies follow-up hits.",
		castVfx = "floor seal draws in straight strokes",
		travelVfx = "ordered gold lattice",
		impactVfx = "sanctuary lines ignite",
		lingeringVfx = "readable holy boundary",
		frameStyle = "cathedral glass",
		codexCategory = "Elemental Zone",
		witchbookAccent = "sanctuary gold",
		motifs = { "gold lattice", "holy boundary" },
	},
	SolarBeam = {
		iconGlyph = "SL",
		artMotif = "pillar of noon light",
		silhouette = "solar pillar",
		motion = "clean white-gold column with heat shimmer",
		loreDescription = "Noon narrowed into a single merciless line.",
		gameplayDescription = "Sustained light beam that pierces lanes and marks targets.",
		castVfx = "solar aperture opens",
		travelVfx = "white-gold column",
		impactVfx = "sun bead at the beam tip",
		lingeringVfx = "gold motes in the lane",
		frameStyle = "polished ivory",
		codexCategory = "Elemental Beam",
		witchbookAccent = "noon gold",
		motifs = { "solar aperture", "gold motes" },
	},
	AxeThrow = {
		iconGlyph = "AX",
		artMotif = "notched throwing axe",
		silhouette = "spinning axe",
		motion = "metal spin with a heavy forward wobble",
		loreDescription = "A practical answer to magic: throw the sharp thing very well.",
		gameplayDescription = "Physical projectile with chunky hits and bleed pressure.",
		castVfx = "metal glint at shoulder height",
		travelVfx = "spinning axe with grey trail",
		impactVfx = "metal chop and red chip",
		lingeringVfx = "short bleed slash",
		frameStyle = "worn steel",
		codexCategory = "Physical Projectile",
		witchbookAccent = "steel grey",
		motifs = { "metal spin", "bleed slash" },
	},
	GuardHammers = {
		iconGlyph = "GH",
		artMotif = "paired watch hammers",
		silhouette = "hammer orbit",
		motion = "two hammers circle like patient sentries",
		loreDescription = "The oath of a guard translated into blunt metal.",
		gameplayDescription = "Physical orbit that protects the player with heavy bleed hits.",
		castVfx = "two hammer heads rise into formation",
		travelVfx = "paired hammer orbit",
		impactVfx = "heavy clang and chip sparks",
		lingeringVfx = "dull steel trail",
		frameStyle = "guard steel",
		codexCategory = "Physical Orbit",
		witchbookAccent = "iron blue",
		motifs = { "paired hammers", "chip sparks" },
	},
	GroundSlam = {
		iconGlyph = "GS",
		artMotif = "shockplate stomp",
		silhouette = "slam plate",
		motion = "downward force ring with chunky debris",
		loreDescription = "A refusal to share the ground with monsters.",
		gameplayDescription = "Physical nova that crushes and bleeds nearby enemies.",
		castVfx = "raised boot-ring shadow",
		travelVfx = "low shockplate",
		impactVfx = "debris pop and dust punch",
		lingeringVfx = "round impact scar",
		frameStyle = "dented iron",
		codexCategory = "Physical Nova",
		witchbookAccent = "impact grey",
		motifs = { "shockplate", "impact scar" },
	},
	CaltropField = {
		iconGlyph = "CF",
		artMotif = "scattered four-point spikes",
		silhouette = "spike field",
		motion = "spikes blink into a practical hazard grid",
		loreDescription = "A trapmaker's handful of bad decisions.",
		gameplayDescription = "Physical zone that shreds enemies crossing the field.",
		castVfx = "small spikes toss outward",
		travelVfx = "hazard grid of four-point spikes",
		impactVfx = "sharp metal pricks",
		lingeringVfx = "readable caltrop field",
		frameStyle = "scratched iron",
		codexCategory = "Physical Zone",
		witchbookAccent = "trap steel",
		motifs = { "four-point spikes", "hazard grid" },
	},
	WhirlwindSlash = {
		iconGlyph = "WW",
		artMotif = "wide sword wheel",
		silhouette = "slash wheel",
		motion = "broad melee lane that reads as a spinning cut",
		loreDescription = "A sword swing stretched until it becomes weather.",
		gameplayDescription = "Short, wide physical beam that carves enemies in front of the player.",
		castVfx = "blade wheel flashes at the caster",
		travelVfx = "wide rotating slash lane",
		impactVfx = "steel arc and chip sparks",
		lingeringVfx = "grey cut afterimage",
		frameStyle = "polished steel",
		codexCategory = "Physical Beam",
		witchbookAccent = "blade grey",
		motifs = { "blade wheel", "cut afterimage" },
	},
	FireTornado = {
		iconGlyph = "FT",
		artMotif = "burning rope funnel",
		silhouette = "fusion funnel",
		motion = "air funnel wrapped in climbing flame bands",
		loreDescription = "Wind gives fire a spine, and the flame learns how to hunt in circles.",
		gameplayDescription = "Fusion zone that pulls enemies into a burning tornado.",
		castVfx = "fire and wind sigils braid together",
		travelVfx = "spiral flame funnel",
		impactVfx = "ember cyclone bite",
		lingeringVfx = "hot spiral boundary",
		frameStyle = "fused ember silver",
		codexCategory = "Fusion Zone",
		witchbookAccent = "ember gale",
		motifs = { "braided sigils", "flame funnel" },
	},
	StormSurge = {
		iconGlyph = "SR",
		artMotif = "electrified breaker wave",
		silhouette = "storm wave",
		motion = "water pool flashes with lightning veins",
		loreDescription = "A tide that stole thunder and kept it in its foam.",
		gameplayDescription = "Fusion zone that slows and shocks enemies over repeated ticks.",
		castVfx = "wave crest crossed by lightning",
		travelVfx = "charged breaker bands",
		impactVfx = "splash strike and electric foam",
		lingeringVfx = "storm foam grid",
		frameStyle = "charged pearl",
		codexCategory = "Fusion Zone",
		witchbookAccent = "storm tide",
		motifs = { "electric foam", "breaker bands" },
	},
	MagmaCrash = {
		iconGlyph = "MC",
		artMotif = "lava meteor plate",
		silhouette = "magma impact",
		motion = "heavy molten plate slams outward",
		loreDescription = "Earth holds the furnace door while fire kicks it open.",
		gameplayDescription = "Fusion nova with a brutal burning stagger radius.",
		castVfx = "molten crack gathers underfoot",
		travelVfx = "rising lava plate",
		impactVfx = "magma plate crash and ember rocks",
		lingeringVfx = "hot cracks fading to black",
		frameStyle = "lava basalt",
		codexCategory = "Fusion Nova",
		witchbookAccent = "magma red",
		motifs = { "lava plate", "ember rocks" },
	},
	RadiantTempest = {
		iconGlyph = "RT",
		artMotif = "holy storm compass",
		silhouette = "radiant cyclone",
		motion = "gold compass spokes spin inside a wind zone",
		loreDescription = "A storm taught manners by a sanctuary bell.",
		gameplayDescription = "Fusion zone that tosses enemies while marking them for damage.",
		castVfx = "compass rose and gust seal overlap",
		travelVfx = "gold cyclone spokes",
		impactVfx = "bright gust brand",
		lingeringVfx = "compass boundary in the storm",
		frameStyle = "gilded silver",
		codexCategory = "Fusion Zone",
		witchbookAccent = "holy gale",
		motifs = { "compass rose", "gold cyclone" },
	},
	VoidFlood = {
		iconGlyph = "VF",
		artMotif = "black current whirl",
		silhouette = "void tide",
		motion = "dark water pulls inward with purple undertow",
		loreDescription = "A flood from the place where rivers disappear.",
		gameplayDescription = "Fusion zone that drags, slows, and exposes packs.",
		castVfx = "water ring sinks into a void rim",
		travelVfx = "black current with purple undertow",
		impactVfx = "inward splash collapse",
		lingeringVfx = "undertow bands",
		frameStyle = "black pearl",
		codexCategory = "Fusion Zone",
		witchbookAccent = "undertow violet",
		motifs = { "void rim", "undertow bands" },
	},
	ThunderQuake = {
		iconGlyph = "TQ",
		artMotif = "charged fault hammer",
		silhouette = "shock fracture",
		motion = "earth crack detonates with lightning teeth",
		loreDescription = "The ground breaks first; the thunder arrives to sign its name.",
		gameplayDescription = "Fusion nova that stuns and staggers a wide circle.",
		castVfx = "fault seam charges yellow",
		travelVfx = "radial crack with lightning teeth",
		impactVfx = "electric stone burst",
		lingeringVfx = "charged fracture lines",
		frameStyle = "copper basalt",
		codexCategory = "Fusion Nova",
		witchbookAccent = "storm stone",
		motifs = { "lightning teeth", "charged fracture" },
	},
	SolarFlare = {
		iconGlyph = "XR",
		artMotif = "white-hot solar lance",
		silhouette = "solar flare beam",
		motion = "sun beam with licking fire corona",
		loreDescription = "Daylight and fire agree to stop being subtle.",
		gameplayDescription = "Fusion beam that burns and exposes everything in a lane.",
		castVfx = "sun aperture ringed by flame",
		travelVfx = "white-hot lance with fire corona",
		impactVfx = "flare bead and ember halo",
		lingeringVfx = "gold ash in the lane",
		frameStyle = "solar enamel",
		codexCategory = "Fusion Beam",
		witchbookAccent = "solar fire",
		motifs = { "fire corona", "gold ash" },
	},
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

	presentation.iconGlyph = presentation.iconGlyph or fallbackIcon
	presentation.artMotif = presentation.artMotif or string.format("%s %s motif", def.element or "Spell", def.attackType or "spell")
	presentation.silhouette = presentation.silhouette or tostring(def.attackType or "spell")
	presentation.motion = presentation.motion or tostring(ATTACK_NOTES[def.attackType] or "distinct spell motion")
	presentation.loreDescription = presentation.loreDescription or string.format("%s carries a signature %s ritual mark.", name, string.lower(tostring(def.element or "spell")))
	presentation.gameplayDescription = presentation.gameplayDescription or makeDescription(def)
	presentation.castVfx = presentation.castVfx or "signature cast sigil"
	presentation.travelVfx = presentation.travelVfx or presentation.motion
	presentation.impactVfx = presentation.impactVfx or "clear impact flash"
	presentation.lingeringVfx = presentation.lingeringVfx or "brief readable afterimage"
	presentation.frameStyle = presentation.frameStyle or (def.isCombo and "fusion frame" or string.format("%s frame", string.lower(tostring(def.element or "spell"))))
	presentation.codexCategory = presentation.codexCategory or (def.isCombo and "Fusion Spell" or def.category)
	presentation.witchbookAccent = presentation.witchbookAccent or tostring(def.element or "Spell")

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
	return SpellDefs.SPELLS[normalizeSpellId(id)] or SpellDefs.SHOP_PRODUCTS[normalizeProductId(id)]
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
	if typeof(a) ~= "string" or typeof(b) ~= "string" or a == "" or b == "" then
		return nil
	end
	local key = makeSynergyKey({ a, b })
	local synergy = SYNERGY_LOOKUP[key]
	return synergy and synergy.resultId or nil
end

function SpellDefs.GetSynergiesFor(spellId)
	local out = {}
	for _, synergy in ipairs(SYNERGY_BY_INGREDIENT[normalizeSpellId(spellId)] or {}) do
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
	runtime.spellId = def.id
	runtime.spellName = def.name
	runtime.element = def.element
	runtime.secondaryElement = def.secondaryElement
	runtime.attackType = def.attackType
	runtime.spellType = def.spellType
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
