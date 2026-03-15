-- ChestService.server.lua (Level1)
-- Spawns random coin chests. Players can open them for coins or for free via Key chance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PlayerData"))
local WorldBounds = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("WorldBounds"))
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local CraftingConfig = require(moduleFolder:WaitForChild("CraftingConfig"))

local MIN_CHESTS = 30
local MAX_CHESTS = 30
local MIN_CHEST_GAP = 24
local CHEST_RAYCAST_TRIES = 45
local CHEST_HEIGHT = 1.8

local BASE_CHEST_COST = 55
local CHEST_COST_STEP = 25
local MIN_CHEST_COST = 25

local KEY_STACK_CHANCE = 0.10 -- each key adds +10% to x before applying x/(1+x)

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

local chestsFolder = workspace:FindFirstChild("Chests")
if not chestsFolder then
	chestsFolder = Instance.new("Folder")
	chestsFolder.Name = "Chests"
	chestsFolder.Parent = workspace
end

local chests = {}
local spawnedForRun = false
local nextChestId = 0
local recipeRng = Random.new()

local RARITY_COLORS = {
	Common = Color3.fromRGB(206, 206, 206),
	Uncommon = Color3.fromRGB(88, 214, 121),
	Rare = Color3.fromRGB(79, 172, 255),
	Epic = Color3.fromRGB(185, 111, 255),
	Legendary = Color3.fromRGB(255, 177, 66),
	Mythical = Color3.fromRGB(255, 84, 129),
}

local NUM_DEFAULTS = {
	ShrineDamageMult = 1,
	ShrineCritDamageBonus = 0,
	ShrineAttackSpeedBonus = 0,
	ShrinePickupRangeBonus = 0,
	ShrineLuckBonus = 0,
	ShrineProjectileBonus = 0,
	ShrineHpRegenFlat = 0,
	ShrineKnockbackMult = 1,
	ShrineDifficultyPct = 0,
	ShrineLifestealPct = 0,
	ShrinePowerupMult = 1,
	ShrineEliteDamageBonus = 0,
	ShrineDurationBonus = 0,
	ShrineJumpHeightBonus = 0,
	ShrineShieldMax = 0,
	ShrineShieldCurrent = 0,
	ShrineMoveSpeedAdded = 0,
	ChestOpenedCount = 0,
	ChestKeyStacks = 0,
	ChestFreeChanceFlat = 0,
	ChestCostMult = 1,
}

local REWARDS = {
	{ rarity = "Common", id = "damage_10", label = "Gym Sauce (+10% Damage)", value = 0.10 },
	{ rarity = "Common", id = "shield_5", label = "Shield Tome (+5 Shield)", value = 5 },
	{ rarity = "Common", id = "pickup_20", label = "Attraction (+20% Pickup Range)", value = 0.20 },
	{ rarity = "Common", id = "crit_dmg_10", label = "Crit Tonic (+10% Crit Damage)", value = 0.10 },
	{ rarity = "Common", id = "move_15", label = "Turbo Socks (+15% Movement Speed)", value = 0.15 },
	{ rarity = "Common", id = "regen_35", label = "Medkit (+35 HP Regen)", value = 35 },
	{ rarity = "Common", id = "key_1", label = "Key (+1 stack)", value = 1 },
	{ rarity = "Uncommon", id = "projectile_1", label = "Backpack (+1 Projectile)", value = 1 },
	{ rarity = "Uncommon", id = "atkspd_8", label = "Battery (+8% Attack Speed)", value = 0.08 },
	{ rarity = "Uncommon", id = "elite_15", label = "Boss Buster (+15% Elite Damage)", value = 0.15 },
	{ rarity = "Rare", id = "lifesteal_10", label = "Demonic Blade (+10% Lifesteal)", value = 0.10 },
	{ rarity = "Rare", id = "luck_8", label = "Clover (+8% Luck)", value = 0.08 },
	{ rarity = "Rare", id = "powerup_15", label = "Anvil (+15% Powerup Mult)", value = 0.15 },
	{ rarity = "Legendary", id = "damage_25", label = "Big Bonk (+25% Damage)", value = 0.25 },
}

