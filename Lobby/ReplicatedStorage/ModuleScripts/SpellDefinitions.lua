-- SpellDefinitions.lua (ReplicatedStorage/ModuleScripts)

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

SpellDefs.BASE_STARTER = {
	"FireOrb",
	"ShadowDagger",
	"PoisonCloud",
	"BoneSpear",
	"WindBlades",
	"IceShards",
}

SpellDefs.SPELLS = {
	FireOrb = {
		id = "FireOrb",
		name = "Fire Orb",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 0,
		base = true,
		tags = {"orbit", "dot", "fire"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	ShadowDagger = {
		id = "ShadowDagger",
		name = "Shadow Dagger",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 0,
		base = true,
		tags = {"projectile", "single", "crit"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	PoisonCloud = {
		id = "PoisonCloud",
		name = "Poison Cloud",
		category = "Control",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 0,
		base = true,
		tags = {"zone", "dot", "poison"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	BoneSpear = {
		id = "BoneSpear",
		name = "Bone Spear",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 0,
		base = true,
		tags = {"projectile", "pierce"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	WindBlades = {
		id = "WindBlades",
		name = "Wind Blades",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 0,
		base = true,
		tags = {"orbit", "control", "knockback"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	IceShards = {
		id = "IceShards",
		name = "Ice Shards",
		category = "Control",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = false,
		tags = {"drop", "aoe", "slow", "freeze"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	EmberSpirits = {
		id = "EmberSpirits",
		name = "Ember Spirits",
		category = "Offense",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = false,
		tags = {"orbit", "seek", "aoe", "fire"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	FlameTrail = {
		id = "FlameTrail",
		name = "Flame Trail",
		category = "Control",
		rarity = "Common",
		maxLevel = 6,
		costCoins = 250,
		base = false,
		tags = {"trail", "dot", "fire"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	LightningChain = {
		id = "LightningChain",
		name = "Lightning Chain",
		category = "Offense",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 700,
		base = false,
		tags = {"chain", "stun", "projectile"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	FrostNova = {
		id = "FrostNova",
		name = "Frost Nova",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 700,
		base = false,
		tags = {"pulse", "slow", "freeze"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	ArcaneMissile = {
		id = "ArcaneMissile",
		name = "Arcane Missile",
		category = "Offense",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 700,
		base = false,
		tags = {"projectile", "homing", "salvo"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	GravityPulse = {
		id = "GravityPulse",
		name = "Gravity Pulse",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 700,
		base = false,
		tags = {"pulse", "knockback", "pull"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	ToxicBlades = {
		id = "ToxicBlades",
		name = "Toxic Blades",
		category = "Offense",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 700,
		base = false,
		tags = {"orbit", "dot", "poison"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	CrystalBarrage = {
		id = "CrystalBarrage",
		name = "Crystal Barrage",
		category = "Offense",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 700,
		base = false,
		tags = {"projectile", "cone", "ricochet"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	ChainHooks = {
		id = "ChainHooks",
		name = "Chain Hooks",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 700,
		base = false,
		tags = {"hook", "pull", "stun"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	IceWall = {
		id = "IceWall",
		name = "Ice Wall",
		category = "Control",
		rarity = "Uncommon",
		maxLevel = 6,
		costCoins = 700,
		base = false,
		tags = {"wall", "block", "slow", "freeze"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	ThunderTotem = {
		id = "ThunderTotem",
		name = "Thunder Totem",
		category = "Offense",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1600,
		base = false,
		tags = {"totem", "projectile", "chain"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	SpiritWolves = {
		id = "SpiritWolves",
		name = "Spirit Wolves",
		category = "Summon",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1600,
		base = false,
		tags = {"summon", "melee", "bleed"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	NecroSwarm = {
		id = "NecroSwarm",
		name = "Necro Swarm",
		category = "Summon",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1600,
		base = false,
		tags = {"summon", "homing", "aoe"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	ArcaneMine = {
		id = "ArcaneMine",
		name = "Arcane Mine",
		category = "Control",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1600,
		base = false,
		tags = {"mine", "aoe", "chain"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	DarkRift = {
		id = "DarkRift",
		name = "Dark Rift",
		category = "Control",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1600,
		base = false,
		tags = {"rift", "pull", "dot"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	MeteorStrike = {
		id = "MeteorStrike",
		name = "Meteor Strike",
		category = "Offense",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1600,
		base = false,
		tags = {"drop", "aoe", "fire"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	SolarBeam = {
		id = "SolarBeam",
		name = "Solar Beam",
		category = "Offense",
		rarity = "Rare",
		maxLevel = 6,
		costCoins = 1600,
		base = false,
		tags = {"beam", "pierce", "dot", "fire"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	VoidRing = {
		id = "VoidRing",
		name = "Void Ring",
		category = "Control",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3500,
		base = false,
		tags = {"ring", "aoe", "pull"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	BloodNova = {
		id = "BloodNova",
		name = "Blood Nova",
		category = "Offense",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3500,
		base = false,
		tags = {"pulse", "aoe", "lifesteal", "bleed"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	PhantomClone = {
		id = "PhantomClone",
		name = "Phantom Clone",
		category = "Utility",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3500,
		base = false,
		tags = {"clone", "synergy"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	Starfall = {
		id = "Starfall",
		name = "Starfall",
		category = "Offense",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3500,
		base = false,
		tags = {"drop", "aoe", "stun"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	RagePulse = {
		id = "RagePulse",
		name = "Rage Pulse",
		category = "Utility",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3500,
		base = false,
		tags = {"aura", "buff", "lowhp"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	TimeFracture = {
		id = "TimeFracture",
		name = "Time Fracture",
		category = "Control",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3500,
		base = false,
		tags = {"zone", "slow", "vuln"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

	SoulLink = {
		id = "SoulLink",
		name = "Soul Link",
		category = "Utility",
		rarity = "Epic",
		maxLevel = 6,
		costCoins = 3500,
		base = false,
		tags = {"link", "aoe", "elite"},
		nextDesc = function(lv)
			return "Upgrade this spell."
		end,
	},

}

function SpellDefs.Get(id: string)
	return SpellDefs.SPELLS[id]
end

function SpellDefs.IsValid(id: string): boolean
	return SpellDefs.SPELLS[id] ~= nil
end

function SpellDefs.GetShopList()
	local out = {}
	for id, def in pairs(SpellDefs.SPELLS) do
		if def.base == false then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

return SpellDefs