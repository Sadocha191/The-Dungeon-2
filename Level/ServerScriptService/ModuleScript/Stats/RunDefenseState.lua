local RunDefenseState = {}

local playerStates = {}

local function ensureState(player)
	local state = playerStates[player]
	if state then
		return state
	end

	state = {
		persistentShield = 0,
		temporaryShield = 0,
		currentOverheal = 0,
		blockShieldGain = false,
		lethalPrevention = {},
	}
	playerStates[player] = state
	return state
end

local function getTotalShield(state)
	return math.max(0, (tonumber(state.persistentShield) or 0) + (tonumber(state.temporaryShield) or 0))
end

function RunDefenseState.Reset(player, defaultShield)
	local state = ensureState(player)
	state.persistentShield = math.max(0, tonumber(defaultShield) or 0)
	state.temporaryShield = 0
	state.currentOverheal = 0
	state.blockShieldGain = false
	state.lethalPrevention = {}
end

function RunDefenseState.Forget(player)
	playerStates[player] = nil
end

function RunDefenseState.GetTotalShield(player)
	return getTotalShield(ensureState(player))
end

function RunDefenseState.GetCurrentShield(player, legacyShield)
	return RunDefenseState.GetTotalShield(player) + math.max(0, tonumber(legacyShield) or 0)
end

function RunDefenseState.GetCurrentOverheal(player)
	return math.max(0, tonumber(ensureState(player).currentOverheal) or 0)
end

function RunDefenseState.IsBlockShieldGain(player)
	return ensureState(player).blockShieldGain == true
end

function RunDefenseState.SetBlockShieldGain(player, enabled)
	ensureState(player).blockShieldGain = enabled == true
end

function RunDefenseState.SyncAttributes(player, legacyShield)
	local state = ensureState(player)
	local effectiveLegacyShield = state.blockShieldGain == true and 0 or math.max(0, tonumber(legacyShield) or 0)
	player:SetAttribute("RunCurrentShield", getTotalShield(state) + effectiveLegacyShield)
	player:SetAttribute("RunPersistentShield", math.max(0, tonumber(state.persistentShield) or 0))
	player:SetAttribute("RunTemporaryShield", math.max(0, tonumber(state.temporaryShield) or 0))
	player:SetAttribute("RunCurrentOverheal", math.max(0, tonumber(state.currentOverheal) or 0))
	player:SetAttribute("RunBlocksShieldGain", state.blockShieldGain == true)
end

function RunDefenseState.ReconcileStats(player, previousShield, nextShield, overhealCap)
	local state = ensureState(player)
	local previousShieldValue = tonumber(previousShield) or 0
	local nextShieldValue = tonumber(nextShield) or 0
	local nextOverhealCap = math.max(0, tonumber(overhealCap) or 0)

	if state.blockShieldGain == true then
		state.persistentShield = 0
		state.temporaryShield = 0
	else
		local shieldDelta = nextShieldValue - previousShieldValue
		if shieldDelta > 0 then
			state.persistentShield = math.min(nextShieldValue, state.persistentShield + shieldDelta)
		elseif shieldDelta < 0 then
			state.persistentShield = math.max(0, math.min(nextShieldValue, state.persistentShield + shieldDelta))
		end
	end
	state.persistentShield = math.clamp(state.persistentShield, 0, math.max(0, nextShieldValue))
	state.currentOverheal = math.clamp(state.currentOverheal, 0, nextOverhealCap)
end

function RunDefenseState.AddShield(player, amount, shieldCap, allowTemporaryOverflow)
	local state = ensureState(player)
	local numericAmount = tonumber(amount) or 0
	if numericAmount == 0 then
		return getTotalShield(state)
	end

	if numericAmount > 0 and state.blockShieldGain == true then
		return getTotalShield(state)
	end

	if numericAmount > 0 then
		if allowTemporaryOverflow == true then
			state.temporaryShield += numericAmount
		else
			local cap = math.max(0, tonumber(shieldCap) or 0)
			state.persistentShield = math.clamp(state.persistentShield + numericAmount, 0, cap)
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

	return getTotalShield(state)
end

function RunDefenseState.AddOverheal(player, amount, overhealCap)
	local state = ensureState(player)
	local numericAmount = math.max(0, tonumber(amount) or 0)
	if numericAmount <= 0 then
		return 0
	end

	local beforeOverheal = state.currentOverheal
	state.currentOverheal = math.clamp(state.currentOverheal + numericAmount, 0, math.max(0, tonumber(overhealCap) or 0))
	return state.currentOverheal - beforeOverheal
end

function RunDefenseState.AbsorbRunDefense(player, amount)
	local state = ensureState(player)
	local incoming = math.max(0, tonumber(amount) or 0)

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

	return incoming
end

function RunDefenseState.RegisterLethalPrevention(player, sourceId, itemId)
	local state = ensureState(player)
	state.lethalPrevention[sourceId] = {
		ItemId = itemId,
		SourceId = sourceId,
	}
end

function RunDefenseState.UnregisterLethalPrevention(player, sourceId)
	local state = ensureState(player)
	state.lethalPrevention[sourceId] = nil
end

function RunDefenseState.ConsumeLethalPrevention(player)
	local state = ensureState(player)
	for sourceId, effectData in pairs(state.lethalPrevention) do
		state.lethalPrevention[sourceId] = nil
		return sourceId, effectData
	end
	return nil, nil
end

return RunDefenseState
