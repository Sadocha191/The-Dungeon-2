local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBounds = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("WorldBounds"))
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local CraftingConfig = require(moduleFolder:WaitForChild("CraftingConfig"))

local MONUMENT_COUNT = 3
local MONUMENT_RAYCAST_TRIES = 60
local MONUMENT_HEIGHT = 2.6
local MIN_MONUMENT_GAP = 110
local CHALLENGE_DURATION = 120
local EXTRA_SPAWN_INTERVAL = 15
local EXTRA_SPAWN_COUNT = 8
local REWARD_OFFSET = 9

local RARITY_COLORS = {
	Common = Color3.fromRGB(206, 206, 206),
	Uncommon = Color3.fromRGB(88, 214, 121),
	Rare = Color3.fromRGB(79, 172, 255),
	Epic = Color3.fromRGB(185, 111, 255),
	Legendary = Color3.fromRGB(255, 177, 66),
	Mythical = Color3.fromRGB(255, 84, 129),
}

local recipeRng = Random.new()

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
local monuments = {}
local activeChallenge = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = false

local function getRarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "")] or Color3.fromRGB(255, 192, 92)
end

local function broadcast(payload)
	for _, plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

local function isAlive(plr: Player?): boolean
	if not plr or plr.Parent ~= Players then
		return false
	end
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

local function clearMonuments()
	activeChallenge = nil
	for _, monument in ipairs(monuments) do
		if monument.model and monument.model.Parent then
			monument.model:Destroy()
		end
	end
	table.clear(monuments)
end

local function getWorldBoundsXZ()
	return WorldBounds.GetXZ(28, Vector2.new(-180, -180), Vector2.new(180, 180))
end

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
		if (other - pos).Magnitude < MIN_MONUMENT_GAP then
			return false
		end
	end
	return true
end

local function randomGroundPoint(existing)
	local pMin, pMax = getWorldBoundsXZ()
	rayParams.FilterDescendantsInstances = buildRaycastBlacklist()

	for _ = 1, MONUMENT_RAYCAST_TRIES do
		local x = pMin.X + math.random() * (pMax.X - pMin.X)
		local z = pMin.Y + math.random() * (pMax.Y - pMin.Y)
		local origin = Vector3.new(x, 420, z)
		local result = workspace:Raycast(origin, Vector3.new(0, -900, 0), rayParams)
		if result then
			local pos = result.Position + Vector3.new(0, MONUMENT_HEIGHT, 0)
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

local function updatePromptStates()
	for _, monument in ipairs(monuments) do
		if monument.prompt then
			local blockedByChallenge = activeChallenge ~= nil and activeChallenge.monument ~= monument
			monument.prompt.Enabled = (not monument.activated) and (not monument.resolved) and (not blockedByChallenge)
		end
	end
end

local function queueCleanup(monument, delaySec)
	if monument.cleanupQueued then
		return
	end
	monument.cleanupQueued = true
	task.delay(delaySec or 0, function()
		if monument.model and monument.model.Parent then
			monument.model:Destroy()
		end
	end)
end

local function spawnChallengeBurst(monument, plr)
	local spawnEnemyBurst = _G.SpawnEnemyBurst
	if type(spawnEnemyBurst) ~= "function" then
		return
	end

	local anchorPos = monument.core and monument.core.Position or monument.rewardPos
	local char = plr and plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		anchorPos = hrp.Position
	end

	local runSeconds = 0
	if type(_G.GetRunSeconds) == "function" then
		runSeconds = _G.GetRunSeconds()
	end

	spawnEnemyBurst(EXTRA_SPAWN_COUNT, anchorPos, runSeconds)
end

local function finishChallenge(monument, success)
	if monument.resolved then
		return
	end

	monument.resolved = true
	activeChallenge = nil
	updatePromptStates()

	if success and monument.owner and isAlive(monument.owner) then
		if monument.core then
			monument.core.Color = Color3.fromRGB(95, 255, 153)
		end
		if monument.label then
			monument.label.Text = "REWARD"
		end

		local spawnRewardChest = _G.SpawnRewardChestForPlayer
		if type(spawnRewardChest) == "function" then
			spawnRewardChest(monument.owner, monument.rewardPos, {
				recipeId = monument.recipeId,
				recipeRarity = monument.recipeRarity,
				rewardLabel = string.format("Recipe: %s", monument.recipeName),
				accentColor = getRarityColor(monument.recipeRarity),
			})
		end

		broadcast({
			type = "heroMonumentRewardReady",
			playerName = getDisplayName(monument.owner),
			rarity = monument.recipeRarity,
			recipeName = monument.recipeName,
		})
	else
		if monument.core then
			monument.core.Color = Color3.fromRGB(255, 98, 98)
		end
		if monument.label then
			monument.label.Text = "FAILED"
		end

		broadcast({
			type = "heroMonumentFailed",
			playerName = getDisplayName(monument.owner),
			rarity = monument.recipeRarity,
		})
	end

	queueCleanup(monument, 3)
end

