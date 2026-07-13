local InventoryIconResolver = {}

function InventoryIconResolver.new(deps)
	deps = deps or {}
	local ReplicatedStorage = deps.ReplicatedStorage or game:GetService("ReplicatedStorage")
	local WeaponConfigs = deps.WeaponConfigs or {}
	local MaterialDefinitions = deps.MaterialDefinitions
	local imageFolderCache = {}
	local imageIndexCache = {}
	local imageFolderConnections = {}

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

	local function normalizeKey(value)
		if typeof(value) ~= "string" then
			return ""
		end
		return string.lower(value):gsub("[^%w]", "")
	end

	local function cacheAsset(index, rawName, asset)
		local key = normalizeKey(rawName)
		if key ~= "" and not index[key] then
			index[key] = asset
		end
	end

	local function disconnectFolderConnections(folderName)
		local connections = imageFolderConnections[folderName]
		if not connections then
			return
		end
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		imageFolderConnections[folderName] = nil
	end

	local function watchFolder(folderName, folder)
		disconnectFolderConnections(folderName)
		imageFolderConnections[folderName] = {
			folder.DescendantAdded:Connect(function()
				imageIndexCache[folderName] = nil
			end),
			folder.DescendantRemoving:Connect(function()
				imageIndexCache[folderName] = nil
			end),
		}
	end

	local function buildImageIndex(folderName)
		local folder = ReplicatedStorage:FindFirstChild(folderName)
		if not folder then
			return nil
		end
		if imageFolderCache[folderName] == folder and imageIndexCache[folderName] then
			return imageIndexCache[folderName]
		end

		if imageFolderCache[folderName] ~= folder then
			imageFolderCache[folderName] = folder
			watchFolder(folderName, folder)
		end

		local index = {}
		for _, object in ipairs(folder:GetDescendants()) do
			local asset = readImageReference(object)
			if asset then
				cacheAsset(index, object.Name, asset)

				local ancestor = object.Parent
				while ancestor and ancestor ~= folder do
					cacheAsset(index, ancestor.Name, asset)
					ancestor = ancestor.Parent
				end
			end
		end
		local direct = readImageReference(folder)
		if direct then
			cacheAsset(index, folder.Name, direct)
		end
		imageIndexCache[folderName] = index
		return index
	end

	local function resolveImage(folderName, candidates)
		local index = buildImageIndex(folderName)
		if not index then
			return nil
		end
		for _, raw in ipairs(candidates or {}) do
			local key = normalizeKey(raw)
			if key ~= "" and index[key] then
				return index[key]
			end
		end
		return nil
	end

	local function appendCandidate(candidates, value)
		if typeof(value) == "string" and value ~= "" then
			table.insert(candidates, value)
		end
	end

	local resolver = {}

	function resolver.WeaponImage(entry)
		local def = entry and entry.def or nil
		local candidates = {}
		appendCandidate(candidates, entry and entry.weaponId)
		appendCandidate(candidates, entry and entry.id)
		appendCandidate(candidates, entry and entry.displayName)
		appendCandidate(candidates, entry and entry.name)
		appendCandidate(candidates, def and def.iconName)
		appendCandidate(candidates, def and def.id)
		appendCandidate(candidates, def and def.name)
		appendCandidate(candidates, def and def.weaponName)
		appendCandidate(candidates, def and def.displayName)
		for _, fallback in ipairs((def and def.iconFallbackNames) or {}) do
			appendCandidate(candidates, fallback)
		end
		appendCandidate(candidates, def and def.categoryIconName)
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
				name = entry.name,
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
