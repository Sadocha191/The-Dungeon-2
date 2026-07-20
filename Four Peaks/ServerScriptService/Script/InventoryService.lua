-- SCRIPT: InventoryService.server.lua
-- Lobby inventory synchronization with serialized, confirmed persistent mutations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))
local CraftingService = require(serverModules:WaitForChild("CraftingService"))
local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local WeaponConfigs = require(replicatedModules:WaitForChild("WeaponConfigs"))
local SpellDefs = require(replicatedModules:WaitForChild("SpellDefinitions"))

local function findWeaponCatalog(): ModuleScript?
	local direct = ServerScriptService:FindFirstChild("WeaponCatalog", true)
	if direct and direct:IsA("ModuleScript") then return direct end
	local folder = ServerScriptService:FindFirstChild("ModuleScript")
		or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild("WeaponCatalog")
		if nested and nested:IsA("ModuleScript") then return nested end
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
	local event = remoteEvents:FindFirstChild(name)
	if event and event:IsA("RemoteEvent") then return event end
	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remoteEvents
	return event
end

local InventoryAction = ensureRemote("InventoryAction")
local InventorySync = ensureRemote("InventorySync")

local ACTION_COOLDOWN_SECONDS = 0.35
local ECONOMY_BUSY_ATTRIBUTE = "EconomyMutationBusy"
local activeMutation = {}
local lastMutation = {}

local WeaponTemplates = ServerStorage:WaitForChild("WeaponTemplates", 10)
if not WeaponTemplates then
	warn("[InventoryService] Missing ServerStorage.WeaponTemplates; fallback to WeaponType attributes only.")
end

local function beginMutation(player: Player): (boolean, string?)
	local userId = player.UserId
	if player:GetAttribute("PersistenceBlocked") == true then return false, "PersistenceUnavailable" end
	if activeMutation[userId] or player:GetAttribute(ECONOMY_BUSY_ATTRIBUTE) == true then return false, "Busy" end
	local current = os.clock()
	if current - (lastMutation[userId] or 0) < ACTION_COOLDOWN_SECONDS then return false, "RateLimited" end
	lastMutation[userId] = current
	activeMutation[userId] = true
	player:SetAttribute(ECONOMY_BUSY_ATTRIBUTE, true)
	return true
end

local function finishMutation(player: Player)
	activeMutation[player.UserId] = nil
	if player.Parent == Players then player:SetAttribute(ECONOMY_BUSY_ATTRIBUTE, nil) end
end

local function blockAfterSaveFailure(player: Player, reason)
	player:SetAttribute("PersistenceBlocked", true)
	warn("[InventoryService] Confirmed save failed; blocking further inventory mutations:", player.Name, reason)
	if not RunService:IsStudio() then
		task.defer(function()
			if player.Parent == Players then
				player:Kick("Your latest inventory change could not be confirmed safely. Please rejoin.")
			end
		end)
	end
end

local function confirmMutation(player: Player, reason: string): boolean
	local saved, saveError = PlayerData.SaveBarrier(player, reason)
	if saved then return true end
	blockAfterSaveFailure(player, saveError)
	return false
end

local function isWeaponTool(instance: Instance): boolean
	if not instance:IsA("Tool") then return false end
	if typeof(instance:GetAttribute("WeaponType")) == "string" then return true end
	return WeaponTemplates and WeaponTemplates:FindFirstChild(instance.Name, true) ~= nil
end

local function clearWeaponTools(container: Instance?)
	if not container then return end
	for _, instance in ipairs(container:GetChildren()) do
		if isWeaponTool(instance) then instance:Destroy() end
	end
end

local function findWeaponName(player: Player): string?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, instance in ipairs(backpack:GetChildren()) do
			if isWeaponTool(instance) then return instance.Name end
		end
	end
	local character = player.Character
	if character then
		for _, instance in ipairs(character:GetChildren()) do
			if isWeaponTool(instance) then return instance.Name end
		end
	end
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, instance in ipairs(starterGear:GetChildren()) do
			if isWeaponTool(instance) then return instance.Name end
		end
	end
	return nil
end

local function applyInstanceAttributes(tool: Tool, instance: any)
	tool:SetAttribute("WeaponInstanceId", instance.instanceId)
	tool:SetAttribute("WeaponLevel", tonumber(instance.level) or 1)
	tool:SetAttribute("WeaponPrefix", tostring(instance.prefix or "Standard"))
	if typeof(instance.rollStats) == "table" then
		for key, value in pairs(instance.rollStats) do
			if typeof(key) == "string" and typeof(value) == "number" then
				tool:SetAttribute("Roll_" .. key, value)
			end
		end
	end
end

