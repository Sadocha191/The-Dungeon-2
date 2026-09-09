local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
local NpcAssetSanitizer = require(moduleFolder:WaitForChild("NpcAssetSanitizer"))

local profiledTypes = {}
local watchedCategories = {}

local function profileTemplateOnce(model: Model, context: string)
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
			"[NpcAssetSanitizerClient] Heavy replicated NPC template %s (%s): %s; limits hit: %s",
			typeName,
			context,
			NpcAssetSanitizer.DescribeProfile(profile),
			table.concat(reasons, ", ")
		))
	end
end

local function sanitizeModel(model: Model, context: string)
	if model:GetAttribute(NpcAssetSanitizer.SANITIZED_ATTRIBUTE) ~= true then
		local removal, changed = NpcAssetSanitizer.SanitizeModel(model)
		if changed and RunService:IsStudio() then
			print(string.format(
				"[NpcAssetSanitizerClient] Removed %d late-replicated editor artifacts from %s (%s)",
				removal and removal.total or 0,
				NpcAssetSanitizer.GetTypeName(model),
				context
			))
		end
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
