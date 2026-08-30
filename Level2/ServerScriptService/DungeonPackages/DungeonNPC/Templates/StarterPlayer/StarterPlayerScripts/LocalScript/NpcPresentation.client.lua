local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local NpcShared = require(moduleFolder:WaitForChild("NpcShared"))
local NpcVisualPool = require(moduleFolder:WaitForChild("NpcVisualPool"))
local LoadingOverlay = require(moduleFolder:WaitForChild("ClientLoadingOverlay"))

local reliableEvent = remotes:WaitForChild(NpcShared.RemoteName)
local motionEvent = remotes:WaitForChild(NpcShared.MotionRemoteName)
local syncRequestEvent = remotes:WaitForChild(NpcShared.SyncRequestRemoteName)
local pool = NpcVisualPool.new({ assets = ReplicatedStorage:WaitForChild("Assets") })

local INTERPOLATION_DELAY = 0.10
local MAX_EXTRAPOLATION = 0.12
local CULL_DISTANCE = 240
local presentations = {}
local requestId = 0
local syncOverlayToken = nil
local syncFullReceived = false
local syncPrewarmTotal = 0
local networkStartedAt = os.clock()
local reliablePackets = 0
local reliableRecords = 0
local motionPackets = 0
local motionRecords = 0
local metricsAccumulator = 0
local classifyAccumulator = NpcShared.PresentationLod.ClassificationInterval
local frameSamples = 0
local frameSeconds = 0
local frameMaximum = 0
local lodCounts = { Critical = 0, Near = 0, Mid = 0, Far = 0, Culled = 0 }

local debugSnapshotConnection = nil
local function bindDebugSnapshotRemote(remote: Instance)
	if not RunService:IsStudio() or not remote:IsA("RemoteFunction") then
		return
	end
	remote.OnClientInvoke = function(requestedNpcId: string?)
		local poolMetrics = pool:GetMetrics()
		local presentationCount = 0
		local presentationsWithVisual = 0
		for _, entry in pairs(presentations) do
			presentationCount += 1
			if entry.record then
				presentationsWithVisual += 1
			end
		end
		local requestedEntry = requestedNpcId and presentations[tostring(requestedNpcId)] or nil
		return {
			activeVisuals = poolMetrics.active,
			freeVisuals = poolMetrics.inactive,
			poolCapacity = poolMetrics.capacity,
			presentationRecords = presentationCount,
			presentationsWithVisual = presentationsWithVisual,
			requestedNpcPresent = requestedEntry ~= nil,
			requestedNpcHasVisual = requestedEntry ~= nil and requestedEntry.record ~= nil,
		}
	end
	if debugSnapshotConnection then
		debugSnapshotConnection:Disconnect()
		debugSnapshotConnection = nil
	end
end

if RunService:IsStudio() then
	local existingDebugRemote = remotes:FindFirstChild(NpcShared.DebugSnapshotRemoteName)
	if existingDebugRemote then
		bindDebugSnapshotRemote(existingDebugRemote)
	else
		debugSnapshotConnection = remotes.ChildAdded:Connect(function(child)
			if child.Name == NpcShared.DebugSnapshotRemoteName then
				bindDebugSnapshotRemote(child)
			end
		end)
	end
end

local metricsFolder = workspace:FindFirstChild("NpcPresentationMetrics")
if not metricsFolder then
	metricsFolder = Instance.new("Folder")
	metricsFolder.Name = "NpcPresentationMetrics"
	metricsFolder.Parent = workspace
end

local spawnFx = {}
for index = 1, 16 do
	local part = Instance.new("Part")
	part.Name = "NpcSpawnFx_" .. index
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Ground
	part.Color = Color3.fromRGB(98, 75, 52)
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.06, 0.1)
	part.CFrame = CFrame.new(0, -12000 - index, 0)
	part.Parent = pool.visualFolder
	spawnFx[index] = { part = part, active = false, startedAt = 0, scale = 1 }
end

local function flatSpeed(value: Vector3?): number
	if typeof(value) ~= "Vector3" then
		return 0
	end
	return math.sqrt(value.X * value.X + value.Z * value.Z)
end

local function safeDirection(value: Vector3?, fallback: Vector3?): Vector3
	if typeof(value) == "Vector3" and value.Magnitude > 1e-4 then
		return value.Unit
	end
	if typeof(fallback) == "Vector3" and fallback.Magnitude > 1e-4 then
		return fallback.Unit
	end
	return Vector3.new(0, 0, -1)
