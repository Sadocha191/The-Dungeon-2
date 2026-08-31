local SpellDefs = {}

SpellDefs.MAX_MAGIC_RUN_SPELLS = 8
SpellDefs.MAX_PHYSICAL_RUN_SPELLS = 0
SpellDefs.MAX_RUN_SPELLS = SpellDefs.MAX_MAGIC_RUN_SPELLS
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
	Air = { order = 1, color = Color3.fromRGB(224, 238, 244) },
	Fire = { order = 2, color = Color3.fromRGB(255, 98, 54) },
	Void = { order = 3, color = Color3.fromRGB(118, 78, 168) },
	Lightning = { order = 4, color = Color3.fromRGB(255, 221, 84) },
	Earth = { order = 5, color = Color3.fromRGB(118, 168, 88) },
	Water = { order = 6, color = Color3.fromRGB(70, 160, 255) },
	Ice = { order = 7, color = Color3.fromRGB(152, 220, 255) },
	Light = { order = 8, color = Color3.fromRGB(255, 236, 176) },
}

SpellDefs.BASE_STARTER = {
	"FireBall_Standard",
	"Tornado_Standard",
	"AirBullet_Standard",
	"RockThrow_Standard",
	"IceShard_Standard",
}

SpellDefs.SPELLS = {}
SpellDefs.SHOP_PRODUCTS = {}
SpellDefs.SPELL_ORDER = {}
SpellDefs.SHOP_ORDER = {}
SpellDefs.SYNERGIES = {}
SpellDefs.COMBINATIONS = {}
SpellDefs.SPELL_PRESENTATION = {}

SpellDefs.LEGACY_SPELL_IDS = {
	GustBurst = "WindBlade",
	FireBolt = "FireBall",
	StoneSpike = "RockThrow",
	RockOrbit = "OrbitingRocks",
	SolarBeam = "SunRay",
}
SpellDefs.LEGACY_PRODUCT_IDS = {}
for legacyId, currentId in pairs(SpellDefs.LEGACY_SPELL_IDS) do
	SpellDefs.LEGACY_PRODUCT_IDS[legacyId .. "_Standard"] = currentId .. "_Standard"
	SpellDefs.LEGACY_PRODUCT_IDS[legacyId .. "_Amplified"] = currentId .. "_Amplified"
end

local BASE_VARIANT_ORDER = { "Standard", "Amplified" }
local QUALITY_ORDER = { "Common", "Uncommon", "Rare", "Epic" }

local function copyTable(src)
	local out = {}
	for key, value in pairs(src or {}) do
		out[key] = typeof(value) == "table" and copyTable(value) or value
	end
	return out
end

local function normalizeSpellId(id)
	if typeof(id) ~= "string" or id == "" then return id end
	return SpellDefs.LEGACY_SPELL_IDS[id] or id
end

local function normalizeProductId(id)
	if typeof(id) ~= "string" or id == "" then return id end
	return SpellDefs.LEGACY_PRODUCT_IDS[id] or id
end

SpellDefs.NormalizeSpellId = normalizeSpellId
SpellDefs.NormalizeProductId = normalizeProductId

local DEFAULT_EFFECTS = {
	Air = { knockback = { force = 18 } },
	Fire = { dot = { kind = "Burn", dps = 4.5, duration = 2.2 } },
	Void = { pull = { force = 14 }, vulnerability = { pct = 0.08, duration = 1.2 } },
	Lightning = { stun = { duration = 0.22 } },
	Earth = { knockback = { force = 14 }, slow = { pct = 0.14, duration = 0.8 } },
	Water = { slow = { pct = 0.22, duration = 1.0 } },
	Ice = { slow = { pct = 0.34, duration = 1.4 } },
	Light = { vulnerability = { pct = 0.10, duration = 1.4 } },
}

local ATTACK_NOTES = {
	Projectile = "Auto-fires at a nearby enemy.",
	Nova = "Triggers an area attack around its cast point.",
	Zone = "Creates a persistent area that repeatedly affects enemies.",
	MovingZone = "Creates a persistent area that moves across the ground.",
	Beam = "Fires a sustained line attack.",
	Orbit = "Creates objects orbiting the player.",
	Chain = "Jumps between nearby enemies.",
	Dash = "Moves the player and damages enemies along the path.",
	Pillar = "Creates a persistent pillar near the player.",
	Global = "Affects enemies across the battlefield.",
	Gates = "Summons portals above the player that fire at enemies.",
}

