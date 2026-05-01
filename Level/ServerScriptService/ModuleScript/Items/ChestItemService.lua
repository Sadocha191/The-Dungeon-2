local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedModules = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local StatsConfig = require(sharedModules:WaitForChild("Stats"):WaitForChild("StatsConfig"))
local ChestItemConfig = require(sharedModules:WaitForChild("Items"):WaitForChild("ChestItemConfig"))
local RunStatsService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("Stats"):WaitForChild("RunStatsService"))
local PlayerData = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PlayerData"))

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes")
local chestItemEvent = remotesFolder:FindFirstChild("ChestItemEvent")
if not chestItemEvent then
	chestItemEvent = Instance.new("RemoteEvent")
	chestItemEvent.Name = "ChestItemEvent"
	chestItemEvent.Parent = remotesFolder
end

local RunStarted = ReplicatedStorage:FindFirstChild("RunStarted") or ReplicatedStorage:WaitForChild("RunStarted")
local PauseState = ReplicatedStorage:FindFirstChild("PauseState") or ReplicatedStorage:WaitForChild("PauseState")

local ChestItemService = {}

local playerInventories = {}
local pendingRewards = {}
local acquisitionCounter = 0

local function cloneTable(source)
	local out = {}
	for key, value in pairs(source or {}) do
		out[key] = value
	end
	return out
end

local function getNumAttr(player, name, fallback)
	local value = player and player:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback or 0
end

local function setNumAttr(player, name, value)
	player:SetAttribute(name, tonumber(value) or 0)
end

local function getBaseWalkSpeed(player)
	return math.max(1, getNumAttr(player, "BaseWalkSpeed", 21))
end

local function applyLegacyBridge(player, modifiers)
	if not player or typeof(modifiers) ~= "table" then
		return
	end

	for statName, delta in pairs(modifiers) do
		local numericDelta = tonumber(delta) or 0
		if numericDelta ~= 0 then
			if statName == "Damage" then
				setNumAttr(player, "ShrineDamageMult", getNumAttr(player, "ShrineDamageMult", 1) * (1 + numericDelta))
			elseif statName == "HPRegen" then
				setNumAttr(player, "ShrineHpRegenFlat", getNumAttr(player, "ShrineHpRegenFlat", 0) + numericDelta)
			elseif statName == "CritDamage" then
				setNumAttr(player, "ShrineCritDamageBonus", getNumAttr(player, "ShrineCritDamageBonus", 0) + numericDelta)
			elseif statName == "AttackSpeed" then
				setNumAttr(player, "ShrineAttackSpeedBonus", getNumAttr(player, "ShrineAttackSpeedBonus", 0) + numericDelta)
			elseif statName == "DamageToElites" then
				setNumAttr(player, "ShrineEliteDamageBonus", getNumAttr(player, "ShrineEliteDamageBonus", 0) + numericDelta)
			elseif statName == "Knockback" then
				setNumAttr(player, "ShrineKnockbackMult", getNumAttr(player, "ShrineKnockbackMult", 1) * (1 + numericDelta))
			elseif statName == "ProjectileCount" then
				setNumAttr(player, "ShrineProjectileBonus", getNumAttr(player, "ShrineProjectileBonus", 0) + numericDelta)
			elseif statName == "Duration" then
				setNumAttr(player, "ShrineDurationBonus", getNumAttr(player, "ShrineDurationBonus", 0) + numericDelta)
			elseif statName == "MovementSpeed" then
				local addSpeed = getBaseWalkSpeed(player) * numericDelta
				setNumAttr(player, "RunBonusSpeed", getNumAttr(player, "RunBonusSpeed", 0) + addSpeed)
				setNumAttr(player, "ShrineMoveSpeedAdded", getNumAttr(player, "ShrineMoveSpeedAdded", 0) + addSpeed)
			elseif statName == "ExtraJumps" then
				setNumAttr(player, "MoveExtraJumpBonus", getNumAttr(player, "MoveExtraJumpBonus", 0) + numericDelta)
			elseif statName == "JumpHeight" then
				setNumAttr(player, "ShrineJumpHeightBonus", getNumAttr(player, "ShrineJumpHeightBonus", 0) + numericDelta)
			elseif statName == "Luck" then
				setNumAttr(player, "ShrineLuckBonus", getNumAttr(player, "ShrineLuckBonus", 0) + numericDelta)
			elseif statName == "Difficulty" then
				setNumAttr(player, "ShrineDifficultyPct", getNumAttr(player, "ShrineDifficultyPct", 0) + numericDelta)
			elseif statName == "PickupRange" then
				setNumAttr(player, "ShrinePickupRangeBonus", getNumAttr(player, "ShrinePickupRangeBonus", 0) + (numericDelta / 8))
			elseif statName == "Lifesteal" then
				setNumAttr(player, "ShrineLifestealPct", getNumAttr(player, "ShrineLifestealPct", 0) + numericDelta)
			elseif statName == "PowerupMultiplier" then
				setNumAttr(player, "ShrinePowerupMult", getNumAttr(player, "ShrinePowerupMult", 1) * (1 + numericDelta))
			end
		end
	end