end

local function movementDirection(value: Vector3?, movementMode: string?, surfaceNormal: Vector3?): Vector3
	local direction = safeDirection(value, Vector3.new(0, 0, -1))
	if movementMode == "Surface" then
		local up = safeDirection(surfaceNormal, Vector3.yAxis)
		local tangent = direction - up * direction:Dot(up)
		if tangent.Magnitude <= 1e-4 then
			local axis = math.abs(up:Dot(Vector3.zAxis)) < 0.95 and Vector3.zAxis or Vector3.xAxis
			tangent = axis - up * axis:Dot(up)
		end
		return tangent.Unit
	end
	if movementMode ~= "Flying" then
		return safeDirection(Vector3.new(direction.X, 0, direction.Z), Vector3.new(0, 0, -1))
	end
	return direction
end

local function setModelVisible(record, visible: boolean)
	if record.visible == visible then
		return
	end
	debug.profilebegin("NpcPresentation.CullTransition")
	record.visible = visible
	for _, descendant in ipairs(record.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = visible and 0 or 1
		end
	end
	if not visible then
		if record.currentTrack then
			pcall(function()
				record.currentTrack:Stop(0.05)
			end)
		end
		record.currentTrack = nil
		record.currentAnimationState = nil
		record.currentAnimationToken = nil
		record.model:PivotTo(CFrame.new(0, -14000 - record.index * 18, 0))
	end
	debug.profileend()
end

local function playSpawnFx(position: Vector3, scale: number?)
	local selected = spawnFx[1]
	for _, candidate in ipairs(spawnFx) do
		if not candidate.active then
			selected = candidate
			break
		end
		if candidate.startedAt < selected.startedAt then
			selected = candidate
		end
	end
	selected.active = true
	selected.startedAt = os.clock()
	selected.scale = math.clamp(tonumber(scale) or 1, 0.8, 3.5)
	selected.part.CFrame = CFrame.new(position + Vector3.new(0, 0.04, 0))
end

local function updateSpawnFx(now: number)
	for _, effect in ipairs(spawnFx) do
		if effect.active then
			local alpha = (now - effect.startedAt) / 0.55
			if alpha >= 1 then
				effect.active = false
				effect.part.Transparency = 1
				effect.part.CFrame = CFrame.new(0, -12000, 0)
			else
				local size = (2.2 + alpha * 2.8) * effect.scale
				effect.part.Size = Vector3.new(size, 0.06, size)
				effect.part.Transparency = 0.45 + alpha * 0.55
			end
		end
	end
end

local function releaseEntry(id: string)
	local entry = presentations[id]
	if not entry then
		return
	end
	if entry.record then
		pool:Release(entry.record)
		entry.record = nil
	end
	presentations[id] = nil
end

local function getOrCreateEntry(id: string)
	local entry = presentations[id]
	if entry then
		return entry
	end
	entry = {
		id = id,
		state = NpcShared.States.Spawn,
		stateChangedAt = os.clock(),
		dead = false,
		despawned = false,
		lod = "Near",
		nextVisualAt = 0,
		retryAcquireAt = 0,
	}
	presentations[id] = entry
	return entry
end

local function writeVisualAttributes(entry)
	local model = entry.record and entry.record.model
	if not model then
		return
	end
	model:SetAttribute("NpcState", entry.state)
	model:SetAttribute("State", entry.state)
	model:SetAttribute("NpcHealth", entry.hp)
	model:SetAttribute("Health", entry.hp)
	model:SetAttribute("NpcMaxHealth", entry.maxHp)
	model:SetAttribute("MaxHealth", entry.maxHp)
	model:SetAttribute("NpcDead", entry.dead)
	model:SetAttribute("IsDead", entry.dead)
end

local function ensureVisual(entry, now: number)
	if entry.record or not entry.visual or entry.despawned or now < entry.retryAcquireAt then
		return
	end
	local record = pool:Acquire(entry.visual, entry.id)
	if not record then
		entry.retryAcquireAt = now + 1
		return
	end
	entry.record = record
	setModelVisible(record, entry.lod ~= "Culled")
	writeVisualAttributes(entry)
	if entry.showSpawnFx and entry.nextMotion and typeof(entry.nextMotion.pos) == "Vector3" then
		playSpawnFx(entry.nextMotion.pos, entry.visual.visualScale)
		entry.showSpawnFx = false
	end
end

local function updateReliableEntry(entry, item, isFull: boolean)
	if typeof(item.visual) == "table" then
		entry.visual = item.visual
	end
	entry.type = item.type or entry.type
	entry.rank = item.rank or entry.rank
	entry.displayName = item.displayName or entry.displayName
	entry.isElite = item.isElite == true
	entry.isMiniBoss = item.isMiniBoss == true
	entry.isBoss = item.isBoss == true
	entry.movementMode = item.movementMode or entry.movementMode
	entry.movementProfile = item.movementProfile or entry.movementProfile
	entry.speed = tonumber(item.speed) or entry.speed or 0
	entry.hp = tonumber(item.hp) or entry.hp
	entry.maxHp = tonumber(item.maxHp) or entry.maxHp
	local nextState = tostring(item.state or entry.state)
	if nextState ~= entry.state then
		entry.state = nextState
		entry.stateChangedAt = os.clock()
	end
	entry.dead = item.dead == true
	entry.despawned = item.despawned == true
	if item.spawn == true and not isFull then
		entry.showSpawnFx = true
	end
	if entry.despawned or entry.dead then
		releaseEntry(entry.id)
		return
	end
	writeVisualAttributes(entry)
end

reliableEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.items) ~= "table" then
		return
	end
	reliablePackets += 1
	reliableRecords += #payload.items
	local full = payload.full == true
	local seen = full and {} or nil
	if typeof(payload.prewarmPlan) == "table" then
		pool:QueuePrewarm(payload.prewarmPlan)
		syncPrewarmTotal = 0
		for _, descriptor in ipairs(payload.prewarmPlan) do
			syncPrewarmTotal += math.max(0, math.floor(tonumber(descriptor.count) or 0))
		end
	end
	for _, item in ipairs(payload.items) do
		local id = tostring(item.id or "")
		if id ~= "" then
			if seen then
				seen[id] = true
			end
			local entry = getOrCreateEntry(id)
			updateReliableEntry(entry, item, full)
		end
	end
	if seen then
		for id in pairs(presentations) do
			if not seen[id] then
				releaseEntry(id)
			end
		end
		if tonumber(payload.requestId) == requestId then
			syncFullReceived = true
		end
	end