local UPGRADE_LABELS = {
	unlock = "Unlock spell",
	damage = "Damage increase",
	globalDamage = "Global damage increase",
	range = "Range increase",
	aoe = "AoE range increase",
	duration = "Duration increase",
	cooldown = "Cooldown reduction",
	pull = "Pull strength increase",
	pullRange = "Pull range increase",
	pullSpeed = "Pull speed increase",
	lift = "Increased lift strength and stronger slow against heavy enemies",
	follow = "Spell follows nearby enemies",
	secondTornado = "Spawns a second smaller tornado nearby",
	knockback = "Knockback increase",
	rangeBig = "Range greatly increased",
	doubleHit = "Hits enemies twice during one cast",
	width = "Width increase",
	closeBonus = "Enemies close to the player take increased damage",
	massiveOuter = "Massive radius and increased damage at the outer edge",
	projectileSpeed = "Projectile speed increase",
	statusSpread = "Status effects spread to nearby enemies",
	statusRange = "Status spread range increase",
	statusMore = "Spreads status effects to more enemies",
	split3 = "Splits into 3 smaller projectiles after impact",
	wider = "Attack becomes wider and hits more enemies",
	mediumKnockback = "Stronger knockback against medium enemies",
	secondWave = "Creates a second weaker wave shortly after the first",
	multiDirection = "Releases attacks in multiple directions",
	burnDamage = "Burning damage increase",
	burnDuration = "Burning duration increase",
	burningGround = "Explosion leaves burning ground",
	burningBonus = "Burning enemies take increased damage",
	secondExplosion = "Creates a second explosion after impact",
	shockwave = "Creates a shockwave on impact",
	fallSpeed = "Fall speed increase",
	burningZone = "Creates a burning zone on impact",
	zoneDuration = "Lingering zone duration increase",
	fragments = "Fragments into smaller projectiles after impact",
	fragmentCount = "Fragment count increase",
	fragmentDamage = "Fragment damage increase",
	miniMeteors = "Calls down several smaller meteors around the impact",
	flightRange = "Flight range increase",
	fireTrail = "Leaves a fire trail behind",
	trailDuration = "Trail duration increase",
	moveSpeed = "Movement speed increase",
	secondPass = "Returns for a second pass",
	feathers = "Releases projectiles during flight",
	featherCount = "Projectile count increase",
	trailDamage = "Trail damage increase",
	explodeReborn = "Explodes at the end and is reborn at the player",
	root = "Enemies pulled to the center are briefly rooted",
	secondPull = "Creates a second inward pull shortly after impact",
	rootDuration = "Root duration increase",
	centerBonus = "Enemies near the center take bonus damage",
	centerDamage = "Center damage increase",
	singularity = "Collapses into a short-lived pulling singularity",
	energyGain = "Energy gain increase",
	energyRequired = "Energy required reduction",
	fearDuration = "Fear duration increase",
	lowHpBonus = "Additional damage to low HP enemies",
	weakness = "Leaves enemies weakened after the blast",
	weaknessDuration = "Weakness duration increase",
	partialRefill = "Kills caused by the spell partially refill its energy",
	multiPulse = "Fires several global damage pulses before disappearing",
	chainRange = "Chain range increase",
	jumps = "Jump count increase",
	ramp = "Each jump deals more damage than the previous one",
	bounce = "Can jump back to previously hit enemies",
	chainSpeed = "Chain speed increase",
	finalBolt = "Final target is struck by an additional lightning bolt",
	splitChain = "Splits into two chains after the first hit",
	stun = "Stun duration increase",
	electrifiedZone = "Leaves an electrified area after impact",
	zoneDamage = "Lingering area damage increase",
	restun = "Enemies in the area can be stunned again",
	secondStrike = "Strikes the same area a second time",
	zoneDurationLightning = "Electrified area duration increase",
	secondDamage = "Second strike damage increase",
	miniStrikes = "Causes several smaller strikes around the impact",
	dashDamage = "Dash damage increase",
	dashDistance = "Dash distance increase",
	trailStun = "Dash trail stuns enemies",
	dashSpeed = "Dash speed increase",
	explosion = "Creates an electric explosion at the end of the dash",
	explosionDamage = "Explosion damage increase",
	explosionRange = "Explosion range increase",
	staticField = "Explosion leaves a short-lasting static field",
	staticDamage = "Static field damage increase",
	fieldDuration = "Static field duration increase",
	charges2 = "Can store 2 charges",
	pulseDamage = "Pulse damage increase",
	pulseRange = "Pulse range increase",
	shieldStrength = "Shield strength increase",
	extraPulse = "Releases an additional damage pulse",
	shieldDuration = "Shield duration increase",
	pulseFrequency = "Pulse frequency increase",
	slow = "Slow strength increase",
	allyAbsorb = "Shield absorbs part of damage dealt to nearby allies",
	shatter = "Shatters on expiry and deals heavy AoE damage",
	orbitRadius = "Orbit radius increase",
	rockCount = "Rock count increase",
	rotationSpeed = "Rotation speed increase",
	rockSize = "Rock size increase",
	blockProjectiles = "Can block enemy projectiles",
	explodeDestroyed = "Destroyed rocks explode into fragments",
	outerRing = "Creates a second outer ring of smaller rocks",
	projectileSize = "Projectile size increase",
	pierce = "Pierces through one additional enemy",
	shatterImpact = "Shatters on impact and damages nearby enemies",
	fragmentRange = "Fragment range increase",
	distanceDamage = "Gains damage based on distance traveled",
	splitRocks = "Splits into several smaller rocks after the first impact",
	rollingSpeed = "Rolling speed increase",
	travelDistance = "Travel distance increase",
	grow = "Grows larger as it rolls",
	rubbleTrail = "Leaves a damaging rubble trail behind",
	shockwaveLarge = "Creates a shockwave when it hits a large enemy",
	stunDuration = "Stun duration increase",
	bubbleSize = "Bubble size increase",
	captureRange = "Capture range increase",
	captureMultiple = "Can capture multiple small enemies",
	bubbleSpeed = "Bubble movement speed increase",
	bubblePull = "Slowly pulls nearby enemies toward itself",
	captureDuration = "Capture duration increase",
	burstSlow = "Bursts at the end, dealing AoE damage and applying slow",
	burstDamage = "Burst damage increase",
	slowDuration = "Slow duration increase",
	splitBubbles = "Splits into several smaller bubbles after bursting",
	beamRange = "Beam range increase",
	beamWidth = "Beam width increase",
	push = "Pushes small enemies backward",
	beamDuration = "Beam duration increase",
	pressure = "Damage builds while staying on the same target",
	pressureDamage = "Pressure damage increase",
	beamPierce = "Pierces through enemies",
	sideStreams = "Splits into two additional side streams",
	lifesteal = "Lifesteal increase",
	multiHit = "Can hit multiple enemies",
	attackSpeed = "Attack speed increase",
	multiHeal = "Hitting multiple enemies increases healing received",
	pullLast = "Pulls the last hit enemy slightly toward the player",
	healing = "Healing increase",
	secondWhip = "Creates a second whip strike from the opposite side",
	spikeCount = "Spike count increase",
	spikeSize = "Spike size increase",
	slowStrength = "Slow strength increase",
	linger = "Spikes remain and damage enemies that touch them",
	spikeDuration = "Spike duration increase",
	shards = "Breaking spikes sends ice shards toward nearby enemies",
	shardDamage = "Ice shard damage increase",
	secondSpikeWave = "Erupts in a second wave around the first one",
	shardShatter = "Shatters on impact into smaller shards",
	burstShards = "Creates a burst of shards in all directions on impact",
	mistRange = "Mist range increase",
	mistDuration = "Mist duration increase",
	slowBuild = "Enemies inside gradually become more slowed",
	mistSize = "Mist size increase",
	freeze = "Enemies staying inside long enough become briefly frozen",
	freezeDuration = "Freeze duration increase",
	buildSpeed = "Slow buildup speed increase",
	frozenBonus = "Frozen enemies take increased damage inside the mist",
	freezeBuild = "Freeze buildup speed increase",
	secondArea = "Spreads into a second nearby area",
	fireRate = "Fire rate increase",
	secondPortal = "Adds a second portal",
	thirdPortal = "Adds a third portal",
	fourthPortal = "Adds a fourth portal",
	plusTwoPortals = "Adds two additional portals",
	targetRange = "Targeting range increase",
	autoTarget = "Automatically targets the nearest enemy",
	retargetKill = "After a kill immediately targets another enemy",
	retargetSpeed = "Retarget speed increase",
	track = "Can track moving enemies",
	tickRate = "Damage frequency increase",
	secondRay = "A second ray can strike another enemy at the same time",
	spearCount = "Spear count increase",
	spearSize = "Spear size increase",
	secondSpearWave = "Spears erupt in a second wave after a short delay",
	spearLinger = "Spears remain and damage enemies that touch them",
	spearDuration = "Spear duration increase",
	rings = "Spears erupt in several rings around the target area",
	sunDamage = "Sun damage increase",
	sunDuration = "Sun duration increase",
	outsideDamage = "Enemies outside shadows take increased damage",
	sunTickRate = "Damage tick rate increase",
	shadowsPartial = "Shadows only reduce part of the damage",
	sunWeakness = "Hit enemies become weakened and take increased damage",
	sunWeaknessDuration = "Weakness duration increase",
	shadowsIgnore = "Shadows no longer protect enemies",
}

local function plan(...)
	return { ... }
end

