local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PlayerStateStore = require(script.Parent:WaitForChild("PlayerStateStore"))
local CurrencyService = require(script.Parent:WaitForChild("CurrencyService"))

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local CraftingConfig = require(moduleFolder:WaitForChild("CraftingConfig"))
local WeaponConfigs = require(moduleFolder:WaitForChild("WeaponConfigs"))

local CraftingService = {}

local function clampInt(value, minValue)
	value = math.floor(tonumber(value) or 0)
	if minValue ~= nil and value < minValue then
		return minValue
	end
	return value
end

local function copyCountMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = clampInt(value, 0)
			if amount > 0 then
				out[key] = amount
			end
		end
	end
	return out
end

local function copyRequirementList(list)
	local out = {}
	for _, entry in ipairs(list or {}) do
		local amount = clampInt(entry.amount, 0)
		if typeof(entry.id) == "string" and entry.id ~= "" and amount > 0 then
			table.insert(out, {
				id = entry.id,
				amount = amount,
			})
		end
	end
	return out
end

local function requirementListToMap(list)
	local out = {}
	for _, entry in ipairs(list or {}) do
		if typeof(entry.id) == "string" and entry.id ~= "" then
			local amount = clampInt(entry.amount, 0)
			if amount > 0 then
				out[entry.id] = amount
			end
		end
	end
	return out
end

local function toPct(value)
	return math.floor((tonumber(value) or 0) * 100 + 0.5)
end

local RARITY_RANK = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythical = 5,
}

local function getPlayerProgress(player)
	local data = PlayerData.Get(player)
	data.crafting = data.crafting or {}
	data.crafting.recipes = data.crafting.recipes or {}
	data.crafting.mineResources = data.crafting.mineResources or {}
	data.crafting.mobMaterials = data.crafting.mobMaterials or {}
	data.crafting.upgradeMaterials = data.crafting.upgradeMaterials or {}
	return data, data.crafting
end

local function markPlayerDataDirty(player)
	if PlayerData.MarkDirty then
		PlayerData.MarkDirty(player)
	end
end

local function markWeaponStateDirty(player, reason)
	if PlayerStateStore.MarkDirty then
		PlayerStateStore.MarkDirty(player, reason or "crafting")
	elseif PlayerStateStore.Save then
		PlayerStateStore.Save(player, true)
	end
end

local function composeDisplayName(inst, def)
	local prefix = tostring(inst.prefix or "")
	local baseName = (def and def.name) or tostring(inst.weaponId or "Unknown")
	if prefix == "" or prefix == "Standard" then
		return baseName
	end
	return string.format("%s %s", prefix, baseName)
end

local function computeInstanceStats(def, inst)
	local combat = def.combat or {}
	local roll = (typeof(inst.rollStats) == "table") and inst.rollStats or {}
	local level = math.max(1, clampInt(inst.level, 1))

	local baseAtk = (combat.baseAtk or def.baseDamage or 0) + (roll.BaseATK or 0)
	local atkPerLevel = (combat.atkPerLevel or 0) + (roll.ATKPerLevel or 0)
	local atk = baseAtk + (level - 1) * atkPerLevel

	local hp = (combat.bonusHP or 0) + (roll.BonusHP or 0)
	local defValue = (combat.bonusDefense or 0) + (roll.BonusDefense or 0)
	local speed = (combat.bonusSpeed or 0) + (roll.BonusSpeed or 0)
	local critRate = (combat.bonusCritRate or 0) + (roll.BonusCritRate or 0)
	local critDmg = (combat.bonusCritDmg or 0) + (roll.BonusCritDmg or 0)
	local lifesteal = (combat.bonusLifesteal or 0) + (roll.BonusLifesteal or 0)

	return {
		ATK = math.floor(atk + 0.5),
		HP = math.floor(hp + 0.5),
		DEF = math.floor(defValue + 0.5),
		SPD = toPct(speed),
		CRIT_RATE = toPct(critRate),
		CRIT_DMG = toPct(critDmg),
		LIFESTEAL = toPct(lifesteal),
	}
end

