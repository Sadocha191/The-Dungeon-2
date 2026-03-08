local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

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

local vfxRoot = workspace:FindFirstChild("SpellVFX")
if not vfxRoot then
	vfxRoot = Instance.new("Folder")
	vfxRoot.Name = "SpellVFX"
	vfxRoot.Parent = workspace
end

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
		s = { cds = {}, orbit = {}, vfx = {} }
		state[plr.UserId] = s
	end
	return s
end

local function getEnemyRoot(model)
	return NpcService.GetRoot(model)
end

local function enemyAlive(model)
	return NpcService.IsAlive(model)
end

local function safeDamage(enemyModel, dmg, meta)
	if isPaused() then
		return 0
	end
	dmg = math.floor(tonumber(dmg) or 0)
	if dmg <= 0 then
		return 0
	end
	return NpcService.ApplyDamage(enemyModel, dmg, meta)
end

local function getEnemyPosition(model)
	local pos = NpcService.GetPosition(model)
	if pos then
		return pos
	end
	local root = getEnemyRoot(model)
	return root and root.Position or nil
end

local function getNearestEnemy(pos, range)
	return NpcService.GetNearestEnemy(pos, range or 9999)
end

local function getEnemiesInRadius(pos, radius)
	return NpcService.GetEnemiesInRadius(pos, radius or 10)
end

local function getAllEnemies()
	return NpcService.GetLivingModels()
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

local function ensurePart(name, size, color, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.fromRGB(255, 255, 255)
	part.Transparency = transparency or 0.25
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = vfxRoot
	return part
end

local function getSpellState(plr, spellId)
	return {
		level = tonumber(plr:GetAttribute(("Spell_%s_Level"):format(spellId))) or 0,
		upgradePower = tonumber(plr:GetAttribute(("Spell_%s_UpgradePower"):format(spellId))) or 0,
		baseMultiplier = tonumber(plr:GetAttribute(("Spell_%s_BaseMultiplier"):format(spellId))) or 1,
		basePower = tonumber(plr:GetAttribute(("Spell_%s_BasePower"):format(spellId))) or 0,
	}
end

local function getAtkMult(plr)
	local runAtkMult = tonumber(plr:GetAttribute("RunAtkMult")) or 1
	local shrineDamageMult = tonumber(plr:GetAttribute("ShrineDamageMult")) or 1
	local spellDamageMult = tonumber(plr:GetAttribute("SpellDamageMult")) or 1
	return runAtkMult * shrineDamageMult * spellDamageMult
end

local function getDurationMult(plr)
	return math.max(0.1, 1 + (tonumber(plr:GetAttribute("ShrineDurationBonus")) or 0))
end

local function distancePointToSegment(point, a, b)
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom <= 1e-4 then
		return (point - a).Magnitude
	end
	local t = math.clamp(((point - a):Dot(ab)) / denom, 0, 1)
	local projection = a + (ab * t)
	return (point - projection).Magnitude
end

local function applyTimedDot(plr, enemy, dps, duration)
	local endAt = spellClock() + duration
	task.spawn(function()
		while spellClock() < endAt and enemyAlive(enemy) do
			safeDamage(enemy, dps * 0.5, { player = plr, showFloating = false })
			task.wait(0.5)
		end
	end)
end

local function applyEffects(plr, enemy, stats, sourcePos)
	local effects = stats.effects or {}
	local effectPower = stats.effectPower or 1
	local durationMult = getDurationMult(plr)
	local enemyPos = getEnemyPosition(enemy)

	if effects.dot then
		applyTimedDot(plr, enemy, (effects.dot.dps or 0) * effectPower, (effects.dot.duration or 0) * durationMult)
	end
	if effects.slow then
		applySlow(enemy, math.clamp((effects.slow.pct or 0) * (0.9 + (effectPower * 0.1)), 0, 0.7), (effects.slow.duration or 0) * durationMult)
	end
	if effects.stun then
		applyFreeze(enemy, (effects.stun.duration or 0) * durationMult * (0.9 + (effectPower * 0.1)))
	end
	if effects.vulnerability then
		enemy:SetAttribute("VulnerableUntil", spellClock() + ((effects.vulnerability.duration or 0) * durationMult))
		enemy:SetAttribute("VulnerablePct", (effects.vulnerability.pct or 0) * (0.9 + (effectPower * 0.1)))
	end
	if enemyPos and sourcePos and effects.knockback then
		local direction = enemyPos - sourcePos
		if direction.Magnitude > 0.01 then
			addImpulse(enemy, direction.Unit * (effects.knockback.force or 0) * (0.8 + (effectPower * 0.2)))
		end
	end
	if enemyPos and sourcePos and effects.pull then
		local direction = sourcePos - enemyPos
		if direction.Magnitude > 0.01 then
			addImpulse(enemy, direction.Unit * (effects.pull.force or 0) * (0.8 + (effectPower * 0.2)))
		end
	end
	if enemyPos and sourcePos and tonumber(stats.pullStrength) and tonumber(stats.pullStrength) > 0 then
		local direction = sourcePos - enemyPos
		if direction.Magnitude > 0.01 then
			addImpulse(enemy, direction.Unit * 10 * tonumber(stats.pullStrength) * (0.8 + (effectPower * 0.2)))
		end
	end
end

local function hitEnemy(plr, enemy, damage, stats, sourcePos)
	if not enemy or not enemyAlive(enemy) then
		return
	end
	local dealt = damage * getAtkMult(plr)
	local vulnUntil = tonumber(enemy:GetAttribute("VulnerableUntil")) or 0
	local vulnPct = tonumber(enemy:GetAttribute("VulnerablePct")) or 0
	if vulnUntil > spellClock() and vulnPct > 0 then
		dealt *= (1 + vulnPct)
	end
	local applied = safeDamage(enemy, dealt, { player = plr })
	if applied > 0 then
		applyEffects(plr, enemy, stats, sourcePos)
	end
end

local function getCastOrigin(hrp)
	return hrp.Position + Vector3.new(0, 1.2, 0)
end

local function syncOrbitVFX(plr, spellId, enabled, params)
	local s = getState(plr)
	s.vfx[spellId] = s.vfx[spellId] or {}
	local last = s.vfx[spellId]

	if not enabled then
		if last.enabled ~= false then
			last.enabled = false
			SpellVFXEvent:FireClient(plr, spellId, false)
		end
		return
	end

	params = params or {}
	local changed = last.enabled ~= true
	for key, value in pairs(params) do
		if last[key] ~= value then
			changed = true
			break
		end
	end
	if changed then
		last.enabled = true
		for key, value in pairs(params) do
			last[key] = value
		end
		SpellVFXEvent:FireClient(plr, spellId, true, params)
	end
end

local function spawnRingVisual(pos, radius, duration, color)
	local part = ensurePart("SpellRing", Vector3.new(radius * 2, 0.35, radius * 2), color, 0.55)
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90)
	part.Position = pos + Vector3.new(0, 0.15, 0)
	Debris:AddItem(part, duration)
