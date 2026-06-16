-- DropPresentation.client.lua
-- Renders server-authoritative drops locally and mirrors the server pickup logic for smooth motion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local dropVisualEvent = remotes:WaitForChild("DropVisualEvent")
local dropSyncRequest = remotes:WaitForChild("DropSyncRequest")

local dropsRoot = workspace:FindFirstChild("Drops")
if not dropsRoot then
	dropsRoot = Instance.new("Folder")
	dropsRoot.Name = "Drops"
	dropsRoot.Parent = workspace
end

local active = {}
local syncRequestId = 0

local ATTRACT_RADIUS = 8
local PICKUP_DIST = 2.5
local ATTRACT_SPEED_MULT = 1.15
local ATTRACT_SPEED_BONUS = 4
local ATTRACT_SPEED_MIN = 22
local GLOBAL_MAGNET_SPEED = 180

local ORB_SIZE = Vector3.new(1, 1, 1)
local ORB_IDLE_BOB = 0.28
local ORB_IDLE_BOB_SPEED = 4.8
local ORB_IDLE_WOBBLE = 0.12
local ORB_ANIMATION_DISTANCE = 95
local ORB_BASE_TRANSPARENCY = 0.16
local ORB_TRAIL_LIGHT_EMISSION = 0.35
local ORB_SPARKLE_LIGHT_EMISSION = 0.4
local GLOBAL_MAGNET_ATTR = "DropGlobalMagnetExpiresAt"

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

local function getServerTimeNow(): number
	return workspace:GetServerTimeNow()
end

local function getPickupRangeMult(plr: Player): number
	local bonus = plr and plr:GetAttribute("ShrinePickupRangeBonus")
	if typeof(bonus) ~= "number" then
		return 1
	end
	return math.max(0.1, 1 + bonus)
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

local function setSparklesEnabled(entry, enabled: boolean)
	if entry.sparkles then
		entry.sparkles.Enabled = enabled
	end
end

local function destroyVisual(entry)
	if entry.part and entry.part.Parent then
		entry.part:Destroy()
	end
	entry.part = nil
	entry.light = nil
	entry.trail = nil
	entry.sparkles = nil
	entry.visualKind = nil
end

local function ensureVisual(entry)
	if entry.part and entry.part.Parent and entry.visualKind == entry.kind then
		return
	end

	destroyVisual(entry)

	local color = DROP_COLORS[entry.kind] or Color3.fromRGB(255, 255, 255)
	local part = Instance.new("Part")
	part.Name = entry.kind == "xp" and "XPOrb" or entry.kind == "coins" and "CoinOrb" or "SoulOrb"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = ORB_SIZE
	part.Transparency = ORB_BASE_TRANSPARENCY
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	part.CFrame = CFrame.new(entry.corePos or Vector3.zero)
	part.Parent = dropsRoot

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = ORB_LIGHT_BRIGHTNESS[entry.kind] or 0.75
	light.Range = ORB_LIGHT_RANGE[entry.kind] or 5
	light.Shadows = false
	light.Parent = part

	entry.part = part
	entry.light = light
	entry.trail = createDropTrail(part, color)
	entry.sparkles = createDropSparkles(part, color)
	entry.baseLightBrightness = light.Brightness
	entry.baseLightRange = light.Range
	entry.visualKind = entry.kind
end

local function cleanupEntry(id: string)
	local entry = active[id]
	if not entry then
		return
	end

	destroyVisual(entry)
	active[id] = nil
end

local function getAliveCharacterInfo(plr: Player)
	if plr:GetAttribute("RunEnded") == true then
		return nil, nil
	end

	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return hrp, hum
	end
	return nil, nil
end

local function nearestAlivePlayer(pos: Vector3): (Player?, number)
	local bestPlr, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local hrp = getAliveCharacterInfo(plr)
		if hrp then
			local dist = (hrp.Position - pos).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestPlr = plr
			end
		end
	end
	return bestPlr, bestDist
end

local function getGlobalMagnetTarget(pos: Vector3, kind: string): (Player?, number)
	if kind ~= "xp" and kind ~= "coins" and kind ~= "souls" then
		return nil, math.huge
	end

	local now = getServerTimeNow()
	local bestPlr, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local expiresAt = tonumber(plr:GetAttribute(GLOBAL_MAGNET_ATTR)) or 0
		if expiresAt > now then
			local hrp = getAliveCharacterInfo(plr)
			if hrp then
				local dist = (hrp.Position - pos).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestPlr = plr
				end
			end
		end
	end

	return bestPlr, bestDist
