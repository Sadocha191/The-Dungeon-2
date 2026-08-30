local RunService = game:GetService("RunService")

local NpcLifecycleDiagnostics = {}

local function countModels(folder: Instance): (number, number)
	local models = 0
	local proxies = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			models += 1
			if child:GetAttribute("NpcServerProxy") == true then
				proxies += 1
			end
		end
	end
	return models, proxies
end

function NpcLifecycleDiagnostics.BuildSnapshot(options): {[string]: any}
	local t = math.max(0, tonumber(options.elapsed()) or 0)
	local npc = options.npcService.GetLifecycleSnapshot()
	local serverModels, serverProxies = countModels(options.enemiesFolder)
	local scheduler = options.scheduler:GetDebugSnapshot(t)
	local wave = options.waveDiagnostics or {}
	local client = typeof(options.clientSnapshot) == "table" and options.clientSnapshot or {}
	return {
		elapsedSeconds = t,
		authoritativeAlive = npc.authoritativeAlive,
		registryRecords = npc.registryRecords,
		registryModelRecords = npc.registryModelRecords,
		registrySpatialRecords = npc.registrySpatialRecords,
		registeredDead = npc.registeredDead,
		registeredMissingModel = npc.registeredMissingModel,
		registeredServerProxies = npc.registeredServerProxies,
		serverModels = serverModels,
		serverProxies = serverProxies,
		populationCounter = npc.authoritativeAlive,
		baseMaxLivingEnemies = options.baseMaxLivingEnemies,
		currentMaxLivingEnemies = options.currentMaxLivingEnemies(t),
		spawnDebt = scheduler.spawnDebt,
		pendingSpawnCount = math.max(0, tonumber(wave.pendingSpawnCount) or 0),
		lastSpawnBlockedReason = wave.lastSpawnBlockedReason,
		lastSpawnAt = wave.lastSpawnAt,
		totalSwarmOverflowDespawns = wave.totalSwarmOverflowDespawns or 0,
		swarmActive = scheduler.swarmActive,
		swarmIndex = scheduler.swarmIndex,
		swarmActiveUntil = scheduler.swarmActiveUntil,
		swarmQueuedDuration = scheduler.swarmQueuedDuration,
		elitePending = scheduler.elitePending,
		eliteDefeated = scheduler.eliteDefeated,
		eliteTotal = scheduler.eliteTotal,
		activeEncounter = options.activeEncounter(),
		activeNormal = options.activeCounts.normal(),
		activeElite = options.activeCounts.elite(),
		activeMiniBoss = options.activeCounts.miniBoss(),
		activeBoss = options.activeCounts.boss(),
		activeVisuals = client.activeVisuals,
		freeVisuals = client.freeVisuals,
		poolCapacity = client.poolCapacity,
		clientPresentationRecords = client.presentationRecords,
		clientPresentationsWithVisual = client.presentationsWithVisual,
		totalSpawns = npc.totalSpawns,
		totalDeaths = npc.totalDeaths,
		totalUnregisters = npc.totalUnregisters,
		totalDespawns = npc.totalDespawns,
		duplicateUnregisterAttempts = npc.duplicateUnregisterAttempts,
		invariantChecks = npc.invariantChecks,
		invariantFailures = npc.invariantFailures,
		deathCallbackFailures = npc.deathCallbackFailures,
		navigationRecords = npc.navigationRecords,
		statusEffectRecords = npc.statusEffectRecords,
		pendingNavigationPaths = npc.pendingNavigationPaths,
		activeNavigationPaths = npc.activeNavigationPaths,
		pendingTombstones = npc.pendingTombstones,
		reliableTrackedIds = npc.reliableTrackedIds,
		motionTrackedIds = npc.motionTrackedIds,
	}
end

local function value(value: any): string
	return value == nil and "n/a" or tostring(value)
end