end

local function spawnNovaVisual(pos, radius, color)
	local part = ensurePart("SpellNova", Vector3.new(radius * 2, 0.4, radius * 2), color, 0.45)
	part.Shape = Enum.PartType.Cylinder
	part.Orientation = Vector3.new(0, 0, 90)
	part.Position = pos + Vector3.new(0, 0.2, 0)
	Debris:AddItem(part, 0.25)
end

local function spawnBeamVisual(origin, dir, range, width, duration, color)
	local part = ensurePart("SpellBeam", Vector3.new(width, width, range), color, 0.55)
	part.CFrame = CFrame.lookAt(origin + (dir * (range * 0.5)), origin + dir) * CFrame.new(0, 0, -(range * 0.5))
	Debris:AddItem(part, duration)
end

local function fireProjectile(plr, origin, dir, speed, range, damage, pierce, stats)
	local part = ensurePart("SpellProjectile", Vector3.new(0.85, 0.85, 0.85), stats.visualColor, 0.15)
	part.Shape = Enum.PartType.Ball
	part.CFrame = CFrame.new(origin)
	local traveled = 0
	local remainingPierce = math.max(0, math.floor(pierce or 0))
	local hit = {}
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not part.Parent then
			conn:Disconnect()
			return
		end
		if isPaused() then
			return
		end

		local step = speed * dt
		traveled += step
		part.CFrame = part.CFrame + (dir * step)

		local enemy = getNearestEnemy(part.Position, 3.5)
		local enemyPos = enemy and getEnemyPosition(enemy)
		if enemy and enemyPos and (enemyPos - part.Position).Magnitude <= 3.5 and not hit[enemy] then
			hit[enemy] = true
			hitEnemy(plr, enemy, damage, stats, origin)
			if remainingPierce <= 0 then
				conn:Disconnect()
				part:Destroy()
				return
			end
			remainingPierce -= 1
		end

		if traveled >= range then
			conn:Disconnect()
			part:Destroy()
		end
	end)
	Debris:AddItem(part, 5)
end

