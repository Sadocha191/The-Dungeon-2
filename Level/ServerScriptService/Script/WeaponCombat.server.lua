local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local VFXEvent = Remotes:WaitForChild("WeaponSwingVFX")

local function findModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	local folder = ServerScriptService:FindFirstChild("ModuleScript") or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end
	return nil
end

local PlayerData = require(findModule("PlayerData") or error("[WeaponCombat] Missing PlayerData"))
local NpcService = require(findModule("NpcService") or error("[WeaponCombat] Missing NpcService"))
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local WeaponConfigs = moduleFolder and moduleFolder:FindFirstChild("WeaponConfigs") and require(moduleFolder.WeaponConfigs) or nil

local TYPE_DEFAULTS = {
	Sword = {
		attackCooldown = 0.58,
		range = 10,
		cleaveTargets = 2,
		cleaveRadius = 6,
		cleaveFalloff = 0.55,
	},
	Scythe = {
		attackCooldown = 0.84,
		range = 11,
		aoeRadius = 7.0,
		aoeMaxTargets = 6,
		aoeFalloff = 0.74,
		bleedDuration = 2.8,
		bleedMaxStacks = 3,
		bleedDpsMultiplier = 0.14,
		healOnKillPct = 0.02,
	},
	Halberd = {
		attackCooldown = 0.80,
		range = 13.5,
		pierceTargets = 3,
		lineWidth = 3.2,
		eliteDamageBonus = 0.12,
	},
	Bow = {
		attackCooldown = 0.70,
		range = 72,
		focusEvery = 3,
		focusMultiplier = 1.22,
	},
	Staff = {
		attackCooldown = 0.74,
		range = 52,
		arcChargeEvery = 4,
		arcChargeMultiplier = 0.55,
		arcChainCount = 1,
		arcChainRadius = 15,
		arcChainMultiplier = 0.30,
	},
	Pistol = {
		attackCooldown = 0.50,
		range = 52,
		executionEvery = 4,
		executionBonusMultiplier = 1.20,
		executeThreshold = 0.30,
		executeThresholdMultiplier = 1.12,
		eliteDamageBonus = 0.08,
	},
}

local DOT_TICK = 0.5
local DOT_STATES = {}
local loops = {}

local function isCombatPlayerActive(plr: Player): boolean
	if not plr or plr.Parent ~= Players or plr:GetAttribute("RunEnded") == true then
		return false
	end

	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and hum.Health > 0 and hrp ~= nil
end

local function shallowCopy(src)
	local out = {}
	for key, value in pairs(src or {}) do
		out[key] = value
	end
	return out
end

local function distancePointToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom <= 1e-4 then
		return (point - a).Magnitude
	end
	local t = math.clamp(((point - a):Dot(ab)) / denom, 0, 1)
	local projection = a + (ab * t)
	return (point - projection).Magnitude
end

local function getLoadoutEntry(plr: Player)
	local data = PlayerData.Get(plr)
	if not data or typeof(data.Loadout) ~= "table" then
		return nil
	end
	return data.Loadout[1]
end

local function getWeaponDef(entry)
	local id = entry and (entry.id or entry.Id)
	if WeaponConfigs and WeaponConfigs.Get and typeof(id) == "string" then
		return WeaponConfigs.Get(id)
	end
	return nil
end

local function resolveWeaponType(entry)
	local def = getWeaponDef(entry)
	if def and typeof(def.weaponType) == "string" then
		return def.weaponType
	end
	return "Sword"
end

local function getAttrNum(plr: Player, name: string, fallback: number): number
	local value = plr:GetAttribute(name)
	if typeof(value) ~= "number" then
		return fallback
	end
	return value
end

local function isBossEnemy(enemyModel: Model): boolean
	if enemyModel:GetAttribute("IsBoss") == true then
		return true
	end
	return string.sub(enemyModel.Name, 1, 5) == "Boss_"
end

local function isEliteEnemy(enemyModel: Model): boolean
	return enemyModel:GetAttribute("IsElite") == true or isBossEnemy(enemyModel)
end

local function getHealthRatio(enemyModel: Model): number
	local health = tonumber(enemyModel:GetAttribute("NpcHealth") or enemyModel:GetAttribute("Health")) or 0
	local maxHealth = tonumber(enemyModel:GetAttribute("NpcMaxHealth") or enemyModel:GetAttribute("MaxHealth")) or 1
	return health / math.max(1, maxHealth)
end

local function getEntryStat(entry, keys: { string }): number
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

