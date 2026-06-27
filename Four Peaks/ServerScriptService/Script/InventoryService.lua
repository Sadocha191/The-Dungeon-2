-- SCRIPT: InventoryService.server.lua
-- GDZIE: ServerScriptService/InventoryService.server.lua
-- CO: synchronizacja ekwipunku lobby z Robloxowym ekwipunkiem (1 broń na pasku)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local function applyInstanceAttributes(tool: Tool, inst: any)
	tool:SetAttribute("WeaponInstanceId", inst.instanceId)
	tool:SetAttribute("WeaponLevel", tonumber(inst.level) or 1)
	tool:SetAttribute("WeaponPrefix", tostring(inst.prefix or "Standard"))
	if typeof(inst.rollStats) == "table" then
		for k, v in pairs(inst.rollStats) do
			if typeof(k) == "string" and typeof(v) == "number" then
				tool:SetAttribute("Roll_" .. k, v)
			end
		end
	end
end

local function equipWeaponInstance(player: Player, instanceId: string): boolean
	if not PlayerStateStore.Get(player) then
		PlayerStateStore.Load(player)
	end
	local inst = PlayerStateStore.GetWeaponInstance(player, instanceId)
	if not inst then
		return false
	end
	local weaponName = inst.weaponId
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

	local function clonePrepared(parent: Instance): Tool
		local clone = template:Clone()
		WeaponCatalog.PrepareTool(clone, weaponName)
		applyInstanceAttributes(clone, inst)
		clone.Parent = parent
		return clone
	end

	clonePrepared(backpack)

	PlayerStateStore.SetEquippedWeaponInstance(player, instanceId)
	PlayerStateStore.EnsureOwnedWeapon(player, weaponName) -- legacy unique list sync
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

local function buildItemData(inst: any, favorites: {[string]: boolean})
	local weaponId = inst.weaponId
	local def = WeaponConfigs.Get(weaponId)
	local rarity = (tostring(inst.rarity or "") ~= "" and tostring(inst.rarity)) or (def and def.rarity) or "Common"
	local item = {
		id = inst.instanceId,
		weaponId = weaponId,
		prefix = tostring(inst.prefix or "Standard"),
		level = tonumber(inst.level) or 1,
		rarity = rarity,
		favorite = favorites[weaponId] == true,
	}
	if def then
		item.weaponType = def.weaponType
		item.maxLevel = def.maxLevel
		item.passiveName = def.passiveName
		item.abilityName = def.abilityName
		item.stats = computeInstanceStats(def, inst)
		local rarityMultiplier = ({
			Common = 1,
			Rare = 1.4,
			Epic = 1.8,
			Legendary = 2.4,
			Mythical = 3,
		})[rarity] or 1
		item.sellValue = def.sellValue or math.max(1, math.floor((def.baseDamage or 0) * 3 * rarityMultiplier))
	end
	if def then
		item.passiveDescription = def.passiveDescription
		item.abilityDescription = def.abilityDescription
	end
	return item
end

local function sendInventory(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	local favorites = buildFavoriteSet(state.FavoriteWeapons)
	local items = {}
	for _, inst in ipairs(state.WeaponInstances or {}) do
		if typeof(inst) == "table" and typeof(inst.instanceId) == "string" then
			table.insert(items, buildItemData(inst, favorites))
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
	if typeof(productId) == "string" and productId ~= "" then
		return productId
	end
	return nil
end

local function saveSpellLoadout(player: Player, nextLoadout: {any})
	local validated = {}
	if PlayerData.SetSpellLoadout then
		validated = PlayerData.SetSpellLoadout(player, nextLoadout)
	end
	if PlayerStateStore.SetSpellLoadout then
		PlayerStateStore.SetSpellLoadout(player, validated)
	end
	if PlayerData.Save then
		PlayerData.Save(player, false)
	end
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
	for _, productId in ipairs(current) do
		table.insert(nextLoadout, productId)
	end

	if actionType == "spellLoadoutSet" then
		saveSpellLoadout(player, payload.loadout or {})
		return true
	end

	local productId = getPayloadSpellProductId(payload)
	local product = productId and SpellDefs.GetProduct(productId) or nil
	if not product or data.spellsUnlocked[productId] ~= true then
		return true
	end

	if actionType == "spellLoadoutEquip" then
		local familySeen = {}
		for _, existingId in ipairs(nextLoadout) do
			local existingProduct = SpellDefs.GetProduct(existingId)
			if existingProduct then
				familySeen[existingProduct.familyId] = true
			end
		end
		if not familySeen[product.familyId] then
			table.insert(nextLoadout, productId)
		end
	elseif actionType == "spellLoadoutUnequip" then
		local filtered = {}
		for _, existingId in ipairs(nextLoadout) do
			if existingId ~= productId then
				table.insert(filtered, existingId)
			end
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
	local actionType = payload.type
	if actionType == "request" then
		sendInventory(player)
		return
	end

	if handleSpellLoadoutAction(player, payload) then
		return
	end

	local instanceId = tostring(payload.id or "")
	if instanceId == "" then return end

	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)

	if actionType == "equip" then
		if not hasInstance(player, instanceId) then return end
		equipWeaponInstance(player, instanceId)
		sendInventory(player)
		return
	end

	if actionType == "favorite" then
		local inst = PlayerStateStore.GetWeaponInstance(player, instanceId)
		if not inst then return end
		PlayerStateStore.SetFavoriteWeapon(player, inst.weaponId, payload.value == true)
		sendInventory(player)
		return
	end

	if actionType == "sell" then
		local inst = PlayerStateStore.GetWeaponInstance(player, instanceId)
		if not inst then return end
		local ok = CraftingService.SellWeaponInstance(player, instanceId)
		if not ok then return end
		PlayerStateStore.SetFavoriteWeapon(player, inst.weaponId, false)

		local updatedState = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
		if state.EquippedWeaponInstanceId == instanceId then
			local nextEquippedId = updatedState.EquippedWeaponInstanceId
			if typeof(nextEquippedId) == "string" and nextEquippedId ~= "" then
				equipWeaponInstance(player, nextEquippedId)
			else
				clearWeaponTools(player:FindFirstChildOfClass("Backpack"))
				clearWeaponTools(player.Character)
			end
		end
		sendInventory(player)
		return
	end
end)

Players.PlayerAdded:Connect(function(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	-- jeśli brak instancji, spróbuj wykryć tool z Backpack/Character i zrobić instancję
	if (#(state.WeaponInstances or {}) == 0) then
		local detected = findWeaponName(player)
		if typeof(detected) == "string" and detected ~= "" then
			PlayerStateStore.EnsureOwnedWeapon(player, detected)
			state = PlayerStateStore.Get(player) or state
		end
	end
	-- equip zapisanej instancji (albo pierwszej)
	if typeof(state.EquippedWeaponInstanceId) == "string" and state.EquippedWeaponInstanceId ~= "" then
		equipWeaponInstance(player, state.EquippedWeaponInstanceId)
	elseif state.WeaponInstances and state.WeaponInstances[1] then
		equipWeaponInstance(player, state.WeaponInstances[1].instanceId)
	end
	task.defer(function()
		sendInventory(player)
	end)
end)

print("[InventoryService] Ready")