local BASE_SPECS = {
	{ id="Tornado", name="Tornado", element="Air", attackType="MovingZone", cost=260, description="Spawns a tornado near the player. It lifts light enemies, slows heavy enemies and moves slowly across the ground.", runtime={baseDamage=8,cooldown=5.2,baseRadius=7,duration=4.5,tickRate=0.35,moveSpeed=4.0,pullStrength=1.2,liftStrength=13}, upgrades=plan("unlock","damage","range","duration","pull","damage","range","cooldown","damage","lift","range","damage","duration","cooldown","follow","damage","range","damage","cooldown","secondTornado") },
	{ id="WindBlade", name="Wind Blade", element="Air", attackType="Nova", cost=230, description="A circular wind slash around the player that damages and knocks enemies back.", runtime={baseDamage=23,cooldown=2.8,baseRadius=9.5,knockbackForce=20}, upgrades=plan("unlock","damage","range","knockback","rangeBig","damage","range","cooldown","knockback","doubleHit","damage","range","width","cooldown","closeBonus","damage","range","knockback","cooldown","massiveOuter") },
	{ id="AirBullet", name="Air Bullet", element="Air", attackType="Projectile", cost=180, description="A wind projectile with a small AoE that can spread status effects from its target.", runtime={baseDamage=17,cooldown=1.1,projectileSpeed=100,range=68,impactRadius=3.5,pierce=0}, upgrades=plan("unlock","damage","aoe","projectileSpeed","statusSpread","damage","aoe","cooldown","damage","statusRange","projectileSpeed","damage","aoe","cooldown","statusMore","damage","aoe","damage","cooldown","split3") },
	{ id="AirPush", name="Air Push", element="Air", attackType="Nova", cost=220, description="A wide horizontal wind slash that pushes smaller enemies away.", runtime={baseDamage=18,cooldown=3.2,baseRadius=10,knockbackForce=26}, upgrades=plan("unlock","damage","range","knockback","wider","damage","range","cooldown","damage","mediumKnockback","range","damage","knockback","cooldown","secondWave","damage","range","damage","cooldown","multiDirection") },

	{ id="FireBall", name="Fire Ball", element="Fire", attackType="Projectile", cost=190, description="A fire orb with a small AoE that burns enemies on impact.", runtime={baseDamage=22,cooldown=1.35,projectileSpeed=88,range=68,impactRadius=5,pierce=0,projectileAsset="FireballVFX",impactAsset="FireballVFXImpact"}, upgrades=plan("unlock","damage","aoe","burnDamage","burnDuration","damage","aoe","cooldown","burnDamage","burningGround","damage","aoe","burnDamage","cooldown","burningBonus","damage","aoe","burnDamage","cooldown","secondExplosion") },
	{ id="Meteor", name="Meteor", element="Fire", attackType="Zone", cost=290, description="Calls a large flaming meteor onto enemies, dealing heavy AoE damage and burning the impact area.", runtime={baseDamage=36,cooldown=6.0,baseRadius=10,duration=2.2,tickRate=0.45,spawnAtEnemy=true,meteor=true}, upgrades=plan("unlock","damage","aoe","burnDamage","shockwave","damage","fallSpeed","cooldown","burnDuration","burningZone","damage","aoe","zoneDuration","cooldown","fragments","damage","fragmentCount","fragmentDamage","cooldown","miniMeteors") },
	{ id="Phoenix", name="Phoenix", element="Fire", attackType="Beam", cost=300, description="A phoenix flies over the player and sends a burning wave through enemies.", runtime={baseDamage=10,cooldown=5.4,duration=1.8,tickRate=0.20,range=62,width=7,phoenix=true}, upgrades=plan("unlock","damage","flightRange","burnDamage","fireTrail","damage","trailDuration","cooldown","moveSpeed","secondPass","damage","width","burnDuration","cooldown","feathers","damage","featherCount","trailDamage","cooldown","explodeReborn") },

	{ id="VoidClap", name="Void Clap", element="Void", attackType="Nova", cost=260, description="Two void forces collapse inward, pulling enemies toward the center.", runtime={baseDamage=25,cooldown=4.0,baseRadius=9.5,spawnAtEnemy=true,pullToCenter=true,pullStrength=1.5}, effects={pull={force=20}}, upgrades=plan("unlock","damage","pullRange","pull","root","damage","aoe","cooldown","pullSpeed","secondPull","damage","pullRange","rootDuration","cooldown","centerBonus","damage","pull","centerDamage","cooldown","singularity") },
	{ id="Doom", name="Doom", element="Void", attackType="Global", cost=340, description="Kills charge a Doom Eye. When charged, it damages all enemies and applies fear-like crowd control.", runtime={baseDamage=42,cooldown=14,energyRequired=16,fearDuration=0.8,global=true}, effects={vulnerability={pct=0.10,duration=1.8}}, upgrades=plan("unlock","globalDamage","energyGain","fearDuration","lowHpBonus","globalDamage","energyRequired","fearDuration","energyGain","weakness","globalDamage","weaknessDuration","energyGain","fearDuration","partialRefill","globalDamage","energyRequired","weakness","fearDuration","multiPulse") },

	{ id="LightningChain", name="Lightning Chain", element="Lightning", attackType="Chain", cost=250, description="Lightning jumps between nearby enemies.", runtime={baseDamage=19,cooldown=2.2,range=60,chainRange=16,jumpCount=4}, upgrades=plan("unlock","damage","chainRange","jumps","ramp","damage","chainRange","cooldown","jumps","bounce","damage","chainSpeed","damage","cooldown","finalBolt","damage","jumps","chainRange","cooldown","splitChain") },
	{ id="Lightning", name="Lightning", element="Lightning", attackType="Nova", cost=255, description="Calls down lightning with a small AoE and stun.", runtime={baseDamage=29,cooldown=3.8,baseRadius=7.5,spawnAtEnemy=true}, upgrades=plan("unlock","damage","aoe","stun","electrifiedZone","damage","range","cooldown","zoneDamage","restun","damage","aoe","stun","cooldown","secondStrike","damage","zoneDurationLightning","secondDamage","cooldown","miniStrikes") },
	{ id="ImpactDash", name="Impact Dash", element="Lightning", attackType="Dash", cost=285, description="A damaging dash that leaves an electric trail and later gains an end explosion.", runtime={baseDamage=20,cooldown=5.0,dashDistance=15,dashSpeed=58,trailRadius=4}, upgrades=plan("unlock","dashDamage","dashDistance","duration","trailStun","dashDamage","dashSpeed","cooldown","stun","explosion","explosionDamage","explosionRange","knockback","cooldown","staticField","staticDamage","dashDistance","fieldDuration","cooldown","charges2") },

	{ id="Pillar", name="Pillar", element="Earth", attackType="Pillar", cost=280, description="Raises an earth pillar that deals damage in pulses and grants a temporary shield.", runtime={baseDamage=14,cooldown=7.0,baseRadius=8,duration=6,tickRate=1.0,shieldStrength=20,shieldDuration=4}, upgrades=plan("unlock","pulseDamage","pulseRange","shieldStrength","extraPulse","pulseDamage","shieldDuration","cooldown","pulseFrequency","slow","pulseDamage","range","shieldStrength","cooldown","allyAbsorb","pulseDamage","pulseFrequency","shieldDuration","cooldown","shatter") },
	{ id="OrbitingRocks", name="Orbiting Rocks", element="Earth", attackType="Orbit", cost=245, description="Rocks orbit the player and damage enemies they touch.", runtime={baseDamage=13,hitCooldown=0.42,baseRadius=6,baseCount=2,orbitSpeed=2.5}, upgrades=plan("unlock","damage","orbitRadius","rockCount","knockback","damage","rotationSpeed","cooldown","rockSize","blockProjectiles","damage","orbitRadius","rockCount","cooldown","explodeDestroyed","fragmentDamage","rotationSpeed","rockSize","cooldown","outerRing") },
	{ id="RockThrow", name="Rock Throw", element="Earth", attackType="Projectile", cost=190, description="Throws a heavy rock at a nearby enemy.", runtime={baseDamage=25,cooldown=1.45,projectileSpeed=78,range=62,pierce=0,impactRadius=2.5}, upgrades=plan("unlock","damage","projectileSize","projectileSpeed","pierce","damage","knockback","cooldown","projectileSize","shatterImpact","damage","fragmentRange","fragmentCount","cooldown","distanceDamage","damage","projectileSpeed","fragmentDamage","cooldown","splitRocks") },
	{ id="RollingRock", name="Rolling Rock", element="Earth", attackType="Projectile", cost=260, description="Launches a large rock that rolls through enemies along the ground.", runtime={baseDamage=30,cooldown=4.2,projectileSpeed=35,range=70,pierce=4,impactRadius=4,groundProjectile=true}, upgrades=plan("unlock","damage","rockSize","rollingSpeed","knockback","damage","travelDistance","cooldown","knockback","grow","damage","rollingSpeed","travelDistance","cooldown","rubbleTrail","damage","rockSize","trailDamage","cooldown","shockwaveLarge") },

	{ id="Bubble", name="Bubble", element="Water", attackType="Zone", cost=250, description="Creates a bubble that traps and stuns enemies.", runtime={baseDamage=4,cooldown=5.0,baseRadius=6.5,duration=3.2,tickRate=0.5,spawnAtEnemy=true,capture=true}, effects={slow={pct=0.45,duration=1.2},stun={duration=0.18}}, upgrades=plan("unlock","stunDuration","bubbleSize","captureRange","captureMultiple","stunDuration","bubbleSpeed","cooldown","bubbleSize","bubblePull","captureDuration","captureRange","bubbleSpeed","cooldown","burstSlow","burstDamage","bubbleSize","slowDuration","cooldown","splitBubbles") },
	{ id="WaterJet", name="Water Jet", element="Water", attackType="Beam", cost=255, description="A sustained water jet that damages and pushes smaller enemies.", runtime={baseDamage=8.5,cooldown=4.6,duration=1.8,tickRate=0.18,range=58,width=4.5,beamPush=12}, upgrades=plan("unlock","damage","beamRange","beamWidth","push","damage","beamDuration","cooldown","knockback","pressure","damage","beamRange","pressureDamage","cooldown","beamPierce","damage","beamWidth","beamDuration","cooldown","sideStreams") },
	{ id="WaterWhip", name="Water Whip", element="Water", attackType="Beam", cost=270, description="A short water whip that steals health from enemies.", runtime={baseDamage=12,cooldown=2.8,duration=0.55,tickRate=0.18,range=25,width=5,lifesteal=0.08}, upgrades=plan("unlock","damage","range","lifesteal","multiHit","damage","attackSpeed","cooldown","lifesteal","multiHeal","damage","range","lifesteal","cooldown","pullLast","damage","attackSpeed","healing","cooldown","secondWhip") },

	{ id="IceSpikes", name="Ice Spikes", element="Ice", attackType="Nova", cost=250, description="Ice spikes erupt from the ground around enemies.", runtime={baseDamage=24,cooldown=3.8,baseRadius=8.5,spawnAtEnemy=true}, upgrades=plan("unlock","damage","aoe","spikeCount","slow","damage","spikeSize","cooldown","slowStrength","linger","damage","aoe","spikeDuration","cooldown","shards","shardDamage","spikeCount","slowDuration","cooldown","secondSpikeWave") },
	{ id="IceShard", name="Ice Shard", element="Ice", attackType="Projectile", cost=190, description="Fires an ice projectile that slows enemies.", runtime={baseDamage=20,cooldown=1.2,projectileSpeed=96,range=68,pierce=0}, upgrades=plan("unlock","damage","projectileSpeed","projectileSize","slow","damage","slowStrength","cooldown","projectileSpeed","pierce","damage","projectileSize","slowDuration","cooldown","shardShatter","fragmentDamage","fragmentCount","damage","cooldown","burstShards") },
	{ id="IceMist", name="Ice Mist", element="Ice", attackType="Zone", cost=260, description="Creates a freezing mist that progressively slows enemies and can freeze them.", runtime={baseDamage=3,cooldown=5.2,baseRadius=8,duration=5,tickRate=0.45,spawnAtEnemy=false,mist=true}, effects={slow={pct=0.38,duration=1.3}}, upgrades=plan("unlock","slowStrength","mistRange","mistDuration","slowBuild","slowStrength","mistSize","cooldown","mistDuration","freeze","freezeDuration","mistRange","buildSpeed","cooldown","frozenBonus","mistDuration","slowStrength","freezeBuild","cooldown","secondArea") },

	{ id="GatesOfBabilon", name="Gates of Babilon", element="Light", attackType="Gates", cost=320, description="Portals appear above the player and fire homing light weapons at nearby enemies.", runtime={baseDamage=20,cooldown=2.6,projectileSpeed=82,range=72,baseCount=1,portalRadius=5,portalHeight=5,castAsset="GilgameshMain",projectileAsset="GilProjectile",impactAsset="GilHitVFX",homing=true,homingTurnRate=9}, upgrades=plan("unlock","damage","projectileSpeed","fireRate","secondPortal","damage","range","cooldown","fireRate","thirdPortal","damage","projectileSpeed","fireRate","cooldown","fourthPortal","damage","range","fireRate","cooldown","plusTwoPortals") },
	{ id="SunRay", name="Sun Ray", element="Light", attackType="Beam", cost=285, description="A beam of light that automatically targets nearby enemies.", runtime={baseDamage=9.5,cooldown=4.5,duration=1.6,tickRate=0.17,range=62,width=3.8,trackingBeam=true}, upgrades=plan("unlock","damage","targetRange","beamDuration","autoTarget","damage","targetRange","cooldown","beamWidth","retargetKill","damage","beamDuration","retargetSpeed","cooldown","track","damage","targetRange","tickRate","cooldown","secondRay") },
	{ id="LightSpears", name="Light Spears", element="Light", attackType="Nova", cost=270, description="Light spears erupt from the ground around the target area.", runtime={baseDamage=26,cooldown=3.9,baseRadius=9,spawnAtEnemy=true}, effects={vulnerability={pct=0.08,duration=1.1},stun={duration=0.12}}, upgrades=plan("unlock","damage","aoe","spearCount","stun","damage","spearSize","cooldown","spearCount","secondSpearWave","damage","aoe","spearCount","cooldown","spearLinger","damage","spearSize","spearDuration","cooldown","rings") },
	{ id="SunPenalty", name="Sun Penalty", element="Light", attackType="Global", cost=340, description="Periodically scorches enemies and players exposed to direct sunlight. Shadows provide protection until later upgrades.", runtime={baseDamage=16,cooldown=10,duration=3,tickRate=0.75,sunPenalty=true}, effects={vulnerability={pct=0.08,duration=1.4}}, upgrades=plan("unlock","sunDamage","sunDuration","cooldown","outsideDamage","sunDamage","sunDuration","cooldown","sunTickRate","shadowsPartial","sunDamage","sunTickRate","sunDuration","cooldown","sunWeakness","sunDamage","sunWeaknessDuration","cooldown","sunDuration","shadowsIgnore") },
}

