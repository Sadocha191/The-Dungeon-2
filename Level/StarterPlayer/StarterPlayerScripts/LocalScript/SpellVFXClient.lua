-- SpellVFXClient.lua
-- Renders orbit and transient spell VFX fully on the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

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
			spawnRingVisual(
				payload.pos,
				math.max(0.1, tonumber(payload.radius) or tonumber(payload.stats and payload.stats.radius) or 1),
				math.max(0.05, tonumber(payload.duration) or 0.3),
				payload.stats or {}
			)
		end
	elseif action == "nova" then
		if typeof(payload.pos) == "Vector3" then
			spawnNovaVisual(
				payload.pos,
				math.max(0.1, tonumber(payload.radius) or tonumber(payload.stats and payload.stats.radius) or 1),
				payload.stats or {}
			)
		end
	elseif action == "beam" then
		if typeof(payload.origin) == "Vector3" and typeof(payload.dir) == "Vector3" and payload.dir.Magnitude > 0.01 then
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
