-- SCRIPT: WeaponTemplates.server.lua
-- GDZIE: ServerScriptService/WeaponTemplates.server.lua (Script)
-- CO: nakłada statystyki/pasywa na modele broni z ServerStorage/WeaponTemplates

local ServerScriptService = game:GetService("ServerScriptService")
local WeaponCatalog = require(ServerScriptService:WaitForChild("WeaponCatalog"))

local STAT_KEYS = { "HP", "SPD", "CRIT_RATE", "CRIT_DMG", "LIFESTEAL", "DEF" }

local WEAPON_DATA = {
	["Knight's Oath"] = {
		weaponType = "Sword",
		rarity = "Common",
		maxLevel = 20,
		baseDamage = 10,
		stats = {
			DEF = 8,
		},
		passiveName = "Light Cleave",
		passiveDescription = "Basic attacks hit up to 2 enemies in a small forward arc. Secondary hit deals 60% damage.",
	},
	["Excallion, Blade of Kings"] = {
		weaponType = "Sword",
		rarity = "Legendary",
		maxLevel = 80,
		baseDamage = 16,
		stats = {
			HP = 120,
			CRIT_RATE = 10,
			CRIT_DMG = 45,
			DEF = 18,
		},
		abilityName = "Royal Shockwave",
		abilityDescription = "Every 5th hit releases a shockwave dealing 120% ATK AoE damage. Staggers non-boss enemies.",
	},
	["Reaper's Crescent"] = {
		weaponType = "Scythe",
		rarity = "Epic",
		maxLevel = 60,
		baseDamage = 19,
		stats = {
			HP = 90,
			SPD = 4,
			LIFESTEAL = 3,
		},
		passiveName = "Bleed on Hit",
		passiveDescription = "Applies Bleed for 3s, stacks up to 5. Each stack deals 12% ATK per second.",
	},
	["Harvest of the End"] = {
		weaponType = "Scythe",
		rarity = "Legendary",
		maxLevel = 80,
		baseDamage = 22,
		stats = {
			HP = 140,
			CRIT_RATE = 8,
			CRIT_DMG = 55,
			LIFESTEAL = 5,
		},
		abilityName = "Feast on Death",
		abilityDescription = "On kill: gain +6% damage for 4s per stack. Stacks up to 10 and refreshes on kill.",
	},
	["Warden's Halberd"] = {
		weaponType = "Halberd",
		rarity = "Rare",
		maxLevel = 40,
		baseDamage = 15,
		stats = {
			DEF = 14,
			CRIT_RATE = 6,
		},
		passiveName = "Pierce",
		passiveDescription = "Attacks hit up to 2 enemies in a straight line.",
	},
	["Dragonspear Halberd"] = {
		weaponType = "Halberd",
		rarity = "Epic",
		maxLevel = 60,
		baseDamage = 18,
		stats = {
			HP = 80,
			DEF = 18,
			CRIT_DMG = 35,
		},
		passiveName = "Armor Break",
		passiveDescription = "Hits reduce enemy DEF by 12% for 3s. Boss effectiveness reduced by 50%.",
	},
	["Hunter's Longbow"] = {
		weaponType = "Bow",
		rarity = "Common",
		maxLevel = 20,
		baseDamage = 9,
		stats = {
			CRIT_RATE = 5,
		},
		passiveName = "Steady Aim",
		passiveDescription = "+20% projectile speed and improved accuracy (no damage bonus).",
	},
	["Stormwind Recurve"] = {
		weaponType = "Bow",
		rarity = "Epic",
		maxLevel = 60,
		baseDamage = 12,
		stats = {
			SPD = 6,
			CRIT_RATE = 10,
			CRIT_DMG = 35,
		},
		passiveName = "Split Shot",
		passiveDescription = "25% chance to split into 2 seeking arrows. Secondary arrows deal 45% damage.",
	},
	["Apprentice Arcstaff"] = {
		weaponType = "Staff",
		rarity = "Rare",
		maxLevel = 40,
		baseDamage = 9,
		stats = {
			HP = 70,
			CRIT_RATE = 7,
		},
		passiveName = "Arc Charge",
		passiveDescription = "Every 4th hit deals +50% ATK magic damage and chains to 1 nearby enemy for 30% damage.",
	},
	["Archmage's Worldstaff"] = {
		weaponType = "Staff",
		rarity = "Mythical",
		maxLevel = 100,
		baseDamage = 15,
		stats = {
			HP = 150,
			SPD = 8,
			CRIT_RATE = 12,
			CRIT_DMG = 70,
		},
		abilityName = "Reality Bend",
		abilityDescription = "Every spell gains a random elemental modifier (Burn/Freeze/Shock). Bosses receive 50% reduced duration.",
	},
	["Blackpowder Flintlock"] = {
		weaponType = "Pistol",
		rarity = "Rare",
		maxLevel = 40,
		baseDamage = 18,
		stats = {
			CRIT_RATE = 8,
			DEF = 10,
		},
		passiveName = "Armor Crack",
		passiveDescription = "Reduces enemy DEF by 8% for 2.5s. Boss effectiveness halved.",
	},
	["Kingslayer Handcannon"] = {
		weaponType = "Pistol",
		rarity = "Legendary",
		maxLevel = 80,
		baseDamage = 26,
		stats = {
			CRIT_RATE = 6,
			CRIT_DMG = 90,
			LIFESTEAL = 3,
			DEF = 12,
		},
		abilityName = "Execution Round",
		abilityDescription = "First shot after reload/no-shot cooldown always crits and deals +25% bonus damage.",
	},
}

local function applyStats(tool: Tool, data)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponType", data.weaponType)
	tool:SetAttribute("BaseDamage", data.baseDamage)
	tool:SetAttribute("Rarity", data.rarity)
	tool:SetAttribute("MaxLevel", data.maxLevel)
	tool:SetAttribute("SellValue", math.max(1, math.floor(data.baseDamage * 3)))

	local stats = data.stats or {}
	for _, key in ipairs(STAT_KEYS) do
		tool:SetAttribute(key, stats[key] or 0)
	end

	tool:SetAttribute("PassiveName", data.passiveName or "")
	tool:SetAttribute("PassiveDescription", data.passiveDescription or "")
	tool:SetAttribute("AbilityName", data.abilityName or "")
	tool:SetAttribute("AbilityDescription", data.abilityDescription or "")
end

local updated = 0
for weaponName, data in pairs(WEAPON_DATA) do
	local template = WeaponCatalog.FindTemplate(weaponName)
	if not template then
		warn("[WeaponTemplates] Missing template:", weaponName)
		continue
	end
	applyStats(template, data)
	WeaponCatalog.PrepareTool(template)
	updated += 1
end

print("[WeaponTemplates] Applied weapon data:", updated)
