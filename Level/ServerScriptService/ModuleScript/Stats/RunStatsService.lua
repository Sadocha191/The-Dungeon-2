local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local sharedModules = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:WaitForChild("ModuleScripts")
local StatsConfig = require(sharedModules:WaitForChild("Stats"):WaitForChild("StatsConfig"))
local NpcService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("NpcService"))

local PauseState = ReplicatedStorage:FindFirstChild("PauseState") or ReplicatedStorage:WaitForChild("PauseState")
local RunStarted = ReplicatedStorage:FindFirstChild("RunStarted") or ReplicatedStorage:WaitForChild("RunStarted")

local RunStatsService = {}

local DEFAULTS = StatsConfig.CloneDefaults()
local playerStates = {}
local itemConsumeCallback = nil

local function getStatAttributeName(statName)
	return "RunStat_" .. tostring(statName)
end

local function cloneTable(source)
	local out = {}
	for key, value in pairs(source or {}) do
		out[key] = value
	end
	return out
end

local function isRunCharacterAlive(player)
	if not player or player.Parent ~= Players or player:GetAttribute("RunEnded") == true then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function getHumanoid(player)
	local character = player and player.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getBaseWalkSpeed(player)
	local value = player and player:GetAttribute("BaseWalkSpeed")
	return typeof(value) == "number" and value or 21
end

local function getBaseJumpPower(player)
	local value = player and player:GetAttribute("BaseJumpPower")
	return typeof(value) == "number" and value or 50
end

local function getLegacyNumberAttr(player, name, fallback)
	local value = player and player:GetAttribute(name)
	if typeof(value) == "number" then
		return value
	end
	return fallback or 0
end

local function ensureState(player)
	local state = playerStates[player]
	if state then
		return state
	end

	state = {
		modifiers = {},
		currentStats = cloneTable(DEFAULTS),
		persistentShield = 0,
		temporaryShield = 0,
		currentOverheal = 0,
		specialFlags = {},
		specialEffects = {},
		lastAppliedMaxHp = DEFAULTS.MaxHP,
	}
	playerStates[player] = state
	return state
end

local function getTotalShield(state)
	return math.max(0, (tonumber(state.persistentShield) or 0) + (tonumber(state.temporaryShield) or 0))
end

local function syncDynamicAttributes(player, state)
	local legacyShield = state.specialFlags.BlockShieldGain == true and 0 or math.max(0, getLegacyNumberAttr(player, "ShrineShieldCurrent", 0))
	player:SetAttribute("RunCurrentShield", getTotalShield(state) + legacyShield)
	player:SetAttribute("RunPersistentShield", math.max(0, tonumber(state.persistentShield) or 0))
	player:SetAttribute("RunTemporaryShield", math.max(0, tonumber(state.temporaryShield) or 0))
	player:SetAttribute("RunCurrentOverheal", math.max(0, tonumber(state.currentOverheal) or 0))
	player:SetAttribute("RunBlocksShieldGain", state.specialFlags.BlockShieldGain == true)
end

local function applyHumanoidStats(player, state, options)
	local humanoid = getHumanoid(player)
	if not humanoid then
		return
	end

	local currentStats = state.currentStats
	local previousMaxHp = tonumber(state.lastAppliedMaxHp) or currentStats.MaxHP
	local targetMaxHp = math.max(1, currentStats.MaxHP)
	local baseWalkSpeed = getBaseWalkSpeed(player)
	local baseJumpPower = getBaseJumpPower(player)

	humanoid.UseJumpPower = true
	humanoid.MaxHealth = targetMaxHp
	if options and options.ResetHealth == true then
		humanoid.Health = targetMaxHp
	else
		if targetMaxHp > previousMaxHp then
			humanoid.Health = math.min(targetMaxHp, humanoid.Health + (targetMaxHp - previousMaxHp))
		else
			humanoid.Health = math.min(humanoid.Health, targetMaxHp)
		end
	end
	humanoid.WalkSpeed = baseWalkSpeed * math.max(0.25, currentStats.MovementSpeed)
	humanoid.JumpPower = baseJumpPower * math.max(0.10, currentStats.JumpHeight)
	state.lastAppliedMaxHp = targetMaxHp
