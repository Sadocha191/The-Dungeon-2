local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
if not remotesFolder then
	error("[SpellService] Missing ReplicatedStorage.Remotes")
end

local SpellVFXEvent = remotesFolder:FindFirstChild("SpellVFXEvent")
if not SpellVFXEvent then
	SpellVFXEvent = Instance.new("RemoteEvent")
	SpellVFXEvent.Name = "SpellVFXEvent"
	SpellVFXEvent.Parent = remotesFolder
end

local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end

local function findServerModule(name)
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

local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local SpellDefs = modFolder and require(modFolder:WaitForChild("SpellDefinitions"))
local NpcService = require(findServerModule("NpcService") or error("[SpellService] Missing NpcService"))
local PlayerData = require(findServerModule("PlayerData") or error("[SpellService] Missing PlayerData"))
local SpellEffects = require(findServerModule("SpellEffects") or error("[SpellService] Missing SpellEffects"))
local SpellProjectiles = require(findServerModule("SpellProjectiles") or error("[SpellService] Missing SpellProjectiles"))
local SpellTargeting = require(findServerModule("SpellTargeting") or error("[SpellService] Missing SpellTargeting"))
local SpellVisuals = require(findServerModule("SpellVisuals") or error("[SpellService] Missing SpellVisuals"))
local SpellSustained = require(findServerModule("SpellSustained") or error("[SpellService] Missing SpellSustained"))
local WeaponConfigs = modFolder and require(modFolder:WaitForChild("WeaponConfigs"))

local vfxRoot = workspace:FindFirstChild("SpellVFX")
if not vfxRoot then
	vfxRoot = Instance.new("Folder")
	vfxRoot.Name = "SpellVFX"
	vfxRoot.Parent = workspace
end

SpellVisuals.Configure({
	spellVfxEvent = SpellVFXEvent,
	getServerTimeNow = function()
		return workspace:GetServerTimeNow()
	end,
})

local pauseAccum = 0
local pauseStart = nil
local state = {}

local function isPaused()
	return PauseState.Value == true
end

local function spellClock()
	local realNow = os.clock()
	if PauseState.Value then
		if not pauseStart then
			pauseStart = realNow
		end
		return pauseStart - pauseAccum
	end
	if pauseStart then
		pauseAccum += (realNow - pauseStart)
		pauseStart = nil
	end
	return realNow - pauseAccum
end

local function getState(plr)
	local s = state[plr.UserId]
	if not s then
		s = { cds = {}, orbit = {}, vfx = {}, impact = {}, windBladeSoundToggle = 1 }
		state[plr.UserId] = s
	end
	return s
end

local function isPlayerRunActive(plr: Player): boolean
	if not plr or plr.Parent ~= Players or plr:GetAttribute("RunEnded") == true then
		return false
	end

	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hum ~= nil and hum.Health > 0 and hrp ~= nil
end

local function getEnemyRoot(model)
	return SpellTargeting.GetEnemyRoot(model)
end

local function enemyAlive(model)
	return SpellTargeting.IsEnemyAlive(model)
end

local function safeDamage(enemyModel, dmg, meta)
	if isPaused() then
		return 0
	end
	if meta and meta.player and not isPlayerRunActive(meta.player) then
		return 0
	end
	dmg = math.floor(tonumber(dmg) or 0)
	if dmg <= 0 then
		return 0
	end
	return NpcService.ApplyDamage(enemyModel, dmg, meta)
end

local function getEnemyPosition(model)
	return SpellTargeting.GetEnemyPosition(model)
end

local function getNearestEnemy(pos, range)
	return SpellTargeting.GetNearestEnemy(pos, range)
end

local function getEnemiesInRadius(pos, radius)
	return SpellTargeting.GetEnemiesInRadius(pos, radius)
end

local function getAllEnemies()
	return SpellTargeting.GetAllEnemies()
end

local function getPrioritizedEnemiesInRange(pos, range)
	return SpellTargeting.GetPrioritizedEnemiesInRange(pos, range)
