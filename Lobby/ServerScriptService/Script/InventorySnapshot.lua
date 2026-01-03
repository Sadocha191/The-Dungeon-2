-- SCRIPT: InventorySnapshot.server.lua
-- GDZIE: ServerScriptService/InventorySnapshot.server.lua
-- CO: RemoteFunction zwraca snapshot ekwipunku (PlayerData + Currencies + WeaponIds)

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
	local weaponSource = data.Weapons
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if typeof(state.OwnedWeapons) == "table" and #state.OwnedWeapons > 0 then
		weaponSource = state.OwnedWeapons
	elseif typeof(weaponSource) ~= "table" or #weaponSource == 0 then
		weaponSource = {}
	end

	local favoriteSet = {}
	for _, name in ipairs(state.FavoriteWeapons or {}) do
		if typeof(name) == "string" then
			favoriteSet[name] = true
		end
	end

	for _, weaponId in ipairs(weaponSource or {}) do
		if typeof(weaponId) == "string" and weaponId ~= "" then
			table.insert(weapons, {
				WeaponId = weaponId,
				Favorite = favoriteSet[weaponId] == true,
			})
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
		equippedId = state.StarterWeaponName,
		weapons = weapons,
	}
end

print("[InventorySnapshot] Ready")
