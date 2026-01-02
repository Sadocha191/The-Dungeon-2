-- SCRIPT: WeaponTemplates.server.lua
-- GDZIE: ServerScriptService/WeaponTemplates.server.lua (Script)
-- CO: normalizuje szablony broni (prefaby) z ReplicatedStorage/WeaponTemplates

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local WeaponCatalog = require(ServerScriptService:WaitForChild("WeaponCatalog"))
local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))

local updated = 0
for _, def in ipairs(WeaponConfigs.GetAll()) do
	local template = WeaponCatalog.FindTemplate(def.id)
	if template then
		WeaponCatalog.PrepareTool(template)
		updated += 1
	else
		warn("[WeaponTemplates] Missing template:", def.id)
	end
end

print("[WeaponTemplates] Normalized weapon templates:", updated)
