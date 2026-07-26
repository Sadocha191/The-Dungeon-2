-- DropService.server.lua
-- Keeps drops fully authoritative on the server while rendering them on clients.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local RunProgressApi = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("RunProgressApi"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name: string): RemoteEvent
	local ev = remotes:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	if ev then ev:Destroy() end
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
local lastDropSyncRequestAt = {}

local ATTRACT_RADIUS = 8
local PICKUP_DIST = 2.5
local ATTRACT_SPEED_MULT = 1.15
local ATTRACT_SPEED_BONUS = 4
local ATTRACT_SPEED_MIN = 22
local ATTRACT_SPEED_CATCHUP_BONUS = 40
local GLOBAL_MAGNET_SPEED = 180
local PICKUP_ANIM_DURATION = 0.24
local ORB_SPAWN_HEIGHT = 2.5
local ORB_HALF_HEIGHT = 0.5
local ORB_SETTLE_SPEED = 42
local ORB_SETTLE_EPSILON = 0.05
local GROUND_SETTLE_INTERVAL = 0.1
local GLOBAL_MAGNET_ATTR = "DropGlobalMagnetExpiresAt"
local DROP_SYNC_REQUEST_COOLDOWN = 1

local GROUND_RAY_PARAMS = RaycastParams.new()
GROUND_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist
GROUND_RAY_PARAMS.IgnoreWater = false

local function firePickupIndicator(plr: Player, kind: string, amount: number)
	if not plr or plr.Parent ~= Players then return end
	amount = math.max(0, math.floor(tonumber(amount) or 0))
	if amount <= 0 then return end
	pickupIndicatorEvent:FireClient(plr, { kind = kind, amount = amount })
end

local function getPickupRangeMult(plr: Player): number
	local bonus = plr and plr:GetAttribute("ShrinePickupRangeBonus")
	if typeof(bonus) ~= "number" then return 1 end
	return math.max(0.1, 1 + bonus)
end

local function buildAlivePlayerSnapshots()
	local list = {}
	local byUserId = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute("RunEnded") ~= true then
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 then
				local snapshot = { player = plr, hrp = hrp, humanoid = hum }
				table.insert(list, snapshot)
				byUserId[plr.UserId] = snapshot
			end
		end
	end
	return list, byUserId
end

local function refreshGroundRayFilter()
	local ignore = {}
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if enemiesFolder then table.insert(ignore, enemiesFolder) end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(ignore, plr.Character) end
	end
	GROUND_RAY_PARAMS.FilterDescendantsInstances = ignore
end

local function raycastGroundedPosition(pos: Vector3): Vector3?
	local result = workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -120, 0), GROUND_RAY_PARAMS)
	if result then
		local grounded = result.Position + result.Normal * ORB_HALF_HEIGHT
		return Vector3.new(grounded.X, grounded.Y, grounded.Z)
	end
	return nil
end

local function getGroundedPosition(pos: Vector3): (Vector3, boolean)
	local grounded = raycastGroundedPosition(pos)
	if grounded then return grounded, true end
	return pos + Vector3.new(0, ORB_SPAWN_HEIGHT, 0), false
end

local function settleDropToGround(meta, nowClock: number)
	if meta.needsGroundSettle ~= true or nowClock < (meta.nextGroundSettleAt or 0) then return end
	local previous = meta.lastGroundSettleAt or (nowClock - GROUND_SETTLE_INTERVAL)
	local elapsed = math.clamp(nowClock - previous, 0, 0.25)
	meta.lastGroundSettleAt = nowClock
	meta.nextGroundSettleAt = nowClock + GROUND_SETTLE_INTERVAL
	local grounded = raycastGroundedPosition(meta.corePos)
	if not grounded then return end
	local target = Vector3.new(meta.corePos.X, grounded.Y, meta.corePos.Z)
	local delta = target - meta.corePos
	if delta.Magnitude <= ORB_SETTLE_EPSILON then
		meta.corePos = target
		meta.needsGroundSettle = false
		return
	end
	local step = math.min(delta.Magnitude, ORB_SETTLE_SPEED * math.max(elapsed, GROUND_SETTLE_INTERVAL))
	if step > 0 then meta.corePos += delta.Unit * step end
end

