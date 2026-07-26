-- WeaponCombat.server.lua (Level1)
-- Server-authoritative auto-attack: nearest enemy hit with optional AoE by weapon type.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local VFXEvent = Remotes:WaitForChild("WeaponSwingVFX")

local function findModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then return direct end
	local folder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then return nested end
	end
	return nil
end

local PlayerData = require(findModule("PlayerData") or error("[WeaponCombat] Missing PlayerData"))
local NpcService = require(findModule("NpcService") or error("[WeaponCombat] Missing NpcService"))
local DamageIndicatorService = require(findModule("DamageIndicatorService") or error("[WeaponCombat] Missing DamageIndicatorService"))
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local WeaponConfigs = moduleFolder and moduleFolder:FindFirstChild("WeaponConfigs") and require(moduleFolder.WeaponConfigs) or nil

local CD_BY_TYPE = {
	Sword = 0.55, Scythe = 0.80, Halberd = 0.75, Claymore = 0.95, Greataxe = 1.05,
	Bow = 0.65, Wand = 0.55, Staff = 0.75, Pistol = 0.45,
}

local RANGE_BY_TYPE = {
	Sword = 9, Scythe = 10, Halberd = 12, Claymore = 10, Greataxe = 10,
	Bow = 60, Wand = 45, Staff = 50, Pistol = 55,
}

local AOE_RADIUS_BY_TYPE = {
	Scythe = 7,
	Halberd = 6.5,
}

local WEAPON_ELEMENT_OVERRIDES = {
	["Knight's Oath"] = "Physical",
	["Excalion, Blade of Kings"] = "Light",
	["Reaper's Crescent"] = "Void",
	["Harvest of the End"] = "Void",
	["Warden's Halberd"] = "Earth",
	["Dragonspear Halberd"] = "Fire",
	["Hunter's Longbow"] = "Air",
	["Stormwind Recurve"] = "Air",
	["Apprentice Arcstaff"] = "Electricity",
	["Archmage's Worldstaff"] = "Fire",
	["Blackpowder Flintlock"] = "Physical",
	["Kingslayer Handcannon"] = "Physical",
}

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

local function getLoadoutEntry(plr: Player)
	local data = PlayerData.Get(plr)
	if not data or typeof(data.Loadout) ~= "table" then return nil end
	return data.Loadout[1]
end

local function getWeaponDef(entry)
	local id = entry and (entry.id or entry.Id)
	if WeaponConfigs and WeaponConfigs.Get and typeof(id) == "string" then
		return WeaponConfigs.Get(id)
	end
	return nil
end

local function normalizeElement(value): string
	local element = tostring(value or "")
	element = ELEMENT_ALIASES[element] or element
	if VALID_ELEMENTS[element] then
		return element
	end
	return "Physical"
end

local function inferElementFromName(name: string): string
	local lower = string.lower(name)
	if lower:find("ember", 1, true)
		or lower:find("fire", 1, true)
		or lower:find("inferno", 1, true)
		or lower:find("flame", 1, true)
		or lower:find("dragon", 1, true)
	then
		return "Fire"
	end
	if lower:find("frost", 1, true)
		or lower:find("glacier", 1, true)
		or lower:find("water", 1, true)
		or lower:find("tide", 1, true)
	then
		return "Water"
	end
	if lower:find("storm", 1, true)
		or lower:find("wind", 1, true)
		or lower:find("feather", 1, true)
		or lower:find("gale", 1, true)
	then
		return "Air"
	end
	if lower:find("earth", 1, true)
		or lower:find("grove", 1, true)
		or lower:find("forest", 1, true)
		or lower:find("moss", 1, true)
		or lower:find("verdant", 1, true)
		or lower:find("nature", 1, true)
		or lower:find("thorn", 1, true)
		or lower:find("ironwood", 1, true)
		or lower:find("rust", 1, true)
	then
		return "Earth"
	end
	if lower:find("void", 1, true)
		or lower:find("shadow", 1, true)
		or lower:find("eclipse", 1, true)
		or lower:find("night", 1, true)
	then
		return "Void"
	end
	if lower:find("sun", 1, true)
		or lower:find("solar", 1, true)
		or lower:find("dawn", 1, true)
		or lower:find("gold", 1, true)
		or lower:find("royal", 1, true)
		or lower:find("angel", 1, true)
	then
		return "Light"
	end
	if lower:find("arc", 1, true)
		or lower:find("volt", 1, true)
		or lower:find("thunder", 1, true)
		or lower:find("lightning", 1, true)
	then
		return "Electricity"
	end
	return "Physical"