local function buildRollStats(def, multiplier)
	local combat = def.combat or {}
	local baseAtk = combat.baseAtk or def.baseDamage or 0
	local atkPerLevel = combat.atkPerLevel or 0

	local function diff(value)
		return (value * multiplier) - value
	end

	return {
		BaseATK = diff(baseAtk),
		ATKPerLevel = diff(atkPerLevel),
		BonusHP = diff(combat.bonusHP or 0),
		BonusSpeed = diff(combat.bonusSpeed or 0),
		BonusCritRate = diff(combat.bonusCritRate or 0),
		BonusCritDmg = diff(combat.bonusCritDmg or 0),
		BonusLifesteal = diff(combat.bonusLifesteal or 0),
		BonusDefense = diff(combat.bonusDefense or 0),
	}
end

local function getResourceDisplayOrder(resourceMap, orderIds)
	local out = {}
	local seen = {}

	for _, resourceId in ipairs(orderIds or {}) do
		local amount = clampInt(resourceMap[resourceId], 0)
		if amount > 0 then
			seen[resourceId] = true
			table.insert(out, {
				id = resourceId,
				amount = amount,
			})
		end
	end

	for resourceId, amount in pairs(resourceMap or {}) do
		if not seen[resourceId] then
			local cleanAmount = clampInt(amount, 0)
			if cleanAmount > 0 then
				table.insert(out, {
					id = resourceId,
					amount = cleanAmount,
				})
			end
		end
	end
	return out
end

local function getMineResourceOrder()
	local out = {}
	for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS or {}) do
		table.insert(out, def.id)
	end
	return out
end

local function getMobResourceOrder()
	local out = {}
	for _, def in ipairs(CraftingConfig.MOB_MATERIAL_DEFS or {}) do
		table.insert(out, def.id)
	end
	return out
end

local function getUpgradeResourceOrder()
	return {
		CraftingConfig.UPGRADE_CRYSTAL_ID,
		CraftingConfig.ELITE_SPECIAL_ID,
		CraftingConfig.BOSS_SPECIAL_ID,
	}
end

local function getRecipeState(progress, recipeId)
	local state = progress.recipes[recipeId]
	if typeof(state) ~= "table" then
		return nil
	end

	state.found = state.found == true
	state.copies = math.max(0, clampInt(state.copies, 0))
	state.tier = math.max(1, clampInt(state.tier, 1))
	state.unlocked = state.unlocked == true
	state.lastFoundAt = clampInt(state.lastFoundAt, 0)
	if state.found and state.copies <= 0 then
		state.copies = 1
	end
	return state
end

local function getOrCreateRecipeState(progress, recipeId)
	local state = getRecipeState(progress, recipeId)
	if state then
		return state
	end

	state = {
		found = true,
		copies = 1,
		tier = 1,
		unlocked = false,
		lastFoundAt = os.time(),
	}
	progress.recipes[recipeId] = state
	return state
end

local function addCount(resourceMap, resourceId, amount)
	if typeof(resourceId) ~= "string" or resourceId == "" then
		return
	end
	amount = clampInt(amount, 0)
	if amount <= 0 then
		return
	end
	resourceMap[resourceId] = clampInt(resourceMap[resourceId], 0) + amount
end

local function spendCount(resourceMap, resourceId, amount)
	amount = clampInt(amount, 0)
	if amount <= 0 then
		return true
	end
	local current = clampInt(resourceMap[resourceId], 0)
	if current < amount then
		return false
	end
	current -= amount
	if current > 0 then
		resourceMap[resourceId] = current
	else
		resourceMap[resourceId] = nil
	end
	return true
end

local function hasAllRequirements(resourceMap, list)
	for _, entry in ipairs(list or {}) do
		if clampInt(resourceMap[entry.id], 0) < clampInt(entry.amount, 0) then
			return false
		end
	end
	return true
end

local function spendRequirementList(resourceMap, list)
	for _, entry in ipairs(list or {}) do
		if not spendCount(resourceMap, entry.id, entry.amount) then
			return false
		end
	end
	return true
end

local function normalizePriorityList(priority)
	local valid = {}
	local seen = {}
	local fallback = CraftingConfig.GetDefaultMinePriority()

	if typeof(priority) == "table" then
		for _, resourceId in ipairs(priority) do
			if typeof(resourceId) == "string" and resourceId ~= "" and CraftingConfig.GetMineResource(resourceId) and not seen[resourceId] then
				seen[resourceId] = true
				table.insert(valid, resourceId)
			end
		end
	end

	for _, resourceId in ipairs(fallback) do
		if not seen[resourceId] then
			seen[resourceId] = true
			table.insert(valid, resourceId)
		end
	end

	return valid
end

