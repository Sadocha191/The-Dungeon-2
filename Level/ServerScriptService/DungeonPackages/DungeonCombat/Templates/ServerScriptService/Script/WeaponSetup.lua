-- WeaponSetup.server.lua (ServerScriptService)
-- Validates authored weapon assets. Runtime placeholder geometry is intentionally not created.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponTemplates = ServerStorage:WaitForChild("WeaponTemplates", 10)
if not WeaponTemplates then
	warn("[WeaponSetup] Missing ServerStorage.WeaponTemplates")
	return
end

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
local weaponConfigsModule = moduleFolder and moduleFolder:FindFirstChild("WeaponConfigs")
local WeaponConfigs = weaponConfigsModule and require(weaponConfigsModule) or nil
if not WeaponConfigs or not WeaponConfigs.GetAll then
	warn("[WeaponSetup] Missing WeaponConfigs module")
	return
end

local function normalizeName(name: string): string
	local normalized = name:gsub("’", "'")
	normalized = normalized:gsub("%s+", " ")
	normalized = normalized:match("^%s*(.-)%s*$") or normalized
	return normalized:lower()
end

local authoredByName: {[string]: Instance} = {}
for _, instance in ipairs(WeaponTemplates:GetDescendants()) do
	if instance:IsA("Tool") or instance:IsA("Model") then
		local key = normalizeName(instance.Name)
		local existing = authoredByName[key]
		if not existing or (instance:IsA("Tool") and not existing:IsA("Tool")) then
			authoredByName[key] = instance
		end
	end
end

local found = 0
local missing = {}
for _, definition in ipairs(WeaponConfigs.GetAll()) do
	if authoredByName[normalizeName(definition.id)] then
		found += 1
	else
		table.insert(missing, definition.id)
	end
end

if #missing > 0 then
	warn("[WeaponSetup] Missing authored weapon templates:", table.concat(missing, ", "))
end
print("[WeaponSetup] Authored weapon templates ready:", found, "missing:", #missing)