end

local function resolveWeaponElement(entry): string
	local def = getWeaponDef(entry)
	local explicit = entry and (entry.element or entry.Element) or nil
	if explicit == nil and def then
		explicit = def.element
	end

	local weaponId = tostring(entry and (entry.id or entry.Id) or "")
	return normalizeElement(explicit or WEAPON_ELEMENT_OVERRIDES[weaponId] or inferElementFromName(weaponId))
end

local function resolveWeaponType(entry)
	local def = getWeaponDef(entry)
	if def and typeof(def.weaponType) == "string" then
		return def.weaponType
	end
	return "Sword"
end

local function getAttrNum(plr: Player, name: string, fallback: number): number
	local v = plr:GetAttribute(name)
	if typeof(v) ~= "number" then
		return fallback
	end
	return v
end

local function isCombatPlayerActive(plr: Player): boolean
	if not plr or plr.Parent ~= Players or plr:GetAttribute("RunEnded") == true then
		return false
	end

	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and hum.Health > 0 and hrp ~= nil
end

local function isEliteEnemy(enemyModel: Model): boolean
	if enemyModel:GetAttribute("IsElite") == true then
		return true
	end
	return string.sub(enemyModel.Name, 1, 5) == "Boss_"
end

local function getEntryStat(entry, keys: {string}): number
	local statMap = entry and (entry.rollStats or entry.RollStats or entry.stats or entry.Stats)
	if typeof(statMap) ~= "table" then
		return 0
	end
	for _, key in ipairs(keys) do
		local value = statMap[key]
		if typeof(value) == "number" then
			return value
		end
	end
	return 0
end

local function calcAttackStats(plr: Player, entry)
	local level = tonumber(entry and (entry.level or entry.Level)) or 1
	level = math.max(1, math.floor(level))

	local def = getWeaponDef(entry)
	local combat = def and def.combat or nil

	local base = 10
	local perLvl = 1
	if combat then
		base = tonumber(combat.baseAtk or def.baseDamage) or base
		perLvl = tonumber(combat.atkPerLevel) or perLvl
	end
	base += getEntryStat(entry, { "BaseATK", "baseAtk" })
	perLvl += getEntryStat(entry, { "ATKPerLevel", "atkPerLevel" })

	local pdata = PlayerData.Get(plr) or {}
	local damageMult = getAttrNum(plr, "ShrineDamageMult", 1)
	local runAtkMult = getAttrNum(plr, "RunAtkMult", 1)
	local attackSpeedBonus = getAttrNum(plr, "ShrineAttackSpeedBonus", 0)
	local critDamageBonus = getAttrNum(plr, "ShrineCritDamageBonus", 0)
	local lifestealBonus = getAttrNum(plr, "ShrineLifestealPct", 0)
	local eliteBonus = getAttrNum(plr, "ShrineEliteDamageBonus", 0)
	local knockbackMult = math.max(0, getAttrNum(plr, "ShrineKnockbackMult", 1))

	local baseDamage = (base + ((level - 1) * perLvl)) * runAtkMult * damageMult

	local critChance = (tonumber(pdata.baseCritRate) or 0.05) + (tonumber(pdata.critChance) or 0)
	local critMult = (tonumber(pdata.baseCritDmg) or 1.5) + (tonumber(pdata.critMult) or 0)
	local lifesteal = (tonumber(pdata.baseLifesteal) or 0) + (tonumber(pdata.lifesteal) or 0)

	if combat then
		critChance += tonumber(combat.bonusCritRate) or 0
		critMult += tonumber(combat.bonusCritDmg) or 0
		lifesteal += tonumber(combat.bonusLifesteal) or 0
	end
	critChance += getEntryStat(entry, { "BonusCritRate", "bonusCritRate" })
	critMult += getEntryStat(entry, { "BonusCritDmg", "bonusCritDmg" })
	lifesteal += getEntryStat(entry, { "BonusLifesteal", "bonusLifesteal" })

	critChance = math.clamp(critChance, 0, 0.95)
	critMult = math.max(1.1, critMult + critDamageBonus)
	lifesteal = math.clamp(lifesteal + lifestealBonus, 0, 0.9)

	local attackSpeedMult = math.max(0.1, (tonumber(pdata.attackSpeed) or 1) * (1 + attackSpeedBonus))
	local eliteMult = 1 + math.max(0, eliteBonus)

	return {
		baseDamage = baseDamage,
		critChance = critChance,
		critMult = critMult,
		lifesteal = lifesteal,
		attackSpeedMult = attackSpeedMult,
		eliteMult = eliteMult,
		knockbackPower = 8 * knockbackMult,
	}