end

local function setStaticIdleVisual(entry)
	if not entry.part then
		return
	end
	if entry.staticVisual and entry.lastStaticPos and (entry.lastStaticPos - entry.corePos).Magnitude <= 1e-3 then
		return
	end

	entry.staticVisual = true
	entry.lastStaticPos = entry.corePos
	entry.part.Size = ORB_SIZE
	entry.part.Transparency = ORB_BASE_TRANSPARENCY
	entry.part.CFrame = CFrame.new(entry.corePos) * CFrame.Angles(0, entry.spinBase or 0, 0)
	if entry.light then
		entry.light.Brightness = entry.baseLightBrightness
		entry.light.Range = entry.baseLightRange
	end
end

local function updateIdleVisual(entry, now: number)
	if not entry.part then
		return
	end

	local bob = math.sin(((now - (entry.spawnAt or now)) * ORB_IDLE_BOB_SPEED) + (entry.phase or 0)) * ORB_IDLE_BOB
	local wobble = math.sin(((now - (entry.spawnAt or now)) * 2.4) + (entry.phase or 0)) * ORB_IDLE_WOBBLE
	local spin = (entry.spinBase or 0) + ((now - (entry.spawnAt or now)) * (entry.spinSpeed or 0))
	entry.staticVisual = false
	entry.part.Size = ORB_SIZE
	entry.part.Transparency = ORB_BASE_TRANSPARENCY
	entry.part.CFrame = CFrame.new(entry.corePos + Vector3.new(0, bob, 0)) * CFrame.Angles(wobble * 0.35, spin, -wobble * 0.35)
	if entry.light then
		entry.light.Brightness = entry.baseLightBrightness + (math.sin(((now - (entry.spawnAt or now)) * 5) + (entry.phase or 0)) * 0.1)
		entry.light.Range = entry.baseLightRange + (math.cos(((now - (entry.spawnAt or now)) * 3.2) + (entry.phase or 0)) * 0.08)
	end
end

local function updateCollectingVisual(entry, now: number)
	local collect = entry.collecting
	if not collect or not entry.part then
		return
	end

	local targetPlayer = collect.playerUserId and Players:GetPlayerByUserId(collect.playerUserId) or nil
	if targetPlayer then
		local targetRoot, targetHum = getAliveCharacterInfo(targetPlayer)
		if targetRoot and targetHum then
			collect.lastTarget = targetRoot.Position + Vector3.new(0, 1.8, 0)
		end
	end

	local alpha = math.clamp((now - (collect.startedAt or now)) / math.max(0.05, collect.duration or 0.24), 0, 1)
	local eased = 1 - ((1 - alpha) ^ 3)
	local origin = typeof(collect.origin) == "Vector3" and collect.origin or entry.corePos
	local targetPos = typeof(collect.lastTarget) == "Vector3" and collect.lastTarget or origin
	local travelPos = origin:Lerp(targetPos, eased)
	local swirlRadius = (1 - eased) * 0.75
	local swirlAngle = (entry.phase or 0) + (alpha * math.pi * 6)
	local swirlOffset = Vector3.new(
		math.cos(swirlAngle) * swirlRadius,
		(math.sin(swirlAngle * 0.5) * 0.2) + (math.sin(alpha * math.pi) * 0.7),
		math.sin(swirlAngle) * swirlRadius
	)

	entry.part.Size = ORB_SIZE:Lerp(ORB_SIZE * 0.28, eased)
	entry.part.Transparency = ORB_BASE_TRANSPARENCY + (eased * 0.8)
	entry.part.CFrame = CFrame.new(travelPos + swirlOffset) * CFrame.Angles(alpha * 12, alpha * 18, alpha * 10)
	if entry.light then
		entry.light.Brightness = entry.baseLightBrightness + ((1 - alpha) * 0.65)
	end
	if entry.trail then
		entry.trail.Enabled = true
		entry.trail.Lifetime = 0.18
	end
	setSparklesEnabled(entry, false)

	if alpha >= 1 then
		entry.part.Transparency = 1
		if entry.light then
			entry.light.Brightness = 0
		end
	end
end