local function nearestAlivePlayer(pos: Vector3, aliveSnapshots): (Player?, number, any?)
	local bestSnapshot, bestDist = nil, math.huge
	for _, snapshot in ipairs(aliveSnapshots) do
		local dist = (snapshot.hrp.Position - pos).Magnitude
		if dist < bestDist then
			bestDist = dist
			bestSnapshot = snapshot
		end
	end
	return bestSnapshot and bestSnapshot.player or nil, bestDist, bestSnapshot
end

local function cleanupGlobalMagnets(aliveByUserId)
	local nowClock = os.clock()
	for userId, info in pairs(activeGlobalMagnets) do
		local plr = info.player
		if info.expiresAt <= nowClock or not plr or plr.Parent ~= Players or not aliveByUserId[userId] then
			activeGlobalMagnets[userId] = nil
			if plr and plr.Parent == Players then plr:SetAttribute(GLOBAL_MAGNET_ATTR, 0) end
		end
	end
end

local function getGlobalMagnetTarget(pos: Vector3, kind: string, aliveByUserId): (Player?, number, any?)
	if kind ~= "xp" and kind ~= "coins" and kind ~= "souls" then return nil, math.huge, nil end
	local bestSnapshot, bestDist = nil, math.huge
	for userId in pairs(activeGlobalMagnets) do
		local snapshot = aliveByUserId[userId]
		if snapshot then
			local dist = (snapshot.hrp.Position - pos).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestSnapshot = snapshot
			end
		end
	end
	return bestSnapshot and bestSnapshot.player or nil, bestDist, bestSnapshot
end

local function serializeCollecting(collect)
	if typeof(collect) ~= "table" then return nil end
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
	if player then dropVisualEvent:FireClient(player, payload) else dropVisualEvent:FireAllClients(payload) end
end

local function sendFullSync(player: Player, requestId: number?)
	if not player or player.Parent ~= Players then return end
	local items = {}
	for _, meta in pairs(activeDrops) do table.insert(items, serializeDrop(meta)) end
	fireDropVisualPayload(player, "sync", { requestId = requestId, items = items })
end

local function awardDrop(plr: Player, meta)
	if meta.awarded or not plr or not plr.Parent or plr:GetAttribute("RunEnded") == true then return end
	meta.awarded = true
	if meta.type == "xp" then
		RunProgressApi.AwardPlayer(plr, meta.amount, 0)
	elseif meta.type == "coins" then
		RunProgressApi.AwardPlayer(plr, 0, meta.amount)
	elseif meta.type == "souls" then
		RunProgressApi.AwardSouls(plr, meta.amount)
	end
	firePickupIndicator(plr, tostring(meta.type), meta.amount)
end

local function removeDrop(meta, plr: Player?)
	if not meta or activeDrops[meta.id] ~= meta then return end
	awardDrop(plr, meta)
	activeDrops[meta.id] = nil
	fireDropVisualPayload(nil, "remove", { ids = { meta.id } })
end

local function startPickupAnimation(meta, plr: Player, nowServer: number)
	if meta.collecting then return end
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
	fireDropVisualPayload(nil, "upsert", { items = { serializeDrop(meta) } })
end

local function updateCollectingDrop(meta, nowServer: number): boolean
	local collect = meta.collecting
	if not collect then return false end
	local plr = collect.player
	local char = plr and plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then collect.lastTarget = hrp.Position + Vector3.new(0, 1.8, 0) end
	local alpha = math.clamp((nowServer - collect.startedAt) / collect.duration, 0, 1)
	if alpha >= 1 then
		removeDrop(meta, plr)
		return true
	end
	return false
end

local function makeDrop(kind: "xp" | "coins" | "souls", amount: number, pos: Vector3)
	nextDropId += 1
	local groundedPosition, isGrounded = getGroundedPosition(pos)
	local meta = {
		id = tostring(nextDropId),
		type = kind,
		amount = math.max(1, math.floor(amount)),
		corePos = groundedPosition,
		spawnAt = workspace:GetServerTimeNow(),
		phase = math.random() * math.pi * 2,
		spinBase = math.random() * math.pi * 2,
		spinSpeed = math.rad(55 + math.random(0, 45)),
		awarded = false,
		collecting = nil,
		needsGroundSettle = not isGrounded,
		nextGroundSettleAt = 0,
		lastGroundSettleAt = nil,
	}
	activeDrops[meta.id] = meta
	fireDropVisualPayload(nil, "upsert", { items = { serializeDrop(meta) } })
	return meta
