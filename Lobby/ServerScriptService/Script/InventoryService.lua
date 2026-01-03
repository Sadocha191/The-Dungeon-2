-- SCRIPT: InventoryService.server.lua
-- GDZIE: ServerScriptService/InventoryService.server.lua
-- CO: synchronizacja ekwipunku lobby z Robloxowym ekwipunkiem (1 broń na pasku)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local CurrencyService = require(serverModules:WaitForChild("CurrencyService"))
local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))

local function findWeaponCatalog(): ModuleScript?
	local direct = ServerScriptService:FindFirstChild("WeaponCatalog", true)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	local folder = ServerScriptService:FindFirstChild("ModuleScript")
		or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild("WeaponCatalog")
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end
	return nil
end

local weaponCatalogModule = findWeaponCatalog()
if not weaponCatalogModule then
	warn("[InventoryService] Missing WeaponCatalog module; inventory disabled.")
	return
end

local WeaponCatalog = require(weaponCatalogModule)

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

local InventoryAction = ensureRemote("InventoryAction")
local InventorySync = ensureRemote("InventorySync")

local WeaponTemplates = ServerStorage:WaitForChild("WeaponTemplates", 10)
if not WeaponTemplates then
	warn("[InventoryService] Missing ServerStorage.WeaponTemplates; fallback to WeaponType attributes only.")
end

local function isWeaponTool(inst: Instance): boolean
	if not inst:IsA("Tool") then
		return false
	end
	if typeof(inst:GetAttribute("WeaponType")) == "string" then
		return true
	end
	return WeaponTemplates and WeaponTemplates:FindFirstChild(inst.Name, true) ~= nil
end

local function clearWeaponTools(container: Instance?)
	if not container then return end
	for _, inst in ipairs(container:GetChildren()) do
		if isWeaponTool(inst) then
			inst:Destroy()
		end
	end
end

