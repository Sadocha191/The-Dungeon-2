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
local ORB_SETTLE_SPEED = 42
local ORB_SETTLE_EPSILON = 0.05
local GROUND_RAY_RETRY_INTERVAL = 0.15

local ORB_SIZE = Vector3.new(1, 1, 1)
local ORB_IDLE_BOB = 0.28
local ORB_IDLE_BOB_SPEED = 4.8
local ORB_IDLE_WOBBLE = 0.12
local ORB_ANIMATION_DISTANCE = 95
local ORB_ANIMATION_DISTANCE_SQ = ORB_ANIMATION_DISTANCE * ORB_ANIMATION_DISTANCE
local ORB_NEAR_ANIMATION_DISTANCE_SQ = 45 * 45
local ORB_IDLE_UPDATE_INTERVAL_NEAR = 1 / 30
local ORB_IDLE_UPDATE_INTERVAL_FAR = 1 / 15
local ORB_BASE_TRANSPARENCY = 0.16
local ORB_TRAIL_LIGHT_EMISSION = 0.35
local ORB_SPARKLE_LIGHT_EMISSION = 0.4
local GLOBAL_MAGNET_ATTR = "DropGlobalMagnetExpiresAt"

local GROUND_RAY_PARAMS = RaycastParams.new()
GROUND_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
GROUND_RAY_PARAMS.IgnoreWater = false

local framePlayerStates = {}
local framePlayerStateByUserId = {}
local groundIgnore = {}

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
	local bonus = plr:GetAttribute("ShrinePickupRangeBonus")
	if typeof(bonus) ~= "number" then
		return 1
	end
	return math.max(0.1, 1 + bonus)
end

local function rebuildFramePlayerCache(now: number)
	table.clear(framePlayerStates)
	table.clear(framePlayerStateByUserId)
	table.clear(groundIgnore)

	table.insert(groundIgnore, dropsRoot)
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then
		table.insert(groundIgnore, enemiesFolder)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		local character = plr.Character
		if character then
			table.insert(groundIgnore, character)
		end

		if plr:GetAttribute("RunEnded") ~= true and character then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local state = {
					player = plr,
					root = root,
					humanoid = humanoid,
					position = root.Position,
					walkSpeed = humanoid.WalkSpeed,
					pickupMult = getPickupRangeMult(plr),
					magnetActive = (tonumber(plr:GetAttribute(GLOBAL_MAGNET_ATTR)) or 0) > now,
				}
				table.insert(framePlayerStates, state)
				framePlayerStateByUserId[plr.UserId] = state
			end
		end
	end

	GROUND_RAY_PARAMS.FilterDescendantsInstances = groundIgnore
end

local function raycastGroundY(pos: Vector3): number?
	local result = workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -120, 0), GROUND_RAY_PARAMS)
	if not result then
		return nil
	end
	return (result.Position + result.Normal * (ORB_SIZE.Y * 0.5)).Y
end

local function resetGrounding(entry)
	entry.grounded = false
	entry.groundY = nil
	entry.nextGroundRayAt = 0
end

local function settleDropToGround(entry, dt: number, now: number)
	if entry.grounded then
		return
	end

	if entry.groundY == nil and now >= (entry.nextGroundRayAt or 0) then
		entry.groundY = raycastGroundY(entry.corePos)
		entry.nextGroundRayAt = now + GROUND_RAY_RETRY_INTERVAL
	end

	local groundY = entry.groundY
	if groundY == nil then
		return
	end

	local target = Vector3.new(entry.corePos.X, groundY, entry.corePos.Z)
	local delta = target - entry.corePos
	local distance = delta.Magnitude
	if distance <= ORB_SETTLE_EPSILON then
		entry.corePos = target
		entry.grounded = true
		return
	end

	local step = math.min(distance, ORB_SETTLE_SPEED * math.max(0, dt))
	if step > 0 then
		entry.corePos += delta.Unit * step
	end
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
	if not entry.sparkles or entry.sparklesEnabled == enabled then
		return
	end
	entry.sparklesEnabled = enabled
	entry.sparkles.Enabled = enabled
end

local function setTrailEnabled(entry, enabled: boolean, lifetime: number?)
	if not entry.trail then
		return
	end
	if lifetime and entry.trailLifetime ~= lifetime then
		entry.trailLifetime = lifetime
		entry.trail.Lifetime = lifetime
	end
	if entry.trailEnabled == enabled then
		return
	end
	entry.trailEnabled = enabled
	entry.trail.Enabled = enabled
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
	entry.sparklesEnabled = nil
	entry.trailEnabled = nil
	entry.trailLifetime = nil
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
	entry.sparklesEnabled = true
	entry.trailEnabled = false
	entry.trailLifetime = entry.trail.Lifetime
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