end)

motionEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or typeof(payload.items) ~= "table" then
		return
	end
	motionPackets += 1
	motionRecords += #payload.items
	local serverTime = tonumber(payload.serverTime) or workspace:GetServerTimeNow()
	for _, item in ipairs(payload.items) do
		local id = tostring(item.id or item[1] or "")
		local position = item.pos or item[2]
		local direction = item.dir or item[3]
		local velocity = item.vel or item[4]
		local normal = item.surfaceNormal or item[5]
		if id ~= "" and typeof(position) == "Vector3" then
			local entry = presentations[id]
			if not entry then
				continue
			end
			entry.previousMotion = entry.nextMotion
			entry.nextMotion = {
				time = serverTime,
				pos = position,
				dir = safeDirection(direction, entry.nextMotion and entry.nextMotion.dir),
				vel = typeof(velocity) == "Vector3" and velocity or Vector3.zero,
				surfaceNormal = safeDirection(normal, Vector3.yAxis),
			}
			if not entry.previousMotion then
				entry.previousMotion = entry.nextMotion
			end
		end
	end
end)

local function sampleMotion(entry, renderTime: number)
	local nextMotion = entry.nextMotion
	if not nextMotion then
		return nil
	end
	local previous = entry.previousMotion or nextMotion
	local interval = nextMotion.time - previous.time
	if interval > 1e-4 and renderTime <= nextMotion.time then
		local alpha = math.clamp((renderTime - previous.time) / interval, 0, 1)
		return {
			pos = previous.pos:Lerp(nextMotion.pos, alpha),
			dir = safeDirection(previous.dir:Lerp(nextMotion.dir, alpha), nextMotion.dir),
			vel = previous.vel:Lerp(nextMotion.vel, alpha),
			surfaceNormal = safeDirection(previous.surfaceNormal:Lerp(nextMotion.surfaceNormal, alpha), Vector3.yAxis),
		}
	end
	local extrapolation = math.clamp(renderTime - nextMotion.time, 0, MAX_EXTRAPOLATION)
	return {
		pos = nextMotion.pos + nextMotion.vel * extrapolation,
		dir = safeDirection(nextMotion.vel, nextMotion.dir),
		vel = nextMotion.vel,
		surfaceNormal = nextMotion.surfaceNormal,
	}