local function applySnapshot(item)
	if typeof(item) ~= "table" or item.id == nil then
		return
	end

	local id = tostring(item.id)
	local entry = active[id]
	if not entry then
		entry = {
			id = id,
		}
		active[id] = entry
	end

	entry.kind = tostring(item.kind or entry.kind or "xp")
	entry.amount = math.max(1, math.floor(tonumber(item.amount) or entry.amount or 1))
	if typeof(item.pos) == "Vector3" then
		entry.corePos = item.pos
	end
	entry.spawnAt = tonumber(item.spawnAt) or entry.spawnAt or getServerTimeNow()
	entry.phase = tonumber(item.phase) or entry.phase or 0
	entry.spinBase = tonumber(item.spinBase) or entry.spinBase or 0
	entry.spinSpeed = tonumber(item.spinSpeed) or entry.spinSpeed or 0
	entry.staticVisual = false

	if typeof(item.collecting) == "table" then
		entry.collecting = {
			playerUserId = tonumber(item.collecting.playerUserId),
			startedAt = tonumber(item.collecting.startedAt) or getServerTimeNow(),
			duration = tonumber(item.collecting.duration) or 0.24,
			origin = typeof(item.collecting.origin) == "Vector3" and item.collecting.origin or entry.corePos,
			lastTarget = typeof(item.collecting.targetPos) == "Vector3" and item.collecting.targetPos or entry.corePos,
		}
		if typeof(item.collecting.origin) == "Vector3" then
			entry.corePos = item.collecting.origin
		end
	else
		entry.collecting = nil
	end

	ensureVisual(entry)
end

local function handleUpsert(items)
	if typeof(items) ~= "table" then
		return
	end

	for _, item in ipairs(items) do
		applySnapshot(item)
	end
end

local function requestSync()
	syncRequestId += 1
	dropSyncRequest:FireServer(syncRequestId)
end

dropVisualEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local action = payload.action
	if action == "sync" then
		local seen = {}
		for _, item in ipairs(payload.items or {}) do
			if typeof(item) == "table" and item.id ~= nil then
				seen[tostring(item.id)] = true
				applySnapshot(item)
			end
		end
		for id in pairs(active) do
			if not seen[id] then
				cleanupEntry(id)
			end
		end
	elseif action == "upsert" then
		handleUpsert(payload.items)
	elseif action == "remove" then
		for _, id in ipairs(payload.ids or {}) do
			cleanupEntry(tostring(id))
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	local now = getServerTimeNow()
	local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

	for id, entry in pairs(active) do
		ensureVisual(entry)
		if not entry.part then
			cleanupEntry(id)
			continue
		end

		if entry.collecting then
			updateCollectingVisual(entry, now)
			continue
		end

		local plr, dist = getGlobalMagnetTarget(entry.corePos, entry.kind)
		local usingGlobalMagnet = plr ~= nil
		if not plr then
			plr, dist = nearestAlivePlayer(entry.corePos)
		end

		if plr then
			local hrp, hum = getAliveCharacterInfo(plr)
			if hrp and hum then
				local pickupMult = getPickupRangeMult(plr)
				local pickupDist = PICKUP_DIST * pickupMult
				local attractRadius = ATTRACT_RADIUS * pickupMult
				if dist > pickupDist and (usingGlobalMagnet or dist <= attractRadius) then
					local target = hrp.Position + Vector3.new(0, 1.6, 0)
					local toTarget = target - entry.corePos
					local toTargetDist = toTarget.Magnitude
					if toTargetDist > 0 then
						local walkSpeed = hum.WalkSpeed or 16
						local attractSpeed
						if usingGlobalMagnet then
							attractSpeed = math.max(GLOBAL_MAGNET_SPEED, walkSpeed * 6)
						else
							attractSpeed = math.max(ATTRACT_SPEED_MIN, walkSpeed * ATTRACT_SPEED_MULT + ATTRACT_SPEED_BONUS)
						end
						local step = math.min(toTargetDist, attractSpeed * dt)
						entry.corePos += toTarget.Unit * step
					end
				end
			end
		end

		local shouldAnimateIdle = localRoot and (localRoot.Position - entry.corePos).Magnitude <= ORB_ANIMATION_DISTANCE
		if shouldAnimateIdle then
			setSparklesEnabled(entry, true)
			if entry.trail then
				entry.trail.Enabled = false
			end
			updateIdleVisual(entry, now)
		else
			setSparklesEnabled(entry, false)
			if entry.trail then
				entry.trail.Enabled = false
			end
			setStaticIdleVisual(entry)
		end
	end
end)

requestSync()
localPlayer.CharacterAdded:Connect(function()
	requestSync()
end)
