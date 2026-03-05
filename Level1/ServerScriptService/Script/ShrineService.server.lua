-- ShrineService.server.lua (Level1)
-- Spawns random charge shrines on map. Staying in range for 5s grants a reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MIN_SHRINES = 3
local MAX_SHRINES = 6
local CHARGE_SECONDS = 5
local CHARGE_RADIUS = 12
local MIN_SHRINE_GAP = 26
local SHRINE_RAYCAST_TRIES = 45
local SHRINE_HEIGHT = 2.2

local XP_REWARD_MIN = 45
local XP_REWARD_MAX = 90
local COIN_REWARD_MIN = 12
local COIN_REWARD_MAX = 28
local SOUL_REWARD_CHANCE = 0.35
local SOUL_REWARD_MIN = 1
local SOUL_REWARD_MAX = 3

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

local shrinesFolder = workspace:FindFirstChild("Shrines")
if not shrinesFolder then
	shrinesFolder = Instance.new("Folder")
	shrinesFolder.Name = "Shrines"
	shrinesFolder.Parent = workspace
end

local shrines = {}
local spawnedForRun = false

local function broadcast(payload)
	if not WaveStatusEvent then
		return
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

local function clearShrines()
	for _, shrine in ipairs(shrines) do
		if shrine.model and shrine.model.Parent then
			shrine.model:Destroy()
		end
	end
	table.clear(shrines)
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
		shrinesFolder,
		workspace:FindFirstChild("Enemies"),
		workspace:FindFirstChild("Drops"),
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
		if (other - pos).Magnitude < MIN_SHRINE_GAP then
			return false
		end
	end
	return true
end

local function randomGroundPoint(existing)
	local pMin, pMax = getWorldBoundsXZ()
	rayParams.FilterDescendantsInstances = buildRaycastBlacklist()

	for _ = 1, SHRINE_RAYCAST_TRIES do
		local x = pMin.X + math.random() * (pMax.X - pMin.X)
		local z = pMin.Y + math.random() * (pMax.Y - pMin.Y)
		local origin = Vector3.new(x, 420, z)
		local result = workspace:Raycast(origin, Vector3.new(0, -900, 0), rayParams)
		if result then
			local pos = result.Position + Vector3.new(0, SHRINE_HEIGHT, 0)
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

