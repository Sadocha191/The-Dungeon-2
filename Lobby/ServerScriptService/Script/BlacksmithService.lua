-- BlacksmithService.server.lua
-- Forge: losuje broń (max Epic), losuje prefix jakości (modyfikuje WSZYSTKIE staty), tworzy instancję.
-- Upgrade: x1 lub +10 (zatrzymuje się na maxLevel albo gdy brakuje Coins).
-- UI: Sync wysyła listę instancji + computed stats + dane do forge panelu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local CurrencyService = require(serverModules:WaitForChild("CurrencyService"))

local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))

local CRAFT_COST = 500

local RARITY_BASE_UPGRADE = {
	Common = 40,
	Rare = 80,
	Epic = 140,
	Legendary = 220,
	Mythical = 320,
}

local function computeUpgradeCost(rarity: string, level: number): number
	local base = RARITY_BASE_UPGRADE[rarity] or 60
	level = math.max(1, math.floor(tonumber(level) or 1))
	-- zależne od rarity + rośnie z levelem
	local factor = 1 + (level - 1) * 0.08
	return math.max(1, math.floor(base * factor))
end

-- Prefixy jakości (globalny roll)
local PREFIX_POOL = {
	{ name = "Flawed",        weight = 15, min = 0.85, max = 0.95 },
	{ name = "Worn",          weight = 20, min = 0.95, max = 1.00 },
	{ name = "Balanced",      weight = 30, min = 1.00, max = 1.05 },
	{ name = "Fine",          weight = 20, min = 1.05, max = 1.12 },
	{ name = "Masterwork",    weight = 12, min = 1.12, max = 1.20 },
	{ name = "Mythic-Forged", weight = 3,  min = 1.20, max = 1.35 },
}

local rng = Random.new()

local function rollPrefix()
	local total = 0
	for _, p in ipairs(PREFIX_POOL) do total += p.weight end
	local pick = rng:NextNumber(0, total)
	local acc = 0
	for _, p in ipairs(PREFIX_POOL) do
		acc += p.weight
		if pick <= acc then
			local mult = rng:NextNumber(p.min, p.max)
			return p.name, mult
		end
	end
	return "Balanced", 1.0
end

-- RollStats jest ADDITIVE (różnica od bazowych), żeby łatwo to sumować
local function buildRollStats(def: any, mult: number): any
	local combat = def.combat or {}
	local baseAtk = combat.baseAtk or def.baseDamage or 0
	local atkPerLevel = combat.atkPerLevel or 0

	local function diff(x: number): number
		return (x * mult) - x
	end

	return {
		BaseATK = diff(baseAtk),
		ATKPerLevel = diff(atkPerLevel),

		BonusHP = diff(combat.bonusHP or 0),
		BonusSpeed = diff(combat.bonusSpeed or 0),
		BonusCritRate = diff(combat.bonusCritRate or 0),
		BonusCritDmg = diff(combat.bonusCritDmg or 0),
		BonusLifesteal = diff(combat.bonusLifesteal or 0),
		BonusDefense = diff(combat.bonusDefense or 0),
	}
end

local function listForgeableWeapons()
	local out = {}
	for _, def in ipairs(WeaponConfigs.GetAll()) do
		local r = def.rarity
		if r == "Common" or r == "Rare" or r == "Epic" then
			table.insert(out, def)
		end
	end
	return out
end

local FORGE_POOL = listForgeableWeapons()