local function startChallenge(monument, plr: Player)
	if activeChallenge then
		return
	end

	local recipeId = CraftingConfig.RollRecipeId(recipeRng)
	local recipeDef = recipeId and CraftingConfig.GetRecipe(recipeId) or nil
	if not recipeDef then
		return
	end

	monument.activated = true
	monument.owner = plr
	monument.recipeId = recipeId
	monument.recipeName = recipeDef.weaponId or recipeId
	monument.recipeRarity = recipeDef.rarity or "Common"
	monument.challengeRemaining = CHALLENGE_DURATION

	local rarityColor = getRarityColor(monument.recipeRarity)
	if monument.core then
		monument.core.Color = rarityColor
	end
	if monument.prompt then
		monument.prompt.Enabled = false
	end
	if monument.billboard then
		monument.billboard.Enabled = true
	end
	if monument.label then
		monument.label.Text = ("%ds"):format(CHALLENGE_DURATION)
		monument.label.TextColor3 = rarityColor
	end

	activeChallenge = {
		monument = monument,
		owner = plr,
		remaining = CHALLENGE_DURATION,
		nextBurstIn = 0,
	}
	updatePromptStates()

	broadcast({
		type = "heroMonumentActivated",
		playerName = getDisplayName(plr),
		duration = CHALLENGE_DURATION,
		rarity = monument.recipeRarity,
		recipeName = monument.recipeName,
	})
end

local function buildMonument(pos: Vector3, idx: number)
	local yaw = math.rad(math.random(0, 359))
	local baseCf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)

	local model = Instance.new("Model")
	model.Name = ("HeroMonument_%d"):format(idx)

	local pedestal = newPart(model, "Pedestal", Vector3.new(9, 1.4, 9), Color3.fromRGB(76, 80, 95), Enum.Material.Slate)
	pedestal.CFrame = baseCf * CFrame.new(0, -1.8, 0)
	pedestal.CanCollide = true

	local body = newPart(model, "Body", Vector3.new(3.2, 5.2, 3.2), Color3.fromRGB(124, 130, 145), Enum.Material.Rock)
	body.CFrame = baseCf * CFrame.new(0, 0.6, 0)
	body.CanCollide = true

	local crest = newPart(model, "Crest", Vector3.new(4.4, 1.1, 1.2), Color3.fromRGB(188, 176, 124), Enum.Material.Metal)
	crest.CFrame = baseCf * CFrame.new(0, 2.7, -1.25)
	crest.CanCollide = false

	local blade = newPart(model, "Blade", Vector3.new(0.6, 5.6, 0.6), Color3.fromRGB(210, 214, 222), Enum.Material.Metal)
	blade.CFrame = baseCf * CFrame.new(0, 2.2, -0.95) * CFrame.Angles(math.rad(10), 0, 0)
	blade.CanCollide = false

	local core = newPart(model, "Core", Vector3.new(1.9, 1.9, 1.9), Color3.fromRGB(255, 214, 94), Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CFrame = baseCf * CFrame.new(0, 2.15, 0.9)
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 94)
	light.Brightness = 2.5
	light.Range = 16
	light.Parent = core

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MonumentPrompt"
	prompt.ActionText = "Invoke Hero"
	prompt.ObjectText = "Hero Monument"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Billboard"
	billboard.Size = UDim2.fromOffset(260, 62)
	billboard.StudsOffset = Vector3.new(0, 3.3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = core

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 240, 194)
	text.TextStrokeTransparency = 0.2
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = "READY"
	text.Parent = billboard

	model.PrimaryPart = core
	model.Parent = statuesFolder

	local rewardPos = core.Position + (baseCf.LookVector * REWARD_OFFSET)

	local monument = {
		model = model,
		core = core,
		prompt = prompt,
		billboard = billboard,
		label = text,
		activated = false,
		resolved = false,
		cleanupQueued = false,
		owner = nil,
		rewardPos = rewardPos,
		recipeId = nil,
		recipeName = nil,
		recipeRarity = nil,
	}

	prompt.Triggered:Connect(function(plr)
		if not RunStarted.Value or PauseState.Value then
			return
		end
		if monument.activated or monument.resolved then
			return
		end
		if not isAlive(plr) then
			return
		end

		startChallenge(monument, plr)
	end)

	return monument
end

local function spawnStatuesForRun()
	if spawnedForRun then
		return
	end
	spawnedForRun = true

	clearMonuments()

	local usedPositions = {}
	for i = 1, MONUMENT_COUNT do
		local pos = randomGroundPoint(usedPositions)
		if pos then
			table.insert(usedPositions, pos)
			table.insert(monuments, buildMonument(pos, i))
		end
	end

	updatePromptStates()
	broadcast({
		type = "heroMonumentsSpawned",
		count = #monuments,
	})
end

RunStarted.Changed:Connect(function(v)
	if v == true then
		spawnStatuesForRun()
	else
		spawnedForRun = false
		clearMonuments()
	end
end)

if RunStarted.Value == true then
	spawnStatuesForRun()
end

RunService.Heartbeat:Connect(function(dt)
	if PauseState.Value then
		return
	end
	if not RunStarted.Value then
		return
	end
	if not activeChallenge then
		return
	end

	local challenge = activeChallenge
	local monument = challenge.monument
	if not monument or monument.resolved or not monument.model or not monument.model.Parent then
		activeChallenge = nil
		updatePromptStates()
		return
	end

	if not isAlive(challenge.owner) then
		finishChallenge(monument, false)
		return
	end

	challenge.remaining = math.max(0, challenge.remaining - dt)
	challenge.nextBurstIn -= dt
	if challenge.nextBurstIn <= 0 then
		spawnChallengeBurst(monument, challenge.owner)
		challenge.nextBurstIn = EXTRA_SPAWN_INTERVAL
	end

	if monument.label then
		monument.label.Text = ("%ds"):format(math.ceil(challenge.remaining))
	end

	if challenge.remaining <= 0 then
		finishChallenge(monument, true)
	end
end)

print("[HeroMonumentService] Ready")
