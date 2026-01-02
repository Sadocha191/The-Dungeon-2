-- WeaponService.lua (ServerScriptService)
-- Responsible for equipping player loadouts from ReplicatedStorage.WeaponTemplates

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function findModule(name: string): ModuleScript?
	local direct = ServerScriptService:FindFirstChild(name)
	if direct and direct:IsA("ModuleScript") then
		return direct
	end
	local folder = ServerScriptService:FindFirstChild("ModuleScript")
		or ServerScriptService:FindFirstChild("ModuleScripts")
	if folder then
		local nested = folder:FindFirstChild(name)
		if nested and nested:IsA("ModuleScript") then
			return nested
		end
	end
	return nil
end

local playerDataModule = findModule("PlayerData")
if not playerDataModule then
	error("[WeaponService] Missing PlayerData module.")
end

local PlayerData = require(playerDataModule)

local WeaponTemplates = ReplicatedStorage:WaitForChild("WeaponTemplates")
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
local WeaponConfigs = moduleFolder and moduleFolder:FindFirstChild("WeaponConfigs")
	and require(moduleFolder.WeaponConfigs) or nil

local WeaponService = {}

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

local function getWeaponConfig(weaponId: string)
	if WeaponConfigs and WeaponConfigs.Get then
		return WeaponConfigs.Get(weaponId)
	end
	return nil
end

local function getRolledStat(stats: any, keys: {string}): number
	if typeof(stats) ~= "table" then
		return 0
	end
	for _, key in ipairs(keys) do
		local value = stats[key]
		if typeof(value) == "number" then
			return value
		end
	end
	return 0
end

local function applyWeaponStats(tool: Tool, weaponId: string, entry: any)
	local def = getWeaponConfig(weaponId)
	if not def then
		tool:SetAttribute("WeaponType", tool:GetAttribute("WeaponType") or "")
		return
	end

	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local level = tonumber(entry and (entry.level or entry.Level)) or 1
	level = math.max(1, math.floor(level))

	local rarity = tostring(entry and (entry.rarity or entry.Rarity) or def.rarity or "")
	local stats = entry and (entry.stats or entry.Stats) or {}
	local combat = def.combat or {}

	tool:SetAttribute("WeaponId", weaponId)
	tool:SetAttribute("WeaponType", def.weaponType or "")
	tool:SetAttribute("WeaponLevel", level)
	tool:SetAttribute("Rarity", rarity)

	local baseAtk = (combat.baseAtk or def.baseDamage or 0) + getRolledStat(stats, { "BaseATK", "baseAtk" })
	local atkPerLevel = (combat.atkPerLevel or 0) + getRolledStat(stats, { "ATKPerLevel", "atkPerLevel" })

	tool:SetAttribute("BaseATK", baseAtk)
	tool:SetAttribute("ATKPerLevel", atkPerLevel)
	tool:SetAttribute("BonusHP", (combat.bonusHP or 0) + getRolledStat(stats, { "BonusHP", "bonusHP", "HP" }))
	tool:SetAttribute("BonusSpeed", (combat.bonusSpeed or 0) + getRolledStat(stats, { "BonusSpeed", "bonusSpeed", "SPD" }))
	tool:SetAttribute("BonusCritRate", (combat.bonusCritRate or 0) + getRolledStat(stats, { "BonusCritRate", "bonusCritRate", "CRIT_RATE" }))
	tool:SetAttribute("BonusCritDmg", (combat.bonusCritDmg or 0) + getRolledStat(stats, { "BonusCritDmg", "bonusCritDmg", "CRIT_DMG" }))
	tool:SetAttribute("BonusLifesteal", (combat.bonusLifesteal or 0) + getRolledStat(stats, { "BonusLifesteal", "bonusLifesteal", "LIFESTEAL" }))
	tool:SetAttribute("BonusDefense", (combat.bonusDefense or 0) + getRolledStat(stats, { "BonusDefense", "bonusDefense", "DEF" }))

	tool:SetAttribute("PassiveName", def.passiveName or "")
	tool:SetAttribute("PassiveDescription", def.passiveDescription or "")
	tool:SetAttribute("AbilityName", def.abilityName or "")
	tool:SetAttribute("AbilityDescription", def.abilityDescription or "")
