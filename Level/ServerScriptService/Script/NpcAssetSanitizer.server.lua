local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:WaitForChild("ModuleScripts")
local NpcAssetSanitizer = require(moduleFolder:WaitForChild("NpcAssetSanitizer"))

local profiledTypes = {}
local watchedCategories = {}
local watchedRuntimeFolders = {}

local function profileTemplateOnce(model: Model, context: string)
	if not RunService:IsStudio() then
		return
	end

	local typeName = NpcAssetSanitizer.GetTypeName(model)
	if profiledTypes[typeName] then
		return
	end
	profiledTypes[typeName] = true

	local profile = NpcAssetSanitizer.ProfileModel(model)
	local isHeavy, reasons = NpcAssetSanitizer.IsHeavyProfile(profile)
	if isHeavy then
		warn(string.format(
			"[NpcAssetSanitizer] Heavy NPC asset %s (%s): %s; limits hit: %s",
			typeName,
			context,
			NpcAssetSanitizer.DescribeProfile(profile),
			table.concat(reasons, ", ")
		))
	end
end

local function sanitizeModel(model: Model, context: string)
	local removal, changed = NpcAssetSanitizer.SanitizeModel(model)
	if changed and RunService:IsStudio() then
		print(string.format(
			"[NpcAssetSanitizer] Removed %d editor artifacts from %s (%s)",
			removal and removal.total or 0,
			NpcAssetSanitizer.GetTypeName(model),
			context
		))
	end
	profileTemplateOnce(model, context)
end

local function watchTemplateCategory(category: Instance)
	if watchedCategories[category] then
		return
	end
	if not category:IsA("Folder") then
		if category:IsA("Model") then
			sanitizeModel(category, "template")
		end
		return
	end

	watchedCategories[category] = true
	for _, child in ipairs(category:GetChildren()) do
		if child:IsA("Model") then
			sanitizeModel(child, "template")
		end
	end
	category.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			sanitizeModel(child, "template-added")
		end
	end)
end

local enemiesRoot = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Enemies")
for _, category in ipairs(enemiesRoot:GetChildren()) do
	watchTemplateCategory(category)
end
enemiesRoot.ChildAdded:Connect(watchTemplateCategory)

local function watchRuntimeFolder(folder: Folder)
	if watchedRuntimeFolders[folder] then
		return
	end
	watchedRuntimeFolders[folder] = true

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			sanitizeModel(child, "runtime-existing")
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			sanitizeModel(child, "runtime-added")
		end
	end)
end

local existingRuntimeFolder = workspace:FindFirstChild("Enemies")
if existingRuntimeFolder and existingRuntimeFolder:IsA("Folder") then
	watchRuntimeFolder(existingRuntimeFolder)
end
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Enemies" and child:IsA("Folder") then
		watchRuntimeFolder(child)
	end
end)

print("[NpcAssetSanitizer] Ready")