local function getPriorityMultiplier(priority, resourceId)
	for index, id in ipairs(priority or {}) do
		if id == resourceId then
			local bonus = 3.0 - ((index - 1) * 0.35)
			return math.max(1.0, bonus)
		end
	end
	return 1.0
end

local function rollMiningYield(userId, startedAt, durationSec, priority)
	local rolls = math.max(0, math.floor(clampInt(durationSec, 0) / 60))
	local seed = clampInt(userId, 0) + clampInt(startedAt, 0) + rolls
	local rng = Random.new(seed)
	local counts = {}

	for _ = 1, rolls do
		local totalWeight = 0
		for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS or {}) do
			totalWeight += (tonumber(def.weight) or 0) * getPriorityMultiplier(priority, def.id)
		end
		if totalWeight <= 0 then
			break
		end

		local pick = rng:NextNumber(0, totalWeight)
		local acc = 0
		for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS or {}) do
			acc += (tonumber(def.weight) or 0) * getPriorityMultiplier(priority, def.id)
			if pick <= acc then
				local minYield = clampInt(def.yieldMin, 1)
				local maxYield = math.max(minYield, clampInt(def.yieldMax, minYield))
				addCount(counts, def.id, rng:NextInteger(minYield, maxYield))
				break
			end
		end
	end

	return counts
end

local function finalizeCompletedMining(player, nowTimestamp)
	local _, progress = getPlayerProgress(player)
	local session = progress.miningSession
	if typeof(session) ~= "table" then
		return nil
	end

	local now = clampInt(nowTimestamp or os.time(), 0)
	if now < clampInt(session.endsAt, 0) then
		return nil
	end

	local priority = normalizePriorityList(session.priority)
	local yieldMap = rollMiningYield(player.UserId, session.startedAt, session.durationSec, priority)
	for resourceId, amount in pairs(yieldMap) do
		addCount(progress.mineResources, resourceId, amount)
	end
	progress.miningSession = nil
	markPlayerDataDirty(player)
	return yieldMap
end

local function buildMiningSessionSnapshot(player)
	local _, progress = getPlayerProgress(player)
	local autoClaimed = finalizeCompletedMining(player, os.time())
	local session = progress.miningSession
	if typeof(session) ~= "table" then
		return {
			active = false,
			priority = normalizePriorityList(nil),
			recentClaim = autoClaimed and getResourceDisplayOrder(autoClaimed, getMineResourceOrder()) or nil,
		}
	end

	local now = os.time()
	local elapsed = math.clamp(now - clampInt(session.startedAt, 0), 0, clampInt(session.durationSec, 0))
	return {
		active = true,
		startedAt = session.startedAt,
		endsAt = session.endsAt,
		durationSec = session.durationSec,
		elapsedSec = elapsed,
		remainingSec = math.max(0, clampInt(session.endsAt, 0) - now),
		priority = normalizePriorityList(session.priority),
		recentClaim = autoClaimed and getResourceDisplayOrder(autoClaimed, getMineResourceOrder()) or nil,
	}
end

local function countCraftedWeaponsById(instances)
	local counts = {}
	for _, inst in ipairs(instances or {}) do
		if typeof(inst) == "table" and typeof(inst.weaponId) == "string" and inst.weaponId ~= "" then
			counts[inst.weaponId] = clampInt(counts[inst.weaponId], 0) + 1
		end
	end
	return counts
end

local function getSellPreview(inst, def)
	local craftCosts = typeof(inst.craftCosts) == "table" and inst.craftCosts or nil
	local mineRefunds = {}
	local mobRefunds = {}

	if craftCosts then
		local mineMap = copyCountMap(craftCosts.mineResources)
		local mobMap = copyCountMap(craftCosts.mobMaterials)
		for resourceId, amount in pairs(mineMap) do
			local refund = math.floor(amount * CraftingConfig.SELL_REFUND_RATIO)
			if refund > 0 then
				mineRefunds[resourceId] = refund
			end
		end
		for resourceId, amount in pairs(mobMap) do
			local refund = math.floor(amount * CraftingConfig.SELL_REFUND_RATIO)
			if refund > 0 then
				mobRefunds[resourceId] = refund
			end
		end
	end

	local baseSilver = 0
	if craftCosts and craftCosts.silver then
		baseSilver = math.floor((tonumber(craftCosts.silver) or 0) * CraftingConfig.SELL_REFUND_RATIO)
	end
	local upgradeSilver = math.floor((tonumber(inst.upgradeSilverSpent) or 0) * CraftingConfig.SELL_UPGRADE_SILVER_RATIO)

	if baseSilver <= 0 and upgradeSilver <= 0 then
		local rarity = (inst.rarity ~= "" and inst.rarity) or def.rarity or "Common"
		local multiplier = ({
			Common = 1.0,
			Rare = 1.4,
			Epic = 1.9,
			Legendary = 2.6,
			Mythical = 3.3,
		})[rarity] or 1.0
		baseSilver = math.max(1, math.floor((tonumber(def.baseDamage) or 1) * 6 * multiplier))
	end

	return {
		silver = math.max(1, baseSilver + upgradeSilver),
		mineResources = mineRefunds,
		mobMaterials = mobRefunds,
	}
