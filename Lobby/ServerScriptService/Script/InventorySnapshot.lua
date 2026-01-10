-- SCRIPT: InventorySnapshot.server.lua
-- GDZIE: ServerScriptService/InventorySnapshot.server.lua
-- CO: RemoteFunction zwraca snapshot ekwipunku (PlayerData + Currencies + WeaponInstances)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript")
	or ServerScriptService:FindFirstChild("ModuleScripts")

local function requireModule(name: string)
	local mod = ServerScriptService:FindFirstChild(name)
	if not mod and moduleFolder then
		mod = moduleFolder:FindFirstChild(name)
	end
	if not mod or not mod:IsA("ModuleScript") then
		warn(("[InventorySnapshot] Missing module: %s"):format(name))
		return nil
	end
	return require(mod)
end

local PlayerData = requireModule("PlayerData")
local CurrencyService = requireModule("CurrencyService")
local PlayerStateStore = requireModule("PlayerStateStore")

local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))

local function toPct(x: number): number
	return math.floor((tonumber(x) or 0) * 100 + 0.5)
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

local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctions then
	remoteFunctions = Instance.new("Folder")
	remoteFunctions.Name = "RemoteFunctions"
	remoteFunctions.Parent = ReplicatedStorage
end

local function ensureRemoteFunction(name)
	local fn = remoteFunctions:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then
		return fn
	end
	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remoteFunctions
	return fn
end

local GetInventorySnapshot = ensureRemoteFunction("RF_GetInventorySnapshot")

GetInventorySnapshot.OnServerInvoke = function(player)
	if not PlayerData or not CurrencyService or not PlayerStateStore then
		return {
			playerInfo = {},
			currencies = {},
			weapons = {},
		}
	end
	local data = PlayerData.Get(player)
	local currencies = CurrencyService.GetBalances(player)

	local weapons = {}
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)

	local favoriteSet = {}
	for _, name in ipairs(state.FavoriteWeapons or {}) do
		if typeof(name) == "string" then
			favoriteSet[name] = true
		end
	end

	for _, inst in ipairs(state.WeaponInstances or {}) do
		if typeof(inst) == "table" then
			local weaponId = inst.weaponId
			if typeof(weaponId) == "string" and weaponId ~= "" then
				local def = WeaponConfigs.Get(weaponId)
				if def then
					table.insert(weapons, {
						InstanceId = inst.instanceId,
						WeaponId = weaponId,
						Prefix = inst.prefix or "Standard",
						Level = tonumber(inst.level) or 1,
						MaxLevel = def.maxLevel or 1,
						Rarity = (inst.rarity ~= "" and inst.rarity) or def.rarity or "Common",
						Stats = computeInstanceStats(def, inst),
						Favorite = favoriteSet[weaponId] == true,
					})
				end
			end
		end
	end

	return {
		playerInfo = {
			level = data.level,
			xp = data.xp,
			nextXp = data.nextXp,
			race = player:GetAttribute("Race"),
		},
		currencies = {
			Coins = currencies.Coins,
			WeaponPoints = currencies.WeaponPoints,
		},
		equippedId = state.EquippedWeaponInstanceId,
		weapons = weapons,
	}
end

print("[InventorySnapshot] Ready")
