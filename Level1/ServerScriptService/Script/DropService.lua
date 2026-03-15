-- DropService.server.lua
-- Animated drops with idle bobbing, magnet motion and a short pickup spiral into the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name: string): RemoteEvent
	local ev = remotes:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then
		return ev
	end
	if ev then
		ev:Destroy()
	end

	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remotes
	return ev
end

local pickupIndicatorEvent = ensureRemoteEvent("PickupIndicatorEvent")

local dropsFolder = workspace:FindFirstChild("Drops")
if not dropsFolder then
	dropsFolder = Instance.new("Folder")
	dropsFolder.Name = "Drops"
	dropsFolder.Parent = workspace
end

local active = {}
local activeGlobalMagnets = {}

local ATTRACT_RADIUS = 8
local PICKUP_DIST = 2.5
local ATTRACT_SPEED_MULT = 1.15
local ATTRACT_SPEED_BONUS = 4
local ATTRACT_SPEED_MIN = 22
local GLOBAL_MAGNET_SPEED = 180

local ORB_SIZE = Vector3.new(1, 1, 1)
local ORB_HALF_HEIGHT = ORB_SIZE.Y * 0.5
local ORB_SPAWN_HEIGHT = 2.5
local ORB_IDLE_BOB = 0.28
local ORB_IDLE_BOB_SPEED = 4.8
local ORB_IDLE_WOBBLE = 0.12
local PICKUP_ANIM_DURATION = 0.24
local ORB_ANIMATION_DISTANCE = 95
local ORB_BASE_TRANSPARENCY = 0.16
local ORB_TRAIL_LIGHT_EMISSION = 0.35
local ORB_SPARKLE_LIGHT_EMISSION = 0.4
local ORB_LIGHT_BRIGHTNESS = {
	xp = 0.7,
	coins = 0.9,
	souls = 0.8,
}
local ORB_LIGHT_RANGE = {
	xp = 4.75,
	coins = 5.25,
	souls = 5.75,
}

local GROUND_RAY_PARAMS = RaycastParams.new()
GROUND_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist
GROUND_RAY_PARAMS.IgnoreWater = false

local DROP_COLORS = {
	xp = Color3.fromRGB(96, 165, 250),
	coins = Color3.fromRGB(255, 180, 60),
	souls = Color3.fromRGB(168, 85, 247),
}

local function blendColor(a, b, alpha)
	return Color3.new(
		a.R + ((b.R - a.R) * alpha),
		a.G + ((b.G - a.G) * alpha),
		a.B + ((b.B - a.B) * alpha)
	)
end

local function brightenColor(color, alpha)
	return blendColor(color, Color3.new(1, 1, 1), alpha or 0.28)
end

local function firePickupIndicator(plr: Player, kind: string, amount: number)
	if not plr or plr.Parent ~= Players then
		return
	end

	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then
		return
	end

	pickupIndicatorEvent:FireClient(plr, {
		kind = kind,
		amount = amount,
	})
end

local function getPickupRangeMult(plr)
	local bonus = plr and plr:GetAttribute("ShrinePickupRangeBonus")
	if typeof(bonus) ~= "number" then
		return 1
	end
	return math.max(0.1, 1 + bonus)
end

local function getGroundedPosition(pos: Vector3)
	local ignore = { dropsFolder }

	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		table.insert(ignore, enemiesFolder)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end

	GROUND_RAY_PARAMS.FilterDescendantsInstances = ignore

	local origin = pos + Vector3.new(0, 10, 0)
	local direction = Vector3.new(0, -120, 0)
	local result = workspace:Raycast(origin, direction, GROUND_RAY_PARAMS)
	if result then
		local grounded = result.Position + result.Normal * ORB_HALF_HEIGHT
		return Vector3.new(grounded.X, grounded.Y, grounded.Z)
	end

	return pos + Vector3.new(0, ORB_SPAWN_HEIGHT, 0)
end

