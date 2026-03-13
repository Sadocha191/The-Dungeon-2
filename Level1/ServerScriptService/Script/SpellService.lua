local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

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
		s = { cds = {}, orbit = {}, vfx = {}, impact = {} }
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

local function blendColor(a, b, alpha)
	return Color3.new(
		a.R + ((b.R - a.R) * alpha),
		a.G + ((b.G - a.G) * alpha),
		a.B + ((b.B - a.B) * alpha)
	)
end

local function brightenColor(color, alpha)
	return blendColor(color, Color3.new(1, 1, 1), alpha or 0.3)
end

local function darkenColor(color, alpha)
	return blendColor(color, Color3.new(0, 0, 0), alpha or 0.3)
end

local function getVisualColors(stats)
	local primary = typeof(stats and stats.visualColor) == "Color3" and stats.visualColor or Color3.fromRGB(255, 255, 255)
	local secondary = typeof(stats and stats.visualSecondaryColor) == "Color3" and stats.visualSecondaryColor or brightenColor(primary, 0.32)
	return primary, secondary
end

local function ensureVfxPart(parent, name, size, color, transparency, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = material or Enum.Material.Neon
	part.Color = color or Color3.fromRGB(255, 255, 255)
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function addPointLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color or Color3.fromRGB(255, 255, 255)
	light.Brightness = brightness or 2
	light.Range = range or 10
	light.Shadows = false
	light.Parent = parent
	return light
end

local function addTrail(part, colorA, colorB, width, lifetime)
	local z = math.max(0.25, part.Size.Z * 0.5)
	local front = Instance.new("Attachment")
	front.Name = "TrailFront"
	front.Position = Vector3.new(0, 0, -z)
	front.Parent = part

	local back = Instance.new("Attachment")
	back.Name = "TrailBack"
	back.Position = Vector3.new(0, 0, z)
	back.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = front
	trail.Attachment1 = back
	trail.Color = ColorSequence.new(colorA, colorB)
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Lifetime = lifetime or 0.12
	trail.MinLength = 0.02
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	local startWidth = math.max(0.08, width or 0.6)
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, startWidth),
		NumberSequenceKeypoint.new(1, math.max(0.02, startWidth * 0.18)),
	})
	trail.Parent = part
	return trail
end