local function pickRandomForgeWeapon(): any?
	if #FORGE_POOL == 0 then return nil end
	return FORGE_POOL[rng:NextInteger(1, #FORGE_POOL)]
end

-- ===== Remotes =====
local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemote(name: string): RemoteEvent
	local ev = remoteEvents:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remoteEvents
	return ev
end

local OpenBlacksmithUI = ensureRemote("OpenBlacksmithUI")
local BlacksmithSync = ensureRemote("BlacksmithSync")
local BlacksmithAction = ensureRemote("BlacksmithAction")

-- ===== NPC Prompt =====
local function findAnyBasePart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function setupBlacksmithPrompt()
	local npcs = workspace:FindFirstChild("NPCs")
	local blacksmith = npcs and npcs:FindFirstChild("Blacksmith")
	if not (blacksmith and blacksmith:IsA("Model")) then
		warn("[BlacksmithService] Missing workspace.NPCs.Blacksmith")
		return
	end

	local part = findAnyBasePart(blacksmith)
	if not part then
		warn("[BlacksmithService] Blacksmith has no BasePart")
		return
	end

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	end

	prompt.ObjectText = "Blacksmith"
	prompt.ActionText = "Forge / Upgrade"

	prompt.Triggered:Connect(function(player: Player)
		OpenBlacksmithUI:FireClient(player)
	end)
end

setupBlacksmithPrompt()

-- ===== Stat compute dla UI =====
local function toPct(x: number): number
	return math.floor((x or 0) * 100 + 0.5)
end

local function computeInstanceStats(def: any, inst: any)
	local combat = def.combat or {}
	local roll = (typeof(inst.rollStats) == "table") and inst.rollStats or {}

	local lvl = math.max(1, math.floor(tonumber(inst.level) or 1))

	local baseAtk = (combat.baseAtk or def.baseDamage or 0) + (roll.BaseATK or 0)
	local atkPerLevel = (combat.atkPerLevel or 0) + (roll.ATKPerLevel or 0)
	local atk = baseAtk + (lvl - 1) * atkPerLevel

	local hp = (combat.bonusHP or 0) + (roll.BonusHP or 0)
	local defv = (combat.bonusDefense or 0) + (roll.BonusDefense or 0)
	local spd = (combat.bonusSpeed or 0) + (roll.BonusSpeed or 0)
	local critRate = (combat.bonusCritRate or 0) + (roll.BonusCritRate or 0)
	local critDmg = (combat.bonusCritDmg or 0) + (roll.BonusCritDmg or 0)
	local lifesteal = (combat.bonusLifesteal or 0) + (roll.BonusLifesteal or 0)

	return {
		ATK = math.floor(atk + 0.5),
		HP = math.floor(hp + 0.5),
		DEF = math.floor(defv + 0.5),
		SPD = toPct(spd),
		CRIT_RATE = toPct(critRate),
		CRIT_DMG = toPct(critDmg),
		LIFESTEAL = toPct(lifesteal),
	}
end

-- ===== Snapshot =====
local lastForgedByUser: {[number]: string} = {} -- instanceId

local function buildSnapshot(player: Player)
	local balances = CurrencyService.GetBalances(player)
	local coins = balances.Coins or 0

	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	local equippedInst = PlayerStateStore.GetEquippedWeaponInstance(player)
	local equippedId = equippedInst and equippedInst.instanceId or nil

	local instancesOut = {}
	for _, inst in ipairs(state.WeaponInstances or {}) do
		local def = WeaponConfigs.Get(inst.weaponId)
		if def then
			local rarity = (inst.rarity ~= "" and inst.rarity) or def.rarity or "Common"
			local maxLevel = def.maxLevel or 1
			local lvl = math.max(1, math.floor(tonumber(inst.level) or 1))
			local canUpgrade = lvl < maxLevel
			local stats = computeInstanceStats(def, inst)

			table.insert(instancesOut, {
				instanceId = inst.instanceId,
				weaponId = inst.weaponId,
				weaponType = def.weaponType or "",
				rarity = rarity,
				rarityColor = def.rarityColor or (WeaponConfigs.RarityColors and WeaponConfigs.RarityColors[rarity]) or "#B0B0B0",
				level = lvl,
				maxLevel = maxLevel,
				prefix = inst.prefix or "Standard",
				stats = stats,
				passiveName = def.passiveName or "",
				abilityName = def.abilityName or "",
				upgradeCost = canUpgrade and computeUpgradeCost(rarity, lvl) or 0,
				canUpgrade = canUpgrade,
			})
		end
	end

	-- sort: equipped first, potem rarity, potem level
	local rarityRank = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }
	table.sort(instancesOut, function(a, b)
		if a.instanceId == equippedId then return true end
		if b.instanceId == equippedId then return false end
		local ra = rarityRank[a.rarity] or 0
		local rb = rarityRank[b.rarity] or 0
		if ra ~= rb then return ra > rb end
		if a.level ~= b.level then return a.level > b.level end
		return tostring(a.weaponId) < tostring(b.weaponId)
	end)

	-- last forged details (pełne info do prawego panelu Forge)
	local lastId = lastForgedByUser[player.UserId]
	local lastDetails = nil
	if typeof(lastId) == "string" and lastId ~= "" then
		for _, row in ipairs(instancesOut) do
			if row.instanceId == lastId then
				lastDetails = row
				break
			end
		end
	end

	return {
		coins = coins,
		craftCost = CRAFT_COST,
		equippedInstanceId = equippedId,
		instances = instancesOut,
		lastForged = lastDetails,
	}
end

local function sync(player: Player)
	BlacksmithSync:FireClient(player, buildSnapshot(player))
end

-- ===== Actions =====
local function tryUpgradeSteps(player: Player, instanceId: string, steps: number)
	local inst = PlayerStateStore.GetWeaponInstance(player, instanceId)
	if not inst then return end

	local def = WeaponConfigs.Get(inst.weaponId)
	if not def then return end

	local rarity = (inst.rarity ~= "" and inst.rarity) or def.rarity or "Common"
	local maxLevel = def.maxLevel or 1

	steps = math.clamp(math.floor(tonumber(steps) or 1), 1, 10)

	for _ = 1, steps do
		local lvl = math.max(1, math.floor(tonumber(inst.level) or 1))
		if lvl >= maxLevel then break end

		local cost = computeUpgradeCost(rarity, lvl)
		if not CurrencyService.RemoveCurrency(player, "Coins", cost) then
			break
		end

		inst.level = lvl + 1
	end

	PlayerStateStore.Save(player)
end

BlacksmithAction.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then return end
	local t = payload.type

	if t == "request" then
		sync(player)
		return
	end

	if t == "forge" then
		if not CurrencyService.RemoveCurrency(player, "Coins", CRAFT_COST) then
			sync(player)
			return
		end

		local def = pickRandomForgeWeapon()
		if not def then
			CurrencyService.AddCoins(player, CRAFT_COST)
			sync(player)
			return
		end

		local prefix, mult = rollPrefix()
		local rollStats = buildRollStats(def, mult)

		local created = PlayerStateStore.AddWeaponInstance(player, def.id, def.rarity, 1, prefix, rollStats)
		PlayerStateStore.EnsureOwnedWeapon(player, def.id)

		if created then
			lastForgedByUser[player.UserId] = created.instanceId
		end

		sync(player)
		return
	end

	if t == "upgrade" then
		local instanceId = tostring(payload.instanceId or "")
		local steps = tonumber(payload.steps) or 1 -- 1 albo 10
		tryUpgradeSteps(player, instanceId, steps)
		sync(player)
		return
	end

	if t == "equip" then
		local instanceId = tostring(payload.instanceId or "")
		PlayerStateStore.SetEquippedWeaponInstance(player, instanceId)
		sync(player)
		return
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	PlayerStateStore.Load(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	PlayerStateStore.Save(player, true)
end)

print("[BlacksmithService] Ready")