local COMBO_SPECS = {
	{ id="InfernoTornado", name="Inferno Tornado", primary="Air", secondary="Fire", attackType="MovingZone", ingredients={"Tornado","FireBall"}, description="A burning tornado pulls enemies in, ignites them and periodically launches fireballs around itself.", runtime={baseDamage=13,cooldown=5.0,baseRadius=8,duration=5,tickRate=0.32,moveSpeed=4.2,pullStrength=1.5,liftStrength=15,fireballBursts=true} },
	{ id="StormBullet", name="Storm Bullet", primary="Air", secondary="Lightning", attackType="Projectile", ingredients={"LightningChain","AirBullet"}, description="Air Bullet releases a Lightning Chain on impact while retaining status spreading.", runtime={baseDamage=24,cooldown=1.15,projectileSpeed=112,range=76,impactRadius=4,chainOnHit=true,jumpCount=5,chainRange=18} },
	{ id="MagmaBoulder", name="Magma Boulder", primary="Earth", secondary="Fire", attackType="Projectile", ingredients={"Meteor","RollingRock"}, description="A superheated boulder crashes down, rolls onward, pushes enemies and leaves a burning trail.", runtime={baseDamage=43,cooldown=5.4,projectileSpeed=38,range=78,pierce=6,impactRadius=5,groundProjectile=true,burningTrail=true} },
	{ id="FrozenArsenal", name="Frozen Arsenal", primary="Light", secondary="Ice", attackType="Gates", ingredients={"IceShard","GatesOfBabilon"}, description="The portals fire ice projectiles that slow enemies and shatter into smaller shards.", runtime={baseDamage=25,cooldown=2.3,projectileSpeed=90,range=76,baseCount=4,portalRadius=5,portalHeight=5,castAsset="GilgameshMain",projectileAsset="GilProjectile",impactAsset="GilHitVFX",homing=true,homingTurnRate=9,fragmentCount=3} },
	{ id="FrozenLight", name="Frozen Light", primary="Light", secondary="Ice", attackType="Beam", ingredients={"IceMist","SunRay"}, description="Sun Ray rapidly deepens the slow on enemies inside Ice Mist and can freeze them.", runtime={baseDamage=12,cooldown=4.2,duration=2,tickRate=0.15,range=68,width=4.5,trackingBeam=true,freezeBuild=true} },
	{ id="BlackStar", name="Black Star", primary="Void", secondary="Fire", attackType="Zone", ingredients={"VoidClap","Meteor"}, description="Void Clap gathers enemies into one point before a meteor crashes into the center.", runtime={baseDamage=48,cooldown=6.0,baseRadius=11,duration=2.4,tickRate=0.4,spawnAtEnemy=true,pullStrength=1.8,meteor=true} },
	{ id="ThunderBubble", name="Thunder Bubble", primary="Water", secondary="Lightning", attackType="Zone", ingredients={"Bubble","Lightning"}, description="A trapping bubble is repeatedly struck by lightning that chains through captured enemies.", runtime={baseDamage=12,cooldown=5,baseRadius=7,duration=4,tickRate=0.42,spawnAtEnemy=true,capture=true,chainOnHit=true,jumpCount=4} },
	{ id="GlacialJet", name="Glacial Jet", primary="Water", secondary="Ice", attackType="Beam", ingredients={"WaterJet","IceSpikes"}, description="Water Jet freezes the ground along its path and Ice Spikes erupt from the frozen strip.", runtime={baseDamage=11,cooldown=4.5,duration=2,tickRate=0.17,range=62,width=5.5,iceTrail=true} },
	{ id="ElectricWhip", name="Electric Whip", primary="Water", secondary="Lightning", attackType="Beam", ingredients={"WaterWhip","LightningChain"}, description="Whip hits release Lightning Chain and part of the chain damage heals the player.", runtime={baseDamage=15,cooldown=2.5,duration=0.7,tickRate=0.16,range=28,width=6,lifesteal=0.12,chainOnHit=true,jumpCount=4} },
	{ id="SacredPillar", name="Sacred Pillar", primary="Earth", secondary="Light", attackType="Pillar", ingredients={"Pillar","LightSpears"}, description="Light Spears repeatedly erupt around the pillar while nearby players receive a shield.", runtime={baseDamage=19,cooldown=6.5,baseRadius=9,duration=7,tickRate=0.8,shieldStrength=32,shieldDuration=5,spearPulse=true} },
	{ id="FlameWave", name="Flame Wave", primary="Air", secondary="Fire", attackType="Nova", ingredients={"AirPush","FireBall"}, description="Air Push becomes a broad wave of fire that knocks enemies away and burns them.", runtime={baseDamage=31,cooldown=3.2,baseRadius=13,knockbackForce=30} },
	{ id="FrostDash", name="Frost Dash", primary="Lightning", secondary="Ice", attackType="Dash", ingredients={"ImpactDash","IceMist"}, description="The dash leaves Ice Mist behind and its end explosion can freeze enemies.", runtime={baseDamage=28,cooldown=4.5,dashDistance=19,dashSpeed=65,trailRadius=5,iceTrail=true,endExplosion=true} },
	{ id="ThunderStones", name="Thunder Stones", primary="Earth", secondary="Lightning", attackType="Orbit", ingredients={"OrbitingRocks","Lightning"}, description="Orbiting rocks are electrically charged and release small stunning lightning bursts on contact.", runtime={baseDamage=18,hitCooldown=0.36,baseRadius=7,baseCount=4,orbitSpeed=3,lightningBurst=true} },
	{ id="SolarPhoenix", name="Solar Phoenix", primary="Fire", secondary="Light", attackType="Beam", ingredients={"Phoenix","SunPenalty"}, description="During Sun Penalty the Phoenix repeatedly crosses the battlefield and creates zones that amplify solar damage.", runtime={baseDamage=15,cooldown=5,duration=2.2,tickRate=0.16,range=72,width=9,phoenix=true,solarZones=true} },
}

