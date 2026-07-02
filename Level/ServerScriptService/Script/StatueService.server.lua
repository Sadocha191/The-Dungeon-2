local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("ModuleScript")
local NpcService = require(modules:WaitForChild("NpcService"))
local RunProgressApi = require(modules:WaitForChild("RunProgressApi"))
local WorldBounds = require(modules:WaitForChild("WorldBounds"))
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local CraftingConfig = require(moduleFolder:WaitForChild("CraftingConfig"))

local STATUE_RAYCAST_TRIES = 60
local STATUE_HEIGHT = 2.4
local MONUMENT_HEIGHT = 2.6
local MIN_STATUE_GAP = 40
local MIN_MONUMENT_GAP = 110

local MAGNET_DURATION = 10
local BATTLE_SPAWN_COUNT = 8
local STATUE_SPAWN_ORDER = { "battle", "magnet", "battle", "magnet", "battle", "magnet" }

local MONUMENT_COUNT = 3
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
local statues = {}
local monuments = {}
local activeChallenge = nil
local isAlive

local function getRarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "")] or Color3.fromRGB(255, 192, 92)
end

local function fireRewardReveal(plr: Player, payload)
	if not isAlive(plr) then
		return
	end
	WaveStatusEvent:FireClient(plr, payload)
end

local function buildStatueRevealPayload(statueType: string)
	if statueType == "battle" then
		return {
			type = "rewardReveal",
			revealKind = "statue",
			headerText = "Statue Draw",
			sourceName = "War Statue",
			itemName = "War Decree",
			rarity = "Rare",
			description = string.format("Summons %d enemies. Clear the wave to spawn a reward chest.", BATTLE_SPAWN_COUNT),
			detailText = "Challenge Event",
			rollDuration = 0.9,
			holdDuration = 1.7,
			candidates = {
				{ label = "Reading Sigils", rarity = "Common" },
				{ label = "Forging Oath", rarity = "Uncommon" },
				{ label = "Binding Trial", rarity = "Rare" },
			},
		}
	end

	return {
		type = "rewardReveal",
		revealKind = "statue",
		headerText = "Statue Draw",
		sourceName = "Magnet Statue",
		itemName = "Magnet Blessing",
		rarity = "Epic",
		description = string.format("XP and coin drops rush to you for %d seconds.", MAGNET_DURATION),
		detailText = string.format("%ds Buff", MAGNET_DURATION),
		rollDuration = 0.9,
		holdDuration = 1.7,
		candidates = {
			{ label = "Charging Core", rarity = "Common" },
			{ label = "Tracing Leylines", rarity = "Rare" },
			{ label = "Stabilizing Field", rarity = "Epic" },
		},
	}
end

local function broadcast(payload)
	for _, plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

isAlive = function(plr: Player?): boolean
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

local function destroyEntries(entries)
	for _, entry in ipairs(entries) do
		if entry.model and entry.model.Parent then
			entry.model:Destroy()
		end
	end
	table.clear(entries)
end

local function clearStructures()
	activeChallenge = nil
	destroyEntries(statues)
	destroyEntries(monuments)
end

local function buildRaycastIgnore()
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