function NpcLifecycleDiagnostics.FormatSnapshot(snapshot: {[string]: any}): string
	return table.concat({
		string.format("t=%.1fs", tonumber(snapshot.elapsedSeconds) or 0),
		"alive=" .. value(snapshot.authoritativeAlive),
		"registry=" .. value(snapshot.registryRecords),
		"registryModel=" .. value(snapshot.registryModelRecords),
		"registrySpatial=" .. value(snapshot.registrySpatialRecords),
		"proxies=" .. value(snapshot.serverProxies),
		"population=" .. value(snapshot.populationCounter),
		"cap=" .. value(snapshot.currentMaxLivingEnemies) .. "/" .. value(snapshot.baseMaxLivingEnemies),
		"spawnDebt=" .. value(snapshot.spawnDebt),
		"pendingSpawn=" .. value(snapshot.pendingSpawnCount),
		"blocked=" .. value(snapshot.lastSpawnBlockedReason),
		"encounter=" .. value(snapshot.activeEncounter),
		string.format(
			"ranks=%s/%s/%s/%s",
			value(snapshot.activeNormal), value(snapshot.activeElite),
			value(snapshot.activeMiniBoss), value(snapshot.activeBoss)
		),
		string.format(
			"swarm=%s index=%s until=%s queued=%s",
			value(snapshot.swarmActive), value(snapshot.swarmIndex),
			value(snapshot.swarmActiveUntil), value(snapshot.swarmQueuedDuration)
		),
		string.format(
			"visuals=%s free=%s pool=%s clientRecords=%s",
			value(snapshot.activeVisuals), value(snapshot.freeVisuals),
			value(snapshot.poolCapacity), value(snapshot.clientPresentationRecords)
		),
		string.format(
			"totals spawn=%s death=%s unregister=%s despawn=%s",
			value(snapshot.totalSpawns), value(snapshot.totalDeaths),
			value(snapshot.totalUnregisters), value(snapshot.totalDespawns)
		),
		string.format(
			"cleanup deadRecords=%s missingModels=%s nav=%s status=%s paths=%s/%s tombstones=%s reliable=%s motion=%s",
			value(snapshot.registeredDead), value(snapshot.registeredMissingModel),
			value(snapshot.navigationRecords), value(snapshot.statusEffectRecords),
			value(snapshot.pendingNavigationPaths), value(snapshot.activeNavigationPaths),
			value(snapshot.pendingTombstones), value(snapshot.reliableTrackedIds),
			value(snapshot.motionTrackedIds)
		),
		string.format(
			"invariants checks=%s failures=%s duplicateUnregister=%s callbackFailures=%s swarmOverflowDespawns=%s",
			value(snapshot.invariantChecks), value(snapshot.invariantFailures),
			value(snapshot.duplicateUnregisterAttempts), value(snapshot.deathCallbackFailures),
			value(snapshot.totalSwarmOverflowDespawns)
		),
	}, " | ")
end

local function metricDelta(after, before, key: string): number
	return (tonumber(after[key]) or 0) - (tonumber(before[key]) or 0)
end

local function simulateTwentyOneMinuteRun(createScheduler): {[string]: any}
	local scheduler = createScheduler()
	local dt = 0.1
	local active = 0
	local totalSpawns = 0
	local totalDeaths = 0
	local spawnsAfterThirteenMinutes = 0
	local spawnsAfterTwentyMinutes = 0
	local swarmOverflowCleaned = 0
	local deathAccumulator = 0

	for step = 0, 21 * 60 / dt do
		local t = step * dt
		local swarmStep = scheduler:StepSwarm(t, false)
		for _, event in ipairs(swarmStep.events) do
			if event.type == "swarmEnd" then
				local cap = scheduler:GetMaxLivingEnemyCap(t)
				local overflow = math.max(0, active - cap)
				active -= overflow
				swarmOverflowCleaned += overflow
			end
		end

		deathAccumulator += dt * 2.5
		local deathsThisStep = math.min(active, math.floor(deathAccumulator))
		if deathsThisStep > 0 then
			active -= deathsThisStep
			totalDeaths += deathsThisStep
			deathAccumulator -= deathsThisStep
		end

		local plan = scheduler:BuildNormalSpawnBudget(t, dt, false, 1, nil, nil)
		local budget = plan.scheduledSpawnBudget + plan.catchupBudget
		local desired = scheduler:DesiredMaxAlive(t, 1, 1, nil)
		local cap = scheduler:GetMaxLivingEnemyCap(t)
		for _ = 1, budget do
			if active >= cap or active >= desired then
				break
			end
			active += 1
			totalSpawns += 1
			if t > 13 * 60 then
				spawnsAfterThirteenMinutes += 1
			end
			if t > 20 * 60 then
				spawnsAfterTwentyMinutes += 1
			end
		end
	end

	return {
		simulatedSeconds = 21 * 60,
		totalSpawns = totalSpawns,
		totalDeaths = totalDeaths,
		alive = active,
		spawnsAfterThirteenMinutes = spawnsAfterThirteenMinutes,
		spawnsAfterTwentyMinutes = spawnsAfterTwentyMinutes,
		swarmOverflowCleaned = swarmOverflowCleaned,
		invariantOk = totalSpawns - totalDeaths - swarmOverflowCleaned == active,
	}
