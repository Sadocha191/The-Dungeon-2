-- SpellVFXClient.lua
-- Renders orbit spell VFX on the client so they stay locked to the player with smooth motion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpellVFXEvent = remotes:WaitForChild("SpellVFXEvent")

local vfxRoot = workspace:FindFirstChild("SpellVFX")
if not vfxRoot then
	vfxRoot = Instance.new("Folder")
	vfxRoot.Name = "SpellVFX"
	vfxRoot.Parent = workspace
end

local active = {}

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

local function getVisualIntensity(cfg)
	local level = math.max(1, tonumber(cfg and cfg.level) or 1)
	local intensity = tonumber(cfg and cfg.visualIntensity) or 1
	return math.max(1, intensity + ((level - 1) * 0.04))
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
		local rock = ensurePart(model, "Rock", Vector3.new(0.62, 0.62, 0.92) * scale, blendColor(primary, Color3.new(0, 0, 0), 0.22), alpha(-0.08), Enum.Material.Slate)
		rock.CFrame = CFrame.new()
		local crystal = ensurePart(model, "Crystal", Vector3.new(0.18, 0.42, 1.12) * scale, primary, alpha(0.02), Enum.Material.Neon)
		crystal.CFrame = CFrame.new()
		spinSpeed = 4.5
	elseif element == "Void" then
		local core = ensurePart(model, "Core", Vector3.new(0.56, 0.56, 0.56) * scale, blendColor(primary, Color3.new(0, 0, 0), 0.2), alpha(-0.06), Enum.Material.Neon, Enum.PartType.Ball)
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
		local handle = ensurePart(model, "Handle", Vector3.new(0.12, 0.12, 0.9) * scale, blendColor(primary, Color3.new(0, 0, 0), 0.28), 0, Enum.Material.Metal)
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

SpellVFXEvent.OnClientEvent:Connect(function(id, enabled, params)
	if not enabled then
		local cfg = active[id]
		if cfg then
			clearOrbs(cfg)
		end
		active[id] = nil
		return
	end

	params = params or {}
	local cfg = active[id]
	if not cfg then
		cfg = { orbs = {}, t = 0 }
		active[id] = cfg
	end

	cfg.count = tonumber(params.count) or 0
	cfg.radius = tonumber(params.radius) or 5
	cfg.orbitSpeed = tonumber(params.orbitSpeed) or 2
	cfg.height = tonumber(params.height) or 1.5
	cfg.size = tonumber(params.size) or 1.2
	cfg.transparency = tonumber(params.transparency) or 0.2
	cfg.color = typeof(params.color) == "Color3" and params.color or Color3.fromRGB(255, 255, 255)
	cfg.secondaryColor = typeof(params.secondaryColor) == "Color3" and params.secondaryColor or brightenColor(cfg.color, 0.32)
	cfg.element = params.element
	cfg.spellType = params.spellType
	cfg.lightRange = tonumber(params.lightRange) or 9
	cfg.lightBrightness = tonumber(params.lightBrightness) or 1.7
	cfg.trailLifetime = tonumber(params.trailLifetime) or 0.12
	cfg.level = tonumber(params.level) or 1
	cfg.visualIntensity = tonumber(params.visualIntensity) or 1

	rebuildOrbs(id, cfg)
end)

RunService.RenderStepped:Connect(function(dt)
	local hrp = getHRP()
	if not hrp then
		return
	end

	local basePos = hrp.Position
	for id, cfg in pairs(active) do
		local count = cfg.count or 0
		if count <= 0 then
			clearOrbs(cfg)
			active[id] = nil
		else
			cfg.t = (cfg.t or 0) + (cfg.orbitSpeed or 2) * dt
			local radius = cfg.radius or 5
			local height = cfg.height or 1.5

			for i = 1, math.min(count, #cfg.orbs) do
				local orb = cfg.orbs[i]
				if orb and orb.model then
					local ang = cfg.t + (i / math.max(1, count)) * math.pi * 2
					local worldPos = basePos + Vector3.new(math.cos(ang) * radius, height, math.sin(ang) * radius)
					local tangent = Vector3.new(-math.sin(ang), 0, math.cos(ang))
					orb.spin = (orb.spin or 0) + (orb.spinSpeed or 0) * dt
					orb.model:PivotTo(CFrame.lookAt(worldPos, worldPos + tangent) * CFrame.Angles(0, 0, orb.spin))
				end
			end
		end
	end
end)
