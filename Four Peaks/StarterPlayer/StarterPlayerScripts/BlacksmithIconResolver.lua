local BlacksmithIconResolver = {}

local WEAPON_ICON_FOLDER_NAME = "WeaponIcons"
local ELEMENT_ICON_FOLDER_NAME = "ElementIcons"
local CATEGORY_DEFAULT_ICONS = {
	Sword = "Knight's Oath",
	Scythe = "Reaper's Crescent",
	Halberd = "Warden's Halberd",
	Bow = "Hunter's Longbow",
	Staff = "Apprentice Arcstaff",
	Pistol = "Blackpowder Flintlock",
}
local CURLY_APOSTROPHE = utf8.char(8217)

function BlacksmithIconResolver.NormalizeElementName(element)
	local value = tostring(element or "")
	if value == "Electricity" then
		return "Electric"
	end
	if value == "" then
		return "Physical"
	end
	return value
end

function BlacksmithIconResolver.new(deps)
	deps = deps or {}
	local ReplicatedStorage = deps.ReplicatedStorage or game:GetService("ReplicatedStorage")
	local folderCache = {
		WeaponIcons = nil,
		ElementIcons = nil,
	}
	local missingWeaponIconWarnings = {}
	local missingElementIconWarnings = {}

	local function readAssetReference(iconObject)
		if not iconObject then
			return nil
		end

		local value = nil
		if iconObject:IsA("StringValue") then
			value = iconObject.Value
		elseif iconObject:IsA("ImageLabel") or iconObject:IsA("ImageButton") then
			value = iconObject.Image
		elseif iconObject:IsA("Decal") or iconObject:IsA("Texture") then
			value = iconObject.Texture
		end

		if typeof(value) == "string" and value ~= "" then
			return value
		end
		return nil
	end

	local function pushUnique(listRef, seen, value)
		if typeof(value) ~= "string" or value == "" or seen[value] then
			return
		end
		seen[value] = true
		table.insert(listRef, value)
	end

	local function buildTypographyVariants(value)
		local variants = {}
		local seen = {}

		local function push(valueToPush)
			pushUnique(variants, seen, valueToPush)
		end

		push(value)
		if typeof(value) ~= "string" or value == "" then
			return variants
		end

		push(value:gsub("'", CURLY_APOSTROPHE))
		push(value:gsub(CURLY_APOSTROPHE, "'"))

		return variants
	end

	local function getFolder(folderName)
		local cached = folderCache[folderName]
		if cached and cached.Parent then
			return cached
		end
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		folderCache[folderName] = folder
		return folder
	end

	local function resolveIconAsset(folderName, rawCandidates)
		local folder = getFolder(folderName)
		if not folder then
			return nil
		end

		local seen = {}
		local candidates = {}
		for _, candidate in ipairs(rawCandidates or {}) do
			for _, variant in ipairs(buildTypographyVariants(candidate)) do
				pushUnique(candidates, seen, variant)
			end
		end

		for _, candidate in ipairs(candidates) do
			local iconObject = folder:FindFirstChild(candidate)
			local assetRef = readAssetReference(iconObject)
			if assetRef then
				return assetRef
			end
		end

		return nil
	end

	local resolver = {}

	function resolver.ResetFolderCache()
		folderCache.WeaponIcons = nil
		folderCache.ElementIcons = nil
	end

	function resolver.ResolveWeaponIconAsset(weaponDef, weaponId, weaponType)
		if not weaponDef then
			return nil
		end

		local candidates = {}
		local seen = {}
		pushUnique(candidates, seen, weaponDef.iconName)
		for _, fallbackName in ipairs(weaponDef.iconFallbackNames or {}) do
			pushUnique(candidates, seen, fallbackName)
		end
		pushUnique(candidates, seen, weaponDef.categoryIconName)
		pushUnique(candidates, seen, CATEGORY_DEFAULT_ICONS[tostring(weaponType or weaponDef.weaponType or "")])

		local assetRef = resolveIconAsset(WEAPON_ICON_FOLDER_NAME, candidates)
		if assetRef then
			missingWeaponIconWarnings[weaponId] = nil
			return assetRef
		end

		if weaponId and not missingWeaponIconWarnings[weaponId] then
			warn("Missing weapon icon:", weaponId, tostring(weaponDef.iconName or ""))
			missingWeaponIconWarnings[weaponId] = true
		end

		return nil
	end

	function resolver.ResolveElementIconAsset(elementName)
		local normalizedElement = BlacksmithIconResolver.NormalizeElementName(elementName)
		local assetRef = resolveIconAsset(ELEMENT_ICON_FOLDER_NAME, { normalizedElement })
		if assetRef then
			missingElementIconWarnings[normalizedElement] = nil
			return assetRef
		end

		if not missingElementIconWarnings[normalizedElement] then
			warn("Missing element icon:", normalizedElement)
			missingElementIconWarnings[normalizedElement] = true
		end

		return nil
	end

	return resolver
end

return BlacksmithIconResolver