end

local function nearestEnemy(fromPos: Vector3, maxRange: number)
	return NpcService.GetNearestEnemy(fromPos, maxRange)
end

local function getEnemiesInRadius(fromPos: Vector3, radius: number)
	return NpcService.GetEnemiesInRadius(fromPos, radius)
end

local loops = {}

local function startLoop(plr: Player)
	if loops[plr] then loops[plr].alive = false end
	local state = { alive = true }
	loops[plr] = state

	task.spawn(function()
		local last = 0
		while state.alive and plr.Parent do
			task.wait(0.05)
			if plr:GetAttribute("RunEnded") == true then
				break
			end

			if PauseState.Value then
				continue
			end

			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not isCombatPlayerActive(plr) or not hrp or not hum then
				continue
			end

			local entry = getLoadoutEntry(plr)
			if not entry then
				continue
			end

			local weaponId = tostring(entry.id or entry.Id or "")
			local wType = resolveWeaponType(entry)
			local element = resolveWeaponElement(entry)
			local stats = calcAttackStats(plr, entry)
			local baseCd = CD_BY_TYPE[wType] or 0.7
			local cd = baseCd / stats.attackSpeedMult
			local range = RANGE_BY_TYPE[wType] or 10

			local now = time()
			if (now - last) < cd then
				continue
			end

			local enemy = nearestEnemy(hrp.Position, range)
			if not enemy or not NpcService.IsAlive(enemy) then
				continue
			end

			local enemyPos = NpcService.GetPosition(enemy)
			if not enemyPos then
				continue
			end

			last = now

			if stats.baseDamage <= 0 then
				continue
			end

			local hitEnemies = { enemy }
			local aoeRadius = AOE_RADIUS_BY_TYPE[wType]
			if aoeRadius then
				hitEnemies = getEnemiesInRadius(enemyPos, aoeRadius)
			end

			local totalHeal = 0
			for _, enemyModel in ipairs(hitEnemies) do
				if NpcService.IsAlive(enemyModel) then
					local enemyHitPos = NpcService.GetPosition(enemyModel)
					local isCrit = math.random() < stats.critChance
					local dealt = stats.baseDamage
					if isCrit then
						dealt *= stats.critMult
					end
					if isEliteEnemy(enemyModel) then
						dealt *= stats.eliteMult
					end
					dealt = math.max(1, math.floor(dealt + 0.5))

					local applied = DamageIndicatorService.ApplyDamage(enemyModel, dealt, {
						player = plr,
						crit = isCrit,
						element = element,
						sourceId = weaponId,
					})
					if applied > 0 then
						if enemyHitPos and stats.knockbackPower > 0 then
							local dir = enemyHitPos - hrp.Position
							if dir.Magnitude > 0.1 then
								NpcService.AddImpulse(enemyModel, dir.Unit * stats.knockbackPower)
							end
						end

						if stats.lifesteal > 0 then
							totalHeal += applied * stats.lifesteal
						end
					end
				end
			end

			if totalHeal > 0 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + totalHeal)
			end

			VFXEvent:FireAllClients({
				weaponId = weaponId,
				pos = enemyPos,
				lookAt = hrp.Position,
			})
		end

		if loops[plr] == state then
			loops[plr] = nil
		end
	end)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		startLoop(plr)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	if loops[plr] then
		loops[plr].alive = false
		loops[plr] = nil
	end
end)

for _, plr in ipairs(Players:GetPlayers()) do
	plr.CharacterAdded:Connect(function()
		startLoop(plr)
	end)
	if plr.Character then
		startLoop(plr)
	end
end