local function findWeaponName(player: Player): string?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, inst in ipairs(backpack:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	local char = player.Character
	if char then
		for _, inst in ipairs(char:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, inst in ipairs(starterGear:GetChildren()) do
			if isWeaponTool(inst) then return inst.Name end
		end
	end
	return nil
end

local function equipWeapon(player: Player, weaponName: string): boolean
	local template = WeaponCatalog.FindTemplate(weaponName)
	if not template then
		warn("[InventoryService] Missing weapon template:", weaponName)
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then
		warn("[InventoryService] No Backpack for", player.Name)
		return false
	end

	clearWeaponTools(backpack)
	clearWeaponTools(player.Character)

	local function clonePrepared(parent: Instance)
		local clone = template:Clone()
		WeaponCatalog.PrepareTool(clone, weaponName)
		clone.Parent = parent
	end

	clonePrepared(backpack)

	PlayerStateStore.SetEquippedWeaponName(player, weaponName)
	PlayerStateStore.EnsureOwnedWeapon(player, weaponName)
	return true
end

local function buildFavoriteSet(list: {any}?): {[string]: boolean}
	local set: {[string]: boolean} = {}
	if typeof(list) ~= "table" then return set end
	for _, name in ipairs(list) do
		if typeof(name) == "string" then
			set[name] = true
		end
	end
	return set
end

local function buildItemData(weaponName: string, favorites: {[string]: boolean})
	local item = {
		id = weaponName,
		name = weaponName,
		favorite = favorites[weaponName] == true,
	}
	local def = WeaponConfigs.Get(weaponName)
	if def then
		item.weaponType = def.weaponType
		item.rarity = def.rarity
		item.baseDamage = def.baseDamage
		local rarityMultiplier = ({
			Common = 1,
			Rare = 1.4,
			Epic = 1.8,
			Legendary = 2.4,
			Mythical = 3,
		})[def.rarity] or 1
		item.sellValue = def.sellValue or math.max(1, math.floor((def.baseDamage or 0) * 3 * rarityMultiplier))
		item.maxLevel = def.maxLevel
		item.stats = def.stats
		item.passiveName = def.passiveName
		item.passiveDescription = def.passiveDescription
		item.abilityName = def.abilityName
		item.abilityDescription = def.abilityDescription
	end
	return item
end

local function getSellValue(weaponName: string): number
	local def = WeaponConfigs.Get(weaponName)
	if not def then return 0 end
	local rarityMultiplier = ({
		Common = 1,
		Rare = 1.4,
		Epic = 1.8,
		Legendary = 2.4,
		Mythical = 3,
	})[def.rarity] or 1
	return def.sellValue or math.max(1, math.floor((def.baseDamage or 0) * 3 * rarityMultiplier))
end

local function sendInventory(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	local favorites = buildFavoriteSet(state.FavoriteWeapons)
	local items = {}
	for _, weaponName in ipairs(state.OwnedWeapons or {}) do
		if typeof(weaponName) == "string" and weaponName ~= "" then
			table.insert(items, buildItemData(weaponName, favorites))
		end
	end
	InventorySync:FireClient(player, {
		items = items,
		equippedId = state.StarterWeaponName,
	})
end

local function isOwned(state: any, weaponName: string): boolean
	if typeof(state.OwnedWeapons) ~= "table" then return false end
	for _, name in ipairs(state.OwnedWeapons) do
		if name == weaponName then
			return true
		end
	end
	return false
end

InventoryAction.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then return end
	local actionType = payload.type
	if actionType == "request" then
		sendInventory(player)
		return
	end

	local weaponName = tostring(payload.id or "")
	if weaponName == "" then return end

	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)

	if actionType == "equip" then
		if not isOwned(state, weaponName) then return end
		equipWeapon(player, weaponName)
		sendInventory(player)
		return
	end

	if actionType == "favorite" then
		if not isOwned(state, weaponName) then return end
		PlayerStateStore.SetFavoriteWeapon(player, weaponName, payload.value == true)
		sendInventory(player)
		return
	end

	if actionType == "sell" then
		if not isOwned(state, weaponName) then return end
		PlayerStateStore.RemoveOwnedWeapon(player, weaponName)
		PlayerStateStore.SetFavoriteWeapon(player, weaponName, false)
		local sellValue = getSellValue(weaponName)
		if sellValue > 0 then
			CurrencyService.AddCoins(player, sellValue)
		end
		if state.StarterWeaponName == weaponName then
			PlayerStateStore.SetEquippedWeaponName(player, nil)
			clearWeaponTools(player:FindFirstChildOfClass("Backpack"))
			clearWeaponTools(player.Character)
		end
		sendInventory(player)
		return
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	local state = PlayerStateStore.Load(player)
	if typeof(state.StarterWeaponName) ~= "string" or state.StarterWeaponName == "" then
		local detected = findWeaponName(player)
		if typeof(detected) == "string" and detected ~= "" then
			PlayerStateStore.EnsureOwnedWeapon(player, detected)
			PlayerStateStore.SetEquippedWeaponName(player, detected)
			state = PlayerStateStore.Get(player) or state
		end
	end
	if typeof(state.StarterWeaponName) == "string" and state.StarterWeaponName ~= "" then
		PlayerStateStore.EnsureOwnedWeapon(player, state.StarterWeaponName)
	end
	if typeof(state.StarterWeaponName) ~= "string" or state.StarterWeaponName == "" then
		local detected = findWeaponName(player)
		if typeof(detected) == "string" and detected ~= "" then
			PlayerStateStore.EnsureOwnedWeapon(player, detected)
			PlayerStateStore.SetEquippedWeaponName(player, detected)
			state = PlayerStateStore.Get(player) or state
		end
	end
	if typeof(state.StarterWeaponName) == "string" and state.StarterWeaponName ~= "" then
		PlayerStateStore.EnsureOwnedWeapon(player, state.StarterWeaponName)
	end
	if typeof(state.StarterWeaponName) ~= "string" or state.StarterWeaponName == "" then
		local detected = findWeaponName(player)
		if typeof(detected) == "string" and detected ~= "" then
			PlayerStateStore.EnsureOwnedWeapon(player, detected)
			PlayerStateStore.SetEquippedWeaponName(player, detected)
			state = PlayerStateStore.Get(player) or state
		end
	end
	if typeof(state.StarterWeaponName) == "string" and state.StarterWeaponName ~= "" then
		equipWeapon(player, state.StarterWeaponName)
	end
	task.defer(function()
		sendInventory(player)
	end)
end)

print("[InventoryService] Ready")
