-- DropService.server.lua
-- Keeps drops fully authoritative on the server while rendering them on clients.

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
local dropVisualEvent = ensureRemoteEvent("DropVisualEvent")
local dropSyncRequest = ensureRemoteEvent("DropSyncRequest")

local activeDrops = {}
local nextDropId = 0
local activeGlobalMagnets = {}

local ATTRACT_RADIUS = 8
local PICKUP_DIST = 2.5
local ATTRACT_SPEED_MULT = 1.15
local ATTRACT_SPEED_BONUS = 4
local ATTRACT_SPEED_MIN = 22
local GLOBAL_MAGNET_SPEED = 180
local PICKUP_ANIM_DURATION = 0.24
local ORB_SPAWN_HEIGHT = 2.5
local ORB_HALF_HEIGHT = 0.5
local ORB_SETTLE_SPEED = 42
local ORB_SETTLE_EPSILON = 0.05
local GLOBAL_MAGNET_ATTR = "DropGlobalMagnetExpiresAt"

local GROUND_RAY_PARAMS = RaycastParams.new()
GROUND_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist
GROUND_RAY_PARAMS.IgnoreWater = false

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

local function getPickupRangeMult(plr: Player): number
	local bonus = plr and plr:GetAttribute("ShrinePickupRangeBonus")
	if typeof(bonus) ~= "number" then
		return 1
	end
	return math.max(0.1, 1 + bonus)
end

local function raycastGroundedPosition(pos: Vector3): Vector3?
	local ignore = {}

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

	return nil
end

local function getGroundedPosition(pos: Vector3): Vector3
	return raycastGroundedPosition(pos) or (pos + Vector3.new(0, ORB_SPAWN_HEIGHT, 0))
end

local function settleDropToGround(meta, dt: number)
	local grounded = raycastGroundedPosition(meta.corePos)
	if not grounded then
		return
	end

	local target = Vector3.new(meta.corePos.X, grounded.Y, meta.corePos.Z)
	local delta = target - meta.corePos
	if delta.Magnitude <= ORB_SETTLE_EPSILON then
		meta.corePos = target
		return
	end

	local step = math.min(delta.Magnitude, ORB_SETTLE_SPEED * math.max(0, dt))
	if step > 0 then
		meta.corePos += delta.Unit * step
	end
end

local function nearestAlivePlayer(pos: Vector3): (Player?, number)
	local bestPlr, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("RunEnded") == true then
			continue
		end

		local char = plr.Character
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

local function cleanupGlobalMagnets()
	local now = os.clock()
	for userId, info in pairs(activeGlobalMagnets) do
		local plr = info.player
		if plr and plr:GetAttribute("RunEnded") == true then
			activeGlobalMagnets[userId] = nil
			if plr.Parent == Players then
				plr:SetAttribute(GLOBAL_MAGNET_ATTR, 0)
			end
			continue
		end

		local char = plr and plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if info.expiresAt <= now or not plr or not plr.Parent or not hrp or not hum or hum.Health <= 0 then
			activeGlobalMagnets[userId] = nil
			if plr and plr.Parent == Players then
				plr:SetAttribute(GLOBAL_MAGNET_ATTR, 0)
			end
		end
	end
end

local function getGlobalMagnetTarget(pos: Vector3, kind: string): (Player?, number)
	if kind ~= "xp" and kind ~= "coins" and kind ~= "souls" then
		return nil, math.huge
	end

	local bestPlr, bestDist = nil, math.huge
	for _, info in pairs(activeGlobalMagnets) do
		local plr = info.player
		if plr and plr:GetAttribute("RunEnded") == true then
			continue
		end

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

local function serializeCollecting(collect)
	if typeof(collect) ~= "table" then
		return nil
	end

	return {
		playerUserId = collect.playerUserId,
		startedAt = collect.startedAt,
		duration = collect.duration,
		origin = collect.origin,
		targetPos = collect.lastTarget,
	}
end

local function serializeDrop(meta)
	return {
		id = meta.id,
		kind = meta.type,
		amount = meta.amount,
		pos = meta.corePos,
		spawnAt = meta.spawnAt,
		phase = meta.phase,
		spinBase = meta.spinBase,
		spinSpeed = meta.spinSpeed,
		collecting = serializeCollecting(meta.collecting),
	}
end

local function fireDropVisualPayload(player: Player?, action: string, payload)
	payload = payload or {}
	payload.action = action
	payload.serverTime = workspace:GetServerTimeNow()
	if player then
		dropVisualEvent:FireClient(player, payload)
	else
		dropVisualEvent:FireAllClients(payload)
	end
end

