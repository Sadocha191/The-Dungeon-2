local ServerStorage = game:GetService("ServerStorage")

local templates = ServerStorage:WaitForChild("WeaponTemplates")

local WeaponCatalog = {}

local function normalizeName(name: string): string
	return name:gsub("’", "'")
end

function WeaponCatalog.FindTemplate(weaponName: string): Tool?
	if typeof(weaponName) ~= "string" or weaponName == "" then
		return nil
	end
	local normalizedTarget = normalizeName(weaponName)
	for _, inst in ipairs(templates:GetDescendants()) do
		if inst:IsA("Tool") then
			if normalizeName(inst.Name) == normalizedTarget then
				return inst
			end
		end
	end
	return nil
end

return WeaponCatalog