end

local function getInventory(player)
	local inventory = playerInventories[player]
	if inventory then
		return inventory
	end

	inventory = {
		Entries = {},
		ById = {},
	}
	playerInventories[player] = inventory
	return inventory
end

local function buildModifierDisplay(statName, delta)
	local definition = StatsConfig.Get(statName)
	if not definition then
		return string.format("%s %+0.2f", tostring(statName), tonumber(delta) or 0)
	end

	local numericDelta = tonumber(delta) or 0
	local sign = numericDelta >= 0 and "+" or "-"
	local absDelta = math.abs(numericDelta)
	local label = definition.Label or statName

	if definition.Format == "percent" then
		return string.format("%s %s%d%%", label, sign, math.floor(absDelta * 100 + 0.5))
	end
	if definition.Format == "multiplier" then
		return string.format("%s %s%.2fx", label, sign, absDelta)
	end

	local decimals = math.max(0, math.floor(tonumber(definition.Decimals) or 0))
	return string.format("%s %s%." .. decimals .. "f", label, sign, absDelta)
end

local function buildModifierEntries(itemDefinition)
	local entries = {}
	for statName, delta in pairs(itemDefinition.Modifiers or {}) do
		entries[#entries + 1] = {
			StatName = statName,
			Delta = delta,
			Text = buildModifierDisplay(statName, delta),
		}
	end
	table.sort(entries, function(a, b)
		local orderA = table.find(StatsConfig.DisplayOrder, a.StatName) or math.huge
		local orderB = table.find(StatsConfig.DisplayOrder, b.StatName) or math.huge
		if orderA ~= orderB then
			return orderA < orderB
		end
		return tostring(a.StatName) < tostring(b.StatName)
	end)
	return entries
end

local function buildInventorySnapshot(player)
	local inventory = getInventory(player)
	local snapshot = {}

	for _, entry in ipairs(inventory.Entries) do
		local itemDefinition = ChestItemConfig.GetItem(entry.ItemId)
		if itemDefinition and (entry.ActiveStacks > 0 or entry.ConsumedCount > 0) then
			snapshot[#snapshot + 1] = {
				Id = itemDefinition.Id,
				Name = itemDefinition.Name,
				Rarity = itemDefinition.Rarity,
				Icon = itemDefinition.Icon,
				Description = itemDefinition.Description,
				MaxStacks = itemDefinition.MaxStacks,
				Stacks = entry.ActiveStacks,
				TotalStacks = entry.TotalStacks,
				ConsumedCount = entry.ConsumedCount,
				IsConsumed = entry.ActiveStacks <= 0 and entry.ConsumedCount > 0,
				AcquisitionIndex = entry.AcquisitionIndex,
			}
		end
	end

	table.sort(snapshot, function(a, b)
		if a.AcquisitionIndex ~= b.AcquisitionIndex then
			return a.AcquisitionIndex < b.AcquisitionIndex
		end
		return a.Name < b.Name
	end)

	return snapshot