local function runProjectile(plr, spellId, stats, hrp)
	local s = getState(plr)
	local now = spellClock()
	if now < (s.cds[spellId] or 0) then
		return
	end

	s.cds[spellId] = now + (stats.cooldown or 1)
	local origin = getCastOrigin(hrp)
	local target = getNearestEnemy(hrp.Position, stats.range or 60)
	local targetPos = target and getEnemyPosition(target)
	if not targetPos then
		return
	end

	local direction = (targetPos - origin)
	if direction.Magnitude <= 0.01 then
		return
	end
	direction = direction.Unit

	for index = 1, math.max(1, stats.count or 1) do
		task.delay((index - 1) * 0.05, function()
			fireProjectile(plr, origin, direction, stats.projectileSpeed or 90, stats.range or 60, stats.damage, stats.pierce or 0, stats)
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

	syncOrbitVFX(plr, spellId, true, {
		count = count,
		radius = radius,
		orbitSpeed = orbitSpeed,
		height = 1.1,
		size = 1.1 + math.min(0.4, (stats.basePower or 0) * 0.1),
		transparency = 0.18,
		color = stats.visualColor,
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
				hitEnemy(plr, enemy, stats.damage, stats, hrp.Position)
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
	s.cds[spellId] = now + (stats.cooldown or 3)

	local radius = stats.radius or 8
	spawnNovaVisual(hrp.Position, radius, stats.visualColor)
	for _, enemy in ipairs(getEnemiesInRadius(hrp.Position, radius)) do
		hitEnemy(plr, enemy, stats.damage, stats, hrp.Position)
	end
end

local function runZone(plr, spellId, stats, hrp)
	local s = getState(plr)
	local now = spellClock()
	if now < (s.cds[spellId] or 0) then
		return
	end
	s.cds[spellId] = now + (stats.cooldown or 4)

	local origin = hrp.Position
	local center = origin
	if stats.spawnAtEnemy then
		local target = getNearestEnemy(origin, 70)
		local targetPos = target and getEnemyPosition(target)
		if targetPos then
			center = targetPos
		end
	end

	local radius = stats.radius or 6
	local duration = (stats.duration or 3) * getDurationMult(plr)
	local tickRate = stats.tickRate or 0.45
	local tickDamage = stats.damage * math.max(0.3, tickRate)
	spawnRingVisual(center, radius, duration, stats.visualColor)

	local endAt = spellClock() + duration
	task.spawn(function()
		while spellClock() < endAt do
			for _, enemy in ipairs(getEnemiesInRadius(center, radius)) do
				hitEnemy(plr, enemy, tickDamage, stats, center)
			end
			task.wait(tickRate)
		end
	end)
end

local function runBeam(plr, spellId, stats, hrp)
	local s = getState(plr)
	local now = spellClock()
	if now < (s.cds[spellId] or 0) then
		return
	end
	s.cds[spellId] = now + (stats.cooldown or 5)

	local origin = getCastOrigin(hrp)
	local target = getNearestEnemy(hrp.Position, stats.range or 60)
	local targetPos = target and getEnemyPosition(target)
	local direction = targetPos and (targetPos - origin) or hrp.CFrame.LookVector
	if direction.Magnitude <= 0.01 then
		return
	end
	direction = direction.Unit

	local range = stats.range or 50
	local width = stats.width or 4
	local duration = stats.duration or 1.5
	local tickRate = stats.tickRate or 0.18
	local beamDamage = stats.damage * math.max(0.6, tickRate * 4)
	spawnBeamVisual(origin, direction, range, width, duration, stats.visualColor)

	local endAt = spellClock() + duration
	task.spawn(function()
		while spellClock() < endAt do
			local hitThisTick = {}
			local beamEnd = origin + (direction * range)
			for _, enemy in ipairs(getAllEnemies()) do
				local enemyPos = getEnemyPosition(enemy)
				if enemyPos and not hitThisTick[enemy] and distancePointToSegment(enemyPos, origin, beamEnd) <= (width * 0.5) then
					hitThisTick[enemy] = true
					hitEnemy(plr, enemy, beamDamage, stats, origin)
				end
			end
			task.wait(tickRate)
		end
	end)
end

local function stopOrbitIfNeeded(plr, spellId)
	local s = getState(plr)
	if s.vfx[spellId] and s.vfx[spellId].enabled then
		syncOrbitVFX(plr, spellId, false)
	end
end

local function stepPlayer(plr, dt)
	if isPaused() then
		return
	end
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
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
		if plr.Parent and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
			stepPlayer(plr, dt)
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	state[plr.UserId] = nil
end)

print("[SpellService] Ready (elemental spell engine)")