local function nearestAlivePlayer(pos: Vector3)
	local bestPlr, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if hrp and h and h.Health > 0 then
			local d = (hrp.Position - pos).Magnitude
			if d < bestDist then
				bestDist = d
				bestPlr = plr
			end
		end
	end
	return bestPlr, bestDist
end

local function cleanupGlobalMagnets()
	local now = os.clock()
	for userId, info in pairs(activeGlobalMagnets) do
		local plr = info.player
		local char = plr and plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if info.expiresAt <= now or not plr or not plr.Parent or not hrp or not hum or hum.Health <= 0 then
			activeGlobalMagnets[userId] = nil
		end
	end
end

local function getGlobalMagnetTarget(pos: Vector3, kind: string)
	if kind ~= "xp" and kind ~= "coins" then
		return nil, math.huge
	end

	local bestPlr, bestDist = nil, math.huge
	for _, info in pairs(activeGlobalMagnets) do
		local plr = info.player
		local char = plr and plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local dist = (hrp.Position - pos).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestPlr = plr
			end
		end
	end

	return bestPlr, bestDist
end

local function createDropTrail(part: BasePart, color: Color3)
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, part.Size.Y * 0.45, 0)
	top.Parent = part

	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -part.Size.Y * 0.45, 0)
	bottom.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color, brightenColor(color, 0.18))
	trail.LightEmission = ORB_TRAIL_LIGHT_EMISSION
	trail.FaceCamera = true
	trail.Lifetime = 0.12
	trail.MinLength = 0.02
	trail.Enabled = false
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.38),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	trail.Parent = part

	return trail
end

local function createDropSparkles(part: BasePart, color: Color3)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SparkAttachment"
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Color = ColorSequence.new(color, brightenColor(color, 0.18))
	emitter.LightEmission = ORB_SPARKLE_LIGHT_EMISSION
	emitter.Lifetime = NumberRange.new(0.35, 0.75)
	emitter.Speed = NumberRange.new(0.12, 0.55)
	emitter.Rate = 8
	emitter.Enabled = true
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.55, 0.08),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.48),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment

	return emitter
end

local function setSparklesEnabled(meta, enabled: boolean)
	if meta.sparkles then
		meta.sparkles.Enabled = enabled
	end
end

local function awardDrop(plr: Player, meta)
	if meta.awarded or not plr or not plr.Parent then
		return
	end

	meta.awarded = true
	if meta.type == "xp" then
		if _G.AwardPlayer then
			_G.AwardPlayer(plr, meta.amount, 0)
		end
	elseif meta.type == "coins" then
		if _G.AwardPlayer then
			_G.AwardPlayer(plr, 0, meta.amount)
		end
	elseif meta.type == "souls" then
		if _G.AwardSouls then
			_G.AwardSouls(plr, meta.amount)
		end
	end

	firePickupIndicator(plr, tostring(meta.type), meta.amount)
end

local function removeDrop(orb, meta, plr)
	awardDrop(plr, meta)
	if orb and orb.Parent then
		orb:Destroy()
	end
	active[orb] = nil
end

local function startPickupAnimation(orb, meta, plr, now)
	if meta.collecting then
		return
	end

	setSparklesEnabled(meta, false)
	meta.collecting = {
		player = plr,
		startedAt = now,
		duration = PICKUP_ANIM_DURATION + (math.random() * 0.06),
		origin = orb.Position,
		lastTarget = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and (plr.Character.HumanoidRootPart.Position + Vector3.new(0, 1.8, 0)) or orb.Position,
	}
	if meta.trail then
		meta.trail.Enabled = true
		meta.trail.Lifetime = 0.18
	end
	if meta.light then
		meta.light.Brightness = meta.baseLightBrightness * 1.3
		meta.light.Range = meta.baseLightRange * 1.12
	end
end