local function buildShrine(pos, idx)
	local model = Instance.new("Model")
	model.Name = ("Shrine_%d"):format(idx)

	local pedestal = newPart(model, "Pedestal", Vector3.new(8, 1.2, 8), Color3.fromRGB(68, 74, 87), Enum.Material.Slate)
	pedestal.CFrame = CFrame.new(pos - Vector3.new(0, 1.4, 0))
	pedestal.CanCollide = true

	local pillar = newPart(model, "Pillar", Vector3.new(1.6, 3.6, 1.6), Color3.fromRGB(100, 110, 128), Enum.Material.Rock)
	pillar.CFrame = CFrame.new(pos - Vector3.new(0, 0.1, 0))
	pillar.CanCollide = true

	local core = newPart(model, "Core", Vector3.new(2.2, 2.2, 2.2), Color3.fromRGB(0, 224, 196), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CFrame = CFrame.new(pos + Vector3.new(0, 2.7, 0))
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false

	local zone = newPart(
		model,
		"ChargeZone",
		Vector3.new(CHARGE_RADIUS * 2, CHARGE_RADIUS * 2, CHARGE_RADIUS * 2),
		Color3.fromRGB(0, 214, 186),
		Enum.Material.ForceField
	)
	zone.Shape = Enum.PartType.Ball
	zone.CFrame = core.CFrame
	zone.Transparency = 0.93
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(0, 230, 197)
	light.Brightness = 2
	light.Range = CHARGE_RADIUS + 4
	light.Parent = core

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Billboard"
	billboard.Size = UDim2.fromOffset(240, 62)
	billboard.StudsOffset = Vector3.new(0, 2.9, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = core

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(235, 255, 250)
	text.TextStrokeTransparency = 0.25
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = "Kapliczka\nStoj blisko 5s"
	text.Parent = billboard

	model.PrimaryPart = core
	model.Parent = shrinesFolder

	return {
		model = model,
		core = core,
		label = text,
		progress = {},
		completed = false,
	}
end

local function getAlivePlayers()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hrp and hum.Health > 0 and plr:GetAttribute("RunEnded") ~= true then
			table.insert(list, plr)
		end
	end
	return list
end

local function randomReward()
	local xp = math.random(XP_REWARD_MIN, XP_REWARD_MAX)
	local coins = math.random(COIN_REWARD_MIN, COIN_REWARD_MAX)
	local souls = 0
	if math.random() <= SOUL_REWARD_CHANCE then
		souls = math.random(SOUL_REWARD_MIN, SOUL_REWARD_MAX)
	end
	return xp, coins, souls
end

local function completeShrine(shrine, plr)
	shrine.completed = true

	local xp, coins, souls = randomReward()
	if _G.AwardPlayer then
		pcall(function()
			_G.AwardPlayer(plr, xp, coins)
		end)
	end
	if souls > 0 and _G.AwardSouls then
		pcall(function()
			_G.AwardSouls(plr, souls)
		end)
	end

	if shrine.label then
		shrine.label.Text = ("Aktywowana!\n+%d XP +%d C"):format(xp, coins)
	end

	local zone = shrine.model:FindFirstChild("ChargeZone")
	if zone and zone:IsA("BasePart") then
		zone.Color = Color3.fromRGB(58, 255, 123)
		zone.Transparency = 0.96
	end
	local core = shrine.model:FindFirstChild("Core")
	if core and core:IsA("BasePart") then
		core.Color = Color3.fromRGB(55, 255, 135)
	end

	broadcast({
		type = "shrineComplete",
		playerName = plr.DisplayName ~= "" and plr.DisplayName or plr.Name,
		xp = xp,
		coins = coins,
		souls = souls,
	})

	task.delay(1.6, function()
		if shrine.model and shrine.model.Parent then
			shrine.model:Destroy()
		end
	end)
end

local function spawnShrinesForRun()
	if spawnedForRun then
		return
	end
	spawnedForRun = true

	clearShrines()

	local count = math.random(MIN_SHRINES, MAX_SHRINES)
	local usedPositions = {}
	for i = 1, count do
		local pos = randomGroundPoint(usedPositions)
		if pos then
			table.insert(usedPositions, pos)
			table.insert(shrines, buildShrine(pos, i))
		end
	end

	broadcast({
		type = "shrinesSpawned",
		count = #shrines,
		chargeSeconds = CHARGE_SECONDS,
	})
end

RunStarted.Changed:Connect(function(v)
	if v == true then
		spawnShrinesForRun()
	else
		spawnedForRun = false
		clearShrines()
	end
end)

if RunStarted.Value == true then
	spawnShrinesForRun()
end

RunService.Heartbeat:Connect(function(dt)
	if not RunStarted.Value then
		return
	end
	if PauseState.Value then
		return
	end
	if #shrines == 0 then
		return
	end

	local alivePlayers = getAlivePlayers()
	if #alivePlayers == 0 then
		return
	end

	for _, shrine in ipairs(shrines) do
		if shrine.completed then
			continue
		end
		if not shrine.core or not shrine.core.Parent then
			continue
		end

		local topProgress = 0
		local anyoneCharging = false

		for _, plr in ipairs(alivePlayers) do
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then
				continue
			end

			local uid = plr.UserId
			local dist = (hrp.Position - shrine.core.Position).Magnitude
			local progress = shrine.progress[uid] or 0

			if dist <= CHARGE_RADIUS then
				progress = math.min(CHARGE_SECONDS, progress + dt)
				shrine.progress[uid] = progress
				anyoneCharging = true

				if progress >= CHARGE_SECONDS then
					completeShrine(shrine, plr)
					break
				end
			else
				progress = 0
				shrine.progress[uid] = nil
			end

			if progress > topProgress then
				topProgress = progress
			end
		end

		if shrine.completed then
			continue
		end

		if shrine.label then
			if anyoneCharging and topProgress > 0 then
				local pct = math.floor((topProgress / CHARGE_SECONDS) * 100 + 0.5)
				shrine.label.Text = ("Kapliczka\nLadowanie %d%%"):format(math.clamp(pct, 0, 100))
			else
				shrine.label.Text = "Kapliczka\nStoj blisko 5s"
			end
		end
	end
end)

print("[ShrineService] Ready")