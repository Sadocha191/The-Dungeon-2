-- SCRIPT: InventoryService.server.lua
-- GDZIE: ServerScriptService/InventoryService.server.lua
-- CO: synchronizacja ekwipunku lobby z Robloxowym ekwipunkiem (1 broń na pasku)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerStateStore = require(ServerScriptService:WaitForChild("PlayerStateStore"))
local WeaponCatalog = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("WeaponCatalog"))

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

local function isWeaponTool(inst: Instance): boolean
	return inst:IsA("Tool") and typeof(inst:GetAttribute("WeaponType")) == "string"
end

local function clearWeaponTools(container: Instance?)
	if not container then return end
	for _, inst in ipairs(container:GetChildren()) do
		if isWeaponTool(inst) then
			inst:Destroy()
		end
	end
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

	local starterGear = player:FindFirstChild("StarterGear") or player:WaitForChild("StarterGear", 10)
	if starterGear then
		clearWeaponTools(starterGear)
	end

	template:Clone().Parent = backpack
	if starterGear then
		template:Clone().Parent = starterGear
	end

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
	local template = WeaponCatalog.FindTemplate(weaponName)
	local item = {
		id = weaponName,
		name = weaponName,
		favorite = favorites[weaponName] == true,
	}
	if template and template:IsA("Tool") then
		local stats = {
			HP = template:GetAttribute("HP"),
			SPD = template:GetAttribute("SPD"),
			CRIT_RATE = template:GetAttribute("CRIT_RATE"),
			CRIT_DMG = template:GetAttribute("CRIT_DMG"),
			LIFESTEAL = template:GetAttribute("LIFESTEAL"),
			DEF = template:GetAttribute("DEF"),
		}
		item.weaponType = template:GetAttribute("WeaponType")
		item.rarity = template:GetAttribute("Rarity")
		item.baseDamage = template:GetAttribute("BaseDamage")
		item.sellValue = template:GetAttribute("SellValue")
		item.maxLevel = template:GetAttribute("MaxLevel")
		item.stats = stats
		item.passiveName = template:GetAttribute("PassiveName")
		item.passiveDescription = template:GetAttribute("PassiveDescription")
		item.abilityName = template:GetAttribute("AbilityName")
		item.abilityDescription = template:GetAttribute("AbilityDescription")
	end
	return item
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
		if state.StarterWeaponName == weaponName then
			PlayerStateStore.SetEquippedWeaponName(player, nil)
			clearWeaponTools(player:FindFirstChildOfClass("Backpack"))
			clearWeaponTools(player.Character)
			local starterGear = player:FindFirstChild("StarterGear")
			clearWeaponTools(starterGear)
		end
		sendInventory(player)
		return
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	local state = PlayerStateStore.Load(player)
	if typeof(state.StarterWeaponName) == "string" and state.StarterWeaponName ~= "" then
		equipWeapon(player, state.StarterWeaponName)
	end
	task.defer(function()
		sendInventory(player)
	end)
end)

print("[InventoryService] Ready")