end

function CraftingService.AddRecipeDiscovery(player, recipeId)
	local recipe = CraftingConfig.GetRecipe(recipeId)
	if not recipe then
		return false, "UnknownRecipe"
	end

	local _, progress = getPlayerProgress(player)
	local state = getRecipeState(progress, recipeId)
	if not state then
		state = getOrCreateRecipeState(progress, recipeId)
	else
		state.found = true
		state.copies = math.max(1, clampInt(state.copies, 0)) + 1
	end
	state.lastFoundAt = os.time()
	state.tier = CraftingConfig.GetRecipeTierFromCopies(state.copies)
	markPlayerDataDirty(player)
	return true, state
end

function CraftingService.AddMobMaterial(player, materialId, amount)
	local _, progress = getPlayerProgress(player)
	addCount(progress.mobMaterials, materialId, amount)
	markPlayerDataDirty(player)
end

function CraftingService.AddUpgradeMaterial(player, materialId, amount)
	local _, progress = getPlayerProgress(player)
	addCount(progress.upgradeMaterials, materialId, amount)
	markPlayerDataDirty(player)
end

function CraftingService.AddMineResources(player, resourceMap)
	local _, progress = getPlayerProgress(player)
	for resourceId, amount in pairs(resourceMap or {}) do
		addCount(progress.mineResources, resourceId, amount)
	end
	markPlayerDataDirty(player)
end

function CraftingService.StartMining(player, durationSec, priority)
	local _, progress = getPlayerProgress(player)
	finalizeCompletedMining(player, os.time())

	if typeof(progress.miningSession) == "table" then
		return false, "MiningActive"
	end

	local validDuration = nil
	durationSec = clampInt(durationSec, 0)
	for _, option in ipairs(CraftingConfig.MINE_DURATION_OPTIONS or {}) do
		if option == durationSec then
			validDuration = option
			break
		end
	end
	if not validDuration then
		return false, "BadDuration"
	end

	local now = os.time()
	progress.miningSession = {
		startedAt = now,
		endsAt = now + validDuration,
		durationSec = validDuration,
		priority = normalizePriorityList(priority),
	}
	markPlayerDataDirty(player)
	return true, buildMiningSessionSnapshot(player)
end

function CraftingService.StopMining(player)
	local _, progress = getPlayerProgress(player)
	local session = progress.miningSession
	if typeof(session) ~= "table" then
		return false, "NoMiningSession"
	end

	local now = os.time()
	local elapsed = math.clamp(now - clampInt(session.startedAt, 0), 0, clampInt(session.durationSec, 0))
	local yieldMap = rollMiningYield(player.UserId, session.startedAt, elapsed, normalizePriorityList(session.priority))
	for resourceId, amount in pairs(yieldMap) do
		addCount(progress.mineResources, resourceId, amount)
	end
	progress.miningSession = nil
	markPlayerDataDirty(player)
	return true, {
		yield = getResourceDisplayOrder(yieldMap, getMineResourceOrder()),
	}
end

function CraftingService.GetMiningSnapshot(player)
	local _, progress = getPlayerProgress(player)
	return {
		silver = CurrencyService.GetSilver(player),
		mineResources = getResourceDisplayOrder(progress.mineResources, getMineResourceOrder()),
		session = buildMiningSessionSnapshot(player),
		durationOptions = CraftingConfig.MINE_DURATION_OPTIONS,
		defaultPriority = normalizePriorityList(nil),
	}
end

