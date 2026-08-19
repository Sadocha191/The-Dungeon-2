-- SpellVFXClient.lua
-- Renders orbit and transient spell VFX fully on the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpellVFXEvent = remotes:WaitForChild("SpellVFXEvent")

local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
	or ReplicatedStorage:WaitForChild("PauseState", 5)

local vfxRoot = workspace:FindFirstChild("SpellVFX")
if not vfxRoot then
	vfxRoot = Instance.new("Folder")
	vfxRoot.Name = "SpellVFX"
	vfxRoot.Parent = workspace
end

local activeOrbits = {}
local activeProjectiles = {}
local WIND_BLADE_EMIT_COUNTS = {
	Debris = 10,
	Dot = 8,
	Mist = 3,
	Slash = 1,
	Smoke = 10,
	Whirl = 2,
	Wind = 1,
}
local WIND_BLADE_SOUND_NAMES = {
	[1] = { "Wind Slash 1", "Wind Slash1" },
	[2] = { "Wind Slash 2", "Wind Slash2" },
}
local WIND_BLADE_AUDIO_CLEANUP_BUFFER = 1.25
local WIND_BLADE_AUDIO_RETRY_DELAY = 0.08
local WIND_BLADE_AUDIO_POOL_SIZE = 6
local WIND_BLADE_AUDIO_ROLLOFF_MAX_DISTANCE = 120
local WIND_BLADE_AUDIO_STOP_BUFFER = 0.25
local windBladeSoundTemplates = {}
local windBladeAudioPools = {}
local windBladeAudioPoolCursor = {}
local windBladeAudioPreloadInFlight = false
local windBladeAudioPreloadGeneration = 0
local windBladeAudioPreloadedGeneration = 0

local function isPaused(): boolean
	return PauseState ~= nil and PauseState.Value == true
end

local function getHRP()
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
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

local function getVisualIntensity(cfg)
	local level = math.max(1, tonumber(cfg and cfg.level) or 1)
	local intensity = tonumber(cfg and cfg.visualIntensity) or 1
	local upgradePower = math.max(0, tonumber(cfg and cfg.upgradePower) or 0)
	local basePower = math.max(0, tonumber(cfg and cfg.basePower) or 0)
	return math.max(1, intensity + ((level - 1) * 0.04) + (upgradePower * 0.05) + (basePower * 0.08))
end

local function getLevelVisualScale(stats, base)
	return (base or 1) * math.clamp(0.92 + (getVisualIntensity(stats) * 0.18), 0.95, 1.9)
end

local function getVisualColors(stats)
	local primary = typeof(stats and stats.visualColor) == "Color3" and stats.visualColor or Color3.fromRGB(255, 255, 255)
	local secondary = typeof(stats and stats.visualSecondaryColor) == "Color3" and stats.visualSecondaryColor or brightenColor(primary, 0.32)
	return primary, secondary
end