end

local function rebuildStats(player, options)
	local state = ensureState(player)
	local previousStats = cloneTable(state.currentStats)
	local nextStats = cloneTable(DEFAULTS)

	for _, modifier in pairs(state.modifiers) do
		for statName, delta in pairs(modifier.Modifiers or {}) do
			if nextStats[statName] ~= nil then
				nextStats[statName] += tonumber(delta) or 0
			end
		end
	end

	local baseWalkSpeed = math.max(1, getBaseWalkSpeed(player))
	nextStats.MaxHP += getLegacyNumberAttr(player, "RunBonusHP", 0)
	nextStats.HPRegen += getLegacyNumberAttr(player, "ShrineHpRegenFlat", 0)
	nextStats.Shield += getLegacyNumberAttr(player, "ShrineShieldMax", 0)
	nextStats.Lifesteal += getLegacyNumberAttr(player, "ShrineLifestealPct", 0)
	nextStats.Damage += math.max(0, getLegacyNumberAttr(player, "ShrineDamageMult", 1) - 1)
	nextStats.Damage += math.max(0, getLegacyNumberAttr(player, "RunAtkMult", 1) - 1)
	nextStats.CritDamage += getLegacyNumberAttr(player, "ShrineCritDamageBonus", 0)
	nextStats.AttackSpeed += getLegacyNumberAttr(player, "ShrineAttackSpeedBonus", 0)
	nextStats.DamageToElites += getLegacyNumberAttr(player, "ShrineEliteDamageBonus", 0)
	nextStats.Knockback += math.max(0, getLegacyNumberAttr(player, "ShrineKnockbackMult", 1) - 1)
	nextStats.ProjectileCount += getLegacyNumberAttr(player, "ShrineProjectileBonus", 0)
	nextStats.Duration += getLegacyNumberAttr(player, "ShrineDurationBonus", 0)
	nextStats.MovementSpeed += getLegacyNumberAttr(player, "RunBonusSpeed", 0) / baseWalkSpeed
	nextStats.ExtraJumps += getLegacyNumberAttr(player, "MoveExtraJumpBonus", 0)
	nextStats.JumpHeight += getLegacyNumberAttr(player, "ShrineJumpHeightBonus", 0)
	nextStats.Luck += getLegacyNumberAttr(player, "ShrineLuckBonus", 0)
	nextStats.Difficulty += getLegacyNumberAttr(player, "ShrineDifficultyPct", 0)
	nextStats.PickupRange += DEFAULTS.PickupRange * math.max(0, getLegacyNumberAttr(player, "ShrinePickupRangeBonus", 0))
	nextStats.PowerupMultiplier += math.max(0, getLegacyNumberAttr(player, "ShrinePowerupMult", 1) - 1)

	if state.specialFlags.BlockShieldGain == true then
		player:SetAttribute("ShrineShieldCurrent", 0)
		player:SetAttribute("ShrineShieldMax", 0)
		nextStats.Shield = 0
	end

	for statName in pairs(nextStats) do
		nextStats[statName] = StatsConfig.Clamp(statName, nextStats[statName])
		player:SetAttribute(getStatAttributeName(statName), nextStats[statName])
	end

	state.currentStats = nextStats

	local shieldDelta = nextStats.Shield - (previousStats.Shield or 0)
	if state.specialFlags.BlockShieldGain == true then
		state.persistentShield = 0
		state.temporaryShield = 0
	elseif shieldDelta > 0 then
		state.persistentShield = math.min(nextStats.Shield, state.persistentShield + shieldDelta)
	elseif shieldDelta < 0 then
		state.persistentShield = math.max(0, math.min(nextStats.Shield, state.persistentShield + shieldDelta))
	end
	state.persistentShield = math.clamp(state.persistentShield, 0, math.max(0, nextStats.Shield))
	state.currentOverheal = math.clamp(state.currentOverheal, 0, math.max(0, nextStats.Overheal))

	syncDynamicAttributes(player, state)
	applyHumanoidStats(player, state, options)

	local changedStats = {}
	for statName, value in pairs(nextStats) do
		local oldValue = previousStats[statName]
		if oldValue ~= value then
			changedStats[statName] = {
				Old = oldValue,
				New = value,
			}
		end
	end

	return nextStats, changedStats