end

local function pickPriorityEnemy(pos, range)
	return SpellTargeting.PickPriorityEnemy(pos, range)
end

local function pickPriorityEnemyList(pos, range, count)
	return SpellTargeting.PickPriorityEnemyList(pos, range, count)
end

local function applySlow(model, slowPct, duration)
	NpcService.ApplySlow(model, slowPct, duration)
end

local function applyFreeze(model, duration)
	NpcService.ApplyFreeze(model, duration)
end

local function addImpulse(model, impulse)
	NpcService.AddImpulse(model, impulse)
end

local function getVisualIntensity(stats)
	local level = math.max(1, tonumber(stats and stats.level) or 1)
	local upgradePower = math.max(0, tonumber(stats and stats.upgradePower) or 0)
	local basePower = math.max(0, tonumber(stats and stats.basePower) or 0)
	return 1 + ((level - 1) * 0.18) + (upgradePower * 0.05) + (basePower * 0.08)
end

local function getLevelVisualScale(stats, base)
	return (base or 1) * math.clamp(0.92 + (getVisualIntensity(stats) * 0.18), 0.95, 1.9)
end

local function getSpellState(plr, spellId)
	return {
		level = tonumber(plr:GetAttribute(("Spell_%s_Level"):format(spellId))) or 0,
		upgradePower = tonumber(plr:GetAttribute(("Spell_%s_UpgradePower"):format(spellId))) or 0,
		baseMultiplier = tonumber(plr:GetAttribute(("Spell_%s_BaseMultiplier"):format(spellId))) or 1,
		basePower = tonumber(plr:GetAttribute(("Spell_%s_BasePower"):format(spellId))) or 0,
	}
end

local function getEquippedWeaponCombat(plr)
	local data = PlayerData.Get(plr)
	local entry = data and typeof(data.Loadout) == "table" and data.Loadout[1] or nil
	local weaponId = entry and (entry.id or entry.Id)
	if typeof(weaponId) ~= "string" or weaponId == "" or not WeaponConfigs or not WeaponConfigs.Get then
		return nil
	end
	local def = WeaponConfigs.Get(weaponId)
	return def and def.combat or nil
end

local function getAtkMult(plr)
	local runAtkMult = tonumber(plr:GetAttribute("RunAtkMult")) or 1
	local shrineDamageMult = tonumber(plr:GetAttribute("ShrineDamageMult")) or 1
	local spellDamageMult = tonumber(plr:GetAttribute("SpellDamageMult")) or 1
	local weaponCombat = getEquippedWeaponCombat(plr)
	local weaponSpellDamage = 1 + math.max(0, tonumber(weaponCombat and weaponCombat.spellDamageBonus) or 0)
	return runAtkMult * shrineDamageMult * spellDamageMult * weaponSpellDamage
end

local function getDurationMult(plr)
	local weaponCombat = getEquippedWeaponCombat(plr)
	local weaponEffectBonus = math.max(0, tonumber(weaponCombat and weaponCombat.spellEffectBonus) or 0)
	return math.max(0.1, (1 + (tonumber(plr:GetAttribute("ShrineDurationBonus")) or 0)) * (1 + weaponEffectBonus))
end

local function getCooldownMult(plr)
	local weaponCombat = getEquippedWeaponCombat(plr)
	local weaponCooldownBonus = math.max(0, tonumber(weaponCombat and weaponCombat.spellCooldownBonus) or 0)
	return math.max(0.72, 1 - weaponCooldownBonus)
end

SpellEffects.Configure({
	addImpulse = addImpulse,
	applyFreeze = applyFreeze,
	applySlow = applySlow,
	getDurationMult = getDurationMult,
	getEnemyPosition = getEnemyPosition,
	isEnemyAlive = enemyAlive,
	safeDamage = safeDamage,
	spellClock = spellClock,
})

local function getTargetDamageMultiplier(enemy, stats)
	return SpellEffects.GetTargetDamageMultiplier(enemy, stats)