local function applyPartDefaults(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function ensurePart(parent, name, size, color, transparency, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Transparency = transparency or 0
	part.Material = material or Enum.Material.Neon
	if shape then
		part.Shape = shape
	end
	applyPartDefaults(part)
	part.Parent = parent
	return part
end

local function addPointLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness or 2
	light.Range = range or 10
	light.Shadows = false
	light.Parent = parent
	return light
end

local function addTrail(part, colorA, colorB, width, lifetime)
	local z = math.max(0.18, part.Size.Z * 0.5)
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
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	local startWidth = math.max(0.06, width or 0.3)
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, startWidth),
		NumberSequenceKeypoint.new(1, math.max(0.02, startWidth * 0.2)),
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

local function getVisualProfile(stats)
	if typeof(stats and stats.visualProfile) == "table" then
		return stats.visualProfile
	end
	return {}
end

local function getProfileSeed(stats, profile)
	local text = tostring(stats and stats.spellId or "")
	if text == "" then
		text = tostring(profile and profile.silhouette or "")
	end
	local total = 0
	for index = 1, #text do
		total += string.byte(text, index) or 0
	end
	return total
end

local function getProfileAccentCount(stats, profile)
	local motifs = profile and profile.motifs
	local motifCount = typeof(motifs) == "table" and #motifs or 0
	local requested = tonumber(profile and profile.accentCount) or motifCount
	local maxCount = stats and stats.isCombo and 5 or 3
	return math.clamp(math.floor(requested), 2, maxCount)
end

local function addProfileAccents(model, baseCFrame, scale, primary, secondary, stats, mode)
	local profile = getVisualProfile(stats)
	local count = getProfileAccentCount(stats, profile)
	local seed = getProfileSeed(stats, profile)
	local comboBoost = stats and stats.isCombo and 1.18 or 1
	local radius = (mode == "projectile" and 0.48 or mode == "beam" and 0.55 or 0.72) * scale * comboBoost

	for index = 1, count do
		local phase = ((index / count) * math.pi * 2) + ((seed % 37) * 0.07)
		local color = index % 2 == 0 and secondary or primary
		local alpha = mode == "beam" and 0.36 or 0.22
		local size
		local offset
		local rotation
		if mode == "projectile" or mode == "orbit" then
			size = Vector3.new(0.08, 0.24 + (index * 0.03), 0.78 + ((seed % 5) * 0.04)) * scale
			offset = Vector3.new(math.cos(phase) * radius, math.sin(phase) * radius, -0.18 + (index * 0.05))
			rotation = CFrame.Angles(0, 0, phase)
		elseif mode == "beam" then
			size = Vector3.new(0.08, radius * 1.2, 0.32 + ((seed + index) % 4) * 0.08)
			offset = Vector3.new(math.cos(phase) * radius, math.sin(phase) * radius, -0.4 + (index * 0.16))
			rotation = CFrame.Angles(0, 0, phase)
		else
			size = Vector3.new(radius * 1.1, 0.08, 0.16 + ((seed + index) % 3) * 0.05)
			offset = Vector3.new(math.cos(phase) * radius, 0.06, math.sin(phase) * radius)
			rotation = CFrame.Angles(0, phase, 0)
		end

		local accent = ensurePart(model, ("SignatureAccent%d"):format(index), size, color, alpha, Enum.Material.Neon)
		accent.CFrame = baseCFrame * CFrame.new(offset) * rotation
	end
end

local function spawnCastVisual(origin, dir, stats)
	if typeof(origin) ~= "Vector3" then
		return
	end

	local primary, secondary = getVisualColors(stats)
	local intensity = getVisualIntensity(stats)
	local scale = math.clamp(0.78 + (intensity * 0.16), 0.85, 1.55)
	local model = Instance.new("Model")
	model.Name = string.format("%sCast", tostring(stats and stats.spellId or "Spell"))
	model.Parent = vfxRoot

	local flatDir = typeof(dir) == "Vector3" and Vector3.new(dir.X, 0, dir.Z) or Vector3.new(0, 0, -1)
	if flatDir.Magnitude <= 0.01 then
		flatDir = Vector3.new(0, 0, -1)
	else
		flatDir = flatDir.Unit
	end
	local base = CFrame.lookAt(origin, origin + flatDir)
	local ring = ensurePart(model, "CastRing", Vector3.new(1.6, 0.08, 1.6) * scale, primary, 0.34, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(origin - Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local notch = ensurePart(model, "CastNotch", Vector3.new(0.18, 0.18, 0.72) * scale, secondary, 0.12, Enum.Material.Neon)
	notch.CFrame = base * CFrame.new(0, -0.15, -0.95 * scale)

	addProfileAccents(model, ring.CFrame, scale, primary, secondary, stats, "cast")
	addBurstEmitter(notch, primary, secondary, stats and stats.isCombo and 12 or 7, math.clamp(scale * 0.55, 0.45, 1.0))
	TweenService:Create(ring, TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(2.5, 0.08, 2.5) * scale,
		Transparency = 1,
	}):Play()
	TweenService:Create(notch, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()
	Debris:AddItem(model, 0.32)
end

local function getWindBladeTemplate()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	local template = animations and animations:FindFirstChild("WindBlade")
	if template and template:IsA("BasePart") then
		return template
	end
	return nil
end

local function findWindBladeSoundByNames(root, candidates)
	if not root or type(candidates) ~= "table" then
		return nil
	end

	for _, name in ipairs(candidates) do
		local sound = root:FindFirstChild(name, true)
		if sound and sound:IsA("Sound") then
			return sound
		end
	end

	return nil
end

local queueWindBladeAudioPreload

local function markWindBladeAudioNeedsPreload()
	windBladeAudioPreloadGeneration += 1
end

local function normalizeWindBladeSound(sound)
	sound.Looped = false
	sound.PlayOnRemove = false
	sound.TimePosition = 0
	sound.RollOffMaxDistance = math.max(sound.RollOffMaxDistance, WIND_BLADE_AUDIO_ROLLOFF_MAX_DISTANCE)
	sound.RollOffMinDistance = math.max(sound.RollOffMinDistance, 10)
end

local function createWindBladeAudioEmitter(variant, index, soundTemplate)
	local emitter = Instance.new("Part")
	emitter.Name = ("WindBladeAudioEmitter%d_%d"):format(variant, index)
	emitter.Size = Vector3.new(0.2, 0.2, 0.2)
	emitter.Transparency = 1
	applyPartDefaults(emitter)
	emitter.Parent = vfxRoot

	local sound = soundTemplate:Clone()
	sound.Name = ("WindBladePoolSound%d"):format(variant)
	normalizeWindBladeSound(sound)
	sound.Parent = emitter

	return {
		emitter = emitter,
		sound = sound,
	}
end

local function ensureWindBladeAudioPool(template)
	if not template then
		return
	end

	for variant, candidateNames in pairs(WIND_BLADE_SOUND_NAMES) do
		local soundTemplate = windBladeSoundTemplates[variant]
		if soundTemplate and soundTemplate.Parent ~= script then
			soundTemplate = nil
			windBladeSoundTemplates[variant] = nil
		end

		if not soundTemplate then
			local sourceSound = findWindBladeSoundByNames(template, candidateNames)
			if sourceSound then
				soundTemplate = sourceSound:Clone()
				soundTemplate.Name = ("WindBladeSoundTemplate%d"):format(variant)
				normalizeWindBladeSound(soundTemplate)
				soundTemplate.Parent = script
				windBladeSoundTemplates[variant] = soundTemplate
				markWindBladeAudioNeedsPreload()
			end
		end

		if soundTemplate then
			local pool = windBladeAudioPools[variant]
			if not pool then
				pool = {}
				windBladeAudioPools[variant] = pool
				windBladeAudioPoolCursor[variant] = 1
			end

			while #pool < WIND_BLADE_AUDIO_POOL_SIZE do
				pool[#pool + 1] = createWindBladeAudioEmitter(variant, #pool + 1, soundTemplate)
				markWindBladeAudioNeedsPreload()
			end
		end
	end

	queueWindBladeAudioPreload()
end

queueWindBladeAudioPreload = function()
	if windBladeAudioPreloadInFlight or windBladeAudioPreloadedGeneration >= windBladeAudioPreloadGeneration then
		return
	end

	local sounds = {}
	for _, soundTemplate in pairs(windBladeSoundTemplates) do
		if soundTemplate and soundTemplate.Parent then
			sounds[#sounds + 1] = soundTemplate
		end
	end
	for _, pool in pairs(windBladeAudioPools) do
		for _, entry in ipairs(pool) do
			if entry.sound and entry.sound.Parent then
				sounds[#sounds + 1] = entry.sound
			end
		end
	end

	if #sounds <= 0 then
		return
	end

	local preloadGeneration = windBladeAudioPreloadGeneration
	windBladeAudioPreloadInFlight = true
	task.spawn(function()
		local ok = pcall(function()
			ContentProvider:PreloadAsync(sounds)
		end)
		if ok then
			windBladeAudioPreloadedGeneration = math.max(windBladeAudioPreloadedGeneration, preloadGeneration)
		end
		windBladeAudioPreloadInFlight = false
		queueWindBladeAudioPreload()
	end)
end

ensureWindBladeAudioPool(getWindBladeTemplate())

local function getFlatDirection(dir)
	if typeof(dir) ~= "Vector3" then
		return Vector3.new(0, 0, -1)
	end

	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude <= 0.01 then
		return Vector3.new(0, 0, -1)
	end

	return flat.Unit
end

local function getWindBladeEmitCount(emitterName)
	for prefix, count in pairs(WIND_BLADE_EMIT_COUNTS) do
		if string.sub(emitterName, 1, #prefix) == prefix then
			return count
		end
	end
	return 2
end

local function findWindBladeSound(effect, variant)
	local candidates = WIND_BLADE_SOUND_NAMES[variant]
	return findWindBladeSoundByNames(effect, candidates)
end

local function prepareWindBladeEffect(effect)
	if effect:IsA("BasePart") then
		applyPartDefaults(effect)
		effect.Anchored = true
	end

	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("BasePart") then
			applyPartDefaults(descendant)
			descendant.Anchored = true
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end
end

local function getWindBladeLifetime(effect)
	local maxLifetime = 0.35
	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			maxLifetime = math.max(maxLifetime, descendant.Lifetime.Max)
		elseif descendant:IsA("Sound") then
			maxLifetime = math.max(maxLifetime, tonumber(descendant.TimeLength) or 0)
		end
	end
	return maxLifetime + WIND_BLADE_AUDIO_CLEANUP_BUFFER
end

local function emitWindBladeParticles(effect)
	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant:Emit(getWindBladeEmitCount(descendant.Name))
		end
	end
end

local function startWindBladePlayback(sound)
	if not sound or not sound.Parent then
		return
	end

	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

local function getWindBladeAudioPoolEntry(variant)
	local pool = windBladeAudioPools[variant]
	if not pool or #pool <= 0 then
		return nil
	end

	local startIndex = windBladeAudioPoolCursor[variant] or 1
	for offset = 0, #pool - 1 do
		local index = ((startIndex + offset - 1) % #pool) + 1
		local entry = pool[index]
		if entry and entry.sound and not entry.sound.Playing then
			windBladeAudioPoolCursor[variant] = (index % #pool) + 1
			return entry
		end
	end

	local entry = pool[startIndex]
	windBladeAudioPoolCursor[variant] = (startIndex % #pool) + 1
	return entry
end

local function getWindBladeSoundDuration(sound)
	if not sound then
		return 0.5
	end

	local speed = math.max(0.05, tonumber(sound.PlaybackSpeed) or 1)
	return math.max(0.5, (tonumber(sound.TimeLength) or 0) / speed)
end

local function stopWindBladeEmbeddedSounds(effect)
	local sound1 = findWindBladeSound(effect, 1)
	local sound2 = findWindBladeSound(effect, 2)

	for _, sound in ipairs({ sound1, sound2 }) do
		if sound then
			sound:Stop()
			sound.TimePosition = 0
		end
	end
end

local function playWindBladeSound(effect, variant)
	stopWindBladeEmbeddedSounds(effect)

	if variant ~= 1 and variant ~= 2 then
		return
	end

	local entry = getWindBladeAudioPoolEntry(variant)
	if not entry or not entry.emitter or not entry.sound then
		return
	end

	entry.emitter.CFrame = effect.CFrame
	local playbackSound = entry.sound
	startWindBladePlayback(playbackSound)
	task.delay(WIND_BLADE_AUDIO_RETRY_DELAY, function()
		if playbackSound.Parent and not playbackSound.Playing then
			startWindBladePlayback(playbackSound)
		end
	end)
	if not playbackSound.IsLoaded then
		local loadedConnection
		loadedConnection = playbackSound.Loaded:Connect(function()
			if loadedConnection then
				loadedConnection:Disconnect()
				loadedConnection = nil
			end
			if playbackSound.Parent and not playbackSound.Playing then
				startWindBladePlayback(playbackSound)
			end
		end)
	end

	task.delay(getWindBladeSoundDuration(playbackSound) + WIND_BLADE_AUDIO_STOP_BUFFER, function()
		if playbackSound.Parent and not playbackSound.Playing then
			playbackSound.TimePosition = 0
		end
	end)
end

local function isWindBladeSpellId(spellId)
	return spellId == "WindBlade" or spellId == "GustBurst"
end

local function spawnWindBladeCastVisual(payload)
	local template = getWindBladeTemplate()
	if not template then
		return
	end
	ensureWindBladeAudioPool(template)

	local direction = getFlatDirection(payload.dir)
	local effectPos = payload.effectPos
	if typeof(effectPos) ~= "Vector3" then
		local basePos = payload.pos
		if typeof(basePos) ~= "Vector3" then
			return
		end
		local radius = math.max(0.1, tonumber(payload.radius) or tonumber(payload.stats and payload.stats.radius) or 1)
		effectPos = basePos + Vector3.new(0, 1.2, 0) + (direction * math.clamp(radius * 0.45, 2.75, 6.0))
	end

	local effect = template:Clone()
	effect.Name = "WindBladeCast"
	prepareWindBladeEffect(effect)
	effect.CFrame = CFrame.lookAt(effectPos, effectPos + direction)
	effect.Parent = vfxRoot
	playWindBladeSound(effect, tonumber(payload.windBladeSoundVariant))
	emitWindBladeParticles(effect)
	Debris:AddItem(effect, getWindBladeLifetime(effect))
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

local function destroyOrb(orb)
	if orb and orb.model then
		pcall(function()
			orb.model:Destroy()
		end)
	end
end

local function clearOrbs(cfg)
	if not cfg or not cfg.orbs then
		return
	end
	for _, orb in ipairs(cfg.orbs) do
		destroyOrb(orb)
	end
	cfg.orbs = {}
end

local function createOrbModel(id, cfg, index)
	local primary = typeof(cfg.color) == "Color3" and cfg.color or Color3.fromRGB(255, 255, 255)
	local secondary = typeof(cfg.secondaryColor) == "Color3" and cfg.secondaryColor or brightenColor(primary, 0.32)
	local level = math.max(1, tonumber(cfg.level) or 1)
	local intensity = getVisualIntensity(cfg)
	local scale = math.max(0.75, (tonumber(cfg.size) or 1.1) * math.clamp(0.96 + (intensity * 0.08), 1, 1.75))
	local baseTransparency = tonumber(cfg.transparency) or 0.18
	local function alpha(extra)
		return math.clamp(baseTransparency + (extra or 0), 0, 0.95)
	end

	local model = Instance.new("Model")
	model.Name = string.format("%s_Orb_%d", id, index)
	model.Parent = vfxRoot

	local guide = ensurePart(model, "Guide", Vector3.new(0.22, 0.22, 1.1) * scale, primary, 1, Enum.Material.SmoothPlastic)
	addPointLight(guide, primary, (tonumber(cfg.lightBrightness) or 1.7) + ((intensity - 1) * 0.55), (tonumber(cfg.lightRange) or 9) + ((level - 1) * 0.45))
	addTrail(guide, primary, secondary, scale * (0.36 + math.min(0.16, (level - 1) * 0.025)), (tonumber(cfg.trailLifetime) or 0.12) + math.min(0.06, (level - 1) * 0.008))

	local spinSpeed = 6
	local element = cfg.element

	if element == "Fire" then
		local core = ensurePart(model, "Core", Vector3.new(0.62, 0.62, 0.62) * scale, primary, alpha(-0.1), Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(0.92, 0.92, 0.92) * scale, secondary, alpha(0.3), Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local ember = ensurePart(model, "Ember", Vector3.new(0.14, 0.14, 0.62) * scale, brightenColor(primary, 0.2), alpha(-0.04), Enum.Material.Neon)
		ember.CFrame = CFrame.new(0, 0, -0.34 * scale)
		spinSpeed = 7
	elseif element == "Electricity" then
		local needle = ensurePart(model, "Needle", Vector3.new(0.16, 0.38, 1.18) * scale, primary, alpha(-0.08), Enum.Material.Neon)
		needle.CFrame = CFrame.new()
		local crossA = ensurePart(model, "CrossA", Vector3.new(0.7, 0.1, 0.24) * scale, secondary, alpha(0.02), Enum.Material.Neon)
		crossA.CFrame = CFrame.Angles(0, 0, math.rad(35))
		local crossB = ensurePart(model, "CrossB", Vector3.new(0.7, 0.1, 0.24) * scale, secondary, alpha(0.02), Enum.Material.Neon)
		crossB.CFrame = CFrame.Angles(0, 0, math.rad(-35))
		local tail = ensurePart(model, "Tail", Vector3.new(0.34, 0.34, 0.34) * scale, brightenColor(primary, 0.22), alpha(0.1), Enum.Material.Glass, Enum.PartType.Ball)
		tail.CFrame = CFrame.new(0, 0, 0.28 * scale)
		spinSpeed = 10
	elseif element == "Air" then
		local blade = ensurePart(model, "Blade", Vector3.new(0.12, 0.54, 1.05) * scale, primary, alpha(-0.06), Enum.Material.Neon)
		blade.CFrame = CFrame.new()
		local wingA = ensurePart(model, "WingA", Vector3.new(0.6, 0.1, 0.34) * scale, secondary, alpha(0.08), Enum.Material.Glass)
		wingA.CFrame = CFrame.Angles(0, 0, math.rad(28))
		local wingB = ensurePart(model, "WingB", Vector3.new(0.6, 0.1, 0.34) * scale, secondary, alpha(0.08), Enum.Material.Glass)
		wingB.CFrame = CFrame.Angles(0, 0, math.rad(-28))
		spinSpeed = 8
	elseif element == "Water" then
		local core = ensurePart(model, "Core", Vector3.new(0.58, 0.58, 0.58) * scale, primary, alpha(-0.04), Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(0.88, 0.88, 0.88) * scale, secondary, alpha(0.28), Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local crest = ensurePart(model, "Crest", Vector3.new(0.12, 0.36, 0.76) * scale, brightenColor(primary, 0.18), alpha(0), Enum.Material.Neon)
		crest.CFrame = CFrame.new(0, 0, -0.14 * scale)
		spinSpeed = 5
	elseif element == "Earth" then
		local rock = ensurePart(model, "Rock", Vector3.new(0.62, 0.62, 0.92) * scale, darkenColor(primary, 0.22), alpha(-0.08), Enum.Material.Slate)
		rock.CFrame = CFrame.new()
		local crystal = ensurePart(model, "Crystal", Vector3.new(0.18, 0.42, 1.12) * scale, primary, alpha(0.02), Enum.Material.Neon)
		crystal.CFrame = CFrame.new()
		spinSpeed = 4.5
	elseif element == "Void" then
		local core = ensurePart(model, "Core", Vector3.new(0.56, 0.56, 0.56) * scale, darkenColor(primary, 0.2), alpha(-0.06), Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(0.94, 0.94, 0.94) * scale, secondary, alpha(0.34), Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local band = ensurePart(model, "Band", Vector3.new(0.78, 0.1, 0.28) * scale, brightenColor(secondary, 0.14), alpha(0.06), Enum.Material.Neon)
		band.CFrame = CFrame.Angles(0, 0, math.rad(45))
		spinSpeed = 6.5
	elseif element == "Light" then
		local core = ensurePart(model, "Core", Vector3.new(0.54, 0.54, 0.54) * scale, primary, alpha(-0.08), Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(0.84, 0.84, 0.84) * scale, secondary, alpha(0.34), Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local spine = ensurePart(model, "Spine", Vector3.new(0.14, 0.46, 1.05) * scale, brightenColor(primary, 0.2), alpha(-0.02), Enum.Material.Neon)
		spine.CFrame = CFrame.new()
		spinSpeed = 5.5
	elseif element == "Physical" then
		local handle = ensurePart(model, "Handle", Vector3.new(0.12, 0.12, 0.9) * scale, darkenColor(primary, 0.28), 0, Enum.Material.Metal)
		handle.CFrame = CFrame.new()
		local headA = ensurePart(model, "HeadA", Vector3.new(0.54, 0.16, 0.24) * scale, brightenColor(primary, 0.12), 0, Enum.Material.Metal)
		headA.CFrame = CFrame.new(0.22 * scale, 0, -0.08 * scale)
		local headB = ensurePart(model, "HeadB", Vector3.new(0.54, 0.16, 0.24) * scale, brightenColor(primary, 0.12), 0, Enum.Material.Metal)
		headB.CFrame = CFrame.new(-0.22 * scale, 0, -0.08 * scale)
		spinSpeed = 9
	else
		local core = ensurePart(model, "Core", Vector3.new(0.58, 0.58, 0.58) * scale, primary, alpha(-0.06), Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(0.86, 0.86, 0.86) * scale, secondary, alpha(0.28), Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
	end

	addProfileAccents(model, CFrame.new(), scale, primary, secondary, cfg, "orbit")

	if level >= 2 then
		local aura = ensurePart(model, "Aura", Vector3.new(1.14, 1.14, 1.14) * scale, brightenColor(primary, 0.08), alpha(0.48), Enum.Material.Glass, Enum.PartType.Ball)
		aura.CFrame = CFrame.new()
	end
	if level >= 4 then
		local ring = ensurePart(model, "LevelRing", Vector3.new(0.92, 0.08, 0.92) * scale, secondary, alpha(0.12), Enum.Material.Neon)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.Angles(0, 0, math.rad(90))
	end
	if level >= 6 then
		local sparkA = ensurePart(model, "SparkA", Vector3.new(0.14, 0.14, 0.14) * scale, brightenColor(primary, 0.2), alpha(-0.08), Enum.Material.Neon, Enum.PartType.Ball)
		sparkA.CFrame = CFrame.new(0.46 * scale, 0, 0)
		local sparkB = ensurePart(model, "SparkB", Vector3.new(0.14, 0.14, 0.14) * scale, brightenColor(secondary, 0.2), alpha(-0.04), Enum.Material.Glass, Enum.PartType.Ball)
		sparkB.CFrame = CFrame.new(-0.46 * scale, 0, 0)
	end

	return {
		model = model,
		spin = (index - 1) * 0.35,
		spinSpeed = spinSpeed + math.min(6, (level - 1) * 0.45),
	}
end

local function rebuildOrbs(id, cfg)
	clearOrbs(cfg)
	cfg.orbs = {}
	for index = 1, math.max(0, cfg.count or 0) do
		table.insert(cfg.orbs, createOrbModel(id, cfg, index))
	end
end

local function spawnImpactVisual(pos, stats)
	local primary, secondary = getVisualColors(stats)
	local intensity = getVisualIntensity(stats)
	local scale = math.clamp((0.8 + ((stats.radius or stats.width or 2) * 0.08)) * (0.92 + intensity * 0.15), 0.75, 2.2)
	local model = Instance.new("Model")
	model.Name = "SpellImpact"
	model.Parent = vfxRoot

	local flash = ensurePart(model, "Flash", Vector3.new(1, 1, 1) * scale, primary, 0.12, Enum.Material.Neon, Enum.PartType.Ball)
	flash.CFrame = CFrame.new(pos)
	local shell = ensurePart(model, "Shell", Vector3.new(1.35, 1.35, 1.35) * scale, secondary, 0.48, Enum.Material.Glass, Enum.PartType.Ball)
	shell.CFrame = CFrame.new(pos)
	local pulse = ensurePart(model, "Pulse", Vector3.new(0.8, 0.14, 0.8) * scale, brightenColor(primary, 0.16), 0.28, Enum.Material.Neon)
	pulse.Shape = Enum.PartType.Cylinder
	pulse.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))

	addPointLight(flash, primary, 2.8 + ((intensity - 1) * 1.1), 12 + math.floor((intensity - 1) * 4))
	addBurstEmitter(flash, primary, secondary, math.clamp(math.floor(10 + (scale * 7) + ((stats.level or 1) * 2)), 10, 30), scale)
	addAmbientEmitter(flash, primary, secondary, math.clamp(math.floor(10 + (intensity * 7)), 10, 24), math.clamp(scale * 0.55, 0.45, 1.5))
	addProfileAccents(model, CFrame.new(pos), scale, primary, secondary, stats, "impact")

	playTween(flash, 0.18, { Size = Vector3.new(2.4, 2.4, 2.4) * scale, Transparency = 1 }, Enum.EasingStyle.Quart)
	playTween(shell, 0.24, { Size = Vector3.new(3.4, 3.4, 3.4) * scale, Transparency = 1 }, Enum.EasingStyle.Quart)
	playTween(pulse, 0.22, { Size = Vector3.new(4.4, 0.14, 4.4) * scale, Transparency = 1 }, Enum.EasingStyle.Quart)

	Debris:AddItem(model, 0.35)
end

local function spawnRingVisual(pos, radius, duration, stats)
	local primary, secondary = getVisualColors(stats)
	local intensity = getVisualIntensity(stats)
	local visualRadius = radius * (0.96 + intensity * 0.05)
	local model = Instance.new("Model")
	model.Name = "SpellRing"
	model.Parent = vfxRoot

	local outer = ensurePart(model, "Outer", Vector3.new(visualRadius * 2, 0.35, visualRadius * 2), primary, 0.58, Enum.Material.Neon)
	outer.Shape = Enum.PartType.Cylinder
	outer.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))

	local inner = ensurePart(
		model,
		"Inner",
		Vector3.new(visualRadius * 1.45, 0.2, visualRadius * 1.45),
		secondary,
		0.76,
		stats and stats.spellType == "Physical" and Enum.Material.Metal or Enum.Material.Glass
	)
	inner.Shape = Enum.PartType.Cylinder
	inner.CFrame = outer.CFrame

	local pulse = ensurePart(model, "Pulse", Vector3.new(visualRadius * 1.05, 0.12, visualRadius * 1.05), brightenColor(primary, 0.18), 0.82, Enum.Material.Neon)
	pulse.Shape = Enum.PartType.Cylinder
	pulse.CFrame = outer.CFrame

	local anchor = ensurePart(model, "Anchor", Vector3.new(0.2, 0.2, 0.2), primary, 1, Enum.Material.SmoothPlastic)
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0))

	addPointLight(anchor, primary, 1.6 + ((intensity - 1) * 0.9), math.clamp((visualRadius * 2.4) + ((stats.level or 1) * 0.7), 10, 24))
	addAmbientEmitter(anchor, primary, secondary, math.clamp(math.floor(8 + visualRadius + (intensity * 4)), 12, 24), math.clamp(visualRadius * 0.12 * intensity, 0.55, 1.6))
	addProfileAccents(model, outer.CFrame, math.clamp(visualRadius * 0.22, 0.8, 2.2), primary, secondary, stats, "ring")
	playTween(pulse, math.min(duration, 0.6), { Size = Vector3.new(visualRadius * 2.25, 0.12, visualRadius * 2.25), Transparency = 1 }, Enum.EasingStyle.Sine)

	Debris:AddItem(model, duration)
end

local function spawnNovaVisual(pos, radius, stats)
	local primary, secondary = getVisualColors(stats)
	local intensity = getVisualIntensity(stats)
	local visualRadius = radius * (0.94 + intensity * 0.06)
	local model = Instance.new("Model")
	model.Name = "SpellNova"
	model.Parent = vfxRoot

	local disk = ensurePart(model, "Disk", Vector3.new(visualRadius * 0.5, 0.35, visualRadius * 0.5), primary, 0.22, Enum.Material.Neon)
	disk.Shape = Enum.PartType.Cylinder
	disk.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))

	local core = ensurePart(model, "Core", Vector3.new(visualRadius * 0.3, visualRadius * 0.3, visualRadius * 0.3), secondary, 0.28, Enum.Material.Glass, Enum.PartType.Ball)
	core.CFrame = CFrame.new(pos + Vector3.new(0, 0.35, 0))
	local shell = ensurePart(model, "Shell", Vector3.new(visualRadius * 0.55, visualRadius * 0.55, visualRadius * 0.55), brightenColor(primary, 0.14), 0.72, Enum.Material.Glass, Enum.PartType.Ball)
	shell.CFrame = core.CFrame

	addPointLight(core, primary, 2.6 + ((intensity - 1) * 1.15), math.clamp((visualRadius * 2.4) + ((stats.level or 1) * 0.7), 12, 26))
	addBurstEmitter(core, primary, secondary, math.clamp(math.floor((visualRadius * 2.1) + ((stats.level or 1) * 2)), 14, 30), math.clamp(visualRadius * 0.1 * intensity, 0.9, 2.1))
	addAmbientEmitter(core, primary, secondary, math.clamp(math.floor(10 + (intensity * 5)), 10, 22), math.clamp(visualRadius * 0.07 * intensity, 0.45, 1.3))
	addProfileAccents(model, disk.CFrame, math.clamp(visualRadius * 0.18, 0.85, 2.0), primary, secondary, stats, "nova")

	playTween(disk, 0.22, { Size = Vector3.new(visualRadius * 2.25, 0.35, visualRadius * 2.25), Transparency = 1 }, Enum.EasingStyle.Quart)
	playTween(core, 0.24, { Size = Vector3.new(visualRadius * 1.35, visualRadius * 1.35, visualRadius * 1.35), Transparency = 1 }, Enum.EasingStyle.Quart)
	playTween(shell, 0.26, { Size = Vector3.new(visualRadius * 1.95, visualRadius * 1.95, visualRadius * 1.95), Transparency = 1 }, Enum.EasingStyle.Quart)

	Debris:AddItem(model, 0.35)
end

local function spawnBeamVisual(origin, dir, range, width, duration, stats)
	local primary, secondary = getVisualColors(stats)
	local intensity = getVisualIntensity(stats)
	local visualWidth = width * (0.95 + intensity * 0.04)
	local model = Instance.new("Model")
	model.Name = "SpellBeam"
	model.Parent = vfxRoot

	local beamCFrame = CFrame.lookAt(origin + (dir * (range * 0.5)), origin + dir) * CFrame.new(0, 0, -(range * 0.5))
	local outer = ensurePart(model, "Outer", Vector3.new(visualWidth * 1.08, visualWidth * 1.08, range), primary, 0.64, Enum.Material.Glass)
	outer.CFrame = beamCFrame

	local coreWidth = math.max(0.35, visualWidth * 0.55)
	local core = ensurePart(model, "Core", Vector3.new(coreWidth, coreWidth, range), secondary, 0.2, Enum.Material.Neon)
	core.CFrame = beamCFrame
	local shell = ensurePart(model, "Shell", Vector3.new(math.max(coreWidth * 1.45, 0.5), math.max(coreWidth * 1.45, 0.5), range), brightenColor(primary, 0.16), 0.8, Enum.Material.Glass)
	shell.CFrame = beamCFrame

	local tipSize = math.max(0.8, visualWidth)
	local tip = ensurePart(model, "Tip", Vector3.new(tipSize, tipSize, tipSize), primary, 0.1, Enum.Material.Neon, Enum.PartType.Ball)
	tip.CFrame = CFrame.new(origin + (dir * range))

	local anchor = ensurePart(model, "Anchor", Vector3.new(0.2, 0.2, 0.2), primary, 1, Enum.Material.SmoothPlastic)
	anchor.CFrame = CFrame.new(origin + (dir * math.min(range * 0.35, 10)))

	addPointLight(anchor, primary, 2.4 + ((intensity - 1) * 1.2), math.clamp((visualWidth * 4.4) + 8 + ((stats.level or 1) * 0.7), 10, 26))
	addAmbientEmitter(anchor, primary, secondary, math.clamp(math.floor((visualWidth * 3.4) + (intensity * 4)), 12, 24), math.clamp(visualWidth * 0.18 * intensity, 0.5, 1.4))
	addProfileAccents(model, beamCFrame, math.clamp(visualWidth * 0.65, 0.7, 2.2), primary, secondary, stats, "beam")

	playTween(outer, duration, { Transparency = 0.9 }, Enum.EasingStyle.Sine)
	playTween(core, duration, { Transparency = 1 }, Enum.EasingStyle.Sine)
	playTween(shell, duration, { Transparency = 1 }, Enum.EasingStyle.Sine)
	playTween(tip, duration, { Transparency = 1 }, Enum.EasingStyle.Sine)

	Debris:AddItem(model, duration + 0.1)
end

local function createProjectileVisual(stats, origin, dir)
	local primary, secondary = getVisualColors(stats)
	local intensity = getVisualIntensity(stats)
	local level = math.max(1, tonumber(stats and stats.level) or 1)
	local visualScale = getLevelVisualScale(stats, 1)
	local model = Instance.new("Model")
	model.Name = string.format("%sProjectile", tostring(stats and stats.spellId or "Spell"))
	model.Parent = vfxRoot

	local guide = ensurePart(model, "Guide", Vector3.new(0.28, 0.28, 1.8) * visualScale, primary, 1, Enum.Material.SmoothPlastic)
	addPointLight(guide, primary, 1.8 + ((intensity - 1) * 1.15), 10 + math.min(8, level * 1.1))
	addTrail(
		guide,
		primary,
		secondary,
		(0.75 + math.min(0.18, (stats.basePower or 0) * 0.08)) * math.clamp(0.95 + ((level - 1) * 0.05), 1, 1.5),
		0.12 + math.min(0.09, ((stats.upgradePower or 0) * 0.005) + ((level - 1) * 0.01))
	)
	addAmbientEmitter(guide, primary, secondary, math.clamp(8 + (level * 4), 12, 34), math.clamp(0.4 + (intensity * 0.18), 0.45, 1.2))

	local spinSpeed = 7
	local element = stats.element

	if element == "Fire" then
		local core = ensurePart(model, "Core", Vector3.new(0.9, 0.9, 0.9) * visualScale, primary, 0.06, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(1.25, 1.25, 1.25) * visualScale, secondary, 0.55, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local emberA = ensurePart(model, "EmberA", Vector3.new(0.18, 0.18, 0.75) * visualScale, brightenColor(primary, 0.2), 0.1, Enum.Material.Neon)
		emberA.CFrame = CFrame.new(0.22 * visualScale, 0, -0.48 * visualScale)
		local emberB = ensurePart(model, "EmberB", Vector3.new(0.18, 0.18, 0.75) * visualScale, brightenColor(primary, 0.2), 0.1, Enum.Material.Neon)
		emberB.CFrame = CFrame.new(-0.22 * visualScale, 0, -0.48 * visualScale)
		spinSpeed = 9
	elseif element == "Electricity" then
		local needle = ensurePart(model, "Needle", Vector3.new(0.22, 0.5, 1.9) * visualScale, primary, 0.05, Enum.Material.Neon)
		needle.CFrame = CFrame.new()
		local crossA = ensurePart(model, "CrossA", Vector3.new(0.9, 0.12, 0.35) * visualScale, secondary, 0.18, Enum.Material.Neon)
		crossA.CFrame = CFrame.Angles(0, 0, math.rad(35))
		local crossB = ensurePart(model, "CrossB", Vector3.new(0.9, 0.12, 0.35) * visualScale, secondary, 0.18, Enum.Material.Neon)
		crossB.CFrame = CFrame.Angles(0, 0, math.rad(-35))
		local tail = ensurePart(model, "Tail", Vector3.new(0.48, 0.48, 0.48) * visualScale, brightenColor(primary, 0.25), 0.28, Enum.Material.Glass, Enum.PartType.Ball)
		tail.CFrame = CFrame.new(0, 0, 0.55 * visualScale)
		spinSpeed = 14
	elseif element == "Air" then
		local blade = ensurePart(model, "Blade", Vector3.new(0.18, 0.82, 1.75) * visualScale, primary, 0.08, Enum.Material.Neon)
		blade.CFrame = CFrame.new()
		local wingA = ensurePart(model, "WingA", Vector3.new(0.85, 0.12, 0.62) * visualScale, secondary, 0.24, Enum.Material.Glass)
		wingA.CFrame = CFrame.new(0, 0, -0.1 * visualScale) * CFrame.Angles(0, 0, math.rad(32))
		local wingB = ensurePart(model, "WingB", Vector3.new(0.85, 0.12, 0.62) * visualScale, secondary, 0.24, Enum.Material.Glass)
		wingB.CFrame = CFrame.new(0, 0, -0.1 * visualScale) * CFrame.Angles(0, 0, math.rad(-32))
		local tip = ensurePart(model, "Tip", Vector3.new(0.12, 0.45, 0.55) * visualScale, brightenColor(primary, 0.2), 0.1, Enum.Material.Neon)
		tip.CFrame = CFrame.new(0, 0, -0.72 * visualScale)
		spinSpeed = 10
	elseif element == "Water" then
		local core = ensurePart(model, "Core", Vector3.new(0.82, 0.82, 0.82) * visualScale, primary, 0.1, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(1.18, 1.18, 1.18) * visualScale, secondary, 0.58, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local crest = ensurePart(model, "Crest", Vector3.new(0.18, 0.58, 1.1) * visualScale, brightenColor(primary, 0.24), 0.2, Enum.Material.Neon)
		crest.CFrame = CFrame.new(0, 0, -0.22 * visualScale)
		local dropA = ensurePart(model, "DropA", Vector3.new(0.28, 0.28, 0.28) * visualScale, secondary, 0.16, Enum.Material.Glass, Enum.PartType.Ball)
		dropA.CFrame = CFrame.new(0.32 * visualScale, 0, 0.12 * visualScale)
		local dropB = ensurePart(model, "DropB", Vector3.new(0.28, 0.28, 0.28) * visualScale, secondary, 0.16, Enum.Material.Glass, Enum.PartType.Ball)
		dropB.CFrame = CFrame.new(-0.32 * visualScale, 0, 0.12 * visualScale)
		spinSpeed = 6
	elseif element == "Earth" then
		local rock = ensurePart(model, "Rock", Vector3.new(0.82, 0.82, 1.35) * visualScale, darkenColor(primary, 0.25), 0.05, Enum.Material.Slate)
		rock.CFrame = CFrame.new()
		local crystal = ensurePart(model, "Crystal", Vector3.new(0.28, 0.56, 1.85) * visualScale, primary, 0.15, Enum.Material.Neon)
		crystal.CFrame = CFrame.new()
		local shardA = ensurePart(model, "ShardA", Vector3.new(0.26, 0.26, 0.85) * visualScale, secondary, 0.18, Enum.Material.Glass)
		shardA.CFrame = CFrame.new(0.28 * visualScale, 0, -0.18 * visualScale)
		local shardB = ensurePart(model, "ShardB", Vector3.new(0.26, 0.26, 0.85) * visualScale, secondary, 0.18, Enum.Material.Glass)
		shardB.CFrame = CFrame.new(-0.28 * visualScale, 0, -0.18 * visualScale)
		spinSpeed = 5
	elseif element == "Void" then
		local core = ensurePart(model, "Core", Vector3.new(0.78, 0.78, 0.78) * visualScale, darkenColor(primary, 0.22), 0.08, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(1.22, 1.22, 1.22) * visualScale, secondary, 0.62, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local bandA = ensurePart(model, "BandA", Vector3.new(1.0, 0.12, 0.42) * visualScale, brightenColor(secondary, 0.18), 0.26, Enum.Material.Neon)
		bandA.CFrame = CFrame.Angles(0, 0, math.rad(45))
		local bandB = ensurePart(model, "BandB", Vector3.new(0.12, 1.0, 0.42) * visualScale, brightenColor(primary, 0.1), 0.36, Enum.Material.Glass)
		bandB.CFrame = CFrame.Angles(0, 0, math.rad(45))
		spinSpeed = 8
	elseif element == "Light" then
		local core = ensurePart(model, "Core", Vector3.new(0.72, 0.72, 0.72) * visualScale, primary, 0.08, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(1.1, 1.1, 1.1) * visualScale, secondary, 0.6, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
		local spine = ensurePart(model, "Spine", Vector3.new(0.2, 0.65, 1.85) * visualScale, brightenColor(primary, 0.2), 0.12, Enum.Material.Neon)
		spine.CFrame = CFrame.new()
		local haloA = ensurePart(model, "HaloA", Vector3.new(0.26, 0.26, 0.26) * visualScale, secondary, 0.16, Enum.Material.Glass, Enum.PartType.Ball)
		haloA.CFrame = CFrame.new(0.38 * visualScale, 0, -0.1 * visualScale)
		local haloB = ensurePart(model, "HaloB", Vector3.new(0.26, 0.26, 0.26) * visualScale, secondary, 0.16, Enum.Material.Glass, Enum.PartType.Ball)
		haloB.CFrame = CFrame.new(-0.38 * visualScale, 0, -0.1 * visualScale)
		spinSpeed = 7
	elseif element == "Physical" then
		local handle = ensurePart(model, "Handle", Vector3.new(0.16, 0.16, 1.45) * visualScale, darkenColor(primary, 0.35), 0, Enum.Material.Metal)
		handle.CFrame = CFrame.new()
		local bladeA = ensurePart(model, "BladeA", Vector3.new(0.95, 0.24, 0.42) * visualScale, brightenColor(primary, 0.18), 0, Enum.Material.Metal)
		bladeA.CFrame = CFrame.new(0.38 * visualScale, 0, -0.18 * visualScale)
		local bladeB = ensurePart(model, "BladeB", Vector3.new(0.95, 0.24, 0.42) * visualScale, brightenColor(primary, 0.18), 0, Enum.Material.Metal)
		bladeB.CFrame = CFrame.new(-0.38 * visualScale, 0, -0.18 * visualScale)
		local pommel = ensurePart(model, "Pommel", Vector3.new(0.25, 0.25, 0.25) * visualScale, secondary, 0, Enum.Material.Metal, Enum.PartType.Ball)
		pommel.CFrame = CFrame.new(0, 0, 0.62 * visualScale)
		local spike = ensurePart(model, "Spike", Vector3.new(0.12, 0.32, 0.55) * visualScale, secondary, 0, Enum.Material.Metal)
		spike.CFrame = CFrame.new(0, 0, -0.78 * visualScale)
		spinSpeed = 16
	else
		local core = ensurePart(model, "Core", Vector3.new(0.82, 0.82, 0.82) * visualScale, primary, 0.08, Enum.Material.Neon, Enum.PartType.Ball)
		core.CFrame = CFrame.new()
		local shell = ensurePart(model, "Shell", Vector3.new(1.15, 1.15, 1.15) * visualScale, secondary, 0.55, Enum.Material.Glass, Enum.PartType.Ball)
		shell.CFrame = CFrame.new()
	end

	addProfileAccents(model, CFrame.new(), visualScale, primary, secondary, stats, "projectile")

	if level >= 2 then
		local aura = ensurePart(model, "Aura", Vector3.new(1.38, 1.38, 1.38) * visualScale, brightenColor(primary, 0.08), 0.82, Enum.Material.Glass, Enum.PartType.Ball)
		aura.CFrame = CFrame.new()
	end
	if level >= 4 then
		local ring = ensurePart(model, "LevelRing", Vector3.new(1.08, 0.1, 1.08) * visualScale, secondary, 0.34, Enum.Material.Neon)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.Angles(0, 0, math.rad(90))
	end
	if level >= 6 then
		local satelliteA = ensurePart(model, "SatelliteA", Vector3.new(0.16, 0.16, 0.16) * visualScale, brightenColor(primary, 0.22), 0.08, Enum.Material.Neon, Enum.PartType.Ball)
		satelliteA.CFrame = CFrame.new(0.52 * visualScale, 0, 0)
		local satelliteB = ensurePart(model, "SatelliteB", Vector3.new(0.16, 0.16, 0.16) * visualScale, brightenColor(secondary, 0.22), 0.12, Enum.Material.Glass, Enum.PartType.Ball)
		satelliteB.CFrame = CFrame.new(-0.52 * visualScale, 0, 0)
	end

	model:PivotTo(CFrame.lookAt(origin, origin + dir))

	return {
		model = model,
		spin = 0,
		spinSpeed = spinSpeed + math.min(8, (level - 1) * 0.8),
	}
end

local function destroyProjectileVisual(projectile)
	if projectile and projectile.model and projectile.model.Parent then
		projectile.model:Destroy()
	end
end

local function spawnProjectileVisual(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local origin = payload.origin
	local dir = payload.dir
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or dir.Magnitude <= 0.01 then
		return
	end

	dir = dir.Unit
	local speed = math.max(1, tonumber(payload.speed) or 90)
	local range = math.max(0.1, tonumber(payload.range) or 0.1)
	local startTime = tonumber(payload.startTime) or workspace:GetServerTimeNow()
	local age = math.max(0, workspace:GetServerTimeNow() - startTime)
	local traveled = math.min(range, speed * age)
	if traveled >= range then
		return
	end

	local pos = origin + (dir * traveled)
	local visual = createProjectileVisual(payload.stats or {}, pos, dir)
	table.insert(activeProjectiles, {
		model = visual.model,
		pos = pos,
		dir = dir,
		speed = speed,
		range = range,
		traveled = traveled,
		spin = visual.spin or 0,
		spinSpeed = visual.spinSpeed or 0,
	})
end

local function handleOrbitEvent(id, enabled, params)
	id = tostring(id)
	local cfg = activeOrbits[id]

	if not enabled then
		if cfg then
			clearOrbs(cfg)
			activeOrbits[id] = nil
		end
		return
	end

	if not cfg then
		cfg = { t = 0, orbs = {} }
		activeOrbits[id] = cfg
	end

	for key, value in pairs(params or {}) do
		cfg[key] = value
	end
	cfg.enabled = true
	cfg.count = math.max(0, math.floor(tonumber(cfg.count) or 0))
	cfg.radius = tonumber(cfg.radius) or 5.5
	cfg.orbitSpeed = tonumber(cfg.orbitSpeed) or 2.6
	cfg.height = tonumber(cfg.height) or 1.1
	cfg.orbs = cfg.orbs or {}

	rebuildOrbs(id, cfg)
end

local function handlePayload(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local action = payload.action
	if action == "impact" then
		if typeof(payload.pos) == "Vector3" then
			spawnImpactVisual(payload.pos, payload.stats or {})
		end
	elseif action == "ring" then
		if typeof(payload.pos) == "Vector3" then
			spawnCastVisual(payload.pos + Vector3.new(0, 1.0, 0), Vector3.new(0, 0, -1), payload.stats or {})
			spawnRingVisual(
				payload.pos,
				math.max(0.1, tonumber(payload.radius) or tonumber(payload.stats and payload.stats.radius) or 1),
				math.max(0.05, tonumber(payload.duration) or 0.3),
				payload.stats or {}
			)
		end
	elseif action == "nova" then
		local spellId = tostring(payload.stats and payload.stats.spellId or "")
		if isWindBladeSpellId(spellId) then
			if typeof(payload.pos) == "Vector3" then
				spawnCastVisual(payload.pos + Vector3.new(0, 1.0, 0), payload.dir, payload.stats or {})
			end
			spawnWindBladeCastVisual(payload)
		elseif typeof(payload.pos) == "Vector3" then
			spawnCastVisual(payload.pos + Vector3.new(0, 1.0, 0), payload.dir, payload.stats or {})
			spawnNovaVisual(
				payload.pos,
				math.max(0.1, tonumber(payload.radius) or tonumber(payload.stats and payload.stats.radius) or 1),
				payload.stats or {}
			)
		end
	elseif action == "beam" then
		if typeof(payload.origin) == "Vector3" and typeof(payload.dir) == "Vector3" and payload.dir.Magnitude > 0.01 then
			spawnCastVisual(payload.origin, payload.dir.Unit, payload.stats or {})
			spawnBeamVisual(
				payload.origin,
				payload.dir.Unit,
				math.max(0.1, tonumber(payload.range) or 1),
				math.max(0.1, tonumber(payload.width) or tonumber(payload.stats and payload.stats.width) or 1),
				math.max(0.05, tonumber(payload.duration) or 0.2),
				payload.stats or {}
			)
		end
	elseif action == "projectile" then
		if typeof(payload.origin) == "Vector3" and typeof(payload.dir) == "Vector3" then
			spawnCastVisual(payload.origin, payload.dir, payload.stats or {})
		end
		spawnProjectileVisual(payload)
	end
end

SpellVFXEvent.OnClientEvent:Connect(function(arg1, arg2, arg3)
	if typeof(arg1) == "table" then
		handlePayload(arg1)
	else
		handleOrbitEvent(arg1, arg2, arg3)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if isPaused() then
		return
	end

	local hrp = getHRP()
	if hrp then
		for id, cfg in pairs(activeOrbits) do
			local count = math.max(0, math.floor(tonumber(cfg.count) or 0))
			if count <= 0 then
				clearOrbs(cfg)
				activeOrbits[id] = nil
				continue
			end

			local orbs = cfg.orbs or {}
			if #orbs ~= count then
				rebuildOrbs(id, cfg)
				orbs = cfg.orbs or {}
			end

			cfg.t = (cfg.t or 0) + ((tonumber(cfg.orbitSpeed) or 2.6) * dt)
			local radius = tonumber(cfg.radius) or 5.5
			local height = tonumber(cfg.height) or 1.1
			for index, orb in ipairs(orbs) do
				if orb.model and orb.model.Parent then
					local angle = (cfg.t or 0) + ((index / count) * math.pi * 2)
					local pos = hrp.Position + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
					orb.spin = (orb.spin or 0) + ((orb.spinSpeed or 0) * dt)
					orb.model:PivotTo(CFrame.lookAt(pos, pos + hrp.CFrame.LookVector) * CFrame.Angles(0, 0, orb.spin or 0))
				end
			end
		end
	end

	for index = #activeProjectiles, 1, -1 do
		local projectile = activeProjectiles[index]
		if not projectile.model or not projectile.model.Parent then
			table.remove(activeProjectiles, index)
			continue
		end

		local step = projectile.speed * dt
		projectile.traveled += step
		if projectile.traveled >= projectile.range then
			destroyProjectileVisual(projectile)
			table.remove(activeProjectiles, index)
			continue
		end

		projectile.pos += projectile.dir * step
		projectile.spin = (projectile.spin or 0) + ((projectile.spinSpeed or 0) * dt)
		projectile.model:PivotTo(
			CFrame.lookAt(projectile.pos, projectile.pos + projectile.dir) * CFrame.Angles(0, 0, projectile.spin or 0)
		)
	end
end)