local function blend(a, b, alpha)
	return Color3.new(a.R + ((b.R - a.R) * alpha), a.G + ((b.G - a.G) * alpha), a.B + ((b.B - a.B) * alpha))
end

local function makeCategory(def)
	return string.format("%s / %s / %s", def.spellType or "Magic", def.element, def.attackType)
end

local function makePresentation(def)
	local name = def.name or def.id
	local primary = SpellDefs.ELEMENTS[def.element] and SpellDefs.ELEMENTS[def.element].color or SpellDefs.COLOR_BASE
	local secondary = def.secondaryElement and SpellDefs.ELEMENTS[def.secondaryElement] and SpellDefs.ELEMENTS[def.secondaryElement].color or primary
	return {
		iconGlyph = string.upper(string.sub(def.id, 1, 2)),
		artMotif = name .. " signature",
		silhouette = name .. " silhouette",
		motion = ATTACK_NOTES[def.attackType] or "Distinct spell motion.",
		loreDescription = def.description,
		gameplayDescription = def.description,
		castVfx = def.runtime and def.runtime.castAsset or (name .. " cast"),
		travelVfx = def.runtime and def.runtime.projectileAsset or (name .. " travel"),
		impactVfx = def.runtime and def.runtime.impactAsset or (name .. " impact"),
		lingeringVfx = def.runtime and def.runtime.zoneAsset or (name .. " linger"),
		frameStyle = def.isCombo and "fusion frame" or string.lower(def.element) .. " frame",
		codexCategory = def.isCombo and "Fusion Spell" or makeCategory(def),
		witchbookAccent = def.element,
		visualDirection = ATTACK_NOTES[def.attackType] or "",
		visualProfile = { silhouette=name .. " silhouette", motion=ATTACK_NOTES[def.attackType] or "", accentCount=def.isCombo and 4 or 2, combo=def.isCombo == true },
		primaryColor = primary,
		secondaryColor = secondary,
	}
end

local function addProduct(def, variantId, variant)
	local productId = string.format("%s_%s", def.id, variantId)
	local cost = math.floor((def.shopCost or 200) * (variant.costMultiplier or 1))
	SpellDefs.SHOP_PRODUCTS[productId] = {
		id=productId, familyId=def.id, name=def.name,
		displayName=string.format("%s (%s)", def.name, variant.shortLabel),
		element=def.element, attackType=def.attackType, spellType=def.spellType,
		category=def.category, description=def.description, baseQuality=variantId,
		cardQuality=variant.cardQuality, baseMultiplier=variant.baseMultiplier, basePower=variant.basePower,
		costCoins=cost, costSouls=cost, color=def.color,
		iconGlyph=def.iconGlyph, artMotif=def.artMotif, loreDescription=def.loreDescription,
		gameplayDescription=def.gameplayDescription, visualDirection=def.visualDirection,
		frameStyle=def.frameStyle, codexCategory=def.codexCategory, witchbookAccent=def.witchbookAccent,
		visualProfile=copyTable(def.visualProfile), presentation=copyTable(def.presentation),
	}
	table.insert(SpellDefs.SHOP_ORDER, productId)
end

local function registerSpell(def)
	def.spellType = "Magic"
	def.maxLevel = def.maxLevel or 20
	def.color = SpellDefs.ELEMENTS[def.element] and SpellDefs.ELEMENTS[def.element].color or SpellDefs.COLOR_BASE
	local secondary = def.secondaryElement and SpellDefs.ELEMENTS[def.secondaryElement] and SpellDefs.ELEMENTS[def.secondaryElement].color or def.color
	def.displayColor = def.secondaryElement and blend(def.color, secondary, 0.45) or def.color
	def.category = makeCategory(def)
	def.presentation = makePresentation(def)
	def.iconGlyph = def.presentation.iconGlyph
	def.artMotif = def.presentation.artMotif
	def.loreDescription = def.presentation.loreDescription
	def.gameplayDescription = def.presentation.gameplayDescription
	def.visualDirection = def.presentation.visualDirection
	def.frameStyle = def.presentation.frameStyle
	def.codexCategory = def.presentation.codexCategory
	def.witchbookAccent = def.presentation.witchbookAccent
	def.visualProfile = copyTable(def.presentation.visualProfile)
	SpellDefs.SPELLS[def.id] = def
	table.insert(SpellDefs.SPELL_ORDER, def.id)
	if def.shopAvailable ~= false then
		for _, variantId in ipairs(BASE_VARIANT_ORDER) do addProduct(def, variantId, SpellDefs.BASE_VARIANT_QUALITIES[variantId]) end
	end
end