end

local function distancePointToSegment(point, a, b)
	return SpellTargeting.DistancePointToSegment(point, a, b)
end

local function applyEffects(plr, enemy, stats, sourcePos)
	SpellEffects.Apply(plr, enemy, stats, sourcePos)
end

local function shouldSpawnImpact(plr, spellId, enemy)
	local s = getState(plr)
	s.impact[spellId] = s.impact[spellId] or {}
	local bucket = s.impact[spellId]
	local now = spellClock()
	if now < (bucket[enemy] or 0) then
		return false
	end
	bucket[enemy] = now + 0.16
	return true
end

local function hitEnemy(plr, enemy, damage, stats, sourcePos, impactPos)
	if not enemy or not enemyAlive(enemy) then
		return
	end
	local dealt = damage * getAtkMult(plr) * getTargetDamageMultiplier(enemy, stats)
	dealt *= SpellEffects.GetVulnerabilityDamageMultiplier(enemy, spellClock())
	local applied = safeDamage(enemy, dealt, { player = plr })
	if applied > 0 then
		applyEffects(plr, enemy, stats, sourcePos)
		if shouldSpawnImpact(plr, tostring(stats and stats.spellId or "Spell"), enemy) then
			local hitPos = impactPos or getEnemyPosition(enemy) or sourcePos
			if hitPos then
				SpellVisuals.Broadcast("impact", {
					pos = hitPos,
					stats = SpellVisuals.ExtractStats(stats),
				})
			end
		end
	end
end

SpellProjectiles.Configure({
	broadcastProjectile = function(payload)
		SpellVisuals.Broadcast("projectile", payload)
	end,
	extractVisualStats = SpellVisuals.ExtractStats,
	getEnemyPosition = getEnemyPosition,
	getNearestEnemy = getNearestEnemy,
	hitEnemy = hitEnemy,
	isPaused = isPaused,
	isPlayerRunActive = isPlayerRunActive,
})

SpellSustained.Configure({
	broadcastBeam = function(payload)
		SpellVisuals.Broadcast("beam", payload)
	end,
	broadcastRing = function(payload)
		SpellVisuals.Broadcast("ring", payload)
	end,
	distancePointToSegment = distancePointToSegment,
	extractVisualStats = SpellVisuals.ExtractStats,
	getAllEnemies = getAllEnemies,
	getDurationMult = getDurationMult,
	getEnemiesInRadius = getEnemiesInRadius,
	getEnemyPosition = getEnemyPosition,
	hitEnemy = hitEnemy,
	isPlayerRunActive = isPlayerRunActive,
	pickPriorityEnemy = pickPriorityEnemy,
	spellClock = spellClock,
})

local function getCastOrigin(hrp)
	return hrp.Position + Vector3.new(0, 1.2, 0)
end

local function flattenDirection(dir)
	if typeof(dir) ~= "Vector3" then
		return Vector3.new(0, 0, -1)
	end

	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude <= 0.01 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function getSpellVisualDirection(origin, fallbackDir, searchRange)
	local direction = fallbackDir
	local target = pickPriorityEnemy(origin, searchRange)
	local targetPos = target and getEnemyPosition(target)
	if targetPos then
		local towardTarget = targetPos - origin
		if towardTarget.Magnitude > 0.01 then
			direction = towardTarget.Unit
		end
	end

	return flattenDirection(direction)
end

local function isWindBladeSpellId(spellId)
	return spellId == "WindBlade" or spellId == "GustBurst"
end

local function consumeWindBladeSoundVariant(plr)
	local s = getState(plr)
	local current = (s.windBladeSoundToggle == 2) and 2 or 1
	s.windBladeSoundToggle = (current == 1) and 2 or 1
	return current
end

local function stopAllOrbitVfx(plr)
	local s = getState(plr)
	SpellVisuals.StopAllOrbits(s.vfx, plr)
end