end

function _G.SpawnDropsAt(pos: Vector3, xp: number, coins: number, souls: number)
	refreshGroundRayFilter()
	local function jitter()
		return Vector3.new((math.random() - 0.5) * 2.6, 0, (math.random() - 0.5) * 2.6)
	end
	if xp and xp > 0 then makeDrop("xp", xp, pos + jitter()) end
	if coins and coins > 0 then makeDrop("coins", coins, pos + jitter()) end
	if souls and souls > 0 then makeDrop("souls", souls, pos + jitter()) end
end

function _G.ActivateGlobalMagnet(plr: Player, duration: number)
	if not plr or not plr.Parent then return false end
	local safeDuration = math.max(1, tonumber(duration) or 10)
	activeGlobalMagnets[plr.UserId] = { player = plr, expiresAt = os.clock() + safeDuration }
	plr:SetAttribute(GLOBAL_MAGNET_ATTR, workspace:GetServerTimeNow() + safeDuration)
	return true
end

dropSyncRequest.OnServerEvent:Connect(function(player: Player, requestId: number?)
	local nowClock = os.clock()
	local lastRequestAt = lastDropSyncRequestAt[player.UserId]
	if lastRequestAt and nowClock - lastRequestAt < DROP_SYNC_REQUEST_COOLDOWN then return end
	lastDropSyncRequestAt[player.UserId] = nowClock
	local cleanRequestId = tonumber(requestId)
	if cleanRequestId then
		if cleanRequestId ~= cleanRequestId or cleanRequestId == math.huge or cleanRequestId == -math.huge then
			cleanRequestId = nil
		else
			cleanRequestId = math.floor(cleanRequestId)
		end
	end
	sendFullSync(player, cleanRequestId)
end)

Players.PlayerRemoving:Connect(function(player)
	lastDropSyncRequestAt[player.UserId] = nil
	activeGlobalMagnets[player.UserId] = nil
end)

RunService.Heartbeat:Connect(function(dt)
	local nowClock = os.clock()
	local nowServer = workspace:GetServerTimeNow()
	local aliveSnapshots, aliveByUserId = buildAlivePlayerSnapshots()
	refreshGroundRayFilter()
	cleanupGlobalMagnets(aliveByUserId)
	for _, meta in pairs(activeDrops) do
		if meta.collecting then
			updateCollectingDrop(meta, nowServer)
			continue
		end
		local plr, dist, snapshot = getGlobalMagnetTarget(meta.corePos, meta.type, aliveByUserId)
		local usingGlobalMagnet = plr ~= nil
		if not plr then plr, dist, snapshot = nearestAlivePlayer(meta.corePos, aliveSnapshots) end
		if not plr or not snapshot then
			settleDropToGround(meta, nowClock)
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
			local target = snapshot.hrp.Position + Vector3.new(0, 1.6, 0)
			local toTarget = target - meta.corePos
			local toTargetDist = toTarget.Magnitude
			if toTargetDist > 0 then
				local walkSpeed = snapshot.humanoid.WalkSpeed or 16
				local rootVelocity = snapshot.hrp.AssemblyLinearVelocity
				local horizontalSpeed = Vector3.new(rootVelocity.X, 0, rootVelocity.Z).Magnitude
				local catchupSpeed = horizontalSpeed + ATTRACT_SPEED_CATCHUP_BONUS
				local attractSpeed = usingGlobalMagnet
					and math.max(GLOBAL_MAGNET_SPEED, walkSpeed * 6, catchupSpeed)
					or math.max(ATTRACT_SPEED_MIN, walkSpeed * ATTRACT_SPEED_MULT + ATTRACT_SPEED_BONUS, catchupSpeed)
				local step = math.min(toTargetDist, attractSpeed * math.max(0, dt))
				meta.corePos += toTarget.Unit * step
				meta.needsGroundSettle = true
				meta.lastGroundSettleAt = nowClock
			end
		else
			settleDropToGround(meta, nowClock)
		end
	end
end)