local function sendFullSync(player: Player, requestId: number?)
	if not player or player.Parent ~= Players then
		return
	end

	local items = {}
	for _, meta in pairs(activeDrops) do
		table.insert(items, serializeDrop(meta))
	end

	fireDropVisualPayload(player, "sync", {
		requestId = requestId,
		items = items,
	})
end

local function awardDrop(plr: Player, meta)
	if meta.awarded or not plr or not plr.Parent or plr:GetAttribute("RunEnded") == true then
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

local function removeDrop(meta, plr: Player?)
	if not meta or activeDrops[meta.id] ~= meta then
		return
	end

	awardDrop(plr, meta)
	activeDrops[meta.id] = nil
	fireDropVisualPayload(nil, "remove", {
		ids = { meta.id },
	})
end

local function startPickupAnimation(meta, plr: Player, nowServer: number)
	if meta.collecting then
		return
	end

	local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local targetPos = hrp and (hrp.Position + Vector3.new(0, 1.8, 0)) or meta.corePos
	meta.collecting = {
		player = plr,
		playerUserId = plr.UserId,
		startedAt = nowServer,
		duration = PICKUP_ANIM_DURATION + (math.random() * 0.06),
		origin = meta.corePos,
		lastTarget = targetPos,
	}

	fireDropVisualPayload(nil, "upsert", {
		items = { serializeDrop(meta) },
	})
end

local function updateCollectingDrop(meta, nowServer: number): boolean
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

	local alpha = math.clamp((nowServer - collect.startedAt) / collect.duration, 0, 1)
	if alpha >= 1 then
		removeDrop(meta, plr)
		return true
	end

	return false
end

local function makeDrop(kind: "xp" | "coins" | "souls", amount: number, pos: Vector3)
	nextDropId += 1
	local meta = {
		id = tostring(nextDropId),
		type = kind,
		amount = math.max(1, math.floor(amount)),
		corePos = getGroundedPosition(pos),
		spawnAt = workspace:GetServerTimeNow(),
		phase = math.random() * math.pi * 2,
		spinBase = math.random() * math.pi * 2,
		spinSpeed = math.rad(55 + math.random(0, 45)),
		awarded = false,
		collecting = nil,
	}

	activeDrops[meta.id] = meta
	fireDropVisualPayload(nil, "upsert", {
		items = { serializeDrop(meta) },
	})
	return meta
end

function _G.SpawnDropsAt(pos: Vector3, xp: number, coins: number, souls: number)
	local function jitter()
		return Vector3.new((math.random() - 0.5) * 2.6, 0, (math.random() - 0.5) * 2.6)
	end

	if xp and xp > 0 then
		makeDrop("xp", xp, pos + jitter())
	end
	if coins and coins > 0 then
		makeDrop("coins", coins, pos + jitter())
	end
	if souls and souls > 0 then
		makeDrop("souls", souls, pos + jitter())
	end
end

function _G.ActivateGlobalMagnet(plr: Player, duration: number)
	if not plr or not plr.Parent then
		return false
	end

	local expiresAt = os.clock() + math.max(1, tonumber(duration) or 10)
	activeGlobalMagnets[plr.UserId] = {
		player = plr,
		expiresAt = expiresAt,
	}
	plr:SetAttribute(GLOBAL_MAGNET_ATTR, workspace:GetServerTimeNow() + math.max(1, tonumber(duration) or 10))
	return true
end

dropSyncRequest.OnServerEvent:Connect(function(player: Player, requestId: number?)
	sendFullSync(player, tonumber(requestId))
end)

RunService.Heartbeat:Connect(function(dt)
	cleanupGlobalMagnets()

	local nowServer = workspace:GetServerTimeNow()
	for _, meta in pairs(activeDrops) do
		if meta.collecting then
			updateCollectingDrop(meta, nowServer)
			continue
		end

		local plr, dist = getGlobalMagnetTarget(meta.corePos, meta.type)
		local usingGlobalMagnet = plr ~= nil
		if not plr then
			plr, dist = nearestAlivePlayer(meta.corePos)
		end
		if not plr then
			settleDropToGround(meta, dt)
			continue
		end

		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum or hum.Health <= 0 then
			settleDropToGround(meta, dt)
			continue
		end

		local pickupMult = getPickupRangeMult(plr)
		local pickupDist = PICKUP_DIST * pickupMult
		local attractRadius = ATTRACT_RADIUS * pickupMult

		if dist <= pickupDist then
			startPickupAnimation(meta, plr, nowServer)
			updateCollectingDrop(meta, nowServer)
			continue
		end

		if usingGlobalMagnet or dist <= attractRadius then
			local target = hrp.Position + Vector3.new(0, 1.6, 0)
			local toTarget = target - meta.corePos
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
				meta.corePos += toTarget.Unit * step
			end
		else
			settleDropToGround(meta, dt)
		end
	end
end)
