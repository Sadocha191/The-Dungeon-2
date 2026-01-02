-- WaveController.server.lua (ServerScriptService) - FIX: mobs always commit to attack (anti-orbit/anti-stuck)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end

local WaveStatusEvent = ReplicatedStorage:FindFirstChild("WaveStatusEvent")
if not WaveStatusEvent then
	WaveStatusEvent = Instance.new("RemoteEvent")
	WaveStatusEvent.Name = "WaveStatusEvent"
	WaveStatusEvent.Parent = ReplicatedStorage
end

local function broadcast(payload)
	for _, plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

local function waitIfPaused()
	while PauseState.Value do task.wait(0.05) end
end

local ORC_TEMPLATE = ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("Orc")

local ENEMIES_FOLDER = workspace:FindFirstChild("Enemies")
if not ENEMIES_FOLDER then
	ENEMIES_FOLDER = Instance.new("Folder")
	ENEMIES_FOLDER.Name = "Enemies"
	ENEMIES_FOLDER.Parent = workspace
end

local DROPS_FOLDER = workspace:FindFirstChild("Drops")

-- Collision groups
local MOBS_GROUP = "Mobs"
pcall(function() PhysicsService:RegisterCollisionGroup(MOBS_GROUP) end)
PhysicsService:CollisionGroupSetCollidable(MOBS_GROUP, MOBS_GROUP, false)

local function setMobGroup(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = MOBS_GROUP
		end
	end
end

-- CONFIG
local PREP_TIME = 5
local TOTAL_WAVES = 8
local BETWEEN_WAVES_COUNTDOWN = 5

local START_COUNT = 20
local COUNT_ADD_PER_WAVE = 4
local MAX_ALIVE_ON_MAP = 12
local WAVE_DURATION = 40

local BASE_HP = 65
local BASE_DAMAGE = 7
local BASE_SPEED = 14
local HP_GROWTH_PER_WAVE = 0.22
local DMG_GROWTH_PER_WAVE = 0.14
local SPEED_GROWTH_PER_WAVE = 0.07
local SPEED_CAP = 22

-- Spawn safe
local SPAWN_RING_MIN = 40
local SPAWN_RING_MAX = 75
local SPAWN_RAY_START_Y = 140
local GROUND_RAY_DIST = 800
local MAX_SPAWN_TRIES = 40
local MAX_GROUND_SLOPE_DEG = 35
local CLEARANCE_PADDING = Vector3.new(2, 1, 2)

-- AI
local THINK_INTERVAL = 0.12
local PATH_RECALC = 0.75
local DIRECT_UPDATE_DT = 0.22
local LOS_DIRECT_CHASE = 110
local WAYPOINT_TIMEOUT = 1.0

-- Combat
local ATTACK_RANGE = 5.2
local ATTACK_COOLDOWN = 1.0

-- Critical FIX thresholds
local OFFSET_ENABLE_DIST = 20        -- dopiero od tego dystansu “rozchodzą się”
local FORCE_DIRECT_DIST = 12         -- poniżej tego zawsze idą prosto na gracza
local ORBIT_DETECT_WINDOW = 1.8      -- jeśli przez tyle sekund nie maleje dystans -> ForceDirect
local ORBIT_MIN_IMPROVEMENT = 1.6    -- ile musi się realnie zmniejszyć dystans
local FORCE_DIRECT_SECONDS = 3.0

local STUCK_CHECK_DT = 1.1
local STUCK_MOVE_EPS = 0.35
local STUCK_SECONDS = 2.2

local KILL_BELOW_Y = -25
local TELEPORT_IF_FAR = 420

local PATH_PARAMS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentJumpHeight = 7,
	AgentMaxSlope = 35,
}

local UI_PUSH_DT = 0.25

local function clamp(x,a,b)
	if x < a then return a end
	if x > b then return b end
	return x
end

local function anyPlayersAlive()
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then return true end
	end
	return false
end