local function updateCollectingDrop(orb, meta, now)
	local collect = meta.collecting
	if not collect then
		return false
	end

	local plr = collect.player
	local char = plr and plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		collect.lastTarget = hrp.Position + Vector3.new(0, 1.8, 0)
	end

	local alpha = math.clamp((now - collect.startedAt) / collect.duration, 0, 1)
	local eased = 1 - ((1 - alpha) ^ 3)
	local targetPos = collect.lastTarget or collect.origin
	local travelPos = collect.origin:Lerp(targetPos, eased)
	local swirlRadius = (1 - eased) * 0.75
	local swirlAngle = meta.phase + (alpha * math.pi * 6)
	local swirlOffset = Vector3.new(
		math.cos(swirlAngle) * swirlRadius,
		(math.sin(swirlAngle * 0.5) * 0.2) + (math.sin(alpha * math.pi) * 0.7),
		math.sin(swirlAngle) * swirlRadius
	)

	orb.Size = ORB_SIZE:Lerp(ORB_SIZE * 0.28, eased)
	orb.Transparency = ORB_BASE_TRANSPARENCY + (eased * 0.8)
	orb.CFrame = CFrame.new(travelPos + swirlOffset) * CFrame.Angles(alpha * 12, alpha * 18, alpha * 10)
	if meta.light then
		meta.light.Brightness = meta.baseLightBrightness + ((1 - alpha) * 0.65)
	end

	if alpha >= 1 then
		removeDrop(orb, meta, plr)
		return true
	end

	return false
end

local function updateIdleVisual(orb, meta, now)
	local bob = math.sin(((now - meta.spawnAt) * ORB_IDLE_BOB_SPEED) + meta.phase) * ORB_IDLE_BOB
	local wobble = math.sin(((now - meta.spawnAt) * 2.4) + meta.phase) * ORB_IDLE_WOBBLE
	local spin = meta.spinBase + ((now - meta.spawnAt) * meta.spinSpeed)
	meta.staticVisual = false
	orb.Size = ORB_SIZE
	orb.Transparency = ORB_BASE_TRANSPARENCY
	orb.CFrame = CFrame.new(meta.corePos + Vector3.new(0, bob, 0)) * CFrame.Angles(wobble * 0.35, spin, -wobble * 0.35)
	if meta.light then
		meta.light.Brightness = meta.baseLightBrightness + (math.sin(((now - meta.spawnAt) * 5) + meta.phase) * 0.1)
		meta.light.Range = meta.baseLightRange + (math.cos(((now - meta.spawnAt) * 3.2) + meta.phase) * 0.08)
	end
end

local function setStaticIdleVisual(orb, meta)
	if meta.staticVisual and meta.lastStaticPos and (meta.lastStaticPos - meta.corePos).Magnitude <= 1e-3 then
		return
	end
	meta.staticVisual = true
	meta.lastStaticPos = meta.corePos
	orb.Size = ORB_SIZE
	orb.Transparency = ORB_BASE_TRANSPARENCY
	orb.CFrame = CFrame.new(meta.corePos) * CFrame.Angles(0, meta.spinBase, 0)
	if meta.light then
		meta.light.Brightness = meta.baseLightBrightness
		meta.light.Range = meta.baseLightRange
	end
end

local function makeOrb(kind: "xp" | "coins" | "souls", amount: number, pos: Vector3)
	local color = DROP_COLORS[kind] or Color3.fromRGB(255, 255, 255)
	local groundedPos = getGroundedPosition(pos)
	local p = Instance.new("Part")
	if kind == "xp" then
		p.Name = "XPOrb"
	elseif kind == "coins" then
		p.Name = "CoinOrb"
	else
		p.Name = "SoulOrb"
	end
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = ORB_SIZE
	p.Transparency = ORB_BASE_TRANSPARENCY
	p.CanCollide = false
	p.CanQuery = false
	p.Anchored = true
	p.CFrame = CFrame.new(groundedPos)
	p.Parent = dropsFolder

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = ORB_LIGHT_BRIGHTNESS[kind] or 0.75
	light.Range = ORB_LIGHT_RANGE[kind] or 5
	light.Shadows = false
	light.Parent = p

	local trail = createDropTrail(p, color)
	local sparkles = createDropSparkles(p, color)

	active[p] = {
		type = kind,
		amount = math.max(1, math.floor(amount)),
		corePos = groundedPos,
		spawnAt = os.clock(),
		phase = math.random() * math.pi * 2,
		spinBase = math.random() * math.pi * 2,
		spinSpeed = math.rad(55 + math.random(0, 45)),
		light = light,
		baseLightBrightness = light.Brightness,
		baseLightRange = light.Range,
		trail = trail,
		sparkles = sparkles,
		awarded = false,
		collecting = nil,
	}

	return p