local function equipWeaponInstance(player: Player, instanceId: string): boolean
	if not PlayerStateStore.Get(player) then PlayerStateStore.Load(player) end
	local instance = PlayerStateStore.GetWeaponInstance(player, instanceId)
	if not instance then return false end
	local weaponName = instance.weaponId
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
	local clone = template:Clone()
	WeaponCatalog.PrepareTool(clone, weaponName)
	applyInstanceAttributes(clone, instance)
	clone.Parent = backpack

	PlayerStateStore.SetEquippedWeaponInstance(player, instanceId)
	PlayerStateStore.EnsureOwnedWeapon(player, weaponName)
	return true
end

local function buildFavoriteSet(list: {any}?): {[string]: boolean}
	local set = {}
	if typeof(list) ~= "table" then return set end
	for _, name in ipairs(list) do
		if typeof(name) == "string" then set[name] = true end
	end
	return set
end

local function toPct(value: number): number
	return math.floor((tonumber(value) or 0) * 100 + 0.5)
end

local function computeInstanceStats(def: any, instance: any)
	local combat = def.combat or {}
	local roll = typeof(instance.rollStats) == "table" and instance.rollStats or {}
	local level = math.max(1, math.floor(tonumber(instance.level) or 1))
	local baseAtk = (combat.baseAtk or def.baseDamage or 0) + (roll.BaseATK or 0)
	local atkPerLevel = (combat.atkPerLevel or 0) + (roll.ATKPerLevel or 0)
	local atk = baseAtk + (level - 1) * atkPerLevel
	return {
		ATK = math.floor(atk + 0.5),
		HP = math.floor(((combat.bonusHP or 0) + (roll.BonusHP or 0)) + 0.5),
		DEF = math.floor(((combat.bonusDefense or 0) + (roll.BonusDefense or 0)) + 0.5),
		SPD = toPct((combat.bonusSpeed or 0) + (roll.BonusSpeed or 0)),
		CRIT_RATE = toPct((combat.bonusCritRate or 0) + (roll.BonusCritRate or 0)),
		CRIT_DMG = toPct((combat.bonusCritDmg or 0) + (roll.BonusCritDmg or 0)),
		LIFESTEAL = toPct((combat.bonusLifesteal or 0) + (roll.BonusLifesteal or 0)),
	}
end

local function buildItemData(instance: any, favorites: {[string]: boolean})
	local weaponId = instance.weaponId
	local def = WeaponConfigs.Get(weaponId)
	local rarity = tostring(instance.rarity or "") ~= "" and tostring(instance.rarity)
		or (def and def.rarity) or "Common"
	local item = {
		id = instance.instanceId,
		weaponId = weaponId,
		prefix = tostring(instance.prefix or "Standard"),
		level = tonumber(instance.level) or 1,
		rarity = rarity,
		favorite = favorites[weaponId] == true,
	}
	if def then
		item.weaponType = def.weaponType
		item.maxLevel = def.maxLevel
		item.passiveName = def.passiveName
		item.abilityName = def.abilityName
		item.stats = computeInstanceStats(def, instance)
		local rarityMultiplier = ({ Common = 1, Rare = 1.4, Epic = 1.8, Legendary = 2.4, Mythical = 3 })[rarity] or 1
		item.sellValue = def.sellValue or math.max(1, math.floor((def.baseDamage or 0) * 3 * rarityMultiplier))
		item.passiveDescription = def.passiveDescription
		item.abilityDescription = def.abilityDescription
	end
	return item
end