local function addBurstEmitter(parent, primary, secondary, emitCount, scale)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BurstAttachment"
	attachment.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Burst"
	emitter.Color = ColorSequence.new(primary, secondary)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.18, 0.32)
	emitter.Speed = NumberRange.new(6 * scale, 12 * scale)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3 * scale),
		NumberSequenceKeypoint.new(0.55, 0.16 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	emitter:Emit(emitCount or 12)
	return emitter
end

local function addAmbientEmitter(parent, primary, secondary, rate, scale)
	local attachment = Instance.new("Attachment")
	attachment.Name = "AmbientAttachment"
	attachment.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Ambient"
	emitter.Color = ColorSequence.new(primary, secondary)
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.35, 0.7)
	emitter.Speed = NumberRange.new(0.45 * scale, 1.4 * scale)
	emitter.Acceleration = Vector3.new(0, 1.2 * scale, 0)
	emitter.Rate = rate or 12
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18 * scale),
		NumberSequenceKeypoint.new(0.6, 0.1 * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	return emitter
end

local function playTween(instance, duration, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
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

local function spawnImpactVisual(pos, stats)
	local primary, secondary = getVisualColors(stats)
	local scale = math.clamp(0.8 + ((stats.radius or stats.width or 2) * 0.08), 0.75, 1.5)
	local model = Instance.new("Model")
	model.Name = "SpellImpact"
	model.Parent = vfxRoot

	local flash = ensureVfxPart(model, "Flash", Vector3.new(1, 1, 1) * scale, primary, 0.12, Enum.Material.Neon, Enum.PartType.Ball)
	flash.CFrame = CFrame.new(pos)
	local shell = ensureVfxPart(model, "Shell", Vector3.new(1.35, 1.35, 1.35) * scale, secondary, 0.48, Enum.Material.Glass, Enum.PartType.Ball)
	shell.CFrame = CFrame.new(pos)

	addPointLight(flash, primary, 2.8, 12)
	addBurstEmitter(flash, primary, secondary, math.clamp(math.floor(10 + (scale * 6)), 10, 20), scale)

	playTween(flash, 0.18, { Size = Vector3.new(2.4, 2.4, 2.4) * scale, Transparency = 1 }, Enum.EasingStyle.Quart)
	playTween(shell, 0.24, { Size = Vector3.new(3.4, 3.4, 3.4) * scale, Transparency = 1 }, Enum.EasingStyle.Quart)

	Debris:AddItem(model, 0.35)
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
		if shouldSpawnImpact(plr, tostring(stats and stats.spellId or "Spell"), enemy) then
			local root = getEnemyRoot(enemy)
			local hitPos = root and (root.Position + Vector3.new(0, math.min(1.25, root.Size.Y * 0.35), 0)) or getEnemyPosition(enemy) or sourcePos
			if hitPos then
				spawnImpactVisual(hitPos, stats or {})
			end
		end
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

local function spawnRingVisual(pos, radius, duration, stats)
	local primary, secondary = getVisualColors(stats)
	local model = Instance.new("Model")
	model.Name = "SpellRing"
	model.Parent = vfxRoot

	local outer = ensureVfxPart(model, "Outer", Vector3.new(radius * 2, 0.35, radius * 2), primary, 0.58, Enum.Material.Neon)
	outer.Shape = Enum.PartType.Cylinder
	outer.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))

	local inner = ensureVfxPart(
		model,
		"Inner",
		Vector3.new(radius * 1.45, 0.2, radius * 1.45),
		secondary,
		0.76,
		stats and stats.spellType == "Physical" and Enum.Material.Metal or Enum.Material.Glass
	)
	inner.Shape = Enum.PartType.Cylinder
	inner.CFrame = outer.CFrame

	local anchor = ensureVfxPart(model, "Anchor", Vector3.new(0.2, 0.2, 0.2), primary, 1, Enum.Material.SmoothPlastic)
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0))

	addPointLight(anchor, primary, 1.6, math.clamp(radius * 2.4, 10, 20))
	addAmbientEmitter(anchor, primary, secondary, math.clamp(math.floor(8 + radius), 10, 18), math.clamp(radius * 0.12, 0.55, 1.2))

	Debris:AddItem(model, duration)
end

local function spawnNovaVisual(pos, radius, stats)
	local primary, secondary = getVisualColors(stats)
	local model = Instance.new("Model")
	model.Name = "SpellNova"
	model.Parent = vfxRoot

	local disk = ensureVfxPart(model, "Disk", Vector3.new(radius * 0.5, 0.35, radius * 0.5), primary, 0.22, Enum.Material.Neon)
	disk.Shape = Enum.PartType.Cylinder
	disk.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))

	local core = ensureVfxPart(model, "Core", Vector3.new(radius * 0.3, radius * 0.3, radius * 0.3), secondary, 0.28, Enum.Material.Glass, Enum.PartType.Ball)
	core.CFrame = CFrame.new(pos + Vector3.new(0, 0.35, 0))

	addPointLight(core, primary, 2.6, math.clamp(radius * 2.4, 12, 22))
	addBurstEmitter(core, primary, secondary, math.clamp(math.floor(radius * 2.1), 12, 24), math.clamp(radius * 0.1, 0.9, 1.5))

	playTween(disk, 0.22, { Size = Vector3.new(radius * 2.2, 0.35, radius * 2.2), Transparency = 1 }, Enum.EasingStyle.Quart)
	playTween(core, 0.24, { Size = Vector3.new(radius * 1.3, radius * 1.3, radius * 1.3), Transparency = 1 }, Enum.EasingStyle.Quart)

	Debris:AddItem(model, 0.35)
end