end

function _G.SpawnDropsAt(pos: Vector3, xp: number, coins: number, souls: number)
	local function jitter()
		return Vector3.new((math.random() - 0.5) * 2.6, 0, (math.random() - 0.5) * 2.6)
	end
	if xp and xp > 0 then
		makeOrb("xp", xp, pos + jitter())
	end
	if coins and coins > 0 then
		makeOrb("coins", coins, pos + jitter())
	end
	if souls and souls > 0 then
		makeOrb("souls", souls, pos + jitter())
	end
end

function _G.ActivateGlobalMagnet(plr: Player, duration: number)
	if not plr or not plr.Parent then
		return false
	end

	activeGlobalMagnets[plr.UserId] = {
		player = plr,
		expiresAt = os.clock() + math.max(1, tonumber(duration) or 10),
	}
	return true
end

RunService.Heartbeat:Connect(function(dt)
	cleanupGlobalMagnets()

	local now = os.clock()
	for orb, meta in pairs(active) do
		if not orb or not orb.Parent then
			active[orb] = nil
			continue
		end

		if meta.collecting then
			if updateCollectingDrop(orb, meta, now) then
				continue
			end
			continue
		end

		local plr, dist = getGlobalMagnetTarget(meta.corePos, meta.type)
		local usingGlobalMagnet = plr ~= nil
		if not plr then
			plr, dist = nearestAlivePlayer(meta.corePos)
		end

		if not plr then
			if meta.trail then
				meta.trail.Enabled = false
			end
			setSparklesEnabled(meta, false)
			setStaticIdleVisual(orb, meta)
			continue
		end

		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			if meta.trail then
				meta.trail.Enabled = false
			end
			setSparklesEnabled(meta, false)
			setStaticIdleVisual(orb, meta)
			continue
		end

		local pickupMult = getPickupRangeMult(plr)
		local pickupDist = PICKUP_DIST * pickupMult
		local attractRadius = ATTRACT_RADIUS * pickupMult
		local shouldAnimateIdle = dist <= ORB_ANIMATION_DISTANCE

		if dist <= pickupDist then
			startPickupAnimation(orb, meta, plr, now)
			updateCollectingDrop(orb, meta, now)
			continue
		end

		if usingGlobalMagnet or dist <= attractRadius then
			local target = hrp.Position + Vector3.new(0, 1.6, 0)
			local toTarget = target - meta.corePos
			local toTargetDist = toTarget.Magnitude
			if meta.trail then
				meta.trail.Enabled = shouldAnimateIdle
				if shouldAnimateIdle then
					meta.trail.Lifetime = usingGlobalMagnet and 0.18 or 0.12
				end
			end
			if toTargetDist > 0 then
				local walkSpeed = hum.WalkSpeed or 16
				local attractSpeed
				if usingGlobalMagnet then
					attractSpeed = math.max(GLOBAL_MAGNET_SPEED, walkSpeed * 6)
				else
					attractSpeed = math.max(ATTRACT_SPEED_MIN, walkSpeed * ATTRACT_SPEED_MULT + ATTRACT_SPEED_BONUS)
				end
				local step = math.min(toTargetDist, attractSpeed * dt)
				meta.corePos += toTarget.Unit * step
			end
		else
			if meta.trail then
				meta.trail.Enabled = false
			end
		end

		if shouldAnimateIdle then
			setSparklesEnabled(meta, true)
			updateIdleVisual(orb, meta, now)
		else
			setSparklesEnabled(meta, false)
			setStaticIdleVisual(orb, meta)
		end
	end
end)
