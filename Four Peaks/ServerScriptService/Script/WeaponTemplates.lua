-- SCRIPT: WeaponTemplates.server.lua
-- GDZIE: ServerScriptService/WeaponTemplates.server.lua (Script)
-- CO: normalizuje szablony broni (prefaby) z ServerStorage/WeaponTemplates

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local WeaponCatalog = require(serverModules:WaitForChild("WeaponCatalog"))
local WeaponConfigs = require((ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript") or ReplicatedStorage:WaitForChild("ModuleScripts", 5) or ReplicatedStorage:WaitForChild("ModuleScript", 5)):WaitForChild("WeaponConfigs"))

local function prepareTemplate(def): boolean
	local template = WeaponCatalog.FindTemplate(def.id)
	if not template then
		return false
	end

	WeaponCatalog.PrepareTool(template, def.id)
	return true
end

local updated = 0
local missingDefs = {}

for _, def in ipairs(WeaponConfigs.GetAll()) do
	if prepareTemplate(def) then
		updated += 1
	else
		table.insert(missingDefs, def)
	end
end

if #missingDefs > 0 then
	local deadline = time() + 2
	repeat
		local stillMissing = {}
		for _, def in ipairs(missingDefs) do
			if prepareTemplate(def) then
				updated += 1
			else
				table.insert(stillMissing, def)
			end
		end

		missingDefs = stillMissing
		if #missingDefs == 0 then
			break
		end

		task.wait(0.1)
	until time() >= deadline
end

for _, def in ipairs(missingDefs) do
	warn("[WeaponTemplates] Missing template:", def.id)
end

print("[WeaponTemplates] Normalized weapon templates:", updated)