local function getAlivePlayerHRPs()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if h and hrp and h.Health > 0 then
			list[#list+1] = hrp
		end
	end
	return list
end

local function getClosestLivingCharacter(fromPos: Vector3)
	local bestChar, bestDist = nil, math.huge
	for _, plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if hrp and h and h.Health > 0 then
			local d = (hrp.Position - fromPos).Magnitude
			if d < bestDist then bestDist = d; bestChar = c end
		end
	end
	return bestChar, bestDist
end

local function makeWaveStats(wave: number)
	local hp = math.floor(BASE_HP * (1 + HP_GROWTH_PER_WAVE*(wave-1)))
	local dmg = math.floor(BASE_DAMAGE * (1 + DMG_GROWTH_PER_WAVE*(wave-1)))
	local spd = math.floor(clamp(BASE_SPEED * (1 + SPEED_GROWTH_PER_WAVE*(wave-1)), BASE_SPEED, SPEED_CAP))
	local total = START_COUNT + COUNT_ADD_PER_WAVE*(wave-1)
	return hp, dmg, spd, total
end

local function randomPointInRing(center: Vector3)
	local theta = math.random() * math.pi * 2
	local r = SPAWN_RING_MIN + math.random()*(SPAWN_RING_MAX - SPAWN_RING_MIN)
	return center + Vector3.new(math.cos(theta)*r, 0, math.sin(theta)*r)
end

local function getSlopeDegrees(normal: Vector3)
	local up = Vector3.new(0,1,0)
	local dot = math.clamp(normal:Dot(up), -1, 1)
	return math.deg(math.acos(dot))
end

local function raycastToGround(xzPoint: Vector3)
	local origin = Vector3.new(xzPoint.X, SPAWN_RAY_START_Y, xzPoint.Z)
	local dir = Vector3.new(0, -GROUND_RAY_DIST, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { ENEMIES_FOLDER }
	if DROPS_FOLDER then table.insert(ex, DROPS_FOLDER) end
	params.FilterDescendantsInstances = ex
	return workspace:Raycast(origin, dir, params)
end

local function isClearAt(cf: CFrame, size: Vector3)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { ENEMIES_FOLDER }
	if DROPS_FOLDER then table.insert(ex, DROPS_FOLDER) end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(ex, plr.Character) end
	end
	params.FilterDescendantsInstances = ex

	for _, p in ipairs(workspace:GetPartBoundsInBox(cf, size, params)) do
		if p.CanCollide and p.Transparency < 1 then return false end
	end
	return true
end

local function getSafeSpawnCFrame(modelForSize: Model)
	local hrps = getAlivePlayerHRPs()
	if #hrps == 0 then return CFrame.new(0,10,0) end

	local ext = modelForSize:GetExtentsSize()
	local boxSize = Vector3.new(
		math.max(4, ext.X) + CLEARANCE_PADDING.X,
		math.max(6, ext.Y) + CLEARANCE_PADDING.Y,
		math.max(4, ext.Z) + CLEARANCE_PADDING.Z
	)

	for _=1, MAX_SPAWN_TRIES do
		local base = hrps[math.random(1,#hrps)].Position
		local xz = randomPointInRing(base)
		local hit = raycastToGround(xz)
		if hit and getSlopeDegrees(hit.Normal) <= MAX_GROUND_SLOPE_DEG then
			local pos = hit.Position + Vector3.new(0, (boxSize.Y*0.5)+0.5, 0)
			local cf = CFrame.new(pos)
			if isClearAt(cf, boxSize) then return cf end
		end
	end

	local base = hrps[math.random(1,#hrps)].Position
	return CFrame.new(base + Vector3.new(SPAWN_RING_MIN, 8, 0))
end

local function clearAllMobs()
	for _, m in ipairs(ENEMIES_FOLDER:GetChildren()) do m:Destroy() end
end

local function hasLOS(fromPos: Vector3, toPos: Vector3, ignore: {Instance})
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(fromPos, (toPos-fromPos), params) == nil
end

local function computeWaypoints(fromPos: Vector3, toPos: Vector3)
	local path = PathfindingService:CreatePath(PATH_PARAMS)
	local ok = pcall(function() path:ComputeAsync(fromPos, toPos) end)
	if not ok then return nil end
	if path.Status ~= Enum.PathStatus.Success then return nil end
	return path:GetWaypoints()
end

-- Goal selection: offset only far; always direct close; ForceDirect when orbiting/stuck
local function pickGoal(targetPos: Vector3, orc: Model, dist: number, forceDirectUntil: number)
	if dist <= FORCE_DIRECT_DIST or time() < forceDirectUntil then
		return targetPos
	end
	if dist < OFFSET_ENABLE_DIST then
		return targetPos
	end

	local angle = orc:GetAttribute("SlotAngle")
	local radius = orc:GetAttribute("SlotRadius")
	if typeof(angle) ~= "number" then
		angle = math.random() * math.pi * 2
		orc:SetAttribute("SlotAngle", angle)
	end
	if typeof(radius) ~= "number" then
		radius = 6 + math.random()*5
		orc:SetAttribute("SlotRadius", radius)
	end
	return targetPos + Vector3.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)
end

local function dropsForWave(wave: number)
	local xp = math.floor(10 + (wave-1)*4 + math.random(0,4))
	local coins = math.floor(2 + (wave-1)*1.0 + math.random(0,2))
	return xp, coins
end

-- ===== SPAWN ORC =====
local function spawnOrc(hp, dmg, spd, wave, onKill)
	local orc = ORC_TEMPLATE:Clone()
	orc.Parent = ENEMIES_FOLDER
	setMobGroup(orc)

	local hum = orc:FindFirstChildOfClass("Humanoid")
	local root = orc:FindFirstChild("HumanoidRootPart")
	if not hum or not root then orc:Destroy() return nil end

	hum.MaxHealth = hp
	hum.Health = hp
	hum.WalkSpeed = spd
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	pcall(function() root:SetNetworkOwner(nil) end)

	root.CFrame = getSafeSpawnCFrame(orc)

	local dead = false
	local function markDead()
		if dead then return end
		dead = true
		if onKill then onKill(root.Position) end
		task.defer(function() if orc.Parent then orc:Destroy() end end)
	end
	hum.Died:Connect(markDead)
	orc.AncestryChanged:Connect(function(_, parent) if parent == nil then markDead() end end)

	task.spawn(function()
		local lastAttack = 0
		local lastPath = 0
		local waypoints = nil
		local wpIndex = 2

		local lastDirect = 0
		local lastMoveIssued = 0
		local goalSetAt = 0
		local currentGoal: Vector3? = nil

		local lastPos = root.Position
		local stuckAccum = 0

		-- anti-orbit tracking
		local orbitTimer = 0
		local orbitStartDist = nil
		local forceDirectUntil = 0

		local moveConn = hum.MoveToFinished:Connect(function(reached)
			if not reached then return end
			if waypoints and wpIndex < #waypoints then
				wpIndex += 1
				local wp = waypoints[wpIndex]
				if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
				hum:MoveTo(wp.Position)
				currentGoal = wp.Position
				goalSetAt = time()
				lastMoveIssued = time()
			end
		end)

		while hum.Health > 0 and orc.Parent do
			waitIfPaused()
			task.wait(THINK_INTERVAL)

			if root.Position.Y < KILL_BELOW_Y then
				root.CFrame = getSafeSpawnCFrame(orc)
				waypoints = nil
				currentGoal = nil
				forceDirectUntil = time() + 1.5
			end

			local targetChar, dist = getClosestLivingCharacter(root.Position)
			if not targetChar then
				waypoints = nil
				currentGoal = nil
				continue
			end

			local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
			local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
			if not targetRoot or not targetHum or targetHum.Health <= 0 then
				waypoints = nil
				currentGoal = nil
				continue
			end

			if dist > TELEPORT_IF_FAR then
				root.CFrame = getSafeSpawnCFrame(orc)
				waypoints = nil
				currentGoal = nil
				forceDirectUntil = time() + 2.0
				continue
			end

			local now = time()

			-- ATTACK: always attempt in range
			if dist <= ATTACK_RANGE and (now - lastAttack) >= ATTACK_COOLDOWN then
				lastAttack = now
				targetHum:TakeDamage(dmg)
				-- gdy bije, wymuś direct chwilę, żeby nie “odpływał” na offset
				forceDirectUntil = math.max(forceDirectUntil, now + 0.8)
			end

			-- STUCK detect (movement)
			if (now - goalSetAt) >= STUCK_CHECK_DT then
				local moved = (root.Position - lastPos).Magnitude
				lastPos = root.Position
				if moved < STUCK_MOVE_EPS then
					stuckAccum += STUCK_CHECK_DT
				else
					stuckAccum = 0
				end
				if stuckAccum >= STUCK_SECONDS then
					waypoints = nil
					currentGoal = nil
					stuckAccum = 0
					forceDirectUntil = now + 2.0
				end
			end

			-- ORBIT detect: jeśli dystans nie maleje -> ForceDirect
			do
				orbitTimer += THINK_INTERVAL
				if orbitStartDist == nil then orbitStartDist = dist end
				if orbitTimer >= ORBIT_DETECT_WINDOW then
					local improvement = (orbitStartDist or dist) - dist
					if improvement < ORBIT_MIN_IMPROVEMENT then
						forceDirectUntil = now + FORCE_DIRECT_SECONDS
						waypoints = nil
						currentGoal = nil
					end
					orbitTimer = 0
					orbitStartDist = dist
				end
			end

			local goal = pickGoal(targetRoot.Position, orc, dist, forceDirectUntil)

			-- DIRECT chase (LOS) - very frequent
			if dist <= LOS_DIRECT_CHASE and hasLOS(root.Position, targetRoot.Position, {orc}) then
				waypoints = nil
				if (now - lastDirect) >= DIRECT_UPDATE_DT or (now - lastMoveIssued) >= 0.30 then
					lastDirect = now
					hum:MoveTo(goal)
					currentGoal = goal
					goalSetAt = now
					lastMoveIssued = now
				end
				continue
			end

			-- PATH
			if (not waypoints) or (now - lastPath >= PATH_RECALC) then
				lastPath = now
				waypoints = computeWaypoints(root.Position, goal)
				wpIndex = 2
				currentGoal = nil

				if waypoints and #waypoints >= 2 then
					local wp = waypoints[wpIndex]
					if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
					hum:MoveTo(wp.Position)
					currentGoal = wp.Position
					goalSetAt = now
					lastMoveIssued = now
				else
					waypoints = nil
					hum:MoveTo(goal)
					currentGoal = goal
					goalSetAt = now
					lastMoveIssued = now
				end
			end

			-- goal timeout -> reset
			if currentGoal and (now - goalSetAt) > WAYPOINT_TIMEOUT then
				waypoints = nil
				currentGoal = nil
			end

			-- hard fail-safe: always re-issue sometimes
			if (now - lastMoveIssued) > 0.55 then
				hum:MoveTo(goal)
				currentGoal = goal
				goalSetAt = now
				lastMoveIssued = now
			end
		end

		moveConn:Disconnect()
		if orc.Parent then orc:Destroy() end
	end)

	return orc
end

-- ===== MAIN =====
task.spawn(function()
	local startTime = time()

	for t = PREP_TIME, 1, -1 do
		waitIfPaused()
		broadcast({type="prepTick", seconds=t})
		task.wait(1)
	end
	broadcast({type="prepTick", seconds=0})

	for wave = 1, TOTAL_WAVES do
		while #Players:GetPlayers() == 0 or not anyPlayersAlive() do task.wait(0.5) end

		if wave > 1 then
			for t = BETWEEN_WAVES_COUNTDOWN, 1, -1 do
				waitIfPaused()
				broadcast({type="waveCountdown", nextWave=wave, totalWaves=TOTAL_WAVES, seconds=t})
				task.wait(1)
			end
			broadcast({type="waveCountdown", nextWave=wave, totalWaves=TOTAL_WAVES, seconds=0})
		end

		local hp, dmg, spd, total = makeWaveStats(wave)
		local killed, alive, spawned = 0, 0, 0
		local remaining = total

		broadcast({type="waveStart", wave=wave, totalWaves=TOTAL_WAVES, totalToKill=total, remaining=remaining})

		local lastUi = 0
		local function pushUi(force)
			local now = time()
			if force or (now - lastUi) >= UI_PUSH_DT then
				lastUi = now
				broadcast({type="waveUpdate", wave=wave, totalWaves=TOTAL_WAVES, totalToKill=total, remaining=remaining, alive=alive, spawned=spawned})
			end
		end

		local spawnInterval = clamp(WAVE_DURATION / math.max(1, total), 0.55, 1.40)
		local nextSpawnAt = time()

		while killed < total do
			waitIfPaused()
			task.wait(0.15)

			local now = time()
			while spawned < total and alive < MAX_ALIVE_ON_MAP and now >= nextSpawnAt do
				local xpDrop, coinDrop = dropsForWave(wave)

				local orc = spawnOrc(hp, dmg, spd, wave, function(pos)
					killed += 1
					remaining = math.max(0, total - killed)
					alive = math.max(0, alive - 1)
					pushUi(false)
					if _G.SpawnDropsAt then _G.SpawnDropsAt(pos, xpDrop, coinDrop) end
				end)

				if orc then
					spawned += 1
					alive += 1
					pushUi(false)
				end

				nextSpawnAt += spawnInterval
				now = time()
			end

			pushUi(false)
		end

		clearAllMobs()
		pushUi(true)
	end

	broadcast({type="complete"})
	if _G.MissionComplete then
		_G.MissionComplete(TOTAL_WAVES, math.floor(time() - startTime))
	end
end)