local function spawnBeamVisual(origin, dir, range, width, duration, stats)
	local primary, secondary = getVisualColors(stats)
	local model = Instance.new("Model")
	model.Name = "SpellBeam"
	model.Parent = vfxRoot

	local beamCFrame = CFrame.lookAt(origin + (dir * (range * 0.5)), origin + dir) * CFrame.new(0, 0, -(range * 0.5))
	local outer = ensureVfxPart(model, "Outer", Vector3.new(width * 1.05, width * 1.05, range), primary, 0.64, Enum.Material.Glass)
	outer.CFrame = beamCFrame

	local coreWidth = math.max(0.35, width * 0.55)
	local core = ensureVfxPart(model, "Core", Vector3.new(coreWidth, coreWidth, range), secondary, 0.2, Enum.Material.Neon)
	core.CFrame = beamCFrame

	local tipSize = math.max(0.8, width)
	local tip = ensureVfxPart(model, "Tip", Vector3.new(tipSize, tipSize, tipSize), primary, 0.1, Enum.Material.Neon, Enum.PartType.Ball)
	tip.CFrame = CFrame.new(origin + (dir * range))

	local anchor = ensureVfxPart(model, "Anchor", Vector3.new(0.2, 0.2, 0.2), primary, 1, Enum.Material.SmoothPlastic)
	anchor.CFrame = CFrame.new(origin + (dir * math.min(range * 0.35, 10)))

	addPointLight(anchor, primary, 2.4, math.clamp((width * 4) + 8, 10, 22))
	addAmbientEmitter(anchor, primary, secondary, math.clamp(math.floor(width * 3), 10, 18), math.clamp(width * 0.18, 0.5, 1.1))

	playTween(outer, duration, { Transparency = 0.9 }, Enum.EasingStyle.Sine)
	playTween(core, duration, { Transparency = 1 }, Enum.EasingStyle.Sine)
	playTween(tip, duration, { Transparency = 1 }, Enum.EasingStyle.Sine)

	Debris:AddItem(model, duration + 0.1)
end

