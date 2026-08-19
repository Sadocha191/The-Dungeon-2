-- Installs all linked dungeon package templates before any gameplay Script is enabled.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local packagesRoot = script.Parent.Parent
local PACKAGE_ORDER = {
	"DungeonShared",
	"DungeonNPC",
	"DungeonCombat",
	"DungeonMovement",
	"DungeonRun",
}
local EXPECTED_SCHEMA_VERSION = 1

local pendingActivation = {}
local installedRoots = 0

local function sortedChildren(parent: Instance): {Instance}
	local children = parent:GetChildren()
	table.sort(children, function(a, b)
		if a.Name == b.Name then
			return a.ClassName < b.ClassName
		end
		return a.Name < b.Name
	end)
	return children
end

local function collectScripts(root: Instance)
	local all = { root }
	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(all, descendant)
	end
	for _, instance in ipairs(all) do
		if instance:IsA("BaseScript") then
			local runtimeDisabled = instance:GetAttribute("DungeonRuntimeDisabled") == true
			instance.Disabled = true
			table.insert(pendingActivation, {
				instance = instance,
				runtimeDisabled = runtimeDisabled,
			})
		end
	end
end

local function clearTemplateMetadata(root: Instance, packageName: string)
	root:SetAttribute("DungeonTemplateSourcePath", nil)
	root:SetAttribute("DungeonPackageOwner", packageName)
end

local function createDestinationContainer(template: Instance, destinationParent: Instance): Instance
	local desiredClass = template:GetAttribute("DungeonDestinationClass")
	assert(desiredClass == "Folder" or desiredClass == "Model",
		("[DungeonPackageBootstrap] cannot create missing %s (%s)"):format(template.Name, tostring(desiredClass)))
	local created = Instance.new(desiredClass)
	created.Name = template.Name
	created.Parent = destinationParent
	return created
end

local function installContainer(templateContainer: Instance, destinationParent: Instance, packageName: string)
	for _, template in ipairs(sortedChildren(templateContainer)) do
		if template:GetAttribute("DungeonTemplateContainer") == true then
			local destination = destinationParent:FindFirstChild(template.Name)
			if not destination then
				destination = createDestinationContainer(template, destinationParent)
			end
			local expectedClass = template:GetAttribute("DungeonDestinationClass")
			assert(expectedClass == "Service" or destination.ClassName == expectedClass,
				("[DungeonPackageBootstrap] destination class mismatch at %s: expected %s, got %s")
					:format(destination:GetFullName(), tostring(expectedClass), destination.ClassName))
			installContainer(template, destination, packageName)
		else
			assert(not destinationParent:FindFirstChild(template.Name),
				("[DungeonPackageBootstrap] destination collision at %s.%s")
					:format(destinationParent:GetFullName(), template.Name))
			local clone = template:Clone()
			collectScripts(clone)
			clearTemplateMetadata(clone, packageName)
			clone.Parent = destinationParent
			installedRoots += 1
		end
	end
end

for _, packageName in ipairs(PACKAGE_ORDER) do
	local packageRoot = packagesRoot:WaitForChild(packageName)
	assert(packageRoot:IsA("Model"), "[DungeonPackageBootstrap] package root must be a Model: " .. packageName)
	assert(packageRoot:GetAttribute("DungeonPackageReady") == true,
		"[DungeonPackageBootstrap] package root is not ready: " .. packageName)
	assert(packageRoot:GetAttribute("DungeonPackageSchemaVersion") == EXPECTED_SCHEMA_VERSION,
		"[DungeonPackageBootstrap] schema mismatch: " .. packageName)
	local templates = packageRoot:WaitForChild("Templates")
	for _, serviceTemplate in ipairs(sortedChildren(templates)) do
		assert(serviceTemplate:GetAttribute("DungeonTemplateContainer") == true,
			"[DungeonPackageBootstrap] unexpected Templates child: " .. serviceTemplate:GetFullName())
		local serviceName = serviceTemplate:GetAttribute("DungeonTemplateService")
		assert(typeof(serviceName) == "string" and serviceName ~= "",
			"[DungeonPackageBootstrap] missing service metadata: " .. serviceTemplate:GetFullName())
		installContainer(serviceTemplate, game:GetService(serviceName), packageName)
	end
end

local levelContext = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("DungeonLevelContext"))
ReplicatedStorage:SetAttribute("DungeonLevelKey", levelContext.GetLevelKey())
ReplicatedStorage:SetAttribute("DungeonPackageBootstrapVersion", EXPECTED_SCHEMA_VERSION)
ReplicatedStorage:SetAttribute("DungeonPackageBootstrapReady", true)

local function activationPriority(instance: BaseScript): number
	local fullName = instance:GetFullName()
	if string.find(fullName, "RunReadyGate", 1, true) then
		return 100
	end
	if instance:IsA("LocalScript") then
		return 80
	end
	if string.find(fullName, "ChestService", 1, true)
		or string.find(fullName, "ShrineService", 1, true)
		or string.find(fullName, "StatueService", 1, true)
		or string.find(fullName, "DropService", 1, true) then
		return 20
	end
	return 40
end

table.sort(pendingActivation, function(a, b)
	local aPriority = activationPriority(a.instance)
	local bPriority = activationPriority(b.instance)
	if aPriority == bPriority then
		return a.instance:GetFullName() < b.instance:GetFullName()
	end
	return aPriority < bPriority
end)

local enabledScripts = 0
for _, entry in ipairs(pendingActivation) do
	local instance = entry.instance
	instance:SetAttribute("DungeonRuntimeDisabled", nil)
	if not entry.runtimeDisabled then
		instance.Disabled = false
		enabledScripts += 1
	end
end

print(("[DungeonPackageBootstrap] Installed %d roots, enabled %d scripts for %s")
	:format(installedRoots, enabledScripts, levelContext.GetLevelKey()))
