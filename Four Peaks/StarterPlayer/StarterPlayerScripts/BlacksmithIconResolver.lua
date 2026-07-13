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
	local indexCache = {}
	local folderConnections = {}
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

	local function normalizeKey(value)
		if typeof(value) ~= "string" then
			return ""
		end
		return string.lower(value):gsub("[^%w]", "")
	end

	local function pushUnique(listRef, seen, value)
		local key = normalizeKey(value)
		if key == "" or seen[key] then
			return
		end
		seen[key] = true
		table.insert(listRef, value)
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

	local function disconnectFolderConnections(folderName)
		for _, connection in ipairs(folderConnections[folderName] or {}) do
			connection:Disconnect()
		end
		folderConnections[folderName] = nil
	end

	local function watchFolder(folderName, folder)
		disconnectFolderConnections(folderName)
		folderConnections[folderName] = {
			folder.DescendantAdded:Connect(function()
				indexCache[folderName] = nil
			end),
			folder.DescendantRemoving:Connect(function()
				indexCache[folderName] = nil
			end),
		}
	end

	local function cacheAsset(index, rawName, assetRef)
		local key = normalizeKey(rawName)
		if key ~= "" and not index[key] then
			index[key] = assetRef
		end
	end

	local function buildIconIndex(folderName)
		local folder = getFolder(folderName)
		if not folder then
			return nil
		end
		if indexCache[folderName] then
			return indexCache[folderName]
		end

		watchFolder(folderName, folder)
		local index = {}
		for _, object in ipairs(folder:GetDescendants()) do
			local assetRef = readAssetReference(object)
			if assetRef then
				cacheAsset(index, object.Name, assetRef)

				local ancestor = object.Parent
				while ancestor and ancestor ~= folder do
					cacheAsset(index, ancestor.Name, assetRef)
					ancestor = ancestor.Parent
				end
			end
		end
		indexCache[folderName] = index
		return index
	end

	local function resolveIconAsset(folderName, rawCandidates)
		local index = buildIconIndex(folderName)
		if not index then
			return nil
		end

		local seen = {}
		local candidates = {}
		for _, candidate in ipairs(rawCandidates or {}) do
			pushUnique(candidates, seen, candidate)
		end

		for _, candidate in ipairs(candidates) do
			local assetRef = index[normalizeKey(candidate)]
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
		indexCache.WeaponIcons = nil
		indexCache.ElementIcons = nil
		disconnectFolderConnections(WEAPON_ICON_FOLDER_NAME)
		disconnectFolderConnections(ELEMENT_ICON_FOLDER_NAME)
	end

	function resolver.ResolveWeaponIconAsset(weaponDef, weaponId, weaponType)
		if not weaponDef then
			return nil
		end

		local candidates = {}
		local seen = {}
		pushUnique(candidates, seen, weaponId)
		pushUnique(candidates, seen, weaponDef.id)
		pushUnique(candidates, seen, weaponDef.name)
		pushUnique(candidates, seen, weaponDef.weaponName)
		pushUnique(candidates, seen, weaponDef.displayName)
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
