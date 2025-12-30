-- WaveController.server.lua (ServerScriptService)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")

local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local ORC_TEMPLATE = ReplicatedStorage:WaitForChild("Enemies"):WaitForChild("Orc")

local WaveStatusEvent = ReplicatedStorage:WaitForChild("WaveStatusEvent")

local function broadcast(payload)
	for _,plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

local function waitIfPaused()
	while PauseState.Value do task.wait(0.05) end
end

-- ===== KONFIG (łatwiej) =====
local PREP_TIME = 5
local TOTAL_WAVES = 8
local BETWEEN_WAVES_COUNTDOWN = 5

local START_COUNT = 18
local COUNT_ADD_PER_WAVE = 3
local MAX_ALIVE_ON_MAP = 10
local WAVE_DURATION = 30

-- Moby WOLNIEJSZE niż gracz (gracz = 24)
local BASE_HP = 55
local BASE_DAMAGE = 6
local BASE_SPEED = 14
local HP_GROWTH_PER_WAVE = 0.20
local DMG_GROWTH_PER_WAVE = 0.12
local SPEED_GROWTH_PER_WAVE = 0.06
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
local PATH_RECALC = 0.65
local LOS_DIRECT_CHASE = 90
local DIRECT_UPDATE_DT = 0.35
local WAYPOINT_TIMEOUT = 1.1
local ATTACK_RANGE = 4
local ATTACK_COOLDOWN = 1.35

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

-- folders
local ENEMIES_FOLDER = workspace:FindFirstChild("Enemies")
if not ENEMIES_FOLDER then
	ENEMIES_FOLDER = Instance.new("Folder")
	ENEMIES_FOLDER.Name = "Enemies"
	ENEMIES_FOLDER.Parent = workspace
end

-- collision groups
local MOBS_GROUP = "Mobs"
pcall(function() PhysicsService:CreateCollisionGroup(MOBS_GROUP) end)
PhysicsService:CollisionGroupSetCollidable(MOBS_GROUP, MOBS_GROUP, false)

local function setMobGroup(model: Model)
	for _,d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(d, MOBS_GROUP)
		end
	end
end

-- helpers
local function anyPlayersAlive()
	for _,plr in ipairs(Players:GetPlayers()) do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then return true end
	end
	return false
end

local function getAlivePlayerHRPs()
	local list = {}
	for _,plr in ipairs(Players:GetPlayers()) do
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
	for _,plr in ipairs(Players:GetPlayers()) do
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

local function clamp(x,a,b)
	if x<a then return a end
	if x>b then return b end
	return x
end

local function makeWaveStats(wave: number)
	local hp = math.floor(BASE_HP * (1 + HP_GROWTH_PER_WAVE * (wave-1)))
	local dmg = math.floor(BASE_DAMAGE * (1 + DMG_GROWTH_PER_WAVE * (wave-1)))
	local spd = math.floor(clamp(BASE_SPEED * (1 + SPEED_GROWTH_PER_WAVE * (wave-1)), BASE_SPEED, SPEED_CAP))
	local total = START_COUNT + COUNT_ADD_PER_WAVE * (wave-1)
	return hp, dmg, spd, total
end

local function randomPointInRing(center: Vector3)
	local theta = math.random() * math.pi * 2
	local r = SPAWN_RING_MIN + math.random() * (SPAWN_RING_MAX - SPAWN_RING_MIN)
	return center + Vector3.new(math.cos(theta)*r, 0, math.sin(theta)*r)
end

local function getSlopeDegrees(normal: Vector3)
	local up = Vector3.new(0,1,0)
	local dot = math.clamp(normal:Dot(up), -1, 1)
	return math.deg(math.acos(dot))
end

local function raycastToGround(xzPoint: Vector3)
	local origin = Vector3.new(xzPoint.X, SPAWN_RAY_START_Y, xzPoint.Z)
	local direction = Vector3.new(0, -GROUND_RAY_DIST, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ENEMIES_FOLDER }
	return workspace:Raycast(origin, direction, params)
end

local function isClearAt(cframe: CFrame, size: Vector3)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { ENEMIES_FOLDER }
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(exclude, plr.Character) end
	end
	params.FilterDescendantsInstances = exclude
	for _,p in ipairs(workspace:GetPartBoundsInBox(cframe, size, params)) do
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

	for _=1,MAX_SPAWN_TRIES do
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
	for _,m in ipairs(ENEMIES_FOLDER:GetChildren()) do
		m:Destroy()
	end