for _, spec in ipairs(BASE_SPECS) do
	registerSpell({ id=spec.id, name=spec.name, element=spec.element, attackType=spec.attackType, shopCost=spec.cost, description=spec.description, runtime=spec.runtime, effects=spec.effects, upgradePlan=spec.upgrades, base=true })
end

local function makeSynergyKey(ingredients)
	local sorted = {}
	for _, ingredient in ipairs(ingredients or {}) do table.insert(sorted, normalizeSpellId(ingredient)) end
	table.sort(sorted)
	return table.concat(sorted, "|")
end

for _, spec in ipairs(COMBO_SPECS) do
	registerSpell({ id=spec.id, name=spec.name, element=spec.primary, secondaryElement=spec.secondary, attackType=spec.attackType, description=spec.description, runtime=spec.runtime, effects=spec.effects, base=false, isCombo=true, maxLevel=1, shopAvailable=false, fusionIngredients=copyTable(spec.ingredients) })
	local required = {}
	for _, id in ipairs(spec.ingredients) do required[id] = "MAX" end
	local combo = { id=spec.id, Id=spec.id, resultId=spec.id, ResultSpell=spec.id, resultSpell=spec.id, ingredients=copyTable(spec.ingredients), RequiredSpells=required, RequiredLevel="MAX", ReplaceBaseSpells=true, HiddenUntilDiscovered=false, key=makeSynergyKey(spec.ingredients) }
	table.insert(SpellDefs.SYNERGIES, combo)
	table.insert(SpellDefs.COMBINATIONS, combo)
end

local SYNERGY_LOOKUP, SYNERGY_BY_INGREDIENT, COMBINATION_BY_ID, COMBINATION_BY_RESULT = {}, {}, {}, {}
for _, combo in ipairs(SpellDefs.COMBINATIONS) do
	SYNERGY_LOOKUP[combo.key] = combo
	COMBINATION_BY_ID[combo.id] = combo
	COMBINATION_BY_RESULT[combo.resultId] = combo
	for _, ingredient in ipairs(combo.ingredients) do
		SYNERGY_BY_INGREDIENT[ingredient] = SYNERGY_BY_INGREDIENT[ingredient] or {}
		table.insert(SYNERGY_BY_INGREDIENT[ingredient], combo)
	end
end

local function feature(runtime, code)
	runtime.features = runtime.features or {}
	runtime.features[code] = true
end

local function scaleEffect(runtime, kind, field, multiplier)
	local effect = runtime.effects and runtime.effects[kind]
	if effect and tonumber(effect[field]) then effect[field] *= multiplier end
end

local function applyLevelUpgrade(runtime, code)
	if code == "unlock" then return end
	if code == "damage" or code == "globalDamage" or code == "dashDamage" or code == "pulseDamage" or code == "sunDamage" then runtime.damage *= 1.12
	elseif code == "range" or code == "beamRange" or code == "targetRange" or code == "flightRange" or code == "travelDistance" or code == "pullRange" or code == "captureRange" or code == "mistRange" or code == "fragmentRange" then runtime.range = (runtime.range or 0) * 1.10; runtime.radius = (runtime.radius or 0) * 1.10
	elseif code == "aoe" or code == "pulseRange" or code == "bubbleSize" or code == "mistSize" or code == "explosionRange" then runtime.radius = (runtime.radius or runtime.impactRadius or 0) * 1.10; runtime.impactRadius = (runtime.impactRadius or 0) * 1.10
	elseif code == "duration" or code == "beamDuration" or code == "mistDuration" or code == "sunDuration" or code == "zoneDuration" or code == "zoneDurationLightning" or code == "fieldDuration" or code == "spikeDuration" or code == "spearDuration" or code == "trailDuration" or code == "shieldDuration" or code == "captureDuration" then runtime.duration = (runtime.duration or 1) * 1.10; runtime.shieldDuration = (runtime.shieldDuration or 0) * 1.10
	elseif code == "cooldown" then runtime.cooldown = math.max(0.25, (runtime.cooldown or 1) * 0.90)
	elseif code == "projectileSpeed" or code == "rollingSpeed" or code == "dashSpeed" or code == "bubbleSpeed" or code == "moveSpeed" or code == "chainSpeed" or code == "rotationSpeed" or code == "fallSpeed" or code == "attackSpeed" then runtime.projectileSpeed = (runtime.projectileSpeed or runtime.moveSpeed or 1) * 1.10; runtime.moveSpeed = (runtime.moveSpeed or 1) * 1.10; runtime.orbitSpeed = (runtime.orbitSpeed or 1) * 1.10; runtime.cooldown = math.max(0.25, (runtime.cooldown or 1) * 0.96)
	elseif code == "knockback" or code == "mediumKnockback" or code == "push" then runtime.knockbackForce = (runtime.knockbackForce or 18) * 1.18
	elseif code == "pull" then runtime.pullStrength = (runtime.pullStrength or 1) * 1.18
	elseif code == "burnDamage" then scaleEffect(runtime,"dot","dps",1.18)
	elseif code == "burnDuration" or code == "slowDuration" or code == "stun" or code == "stunDuration" or code == "fearDuration" or code == "rootDuration" or code == "freezeDuration" then scaleEffect(runtime,"dot","duration",1.15); scaleEffect(runtime,"slow","duration",1.15); scaleEffect(runtime,"stun","duration",1.15); runtime.fearDuration = (runtime.fearDuration or 0.8) * 1.15
	elseif code == "slow" or code == "slowStrength" then scaleEffect(runtime,"slow","pct",1.14)
	elseif code == "lifesteal" or code == "healing" then runtime.lifesteal = math.min(0.45, (runtime.lifesteal or 0.05) + 0.025)
	elseif code == "fireRate" or code == "pulseFrequency" or code == "tickRate" or code == "sunTickRate" then runtime.cooldown = math.max(0.25,(runtime.cooldown or 1)*0.92); runtime.tickRate = math.max(0.08,(runtime.tickRate or 0.4)*0.90)
	elseif code == "rockCount" or code == "spikeCount" or code == "spearCount" or code == "fragmentCount" or code == "featherCount" or code == "jumps" then runtime.count = (runtime.count or runtime.baseCount or 1) + 1; runtime.baseCount = runtime.count; runtime.jumpCount = (runtime.jumpCount or 3) + 1
	elseif code == "secondPortal" then runtime.baseCount = math.max(runtime.baseCount or 1,2)
	elseif code == "thirdPortal" then runtime.baseCount = math.max(runtime.baseCount or 1,3)
	elseif code == "fourthPortal" then runtime.baseCount = math.max(runtime.baseCount or 1,4)
	elseif code == "plusTwoPortals" then runtime.baseCount = (runtime.baseCount or 4) + 2
	elseif code == "orbitRadius" then runtime.radius = (runtime.radius or runtime.baseRadius or 5) * 1.12
	elseif code == "beamWidth" or code == "width" or code == "wider" or code == "spikeSize" or code == "spearSize" or code == "rockSize" or code == "projectileSize" then runtime.width = (runtime.width or 1) * 1.12; runtime.visualScale = (runtime.visualScale or 1) * 1.12
	elseif code == "pierce" or code == "beamPierce" then runtime.pierce = (runtime.pierce or 0) + 1
	elseif code == "energyGain" then runtime.energyGainMultiplier = (runtime.energyGainMultiplier or 1) + 0.15
	elseif code == "energyRequired" then runtime.energyRequired = math.max(3, math.floor((runtime.energyRequired or 16) * 0.88 + 0.5))
	elseif code == "shieldStrength" then runtime.shieldStrength = (runtime.shieldStrength or 20) * 1.18
	elseif code == "dashDistance" then runtime.dashDistance = (runtime.dashDistance or 15) * 1.12
	end
	feature(runtime, code)
end

function SpellDefs.Get(id)
	local spellId = normalizeSpellId(id)
	return SpellDefs.SPELLS[spellId] or SpellDefs.SHOP_PRODUCTS[normalizeProductId(id)]