local function fireProjectile(plr, origin, dir, speed, range, damage, pierce, stats)
	SpellProjectiles.Fire({
		player = plr,
		origin = origin,
		dir = dir,
		speed = speed,
		range = range,
		damage = damage,
		pierce = pierce,
		stats = stats,
	})
end

local function runProjectile(plr, spellId, stats, hrp)
	local s = getState(plr)
	local now = spellClock()
	if now < (s.cds[spellId] or 0) then
		return
	end

	s.cds[spellId] = now + ((stats.cooldown or 1) * getCooldownMult(plr))
	local origin = getCastOrigin(hrp)
	local searchRange = stats.range or 60
	local targets = pickPriorityEnemyList(hrp.Position, searchRange, math.max(1, stats.count or 1))
	if #targets <= 0 then
		return
	end

	for index = 1, math.max(1, stats.count or 1) do
		local assignedTarget = targets[index]
		task.delay((index - 1) * 0.05, function()
			if not isPlayerRunActive(plr) then
				return
			end
			local target = assignedTarget
			if not target or not enemyAlive(target) then
				target = pickPriorityEnemy(hrp.Position, searchRange)
			end
			local targetPos = target and getEnemyPosition(target)
			if not targetPos then
				return
			end
			local direction = targetPos - origin
			if direction.Magnitude <= 0.01 then
				return
			end
			fireProjectile(plr, origin, direction.Unit, stats.projectileSpeed or 90, searchRange, stats.damage, stats.pierce or 0, stats)
		end)
	end
end

local function runOrbit(plr, spellId, stats, hrp, dt)
	local s = getState(plr)
	local bucket = s.orbit[spellId]
	if not bucket then
		bucket = { t = 0, lastHit = {} }
		s.orbit[spellId] = bucket
	end

	local count = math.max(1, stats.count or 1)
	local radius = stats.radius or 5.5
	local orbitSpeed = stats.orbitSpeed or 2.6
	local hitCooldown = stats.hitCooldown or 0.35

	SpellVisuals.SyncOrbit(s.vfx, plr, spellId, true, {
		count = count,
		radius = radius,
		orbitSpeed = orbitSpeed,
		height = 1.1,
		size = getLevelVisualScale(stats, 1.02 + math.min(0.46, (stats.basePower or 0) * 0.1)),
		transparency = 0.18,
		color = stats.visualColor,
		secondaryColor = stats.visualSecondaryColor,
		element = stats.element,
		secondaryElement = stats.secondaryElement,
		attackType = stats.attackType,
		spellType = stats.spellType,
		isCombo = stats.isCombo == true,
		iconGlyph = stats.iconGlyph,
		artMotif = stats.artMotif,
		visualDirection = stats.visualDirection,
		visualProfile = stats.visualProfile,
		lightRange = 8.5 + math.min(4.5, (stats.level or 1) * 0.4),
		lightBrightness = 1.6 + math.min(1.4, (stats.basePower or 0) * 0.35 + (stats.upgradePower or 0) * 0.05),
		trailLifetime = 0.11 + math.min(0.08, (stats.upgradePower or 0) * 0.004),
		level = stats.level or 1,
		visualIntensity = getVisualIntensity(stats),
	})

	bucket.t = (bucket.t or 0) + orbitSpeed * dt
	for index = 1, count do
		local angle = bucket.t + (index / count) * math.pi * 2
		local orbPos = hrp.Position + Vector3.new(math.cos(angle) * radius, 1.1, math.sin(angle) * radius)
		local enemy = getNearestEnemy(orbPos, 3.25)
		if enemy and enemyAlive(enemy) then
			local lastHit = bucket.lastHit[enemy] or 0
			if spellClock() - lastHit >= hitCooldown then
				bucket.lastHit[enemy] = spellClock()
				hitEnemy(plr, enemy, stats.damage, stats, orbPos, orbPos)
			end
		end
	end
end