end

local function hasLOS(fromPos: Vector3, toPos: Vector3, ignoreList: {Instance})
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList
	return workspace:Raycast(fromPos, (toPos-fromPos), params) == nil
end

local function computeWaypoints(fromPos: Vector3, toPos: Vector3)
	local path = PathfindingService:CreatePath(PATH_PARAMS)
	local ok = pcall(function() path:ComputeAsync(fromPos, toPos) end)
	if not ok then return nil end
	if path.Status ~= Enum.PathStatus.Success then return nil end
	return path:GetWaypoints()
end

-- HP bar mały
local function attachHpBar(model: Model, hum: Humanoid)
	for _,d in ipairs(model:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Name == "HPBillboard" then d:Destroy() end
	end
	local anchor = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
	if not (anchor and anchor:IsA("BasePart")) then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBillboard"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 110
	gui.Size = UDim2.fromOffset(100, 12)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.Parent = anchor

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1,1)
	back.BackgroundColor3 = Color3.fromRGB(10,10,12)
	back.BackgroundTransparency = 0.28
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 8)

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.fromOffset(6, 4)
	barBg.Size = UDim2.new(1, -12, 1, -8)
	barBg.BackgroundColor3 = Color3.fromRGB(36,36,40)
	barBg.BorderSizePixel = 0
	barBg.Parent = back
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 999)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1,1)
	fill.BackgroundColor3 = Color3.fromRGB(80,200,120)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 999)

	local function refresh()
		local maxHp = math.max(1, hum.MaxHealth)
		local cur = math.clamp(hum.Health, 0, maxHp)
		fill.Size = UDim2.new(cur/maxHp, 0, 1, 0)
	end
	refresh()
	hum.HealthChanged:Connect(refresh)
	hum.Died:Connect(function()
		if gui and gui.Parent then gui:Destroy() end
	end)
end

-- MOB “slot offset” => nie idą w jednej linii
local function offsetGoal(targetPos: Vector3, orc: Model)
	local angle = orc:GetAttribute("SlotAngle")
	local radius = orc:GetAttribute("SlotRadius")
	if typeof(angle) ~= "number" then
		angle = math.random() * math.pi * 2
		orc:SetAttribute("SlotAngle", angle)
	end
	if typeof(radius) ~= "number" then
		radius = 6 + math.random()*6
		orc:SetAttribute("SlotRadius", radius)
	end
	return targetPos + Vector3.new(math.cos(angle)*radius, 0, math.sin(angle)*radius)
end

local function dropsForWave(wave: number)
	local xp = math.floor(10 + (wave-1)*4 + math.random(0,4))
	local coins = math.floor(2 + (wave-1)*1.0 + math.random(0,2))
	return xp, coins
