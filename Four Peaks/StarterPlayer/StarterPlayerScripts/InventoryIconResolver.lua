local InventoryIconResolver = {}

function InventoryIconResolver.new(deps)
	deps = deps or {}
	local ReplicatedStorage = deps.ReplicatedStorage or game:GetService("ReplicatedStorage")
	local WeaponConfigs = deps.WeaponConfigs or {}
	local MaterialDefinitions = deps.MaterialDefinitions
	local imageFolderCache = {}
	local imageIndexCache = {}

	local function readImageReference(object)
		if not object then
			return nil
		end
		if object:IsA("StringValue") then
			return object.Value ~= "" and object.Value or nil
		elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
			return object.Image ~= "" and object.Image or nil
		elseif object:IsA("Decal") or object:IsA("Texture") then
			return object.Texture ~= "" and object.Texture or nil
		end
		return nil
	end

	local function buildImageIndex(folderName)
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if not folder then
			return nil
		end
		if imageFolderCache[folderName] == folder and imageIndexCache[folderName] then
			return imageIndexCache[folderName]
		end
		local index = {}
		for _, object in ipairs(folder:GetDescendants()) do
			local asset = readImageReference(object)
			if asset then
				local key = string.lower(object.Name)
				index[key] = index[key] or asset
				index[key:gsub("[%s_%-]", "")] = index[key:gsub("[%s_%-]", "")] or asset
			end
		end
		local direct = readImageReference(folder)
		if direct then
			index[string.lower(folder.Name)] = direct
		end
		imageFolderCache[folderName] = folder
		imageIndexCache[folderName] = index
		return index
	end

	local function resolveImage(folderName, candidates)
		local index = buildImageIndex(folderName)
		if not index then
			return nil
		end
		for _, raw in ipairs(candidates or {}) do
			if typeof(raw) == "string" and raw ~= "" then
				local key = string.lower(raw)
				local asset = index[key] or index[key:gsub("[%s_%-]", "")]
				if asset then
					return asset
				end
			end
		end
		return nil
	end

	local resolver = {}

	function resolver.WeaponImage(entry)
		local def = entry and entry.def or nil
		local candidates = {
			entry and entry.weaponId,
			entry and entry.displayName,
			def and def.iconName,
			def and def.name,
			def and def.id,
			def and def.categoryIconName,
		}
		for _, fallback in ipairs((def and def.iconFallbackNames) or {}) do
			table.insert(candidates, fallback)
		end
		return resolveImage("WeaponIcons", candidates)
	end

	function resolver.MaterialImage(entry)
		if MaterialDefinitions and MaterialDefinitions.GetAssetRef then
			local ok, asset = pcall(MaterialDefinitions.GetAssetRef, entry.id)
			if ok and typeof(asset) == "string" and asset ~= "" then
				return asset
			end
		end
		return resolveImage("MaterialIcons", { entry.id, entry.displayName, entry.iconName })
	end

	function resolver.SpellImage(entry)
		local direct = resolveImage("SpellIcons", {
			entry and entry.familyId,
			entry and entry.id,
			entry and entry.displayName,
			entry and entry.name,
			entry and entry.iconGlyph,
		})
		if direct then
			return direct
		end
		return resolveImage("ElementIcons", { entry and entry.element })
	end

	function resolver.CodexImage(entry)
		if not entry then
			return nil
		end
		local sourceId = entry.entryId or entry.id
		if entry.category == "Weapons" then
			return resolver.WeaponImage({
				weaponId = sourceId,
				displayName = entry.displayName,
				def = WeaponConfigs.Get and WeaponConfigs.Get(sourceId),
			})
		elseif entry.category == "Materials" then
			local copy = {}
			for key, value in pairs(entry) do
				copy[key] = value
			end
			copy.id = sourceId
			return resolver.MaterialImage(copy)
		elseif entry.category == "Spells" or entry.category == "Combinations" then
			return resolver.SpellImage(entry)
		end
		return resolveImage("CodexIcons", { entry.id, entry.displayName, entry.category })
	end

	return resolver
end

return InventoryIconResolver