function CraftingService.UnlockRecipe(player, recipeId)
	local recipe = CraftingConfig.GetRecipe(recipeId)
	if not recipe then
		return false, "UnknownRecipe"
	end

	local data, progress = getPlayerProgress(player)
	local state = getRecipeState(progress, recipeId)
	if not state or not state.found then
		return false, "RecipeHidden"
	end
	state.tier = CraftingConfig.GetRecipeTierFromCopies(state.copies)
	if state.unlocked then
		return false, "AlreadyUnlocked"
	end
	if clampInt(data.level, 1) < clampInt(recipe.requiredLevel, 1) then
		return false, "LevelLocked"
	end

	local requirements = CraftingConfig.BuildRecipeRequirements(recipeId, state.tier)
	local unlockCost = requirements and clampInt(requirements.unlockSilverCost, 0) or 0
	if not CurrencyService.RemoveCurrency(player, "Silver", unlockCost) then
		return false, "NotEnoughSilver"
	end

	state.unlocked = true
	markPlayerDataDirty(player)
	return true, state
end

function CraftingService.CraftRecipe(player, recipeId)
	local recipe = CraftingConfig.GetRecipe(recipeId)
	if not recipe then
		return false, "UnknownRecipe"
	end

	local data, progress = getPlayerProgress(player)
	local state = getRecipeState(progress, recipeId)
	if not state or not state.found then
		return false, "RecipeHidden"
	end
	state.tier = CraftingConfig.GetRecipeTierFromCopies(state.copies)
	if not state.unlocked then
		return false, "RecipeLocked"
	end
	if clampInt(data.level, 1) < clampInt(recipe.requiredLevel, 1) then
		return false, "LevelLocked"
	end

	local requirements = CraftingConfig.BuildRecipeRequirements(recipeId, state.tier)
	if not requirements then
		return false, "BadRecipeConfig"
	end
	if not hasAllRequirements(progress.mineResources, requirements.mineResources) then
		return false, "MissingMineResources"
	end
	if not hasAllRequirements(progress.mobMaterials, requirements.mobMaterials) then
		return false, "MissingMobMaterials"
	end
	if not CurrencyService.RemoveCurrency(player, "Silver", requirements.craftSilverCost) then
		return false, "NotEnoughSilver"
	end

	spendRequirementList(progress.mineResources, requirements.mineResources)
	spendRequirementList(progress.mobMaterials, requirements.mobMaterials)
	markPlayerDataDirty(player)

	local def = WeaponConfigs.Get(recipe.weaponId)
	if not def then
		CurrencyService.AddSilver(player, requirements.craftSilverCost)
		return false, "MissingWeaponDef"
	end

	local tier = math.max(1, clampInt(state.tier, 1))
	local prefix = CraftingConfig.GetRecipeTierPrefix(tier)
	local rollStats = buildRollStats(def, CraftingConfig.GetRecipeTierStatBonus(tier))
	local created = PlayerStateStore.AddWeaponInstance(player, recipe.weaponId, def.rarity, 1, prefix, rollStats)
	if not created then
		CurrencyService.AddSilver(player, requirements.craftSilverCost)
		return false, "CreateFailed"
	end

	created.recipeId = recipeId
	created.recipeTier = tier
	created.craftCosts = {
		silver = requirements.craftSilverCost,
		mineResources = requirementListToMap(requirements.mineResources),
		mobMaterials = requirementListToMap(requirements.mobMaterials),
	}
	created.upgradeSilverSpent = clampInt(created.upgradeSilverSpent, 0)
	created.upgradeMaterialsSpent = copyCountMap(created.upgradeMaterialsSpent)
	markWeaponStateDirty(player, "weapon_crafted")

	return true, created
end