local function getWeaponRuntime(entry)
	local weaponType = resolveWeaponType(entry)
	local runtime = shallowCopy(TYPE_DEFAULTS[weaponType] or TYPE_DEFAULTS.Sword)
	local def = getWeaponDef(entry)
	if def and typeof(def.combat) == "table" then
		for key, value in pairs(def.combat) do
			if typeof(value) == "number" or typeof(value) == "boolean" then
				runtime[key] = value
			end
		end
	end
	runtime.weaponType = weaponType
	runtime.weaponId = def and def.id or tostring(entry and (entry.id or entry.Id) or "")
	return runtime
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
		knockbackPower = 7.5 * knockbackMult,
	}
end

local function nearestEnemy(fromPos: Vector3, maxRange: number)
	return NpcService.GetNearestEnemy(fromPos, maxRange)
end

local function getEnemiesInRadius(fromPos: Vector3, radius: number)
	return NpcService.GetEnemiesInRadius(fromPos, radius)
end

local function getSortedEnemies(fromPos: Vector3, radius: number)
	local enemies = getEnemiesInRadius(fromPos, radius)
	table.sort(enemies, function(a, b)
		local posA = NpcService.GetPosition(a)
		local posB = NpcService.GetPosition(b)
		if not posA or not posB then
			return tostring(a) < tostring(b)
		end
		return (posA - fromPos).Magnitude < (posB - fromPos).Magnitude
	end)
	return enemies
end

local function healPlayer(plr: Player, amount: number)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and amount > 0 then
		hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
	end
end

local function dotKey(plr: Player, enemyModel: Model, effectName: string): string
	local npcId = tostring(enemyModel:GetAttribute("NpcId") or enemyModel.Name)
	return string.format("%d:%s:%s", plr.UserId, npcId, effectName)
end

local function applyBleed(plr: Player, enemyModel: Model, stats, runtime)
	local dpsMultiplier = tonumber(runtime.bleedDpsMultiplier) or 0
	local duration = tonumber(runtime.bleedDuration) or 0
	if dpsMultiplier <= 0 or duration <= 0 then
		return
	end

	local maxStacks = math.max(1, math.floor(tonumber(runtime.bleedMaxStacks) or 1))
	local key = dotKey(plr, enemyModel, "Bleed")
	local entry = DOT_STATES[key]
	if not entry then
		entry = {
			player = plr,
			enemy = enemyModel,
			stacks = 0,
			dps = 0,
			expiresAt = 0,
		}
		DOT_STATES[key] = entry
		task.spawn(function()
			while DOT_STATES[key] == entry do
				if not isCombatPlayerActive(entry.player) or not NpcService.IsAlive(entry.enemy) then
					break
				end
				if time() >= (entry.expiresAt or 0) then
					break
				end
				if PauseState.Value then
					task.wait(0.1)
					continue
				end

				local tickDamage = (entry.dps or 0) * math.max(1, entry.stacks or 1) * DOT_TICK
				if isBossEnemy(entry.enemy) then
					tickDamage *= 0.7
				elseif isEliteEnemy(entry.enemy) then
					tickDamage *= 0.85
				end
				if tickDamage > 0 then
					NpcService.ApplyDamage(entry.enemy, tickDamage, {
						player = entry.player,
						showFloating = false,
					})
				end
				task.wait(DOT_TICK)
			end
			DOT_STATES[key] = nil
		end)
	end

	entry.stacks = math.min(maxStacks, (entry.stacks or 0) + 1)
	entry.dps = stats.baseDamage * dpsMultiplier
	entry.expiresAt = time() + duration
end

local function buildCleaveTargets(primaryEnemy: Model, centerPos: Vector3, maxTargets: number, radius: number, falloff: number)
	local results = {
		{ model = primaryEnemy, damageMultiplier = 1 },
	}
	for _, enemyModel in ipairs(getSortedEnemies(centerPos, radius)) do
		if enemyModel ~= primaryEnemy then
			table.insert(results, {
				model = enemyModel,
				damageMultiplier = falloff,
			})
			if #results >= maxTargets then
				break
			end
		end
	end
	return results
end

local function buildLineTargets(originPos: Vector3, targetPos: Vector3, runtime)
	local direction = targetPos - originPos
	if direction.Magnitude <= 0.05 then
		return {}
	end
	direction = direction.Unit

	local range = tonumber(runtime.range) or 12
	local width = tonumber(runtime.lineWidth) or 3
	local maxTargets = math.max(1, math.floor(tonumber(runtime.pierceTargets) or 1))
	local beamEnd = originPos + (direction * range)
	local candidates = {}

	for _, enemyModel in ipairs(getEnemiesInRadius(originPos, range + width + 2)) do
		local enemyPos = NpcService.GetPosition(enemyModel)
		if enemyPos and distancePointToSegment(enemyPos, originPos, beamEnd) <= width then
			local progress = (enemyPos - originPos):Dot(direction)
			if progress >= -1 and progress <= (range + 1) then
				table.insert(candidates, {
					model = enemyModel,
					progress = progress,
				})
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.progress < b.progress
	end)

	local results = {}
	for index, candidate in ipairs(candidates) do
		if index > maxTargets then
			break
		end
		results[#results + 1] = {
			model = candidate.model,
			damageMultiplier = 1,
		}
	end
	return results