local function runNova(plr, spellId, stats, hrp)
	local s = getState(plr)
	local now = spellClock()
	if now < (s.cds[spellId] or 0) then
		return
	end
	s.cds[spellId] = now + ((stats.cooldown or 3) * getCooldownMult(plr))

	local origin = getCastOrigin(hrp)
	local radius = stats.radius or 8
	local visualDir = getSpellVisualDirection(origin, hrp.CFrame.LookVector, math.max(24, radius + 12))
	local effectPos = origin + (visualDir * math.clamp(radius * 0.45, 2.75, 6.0))
	local payload = {
		pos = hrp.Position,
		effectPos = effectPos,
		dir = visualDir,
		radius = radius,
		stats = SpellVisuals.ExtractStats(stats),
	}
	if isWindBladeSpellId(stats and stats.spellId) or isWindBladeSpellId(spellId) then
		payload.windBladeSoundVariant = consumeWindBladeSoundVariant(plr)
	end
	SpellVisuals.Broadcast("nova", {
		pos = payload.pos,
		effectPos = payload.effectPos,
		dir = payload.dir,
		radius = payload.radius,
		stats = payload.stats,
		windBladeSoundVariant = payload.windBladeSoundVariant,
	})
	for _, enemy in ipairs(getEnemiesInRadius(hrp.Position, radius)) do
		hitEnemy(plr, enemy, stats.damage, stats, hrp.Position, getEnemyPosition(enemy))
	end
end

local function runZone(plr, spellId, stats, hrp)
	local s = getState(plr)
	local now = spellClock()
	if now < (s.cds[spellId] or 0) then
		return
	end
	s.cds[spellId] = now + ((stats.cooldown or 4) * getCooldownMult(plr))

	SpellSustained.RunZone({
		player = plr,
		stats = stats,
		origin = hrp.Position,
	})
end

local function runBeam(plr, spellId, stats, hrp)
	local s = getState(plr)
	local now = spellClock()
	if now < (s.cds[spellId] or 0) then
		return
	end
	s.cds[spellId] = now + ((stats.cooldown or 5) * getCooldownMult(plr))

	local origin = getCastOrigin(hrp)
	SpellSustained.RunBeam({
		player = plr,
		stats = stats,
		origin = origin,
		targetSearchPosition = hrp.Position,
		fallbackDirection = hrp.CFrame.LookVector,
	})
end

local function stopOrbitIfNeeded(plr, spellId)
	local s = getState(plr)
	if s.vfx[spellId] and s.vfx[spellId].enabled then
		SpellVisuals.SyncOrbit(s.vfx, plr, spellId, false)
	end
end

local function stepPlayer(plr, dt)
	if not isPlayerRunActive(plr) then
		stopAllOrbitVfx(plr)
		return
	end
	if isPaused() then
		return
	end
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		stopAllOrbitVfx(plr)
		return
	end

	for _, spellId in ipairs(SpellDefs.SPELL_ORDER or {}) do
		local spellState = getSpellState(plr, spellId)
		if spellState.level > 0 then
			local def = SpellDefs.GetSpell(spellId)
			local stats = SpellDefs.ComputeRuntimeStats(def, spellState)
			local archetype = stats and stats.archetype
			if archetype == "Projectile" then
				runProjectile(plr, spellId, stats, hrp)
			elseif archetype == "Orbit" then
				runOrbit(plr, spellId, stats, hrp, dt)
			elseif archetype == "Nova" then
				runNova(plr, spellId, stats, hrp)
			elseif archetype == "Zone" then
				runZone(plr, spellId, stats, hrp)
			elseif archetype == "Beam" then
				runBeam(plr, spellId, stats, hrp)
			end
		else
			local def = SpellDefs.GetSpell(spellId)
			if def and def.attackType == "Orbit" then
				stopOrbitIfNeeded(plr, spellId)
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	if isPaused() then
		return
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if isPlayerRunActive(plr) then
			stepPlayer(plr, dt)
		else
			stopAllOrbitVfx(plr)
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	state[plr.UserId] = nil
end)

print("[SpellService] Ready (elemental spell engine)")
