local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NpcService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("NpcService"))

local STATUE_RAYCAST_TRIES = 60
local STATUE_HEIGHT = 2.4
local MIN_STATUE_GAP = 40

local MAGNET_DURATION = 10
local BATTLE_SPAWN_COUNT = 8

local RunStarted = ReplicatedStorage:FindFirstChild("RunStarted")
if not RunStarted then
	RunStarted = Instance.new("BoolValue")
	RunStarted.Name = "RunStarted"
	RunStarted.Value = false
	RunStarted.Parent = ReplicatedStorage
end

local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local WaveStatusEvent = Remotes:FindFirstChild("WaveStatusEvent")
if not WaveStatusEvent then
	WaveStatusEvent = Instance.new("RemoteEvent")
	WaveStatusEvent.Name = "WaveStatusEvent"
	WaveStatusEvent.Parent = Remotes
end

local statuesFolder = workspace:FindFirstChild("Statues")
if not statuesFolder then
	statuesFolder = Instance.new("Folder")
	statuesFolder.Name = "Statues"
	statuesFolder.Parent = workspace
end

local spawnedForRun = false
local statues = {}

local function broadcast(payload)
	for _, plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

local function isAlive(plr: Player): boolean
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and plr:GetAttribute("RunEnded") ~= true
end

local function getDisplayName(plr: Player?): string
	if not plr then
		return "Player"
	end
	if plr.DisplayName ~= "" then
		return plr.DisplayName
	end
	return plr.Name
end

local function clearStatues()
	for _, statue in ipairs(statues) do
		if statue.model and statue.model.Parent then
			statue.model:Destroy()
		end
	end
	table.clear(statues)
end

local function getWorldBoundsXZ()
	local minX, minZ = math.huge, math.huge
	local maxX, maxZ = -math.huge, -math.huge
	local count = 0

	local function consider(inst)
		if not inst:IsA("BasePart") then return end
		if not inst.CanCollide then return end
		if inst.Size.Magnitude <= 6 then return end

		local p = inst.Position
		minX = math.min(minX, p.X)
		maxX = math.max(maxX, p.X)
		minZ = math.min(minZ, p.Z)
		maxZ = math.max(maxZ, p.Z)
		count += 1
	end

	local map = workspace:FindFirstChild("Map")
	if map then
		for _, d in ipairs(map:GetDescendants()) do
			consider(d)
		end
	else
		for _, d in ipairs(workspace:GetDescendants()) do
			if count > 1000 then break end
			consider(d)
		end
	end

	if count < 10 or minX == math.huge then
		return Vector2.new(-180, -180), Vector2.new(180, 180)
	end

	local pad = 20
	return Vector2.new(minX + pad, minZ + pad), Vector2.new(maxX - pad, maxZ - pad)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = false

local function buildRaycastBlacklist()
	local list = {
		statuesFolder,
		workspace:FindFirstChild("Enemies"),
		workspace:FindFirstChild("Drops"),
		workspace:FindFirstChild("Shrines"),
		workspace:FindFirstChild("Chests"),
	}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(list, plr.Character)
		end
	end
	return list
end

local function farEnoughFromOthers(pos, used)
	for _, other in ipairs(used) do
		if (other - pos).Magnitude < MIN_STATUE_GAP then
			return false
		end
	end
	return true
end

local function randomGroundPoint(existing)
	local pMin, pMax = getWorldBoundsXZ()
	rayParams.FilterDescendantsInstances = buildRaycastBlacklist()

	for _ = 1, STATUE_RAYCAST_TRIES do
		local x = pMin.X + math.random() * (pMax.X - pMin.X)
		local z = pMin.Y + math.random() * (pMax.Y - pMin.Y)
		local origin = Vector3.new(x, 420, z)
		local result = workspace:Raycast(origin, Vector3.new(0, -900, 0), rayParams)
		if result then
			local pos = result.Position + Vector3.new(0, STATUE_HEIGHT, 0)
			if farEnoughFromOthers(pos, existing) then
				return pos
			end
		end
	end
	return nil
end