end

local function syncInventory(player)
	if not player or player.Parent ~= Players then
		return
	end

	chestItemEvent:FireClient(player, {
		type = "inventorySync",
		inventory = buildInventorySnapshot(player),
	})
end

local function ensureInventoryEntry(player, itemId)
	local inventory = getInventory(player)
	local entry = inventory.ById[itemId]
	if entry then
		return entry
	end

	acquisitionCounter += 1
	entry = {
		ItemId = itemId,
		ActiveStacks = 0,
		TotalStacks = 0,
		ConsumedCount = 0,
		AcquisitionIndex = acquisitionCounter,
		SourceIds = {},
	}
	inventory.ById[itemId] = entry
	inventory.Entries[#inventory.Entries + 1] = entry
	return entry
end

local function getAvailableItemsByRarity(player)
	local available = {}
	for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
		available[rarity] = {}
		for _, itemDefinition in ipairs(ChestItemConfig.GetItemsForRarity(rarity)) do
			local entry = getInventory(player).ById[itemDefinition.Id]
			local totalStacks = entry and entry.TotalStacks or 0
			if totalStacks < itemDefinition.MaxStacks then
				available[rarity][#available[rarity] + 1] = itemDefinition
			end
		end
	end
	return available
end

local function buildAdjustedWeights(player)
	local luck = math.max(0, RunStatsService.GetStat(player, "Luck"))
	local luckTiers = luck / 0.10

	return {
		Common = ChestItemConfig.RarityWeights.Common * math.max(0.55, 1 - (0.035 * luckTiers)),
		Uncommon = ChestItemConfig.RarityWeights.Uncommon * (1 + (0.015 * luckTiers)),
		Rare = ChestItemConfig.RarityWeights.Rare * (1 + (0.05 * luckTiers)),
		Epic = ChestItemConfig.RarityWeights.Epic * (1 + (0.08 * luckTiers)),
		Legendary = ChestItemConfig.RarityWeights.Legendary * (1 + (0.12 * luckTiers)),
	}
end

local function rollWeightedRarity(player)
	local weights = buildAdjustedWeights(player)
	local total = 0
	for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
		total += math.max(0, tonumber(weights[rarity]) or 0)
	end
	if total <= 0 then
		return "Common"
	end

	local roll = math.random() * total
	local progress = 0
	for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
		progress += math.max(0, tonumber(weights[rarity]) or 0)
		if roll <= progress then
			return rarity
		end
	end
	return "Common"
end

local function resolveFallbackRarity(rarity, availableByRarity)
	local chosenIndex = table.find(ChestItemConfig.RarityOrder, rarity) or 1
	for index = chosenIndex, 1, -1 do
		local candidateRarity = ChestItemConfig.RarityOrder[index]
		if #(availableByRarity[candidateRarity] or {}) > 0 then
			return candidateRarity
		end
	end
	return nil
end

local function pickFallbackReward()
	local pool = ChestItemConfig.FallbackRewards
	return pool[math.random(1, #pool)]
end

local function buildRewardPayload(definition, token, sourceName, rewardDetail)
	local payload = {
		type = "openReward",
		token = token,
		sourceName = sourceName or "Treasure Chest",
		rewardType = rewardDetail.RewardType,
		rarity = rewardDetail.Rarity,
		color = ChestItemConfig.RarityColors[rewardDetail.Rarity],
	}

	if rewardDetail.RewardType == "Item" then
		payload.item = {
			Id = definition.Id,
			Name = definition.Name,
			Icon = definition.Icon,
			Rarity = definition.Rarity,
			Description = definition.Description,
			MaxStacks = definition.MaxStacks,
			ModifierLines = buildModifierEntries(definition),
		}
	else
		payload.fallback = {
			Id = definition.Id,
			Name = definition.Name,
			Kind = definition.Kind,
			Amount = definition.Amount,
			Description = definition.Description,
			ModifierLines = {
				{
					Text = string.format("+%d %s", definition.Amount, definition.Kind),
				},
			},
		}
	end

	return payload
end

local function awardFallback(player, rewardDefinition)
	if rewardDefinition.Kind == "XP" then
		if type(_G.AwardPlayer) == "function" then
			_G.AwardPlayer(player, rewardDefinition.Amount, 0)
		end
	elseif rewardDefinition.Kind == "Gold" then
		if type(_G.AwardPlayer) == "function" then
			_G.AwardPlayer(player, 0, rewardDefinition.Amount)
		end
	elseif rewardDefinition.Kind == "Silver" then
		if type(_G.AwardSouls) == "function" then
			_G.AwardSouls(player, rewardDefinition.Amount)
		else
			local data = PlayerData.Get(player)
			data.silver = (tonumber(data.silver) or 0) + rewardDefinition.Amount
			if PlayerData.MarkDirty then
				PlayerData.MarkDirty(player)
			end
		end
	end
end

local function logChangedStats(player, changedStats)
	for statName, change in pairs(changedStats or {}) do
		print(string.format(
			"[ChestItemService] %s stat %s changed from %s to %s",
			player.Name,
			statName,
			StatsConfig.FormatValue(statName, change.Old),
			StatsConfig.FormatValue(statName, change.New)
		))
	end
end

local function releasePause(pauseSource)
	print(string.format("[ChestItemService] Resuming run (%s)", tostring(pauseSource)))
	if type(_G.SetGlobalRunPause) == "function" then
		_G.SetGlobalRunPause(pauseSource, false)
	else
		PauseState.Value = false
	end
end

local function acquirePause(pauseSource)
	print(string.format("[ChestItemService] Pausing run (%s)", tostring(pauseSource)))
	if type(_G.SetGlobalRunPause) == "function" then
		_G.SetGlobalRunPause(pauseSource, true)
	else
		PauseState.Value = true
	end
end

local function clearPendingReward(player)
	local pending = pendingRewards[player]
	if not pending then
		return
	end

	releasePause(pending.PauseSource)
	pendingRewards[player] = nil
end

local function grantItem(player, itemId)
	local itemDefinition = ChestItemConfig.GetItem(itemId)
	if not itemDefinition then
		return nil, {}
	end

	local inventoryEntry = ensureInventoryEntry(player, itemId)
	inventoryEntry.ActiveStacks += 1
	inventoryEntry.TotalStacks += 1

	local sourceId = string.format("ChestItem:%s:%d", itemId, inventoryEntry.TotalStacks)
	inventoryEntry.SourceIds[#inventoryEntry.SourceIds + 1] = sourceId

	local _, changedStats = RunStatsService.AddModifier(player, sourceId, itemDefinition.Modifiers, {
		ItemId = itemDefinition.Id,
	})

	if itemDefinition.SpecialEffect then
		RunStatsService.RegisterSpecialEffect(player, sourceId, itemDefinition.Id, itemDefinition.SpecialEffect)
	end

	applyLegacyBridge(player, itemDefinition.Modifiers)

	syncInventory(player)
	return sourceId, changedStats
end

function ChestItemService.MarkItemConsumed(player, itemId, sourceId)
	local inventory = getInventory(player)
	local entry = inventory.ById[itemId]
	if not entry then
		return
	end

	if entry.ActiveStacks > 0 then
		entry.ActiveStacks -= 1
	end
	entry.ConsumedCount += 1

	if sourceId then
		for index = #entry.SourceIds, 1, -1 do
			if entry.SourceIds[index] == sourceId then
				table.remove(entry.SourceIds, index)
				break
			end
		end
	end

	syncInventory(player)
end

RunStatsService.SetItemConsumeCallback(function(player, itemId, consumeInfo)
	ChestItemService.MarkItemConsumed(player, itemId, consumeInfo and consumeInfo.SourceId)
end)

function ChestItemService.ResetPlayer(player)
	playerInventories[player] = {
		Entries = {},
		ById = {},
	}
	clearPendingReward(player)
	syncInventory(player)
end

function ChestItemService.RollReward(player)
	local availableByRarity = getAvailableItemsByRarity(player)
	local hasAnyItems = false
	for _, rarity in ipairs(ChestItemConfig.RarityOrder) do
		if #(availableByRarity[rarity] or {}) > 0 then
			hasAnyItems = true
			break
		end
	end

	if not hasAnyItems then
		local fallback = pickFallbackReward()
		return fallback, {
			RewardType = "Fallback",
			Rarity = "Common",
		}
	end

	local rolledRarity = rollWeightedRarity(player)
	local resolvedRarity = resolveFallbackRarity(rolledRarity, availableByRarity)
	if not resolvedRarity then
		local fallback = pickFallbackReward()
		return fallback, {
			RewardType = "Fallback",
			Rarity = "Common",
		}
	end

	local bucket = availableByRarity[resolvedRarity]
	local chosenItem = bucket[math.random(1, #bucket)]
	print(string.format("[ChestItemService] Rolled rarity %s for %s", resolvedRarity, player.Name))
	return chosenItem, {
		RewardType = "Item",
		Rarity = resolvedRarity,
		RolledRarity = rolledRarity,
	}
end

function ChestItemService.OpenReward(player, context)
	if not player or player.Parent ~= Players then
		return nil
	end
	if pendingRewards[player] then
		return nil
	end

	local rewardDefinition, rewardDetail = ChestItemService.RollReward(player)
	if not rewardDefinition or not rewardDetail then
		return nil
	end

	local token = string.format("%d:%d:%d", player.UserId, math.floor(os.clock() * 1000), math.random(100000, 999999))
	local pauseSource = "ChestReward:" .. token
	local payload = buildRewardPayload(rewardDefinition, token, context and context.SourceName, rewardDetail)

	pendingRewards[player] = {
		Token = token,
		RewardDefinition = rewardDefinition,
		RewardDetail = rewardDetail,
		PauseSource = pauseSource,
	}

	acquirePause(pauseSource)

	print(string.format(
		"[ChestItemService] Chest reward opened for %s -> %s (%s)",
		player.Name,
		rewardDefinition.Name,
		rewardDetail.Rarity
	))

	chestItemEvent:FireClient(player, payload)
	return rewardDefinition, rewardDetail
end

function ChestItemService.ClaimReward(player, token)
	local pending = pendingRewards[player]
	if not pending or pending.Token ~= token then
		return false
	end

	local rewardDefinition = pending.RewardDefinition
	local rewardDetail = pending.RewardDetail

	print(string.format("[ChestItemService] %s clicked TAKE", player.Name))

	if rewardDetail.RewardType == "Item" then
		local _, changedStats = grantItem(player, rewardDefinition.Id)
		logChangedStats(player, changedStats)
	elseif rewardDetail.RewardType == "Fallback" then
		awardFallback(player, rewardDefinition)
	end

	releasePause(pending.PauseSource)
	pendingRewards[player] = nil

	chestItemEvent:FireClient(player, {
		type = "rewardClosed",
		token = token,
	})
	syncInventory(player)

	return true
end

chestItemEvent.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	if tostring(payload.type or "") == "takeReward" then
		ChestItemService.ClaimReward(player, tostring(payload.token or ""))
	elseif tostring(payload.type or "") == "requestInventorySync" then
		syncInventory(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	ChestItemService.ResetPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	clearPendingReward(player)
	playerInventories[player] = nil
	pendingRewards[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	ChestItemService.ResetPlayer(player)
end

RunStarted.Changed:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		ChestItemService.ResetPlayer(player)
	end
end)

return ChestItemService