end

function NpcLifecycleDiagnostics.RunLongTest(options, requestedCycles: number?): {[string]: any}
	assert(RunService:IsStudio(), "[NpcLifecycleDiagnostics] Long lifecycle test is Studio-only")
	local cycles = math.clamp(math.floor(tonumber(requestedCycles) or 1000), 100, 5000)
	local errors = {}
	local startedAt = os.clock()

	local function check(condition: boolean, message: string)
		if not condition then
			table.insert(errors, message)
		end
	end

	local function flush()
		options.npcService.FlushReplicationForDebug()
		task.wait()
	end

	local function killSpawned(rank: string, mobName: string?, damageKind: string): (Model?, string?)
		local mob = options.spawn(rank, mobName, "LifecycleTest")
		if not mob then
			table.insert(errors, string.format("spawn failed: rank=%s type=%s", rank, tostring(mobName)))
			return nil, nil
		end
		local npcId = tostring(mob:GetAttribute("NpcId") or "")
		local meta = {
			suppressRewards = true,
			showFloating = false,
			damageSource = damageKind,
			element = damageKind == "Spell" and "Fire" or nil,
		}
		options.applyDamage(mob, 1e12, meta)
		check(not options.npcService.IsAlive(mob), damageKind .. " death remained alive")
		check(mob.Parent == nil, damageKind .. " death retained server proxy")
		return mob, npcId
	end

	options.clear()
	flush()
	local initial = options.dump()
	check(initial.authoritativeAlive == 0, "initial alive count was not zero")
	check(initial.registryRecords == 0, "initial registry was not empty")

	-- Reliable death must release the client visual in the event handler itself.
	local visualMob = options.spawn("Normal", options.resolveType("Normal"), "LifecycleVisualTest")
	if visualMob then
		local visualNpcId = tostring(visualMob:GetAttribute("NpcId") or "")
		options.npcService.FlushReplicationForDebug()
		task.wait(0.25)
		local clientBefore = options.captureClient(visualNpcId)
		options.applyDamage(visualMob, 1e12, {
			suppressRewards = true,
			showFloating = false,
			damageSource = "Weapon",
		})
		options.npcService.FlushReplicationForDebug()
		task.wait(0.05)
		local clientAfter = options.captureClient(visualNpcId)
		if clientAfter then
			check(clientAfter.requestedNpcPresent ~= true, "dead client presentation record was retained")
			check(clientAfter.requestedNpcHasVisual ~= true, "dead client visual was retained")
		end
		options.visualTest = {
			before = clientBefore,
			after = clientAfter,
		}
	else
		table.insert(errors, "visual test normal spawn failed")
	end

	-- Verify each requested class and both authoritative damage entry paths.
	killSpawned("Normal", options.resolveType("Normal"), "Weapon")
	local flyingName = options.resolveType("Normal", "Flying")
	if flyingName then
		killSpawned("Normal", flyingName, "Spell")
	else
		table.insert(errors, "no flying Normal NPC template/config found")
	end
	killSpawned("Elite", options.resolveType("Elite"), "Weapon")
	killSpawned("MiniBoss", options.resolveType("MiniBoss"), "Spell")
	killSpawned("Boss", options.resolveType("Boss"), "Weapon")

	-- A yielding callback must observe an already released slot and destroyed proxy.
	local yieldingMob = options.spawn("Normal", options.resolveType("Normal"), "LifecycleYieldTest")
	if yieldingMob then
		local callbackEntered = false
		local callbackFinished = false
		options.npcService.BindDeath(yieldingMob, function()
			callbackEntered = true
			task.wait(0.15)
			callbackFinished = true
		end)
		task.spawn(function()
			options.applyDamage(yieldingMob, 1e12, {
				suppressRewards = true,
				showFloating = false,
				damageSource = "Weapon",
			})
		end)
		local deadline = os.clock() + 1
		repeat task.wait() until callbackEntered or os.clock() >= deadline
		local duringCallback = options.dump()
		check(callbackEntered, "yielding death callback did not start")
		check(duringCallback.authoritativeAlive == 0, "population slot waited for death callback")
		check(duringCallback.registryRecords == 0, "registry record waited for death callback")
		check(duringCallback.serverProxies == 0, "server proxy waited for death callback")
		repeat task.wait() until callbackFinished or os.clock() >= deadline + 1
		check(callbackFinished, "yielding death callback did not finish")
	else
		table.insert(errors, "yielding callback test spawn failed")
	end

	options.clear()
	flush()
	local longPhaseBefore = options.dump()
	local normalName = options.resolveType("Normal")
	for index = 1, cycles do
		killSpawned("Normal", normalName, index % 2 == 0 and "Spell" or "Weapon")
		if index % 40 == 0 then
			options.npcService.FlushReplicationForDebug()
			task.wait()
		end
	end
	flush()
	local longPhaseAfter = options.dump()
	local longSpawns = metricDelta(longPhaseAfter, longPhaseBefore, "totalSpawns")
	local longDeaths = metricDelta(longPhaseAfter, longPhaseBefore, "totalDeaths")
	local longUnregisters = metricDelta(longPhaseAfter, longPhaseBefore, "totalUnregisters")
	local longDespawns = metricDelta(longPhaseAfter, longPhaseBefore, "totalDespawns")
	check(longSpawns == cycles, string.format("long phase spawns=%d expected=%d", longSpawns, cycles))
	check(longDeaths == cycles, string.format("long phase deaths=%d expected=%d", longDeaths, cycles))
	check(longUnregisters == cycles, string.format("long phase unregisters=%d expected=%d", longUnregisters, cycles))
	check(longDespawns == 0, string.format("long phase despawns=%d expected=0", longDespawns))
	check(longSpawns - longDeaths == longPhaseAfter.authoritativeAlive, "spawn-death did not match alive after long phase")
	check(longPhaseAfter.registryRecords == 0, "registry was not empty after long death phase")

	local despawnMob = options.spawn("Normal", normalName, "LifecycleDespawnTest")
	if despawnMob then
		options.npcService.Despawn(despawnMob)
		check(despawnMob.Parent == nil, "despawn retained server proxy")
	else
		table.insert(errors, "despawn test spawn failed")
	end

	for _ = 1, 4 do
		options.spawn("Normal", normalName, "LifecycleDebugClearTest")
	end
	local debugCleared = options.clear()
	check(debugCleared >= 4, "debug clear did not remove all test NPCs")

	for _ = 1, 8 do
		options.spawn("Normal", normalName, "RunSwarm")
	end
	local beforeEncounterCleanup = options.dump()
	local targetAfterCleanup = math.max(0, beforeEncounterCleanup.authoritativeAlive - 3)
	local encounterCleaned = options.cleanupSwarmOverflow(targetAfterCleanup)
	local afterEncounterCleanup = options.dump()
	check(encounterCleaned == 3, string.format("encounter cleanup removed=%d expected=3", encounterCleaned))
	check(afterEncounterCleanup.authoritativeAlive == targetAfterCleanup, "encounter cleanup left wrong population")
	options.clear()

	local respawnMob = options.spawn("Normal", normalName, "LifecycleRespawnTest")
	check(respawnMob ~= nil and options.npcService.GetActiveCount() == 1, "spawn did not resume after all cleanup paths")
	if respawnMob then
		options.applyDamage(respawnMob, 1e12, {
			suppressRewards = true,
			showFloating = false,
			damageSource = "Weapon",
		})
	end
	options.clear()
	flush()
	local final = options.dump()
	check(final.authoritativeAlive == 0, "final authoritative alive was not zero")
	check(final.registryRecords == 0, "final registry was not empty")
	check(final.populationCounter == 0, "final population counter was not zero")
	check(final.serverProxies == 0, "final server proxy count was not zero")
	check(final.invariantFailures == 0, "lifecycle invariant failures were recorded")
	check(final.duplicateUnregisterAttempts == 0, "duplicate unregister attempts were recorded")
	check(
		final.totalSpawns - final.totalDeaths - final.totalDespawns == final.registryRecords,
		"global spawn-death-despawn invariant did not match registry"
	)
	local schedulerSimulation = simulateTwentyOneMinuteRun(options.createScheduler)
	check(schedulerSimulation.invariantOk, "21-minute scheduler simulation population invariant failed")
	check(schedulerSimulation.spawnsAfterThirteenMinutes > 0, "scheduler did not spawn after 13 minutes")
	check(schedulerSimulation.spawnsAfterTwentyMinutes > 0, "scheduler did not spawn after 20 minutes")

	return {
		ok = #errors == 0,
		cycles = cycles,
		durationSeconds = os.clock() - startedAt,
		errors = errors,
		longPhase = {
			totalSpawns = longSpawns,
			totalDeaths = longDeaths,
			totalUnregisters = longUnregisters,
			totalDespawns = longDespawns,
		},
		encounterCleaned = encounterCleaned,
		visualTest = options.visualTest,
		schedulerSimulation = schedulerSimulation,
		final = final,
	}
end

return NpcLifecycleDiagnostics