local REWARDS_BY_RARITY = {
	Common = {},
	Uncommon = {},
	Rare = {},
	Legendary = {},
}
for _, reward in ipairs(REWARDS) do
	table.insert(REWARDS_BY_RARITY[reward.rarity], reward)
end

local function getNumAttr(plr, name, fallback)
	local v = plr:GetAttribute(name)
	if typeof(v) ~= "number" then
		return fallback
	end
	return v
end

local function setNumAttr(plr, name, value)
	plr:SetAttribute(name, tonumber(value) or 0)
end

local function ensureDefaults(plr)
	for attr, defaultValue in pairs(NUM_DEFAULTS) do
		if typeof(plr:GetAttribute(attr)) ~= "number" then
			setNumAttr(plr, attr, defaultValue)
		end
	end
end

local function applyMovement(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local baseSpeed = getNumAttr(plr, "BaseWalkSpeed", 18)
	local runBonusSpeed = getNumAttr(plr, "RunBonusSpeed", 0)
	hum.WalkSpeed = baseSpeed + runBonusSpeed
end

local function broadcast(payload)
	for _, plr in ipairs(Players:GetPlayers()) do
		WaveStatusEvent:FireClient(plr, payload)
	end
end

local function clearChests()
	for _, chest in ipairs(chests) do
		if chest.model and chest.model.Parent then
			chest.model:Destroy()
		end
	end
	table.clear(chests)
end

local function getWorldBoundsXZ()
	return WorldBounds.GetXZ(20, Vector2.new(-180, -180), Vector2.new(180, 180))
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.IgnoreWater = false

local function buildRaycastBlacklist()
	local list = {
		chestsFolder,
		workspace:FindFirstChild("Enemies"),
		workspace:FindFirstChild("Drops"),
		workspace:FindFirstChild("Shrines"),
		workspace:FindFirstChild("Statues"),
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
		if (other - pos).Magnitude < MIN_CHEST_GAP then
			return false
		end
	end
	return true
end

local function randomGroundPoint(existing)
	local pMin, pMax = getWorldBoundsXZ()
	rayParams.FilterDescendantsInstances = buildRaycastBlacklist()

	for _ = 1, CHEST_RAYCAST_TRIES do
		local x = pMin.X + math.random() * (pMax.X - pMin.X)
		local z = pMin.Y + math.random() * (pMax.Y - pMin.Y)
		local origin = Vector3.new(x, 420, z)
		local result = workspace:Raycast(origin, Vector3.new(0, -900, 0), rayParams)
		if result then
			local pos = result.Position + Vector3.new(0, CHEST_HEIGHT, 0)
			if farEnoughFromOthers(pos, existing) then
				return pos
			end
		end
	end
	return nil
end

local function groundPointFromXZ(pos: Vector3)
	rayParams.FilterDescendantsInstances = buildRaycastBlacklist()

	local originY = math.max(420, pos.Y + 80)
	local origin = Vector3.new(pos.X, originY, pos.Z)
	local result = workspace:Raycast(origin, Vector3.new(0, -1000, 0), rayParams)
	if result then
		return result.Position + Vector3.new(0, CHEST_HEIGHT, 0)
	end
	return pos
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

local function computeFreeChance(plr)
	local keyStacks = math.max(0, getNumAttr(plr, "ChestKeyStacks", 0))
	local flat = math.max(0, getNumAttr(plr, "ChestFreeChanceFlat", 0))
	local x = keyStacks * KEY_STACK_CHANCE + flat
	if x <= 0 then
		return 0
	end
	return math.clamp(x / (1 + x), 0, 0.95)
end

local function getChestCost(plr)
	local opened = math.max(0, math.floor(getNumAttr(plr, "ChestOpenedCount", 0)))
	local mult = math.max(0.2, getNumAttr(plr, "ChestCostMult", 1))
	local raw = (BASE_CHEST_COST + opened * CHEST_COST_STEP) * mult
	return math.max(MIN_CHEST_COST, math.floor(raw + 0.5))
end

local function getRarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "")] or Color3.fromRGB(255, 209, 83)
end

