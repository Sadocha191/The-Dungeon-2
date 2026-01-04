-- WeaponTemplates.server.lua (ServerScriptService)
-- Ensures weapon templates have correct WeaponType metadata.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponTemplates = ServerStorage:WaitForChild("WeaponTemplates", 10)
if not WeaponTemplates then
	warn("[WeaponTemplates] Missing ServerStorage.WeaponTemplates")
	return
end

local moduleFolder = ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local weaponConfigsModule = (moduleFolder and moduleFolder:FindFirstChild("WeaponConfigs"))
	or ReplicatedStorage:FindFirstChild("WeaponConfigs")
local WeaponConfigs = weaponConfigsModule and require(weaponConfigsModule) or nil

if not WeaponConfigs or not WeaponConfigs.GetAll then
	warn("[WeaponTemplates] Missing WeaponConfigs module")
	return
end

local function findTemplate(name: string): Instance?
	return WeaponTemplates:FindFirstChild(name, true)
end

local function applyConfig(inst: Instance, def: any)
	if not inst or not def then return end
	inst:SetAttribute("WeaponId", def.id)
	inst:SetAttribute("WeaponType", def.weaponType or inst:GetAttribute("WeaponType") or "")

	local combat = def.combat or {}
	if inst:GetAttribute("BaseATK") == nil then
		inst:SetAttribute("BaseATK", combat.baseAtk or def.baseDamage or 0)
	end
	if inst:GetAttribute("ATKPerLevel") == nil then
		inst:SetAttribute("ATKPerLevel", combat.atkPerLevel or 0)
	end
end

local updated = 0
for _, def in ipairs(WeaponConfigs.GetAll()) do
	local template = findTemplate(def.id)
	if template then
		applyConfig(template, def)
		for _, desc in ipairs(template:GetDescendants()) do
			if desc:IsA("Tool") then
				applyConfig(desc, def)
			end
		end
		updated += 1
	else
		warn("[WeaponTemplates] Missing template:", def.id)
	end
end

print("[WeaponTemplates] Normalized weapon templates:", updated)
