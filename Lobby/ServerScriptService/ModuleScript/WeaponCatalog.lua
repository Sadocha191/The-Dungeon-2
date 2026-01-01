local ServerStorage = game:GetService("ServerStorage")

local templates = ServerStorage:WaitForChild("WeaponTemplates")

local WeaponCatalog = {}

function WeaponCatalog.FindTemplate(weaponName: string): Tool?
	if typeof(weaponName) ~= "string" or weaponName == "" then
		return nil
	end
	local found = templates:FindFirstChild(weaponName, true)
	if found and found:IsA("Tool") then
		return found
	end
	return nil
end

return WeaponCatalog
