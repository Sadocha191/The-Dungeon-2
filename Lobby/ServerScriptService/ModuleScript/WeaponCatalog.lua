local ServerStorage = game:GetService("ServerStorage")

local templates = ServerStorage:WaitForChild("WeaponTemplates")

local WeaponCatalog = {}

local function normalizeName(name: string): string
	return name:gsub("’", "'")
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

function WeaponCatalog.FindTemplate(weaponName: string): Tool?
	if typeof(weaponName) ~= "string" or weaponName == "" then
		return nil
	end
	local normalizedTarget = normalizeName(weaponName)
	local fallback: Instance? = nil
	for _, inst in ipairs(templates:GetDescendants()) do
		if inst:IsA("Tool") then
			if normalizeName(inst.Name) == normalizedTarget then
				return inst
			end
		elseif not fallback and normalizeName(inst.Name) == normalizedTarget then
			fallback = inst
		end
	end
	if fallback then
		return wrapAsTool(fallback)
	end
	return nil
end

return WeaponCatalog