end

local function classify(entry, camera)
	local motion = entry.nextMotion
	if not motion or not camera then
		return "Culled"
	end
	local distance = (motion.pos - camera.CFrame.Position).Magnitude
	local _, onScreen = camera:WorldToViewportPoint(motion.pos)
	if entry.isBoss or entry.isMiniBoss or distance <= NpcShared.PresentationLod.CriticalDistance then
		return "Critical"
	end
	if not onScreen or distance > CULL_DISTANCE then
		return "Culled"
	end
	if distance <= NpcShared.PresentationLod.NearDistance then
		return "Near"
	end
	if distance <= NpcShared.PresentationLod.MidDistance then
		return "Mid"
	end
	return "Far"
end

local function lodHz(lod: string): number
	if lod == "Critical" or lod == "Near" then
		return NpcShared.PresentationLod.NearHz
	end
	if lod == "Mid" then
		return NpcShared.PresentationLod.MidHz
	end
	if lod == "Far" then
		return NpcShared.PresentationLod.FarHz
	end
	return NpcShared.PresentationLod.CulledHz
end

local function animationState(entry, motion): string
	if entry.dead then
		return "death"
	end
	if entry.state == NpcShared.States.Attacking then
		return "attack"
	end
	local speed = entry.movementMode == "Flying" and motion.vel.Magnitude or flatSpeed(motion.vel)
	return speed > 0.75 and "run" or "idle"
end

local function poseFor(entry, motion, now: number): CFrame
	local pose = CFrame.identity
	local model = entry.record and entry.record.model
	if model and model:GetAttribute("NpcLightweight") == true and not entry.dead then
		local speed = flatSpeed(motion.vel)
		local moving = speed > 0.75
		local phase = tonumber(entry.id) or 0
		local bob = math.sin(now * (moving and 8 or 1.8) + phase) * (moving and 0.10 or 0.035)
		pose = CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, math.sin(now * 1.8 + phase) * 0.025)
	end
	if entry.type == "Goblin" and entry.state == NpcShared.States.Attacking and not entry.dead then
		local alpha = math.clamp((now - entry.stateChangedAt) / 0.38, 0, 1)
		pose *= CFrame.Angles(0, 0, math.sin(alpha * math.pi) * math.rad(28))
	end
	return pose
end

local function updatePresentation(entry, now: number, renderTime: number)
	if syncOverlayToken and not pool:IsPrewarmComplete() then
		return
	end
	ensureVisual(entry, now)
	local record = entry.record
	if record and entry.showSpawnFx and entry.nextMotion then
		playSpawnFx(entry.nextMotion.pos, entry.visual and entry.visual.visualScale)
		entry.showSpawnFx = false
	end
	if not record or now < entry.nextVisualAt then
		return
	end
	entry.nextVisualAt = now + 1 / lodHz(entry.lod)
	if entry.lod == "Culled" then
		return
	end
	local motion = sampleMotion(entry, renderTime)
	if not motion then
		return
	end
	local up = entry.movementMode == "Surface" and motion.surfaceNormal or Vector3.yAxis
	local forward = movementDirection(motion.vel.Magnitude > 0.2 and motion.vel or motion.dir, entry.movementMode, up)
	if math.abs(forward:Dot(up)) > 0.98 then
		up = Vector3.xAxis
	end
	local rootFrame = CFrame.lookAt(motion.pos, motion.pos + forward, up)
	record.model:PivotTo(rootFrame * poseFor(entry, motion, now) * record.rootToPivot)
	local stateName = animationState(entry, motion)
	pool:PlayAnimation(record, stateName, entry.stateChangedAt)
	if stateName == "run" and record.currentTrack then
		pcall(function()
			record.currentTrack:AdjustSpeed(math.clamp(flatSpeed(motion.vel) / math.max(1, entry.speed), 0.6, 1.8))
		end)
	end
end