end
function SpellDefs.GetSpell(id) return SpellDefs.SPELLS[normalizeSpellId(id)] end
function SpellDefs.GetProduct(id) return SpellDefs.SHOP_PRODUCTS[normalizeProductId(id)] end
function SpellDefs.IsValid(id) return SpellDefs.Get(id) ~= nil end
function SpellDefs.GetShopList() return copyTable(SpellDefs.SHOP_ORDER) end
function SpellDefs.GetSpellIds() return copyTable(SpellDefs.SPELL_ORDER) end
function SpellDefs.GetElementColor(element) return SpellDefs.ELEMENTS[element] and SpellDefs.ELEMENTS[element].color or SpellDefs.COLOR_BASE end
function SpellDefs.GetSpellColor(spellIdOrDef)
	local def = typeof(spellIdOrDef)=="string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	return (def and def.displayColor) or (def and def.color) or SpellDefs.COLOR_BASE
end
function SpellDefs.GetPresentation(spellIdOrDef)
	local def = typeof(spellIdOrDef)=="string" and (SpellDefs.GetSpell(spellIdOrDef) or SpellDefs.GetProduct(spellIdOrDef)) or spellIdOrDef
	return def and copyTable(def.presentation) or {}
end
function SpellDefs.GetVisualProfile(spellIdOrDef)
	local p = SpellDefs.GetPresentation(spellIdOrDef)
	return copyTable(p.visualProfile or {})
end
function SpellDefs.GetSpellArtData(spellIdOrDef)
	local def = typeof(spellIdOrDef)=="string" and (SpellDefs.GetSpell(spellIdOrDef) or SpellDefs.GetProduct(spellIdOrDef)) or spellIdOrDef
	if not def then return {} end
	return { iconGlyph=def.iconGlyph, artMotif=def.artMotif, loreDescription=def.loreDescription, gameplayDescription=def.gameplayDescription, visualDirection=def.visualDirection, frameStyle=def.frameStyle, codexCategory=def.codexCategory, witchbookAccent=def.witchbookAccent, color=SpellDefs.GetSpellColor(def) }
end
function SpellDefs.DescribeVisualDirection(spellIdOrDef)
	local def = typeof(spellIdOrDef)=="string" and (SpellDefs.GetSpell(spellIdOrDef) or SpellDefs.GetProduct(spellIdOrDef)) or spellIdOrDef
	return def and def.visualDirection or ""
end
function SpellDefs.GetTypeLimit(spellType) return SpellDefs.MAX_MAGIC_RUN_SPELLS end

function SpellDefs.ResolveUnlockedProducts(unlockedIds)
	local strongest = {}
	for _, id in ipairs(unlockedIds or {}) do
		local product = SpellDefs.GetProduct(id) or (typeof(id)=="string" and SpellDefs.GetProduct(normalizeSpellId(id).."_Standard"))
		if product then
			local previous = strongest[product.familyId]
			if not previous or (product.baseMultiplier or 1) > (previous.baseMultiplier or 1) then strongest[product.familyId] = product end
		end
	end
	return strongest
end

function SpellDefs.GetSynergyResult(a,b)
	local combo = SYNERGY_LOOKUP[makeSynergyKey({normalizeSpellId(a),normalizeSpellId(b)})]
	return combo and combo.resultId or nil
end
function SpellDefs.GetSynergiesFor(spellId) return copyTable(SYNERGY_BY_INGREDIENT[normalizeSpellId(spellId)] or {}) end
function SpellDefs.IsIngredientBlockedByCombo(spellId, activeSet)
	for _, combo in ipairs(SYNERGY_BY_INGREDIENT[normalizeSpellId(spellId)] or {}) do if activeSet[combo.resultId] then return true end end
	return false
end
function SpellDefs.GetSynergyHint(spellId, activeSet)
	spellId = normalizeSpellId(spellId)
	for _, combo in ipairs(SYNERGY_BY_INGREDIENT[spellId] or {}) do
		local other = combo.ingredients[1] == spellId and combo.ingredients[2] or combo.ingredients[1]
		if activeSet[other] then return combo.resultId, other end
	end
	return nil,nil
end

function SpellDefs.DescribeShopProduct(productIdOrDef)
	local p = typeof(productIdOrDef)=="string" and SpellDefs.GetProduct(productIdOrDef) or productIdOrDef
	if not p then return "" end
	local v = SpellDefs.BASE_VARIANT_QUALITIES[p.baseQuality]
	return string.format("%s\n%s\n%s", p.category, v and v.label or "Base Variant", p.gameplayDescription or p.description or "")
end
function SpellDefs.DescribeNewOffer(productIdOrDef)
	local p = typeof(productIdOrDef)=="string" and SpellDefs.GetProduct(productIdOrDef) or productIdOrDef
	if not p then return "" end
	local v = SpellDefs.BASE_VARIANT_QUALITIES[p.baseQuality]
	return string.format("%s\n%s\nUnlocks %s.", p.category, v and v.label or "Base Variant", p.name)
end
function SpellDefs.DescribeUpgradeOffer(spellIdOrDef, qualityId, currentLevel)
	local def = typeof(spellIdOrDef)=="string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	if not def then return "" end
	local nextLevel = math.clamp((currentLevel or 0)+1,1,def.maxLevel or 20)
	local code = def.upgradePlan and def.upgradePlan[nextLevel]
	local text = code and UPGRADE_LABELS[code] or "Improves the spell."
	local quality = SpellDefs.UPGRADE_QUALITIES[qualityId] or SpellDefs.UPGRADE_QUALITIES.Common
	return string.format("%s\n%s (+%.2f power)\nLv.%d: %s", def.category, quality.bonusText, quality.power, nextLevel, text)
end

function SpellDefs.ComputeRuntimeStats(spellIdOrDef, state)
	local def = typeof(spellIdOrDef)=="string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	if not def then return nil end
	local runtime = copyTable(def.runtime or {})
	local level = math.clamp(math.floor(tonumber(state and state.level) or 1),1,def.maxLevel or 20)
	local baseMultiplier = math.max(0.5, tonumber(state and state.baseMultiplier) or 1)
	local basePower = math.max(0, tonumber(state and state.basePower) or 0)
	local upgradePower = math.max(0, tonumber(state and state.upgradePower) or 0)

	runtime.damage = (runtime.baseDamage or 10) * baseMultiplier
	runtime.radius = runtime.baseRadius or runtime.radius or 0
	runtime.count = runtime.baseCount or runtime.count or 1
	runtime.effects = copyTable(def.effects or DEFAULT_EFFECTS[def.element] or {})
	for upgradeLevel = 2, level do
		local code = def.upgradePlan and def.upgradePlan[upgradeLevel]
		if code then applyLevelUpgrade(runtime, code) end
	end
	local qualityFactor = 1 + (basePower * 0.07) + (upgradePower * 0.045)
	runtime.damage *= qualityFactor
	runtime.radius *= 1 + (basePower * 0.02) + (upgradePower * 0.01)
	if runtime.range then runtime.range *= 1 + (basePower * 0.015) + (upgradePower * 0.008) end
	if runtime.impactRadius then runtime.impactRadius *= 1 + (basePower * 0.02) + (upgradePower * 0.01) end

	runtime.level=level; runtime.baseMultiplier=baseMultiplier; runtime.basePower=basePower; runtime.upgradePower=upgradePower
	runtime.spellId=def.id; runtime.spellName=def.name; runtime.element=def.element; runtime.secondaryElement=def.secondaryElement
	runtime.attackType=def.attackType; runtime.archetype=def.attackType; runtime.spellType=def.spellType; runtime.isCombo=def.isCombo==true
	runtime.visualColor=SpellDefs.GetSpellColor(def)
	runtime.visualSecondaryColor=def.secondaryElement and SpellDefs.GetElementColor(def.secondaryElement) or blend(runtime.visualColor, Color3.new(1,1,1),0.28)
	runtime.iconGlyph=def.iconGlyph; runtime.artMotif=def.artMotif; runtime.visualDirection=def.visualDirection; runtime.visualProfile=copyTable(def.visualProfile); runtime.presentation=copyTable(def.presentation)
	runtime.effectPower=1 + ((level-1)*0.035) + (upgradePower*0.035) + (basePower*0.02)
	runtime.eliteDamageMultiplier=1; runtime.bossDamageMultiplier=1
	return runtime