local function buildOverlapIgnore()
	local list = {
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

local function farEnoughFromOthers(pos, used, minGap)
	for _, other in ipairs(used) do
		local otherPos = other.pos or other
		local otherGap = other.gap or 0
		if (otherPos - pos).Magnitude < math.max(minGap, otherGap) then
			return false
		end
	end
	return true
end

local function randomGroundPoint(existing, minGap, heightOffset)
	local clearanceRadius = minGap >= MIN_MONUMENT_GAP and 8.5 or 6.5
	return WorldBounds.FindRandomTerrainPoint({
		pad = 28,
		tries = STATUE_RAYCAST_TRIES,
		heightOffset = heightOffset,
		raycastIgnoreInstances = buildRaycastIgnore(),
		overlapIgnoreInstances = buildOverlapIgnore(),
		clearanceRadius = clearanceRadius,
		clearanceHeight = 10,
		maxSlopeDeg = 35,
		fallbackMin = Vector2.new(-180, -180),
		fallbackMax = Vector2.new(180, 180),
		isValid = function(pos)
			return farEnoughFromOthers(pos, existing, minGap)
		end,
	})
end

local function rememberPosition(used, pos, gap)
	table.insert(used, {
		pos = pos,
		gap = gap,
	})
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

local function queueCleanup(entry, delaySec)
	if entry.cleanupQueued then
		return
	end
	entry.cleanupQueued = true
	task.delay(delaySec or 0, function()
		if entry.model and entry.model.Parent then
			entry.model:Destroy()
		end
	end)
end

local function updateMonumentPromptStates()
	for _, monument in ipairs(monuments) do
		if monument.prompt then
			local blockedByChallenge = activeChallenge ~= nil and activeChallenge.monument ~= monument
			monument.prompt.Enabled = (not monument.activated) and (not monument.resolved) and (not blockedByChallenge)
		end
	end
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
	runSeconds = RunProgressApi.GetRunSeconds()

	spawnEnemyBurst(EXTRA_SPAWN_COUNT, anchorPos, runSeconds, "HeroMonument")
end

local function finishChallenge(monument, success)
	if monument.resolved then
		return
	end

	monument.resolved = true
	activeChallenge = nil
	updateMonumentPromptStates()

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
	updateMonumentPromptStates()

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
		rewardPos = core.Position + (baseCf.LookVector * REWARD_OFFSET),
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

local function completeBattleStatue(statue)
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
	runSeconds = RunProgressApi.GetRunSeconds()

	local spawned = spawnEnemyBurst(BATTLE_SPAWN_COUNT, statue.core.Position, runSeconds, "BattleStatue")
	statue.remaining = #spawned
	if statue.remaining <= 0 then
		completeBattleStatue(statue)
		return
	end

	fireRewardReveal(plr, buildStatueRevealPayload("battle"))

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
	fireRewardReveal(plr, buildStatueRevealPayload("magnet"))

	broadcast({
		type = "statueActivated",
		statueType = "magnet",
		playerName = getDisplayName(plr),
		duration = MAGNET_DURATION,
	})

	queueCleanup(statue, 1)
end

local function buildStatue(pos: Vector3, idx: number, statueType: string)
	local yaw = math.rad(math.random(0, 359))
	local baseCf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)

	local model = Instance.new("Model")
	model.Name = ("%sStatue_%d"):format(statueType == "battle" and "Battle" or "Magnet", idx)

	local pedestalColor = statueType == "battle" and Color3.fromRGB(88, 76, 72) or Color3.fromRGB(62, 86, 92)
	local coreColor = statueType == "battle" and Color3.fromRGB(255, 178, 82) or Color3.fromRGB(114, 241, 220)
	local lightColor = statueType == "battle" and Color3.fromRGB(255, 161, 70) or Color3.fromRGB(99, 255, 228)

	local pedestal = newPart(model, "Pedestal", Vector3.new(8, 1.3, 8), pedestalColor, Enum.Material.Slate)
	pedestal.CFrame = baseCf * CFrame.new(0, -1.6, 0)
	pedestal.CanCollide = true

	local body = newPart(model, "Body", Vector3.new(2.8, 4.8, 2.8), Color3.fromRGB(116, 122, 138), Enum.Material.Rock)
	body.CFrame = baseCf * CFrame.new(0, 0.7, 0)
	body.CanCollide = true

	local crown = newPart(model, "Crown", Vector3.new(3.2, 1.4, 3.2), Color3.fromRGB(136, 143, 160), Enum.Material.Rock)
	crown.CFrame = baseCf * CFrame.new(0, 3.5, 0)
	crown.CanCollide = true

	local core = newPart(model, "Core", Vector3.new(1.8, 1.8, 1.8), coreColor, Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CFrame = baseCf * CFrame.new(0, 2.1, 0)
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
		if not isAlive(plr) then
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

local function spawnStructuresForRun()
	if spawnedForRun then
		return
	end
	spawnedForRun = true

	clearStructures()

	local usedPositions = {}

	for i = 1, MONUMENT_COUNT do
		local pos = randomGroundPoint(usedPositions, MIN_MONUMENT_GAP, MONUMENT_HEIGHT)
		if pos then
			rememberPosition(usedPositions, pos, MIN_MONUMENT_GAP)
			table.insert(monuments, buildMonument(pos, i))
		end
	end

	for i, statueType in ipairs(STATUE_SPAWN_ORDER) do
		local pos = randomGroundPoint(usedPositions, MIN_STATUE_GAP, STATUE_HEIGHT)
		if pos then
			rememberPosition(usedPositions, pos, MIN_STATUE_GAP)
			table.insert(statues, buildStatue(pos, i, statueType))
		end
	end

	updateMonumentPromptStates()

end

_G.PrepareRunStructures = function()
	spawnStructuresForRun()
	return {
		monuments = #monuments,
		statues = #statues,
	}
end

RunStarted.Changed:Connect(function(v)
	if v == true then
		spawnStructuresForRun()
	else
		spawnedForRun = false
		clearStructures()
	end
end)

if RunStarted.Value == true then
	spawnStructuresForRun()
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
		updateMonumentPromptStates()
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

print("[StatueService] Ready")
