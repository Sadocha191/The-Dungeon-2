-- ChestService.server.lua (Level1)
-- Spawns random coin chests. Players can open them for coins or for free via Key chance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PlayerData"))
local PickupToastService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("PickupToastService"))
local WorldBounds = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("WorldBounds"))
local ChestItemService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("Items"):WaitForChild("ChestItemService"))
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local CraftingConfig = require(moduleFolder:WaitForChild("CraftingConfig"))

local MIN_CHESTS = 300
local MAX_CHESTS = 500
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
local revealRng = Random.new()

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
	MoveSprintLevel = 0,
	MoveExtraJumpBonus = 0,
	MoveSlideLevel = 0,
	MoveDashLevel = 0,
}

local REWARDS = {
	{ rarity = "Common", id = "damage_10", label = "Gym Sauce (+10% Damage)", value = 0.10 },
	{ rarity = "Common", id = "shield_5", label = "Shield Tome (+5 Shield)", value = 5 },
	{ rarity = "Common", id = "pickup_20", label = "Attraction (+20% Pickup Range)", value = 0.20 },
	{ rarity = "Common", id = "crit_dmg_10", label = "Crit Tonic (+10% Crit Damage)", value = 0.10 },
	{ rarity = "Common", id = "move_15", label = "Turbo Socks (+15% Movement Speed)", value = 0.15 },
	{ rarity = "Common", id = "sprint_1", label = "Runner's Crest (+12% Sprint Speed)", value = 1 },
	{ rarity = "Common", id = "key_1", label = "Key (+1 stack)", value = 1 },
	{ rarity = "Uncommon", id = "projectile_1", label = "Backpack (+1 Projectile)", value = 1 },
	{ rarity = "Uncommon", id = "atkspd_8", label = "Battery (+8% Attack Speed)", value = 0.08 },
	{ rarity = "Uncommon", id = "elite_15", label = "Boss Buster (+15% Elite Damage)", value = 0.15 },
	{ rarity = "Uncommon", id = "airjump_1", label = "Feather Sigil (+1 Extra Jump)", value = 1 },
	{ rarity = "Uncommon", id = "slide_1", label = "Knee Guards (+1 Slide Tier)", value = 1 },
	{ rarity = "Rare", id = "lifesteal_10", label = "Demonic Blade (+10% Lifesteal)", value = 0.10 },
	{ rarity = "Rare", id = "luck_8", label = "Clover (+8% Luck)", value = 0.08 },
	{ rarity = "Rare", id = "powerup_15", label = "Anvil (+15% Powerup Mult)", value = 0.15 },
	{ rarity = "Rare", id = "dash_1", label = "Blink Spurs (+1 Dash Tier)", value = 1 },
	{ rarity = "Legendary", id = "damage_25", label = "Big Bonk (+25% Damage)", value = 0.25 },
}