local function createProjectileVisual(stats, origin, dir)
	local primary, secondary = getVisualColors(stats)
	local model = Instance.new("Model")
	model.Name = string.format("%sProjectile", tostring(stats and stats.spellId or "Spell"))
	model.Parent = vfxRoot

	local guide = ensureVfxPart(model, "Guide", Vector3.new(0.28, 0.28, 1.8), primary, 1, Enum.Material.SmoothPlastic)
	addPointLight(guide, primary, 1.8 + math.min(1.2, (stats.level or 1) * 0.18), 10 + math.min(6, stats.level or 1))
	addTrail(
		guide,
		primary,
		secondary,
		0.75 + math.min(0.18, (stats.basePower or 0) * 0.08),
		0.12 + math.min(0.06, (stats.upgradePower or 0) * 0.005)
	)

	local spinSpeed = 7

	if stats.element == "Fire" then
		local core = ensureVfxPart(model, "Core", Vector3.new(0.9, 0.9, 0.9), primary, 0.06, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensureVfxPart(model, "Shell", Vector3.new(1.25, 1.25, 1.25), secondary, 0.55, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local emberA = ensureVfxPart(model, "EmberA", Vector3.new(0.18, 0.18, 0.75), brightenColor(primary, 0.2), 0.1, Enum.Material.Neon)
		emberA.CFrame = CFrame.new(0.22, 0, -0.48)
		local emberB = ensureVfxPart(model, "EmberB", Vector3.new(0.18, 0.18, 0.75), brightenColor(primary, 0.2), 0.1, Enum.Material.Neon)
		emberB.CFrame = CFrame.new(-0.22, 0, -0.48)
		spinSpeed = 9
	elseif stats.element == "Electricity" then
		local needle = ensureVfxPart(model, "Needle", Vector3.new(0.22, 0.5, 1.9), primary, 0.05, Enum.Material.Neon)
		needle.CFrame = CFrame.new()
		local crossA = ensureVfxPart(model, "CrossA", Vector3.new(0.9, 0.12, 0.35), secondary, 0.18, Enum.Material.Neon)
		crossA.CFrame = CFrame.Angles(0, 0, math.rad(35))
		local crossB = ensureVfxPart(model, "CrossB", Vector3.new(0.9, 0.12, 0.35), secondary, 0.18, Enum.Material.Neon)
		crossB.CFrame = CFrame.Angles(0, 0, math.rad(-35))
		local tail = ensureVfxPart(model, "Tail", Vector3.new(0.48, 0.48, 0.48), brightenColor(primary, 0.25), 0.28, Enum.Material.Glass, Enum.PartType.Ball)
		tail.CFrame = CFrame.new(0, 0, 0.55)
		spinSpeed = 14
	elseif stats.element == "Air" then
		local blade = ensureVfxPart(model, "Blade", Vector3.new(0.18, 0.82, 1.75), primary, 0.08, Enum.Material.Neon)
		blade.CFrame = CFrame.new()
		local wingA = ensureVfxPart(model, "WingA", Vector3.new(0.85, 0.12, 0.62), secondary, 0.24, Enum.Material.Glass)
		wingA.CFrame = CFrame.new(0, 0, -0.1) * CFrame.Angles(0, 0, math.rad(32))
		local wingB = ensureVfxPart(model, "WingB", Vector3.new(0.85, 0.12, 0.62), secondary, 0.24, Enum.Material.Glass)
		wingB.CFrame = CFrame.new(0, 0, -0.1) * CFrame.Angles(0, 0, math.rad(-32))
		local tip = ensureVfxPart(model, "Tip", Vector3.new(0.12, 0.45, 0.55), brightenColor(primary, 0.2), 0.1, Enum.Material.Neon)
		tip.CFrame = CFrame.new(0, 0, -0.72)
		spinSpeed = 10
	elseif stats.element == "Water" then
		local core = ensureVfxPart(model, "Core", Vector3.new(0.82, 0.82, 0.82), primary, 0.1, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensureVfxPart(model, "Shell", Vector3.new(1.18, 1.18, 1.18), secondary, 0.58, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local crest = ensureVfxPart(model, "Crest", Vector3.new(0.18, 0.58, 1.1), brightenColor(primary, 0.24), 0.2, Enum.Material.Neon)
		crest.CFrame = CFrame.new(0, 0, -0.22)
		local dropA = ensureVfxPart(model, "DropA", Vector3.new(0.28, 0.28, 0.28), secondary, 0.16, Enum.Material.Glass, Enum.PartType.Ball)
		dropA.CFrame = CFrame.new(0.32, 0, 0.12)
		local dropB = ensureVfxPart(model, "DropB", Vector3.new(0.28, 0.28, 0.28), secondary, 0.16, Enum.Material.Glass, Enum.PartType.Ball)
		dropB.CFrame = CFrame.new(-0.32, 0, 0.12)
		spinSpeed = 6
	elseif stats.element == "Earth" then
		local rock = ensureVfxPart(model, "Rock", Vector3.new(0.82, 0.82, 1.35), darkenColor(primary, 0.25), 0.05, Enum.Material.Slate)
		rock.CFrame = CFrame.new()
		local crystal = ensureVfxPart(model, "Crystal", Vector3.new(0.28, 0.56, 1.85), primary, 0.15, Enum.Material.Neon)
		crystal.CFrame = CFrame.new()
		local shardA = ensureVfxPart(model, "ShardA", Vector3.new(0.26, 0.26, 0.85), secondary, 0.18, Enum.Material.Glass)
		shardA.CFrame = CFrame.new(0.28, 0, -0.18)
		local shardB = ensureVfxPart(model, "ShardB", Vector3.new(0.26, 0.26, 0.85), secondary, 0.18, Enum.Material.Glass)
		shardB.CFrame = CFrame.new(-0.28, 0, -0.18)
		spinSpeed = 5
	elseif stats.element == "Void" then
		local core = ensureVfxPart(model, "Core", Vector3.new(0.78, 0.78, 0.78), darkenColor(primary, 0.22), 0.08, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensureVfxPart(model, "Shell", Vector3.new(1.22, 1.22, 1.22), secondary, 0.62, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local bandA = ensureVfxPart(model, "BandA", Vector3.new(1.0, 0.12, 0.42), brightenColor(secondary, 0.18), 0.26, Enum.Material.Neon)
		bandA.CFrame = CFrame.Angles(0, 0, math.rad(45))
		local bandB = ensureVfxPart(model, "BandB", Vector3.new(0.12, 1.0, 0.42), brightenColor(primary, 0.1), 0.36, Enum.Material.Glass)
		bandB.CFrame = CFrame.Angles(0, 0, math.rad(45))
		spinSpeed = 8
	elseif stats.element == "Light" then
		local core = ensureVfxPart(model, "Core", Vector3.new(0.72, 0.72, 0.72), primary, 0.08, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensureVfxPart(model, "Shell", Vector3.new(1.1, 1.1, 1.1), secondary, 0.6, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local spine = ensureVfxPart(model, "Spine", Vector3.new(0.2, 0.65, 1.85), brightenColor(primary, 0.2), 0.12, Enum.Material.Neon)
		spine.CFrame = CFrame.new()
		local haloA = ensureVfxPart(model, "HaloA", Vector3.new(0.26, 0.26, 0.26), secondary, 0.16, Enum.Material.Glass, Enum.PartType.Ball)
		haloA.CFrame = CFrame.new(0.38, 0, -0.1)
		local haloB = ensureVfxPart(model, "HaloB", Vector3.new(0.26, 0.26, 0.26), secondary, 0.16, Enum.Material.Glass, Enum.PartType.Ball)
		haloB.CFrame = CFrame.new(-0.38, 0, -0.1)
		spinSpeed = 7
	elseif stats.element == "Physical" then
		local handle = ensureVfxPart(model, "Handle", Vector3.new(0.16, 0.16, 1.45), darkenColor(primary, 0.35), 0, Enum.Material.Metal)
		handle.CFrame = CFrame.new()
		local bladeA = ensureVfxPart(model, "BladeA", Vector3.new(0.95, 0.24, 0.42), brightenColor(primary, 0.18), 0, Enum.Material.Metal)
		bladeA.CFrame = CFrame.new(0.38, 0, -0.18)
		local bladeB = ensureVfxPart(model, "BladeB", Vector3.new(0.95, 0.24, 0.42), brightenColor(primary, 0.18), 0, Enum.Material.Metal)
		bladeB.CFrame = CFrame.new(-0.38, 0, -0.18)
		local pommel = ensureVfxPart(model, "Pommel", Vector3.new(0.25, 0.25, 0.25), secondary, 0, Enum.Material.Metal, Enum.PartType.Ball)
		pommel.CFrame = CFrame.new(0, 0, 0.62)
		local spike = ensureVfxPart(model, "Spike", Vector3.new(0.12, 0.32, 0.55), secondary, 0, Enum.Material.Metal)
		spike.CFrame = CFrame.new(0, 0, -0.78)
		spinSpeed = 16
	else
		local core = ensureVfxPart(model, "Core", Vector3.new(0.82, 0.82, 0.82), primary, 0.08, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensureVfxPart(model, "Shell", Vector3.new(1.15, 1.15, 1.15), secondary, 0.55, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
	end

	model:PivotTo(CFrame.lookAt(origin, origin + dir))
	Debris:AddItem(model, 5)

	return {
		model = model,
		spin = 0,
		spinSpeed = spinSpeed,
	}
end

local function destroyProjectileVisual(visual)
	if visual and visual.model and visual.model.Parent then
		visual.model:Destroy()
	end
end

local function fireProjectile(plr, origin, dir, speed, range, damage, pierce, stats)
	local visual = createProjectileVisual(stats, origin, dir)
	local pos = origin
	local traveled = 0
	local remainingPierce = math.max(0, math.floor(pierce or 0))
	local hit = {}
	local collisionRadius = stats.element == "Physical" and 3.6 or 3.3
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not visual or not visual.model or not visual.model.Parent then
			conn:Disconnect()
			return
		end
		if isPaused() then
			return
		end

		local step = speed * dt
		traveled += step
		pos += dir * step
		visual.spin += (visual.spinSpeed or 0) * dt
		visual.model:PivotTo(CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, visual.spin))

		local enemy = getNearestEnemy(pos, collisionRadius)
		local enemyPos = enemy and getEnemyPosition(enemy)
		if enemy and enemyPos and (enemyPos - pos).Magnitude <= collisionRadius and not hit[enemy] then
			hit[enemy] = true
			hitEnemy(plr, enemy, damage, stats, pos)
			if remainingPierce <= 0 then
				conn:Disconnect()
				destroyProjectileVisual(visual)
				return
			end
			remainingPierce -= 1
		end

		if traveled >= range then
			conn:Disconnect()
			destroyProjectileVisual(visual)
		end
	end)
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
		secondaryColor = stats.visualSecondaryColor,
		element = stats.element,
		spellType = stats.spellType,
		lightRange = 8.5 + math.min(4.5, (stats.level or 1) * 0.4),
		lightBrightness = 1.6 + math.min(1.4, (stats.basePower or 0) * 0.35 + (stats.upgradePower or 0) * 0.05),
		trailLifetime = 0.11 + math.min(0.08, (stats.upgradePower or 0) * 0.004),
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
	spawnNovaVisual(hrp.Position, radius, stats)
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
	spawnRingVisual(center, radius, duration, stats)

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
	spawnBeamVisual(origin, direction, range, width, duration, stats)

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