end

local function consumeAngelDebt(player, state)
	local bucket = state.specialEffects.AngelDebt
	if type(bucket) ~= "table" then
		return false
	end

	local sourceId, effectData
	for candidateSourceId, candidateData in pairs(bucket) do
		sourceId = candidateSourceId
		effectData = candidateData
		break
	end
	if not sourceId or not effectData then
		return false
	end

	local triggerMaxHp = RunStatsService.GetStat(player, "MaxHP")
	bucket[sourceId] = nil
	if next(bucket) == nil then
		state.specialEffects.AngelDebt = nil
	end

	RunStatsService.RemoveModifier(player, sourceId)

	local humanoid = getHumanoid(player)
	if humanoid and humanoid.Health > 0 then
		local recoverAmount = math.max(1, math.floor(triggerMaxHp * 0.5 + 0.5))
		humanoid.Health = math.min(humanoid.MaxHealth, recoverAmount)
	end

	RunStatsService.AddShield(player, math.max(1, math.floor(triggerMaxHp * 0.5 + 0.5)), true)

	if itemConsumeCallback then
		itemConsumeCallback(player, effectData.ItemId, {
			ItemId = effectData.ItemId,
			SourceId = sourceId,
			Reason = "AngelDebt",
		})
	end

	print(string.format("[RunStatsService] Angel's Debt consumed for %s", player.Name))
	return true
end

function RunStatsService.SetItemConsumeCallback(callback)
	itemConsumeCallback = callback
end

function RunStatsService.ResetPlayer(player)
	local state = ensureState(player)
	state.modifiers = {}
	state.currentStats = cloneTable(DEFAULTS)
	state.persistentShield = DEFAULTS.Shield
	state.temporaryShield = 0
	state.currentOverheal = 0
	state.specialFlags = {}
	state.specialEffects = {}
	state.lastAppliedMaxHp = DEFAULTS.MaxHP

	rebuildStats(player, {
		ResetHealth = true,
	})
end

function RunStatsService.AddModifier(player, sourceId, modifiers, metadata)
	assert(type(sourceId) == "string" and sourceId ~= "", "RunStatsService.AddModifier requires sourceId")

	local state = ensureState(player)
	state.modifiers[sourceId] = {
		Id = sourceId,
		Modifiers = cloneTable(modifiers),
		Metadata = cloneTable(metadata),
	}

	return rebuildStats(player)
end

function RunStatsService.RemoveModifier(player, sourceId)
	local state = ensureState(player)
	if not state.modifiers[sourceId] then
		return state.currentStats, {}
	end

	state.modifiers[sourceId] = nil

	if type(state.specialEffects.AngelDebt) == "table" then
		state.specialEffects.AngelDebt[sourceId] = nil
		if next(state.specialEffects.AngelDebt) == nil then
			state.specialEffects.AngelDebt = nil
		end
	end

	return rebuildStats(player)
end

function RunStatsService.RegisterSpecialEffect(player, sourceId, itemId, specialEffect)
	local state = ensureState(player)
	if typeof(specialEffect) ~= "table" then
		return
	end

	local effectType = tostring(specialEffect.Type or "")
	if effectType == "AngelDebt" then
		state.specialEffects.AngelDebt = state.specialEffects.AngelDebt or {}
		state.specialEffects.AngelDebt[sourceId] = {
			ItemId = itemId,
			SourceId = sourceId,
		}
	elseif effectType == "BloodMoonContract" then
		state.specialFlags.BlockShieldGain = specialEffect.BlockShieldGain == true
		rebuildStats(player)
	end