local REWARD_REVEAL_DESCRIPTIONS = {
	damage_10 = "Your weapons hit harder for the rest of the run.",
	damage_25 = "A massive damage boost is locked in for this expedition.",
	shield_5 = "Gain extra shield immediately.",
	pickup_20 = "Drops snap in from farther away.",
	crit_dmg_10 = "Critical hits now deal more damage.",
	move_15 = "Movement speed increases for the rest of the run.",
	sprint_1 = "Your sprint gets faster for the rest of the run.",
	key_1 = "Future chests are more likely to open for free.",
	projectile_1 = "Projectile spells fire one extra projectile.",
	atkspd_8 = "Attack speed rises and your swings come out faster.",
	elite_15 = "Elites and bosses take extra damage from you.",
	airjump_1 = "Gain one more mid-air jump for the rest of the run.",
	slide_1 = "Your slide becomes faster and recovers quicker.",
	lifesteal_10 = "A slice of your damage now returns as health.",
	luck_8 = "Future reward rolls lean toward better rarities.",
	powerup_15 = "All later shrine and chest bonuses become stronger.",
	dash_1 = "Your dash travels farther and refreshes faster.",
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

local function buildRaycastIgnore()
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

local function farEnoughFromOthers(pos, used)
	for _, other in ipairs(used) do
		if (other - pos).Magnitude < MIN_CHEST_GAP then
			return false
		end
	end
	return true
end

local function randomGroundPoint(existing)
	return WorldBounds.FindRandomTerrainPoint({
		pad = 20,
		tries = CHEST_RAYCAST_TRIES,
		heightOffset = CHEST_HEIGHT,
		raycastIgnoreInstances = buildRaycastIgnore(),
		overlapIgnoreInstances = buildOverlapIgnore(),
		clearanceRadius = 4.5,
		clearanceHeight = 7,
		maxSlopeDeg = 35,
		fallbackMin = Vector2.new(-180, -180),
		fallbackMax = Vector2.new(180, 180),
		isValid = function(pos)
			return farEnoughFromOthers(pos, existing)
		end,
	})
end

local function groundPointFromXZ(pos: Vector3)
	local grounded = WorldBounds.FindNearbyTerrainPoint(pos, {
		heightOffset = CHEST_HEIGHT,
		raycastIgnoreInstances = buildRaycastIgnore(),
		overlapIgnoreInstances = buildOverlapIgnore(),
		clearanceRadius = 4.5,
		clearanceHeight = 7,
		maxSlopeDeg = 35,
		samplesPerRing = 10,
		searchRadii = { 0, 5, 10, 15 },
	})
	if grounded then
		return grounded
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

local function shuffleInPlace(list, rng)
	for index = #list, 2, -1 do
		local swapIndex = rng:NextInteger(1, index)
		list[index], list[swapIndex] = list[swapIndex], list[index]
	end
	return list
end

local function buildRewardRevealCandidates(finalReward)
	local entries = {}
	for _, reward in ipairs(REWARDS) do
		if reward.id ~= finalReward.id then
			table.insert(entries, {
				label = reward.label,
				rarity = reward.rarity,
			})
		end
	end

	shuffleInPlace(entries, revealRng)

	local candidates = {}
	for index = 1, math.min(4, #entries) do
		table.insert(candidates, entries[index])
	end
	table.insert(candidates, {
		label = finalReward.label,
		rarity = finalReward.rarity,
	})
	return candidates
end

local function buildRecipeRevealCandidates(finalRecipeId)
	local entries = {}
	local allRecipes = (typeof(CraftingConfig.GetAllRecipes) == "function" and CraftingConfig.GetAllRecipes()) or CraftingConfig.Recipes or {}
	for _, recipe in ipairs(allRecipes) do
		if recipe.recipeId ~= finalRecipeId then
			table.insert(entries, {
				label = recipe.weaponId or recipe.recipeId,
				rarity = recipe.rarity or "Common",
			})
		end
	end

	shuffleInPlace(entries, revealRng)

	local candidates = {}
	for index = 1, math.min(4, #entries) do
		table.insert(candidates, entries[index])
	end
	return candidates
end

local function getChestSourceName(chest)
	if chest.specialRewardOnly == true then
		return "Hero Reward Chest"
	end
	if chest.forceFree == true then
		return "Reward Chest"
	end
	return "Treasure Chest"
end

local function getRewardDetailText(chest, openedForFree, cost)
	if chest.specialRewardOnly == true then
		return "Hero Reward"
	end
	if openedForFree then
		return "Free Open"
	end
	return string.format("-%d Coins", math.max(0, math.floor(tonumber(cost) or 0)))
end

local function getChestRewardDescription(reward)
	if not reward then
		return "A powerful run bonus has been locked in."
	end
	return REWARD_REVEAL_DESCRIPTIONS[reward.id] or "A powerful run bonus has been locked in."
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
		local baseSpeed = getNumAttr(plr, "BaseWalkSpeed", 21)
		local addSpeed = baseSpeed * scaled
		setNumAttr(plr, "RunBonusSpeed", getNumAttr(plr, "RunBonusSpeed", 0) + addSpeed)
		setNumAttr(plr, "ShrineMoveSpeedAdded", getNumAttr(plr, "ShrineMoveSpeedAdded", 0) + addSpeed)
		applyMovement(plr)

	elseif reward.id == "sprint_1" then
		setNumAttr(plr, "MoveSprintLevel", getNumAttr(plr, "MoveSprintLevel", 0) + 1)

	elseif reward.id == "key_1" then
		setNumAttr(plr, "ChestKeyStacks", getNumAttr(plr, "ChestKeyStacks", 0) + 1)

	elseif reward.id == "projectile_1" then
		setNumAttr(plr, "ShrineProjectileBonus", getNumAttr(plr, "ShrineProjectileBonus", 0) + 1)

	elseif reward.id == "atkspd_8" then
		setNumAttr(plr, "ShrineAttackSpeedBonus", getNumAttr(plr, "ShrineAttackSpeedBonus", 0) + scaled)

	elseif reward.id == "elite_15" then
		setNumAttr(plr, "ShrineEliteDamageBonus", getNumAttr(plr, "ShrineEliteDamageBonus", 0) + scaled)

	elseif reward.id == "airjump_1" then
		setNumAttr(plr, "MoveExtraJumpBonus", getNumAttr(plr, "MoveExtraJumpBonus", 0) + math.max(1, math.floor(scaled + 0.5)))

	elseif reward.id == "slide_1" then
		setNumAttr(plr, "MoveSlideLevel", getNumAttr(plr, "MoveSlideLevel", 0) + 1)

	elseif reward.id == "lifesteal_10" then
		setNumAttr(plr, "ShrineLifestealPct", getNumAttr(plr, "ShrineLifestealPct", 0) + scaled)

	elseif reward.id == "luck_8" then
		setNumAttr(plr, "ShrineLuckBonus", getNumAttr(plr, "ShrineLuckBonus", 0) + scaled)

	elseif reward.id == "powerup_15" then
		setNumAttr(plr, "ShrinePowerupMult", getNumAttr(plr, "ShrinePowerupMult", 1) * (1 + scaled))

	elseif reward.id == "dash_1" then
		setNumAttr(plr, "MoveDashLevel", getNumAttr(plr, "MoveDashLevel", 0) + 1)
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

	print(string.format("[ChestService] Chest open requested by %s", plr.Name))
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
	local reward = nil

	if chest.recipeId then
		foundRecipeId, recipeState = awardRecipeDiscovery(plr, chest.recipeId)
		local recipeDef = foundRecipeId and CraftingConfig.GetRecipe(foundRecipeId) or nil
		rarity = chest.recipeRarity or (recipeDef and recipeDef.rarity) or "Common"
		rewardName = chest.rewardLabel or ((recipeDef and recipeDef.weaponId) or foundRecipeId or "Recipe")
	else
		local rewardDefinition, rewardDetail = ChestItemService.OpenReward(plr, {
			SourceName = getChestSourceName(chest),
		})
		if not rewardDefinition or not rewardDetail then
			chest.opened = false
			if chest.prompt then
				chest.prompt.Enabled = true
			end
			return
		end
		reward = rewardDefinition
		rarity = rewardDetail.Rarity or rewardDefinition.Rarity or "Common"
		rewardName = rewardDefinition.Name or rewardDefinition.label or "Reward"
		print(string.format("[ChestService] Chest paused run for %s", plr.Name))
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
		local tier = recipeState and recipeState.tier or 1
		local recipeCopies = recipeState and recipeState.copies or 1
		PickupToastService.PushRecipe(plr, foundRecipeId, string.format("Weapon Schematic - Tier %d", tier), 1)
		WaveStatusEvent:FireClient(plr, {
			type = "rewardReveal",
			revealKind = "chest",
			headerText = "Chest Draw",
			sourceName = getChestSourceName(chest),
			itemName = rewardName,
			rarity = rarity,
			description = string.format("Weapon schematic secured. Copies: %d. Current tier: %d.", recipeCopies, tier),
			detailText = getRewardDetailText(chest, openedForFree, chest.forceFree == true and 0 or cost),
			rollDuration = 1.05,
			holdDuration = 1.9,
			candidates = buildRecipeRevealCandidates(foundRecipeId),
		})
		WaveStatusEvent:FireClient(plr, {
			type = "recipeFound",
			recipeId = foundRecipeId,
			recipeName = recipeDef and recipeDef.weaponId or foundRecipeId,
			copies = recipeCopies,
			tier = tier,
			rarity = recipeDef and recipeDef.rarity or chest.recipeRarity,
		})
	elseif reward then
		print(string.format("[ChestService] Rolled chest item %s (%s) for %s", rewardName, rarity, plr.Name))
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