local function publishMetrics()
	local poolMetrics = pool:GetMetrics()
	local elapsed = math.max(0.001, os.clock() - networkStartedAt)
	metricsFolder:SetAttribute("ActiveVisuals", poolMetrics.active)
	metricsFolder:SetAttribute("PoolCapacity", poolMetrics.capacity)
	metricsFolder:SetAttribute("PooledInactive", poolMetrics.inactive)
	metricsFolder:SetAttribute("PoolGrowths", poolMetrics.growths)
	metricsFolder:SetAttribute("VisualsCreated", poolMetrics.created)
	metricsFolder:SetAttribute("VisualsCreatedDuringRun", poolMetrics.createdDuringRun)
	metricsFolder:SetAttribute("PrewarmRemaining", poolMetrics.prewarmRemaining)
	metricsFolder:SetAttribute("AcquireAverageMs", poolMetrics.averageAcquireMs)
	metricsFolder:SetAttribute("AcquireMaximumMs", poolMetrics.maximumAcquireMs)
	metricsFolder:SetAttribute("ReleaseAverageMs", poolMetrics.averageReleaseMs)
	metricsFolder:SetAttribute("ReleaseMaximumMs", poolMetrics.maximumReleaseMs)
	metricsFolder:SetAttribute("ReliablePacketsPerSecond", reliablePackets / elapsed)
	metricsFolder:SetAttribute("ReliableRecordsPerSecond", reliableRecords / elapsed)
	metricsFolder:SetAttribute("MotionPacketsPerSecond", motionPackets / elapsed)
	metricsFolder:SetAttribute("MotionRecordsPerSecond", motionRecords / elapsed)
	metricsFolder:SetAttribute("PresentationAverageMs", frameSamples > 0 and frameSeconds / frameSamples * 1000 or 0)
	metricsFolder:SetAttribute("PresentationMaximumMs", frameMaximum * 1000)
	for lod, count in pairs(lodCounts) do
		metricsFolder:SetAttribute("Lod" .. lod, count)
	end
	frameSamples = 0
	frameSeconds = 0
	frameMaximum = 0
end

RunService.RenderStepped:Connect(function(dt)
	local frameStartedAt = os.clock()
	debug.profilebegin("NpcPresentation.Frame")
	local now = os.clock()
	local renderTime = workspace:GetServerTimeNow() - INTERPOLATION_DELAY
	pool:StepPrewarm(syncOverlayToken and 3 or 1)
	updateSpawnFx(now)

	classifyAccumulator += dt
	if classifyAccumulator >= NpcShared.PresentationLod.ClassificationInterval then
		debug.profilebegin("NpcPresentation.Classify")
		classifyAccumulator %= NpcShared.PresentationLod.ClassificationInterval
		for lod in pairs(lodCounts) do
			lodCounts[lod] = 0
		end
		local camera = workspace.CurrentCamera
		for _, entry in pairs(presentations) do
			local nextLod = classify(entry, camera)
			if nextLod ~= entry.lod then
				entry.lod = nextLod
				entry.nextVisualAt = 0
			end
			lodCounts[entry.lod] += 1
			if entry.record then
				setModelVisible(entry.record, entry.lod ~= "Culled")
			end
		end
		debug.profileend()
	end

	for id, entry in pairs(presentations) do
		updatePresentation(entry, now, renderTime)
	end

	if syncOverlayToken and syncFullReceived then
		local poolMetrics = pool:GetMetrics()
		local complete = poolMetrics.prewarmRemaining == 0
		local progress = syncPrewarmTotal > 0
			and math.clamp(1 - poolMetrics.prewarmRemaining / syncPrewarmTotal, 0, 1)
			or 1
		LoadingOverlay.Update(syncOverlayToken, {
			title = "Preparing enemies",
			message = string.format("NPC visual pool: %d / %d", syncPrewarmTotal - poolMetrics.prewarmRemaining, syncPrewarmTotal),
			progress = progress,
		})
		if complete then
			LoadingOverlay.Release(syncOverlayToken)
			syncOverlayToken = nil
		end
	end

	metricsAccumulator += dt
	local frameDuration = os.clock() - frameStartedAt
	frameSamples += 1
	frameSeconds += frameDuration
	frameMaximum = math.max(frameMaximum, frameDuration)
	if metricsAccumulator >= 1 then
		metricsAccumulator %= 1
		publishMetrics()
	end
	debug.profileend()
end)

local function requestFullSync()
	requestId += 1
	syncFullReceived = false
	syncPrewarmTotal = 0
	if syncOverlayToken then
		LoadingOverlay.Release(syncOverlayToken)
	end
	syncOverlayToken = LoadingOverlay.Acquire({
		title = "Preparing enemies",
		message = "Synchronizing NPC state",
		progress = 0,
	})
	syncRequestEvent:FireServer(requestId)
end

requestFullSync()
localPlayer.CharacterAdded:Connect(requestFullSync)