end

function RunStatsService.UnregisterSpecialEffect(player, sourceId, specialEffect)
	local state = ensureState(player)
	if typeof(specialEffect) ~= "table" then
		return
	end

	local effectType = tostring(specialEffect.Type or "")
	if effectType == "AngelDebt" and type(state.specialEffects.AngelDebt) == "table" then
		state.specialEffects.AngelDebt[sourceId] = nil
		if next(state.specialEffects.AngelDebt) == nil then
			state.specialEffects.AngelDebt = nil
		end
	elseif effectType == "BloodMoonContract" then
		state.specialFlags.BlockShieldGain = false
		rebuildStats(player)
	end
end

function RunStatsService.GetStat(player, statName)
	local state = ensureState(player)
	local currentValue = state.currentStats[statName]
	if currentValue ~= nil then
		return currentValue
	end
	return DEFAULTS[statName]
end

function RunStatsService.GetAllStats(player)
	return cloneTable(ensureState(player).currentStats)
end

function RunStatsService.GetCurrentShield(player)
	local state = ensureState(player)
	return getTotalShield(state) + math.max(0, getLegacyNumberAttr(player, "ShrineShieldCurrent", 0))
end

function RunStatsService.GetCurrentOverheal(player)
	return math.max(0, tonumber(ensureState(player).currentOverheal) or 0)
end

function RunStatsService.GetAverageStat(statName)
	local total = 0
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Parent == Players and player:GetAttribute("RunEnded") ~= true then
			total += RunStatsService.GetStat(player, statName)
			count += 1
		end
	end
	if count <= 0 then
		return DEFAULTS[statName]
	end
	return total / count
end

function RunStatsService.AddShield(player, amount, allowTemporaryOverflow)
	local state = ensureState(player)
	local numericAmount = tonumber(amount) or 0
	if numericAmount == 0 then
		return getTotalShield(state)
	end

	if numericAmount > 0 and state.specialFlags.BlockShieldGain == true then
		syncDynamicAttributes(player, state)
		return getTotalShield(state)
	end

	if numericAmount > 0 then
		if allowTemporaryOverflow == true then
			state.temporaryShield += numericAmount
		else
			local shieldCap = math.max(0, RunStatsService.GetStat(player, "Shield"))
			state.persistentShield = math.clamp(state.persistentShield + numericAmount, 0, shieldCap)
		end
	else
		local remaining = math.abs(numericAmount)
		if state.temporaryShield > 0 then
			local used = math.min(state.temporaryShield, remaining)
			state.temporaryShield -= used
			remaining -= used
		end
		if remaining > 0 then
			state.persistentShield = math.max(0, state.persistentShield - remaining)
		end
	end

	syncDynamicAttributes(player, state)
	return getTotalShield(state)
end

function RunStatsService.HealPlayer(player, amount)
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return 0
	end

	local numericAmount = math.max(0, tonumber(amount) or 0)
	if numericAmount <= 0 then
		return 0
	end

	local state = ensureState(player)
	local maxHp = RunStatsService.GetStat(player, "MaxHP")
	local healed = math.min(numericAmount, math.max(0, maxHp - humanoid.Health))
	if healed > 0 then
		humanoid.Health = math.min(maxHp, humanoid.Health + healed)
	end

	local remaining = numericAmount - healed
	if remaining > 0 then
		local overhealCap = math.max(0, RunStatsService.GetStat(player, "Overheal"))
		if overhealCap > 0 then
			local beforeOverheal = state.currentOverheal
			state.currentOverheal = math.clamp(state.currentOverheal + remaining, 0, overhealCap)
			healed += (state.currentOverheal - beforeOverheal)
		end
	end

	syncDynamicAttributes(player, state)
	return healed
