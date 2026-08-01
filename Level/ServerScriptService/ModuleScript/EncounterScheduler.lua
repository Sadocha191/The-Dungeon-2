local EncounterScheduler = {}
EncounterScheduler.__index = EncounterScheduler

local DEFAULT_LEVEL_SPAWN_BAND = {
	baseMaxAlive = 24,
	alivePerMinute = 4,
	spawnBurst = 1,
	intervalMultiplier = 1,
}

local DEFAULT_IMPORTANT_ENCOUNTER_CONFIG = {
	maxAliveMultiplier = 1,
	intervalMultiplier = 1,
	burstMultiplier = 1,
	minNormalAlive = 0,
	trimInterval = 0,
	trimDistance = 0,
}

local function copyArray(source)
	local out = {}
	if typeof(source) == "table" then
		for i, value in ipairs(source) do
			out[i] = value
		end
	end
	return out
end

function EncounterScheduler.new(options)
	assert(type(options) == "table", "[EncounterScheduler] options table is required")

	local runTimeLimit = math.max(1, tonumber(options.runTimeLimit) or (15 * 60))
	local eliteIntervalSeconds = math.max(1, tonumber(options.eliteIntervalSeconds) or (5 * 60))
	local maxLivingEnemies = math.max(1, math.floor(tonumber(options.maxLivingEnemies) or 100))
	local spawnLimitConfig = options.spawnLimitConfig or {}
	local eliteOrder = copyArray(options.eliteOrder)
	local eliteTotal = (#eliteOrder > 0) and math.max(1, math.floor(runTimeLimit / eliteIntervalSeconds)) or 0
	local swarmEventTimes = copyArray(options.swarmEventTimes)

	return setmetatable({
		runTimeLimit = runTimeLimit,
		eliteIntervalSeconds = eliteIntervalSeconds,
		maxLivingEnemies = maxLivingEnemies,
		levelSpawnBands = options.levelSpawnBands or {},
		overtimeSpawnConfig = options.overtimeSpawnConfig or {},
		swarmSpawnConfig = options.swarmSpawnConfig or {},
		importantEncounterSpawnConfig = options.importantEncounterSpawnConfig or {},
		spawnLimitConfig = {
			swarmTargetMaxAlive = math.max(0, math.floor(tonumber(spawnLimitConfig.swarmTargetMaxAlive) or 0)),
			swarmMaxLivingEnemies = math.max(maxLivingEnemies, math.floor(tonumber(spawnLimitConfig.swarmMaxLivingEnemies) or maxLivingEnemies)),
			postEliteCatchupDuration = math.max(0.1, tonumber(spawnLimitConfig.postEliteCatchupDuration) or 10),
			postEliteMaxPerTick = math.max(1, math.floor(tonumber(spawnLimitConfig.postEliteMaxPerTick) or 4)),
			postEliteMaxDebt = math.max(0, math.floor(tonumber(spawnLimitConfig.postEliteMaxDebt) or 8)),
		},
		swarmEventTimes = swarmEventTimes,
		swarmDuration = tonumber(options.swarmDuration) or 60,
		swarmState = {
			index = 1,
			nextAt = swarmEventTimes[1] or math.huge,
			active = false,
			activeUntil = 0,
			queuedDuration = 0,
			eliteSuppressionActive = false,
		},
		normalSpawnState = {
			nextAt = 0,
			debt = 0,
			catchupAccumulator = 0,
			catchupRate = 0,
			wasEliteEncounterActive = false,
			nextEncounterTrimAt = 0,
		},
		eliteOrder = eliteOrder,
		eliteTotal = eliteTotal,
		eliteIndex = 1,
		eliteCount = 0,
		nextEliteAt = eliteTotal > 0 and eliteIntervalSeconds or math.huge,
	}, EncounterScheduler)
end

function EncounterScheduler:GetRunPressure(elapsedSeconds: number, avgRunLevel: number)
	local minutes = math.floor(math.max(0, elapsedSeconds) / 60)
	local resolvedAverage = math.max(0, tonumber(avgRunLevel) or 0)
	local levelPressure = math.max(0, resolvedAverage - 2)
	return minutes, resolvedAverage, levelPressure
end

function EncounterScheduler:GetSpawnBand(avgRunLevel: number)
	local resolvedLevel = math.max(1, math.floor((tonumber(avgRunLevel) or 0) + 0.5))
	for _, band in ipairs(self.levelSpawnBands) do
		local minLevel = math.max(1, math.floor(tonumber(band.minLevel) or 1))
		local maxLevel = tonumber(band.maxLevel) or math.huge
		if resolvedLevel >= minLevel and resolvedLevel <= maxLevel then
			return band
		end
	end
	return self.levelSpawnBands[#self.levelSpawnBands] or DEFAULT_LEVEL_SPAWN_BAND
end

function EncounterScheduler:TimeScaleMult(elapsedSeconds: number, avgRunLevel: number)
	local minutes, _, levelPressure = self:GetRunPressure(elapsedSeconds, avgRunLevel)
	local hpMult = (1.07) ^ minutes * (1.14 ^ levelPressure)
	local dmgMult = (1.045) ^ minutes * (1.09 ^ levelPressure)
	local speedMult = math.min(1.35, 1 + (minutes * 0.015) + (levelPressure * 0.035))
	local cooldownMult = math.max(0.78, 1 - (minutes * 0.01) - (levelPressure * 0.025))
	return hpMult, dmgMult, speedMult, cooldownMult
end

function EncounterScheduler:GetPool(elapsedSeconds: number)
	if elapsedSeconds < 90 then
		return { { "Slime", 100 } }
	elseif elapsedSeconds < 210 then
		return { { "Slime", 55 }, { "Bat", 25 }, { "Goblin", 20 } }
	elseif elapsedSeconds < 360 then
		return { { "Slime", 25 }, { "Bat", 20 }, { "Goblin", 30 }, { "Grzyb", 25 } }
	elseif elapsedSeconds < 540 then
		return { { "Bat", 18 }, { "Goblin", 25 }, { "Grzyb", 22 }, { "Stump", 20 }, { "Cauldron", 15 } }
	elseif elapsedSeconds < 720 then
		return { { "Goblin", 20 }, { "Grzyb", 15 }, { "Stump", 25 }, { "Cauldron", 20 }, { "Ent_Fat", 20 } }
	else
		return { { "Slime", 8 }, { "Bat", 12 }, { "Goblin", 18 }, { "Grzyb", 10 }, { "Stump", 20 }, { "Cauldron", 15 }, { "Ent_Fat", 17 } }
	end
end

function EncounterScheduler.PickWeighted(pool)
	local total = 0
	for _, it in ipairs(pool) do
		total += it[2]
	end
	local r = math.random() * total
	local acc = 0
	for _, it in ipairs(pool) do
		acc += it[2]
		if r <= acc then
			return it[1]
		end
	end
	return pool[#pool][1]
end

function EncounterScheduler:GetImportantEncounterConfig(kind: string?)
	local cfg = kind and self.importantEncounterSpawnConfig[kind] or nil
	if typeof(cfg) ~= "table" then
		cfg = DEFAULT_IMPORTANT_ENCOUNTER_CONFIG
	end
	return {
		maxAliveMultiplier = math.max(0.05, tonumber(cfg.maxAliveMultiplier) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.maxAliveMultiplier),
		intervalMultiplier = math.max(0.05, tonumber(cfg.intervalMultiplier) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.intervalMultiplier),
		burstMultiplier = math.max(0.05, tonumber(cfg.burstMultiplier) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.burstMultiplier),
		minNormalAlive = math.max(0, math.floor(tonumber(cfg.minNormalAlive) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.minNormalAlive)),
		trimInterval = math.max(0, tonumber(cfg.trimInterval) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.trimInterval),
		trimDistance = math.max(0, tonumber(cfg.trimDistance) or DEFAULT_IMPORTANT_ENCOUNTER_CONFIG.trimDistance),
	}
end

function EncounterScheduler:IsSwarmActiveAt(t: number): boolean
	return self.swarmState.active and t < self.swarmState.activeUntil
end

function EncounterScheduler:GetMaxLivingEnemyCap(t: number?): number
	local currentTime = math.max(0, tonumber(t) or 0)
	if self:IsSwarmActiveAt(currentTime) then
		return self.spawnLimitConfig.swarmMaxLivingEnemies
	end
	return self.maxLivingEnemies
end

function EncounterScheduler:HasEnemyCapacity(activeCount: number, slotsNeeded: number?, t: number?): boolean
	local needed = math.max(1, math.floor(tonumber(slotsNeeded) or 1))
	return (math.max(0, math.floor(tonumber(activeCount) or 0)) + needed) <= self:GetMaxLivingEnemyCap(t)
end

function EncounterScheduler:DesiredMaxAlive(t: number, avgRunLevel: number, maxAliveScale: number?, encounterKind: string?)
	local minutes = self:GetRunPressure(t, avgRunLevel)
	local band = self:GetSpawnBand(avgRunLevel)
	local base = math.max(1, math.floor(tonumber(band.baseMaxAlive) or DEFAULT_LEVEL_SPAWN_BAND.baseMaxAlive))
	local addPerMinute = math.max(0, math.floor(tonumber(band.alivePerMinute) or DEFAULT_LEVEL_SPAWN_BAND.alivePerMinute))
	local v = base + (minutes * addPerMinute)
	if t >= self.runTimeLimit then
		local overtimeBase = math.max(0, math.floor(tonumber(self.overtimeSpawnConfig.extraMaxAlive) or 0))
		local overtimeStepSeconds = math.max(1, math.floor(tonumber(self.overtimeSpawnConfig.maxAliveStepSeconds) or 12))
		local overtimeStepAmount = math.max(0, math.floor(tonumber(self.overtimeSpawnConfig.maxAliveStepAmount) or 0))
		v += overtimeBase + (math.floor((t - self.runTimeLimit) / overtimeStepSeconds) * overtimeStepAmount)
	end
	local scaled = math.max(base, math.floor((v * (tonumber(maxAliveScale) or 1)) + 0.5))
	local encounterConfig = self:GetImportantEncounterConfig(encounterKind)
	scaled = math.max(
		encounterConfig.minNormalAlive,
		math.floor((scaled * encounterConfig.maxAliveMultiplier) + 0.5)
	)
	if self:IsSwarmActiveAt(t) and self.spawnLimitConfig.swarmTargetMaxAlive > 0 then
		scaled = math.max(scaled, self.spawnLimitConfig.swarmTargetMaxAlive)
	end
	return math.clamp(scaled, math.max(1, encounterConfig.minNormalAlive), self:GetMaxLivingEnemyCap(t))
end

function EncounterScheduler:SpawnInterval(t: number, avgRunLevel: number, intervalScale: number?, encounterKind: string?)
	local _, _, levelPressure = self:GetRunPressure(t, avgRunLevel)
	local band = self:GetSpawnBand(avgRunLevel)
	local minI = 0.24
	local maxI = 0.56
	local p = math.clamp(t / 1500, 0, 1)
	local i = maxI - (maxI - minI) * p
	i = i / (1 + (levelPressure * 0.08))
	i *= math.max(0.05, tonumber(band.intervalMultiplier) or DEFAULT_LEVEL_SPAWN_BAND.intervalMultiplier)
	if t >= self.runTimeLimit then
		i = math.max(0.09, i * math.max(0.05, tonumber(self.overtimeSpawnConfig.intervalMultiplier) or 0.42))
	end
	if self:IsSwarmActiveAt(t) then
		i = math.max(0.08, i * math.max(0.05, tonumber(self.swarmSpawnConfig.intervalMultiplier) or 0.33))
	end
	local encounterConfig = self:GetImportantEncounterConfig(encounterKind)
	return math.max(0.04, i * (tonumber(intervalScale) or 1) * encounterConfig.intervalMultiplier)
end

function EncounterScheduler:GetNormalSpawnBurstSize(t: number, avgRunLevel: number, burstScale: number?, encounterKind: string?): number
	local band = self:GetSpawnBand(avgRunLevel)
	local burst = math.max(1, math.floor(tonumber(band.spawnBurst) or DEFAULT_LEVEL_SPAWN_BAND.spawnBurst))
	if self:IsSwarmActiveAt(t) then
		burst += math.max(0, math.floor(tonumber(self.swarmSpawnConfig.extraBurst) or 0))
	end
	if t >= self.runTimeLimit then
		burst += math.max(0, math.floor(tonumber(self.overtimeSpawnConfig.extraBurst) or 0))
	end
	local encounterConfig = self:GetImportantEncounterConfig(encounterKind)
	local scaledBurst = math.floor((burst * (tonumber(burstScale) or 1) * encounterConfig.burstMultiplier) + 0.5)
	return math.max(1, scaledBurst)
end

function EncounterScheduler:GetEliteProgress()
	return {
		defeated = self.eliteCount,
		total = self.eliteTotal,
		index = self.eliteIndex,
		nextAt = self.nextEliteAt,
	}
end

function EncounterScheduler:GetNextEliteIn(t: number)
	if self.eliteIndex <= self.eliteTotal and self.nextEliteAt < math.huge then
		return math.max(0, self.nextEliteAt - t)
	end
	return nil
end

function EncounterScheduler:GetCurrentEliteName()
	if self.eliteIndex > self.eliteTotal or #self.eliteOrder == 0 then
		return nil
	end
	return self.eliteOrder[((self.eliteIndex - 1) % #self.eliteOrder) + 1]
end

function EncounterScheduler:GetPendingElite(t: number)
	if self.eliteIndex <= self.eliteTotal and t >= self.nextEliteAt then
		return self:GetCurrentEliteName()
	end
	return nil
end

function EncounterScheduler:RecordEliteSpawnResult(spawned: boolean, t: number)
	if spawned then
		self.eliteIndex += 1
		self.nextEliteAt = self.eliteIndex <= self.eliteTotal and (self.eliteIndex * self.eliteIntervalSeconds) or math.huge
	else
		self.nextEliteAt = t + 1
	end
end

function EncounterScheduler:RecordEliteDefeated()
	self.eliteCount += 1
	return self.eliteCount, self.eliteTotal
end

function EncounterScheduler:StepSwarm(t: number, eliteEncounterActive: boolean)
	local state = self.swarmState
	local result = {
		events = {},
		suppressAmbientNormals = false,
	}

	while state.index <= #self.swarmEventTimes and t >= state.nextAt do
		state.queuedDuration += self.swarmDuration
		state.index += 1
		state.nextAt = self.swarmEventTimes[state.index] or math.huge
	end

	if eliteEncounterActive then
		if state.active then
			state.queuedDuration += math.max(0, state.activeUntil - t)
			state.active = false
			state.activeUntil = 0
			table.insert(result.events, { type = "swarmEnd" })
		end
		if not state.eliteSuppressionActive then
			state.eliteSuppressionActive = true
			result.suppressAmbientNormals = true
		end
	else
		state.eliteSuppressionActive = false
		if state.active and t >= state.activeUntil then
			state.active = false
			state.activeUntil = 0
			table.insert(result.events, { type = "swarmEnd" })
		end
		if (not state.active) and state.queuedDuration > 0 then
			local swarmDuration = state.queuedDuration
			state.queuedDuration = 0
			state.active = true
			state.activeUntil = t + swarmDuration
			table.insert(result.events, {
				type = "swarmStart",
				duration = math.max(1, math.ceil(swarmDuration)),
				startedAt = math.floor(t),
			})
		end
	end

	return result
end

function EncounterScheduler:BuildNormalSpawnBudget(t: number, dt: number, eliteEncounterActive: boolean, avgRunLevel: number, stress, encounterKind: string?)
	local state = self.normalSpawnState
	local burstScale = stress and stress.burstSize or 1
	local intervalScale = stress and stress.intervalScale or 1

	if state.nextAt <= 0 then
		state.nextAt = t + self:SpawnInterval(t, avgRunLevel, intervalScale, encounterKind)
	end

	local scheduledSpawnBudget = 0
	local scheduleGuard = 0
	while t >= state.nextAt and scheduleGuard < 24 do
		scheduleGuard += 1
		local spawnAt = state.nextAt
		state.nextAt += self:SpawnInterval(spawnAt, avgRunLevel, intervalScale, encounterKind)
		local burstSize = self:GetNormalSpawnBurstSize(spawnAt, avgRunLevel, burstScale, encounterKind)
		if eliteEncounterActive then
			local maxDebt = self.spawnLimitConfig.postEliteMaxDebt
			if maxDebt > 0 then
				state.debt = math.min(maxDebt, state.debt + burstSize)
			else
				state.debt = 0
			end
		else
			scheduledSpawnBudget += burstSize
		end
	end

	if state.wasEliteEncounterActive and not eliteEncounterActive then
		state.catchupAccumulator = 0
		state.catchupRate = state.debt / self.spawnLimitConfig.postEliteCatchupDuration
	end
	state.wasEliteEncounterActive = eliteEncounterActive

	if eliteEncounterActive then
		return {
			scheduledSpawnBudget = scheduledSpawnBudget,
			catchupBudget = 0,
			pausedForElite = true,
			scheduleGuard = scheduleGuard,
		}
	end

	local catchupBudget = 0
	if state.debt > 0 then
		state.catchupAccumulator = math.min(
			self.spawnLimitConfig.postEliteMaxPerTick,
			state.catchupAccumulator + (state.catchupRate * math.max(0, tonumber(dt) or 0))
		)
	else
		state.catchupAccumulator = 0
		state.catchupRate = 0
	end

	if state.debt > 0 then
		catchupBudget = math.min(
			state.debt,
			self.spawnLimitConfig.postEliteMaxPerTick,
			math.floor(state.catchupAccumulator)
		)
	end

	return {
		scheduledSpawnBudget = scheduledSpawnBudget,
		catchupBudget = catchupBudget,
		pausedForElite = false,
		scheduleGuard = scheduleGuard,
	}
end

function EncounterScheduler:ShouldTrimNormal(t: number, encounterKind: string?, normalAliveNow: number, maxAlive: number): boolean
	local encounterConfig = self:GetImportantEncounterConfig(encounterKind)
	return encounterKind ~= nil
		and normalAliveNow > maxAlive
		and encounterConfig.trimInterval > 0
		and t >= self.normalSpawnState.nextEncounterTrimAt
end

function EncounterScheduler:RecordNormalTrim(t: number, encounterKind: string?)
	local encounterConfig = self:GetImportantEncounterConfig(encounterKind)
	self.normalSpawnState.nextEncounterTrimAt = t + encounterConfig.trimInterval
	return encounterConfig
end

function EncounterScheduler:RecordNormalSpawned(kind: string?)
	if kind == "catchup" then
		local state = self.normalSpawnState
		state.debt = math.max(0, state.debt - 1)
		state.catchupAccumulator = math.max(0, state.catchupAccumulator - 1)
		if state.debt <= 0 then
			state.catchupAccumulator = 0
			state.catchupRate = 0
		end
	end
end

return EncounterScheduler
