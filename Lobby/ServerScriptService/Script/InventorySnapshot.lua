-- SCRIPT: InventorySnapshot.server.lua
-- GDZIE: ServerScriptService/InventorySnapshot.server.lua
-- CO: RemoteFunction zwraca snapshot ekwipunku (PlayerData + Currencies + WeaponIds)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local moduleFolder = ServerScriptService:FindFirstChild("ModuleScript")
	or ServerScriptService:FindFirstChild("ModuleScripts")
if not moduleFolder then
	warn("[InventorySnapshot] Missing ModuleScript folder; inventory snapshot disabled.")
	return
end

local CurrencyService = require(moduleFolder:WaitForChild("CurrencyService"))
local PlayerStateStore = require(moduleFolder:WaitForChild("PlayerStateStore"))

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
	local data = PlayerData.Get(player)
	local currencies = CurrencyService.GetBalances(player)

	local weapons = {}
	local weaponSource = data.Weapons
	if typeof(weaponSource) ~= "table" or #weaponSource == 0 then
		local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
		weaponSource = state.OwnedWeapons
	end

	for _, weaponId in ipairs(weaponSource or {}) do
		if typeof(weaponId) == "string" and weaponId ~= "" then
			table.insert(weapons, { WeaponId = weaponId })
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
		weapons = weapons,
	}
end

print("[InventorySnapshot] Ready")
