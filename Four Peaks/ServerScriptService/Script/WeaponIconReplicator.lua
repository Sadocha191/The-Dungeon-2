local ReplicatedStorage = game:GetService("ReplicatedStorage")

local moduleRoot = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local WeaponConfigs = require(moduleRoot:WaitForChild("WeaponConfigs"))

local IMAGE_CATEGORY = "Images"
local ELEMENT_ICON_NAMES = {
	"Air",
	"Earth",
	"Electric",
	"Fire",
	"Light",
	"Physical",
	"Void",
	"Water",
}

local function buildAssetReference(iconName)
	return string.format("rbxgameasset://%s/%s", IMAGE_CATEGORY, tostring(iconName))
end

local function ensureFolder(folderName)
	local folder = ReplicatedStorage:FindFirstChild(folderName)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder and not folder:IsA("Folder") then
		warn(("[WeaponIconReplicator] %s exists but is not a Folder"):format(folderName))
		return nil
	end
	folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = ReplicatedStorage
	return folder
end

local function ensureStringValue(folder, valueName, defaultValue)
	if not folder or typeof(valueName) ~= "string" or valueName == "" then
		return false
	end

	local existing = folder:FindFirstChild(valueName)
	if existing and not existing:IsA("StringValue") then
		warn(("[WeaponIconReplicator] %s.%s exists but is not a StringValue"):format(folder.Name, valueName))
		return false
	end

	if not existing then
		existing = Instance.new("StringValue")
		existing.Name = valueName
		existing.Value = defaultValue
		existing.Parent = folder
		return true
	end

	if existing.Value == "" and typeof(defaultValue) == "string" and defaultValue ~= "" then
		existing.Value = defaultValue
		return true
	end

	return false
end

local function collectWeaponIconNames()
	local names = {}
	local seen = {}

	local function push(value)
		if typeof(value) ~= "string" or value == "" or seen[value] then
			return
		end
		seen[value] = true
		table.insert(names, value)
	end

	for _, def in ipairs(WeaponConfigs.GetAll()) do
		push(def.iconName)
		push(def.categoryIconName)
		for _, fallbackName in ipairs(def.iconFallbackNames or {}) do
			push(fallbackName)
		end
	end

	return names
end

local function ensureWeaponIcons()
	local folder = ensureFolder("WeaponIcons")
	local created = 0
	for _, iconName in ipairs(collectWeaponIconNames()) do
		if ensureStringValue(folder, iconName, buildAssetReference(iconName)) then
			created += 1
		end
	end
	return created
end

local function ensureElementIcons()
	local folder = ensureFolder("ElementIcons")
	local created = 0
	for _, iconName in ipairs(ELEMENT_ICON_NAMES) do
		if ensureStringValue(folder, iconName, buildAssetReference(iconName)) then
			created += 1
		end
	end
	return created
end

local function ensureMaterialIcons()
	local folder = ensureFolder("MaterialIcons")
	if not folder then
		return 0
	end

	local created = 0
	for index = 1, 48 do
		local iconName = string.format("Material_%02d", index)
		if ensureStringValue(folder, iconName, buildAssetReference(iconName)) then
			created += 1
		end
	end

	if ensureStringValue(folder, "materials_icon", buildAssetReference("materials_icon")) then
		created += 1
	end

	return created
end

local weaponCount = ensureWeaponIcons()
local elementCount = ensureElementIcons()
local materialCount = ensureMaterialIcons()

print(
	("[WeaponIconReplicator] Ensured icon contracts (WeaponIcons +%d, ElementIcons +%d, MaterialIcons +%d)")
		:format(weaponCount, elementCount, materialCount)
)