end

local function addUniqueResult(results, seen, enemyModel: Model, damageMultiplier: number)
	if seen[enemyModel] then
		return
	end
	seen[enemyModel] = true
	results[#results + 1] = {
		model = enemyModel,
		damageMultiplier = damageMultiplier,
	}
end

local function buildAttackTargets(originPos: Vector3, primaryEnemy: Model, primaryPos: Vector3, runtime)
	local seen = {}
	local results = {}

	if runtime.weaponType == "Sword" then
		for _, hit in ipairs(buildCleaveTargets(
			primaryEnemy,
			primaryPos,
			math.max(1, math.floor(tonumber(runtime.cleaveTargets) or 1)),
			tonumber(runtime.cleaveRadius) or 6,
			tonumber(runtime.cleaveFalloff) or 0.55
		)) do
			addUniqueResult(results, seen, hit.model, hit.damageMultiplier)
		end
	elseif runtime.weaponType == "Scythe" then
		for _, hit in ipairs(buildCleaveTargets(
			primaryEnemy,
			primaryPos,
			math.max(1, math.floor(tonumber(runtime.aoeMaxTargets) or 1)),
			tonumber(runtime.aoeRadius) or 7,
			tonumber(runtime.aoeFalloff) or 0.74
		)) do
			addUniqueResult(results, seen, hit.model, hit.damageMultiplier)
		end
	elseif runtime.weaponType == "Halberd" then
		for _, hit in ipairs(buildLineTargets(originPos, primaryPos, runtime)) do
			addUniqueResult(results, seen, hit.model, hit.damageMultiplier)
		end
	else
		addUniqueResult(results, seen, primaryEnemy, 1)
	end

	return results
end