end

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
	attachHpBar(orc, hum)

	local killed = false
	local function markKill(pos: Vector3)
		if killed then return end
		killed = true
		if onKill then onKill(pos) end
		task.defer(function()
			if orc and orc.Parent then orc:Destroy() end
		end)
	end

	hum.Died:Connect(function() markKill(root.Position) end)
	orc.AncestryChanged:Connect(function(_, parent)
		if parent == nil then markKill(root.Position) end
	end)

	task.spawn(function()
		local lastAttack = 0
		local lastPath = 0
		local waypoints = nil
		local wpIndex = 2
		local lastDirect = 0
		local goalSetAt = 0
		local currentGoal: Vector3? = nil

		local moveConn
		moveConn = hum.MoveToFinished:Connect(function(reached)
			if not reached then return end
			if waypoints and wpIndex < #waypoints then
				wpIndex += 1
				local wp = waypoints[wpIndex]
				if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
				hum:MoveTo(wp.Position)
				currentGoal = wp.Position
				goalSetAt = time()
			end
		end)

		while hum.Health > 0 and orc.Parent do
			waitIfPaused()
			task.wait(THINK_INTERVAL)

			if root.Position.Y < KILL_BELOW_Y then
				root.CFrame = getSafeSpawnCFrame(orc)
				waypoints = nil
				currentGoal = nil
			end

			local targetChar = getClosestLivingCharacter(root.Position)
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

			local targetPos = offsetGoal(targetRoot.Position, orc)
			local dist = (targetRoot.Position - root.Position).Magnitude

			if dist > TELEPORT_IF_FAR then
				root.CFrame = getSafeSpawnCFrame(orc)
				waypoints = nil
				currentGoal = nil
				continue
			end

			local now = time()
			if dist <= ATTACK_RANGE and (now - lastAttack) >= ATTACK_COOLDOWN then
				lastAttack = now
				targetHum:TakeDamage(dmg)
			end

			if dist <= LOS_DIRECT_CHASE and hasLOS(root.Position, targetRoot.Position, {orc}) then
				waypoints = nil
				if (now - lastDirect) >= DIRECT_UPDATE_DT then
					lastDirect = now
					hum:MoveTo(targetPos)
					currentGoal = targetPos
					goalSetAt = now
				end
				continue
			end

			if (not waypoints) or (now - lastPath >= PATH_RECALC) then
				lastPath = now
				waypoints = computeWaypoints(root.Position, targetPos)
				wpIndex = 2
				currentGoal = nil
				if waypoints and #waypoints >= 2 then
					local wp = waypoints[wpIndex]
					if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
					hum:MoveTo(wp.Position)
					currentGoal = wp.Position
					goalSetAt = now
				end
			end

			if waypoints and currentGoal and (now - goalSetAt) > WAYPOINT_TIMEOUT then
				waypoints = nil
				currentGoal = nil
			end
		end

		if moveConn then moveConn:Disconnect() end
		if orc and orc.Parent then orc:Destroy() end
	end)

	return orc
end

-- ===== MAIN =====
task.spawn(function()
	while #Players:GetPlayers() == 0 do task.wait(1) end

	for t=PREP_TIME,1,-1 do
		waitIfPaused()
		broadcast({type="prepTick", seconds=t})
		task.wait(1)
	end
	broadcast({type="prepTick", seconds=0})

	for wave=1,TOTAL_WAVES do
		while #Players:GetPlayers()==0 do task.wait(1) end

		if wave > 1 then
			for t=BETWEEN_WAVES_COUNTDOWN,1,-1 do
				waitIfPaused()
				broadcast({type="waveCountdown", nextWave=wave, totalWaves=TOTAL_WAVES, seconds=t})
				task.wait(1)
			end
			broadcast({type="waveCountdown", nextWave=wave, totalWaves=TOTAL_WAVES, seconds=0})
		end

		local hp,dmg,spd,total = makeWaveStats(wave)
		local killed, alive, spawned = 0,0,0
		local remaining = total

		broadcast({type="waveStart", wave=wave, totalWaves=TOTAL_WAVES, totalToKill=total, remaining=remaining})

		local lastUi = 0
		local function pushUi(force)
			local now = time()
			if force or (now-lastUi) >= UI_PUSH_DT then
				lastUi = now
				broadcast({type="waveUpdate", wave=wave, totalWaves=TOTAL_WAVES, totalToKill=total, remaining=remaining, alive=alive, spawned=spawned})
			end
		end

		local spawnInterval = math.max(0.20, WAVE_DURATION / math.max(1,total))
		local nextSpawnAt = time()

		while killed < total do
			waitIfPaused()
			task.wait(0.15)

			if not anyPlayersAlive() then
				clearAllMobs()
				alive = 0
				while not anyPlayersAlive() do task.wait(0.25) end
				for t=3,1,-1 do
					waitIfPaused()
					broadcast({type="waveCountdown", nextWave=wave, totalWaves=TOTAL_WAVES, seconds=t})
					task.wait(1)
				end
				nextSpawnAt = time() + 0.2
			end

			local now = time()
			while spawned < total and alive < MAX_ALIVE_ON_MAP and now >= nextSpawnAt do
				local xpDrop, coinDrop = dropsForWave(wave)

				local orc = spawnOrc(hp,dmg,spd,wave,function(pos)
					killed += 1
					remaining = math.max(0, total-killed)
					alive = math.max(0, alive-1)
					pushUi(false)

					-- SPAWN ORBÓW (zamiast dawać od razu)
					if _G.SpawnDropsAt then
						_G.SpawnDropsAt(pos, xpDrop, coinDrop)
					end
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
end)
