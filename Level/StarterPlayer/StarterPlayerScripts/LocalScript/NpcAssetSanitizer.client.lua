local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local NpcAssetSanitizer = require(moduleFolder:WaitForChild("NpcAssetSanitizer"))

local profiledTypes = {}
local watchedFolders = {}

local function profileModelOnce(model: Model, context: string)
	if not RunService:IsStudio() or not model.Parent then
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
			"[NpcAssetSanitizerClient] Heavy replicated NPC %s (%s): %s; limits hit: %s",
			typeName,
			context,
			NpcAssetSanitizer.DescribeProfile(profile),
			table.concat(reasons, ", ")
		))
	end
end

local function handleModel(model: Model, context: string)
	if model:GetAttribute(NpcAssetSanitizer.SANITIZED_ATTRIBUTE) ~= true then
		local removal, changed = NpcAssetSanitizer.SanitizeModel(model)
		if changed and RunService:IsStudio() then
			print(string.format(
				"[NpcAssetSanitizerClient] Removed %d late-replicated editor artifacts from %s",
				removal and removal.total or 0,
				NpcAssetSanitizer.GetTypeName(model)
			))
		end
	end

	if RunService:IsStudio() then
		task.defer(profileModelOnce, model, context)
	end
end

local function watchEnemiesFolder(folder: Folder)
	if watchedFolders[folder] then
		return
	end
	watchedFolders[folder] = true

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			handleModel(child, "existing")
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			handleModel(child, "added")
		end
	end)
end

local existingEnemiesFolder = workspace:FindFirstChild("Enemies")
if existingEnemiesFolder and existingEnemiesFolder:IsA("Folder") then
	watchEnemiesFolder(existingEnemiesFolder)
end
workspace.ChildAdded:Connect(function(child)
	if child.Name == "Enemies" and child:IsA("Folder") then
		watchEnemiesFolder(child)
	end
end)