function CraftingService.TryUpgradeWeapon(player, instanceId, steps)
	if not PlayerStateStore.Get(player) then
		PlayerStateStore.Load(player)
	end
	local _, progress = getPlayerProgress(player)
	local inst = PlayerStateStore.GetWeaponInstance(player, instanceId)
	if not inst then
		return false, "UnknownInstance"
	end

	local def = WeaponConfigs.Get(inst.weaponId)
	if not def then
		return false, "MissingWeaponDef"
	end

	local rarity = (inst.rarity ~= "" and inst.rarity) or def.rarity or "Common"
	local maxLevel = math.max(1, clampInt(def.maxLevel, 1))
	steps = math.clamp(clampInt(steps, 1), 1, 10)

	local upgraded = 0
	for _ = 1, steps do
		local level = math.max(1, clampInt(inst.level, 1))
		if level >= maxLevel then
			break
		end

		local cost = CraftingConfig.GetUpgradeCost(rarity, level, maxLevel)
		if not CurrencyService.RemoveCurrency(player, "Silver", cost.silver) then
			break
		end
		if not spendCount(progress.upgradeMaterials, CraftingConfig.UPGRADE_CRYSTAL_ID, cost.crystals) then
			CurrencyService.AddSilver(player, cost.silver)
			break
		end
		if cost.special and not spendCount(progress.upgradeMaterials, cost.special.id, cost.special.amount) then
			CurrencyService.AddSilver(player, cost.silver)
			addCount(progress.upgradeMaterials, CraftingConfig.UPGRADE_CRYSTAL_ID, cost.crystals)
			break
		end

		inst.level = level + 1
		inst.upgradeSilverSpent = clampInt(inst.upgradeSilverSpent, 0) + cost.silver
		inst.upgradeMaterialsSpent = copyCountMap(inst.upgradeMaterialsSpent)
		addCount(inst.upgradeMaterialsSpent, CraftingConfig.UPGRADE_CRYSTAL_ID, cost.crystals)
		if cost.special then
			addCount(inst.upgradeMaterialsSpent, cost.special.id, cost.special.amount)
		end
		upgraded += 1
	end

	if upgraded > 0 then
		markPlayerDataDirty(player)
		markWeaponStateDirty(player, "weapon_upgrade")
	end

	return upgraded > 0, upgraded
end

function CraftingService.SellWeaponInstance(player, instanceId)
	local inst = PlayerStateStore.GetWeaponInstance(player, instanceId)
	if not inst then
		return false, "UnknownInstance"
	end

	local def = WeaponConfigs.Get(inst.weaponId)
	if not def then
		return false, "MissingWeaponDef"
	end

	local preview = getSellPreview(inst, def)
	local removed = PlayerStateStore.RemoveWeaponInstance(player, instanceId)
	if not removed then
		return false, "RemoveFailed"
	end

	CurrencyService.AddSilver(player, preview.silver)

	local _, progress = getPlayerProgress(player)
	for resourceId, amount in pairs(preview.mineResources) do
		addCount(progress.mineResources, resourceId, amount)
	end
	for resourceId, amount in pairs(preview.mobMaterials) do
		addCount(progress.mobMaterials, resourceId, amount)
	end
	markPlayerDataDirty(player)
	markWeaponStateDirty(player, "weapon_sell")
	return true, preview
end