local function getNearbyExtraTargets(centerPos: Vector3, radius: number, count: number, hitSet)
	local results = {}
	for _, enemyModel in ipairs(getSortedEnemies(centerPos, radius)) do
		if not hitSet[enemyModel] then
			results[#results + 1] = enemyModel
			if #results >= count then
				break
			end
		end
	end
	return results
end

local function startLoop(plr: Player)
	if loops[plr] then
		loops[plr].alive = false
	end
	local state = {
		alive = true,
		attackIndex = 0,
		lastAttackAt = 0,
		killChainStacks = 0,
		killChainExpireAt = 0,
	}
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
			if not hrp or not hum or hum.Health <= 0 then
				continue
			end

			local entry = getLoadoutEntry(plr)
			if not entry then
				continue
			end

			local runtime = getWeaponRuntime(entry)
			local stats = calcAttackStats(plr, entry)
			local cd = (tonumber(runtime.attackCooldown) or 0.7) / stats.attackSpeedMult
			local range = tonumber(runtime.range) or 10

			local now = time()
			if state.killChainExpireAt > 0 and now >= state.killChainExpireAt then
				state.killChainStacks = 0
				state.killChainExpireAt = 0
			end

			if (now - last) < cd then
				continue
			end

			local primaryEnemy = nearestEnemy(hrp.Position, range)
			if not primaryEnemy or not NpcService.IsAlive(primaryEnemy) then
				continue
			end

			local primaryPos = NpcService.GetPosition(primaryEnemy)
			if not primaryPos then
				continue
			end

			last = now
			state.lastAttackAt = now
			state.attackIndex += 1

			if stats.baseDamage <= 0 then
				continue
			end

			local attackTargets = buildAttackTargets(hrp.Position, primaryEnemy, primaryPos, runtime)
			local totalHeal = 0
			local hitSet = {}
			local primaryApplied = 0

			local attackBonus = 1
			if runtime.focusEvery and state.attackIndex % math.max(1, math.floor(runtime.focusEvery)) == 0 then
				attackBonus *= tonumber(runtime.focusMultiplier) or 1.2
			end
			if runtime.executionEvery and state.attackIndex % math.max(1, math.floor(runtime.executionEvery)) == 0 then
				attackBonus *= tonumber(runtime.executionBonusMultiplier) or 1.2
			end
			if state.killChainStacks > 0 then
				attackBonus *= 1 + (state.killChainStacks * (tonumber(runtime.killChainPerKill) or 0))
			end

			local function dealDamage(enemyModel: Model, damageMultiplier: number, options)
				local allowRepeat = options and options.allowRepeat == true
				if (hitSet[enemyModel] and not allowRepeat) or not NpcService.IsAlive(enemyModel) then
					return 0
				end
				if not allowRepeat then
					hitSet[enemyModel] = true
				end

				local enemyPos = NpcService.GetPosition(enemyModel)
				local isCrit = math.random() < stats.critChance
				if options and options.alwaysCrit then
					isCrit = true
				end

				local dealt = stats.baseDamage * damageMultiplier
				if options and options.attackBonus then
					dealt *= options.attackBonus
				end
				if isCrit then
					dealt *= stats.critMult
				end
				if isEliteEnemy(enemyModel) then
					dealt *= stats.eliteMult * (1 + math.max(0, tonumber(runtime.eliteDamageBonus) or 0))
				end
				if runtime.executeThreshold and getHealthRatio(enemyModel) <= tonumber(runtime.executeThreshold) then
					dealt *= tonumber(runtime.executeThresholdMultiplier) or 1.1
				end

				dealt = math.max(1, math.floor(dealt + 0.5))

				local applied = NpcService.ApplyDamage(enemyModel, dealt, {
					player = plr,
					crit = isCrit,
				})

				if applied > 0 then
					if enemyPos and stats.knockbackPower > 0 then
						local dir = enemyPos - hrp.Position
						if dir.Magnitude > 0.1 then
							NpcService.AddImpulse(enemyModel, dir.Unit * stats.knockbackPower)
						end
					end
					if stats.lifesteal > 0 then
						totalHeal += applied * stats.lifesteal
					end
					if tonumber(runtime.bleedDpsMultiplier) and tonumber(runtime.bleedDpsMultiplier) > 0 then
						applyBleed(plr, enemyModel, stats, runtime)
					end

					local enemyDied = not NpcService.IsAlive(enemyModel)
					if enemyDied then
						local healOnKillPct = tonumber(runtime.healOnKillPct) or 0
						if healOnKillPct > 0 then
							totalHeal += hum.MaxHealth * healOnKillPct
						end
						local killChainPerKill = tonumber(runtime.killChainPerKill) or 0
						if killChainPerKill > 0 then
							state.killChainStacks = math.min(
								math.max(1, math.floor(tonumber(runtime.killChainMaxStacks) or 1)),
								state.killChainStacks + 1
							)
							state.killChainExpireAt = now + math.max(1, tonumber(runtime.killChainDuration) or 4)
						end
					end
				end

				return applied
			end

			for index, hit in ipairs(attackTargets) do
				local applied = dealDamage(hit.model, hit.damageMultiplier or 1, {
					attackBonus = index == 1 and attackBonus or 1,
					alwaysCrit = index == 1 and runtime.executionAlwaysCrit == true and runtime.executionEvery and state.attackIndex % math.max(1, math.floor(runtime.executionEvery)) == 0,
				})
				if index == 1 then
					primaryApplied = applied
				end
			end

			if runtime.shockwaveEvery and state.attackIndex % math.max(1, math.floor(runtime.shockwaveEvery)) == 0 then
				for _, extraEnemy in ipairs(getNearbyExtraTargets(
					primaryPos,
					tonumber(runtime.shockwaveRadius) or 8,
					math.max(1, math.floor(tonumber(runtime.shockwaveMaxTargets) or 6)),
					hitSet
				)) do
					dealDamage(extraEnemy, tonumber(runtime.shockwaveMultiplier) or 1.1, nil)
				end
			end

			if primaryApplied > 0 and runtime.splitChance and math.random() < tonumber(runtime.splitChance) then
				for _, extraEnemy in ipairs(getNearbyExtraTargets(
					primaryPos,
					tonumber(runtime.splitRadius) or 14,
					math.max(1, math.floor(tonumber(runtime.splitCount) or 1)),
					hitSet
				)) do
					dealDamage(extraEnemy, tonumber(runtime.splitDamageMultiplier) or 0.45, nil)
				end
			end

			if primaryApplied > 0 and runtime.arcChargeEvery and state.attackIndex % math.max(1, math.floor(runtime.arcChargeEvery)) == 0 then
				dealDamage(primaryEnemy, tonumber(runtime.arcChargeMultiplier) or 0.55, {
					attackBonus = 1,
					allowRepeat = true,
				})
				for _, extraEnemy in ipairs(getNearbyExtraTargets(
					primaryPos,
					tonumber(runtime.arcChainRadius) or 15,
					math.max(0, math.floor(tonumber(runtime.arcChainCount) or 0)),
					hitSet
				)) do
					dealDamage(extraEnemy, tonumber(runtime.arcChainMultiplier) or 0.30, nil)
				end
			end

			if totalHeal > 0 then
				healPlayer(plr, totalHeal)
			end

			local weaponId = entry.id or entry.Id or ""
			VFXEvent:FireAllClients({
				weaponId = weaponId,
				pos = primaryPos,
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
