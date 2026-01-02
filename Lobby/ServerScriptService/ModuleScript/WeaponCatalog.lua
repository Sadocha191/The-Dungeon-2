local ReplicatedStorage = game:GetService("ReplicatedStorage")

local templates = ReplicatedStorage:WaitForChild("WeaponTemplates")
local weaponConfigsModule = ReplicatedStorage:FindFirstChild("ModuleScripts")
	and ReplicatedStorage.ModuleScripts:FindFirstChild("WeaponConfigs")
local WeaponConfigs = weaponConfigsModule and require(weaponConfigsModule) or nil

local WeaponCatalog = {}

local function normalizeName(name: string): string
	local normalized = name:gsub("’", "'")
	normalized = normalized:gsub("%s+", " ")
	normalized = normalized:match("^%s*(.-)%s*$") or normalized
	return normalized
end

local function wrapAsTool(container: Instance): Tool?
	if container:IsA("Tool") then
		return container
	end
	if not (container:IsA("Folder") or container:IsA("Model")) then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = container.Name
	tool.Parent = container.Parent

	for _, child in ipairs(container:GetChildren()) do
		child.Parent = tool
	end
	container:Destroy()

	return tool
end

local function disableLegacyScripts(tool: Tool)
	for _, inst in ipairs(tool:GetDescendants()) do
		if inst:IsA("Script") or inst:IsA("LocalScript") then
			inst.Disabled = true
		end
	end
end

local function clearToolJoints(tool: Tool)
	for _, inst in ipairs(tool:GetDescendants()) do
		if inst:IsA("JointInstance") or inst:IsA("WeldConstraint") then
			inst:Destroy()
		end
	end
end

local function normalizeToolParts(tool: Tool)
	clearToolJoints(tool)
	local handle = tool:FindFirstChild("Handle", true)
	local handlePart: BasePart? = nil
	if handle and handle:IsA("BasePart") then
		handlePart = handle
	else
		for _, inst in ipairs(tool:GetDescendants()) do
			if inst:IsA("BasePart") then
				handlePart = inst
				inst.Name = "Handle"
				break
			end
		end
	end

	if handlePart then
		handlePart.Parent = tool
		handlePart.Anchored = false
		handlePart.CanCollide = false
		handlePart.Massless = true
	end

	for _, inst in ipairs(tool:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = false
			inst.CanCollide = false
			inst.Massless = true
			if handlePart and inst ~= handlePart then
				local existing = false
				for _, joint in ipairs(inst:GetChildren()) do
					if joint:IsA("WeldConstraint") and (joint.Part0 == handlePart or joint.Part1 == handlePart) then
						existing = true
						break
					end
				end
				if not existing then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handlePart
					weld.Part1 = inst
					weld.Parent = inst
				end
			end
		end
	end
end

local function applyWeaponConfig(tool: Tool, weaponName: string)
	if not WeaponConfigs then return end
	local def = WeaponConfigs.Get and WeaponConfigs.Get(weaponName) or WeaponConfigs.Defs and WeaponConfigs.Defs[weaponName]
	if not def then return end

	local stats = def.stats or {}
	tool:SetAttribute("WeaponType", def.weaponType or "")
	tool:SetAttribute("Rarity", def.rarity or "")
	tool:SetAttribute("BaseDamage", def.baseDamage or 0)
	tool:SetAttribute("MaxLevel", def.maxLevel or 0)
	tool:SetAttribute("SellValue", def.sellValue or math.max(1, math.floor((def.baseDamage or 0) * 3)))

	tool:SetAttribute("HP", stats.HP or 0)
	tool:SetAttribute("SPD", stats.SPD or 0)
	tool:SetAttribute("CRIT_RATE", stats.CRIT_RATE or 0)
	tool:SetAttribute("CRIT_DMG", stats.CRIT_DMG or 0)
	tool:SetAttribute("LIFESTEAL", stats.LIFESTEAL or 0)
	tool:SetAttribute("DEF", stats.DEF or 0)

	tool:SetAttribute("PassiveName", def.passiveName or "")
	tool:SetAttribute("PassiveDescription", def.passiveDescription or "")
	tool:SetAttribute("AbilityName", def.abilityName or "")
	tool:SetAttribute("AbilityDescription", def.abilityDescription or "")
end

function WeaponCatalog.PrepareTool(tool: Tool, weaponName: string?)
	tool.RequiresHandle = true
	disableLegacyScripts(tool)
	normalizeToolParts(tool)
	if weaponName then
		applyWeaponConfig(tool, weaponName)
	end
end

function WeaponCatalog.FindTemplate(weaponName: string): Tool?
	if typeof(weaponName) ~= "string" or weaponName == "" then
		return nil
	end
	local normalizedTarget = normalizeName(weaponName)
	local fallback: Instance? = nil
	for _, inst in ipairs(templates:GetDescendants()) do
		if inst:IsA("Tool") then
			if normalizeName(inst.Name) == normalizedTarget then
				WeaponCatalog.PrepareTool(inst)
				return inst
			end
		elseif not fallback and normalizeName(inst.Name) == normalizedTarget then
			fallback = inst
		end
	end
	if fallback then
		local wrapped = wrapAsTool(fallback)
		if wrapped then
			WeaponCatalog.PrepareTool(wrapped)
			return wrapped
		end
	end
	return nil
end

return WeaponCatalog