end

function RunStatsService.ApplyDamageToPlayer(player, amount, source)
	if not player or not player.Parent then
		return 0
	end

	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return 0
	end

	local incoming = math.max(0, tonumber(amount) or 0)
	if incoming <= 0 then
		return 0
	end

	local state = ensureState(player)
	local evasionChance = math.max(0, RunStatsService.GetStat(player, "Evasion"))
	if evasionChance > 0 and math.random() < evasionChance then
		print(string.format("[RunStatsService] %s evaded incoming damage", player.Name))
		return 0
	end

	local armor = math.clamp(RunStatsService.GetStat(player, "Armor"), 0, 0.80)
	incoming *= (1 - armor)

	local legacyShield = state.specialFlags.BlockShieldGain == true and 0 or math.max(0, getLegacyNumberAttr(player, "ShrineShieldCurrent", 0))
	if legacyShield > 0 and incoming > 0 then
		local absorbed = math.min(legacyShield, incoming)
		legacyShield -= absorbed
		incoming -= absorbed
		player:SetAttribute("ShrineShieldCurrent", legacyShield)
	end

	if state.temporaryShield > 0 and incoming > 0 then
		local absorbed = math.min(state.temporaryShield, incoming)
		state.temporaryShield -= absorbed
		incoming -= absorbed
	end

	if state.persistentShield > 0 and incoming > 0 then
		local absorbed = math.min(state.persistentShield, incoming)
		state.persistentShield -= absorbed
		incoming -= absorbed
	end

	if state.currentOverheal > 0 and incoming > 0 then
		local absorbed = math.min(state.currentOverheal, incoming)
		state.currentOverheal -= absorbed
		incoming -= absorbed
	end

	if incoming > 0 then
		local lethal = incoming >= humanoid.Health
		if lethal and consumeAngelDebt(player, state) then
			syncDynamicAttributes(player, state)
			return amount
		end
		humanoid:TakeDamage(incoming)
	end

	local thorns = math.max(0, RunStatsService.GetStat(player, "Thorns"))
	local sourceModel = typeof(source) == "Instance" and source or (typeof(source) == "table" and source.Model)
	if thorns > 0 and sourceModel and sourceModel:IsA("Model") and NpcService.IsAlive(sourceModel) then
		NpcService.ApplyDamage(sourceModel, thorns, {
			player = player,
			showFloating = false,
		})
	end

	syncDynamicAttributes(player, state)
	return incoming
end

local function refreshAllLivingPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Parent == Players then
			rebuildStats(player)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	RunStatsService.ResetPlayer(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		rebuildStats(player, {
			ResetHealth = RunStarted.Value ~= true,
		})
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerStates[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	RunStatsService.ResetPlayer(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		rebuildStats(player, {
			ResetHealth = RunStarted.Value ~= true,
		})
	end)
end

RunStarted.Changed:Connect(function(started)
	if started == true then
		for _, player in ipairs(Players:GetPlayers()) do
			RunStatsService.ResetPlayer(player)
		end
	else
		for _, player in ipairs(Players:GetPlayers()) do
			RunStatsService.ResetPlayer(player)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	if RunStarted.Value ~= true or PauseState.Value == true then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if isRunCharacterAlive(player) then
			local regen = RunStatsService.GetStat(player, "HPRegen")
			if regen > 0 then
				RunStatsService.HealPlayer(player, regen * dt)
			end
			syncDynamicAttributes(player, ensureState(player))
		end
	end
end)

_G.ApplyDamageToPlayer = function(player, amount, source)
	return RunStatsService.ApplyDamageToPlayer(player, amount, source)
end

_G.GetRunStat = function(player, statName)
	return RunStatsService.GetStat(player, statName)
end

_G.HealRunPlayer = function(player, amount)
	return RunStatsService.HealPlayer(player, amount)
end

refreshAllLivingPlayers()

return RunStatsService