local function pickRewardRarity(plr)
	local luck = math.max(0, getNumAttr(plr, "ShrineLuckBonus", 0))
	local commonW = math.max(8, 75 * (1 - luck * 0.8))
	local uncommonW = 20 * (1 + luck * 1.4)
	local rareW = 4 * (1 + luck * 1.8)
	local legendaryW = 1 * (1 + luck * 2.0)

	local total = commonW + uncommonW + rareW + legendaryW
	local roll = math.random() * total
	if roll <= commonW then
		return "Common"
	end
	if roll <= commonW + uncommonW then
		return "Uncommon"
	end
	if roll <= commonW + uncommonW + rareW then
		return "Rare"
	end
	return "Legendary"
end

local function pickReward(plr)
	local rarity = pickRewardRarity(plr)
	local bucket = REWARDS_BY_RARITY[rarity]
	if not bucket or #bucket == 0 then
		bucket = REWARDS_BY_RARITY.Common
		rarity = "Common"
	end
	return bucket[math.random(1, #bucket)], rarity
end

local function applyReward(plr, reward)
	ensureDefaults(plr)

	local powerMult = math.max(1, getNumAttr(plr, "ShrinePowerupMult", 1))
	local scaled = reward.value
	if reward.id ~= "powerup_15" and reward.id ~= "key_1" then
		scaled = scaled * powerMult
	end

	if reward.id == "damage_10" or reward.id == "damage_25" then
		setNumAttr(plr, "ShrineDamageMult", getNumAttr(plr, "ShrineDamageMult", 1) * (1 + scaled))

	elseif reward.id == "shield_5" then
		local addShield = math.max(1, math.floor(scaled + 0.5))
		setNumAttr(plr, "ShrineShieldMax", getNumAttr(plr, "ShrineShieldMax", 0) + addShield)
		setNumAttr(plr, "ShrineShieldCurrent", getNumAttr(plr, "ShrineShieldCurrent", 0) + addShield)

	elseif reward.id == "pickup_20" then
		setNumAttr(plr, "ShrinePickupRangeBonus", getNumAttr(plr, "ShrinePickupRangeBonus", 0) + scaled)

	elseif reward.id == "crit_dmg_10" then
		setNumAttr(plr, "ShrineCritDamageBonus", getNumAttr(plr, "ShrineCritDamageBonus", 0) + scaled)

	elseif reward.id == "move_15" then
		local baseSpeed = getNumAttr(plr, "BaseWalkSpeed", 18)
		local addSpeed = baseSpeed * scaled
		setNumAttr(plr, "RunBonusSpeed", getNumAttr(plr, "RunBonusSpeed", 0) + addSpeed)
		setNumAttr(plr, "ShrineMoveSpeedAdded", getNumAttr(plr, "ShrineMoveSpeedAdded", 0) + addSpeed)
		applyMovement(plr)

	elseif reward.id == "regen_35" then
		setNumAttr(plr, "ShrineHpRegenFlat", getNumAttr(plr, "ShrineHpRegenFlat", 0) + scaled)

	elseif reward.id == "key_1" then
		setNumAttr(plr, "ChestKeyStacks", getNumAttr(plr, "ChestKeyStacks", 0) + 1)

	elseif reward.id == "projectile_1" then
		setNumAttr(plr, "ShrineProjectileBonus", getNumAttr(plr, "ShrineProjectileBonus", 0) + 1)

	elseif reward.id == "atkspd_8" then
		setNumAttr(plr, "ShrineAttackSpeedBonus", getNumAttr(plr, "ShrineAttackSpeedBonus", 0) + scaled)

	elseif reward.id == "elite_15" then
		setNumAttr(plr, "ShrineEliteDamageBonus", getNumAttr(plr, "ShrineEliteDamageBonus", 0) + scaled)

	elseif reward.id == "lifesteal_10" then
		setNumAttr(plr, "ShrineLifestealPct", getNumAttr(plr, "ShrineLifestealPct", 0) + scaled)

	elseif reward.id == "luck_8" then
		setNumAttr(plr, "ShrineLuckBonus", getNumAttr(plr, "ShrineLuckBonus", 0) + scaled)

	elseif reward.id == "powerup_15" then
		setNumAttr(plr, "ShrinePowerupMult", getNumAttr(plr, "ShrinePowerupMult", 1) * (1 + scaled))
	end
end

local function awardRecipeDiscovery(plr, forcedRecipeId)
	local recipeId = forcedRecipeId
	if typeof(recipeId) ~= "string" or recipeId == "" then
		if recipeRng:NextNumber() > (tonumber(CraftingConfig.RECIPE_DROP_CHANCE) or 0) then
			return nil
		end
		recipeId = CraftingConfig.RollRecipeId(recipeRng)
	end
	if typeof(recipeId) ~= "string" or recipeId == "" then
		return nil
	end

	local data = PlayerData.Get(plr)
	data.crafting = data.crafting or {}
	data.crafting.recipes = data.crafting.recipes or {}

	local state = data.crafting.recipes[recipeId]
	if typeof(state) ~= "table" then
		state = {
			found = true,
			copies = 1,
			tier = 1,
			unlocked = false,
			lastFoundAt = os.time(),
		}
	else
		state.found = true
		state.copies = math.max(1, math.floor(tonumber(state.copies) or 1)) + 1
		state.lastFoundAt = os.time()
	end
	state.tier = CraftingConfig.GetRecipeTierFromCopies(state.copies)
	data.crafting.recipes[recipeId] = state
	if PlayerData.MarkDirty then
		PlayerData.MarkDirty(plr)
	end
	return recipeId, state
end

local function createChestModel(pos, idx, config)
	config = config or {}
	local accentColor = typeof(config.accentColor) == "Color3" and config.accentColor or Color3.fromRGB(213, 168, 69)
	local coreColor = typeof(config.coreColor) == "Color3" and config.coreColor or accentColor
	if config.forceFree == true and not config.recipeId and typeof(config.coreColor) ~= "Color3" then
		coreColor = Color3.fromRGB(109, 255, 157)
	end

	local model = Instance.new("Model")
	model.Name = tostring(config.name or ("Chest_%d"):format(idx))

	local base = newPart(model, "Base", Vector3.new(5.2, 1.2, 4.2), Color3.fromRGB(86, 56, 35), Enum.Material.WoodPlanks)
	base.CFrame = CFrame.new(pos - Vector3.new(0, 1.4, 0))
	base.CanCollide = true

	local body = newPart(model, "Body", Vector3.new(4.4, 2, 3.4), Color3.fromRGB(121, 80, 44), Enum.Material.Wood)
	body.CFrame = CFrame.new(pos)
	body.CanCollide = true

	local band = newPart(model, "Band", Vector3.new(4.5, 0.4, 3.6), accentColor, Enum.Material.Metal)
	band.CFrame = CFrame.new(pos + Vector3.new(0, 0.75, 0))
	band.CanCollide = false

	local lid = newPart(model, "Lid", Vector3.new(4.6, 0.9, 3.6), Color3.fromRGB(103, 67, 38), Enum.Material.Wood)
	lid.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, -0.2))
	lid.CanCollide = true

	local core = newPart(model, "Core", Vector3.new(1.2, 1.2, 1.2), coreColor, Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.CFrame = CFrame.new(pos + Vector3.new(0, 1.3, 0.8))
	core.CanCollide = false
	core.CanTouch = false
	core.CanQuery = false

	local light = Instance.new("PointLight")
	light.Color = coreColor
	light.Brightness = 1.8
	light.Range = 14
	light.Parent = core

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = tostring(config.actionText or "Open Chest")
	prompt.ObjectText = tostring(config.objectText or "")
	prompt.HoldDuration = 0.45
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	model.PrimaryPart = core
	model.Parent = chestsFolder

	return {
		model = model,
		core = core,
		lid = lid,
		prompt = prompt,
		opened = false,
		forceFree = config.forceFree == true,
		ownerUserId = tonumber(config.ownerUserId),
		countsForScaling = config.countsForScaling ~= false,
		recipeId = typeof(config.recipeId) == "string" and config.recipeId or nil,
		recipeRarity = typeof(config.recipeRarity) == "string" and config.recipeRarity or nil,
		specialRewardOnly = config.specialRewardOnly == true,
		rewardLabel = typeof(config.rewardLabel) == "string" and config.rewardLabel or nil,
	}
end

local handleOpen

local function spawnChestInstance(pos: Vector3, config)
	nextChestId += 1

	local groundedPos = groundPointFromXZ(pos)
	local chest = createChestModel(groundedPos, nextChestId, config)
	chest.prompt.Triggered:Connect(function(plr)
		handleOpen(chest, plr)
	end)
	table.insert(chests, chest)
	return chest
end

local function isAlive(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0 and plr:GetAttribute("RunEnded") ~= true
end

handleOpen = function(chest, plr)
	if not chest or chest.opened then
		return
	end
	if not RunStarted.Value or PauseState.Value then
		return
	end
	if not plr or not plr.Parent or not isAlive(plr) then
		return
	end
	if chest.ownerUserId and chest.ownerUserId ~= plr.UserId then
		return
	end

	ensureDefaults(plr)

	local cost = getChestCost(plr)
	local freeChance = computeFreeChance(plr)
	local openedForFree = chest.forceFree == true or (math.random() < freeChance)

	if not openedForFree then
		local canSpend = false
		if type(_G.TrySpendRunCoins) == "function" then
			local ok = _G.TrySpendRunCoins(plr, cost)
			canSpend = (ok == true)
		end
		if not canSpend then
			WaveStatusEvent:FireClient(plr, {
				type = "chestFail",
				cost = cost,
				required = cost,
				freeChancePct = math.floor(freeChance * 100 + 0.5),
			})
			return
		end
	end

	chest.opened = true
	if chest.prompt then
		chest.prompt.Enabled = false
	end

	if chest.lid and chest.lid:IsA("BasePart") then
		chest.lid.CFrame = chest.lid.CFrame * CFrame.new(0, 0.5, -0.8) * CFrame.Angles(math.rad(-28), 0, 0)
	end
	if chest.core and chest.core:IsA("BasePart") then
		chest.core.Color = Color3.fromRGB(93, 255, 137)
	end

	local rewardName = nil
	local rarity = "Common"
	local foundRecipeId, recipeState = nil, nil

	if chest.recipeId then
		foundRecipeId, recipeState = awardRecipeDiscovery(plr, chest.recipeId)
		local recipeDef = foundRecipeId and CraftingConfig.GetRecipe(foundRecipeId) or nil
		rarity = chest.recipeRarity or (recipeDef and recipeDef.rarity) or "Common"
		rewardName = chest.rewardLabel or ((recipeDef and recipeDef.weaponId) or foundRecipeId or "Recipe")
	else
		local reward
		reward, rarity = pickReward(plr)
		applyReward(plr, reward)
		rewardName = reward.label
	end

	if chest.countsForScaling ~= false then
		setNumAttr(plr, "ChestOpenedCount", getNumAttr(plr, "ChestOpenedCount", 0) + 1)
	end

	broadcast({
		type = "chestOpened",
		playerName = plr.DisplayName ~= "" and plr.DisplayName or plr.Name,
		rewardName = rewardName or "Reward",
		rarity = rarity,
		free = openedForFree,
		cost = chest.forceFree == true and 0 or cost,
	})

	if foundRecipeId then
		local recipeDef = CraftingConfig.GetRecipe(foundRecipeId)
		WaveStatusEvent:FireClient(plr, {
			type = "recipeFound",
			recipeId = foundRecipeId,
			recipeName = recipeDef and recipeDef.weaponId or foundRecipeId,
			copies = recipeState and recipeState.copies or 1,
			tier = recipeState and recipeState.tier or 1,
			rarity = recipeDef and recipeDef.rarity or chest.recipeRarity,
		})
	end

	task.delay(1.8, function()
		if chest.model and chest.model.Parent then
			chest.model:Destroy()
		end
	end)
end

local function spawnChestsForRun()
	if spawnedForRun then
		return
	end
	spawnedForRun = true

	clearChests()
	for _, plr in ipairs(Players:GetPlayers()) do
		ensureDefaults(plr)
		setNumAttr(plr, "ChestOpenedCount", 0)
		setNumAttr(plr, "ChestKeyStacks", 0)
	end

	local used = {}
	local count = math.random(MIN_CHESTS, MAX_CHESTS)
	for i = 1, count do
		local pos = randomGroundPoint(used)
		if pos then
			table.insert(used, pos)
			spawnChestInstance(pos, {
				name = ("Chest_%d"):format(i),
			})
		end
	end

	broadcast({
		type = "chestsSpawned",
		count = #chests,
		baseCost = BASE_CHEST_COST,
	})
end

_G.PrepareRunChests = function()
	spawnChestsForRun()
	return #chests
end

function _G.SpawnRewardChestForPlayer(plr: Player, pos: Vector3, config)
	if not plr or not plr.Parent then
		return nil
	end

	local chestConfig = typeof(config) == "table" and table.clone(config) or {}
	chestConfig.name = chestConfig.name or ("RewardChest_%d"):format(nextChestId + 1)
	chestConfig.forceFree = true
	chestConfig.ownerUserId = plr.UserId
	chestConfig.countsForScaling = false

	if chestConfig.recipeId then
		local recipeDef = CraftingConfig.GetRecipe(chestConfig.recipeId)
		chestConfig.recipeRarity = chestConfig.recipeRarity or (recipeDef and recipeDef.rarity) or "Common"
		chestConfig.rewardLabel = chestConfig.rewardLabel or ((recipeDef and recipeDef.weaponId) or chestConfig.recipeId)
		chestConfig.actionText = chestConfig.actionText or "Claim Recipe"
		chestConfig.objectText = chestConfig.objectText or "Hero Reward"
		chestConfig.specialRewardOnly = chestConfig.specialRewardOnly ~= false
		chestConfig.accentColor = chestConfig.accentColor or getRarityColor(chestConfig.recipeRarity)
		chestConfig.coreColor = chestConfig.coreColor or chestConfig.accentColor
	else
		chestConfig.actionText = chestConfig.actionText or "Claim Chest"
	end

	return spawnChestInstance(pos, chestConfig)
end

Players.PlayerAdded:Connect(function(plr)
	ensureDefaults(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.1)
		ensureDefaults(plr)
	end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
	ensureDefaults(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.1)
		ensureDefaults(plr)
	end)
end

RunStarted.Changed:Connect(function(v)
	if v == true then
		spawnChestsForRun()
	else
		spawnedForRun = false
		clearChests()
		for _, plr in ipairs(Players:GetPlayers()) do
			setNumAttr(plr, "ChestOpenedCount", 0)
			setNumAttr(plr, "ChestKeyStacks", 0)
		end
	end
end)

if RunStarted.Value == true then
	spawnChestsForRun()
end

print("[ChestService] Ready")
