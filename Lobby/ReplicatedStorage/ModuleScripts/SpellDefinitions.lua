-- SpellDefinitions.lua (ReplicatedStorage/ModuleScripts)
-- Updated: new spells, English descriptions, and per-level upgrade previews.

local SpellDefs = {}

SpellDefs.MAX_RUN_SPELLS = 6

SpellDefs.RARITY_WEIGHTS = {
	Common = 0.50,
	Uncommon = 0.335,
	Rare = 0.115,
	Epic = 0.05,
}

SpellDefs.COLOR_BASE  = Color3.fromRGB(120, 190, 255)
SpellDefs.COLOR_SHOP  = Color3.fromRGB(190, 120, 255)

-- 6 starter spells (given early / tutorial)
SpellDefs.BASE_STARTER = {
	"FireOrb",
	"ShadowDagger",
	"PoisonCloud",
	"BoneSpear",
	"WindBlades",
	"IceShards",
}

local function makeNextDesc(upgrades, maxLevel)
	return function(currentLevel)
		if currentLevel >= maxLevel then return "MAX LEVEL" end
		local nextLevel = currentLevel + 1
		return upgrades[nextLevel] or ""
	end
end

SpellDefs.SPELLS = {

	-- =========================
	-- COMMON
	-- =========================

	FireOrb = {
		id = "FireOrb",
		name = "Fire Orb",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = true,
		tags = { "offense" },
		description = "1–3 fiery orbs orbit around you and deal contact damage on hit. Can apply Burn at higher levels.",
		upgrades = {
			"Gain 1 orbiting orb.",
			"+10% damage.",
			"Gain a second orb.",
			"+10% orbit radius.",
			"Burn on hit (2s, refreshes).",
			"Gain a third orb and Burn can stack (x2).",
		},
		params = { orbitRadius = 6, orbitSpeed = 4, hitCooldownPerEnemy = 0.25, baseDmg = 10, burnDmg = 4, burnDuration = 2 },
		nextDesc = makeNextDesc({
			"Gain 1 orbiting orb.",
			"+10% damage.",
			"Gain a second orb.",
			"+10% orbit radius.",
			"Burn on hit (2s, refreshes).",
			"Gain a third orb and Burn can stack (x2).",
		}, 6),
	},

	ShadowDagger = {
		id = "ShadowDagger",
		name = "Shadow Dagger",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = true,
		tags = { "offense", "projectile" },
		description = "Throws daggers at the nearest enemy in range. Projectiles travel straight and can hit enemies along the path.",
		upgrades = {
			"Throw 1 dagger every 0.8s.",
			"-10% cooldown.",
			"Throw 2 daggers (0.1s burst).",
			"+20% projectile speed.",
			"+10% crit chance.",
			"Pierce up to 2 enemies.",
		},
		params = { range = 30, fireRate = 0.8, projectileSpeed = 90, spread = 0, pierce = 0, critChance = 0, critMulti = 2 },
		nextDesc = makeNextDesc({
			"Throw 1 dagger every 0.8s.",
			"-10% cooldown.",
			"Throw 2 daggers (0.1s burst).",
			"+20% projectile speed.",
			"+10% crit chance.",
			"Pierce up to 2 enemies.",
		}, 6),
	},

	PoisonCloud = {
		id = "PoisonCloud",
		name = "Poison Cloud",
		category = "Control",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = true,
		tags = { "control", "dot", "placement" },
		description = "Drops a poison puddle behind you. Enemies standing in it take damage over time.",
		upgrades = {
			"Drop 1 cloud every 2.5s.",
			"+15% cloud radius.",
			"+1s duration.",
			"Faster ticks (every 0.4s).",
			"Poison stacks (max 5) for bonus damage.",
			"Drop 2 clouds (left/right) every 2.5s.",
		},
		params = { spawnInterval = 2.5, cloudRadius = 7, duration = 3, tickRate = 0.5, stackMax = 0, stackBonus = 0.12 },
		nextDesc = makeNextDesc({
			"Drop 1 cloud every 2.5s.",
			"+15% cloud radius.",
			"+1s duration.",
			"Faster ticks (every 0.4s).",
			"Poison stacks (max 5) for bonus damage.",
			"Drop 2 clouds (left/right) every 2.5s.",
		}, 6),
	},

	BoneSpear = {
		id = "BoneSpear",
		name = "Bone Spear",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = true,
		tags = { "offense", "projectile" },
		description = "Fires spears toward the nearest enemy with a slight random spread. Spears pierce multiple targets.",
		upgrades = {
			"Fire 1 spear (pierce 2).",
			"+15% damage.",
			"Fire +1 spear.",
			"+1 pierce.",
			"+20% projectile speed.",
			"Fire +1 spear and increase pierce to 5.",
		},
		params = { fireRate = 1.4, projectileSpeed = 110, pierce = 2, spreadAngle = 8, baseDmg = 18 },
		nextDesc = makeNextDesc({
			"Fire 1 spear (pierce 2).",
			"+15% damage.",
			"Fire +1 spear.",
			"+1 pierce.",
			"+20% projectile speed.",
			"Fire +1 spear and increase pierce to 5.",
		}, 6),
	},

	WindBlades = {
		id = "WindBlades",
		name = "Wind Blades",
		category = "Control",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = true,
		tags = { "control", "orbit" },
		description = "A spinning blade orbits you at a larger radius, hitting enemies on contact with a per-enemy hit cooldown. Can knock enemies back at higher levels.",
		upgrades = {
			"Gain 1 blade.",
			"+10% orbit speed.",
			"Gain a second blade.",
			"+15% orbit radius.",
			"Small knockback on hit.",
			"+20% orbit speed and +15% damage.",
		},
		params = { orbitRadius = 9, orbitSpeed = 3.5, hitCooldownPerEnemy = 0.35, baseDmg = 14, knockback = 0 },
		nextDesc = makeNextDesc({
			"Gain 1 blade.",
			"+10% orbit speed.",
			"Gain a second blade.",
			"+15% orbit radius.",
			"Small knockback on hit.",
			"+20% orbit speed and +15% damage.",
		}, 6),
	},

	IceShards = {
		id = "IceShards",
		name = "Ice Shards",
		category = "Control",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = true,
		tags = { "control", "aoe" },
		description = "Drops ice shards from above around you. Impacts deal small AoE damage and slow enemies.",
		upgrades = {
			"Drop 2 shards every 2.0s.",
			"+15% impact AoE.",
			"Drop 3 shards.",
			"+0.5s slow duration.",
			"+10% chance to Freeze.",
			"Drop 5 shards and increase Freeze chance to 20%.",
		},
		params = { interval = 2.0, count = 2, dropHeight = 35, impactRadius = 6, slowPct = 0.30, slowDuration = 1.0, freezeChance = 0 },
		nextDesc = makeNextDesc({
			"Drop 2 shards every 2.0s.",
			"+15% impact AoE.",
			"Drop 3 shards.",
			"+0.5s slow duration.",
			"+10% chance to Freeze.",
			"Drop 5 shards and increase Freeze chance to 20%.",
		}, 6),
	},

	EmberSpirits = {
		id = "EmberSpirits",
		name = "Ember Spirits",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = false,
		tags = { "offense", "summon" },
		description = "Small spirits orbit close to you. One spirit launches at the nearest enemy and explodes in a small AoE.",
		upgrades = {
			"Summon 2 spirits.",
			"+10% explosion radius.",
			"Summon 3 spirits.",
			"+10% launch rate.",
			"Burn on explosion.",
			"Summon 5 spirits.",
		},
		params = { spiritCount = 2, orbitRadius = 4, launchInterval = 1.2, homingStrength = 1, explosionRadius = 7, baseDmg = 22, burnDmg = 4, burnDuration = 2 },
		nextDesc = makeNextDesc({
			"Summon 2 spirits.",
			"+10% explosion radius.",
			"Summon 3 spirits.",
			"+10% launch rate.",
			"Burn on explosion.",
			"Summon 5 spirits.",
		}, 6),
	},

	FlameTrail = {
		id = "FlameTrail",
		name = "Flame Trail",
		category = "Control",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = false,
		tags = { "control", "dot", "placement" },
		description = "Leaves burning segments under you. Enemies on the trail take damage over time.",
		upgrades = {
			"Trail segments last 2s.",
			"+10% segment size.",
			"Trail segments last 3s.",
			"Faster ticks (every 0.4s).",
			"Burn can stack.",
			"Double trail width.",
		},
		params = { spawnEvery = 0.35, segmentSize = 6, duration = 2, tickRate = 0.5, baseDmg = 10 },
		nextDesc = makeNextDesc({
			"Trail segments last 2s.",
			"+10% segment size.",
			"Trail segments last 3s.",
			"Faster ticks (every 0.4s).",
			"Burn can stack.",
			"Double trail width.",
		}, 6),
	},

	-- =========================
	-- UNCOMMON
	-- =========================

	LightningChain = {
		id = "LightningChain",
		name = "Lightning Chain",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 600,
		base = false,
		tags = { "control", "chain" },
		description = "Strikes the nearest enemy, then chains to additional nearby enemies.",
		upgrades = {
			"Chain up to 3 jumps.",
			"+10% damage.",
			"Chain up to 4 jumps.",
			"+20% jump radius.",
			"Stun 0.3s on hit.",
			"Chain up to 6 jumps and stun 0.5s.",
		},
		params = { range = 35, jumpRadius = 12, jumps = 3, baseDmg = 26, stunDuration = 0 },
		nextDesc = makeNextDesc({
			"Chain up to 3 jumps.",
			"+10% damage.",
			"Chain up to 4 jumps.",
			"+20% jump radius.",
			"Stun 0.3s on hit.",
			"Chain up to 6 jumps and stun 0.5s.",
		}, 6),
	},

	FrostNova = {
		id = "FrostNova",
		name = "Frost Nova",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 600,
		base = false,
		tags = { "control", "aoe" },
		description = "Emits a freezing pulse from you, slowing enemies in range. Can Freeze at higher levels.",
		upgrades = {
			"Slow 35% for 1.5s (every 6.0s).",
			"+15% radius.",
			"-10% cooldown.",
			"+10% Freeze chance.",
			"Freeze lasts 1.0s.",
			"Freeze chance 25% and +15% radius.",
		},
		params = { interval = 6.0, radius = 12, slowPct = 0.35, slowDuration = 1.5, freezeChance = 0, freezeDuration = 0 },
		nextDesc = makeNextDesc({
			"Slow 35% for 1.5s (every 6.0s).",
			"+15% radius.",
			"-10% cooldown.",
			"+10% Freeze chance.",
			"Freeze lasts 1.0s.",
			"Freeze chance 25% and +15% radius.",
		}, 6),
	},

	ArcaneMissile = {
		id = "ArcaneMissile",
		name = "Arcane Missile",
		category = "Offense",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 600,
		base = false,
		tags = { "offense", "projectile" },
		description = "Fires a volley of homing missiles. Missiles retarget if their target dies mid-flight.",
		upgrades = {
			"Fire 2 missiles every 2.2s.",
			"+15% missile speed.",
			"Fire 3 missiles.",
			"+15% damage.",
			"Small impact explosion.",
			"Fire 5 missiles.",
		},
		params = { missileCount = 2, range = 40, speed = 95, turnRate = 10, impactRadius = 0, baseDmg = 20 },
		nextDesc = makeNextDesc({
			"Fire 2 missiles every 2.2s.",
			"+15% missile speed.",
			"Fire 3 missiles.",
			"+15% damage.",
			"Small impact explosion.",
			"Fire 5 missiles.",
		}, 6),
	},

	GravityPulse = {
		id = "GravityPulse",
		name = "Gravity Pulse",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 600,
		base = false,
		tags = { "control", "knockback" },
		description = "Sends out a pulse that damages and knocks enemies away. Can briefly pull enemies inward at higher levels.",
		upgrades = {
			"Pulse radius 10 (every 5.0s).",
			"+20% knockback force.",
			"+15% damage.",
			"-10% cooldown.",
			"Brief pull-in (0.3s) before pushing.",
			"Bigger radius and pull lasts 0.6s.",
		},
		params = { interval = 5.0, radius = 10, force = 60, baseDmg = 22, pullDuration = 0 },
		nextDesc = makeNextDesc({
			"Pulse radius 10 (every 5.0s).",
			"+20% knockback force.",
			"+15% damage.",
			"-10% cooldown.",
			"Brief pull-in (0.3s) before pushing.",
			"Bigger radius and pull lasts 0.6s.",
		}, 6),
	},

	ToxicBlades = {
		id = "ToxicBlades",
		name = "Toxic Blades",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 600,
		base = false,
		tags = { "control", "orbit", "dot" },
		description = "Poisoned blades orbit you. Hits apply a stacking poison debuff.",
		upgrades = {
			"Gain 2 blades.",
			"+10% poison damage.",
			"Gain 3 blades.",
			"+2 max poison stacks.",
			"Gain +1 blade.",
			"Gain 6 blades and increase max stacks to 10.",
		},
		params = { bladeCount = 2, orbitRadius = 8, orbitSpeed = 3.2, hitCooldown = 0.35, poisonTick = 0.5, poisonDuration = 3, stackMax = 5 },
		nextDesc = makeNextDesc({
			"Gain 2 blades.",
			"+10% poison damage.",
			"Gain 3 blades.",
			"+2 max poison stacks.",
			"Gain +1 blade.",
			"Gain 6 blades and increase max stacks to 10.",
		}, 6),
	},

	CrystalBarrage = {
		id = "CrystalBarrage",
		name = "Crystal Barrage",
		category = "Offense",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 600,
		base = false,
		tags = { "offense", "projectile", "cone" },
		description = "Fires a cone of crystal shards toward the nearest enemy. Shards can gain AoE and ricochet at higher levels.",
		upgrades = {
			"Fire 5 shards every 2.6s.",
			"+10% damage (or tighter spread).",
			"Fire 7 shards.",
			"Impact creates a small AoE.",
			"Ricochet once.",
			"Fire 10 shards and increase AoE.",
		},
		params = { shardCount = 5, coneAngle = 28, range = 35, speed = 105, impactRadius = 0, ricochet = 0, baseDmg = 14 },
		nextDesc = makeNextDesc({
			"Fire 5 shards every 2.6s.",
			"+10% damage (or tighter spread).",
			"Fire 7 shards.",
			"Impact creates a small AoE.",
			"Ricochet once.",
			"Fire 10 shards and increase AoE.",
		}, 6),
	},

	ChainHooks = {
		id = "ChainHooks",
		name = "Chain Hooks",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 600,
		base = false,
		tags = { "control", "pull" },
		description = "Launches hooks at nearby enemies, pulling them closer without teleporting them.",
		upgrades = {
			"Launch 1 hook every 4.0s.",
			"+15% range.",
			"Launch 2 hooks.",
			"+20% pull force.",
			"Stun 0.3s after pull.",
			"2 hooks and bigger range.",
		},
		params = { range = 28, hookCount = 1, pullForce = 90, stunDuration = 0 },
		nextDesc = makeNextDesc({
			"Launch 1 hook every 4.0s.",
			"+15% range.",
			"Launch 2 hooks.",
			"+20% pull force.",
			"Stun 0.3s after pull.",
			"2 hooks and bigger range.",
		}, 6),
	},

	IceWall = {
		id = "IceWall",
		name = "Ice Wall",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 600,
		base = false,
		tags = { "control", "block" },
		description = "Creates ice walls around you. Walls block movement and slow enemies on contact.",
		upgrades = {
			"Create 1 wall for 3s (every 8.0s).",
			"+25% wall HP.",
			"Create 2 walls.",
			"+1s duration.",
			"+10% Freeze chance on touch.",
			"Create 2 walls lasting 6s.",
		},
		params = { interval = 8.0, wallCount = 1, wallSize = 10, wallHP = 200, duration = 3, slowPct = 0.35, freezeChance = 0 },
		nextDesc = makeNextDesc({
			"Create 1 wall for 3s (every 8.0s).",
			"+25% wall HP.",
			"Create 2 walls.",
			"+1s duration.",
			"+10% Freeze chance on touch.",
			"Create 2 walls lasting 6s.",
		}, 6),
	},

	-- =========================
	-- RARE
	-- =========================

	ThunderTotem = {
		id = "ThunderTotem",
		name = "Thunder Totem",
		category = "Summon",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1400,
		base = false,
		tags = { "summon", "turret" },
		description = "Places a totem near you that periodically fires lightning bolts at the nearest enemy.",
		upgrades = {
			"Place 1 totem (10s duration).",
			"+10% fire rate.",
			"+2s duration.",
			"+15% damage.",
			"Bolts chain 1 extra jump.",
			"Place 2 totems.",
		},
		params = { totemCount = 1, duration = 10, range = 35, fireRate = 0.9, baseDmg = 18, chainJumps = 0 },
		nextDesc = makeNextDesc({
			"Place 1 totem (10s duration).",
			"+10% fire rate.",
			"+2s duration.",
			"+15% damage.",
			"Bolts chain 1 extra jump.",
			"Place 2 totems.",
		}, 6),
	},

	SpiritWolves = {
		id = "SpiritWolves",
		name = "Spirit Wolves",
		category = "Summon",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1400,
		base = false,
		tags = { "summon", "melee" },
		description = "Summons spirit wolves that lunge to bite nearby enemies, then return to you.",
		upgrades = {
			"Summon 1 wolf.",
			"+10% attack speed.",
			"Summon 2 wolves.",
			"+15% damage.",
			"Apply Bleed (DoT).",
			"Summon 3 wolves and Bleed can stack.",
		},
		params = { wolfCount = 1, leashRadius = 10, aggroRange = 26, biteRate = 1.0, baseDmg = 24, bleedDmg = 6, bleedDuration = 3 },
		nextDesc = makeNextDesc({
			"Summon 1 wolf.",
			"+10% attack speed.",
			"Summon 2 wolves.",
			"+15% damage.",
			"Apply Bleed (DoT).",
			"Summon 3 wolves and Bleed can stack.",
		}, 6),
	},

	NecroSwarm = {
		id = "NecroSwarm",
		name = "Necro Swarm",
		category = "Offense",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1400,
		base = false,
		tags = { "offense", "summon" },
		description = "Summons homing skulls that seek enemies and explode on impact.",
		upgrades = {
			"Spawn 1 skull every 1.6s.",
			"+15% skull speed.",
			"Spawn 2 skulls.",
			"+15% explosion AoE.",
			"Pierce 1 target, then explode.",
			"Spawn 3 skulls.",
		},
		params = { spawnRate = 1.6, skullCount = 1, speed = 80, homing = 1, impactRadius = 7, baseDmg = 22 },
		nextDesc = makeNextDesc({
			"Spawn 1 skull every 1.6s.",
			"+15% skull speed.",
			"Spawn 2 skulls.",
			"+15% explosion AoE.",
			"Pierce 1 target, then explode.",
			"Spawn 3 skulls.",
		}, 6),
	},

	ArcaneMine = {
		id = "ArcaneMine",
		name = "Arcane Mine",
		category = "Control",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1400,
		base = false,
		tags = { "control", "placement" },
		description = "Scatters mines around you. Mines arm shortly after placement and explode when enemies enter their trigger radius.",
		upgrades = {
			"Place 2 mines every 3.5s.",
			"+15% damage.",
			"Place 3 mines.",
			"+15% explosion radius.",
			"Chain reaction: explosions can trigger nearby mines.",
			"Place 5 mines.",
		},
		params = { interval = 3.5, mineCount = 2, armTime = 0.3, maxLife = 4.0, triggerRadius = 5, explosionRadius = 8, baseDmg = 30, chainRadius = 10 },
		nextDesc = makeNextDesc({
			"Place 2 mines every 3.5s.",
			"+15% damage.",
			"Place 3 mines.",
			"+15% explosion radius.",
			"Chain reaction: explosions can trigger nearby mines.",
			"Place 5 mines.",
		}, 6),
	},

	DarkRift = {
		id = "DarkRift",
		name = "Dark Rift",
		category = "Control",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1400,
		base = false,
		tags = { "control", "pull", "aoe" },
		description = "Opens a rift near you that damages enemies over time and pulls them toward its center.",
		upgrades = {
			"Spawn 1 rift (4s duration) every 7s.",
			"+15% radius.",
			"+1s duration.",
			"+20% pull force.",
			"Faster damage ticks.",
			"Spawn 2 rifts on opposite sides.",
		},
		params = { interval = 7.0, riftCount = 1, radius = 10, duration = 4, tickRate = 0.5, pullForce = 80, baseDmg = 12 },
		nextDesc = makeNextDesc({
			"Spawn 1 rift (4s duration) every 7s.",
			"+15% radius.",
			"+1s duration.",
			"+20% pull force.",
			"Faster damage ticks.",
			"Spawn 2 rifts on opposite sides.",
		}, 6),
	},

	MeteorStrike = {
		id = "MeteorStrike",
		name = "Meteor Strike",
		category = "Offense",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1400,
		base = false,
		tags = { "offense", "aoe" },
		description = "Calls down meteors around you. Each impact has a short warning marker, then deals heavy AoE damage.",
		upgrades = {
			"Call 1 meteor every 4.5s.",
			"+15% impact AoE.",
			"Call 2 meteors.",
			"-10% cooldown.",
			"Leave a fire pool for 2s.",
			"Call 3 meteors.",
		},
		params = { interval = 4.5, meteorCount = 1, minRadius = 10, maxRadius = 25, warningTime = 0.6, impactRadius = 10, baseDmg = 55, firePoolDmg = 10, firePoolDuration = 0 },
		nextDesc = makeNextDesc({
			"Call 1 meteor every 4.5s.",
			"+15% impact AoE.",
			"Call 2 meteors.",
			"-10% cooldown.",
			"Leave a fire pool for 2s.",
			"Call 3 meteors.",
		}, 6),
	},

	SolarBeam = {
		id = "SolarBeam",
		name = "Solar Beam",
		category = "Offense",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1400,
		base = false,
		tags = { "offense", "beam" },
		description = "Fires a sustained beam toward the nearest enemy, damaging everything in a line.",
		upgrades = {
			"Beam lasts 1.2s (every 6.5s).",
			"+10% tick damage.",
			"Beam lasts 1.6s.",
			"+20% beam width.",
			"Burn on hit.",
			"Beam lasts 2.2s and has longer range.",
		},
		params = { interval = 6.5, duration = 1.2, range = 60, width = 3, tickRate = 0.18, baseDmg = 10, rotateSpeed = 6, burnDmg = 4, burnDuration = 2 },
		nextDesc = makeNextDesc({
			"Beam lasts 1.2s (every 6.5s).",
			"+10% tick damage.",
			"Beam lasts 1.6s.",
			"+20% beam width.",
			"Burn on hit.",
			"Beam lasts 2.2s and has longer range.",
		}, 6),
	},

	-- =========================
	-- EPIC
	-- =========================

	VoidRing = {
		id = "VoidRing",
		name = "Void Ring",
		category = "Control",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3200,
		base = false,
		tags = { "control", "aoe" },
		description = "Expands a void ring from you. Enemies are hit when they cross the ring’s edge. Can return for extra waves at higher levels.",
		upgrades = {
			"Cast 1 expanding wave every 5.5s.",
			"+15% max radius.",
			"Cast 2 waves (out and back).",
			"+15% damage.",
			"Light pull toward the center.",
			"Cast 3 waves with faster speed.",
		},
		params = { interval = 5.5, startRadius = 4, endRadius = 24, speed = 30, baseDmg = 40, pullForce = 0 },
		nextDesc = makeNextDesc({
			"Cast 1 expanding wave every 5.5s.",
			"+15% max radius.",
			"Cast 2 waves (out and back).",
			"+15% damage.",
			"Light pull toward the center.",
			"Cast 3 waves with faster speed.",
		}, 6),
	},

	BloodNova = {
		id = "BloodNova",
		name = "Blood Nova",
		category = "Offense",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3200,
		base = false,
		tags = { "offense", "aoe" },
		description = "Explodes around you, dealing damage that scales with your missing HP (lower HP = higher damage).",
		upgrades = {
			"Blood Nova every 7.0s.",
			"+15% radius.",
			"-10% cooldown.",
			"+5% lifesteal from hits.",
			"Apply Bleed.",
			"Stronger missing-HP scaling and 10% lifesteal.",
		},
		params = { interval = 7.0, radius = 12, baseDmg = 45, missingHpMultiplier = 0.9, lifestealPct = 0, bleedDmg = 8, bleedDuration = 3 },
		nextDesc = makeNextDesc({
			"Blood Nova every 7.0s.",
			"+15% radius.",
			"-10% cooldown.",
			"+5% lifesteal from hits.",
			"Apply Bleed.",
			"Stronger missing-HP scaling and 10% lifesteal.",
		}, 6),
	},

	PhantomClone = {
		id = "PhantomClone",
		name = "Phantom Clone",
		category = "Summon",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3200,
		base = false,
		tags = { "summon", "utility" },
		description = "Summons a clone that repeats your projectile casts with a short delay and reduced damage.",
		upgrades = {
			"Clone copies projectiles at 35% damage.",
			"Copy damage 45%.",
			"Clone positions more aggressively.",
			"Copy damage 60%.",
			"Summon 2 clones at 35% damage each.",
			"Upgrade to 1 clone at 90% damage (or keep 2 at 60%).",
		},
		params = { copyPct = 0.35, delay = 0.15, cloneCount = 1 },
		nextDesc = makeNextDesc({
			"Clone copies projectiles at 35% damage.",
			"Copy damage 45%.",
			"Clone positions more aggressively.",
			"Copy damage 60%.",
			"Summon 2 clones at 35% damage each.",
			"Upgrade to 1 clone at 90% damage (or keep 2 at 60%).",
		}, 6),
	},

	Starfall = {
		id = "Starfall",
		name = "Starfall",
		category = "Control",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3200,
		base = false,
		tags = { "control", "aoe" },
		description = "Calls down a series of strikes from the sky around you. Impacts deal AoE damage and can briefly stun enemies.",
		upgrades = {
			"5 strikes every 8.5s.",
			"+15% impact AoE.",
			"7 strikes.",
			"Stun 0.3s on hit.",
			"9 strikes.",
			"12 strikes and a larger strike area.",
		},
		params = { interval = 8.5, strikes = 5, radiusMin = 20, radiusMax = 35, warningTime = 0.6, impactRadius = 8, baseDmg = 28, stunDuration = 0 },
		nextDesc = makeNextDesc({
			"5 strikes every 8.5s.",
			"+15% impact AoE.",
			"7 strikes.",
			"Stun 0.3s on hit.",
			"9 strikes.",
			"12 strikes and a larger strike area.",
		}, 6),
	},

	RagePulse = {
		id = "RagePulse",
		name = "Rage Pulse",
		category = "Offense",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3200,
		base = false,
		tags = { "offense", "passive" },
		description = "A passive aura that increases your damage as your HP gets lower. Can also deal aura damage at higher levels.",
		upgrades = {
			"Missing-HP damage bonus up to 20%.",
			"Max bonus up to 30%.",
			"Gain aura damage ticks.",
			"+15% aura radius.",
			"Small lifesteal.",
			"Max bonus up to 50% and stronger aura.",
		},
		params = { minBonus = 0.0, maxBonus = 0.20, auraRadius = 0, auraTick = 0.6, auraDmg = 6, lifestealPct = 0 },
		nextDesc = makeNextDesc({
			"Missing-HP damage bonus up to 20%.",
			"Max bonus up to 30%.",
			"Gain aura damage ticks.",
			"+15% aura radius.",
			"Small lifesteal.",
			"Max bonus up to 50% and stronger aura.",
		}, 6),
	},

	TimeFracture = {
		id = "TimeFracture",
		name = "Time Fracture",
		category = "Control",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3200,
		base = false,
		tags = { "control", "slow" },
		description = "Creates a time zone around you that slows enemy movement and attacks for a short duration.",
		upgrades = {
			"Slow 30% for 3s every 10s.",
			"+15% radius.",
			"Slow 40%.",
			"+1s duration.",
			"Enemies inside take increased damage.",
			"Slow 55% for 5s and bigger radius.",
		},
		params = { interval = 10.0, radius = 14, duration = 3.0, slowPct = 0.30, vulnPct = 0 },
		nextDesc = makeNextDesc({
			"Slow 30% for 3s every 10s.",
			"+15% radius.",
			"Slow 40%.",
			"+1s duration.",
			"Enemies inside take increased damage.",
			"Slow 55% for 5s and bigger radius.",
		}, 6),
	},

	SoulLink = {
		id = "SoulLink",
		name = "Soul Link",
		category = "Control",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3200,
		base = false,
		tags = { "control", "utility" },
		description = "Links a priority enemy. Damage dealt to the anchor splashes to nearby enemies for a duration.",
		upgrades = {
			"Link 25% damage to nearby enemies every 9s.",
			"+15% link radius.",
			"Link 35% damage.",
			"+1.5s duration.",
			"Link also applies from indirect sources.",
			"Link 50% damage and bigger radius.",
		},
		params = { interval = 9.0, duration = 4.0, linkPct = 0.25, radius = 14, retargetDelay = 0.2 },
		nextDesc = makeNextDesc({
			"Link 25% damage to nearby enemies every 9s.",
			"+15% link radius.",
			"Link 35% damage.",
			"+1.5s duration.",
			"Link also applies from indirect sources.",
			"Link 50% damage and bigger radius.",
		}, 6),
	},
}

-- =========================
-- Helpers used by Lobby SpellService / Witch shop
-- =========================

function SpellDefs.Get(id: string)
	return SpellDefs.SPELLS[id]
end

function SpellDefs.IsValid(id: string): boolean
	return SpellDefs.SPELLS[id] ~= nil
end

-- List of spells that should appear in the witch shop.
-- Includes all non-base spells with a coin cost.
function SpellDefs.GetShopList(): {string}
	local list = {}
	for id, def in pairs(SpellDefs.SPELLS) do
		if typeof(def) == "table" then
			local cost = tonumber(def.costCoins) or 0
			local isBase = def.base == true
			if (not isBase) and cost > 0 then
				table.insert(list, id)
			end
		end
	end
	-- stable ordering (cheaper first, then name) so the shop doesn't jump around
	table.sort(list, function(a, b)
		local da = SpellDefs.SPELLS[a]
		local db = SpellDefs.SPELLS[b]
		local ca = tonumber(da and da.costCoins) or 0
		local cb = tonumber(db and db.costCoins) or 0
		if ca ~= cb then
			return ca < cb
		end
		local na = tostring(da and da.name or a)
		local nb = tostring(db and db.name or b)
		return na < nb
	end)
	return list
end

return SpellDefs
