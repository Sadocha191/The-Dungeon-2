-- SpellDefinitions.lua (ReplicatedStorage/ModuleScripts)
-- Definicje + opisy "next level" pod UI

local SpellDefs = {}

SpellDefs.MAX_RUN_SPELLS = 6

-- kolory pod UI (możesz zmienić)
SpellDefs.COLOR_BASE  = Color3.fromRGB(120, 190, 255)
SpellDefs.COLOR_SHOP  = Color3.fromRGB(190, 120, 255)

-- Bazowe 6 (dawane w tutorialu)
SpellDefs.BASE_STARTER = {
	"SeekerBolt",
	"WardingSigils",
	"HexAura",
	"StormMark",
	"CursedPuddle",
	"RicochetShard",
}

SpellDefs.SPELLS = {
	SeekerBolt = {
		id = "SeekerBolt",
		name = "Seeker Bolt",
		category = "Offense",
		maxLevel = 8,
		costCoins = 0,
		base = true,
		-- przykładowe skale
		scale = { dmg = 8, cd = 1.30, homing = 1 },
		nextDesc = function(lv)
			local dmg = 8 + (lv * 4)
			local cd  = math.max(0.35, 1.30 - (lv * 0.10))
			return ("Homing bolt. Next: +DMG (%d), -CD (%.2fs)."):format(dmg, cd)
		end,
	},

	WardingSigils = {
		id = "WardingSigils",
		name = "Warding Sigils",
		category = "Offense",
		maxLevel = 8,
		costCoins = 0,
		base = true,
		nextDesc = function(lv)
			local count = 2 + math.floor((lv+1)/2)
			local dmg = 6 + (lv * 3)
			return ("Orbiting sigils. Next: sigils=%d, dmg=%d."):format(count, dmg)
		end,
	},

	HexAura = {
		id = "HexAura",
		name = "Hex Aura",
		category = "Control",
		maxLevel = 8,
		costCoins = 0,
		base = true,
		nextDesc = function(lv)
			local dps = 3 + (lv * 2)
			local radius = 8 + (lv * 1.0)
			return ("Damage aura. Next: dps=%d, radius=%.1f."):format(dps, radius)
		end,
	},

	StormMark = {
		id = "StormMark",
		name = "Storm Mark",
		category = "Offense",
		maxLevel = 8,
		costCoins = 0,
		base = true,
		nextDesc = function(lv)
			local dmg = 10 + (lv * 5)
			local cd = math.max(0.6, 2.0 - (lv * 0.15))
			return ("Random strike. Next: dmg=%d, cd=%.2fs."):format(dmg, cd)
		end,
	},

	CursedPuddle = {
		id = "CursedPuddle",
		name = "Cursed Puddle",
		category = "Control",
		maxLevel = 8,
		costCoins = 0,
		base = true,
		nextDesc = function(lv)
			local dps = 4 + (lv * 2)
			local dur = 2.5 + (lv * 0.35)
			return ("Ground DoT. Next: dps=%d, duration=%.1fs."):format(dps, dur)
		end,
	},

	RicochetShard = {
		id = "RicochetShard",
		name = "Ricochet Shard",
		category = "Offense",
		maxLevel = 8,
		costCoins = 0,
		base = true,
		nextDesc = function(lv)
			local bounces = 1 + math.floor((lv+1)/2)
			local dmg = 7 + (lv * 3)
			return ("Bouncing shard. Next: bounces=%d, dmg=%d."):format(bounces, dmg)
		end,
	},

	-- Shop / unlocki (przykładowa pula)
	ChainSpark = {
		id = "ChainSpark",
		name = "Chain Spark",
		category = "Offense",
		maxLevel = 8,
		costCoins = 600,
		base = false,
		nextDesc = function(lv)
			local jumps = 2 + math.floor((lv+1)/2)
			local dmg = 6 + (lv * 3)
			return ("Chain hit. Next: jumps=%d, dmg=%d."):format(jumps, dmg)
		end,
	},

	GravityWell = {
		id = "GravityWell",
		name = "Gravity Well",
		category = "Control",
		maxLevel = 8,
		costCoins = 800,
		base = false,
		nextDesc = function(lv)
			local radius = 7 + (lv * 1.1)
			local dps = 3 + (lv * 2)
			return ("Pull zone. Next: radius=%.1f, dps=%d."):format(radius, dps)
		end,
	},

	FrostNeedle = {
		id = "FrostNeedle",
		name = "Frost Needle",
		category = "Control",
		maxLevel = 8,
		costCoins = 700,
		base = false,
		nextDesc = function(lv)
			local dmg = 7 + (lv * 3)
			local slow = math.min(0.55, 0.15 + (lv * 0.05))
			return ("Fast projectile. Next: dmg=%d, slow=%.0f%%."):format(dmg, slow*100)
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