local function newPart(parent, name, size, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.Parent = parent
	return p
end

local function waitForGlobalFunction(name: string, timeoutSec: number)
	local deadline = os.clock() + math.max(0.1, timeoutSec)
	while os.clock() <= deadline do
		local fn = _G[name]
		if type(fn) == "function" then
			return fn
		end
		task.wait(0.1)
	end
	return nil
end

local function queueCleanup(statue, delaySec)
	if statue.cleanupQueued then
		return
	end
	statue.cleanupQueued = true
	task.delay(delaySec or 0, function()
		if statue.model and statue.model.Parent then
			statue.model:Destroy()
		end
	end)
end

local completeBattleStatue

local function activateBattleStatue(statue, plr: Player)
	statue.activated = true
	statue.owner = plr
	if statue.prompt then
		statue.prompt.Enabled = false
	end
	if statue.core then
		statue.core.Color = Color3.fromRGB(255, 121, 72)
	end

	broadcast({
		type = "statueActivated",
		statueType = "battle",
		playerName = getDisplayName(plr),
		spawnCount = BATTLE_SPAWN_COUNT,
	})

	local spawnEnemyBurst = waitForGlobalFunction("SpawnEnemyBurst", 2)
	if not spawnEnemyBurst then
		statue.activated = false
		if statue.prompt then
			statue.prompt.Enabled = true
		end
		if statue.core then
			statue.core.Color = statue.idleCoreColor
		end
		return
	end

	local runSeconds = 0
	if type(_G.GetRunSeconds) == "function" then
		runSeconds = _G.GetRunSeconds()
	end

	local spawned = spawnEnemyBurst(BATTLE_SPAWN_COUNT, statue.core.Position, runSeconds)
	statue.remaining = #spawned
	if statue.remaining <= 0 then
		completeBattleStatue(statue)
		return
	end

	for _, mob in ipairs(spawned) do
		NpcService.BindDeath(mob, function()
			if statue.resolved then
				return
			end
			statue.remaining = math.max(0, (statue.remaining or 0) - 1)
			if statue.remaining <= 0 then
				completeBattleStatue(statue)
			end
		end)
	end
end

local function activateMagnetStatue(statue, plr: Player)
	statue.activated = true
	statue.resolved = true
	statue.owner = plr
	if statue.prompt then
		statue.prompt.Enabled = false
	end
	if statue.core then
		statue.core.Color = Color3.fromRGB(80, 255, 197)
	end

	local activateGlobalMagnet = waitForGlobalFunction("ActivateGlobalMagnet", 2)
	if not activateGlobalMagnet then
		statue.activated = false
		statue.resolved = false
		if statue.prompt then
			statue.prompt.Enabled = true
		end
		if statue.core then
			statue.core.Color = statue.idleCoreColor
		end
		return
	end
	activateGlobalMagnet(plr, MAGNET_DURATION)

	broadcast({
		type = "statueActivated",
		statueType = "magnet",
		playerName = getDisplayName(plr),
		duration = MAGNET_DURATION,
	})

	queueCleanup(statue, 1)
end

completeBattleStatue = function(statue)
	if statue.resolved then
		return
	end
	statue.resolved = true
	statue.remaining = 0

	if statue.core then
		statue.core.Color = Color3.fromRGB(84, 255, 130)
	end

	local spawnRewardChest = waitForGlobalFunction("SpawnRewardChestForPlayer", 2)
	if spawnRewardChest and statue.owner and statue.core then
		spawnRewardChest(statue.owner, statue.core.Position)
	end

	broadcast({
		type = "statueRewardReady",
		statueType = "battle",
		playerName = getDisplayName(statue.owner),
	})

	queueCleanup(statue, 1.25)
end

local function buildStatue(pos: Vector3, idx: number, statueType: string)
	local model = Instance.new("Model")
	model.Name = ("%sStatue_%d"):format(statueType == "battle" and "Battle" or "Magnet", idx)

	local pedestalColor = statueType == "battle" and Color3.fromRGB(88, 76, 72) or Color3.fromRGB(62, 86, 92)
	local coreColor = statueType == "battle" and Color3.fromRGB(255, 178, 82) or Color3.fromRGB(114, 241, 220)
	local lightColor = statueType == "battle" and Color3.fromRGB(255, 161, 70) or Color3.fromRGB(99, 255, 228)

	local pedestal = newPart(model, "Pedestal", Vector3.new(8, 1.3, 8), pedestalColor, Enum.Material.Slate)
	pedestal.CFrame = CFrame.new(pos - Vector3.new(0, 1.6, 0))
	pedestal.CanCollide = true

	local body = newPart(model, "Body", Vector3.new(2.8, 4.8, 2.8), Color3.fromRGB(116, 122, 138), Enum.Material.Rock)
	body.CFrame = CFrame.new(pos + Vector3.new(0, 0.7, 0))
	body.CanCollide = true

	local crown = newPart(model, "Crown", Vector3.new(3.2, 1.4, 3.2), Color3.fromRGB(136, 143, 160), Enum.Material.Rock)
	crown.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0))
	crown.CanCollide = true

	local core = newPart(model, "Core", Vector3.new(1.8, 1.8, 1.8), coreColor, Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CFrame = CFrame.new(pos + Vector3.new(0, 2.1, 0))
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false

	local light = Instance.new("PointLight")
	light.Color = lightColor
	light.Brightness = 2.2
	light.Range = 15
	light.Parent = core

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StatuePrompt"
	prompt.ActionText = statueType == "battle" and "Awaken Statue" or "Activate Magnet"
	prompt.ObjectText = statueType == "battle" and "War Statue" or "Magnet Statue"
	prompt.HoldDuration = 0.65
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	model.PrimaryPart = core
	model.Parent = statuesFolder

	local statue = {
		model = model,
		core = core,
		prompt = prompt,
		statueType = statueType,
		idleCoreColor = coreColor,
		activated = false,
		resolved = false,
		owner = nil,
		remaining = 0,
		cleanupQueued = false,
	}

	prompt.Triggered:Connect(function(plr)
		if not RunStarted.Value or PauseState.Value then
			return
		end
		if statue.activated or statue.resolved then
			return
		end
		if not plr or not plr.Parent or not isAlive(plr) then
			return
		end

		if statueType == "battle" then
			activateBattleStatue(statue, plr)
		else
			activateMagnetStatue(statue, plr)
		end
	end)

	return statue
end

local function spawnStatuesForRun()
	if spawnedForRun then
		return
	end
	spawnedForRun = true

	clearStatues()

	local usedPositions = {}
	for i, statueType in ipairs({ "battle", "magnet" }) do
		local pos = randomGroundPoint(usedPositions)
		if pos then
			table.insert(usedPositions, pos)
			table.insert(statues, buildStatue(pos, i, statueType))
		end
	end

	broadcast({
		type = "statuesSpawned",
		count = #statues,
	})
end

RunStarted.Changed:Connect(function(v)
	if v == true then
		spawnStatuesForRun()
	else
		spawnedForRun = false
		clearStatues()
	end
end)

if RunStarted.Value == true then
	spawnStatuesForRun()
end

print("[StatueService] Ready")