end

function SpellDefs.SortSpellIds(ids)
	table.sort(ids,function(a,b)
		local da,db=SpellDefs.GetSpell(a),SpellDefs.GetSpell(b)
		if not da or not db then return tostring(a)<tostring(b) end
		local oa=SpellDefs.ELEMENTS[da.element] and SpellDefs.ELEMENTS[da.element].order or 99
		local ob=SpellDefs.ELEMENTS[db.element] and SpellDefs.ELEMENTS[db.element].order or 99
		if oa~=ob then return oa<ob end
		return tostring(da.name)<tostring(db.name)
	end)
	return ids
end
function SpellDefs.GetQualityOrder() return copyTable(QUALITY_ORDER) end
function SpellDefs.GetLoadoutLimit() return SpellDefs.SPELL_LOADOUT_MAX_SLOTS end
function SpellDefs.ProductToSpellId(productId)
	local p=SpellDefs.GetProduct(productId)
	return p and p.familyId or normalizeSpellId(productId)
end
function SpellDefs.NormalizeLoadoutProductId(id)
	if typeof(id)=="table" then id=id.id or id.productId or id.ProductId or id.spellId or id.SpellId end
	if typeof(id)~="string" or id=="" then return nil end
	local normalized=normalizeProductId(id)
	if SpellDefs.GetProduct(normalized) then return normalized end
	local standard=normalizeSpellId(normalized).."_Standard"
	return SpellDefs.GetProduct(standard) and standard or nil
end
local function unlockedContains(unlockedMap, productId)
	if typeof(unlockedMap)~="table" then return false end
	if unlockedMap[productId]==true then return true end
	local p=SpellDefs.GetProduct(productId)
	return p and unlockedMap[p.familyId]==true or false
end
function SpellDefs.ValidateSpellLoadout(rawLoadout, unlockedMap)
	local out,seen={},{}
	if typeof(rawLoadout)~="table" then return out end
	for _,raw in ipairs(rawLoadout) do
		local productId=SpellDefs.NormalizeLoadoutProductId(raw)
		local p=productId and SpellDefs.GetProduct(productId)
		if p and unlockedContains(unlockedMap,productId) and not seen[p.familyId] then
			seen[p.familyId]=true; table.insert(out,productId)
			if #out>=SpellDefs.GetLoadoutLimit() then break end
		end
	end
	return out
end
function SpellDefs.BuildDefaultLoadout(unlockedMap)
	local out,seen={},{}
	local function add(id)
		local productId=SpellDefs.NormalizeLoadoutProductId(id); local p=productId and SpellDefs.GetProduct(productId)
		if p and unlockedContains(unlockedMap,productId) and not seen[p.familyId] then seen[p.familyId]=true; table.insert(out,productId) end
	end
	for _,id in ipairs(SpellDefs.BASE_STARTER) do add(id); if #out>=SpellDefs.GetLoadoutLimit() then return out end end
	for id,value in pairs(unlockedMap or {}) do if value==true then add(id); if #out>=SpellDefs.GetLoadoutLimit() then break end end end
	return out
end

local function fmtNumber(v,d)
	local n=tonumber(v) or 0
	if math.abs(n-math.floor(n+0.5))<0.01 then return tostring(math.floor(n+0.5)) end
	return string.format("%."..tostring(d or 1).."f",n)
end
function SpellDefs.GetSpellStatLines(spellIdOrDef,state)
	local def=typeof(spellIdOrDef)=="string" and SpellDefs.GetSpell(spellIdOrDef) or spellIdOrDef
	local s=def and SpellDefs.ComputeRuntimeStats(def,state or {level=1})
	if not s then return {} end
	local lines={"Damage "..fmtNumber(s.damage,1)}
	if s.cooldown then table.insert(lines,"Cooldown "..fmtNumber(s.cooldown,2).."s") end
	if s.count and s.count>1 then table.insert(lines,"Count "..math.floor(s.count)) end
	if s.pierce and s.pierce>0 then table.insert(lines,"Pierce "..math.floor(s.pierce)) end
	if s.radius and s.radius>0 then table.insert(lines,"Radius "..fmtNumber(s.radius,1)) end
	if s.range and s.range>0 then table.insert(lines,"Range "..fmtNumber(s.range,1)) end
	if s.duration and s.duration>0 then table.insert(lines,"Duration "..fmtNumber(s.duration,1).."s") end
	return lines
end
function SpellDefs.GetSpellUpgradeLevels(spellId)
	local def=SpellDefs.GetSpell(spellId); local out={}; if not def then return out end
	for level=1,def.maxLevel do
		local code=def.upgradePlan and def.upgradePlan[level]
		table.insert(out,{level=level,description=code and UPGRADE_LABELS[code] or (level==1 and "Unlock spell" or "Improves the spell"),statLines=SpellDefs.GetSpellStatLines(def,{level=level})})
	end
	return out
end
function SpellDefs.GetCombinationList() return copyTable(SpellDefs.COMBINATIONS) end
function SpellDefs.GetCombinationById(id) return COMBINATION_BY_ID[normalizeSpellId(id)] end
function SpellDefs.GetCombinationForResult(id) return COMBINATION_BY_RESULT[normalizeSpellId(id)] end
local function readLevel(source,id)
	if type(source)=="function" then return tonumber(source(id)) or 0 end
	if typeof(source)=="table" then return tonumber(source[id]) or 0 end
	return 0
end
function SpellDefs.CanOfferCombination(comboOrId,levelSource,hasResult)
	local combo=typeof(comboOrId)=="table" and comboOrId or SpellDefs.GetCombinationById(comboOrId)
	if not combo then return false end
	if type(hasResult)=="function" and hasResult(combo.resultId) then return false end
	for _,ingredient in ipairs(combo.ingredients) do
		local def=SpellDefs.GetSpell(ingredient)
		if not def or readLevel(levelSource,ingredient)<(def.maxLevel or 20) then return false end
	end
	return true
end
function SpellDefs.DescribeCombination(comboOrId)
	local combo=typeof(comboOrId)=="table" and comboOrId or SpellDefs.GetCombinationById(comboOrId)
	if not combo then return "" end
	local parts={}
	for _,id in ipairs(combo.ingredients) do local d=SpellDefs.GetSpell(id); table.insert(parts,(d and d.name or id).." MAX") end
	local result=SpellDefs.GetSpell(combo.resultId)
	return string.format("Requires %s.\nResult: %s.\nReplaces both base spells.",table.concat(parts," + "),result and result.name or combo.resultId)
end
function SpellDefs.GetCombinationStatus(comboOrId,levelSource,discoveredMap)
	local combo=typeof(comboOrId)=="table" and comboOrId or SpellDefs.GetCombinationById(comboOrId)
	if not combo then return "unknown" end
	if typeof(discoveredMap)=="table" and discoveredMap[combo.id]==true then return "discovered" end
	return SpellDefs.CanOfferCombination(combo,levelSource) and "ready" or "locked"
end
function SpellDefs.SummarizeDamageByElement(productIds)
	local totals={}
	for _,raw in ipairs(productIds or {}) do
		local productId=SpellDefs.NormalizeLoadoutProductId(raw); local p=productId and SpellDefs.GetProduct(productId); local d=p and SpellDefs.GetSpell(p.familyId)
		if d then totals[d.element]=(totals[d.element] or 0)+(d.runtime and d.runtime.baseDamage or 0) end
	end
	return totals
end

return SpellDefs