local function findTargetState(pos: Vector3, kind: string)
	local nearestState = nil
	local nearestDistSq = math.huge
	local magnetState = nil
	local magnetDistSq = math.huge
	local supportsMagnet = kind == "xp" or kind == "coins" or kind == "souls"

	for _, state in ipairs(framePlayerStates) do
		local offset = state.position - pos
		local distSq = offset:Dot(offset)
		if distSq < nearestDistSq then
			nearestDistSq = distSq
			nearestState = state
		end
		if supportsMagnet and state.magnetActive and distSq < magnetDistSq then
			magnetDistSq = distSq
			magnetState = state
		end
	end

	if magnetState then
		return magnetState, math.sqrt(magnetDistSq), true
	end
	if nearestState then
		return nearestState, math.sqrt(nearestDistSq), false
	end
	return nil, math.huge, false
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

	local elapsed = now - (entry.spawnAt or now)
	local phase = entry.phase or 0
	local bob = math.sin((elapsed * ORB_IDLE_BOB_SPEED) + phase) * ORB_IDLE_BOB
	local wobble = math.sin((elapsed * 2.4) + phase) * ORB_IDLE_WOBBLE
	local spin = (entry.spinBase or 0) + (elapsed * (entry.spinSpeed or 0))
	entry.staticVisual = false
	entry.part.Size = ORB_SIZE
	entry.part.Transparency = ORB_BASE_TRANSPARENCY
	entry.part.CFrame = CFrame.new(entry.corePos + Vector3.new(0, bob, 0)) * CFrame.Angles(wobble * 0.35, spin, -wobble * 0.35)
	if entry.light then
		entry.light.Brightness = entry.baseLightBrightness + (math.sin((elapsed * 5) + phase) * 0.1)
		entry.light.Range = entry.baseLightRange + (math.cos((elapsed * 3.2) + phase) * 0.08)
	end
end

local function updateCollectingVisual(entry, now: number)
	local collect = entry.collecting
	if not collect or not entry.part then
		return
	end

	local targetState = collect.playerUserId and framePlayerStateByUserId[collect.playerUserId] or nil
	if targetState then
		collect.lastTarget = targetState.position + Vector3.new(0, 1.8, 0)
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
	setTrailEnabled(entry, true, 0.18)
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
		local moved = entry.corePos == nil or (item.pos - entry.corePos).Magnitude > ORB_SETTLE_EPSILON
		entry.corePos = item.pos
		if moved then
			resetGrounding(entry)
		end
	end
	entry.corePos = entry.corePos or Vector3.zero
	entry.spawnAt = tonumber(item.spawnAt) or entry.spawnAt or getServerTimeNow()
	entry.phase = tonumber(item.phase) or entry.phase or 0
	entry.spinBase = tonumber(item.spinBase) or entry.spinBase or 0
	entry.spinSpeed = tonumber(item.spinSpeed) or entry.spinSpeed or 0
	entry.staticVisual = false
	entry.nextIdleVisualAt = 0

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
	debug.profilebegin("DropPresentation.Frame")

	local now = getServerTimeNow()
	rebuildFramePlayerCache(now)
	local localState = framePlayerStateByUserId[localPlayer.UserId]
	local localPosition = localState and localState.position or nil

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

		local targetState, distance, usingGlobalMagnet = findTargetState(entry.corePos, entry.kind)
		local shouldSettle = true
		local movingToPlayer = false
		if targetState then
			local pickupDist = PICKUP_DIST * targetState.pickupMult
			local attractRadius = ATTRACT_RADIUS * targetState.pickupMult
			if distance <= pickupDist then
				shouldSettle = false
			elseif usingGlobalMagnet or distance <= attractRadius then
				shouldSettle = false
				movingToPlayer = true
				local target = targetState.position + Vector3.new(0, 1.6, 0)
				local toTarget = target - entry.corePos
				local toTargetDist = toTarget.Magnitude
				if toTargetDist > 0 then
					local attractSpeed
					if usingGlobalMagnet then
						attractSpeed = math.max(GLOBAL_MAGNET_SPEED, targetState.walkSpeed * 6)
					else
						attractSpeed = math.max(
							ATTRACT_SPEED_MIN,
							targetState.walkSpeed * ATTRACT_SPEED_MULT + ATTRACT_SPEED_BONUS
						)
					end
					local step = math.min(toTargetDist, attractSpeed * dt)
					entry.corePos += toTarget.Unit * step
					resetGrounding(entry)
				end
			end
		end

		if shouldSettle then
			settleDropToGround(entry, dt, now)
		end

		local distanceToLocalSq = math.huge
		if localPosition then
			local localOffset = localPosition - entry.corePos
			distanceToLocalSq = localOffset:Dot(localOffset)
		end
		local shouldAnimateIdle = distanceToLocalSq <= ORB_ANIMATION_DISTANCE_SQ
		if shouldAnimateIdle then
			setSparklesEnabled(entry, true)
			setTrailEnabled(entry, false)

			local interval = distanceToLocalSq <= ORB_NEAR_ANIMATION_DISTANCE_SQ
				and ORB_IDLE_UPDATE_INTERVAL_NEAR
				or ORB_IDLE_UPDATE_INTERVAL_FAR
			if movingToPlayer or not entry.grounded or now >= (entry.nextIdleVisualAt or 0) then
				entry.nextIdleVisualAt = now + interval
				updateIdleVisual(entry, now)
			end
		else
			setSparklesEnabled(entry, false)
			setTrailEnabled(entry, false)
			setStaticIdleVisual(entry)
		end
	end

	debug.profileend()
end)

requestSync()
localPlayer.CharacterAdded:Connect(function()
	requestSync()
end)