local function sendInventory(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if not state then return end
	local favorites = buildFavoriteSet(state.FavoriteWeapons)
	local items = {}
	for _, instance in ipairs(state.WeaponInstances or {}) do
		if typeof(instance) == "table" and typeof(instance.instanceId) == "string" then
			table.insert(items, buildItemData(instance, favorites))
		end
	end
	InventorySync:FireClient(player, {
		items = items,
		equippedId = state.EquippedWeaponInstanceId,
	})
end

local function hasInstance(player: Player, instanceId: string): boolean
	return PlayerStateStore.GetWeaponInstance(player, instanceId) ~= nil
end

local function getPayloadSpellProductId(payload: any): string?
	local raw = payload.productId or payload.id or payload.spellId
	local productId = SpellDefs.NormalizeLoadoutProductId(raw)
	if typeof(productId) == "string" and productId ~= "" then return productId end
	return nil
end

local function saveSpellLoadout(player: Player, nextLoadout: {any})
	local validated = {}
	if PlayerData.SetSpellLoadout then validated = PlayerData.SetSpellLoadout(player, nextLoadout) end
	if PlayerStateStore.SetSpellLoadout then PlayerStateStore.SetSpellLoadout(player, validated) end
	return validated
end

local function handleSpellLoadoutAction(player: Player, payload: any): boolean
	local actionType = tostring(payload.type or "")
	if actionType ~= "spellLoadoutEquip"
		and actionType ~= "spellLoadoutUnequip"
		and actionType ~= "spellLoadoutMove"
		and actionType ~= "spellLoadoutSet"
	then
		return false
	end

	local data = PlayerData.Get(player)
	data.spellsUnlocked = data.spellsUnlocked or {}
	local current = PlayerData.ResolveSpellLoadout and PlayerData.ResolveSpellLoadout(player)
		or (PlayerData.GetSpellLoadout and PlayerData.GetSpellLoadout(player))
		or {}
	local nextLoadout = {}
	for _, productId in ipairs(current) do table.insert(nextLoadout, productId) end

	if actionType == "spellLoadoutSet" then
		saveSpellLoadout(player, payload.loadout or {})
		return true
	end

	local productId = getPayloadSpellProductId(payload)
	local product = productId and SpellDefs.GetProduct(productId) or nil
	if not product or data.spellsUnlocked[productId] ~= true then return true end

	if actionType == "spellLoadoutEquip" then
		local familySeen = {}
		for _, existingId in ipairs(nextLoadout) do
			local existingProduct = SpellDefs.GetProduct(existingId)
			if existingProduct then familySeen[existingProduct.familyId] = true end
		end
		if not familySeen[product.familyId] then table.insert(nextLoadout, productId) end
	elseif actionType == "spellLoadoutUnequip" then
		local filtered = {}
		for _, existingId in ipairs(nextLoadout) do
			if existingId ~= productId then table.insert(filtered, existingId) end
		end
		nextLoadout = filtered
	elseif actionType == "spellLoadoutMove" then
		local direction = math.clamp(math.floor(tonumber(payload.direction) or 0), -1, 1)
		if direction ~= 0 then
			for index, existingId in ipairs(nextLoadout) do
				if existingId == productId then
					local target = math.clamp(index + direction, 1, #nextLoadout)
					if target ~= index then
						nextLoadout[index], nextLoadout[target] = nextLoadout[target], nextLoadout[index]
					end
					break
				end
			end
		end
	end

	saveSpellLoadout(player, nextLoadout)
	return true
end

InventoryAction.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" then return end
	local actionType = tostring(payload.type or "")
	if actionType == "request" then
		sendInventory(player)
		return
	end

	local allowed = beginMutation(player)
	if not allowed then return end

	local callOk, callError = pcall(function()
		if handleSpellLoadoutAction(player, payload) then
			confirmMutation(player, "inventory_spell_loadout")
			sendInventory(player)
			return
		end

		local instanceId = tostring(payload.id or "")
		if instanceId == "" then return end
		local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
		if not state then return end

		if actionType == "equip" then
			if not hasInstance(player, instanceId) then return end
			if equipWeaponInstance(player, instanceId) and confirmMutation(player, "inventory_equip") then
				sendInventory(player)
			end
			return
		end

		if actionType == "favorite" then
			local instance = PlayerStateStore.GetWeaponInstance(player, instanceId)
			if not instance then return end
			PlayerStateStore.SetFavoriteWeapon(player, instance.weaponId, payload.value == true)
			if confirmMutation(player, "inventory_favorite") then sendInventory(player) end
			return
		end

		if actionType == "sell" then
			local instance = PlayerStateStore.GetWeaponInstance(player, instanceId)
			if not instance then return end
			local equippedBefore = state.EquippedWeaponInstanceId
			local sold = CraftingService.SellWeaponInstance(player, instanceId)
			if not sold then return end
			PlayerStateStore.SetFavoriteWeapon(player, instance.weaponId, false)

			local updatedState = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
			if equippedBefore == instanceId then
				local nextEquippedId = updatedState and updatedState.EquippedWeaponInstanceId or nil
				if typeof(nextEquippedId) == "string" and nextEquippedId ~= "" then
					if not equipWeaponInstance(player, nextEquippedId) then
						clearWeaponTools(player:FindFirstChildOfClass("Backpack"))
						clearWeaponTools(player.Character)
					end
				else
					clearWeaponTools(player:FindFirstChildOfClass("Backpack"))
					clearWeaponTools(player.Character)
				end
			end
			if confirmMutation(player, "inventory_sell") then sendInventory(player) end
		end
	end)

	finishMutation(player)
	if not callOk then
		warn("[InventoryService] Inventory action failed with an exception:", player.Name, actionType, callError)
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if not state then return end
	if #(state.WeaponInstances or {}) == 0 then
		local detected = findWeaponName(player)
		if typeof(detected) == "string" and detected ~= "" then
			PlayerStateStore.EnsureOwnedWeapon(player, detected)
			state = PlayerStateStore.Get(player) or state
		end
	end
	if typeof(state.EquippedWeaponInstanceId) == "string" and state.EquippedWeaponInstanceId ~= "" then
		equipWeaponInstance(player, state.EquippedWeaponInstanceId)
	elseif state.WeaponInstances and state.WeaponInstances[1] then
		equipWeaponInstance(player, state.WeaponInstances[1].instanceId)
	end
	task.defer(function() sendInventory(player) end)
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	activeMutation[userId] = nil
	lastMutation[userId] = nil
end)

print("[InventoryService] Ready (shared economy lock + confirmed persistence)")