end

local function wrapAsTool(container: Instance, weaponId: string): Tool?
	if container:IsA("Tool") then
		return container
	end
	if not (container:IsA("Folder") or container:IsA("Model")) then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = weaponId
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Parent = container.Parent

	for _, child in ipairs(container:GetChildren()) do
		child.Parent = tool
	end
	container:Destroy()

	local handle = tool:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then
		handle.Name = "Handle"
		handle.Parent = tool
	else
		for _, inst in ipairs(tool:GetDescendants()) do
			if inst:IsA("BasePart") then
				inst.Name = "Handle"
				inst.Parent = tool
				break
			end
		end
	end

	return tool
end

local function cloneTemplate(weaponId: string): Tool?
	local template = WeaponTemplates:FindFirstChild(weaponId)
	if not template then
		warn("[WeaponService] Missing weapon template:", weaponId)
		return nil
	end

	local clone = template:Clone()
	local tool = wrapAsTool(clone, weaponId)
	if tool then
		return tool
	end

	warn("[WeaponService] Template is not a Tool/Folder/Model:", weaponId)
	return nil
end

local function normalizeLoadoutEntry(entry: any): (string?, any)
	if typeof(entry) == "string" then
		return entry, { id = entry, level = 1 }
	end
	if typeof(entry) ~= "table" then
		return nil, nil
	end
	local id = entry.id or entry.weaponId or entry.weaponID or entry.name or entry.weaponName
	if typeof(id) ~= "string" or id == "" then
		return nil, nil
	end
	return id, entry
end

local function buildLoadoutList(player: Player)
	local data = PlayerData.Get(player)
	local loadout = data.Loadout or data.loadout

	local entries = {}
	if typeof(loadout) == "table" then
		for _, entry in ipairs(loadout) do
			local id, normalized = normalizeLoadoutEntry(entry)
			if id then
				table.insert(entries, { id = id, entry = normalized })
			end
		end
	end

	if #entries == 0 then
		local starter = player:GetAttribute("StarterWeaponName")
		if typeof(starter) == "string" and starter ~= "" then
			entries = { { id = starter, entry = { id = starter, level = 1 } } }
		end
	end

	if #entries == 0 then
		entries = { { id = "Sword", entry = { id = "Sword", level = 1 } } }
	end

	return entries
end

function WeaponService.EquipLoadout(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then return end

	local starterGear = player:FindFirstChild("StarterGear")

	clearWeaponTools(backpack)
	clearWeaponTools(player.Character)
	clearWeaponTools(starterGear)

	local equippedTool: Tool? = nil
	for _, payload in ipairs(buildLoadoutList(player)) do
		local tool = cloneTemplate(payload.id)
		if tool then
			applyWeaponStats(tool, payload.id, payload.entry)
			tool.Parent = backpack
			if not equippedTool then
				equippedTool = tool
			end
			if starterGear then
				local starterClone = cloneTemplate(payload.id)
				if starterClone then
					applyWeaponStats(starterClone, payload.id, payload.entry)
					starterClone.Parent = starterGear
				end
			end
		end
	end

	if equippedTool then
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:EquipTool(equippedTool)
		end
	end
end

function WeaponService.SyncLoadoutFromStarter(player: Player)
	local data = PlayerData.Get(player)
	local starter = player:GetAttribute("StarterWeaponName")
	if typeof(starter) == "string" and starter ~= "" then
		data.Loadout = { { id = starter, level = 1 } }
		PlayerData.MarkDirty(player)
	end
end

return WeaponService