function CraftingService.BuildBlacksmithSnapshot(player)
	finalizeCompletedMining(player, os.time())
	local data, progress = getPlayerProgress(player)
	local balances = CurrencyService.GetBalances(player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	local instances = state.WeaponInstances or {}
	local craftedCounts = countCraftedWeaponsById(instances)

	local craftEntries = {}
	for recipeId, recipeState in pairs(progress.recipes or {}) do
		local recipe = CraftingConfig.GetRecipe(recipeId)
		local stateEntry = getRecipeState(progress, recipeId)
		if recipe and stateEntry and stateEntry.found then
			local tier = CraftingConfig.GetRecipeTierFromCopies(stateEntry.copies)
			stateEntry.tier = tier
			local requirements = CraftingConfig.BuildRecipeRequirements(recipeId, tier)
			local craftedCount = clampInt(craftedCounts[recipe.weaponId], 0)
			local hasMine = hasAllRequirements(progress.mineResources, requirements.mineResources)
			local hasMob = hasAllRequirements(progress.mobMaterials, requirements.mobMaterials)
			local levelOk = clampInt(data.level, 1) >= clampInt(recipe.requiredLevel, 1)
			local silverForCraft = clampInt(balances.Silver, 0) >= clampInt(requirements.craftSilverCost, 0)
			local silverForUnlock = clampInt(balances.Silver, 0) >= clampInt(requirements.unlockSilverCost, 0)
			local canCraft = stateEntry.unlocked and levelOk and hasMine and hasMob and silverForCraft
			local status = "Found"
			if craftedCount > 0 then
				status = "Crafted"
			elseif canCraft then
				status = "Craftable"
			elseif stateEntry.unlocked then
				status = "Unlocked"
			end

			table.insert(craftEntries, {
				recipeId = recipeId,
				weaponId = recipe.weaponId,
				name = recipe.weaponId,
				rarity = recipe.rarity,
				requiredLevel = recipe.requiredLevel,
				status = status,
				copies = stateEntry.copies,
				tier = tier,
				nextTierCopies = CraftingConfig.GetNextTierCopyTarget(tier),
				unlocked = stateEntry.unlocked,
				craftedCount = craftedCount,
				unlockSilverCost = requirements.unlockSilverCost,
				craftSilverCost = requirements.craftSilverCost,
				mineResources = copyRequirementList(requirements.mineResources),
				mobMaterials = copyRequirementList(requirements.mobMaterials),
				canUnlock = (not stateEntry.unlocked) and levelOk and silverForUnlock,
				canCraft = canCraft,
				hasMineResources = hasMine,
				hasMobMaterials = hasMob,
				levelMet = levelOk,
			})
		end
	end

	table.sort(craftEntries, function(a, b)
		if a.requiredLevel ~= b.requiredLevel then
			return a.requiredLevel < b.requiredLevel
		end
		local rarityA = RARITY_RANK[a.rarity] or 0
		local rarityB = RARITY_RANK[b.rarity] or 0
		if rarityA ~= rarityB then
			return rarityA < rarityB
		end
		return tostring(a.name) < tostring(b.name)
	end)

	local upgradeEntries = {}
	local sellEntries = {}

	for _, inst in ipairs(instances) do
		local def = WeaponConfigs.Get(inst.weaponId)
		if def then
			local rarity = (inst.rarity ~= "" and inst.rarity) or def.rarity or "Common"
			local level = math.max(1, clampInt(inst.level, 1))
			local maxLevel = math.max(1, clampInt(def.maxLevel, 1))
			local stats = computeInstanceStats(def, inst)
			local displayName = composeDisplayName(inst, def)

			local upgradeRow = {
				instanceId = inst.instanceId,
				weaponId = inst.weaponId,
				name = displayName,
				rarity = rarity,
				level = level,
				maxLevel = maxLevel,
				stats = stats,
				canUpgrade = level < maxLevel,
			}
			if upgradeRow.canUpgrade then
				local upgradeCost = CraftingConfig.GetUpgradeCost(rarity, level, maxLevel)
				upgradeRow.upgradeCost = upgradeCost
				upgradeRow.canAfford = clampInt(balances.Silver, 0) >= clampInt(upgradeCost.silver, 0)
					and clampInt(progress.upgradeMaterials[CraftingConfig.UPGRADE_CRYSTAL_ID], 0) >= clampInt(upgradeCost.crystals, 0)
				if upgradeCost.special then
					upgradeRow.canAfford = upgradeRow.canAfford
						and clampInt(progress.upgradeMaterials[upgradeCost.special.id], 0) >= clampInt(upgradeCost.special.amount, 0)
				end
			end
			table.insert(upgradeEntries, upgradeRow)

			local sellPreview = getSellPreview(inst, def)
			table.insert(sellEntries, {
				instanceId = inst.instanceId,
				weaponId = inst.weaponId,
				name = displayName,
				rarity = rarity,
				level = level,
				maxLevel = maxLevel,
				silverRefund = sellPreview.silver,
				mineResources = getResourceDisplayOrder(sellPreview.mineResources, getMineResourceOrder()),
				mobMaterials = getResourceDisplayOrder(sellPreview.mobMaterials, getMobResourceOrder()),
			})
		end
	end

	table.sort(upgradeEntries, function(a, b)
		local rarityA = RARITY_RANK[a.rarity] or 0
		local rarityB = RARITY_RANK[b.rarity] or 0
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		return tostring(a.name) < tostring(b.name)
	end)
	table.sort(sellEntries, function(a, b)
		if a.silverRefund ~= b.silverRefund then
			return a.silverRefund > b.silverRefund
		end
		return tostring(a.name) < tostring(b.name)
	end)

	return {
		silver = clampInt(balances.Silver, 0),
		accountLevel = clampInt(data.level, 1),
		mineResources = getResourceDisplayOrder(progress.mineResources, getMineResourceOrder()),
		mobMaterials = getResourceDisplayOrder(progress.mobMaterials, getMobResourceOrder()),
		upgradeMaterials = getResourceDisplayOrder(progress.upgradeMaterials, getUpgradeResourceOrder()),
		craftEntries = craftEntries,
		upgradeEntries = upgradeEntries,
		sellEntries = sellEntries,
	}
end

return CraftingService
