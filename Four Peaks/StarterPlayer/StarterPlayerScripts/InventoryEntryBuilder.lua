local InventoryEntryBuilder = {}

function InventoryEntryBuilder.new(deps)
	deps = deps or {}
	local WeaponConfigs = deps.WeaponConfigs or { Defs = {}, List = {} }
	local SpellDefs = deps.SpellDefs or {}
	local CraftingConfig = deps.CraftingConfig or {}
	local MaterialDefinitions = deps.MaterialDefinitions

	local materialUses = {}
	for _, recipe in ipairs(CraftingConfig.Recipes or {}) do
		for _, requirement in ipairs(recipe.materials or {}) do
			local id = requirement.id
			if typeof(id) == "string" and id ~= "" then
				materialUses[id] = materialUses[id] or {}
				table.insert(materialUses[id], recipe.weaponId or recipe.recipeId or "Unknown recipe")
			end
		end
	end
	materialUses[CraftingConfig.UPGRADE_CRYSTAL_ID or "Upgrade Crystal"] = { "Weapon upgrades" }
	materialUses[CraftingConfig.ELITE_SPECIAL_ID or "Elite Sigil"] = { "High-level weapon upgrades" }
	materialUses[CraftingConfig.BOSS_SPECIAL_ID or "Boss Core"] = { "Endgame weapon upgrades" }

	local function getWeaponDef(id)
		return WeaponConfigs.Get and WeaponConfigs.Get(id) or (WeaponConfigs.Defs and WeaponConfigs.Defs[id])
	end

	local function getMaterialDefinition(id)
		if MaterialDefinitions and MaterialDefinitions.Get then
			local ok, def = pcall(MaterialDefinitions.Get, id)
			if ok and def then return def end
		end
		if CraftingConfig.GetMaterialDefinition then
			local ok, def = pcall(CraftingConfig.GetMaterialDefinition, id)
			if ok and def then return def end
		end
		return (CraftingConfig.MaterialDefsById and CraftingConfig.MaterialDefsById[id])
			or (CraftingConfig.MineResourcesById and CraftingConfig.MineResourcesById[id])
			or (CraftingConfig.MobMaterialsById and CraftingConfig.MobMaterialsById[id])
	end

	local function addMaterialEntries(out, raw, bucket, sourceLabel)
		for _, entry in ipairs(raw or {}) do
			local id = entry.id
			if typeof(id) == "string" and id ~= "" then
				local def = getMaterialDefinition(id) or {}
				table.insert(out, {
					id = id,
					displayName = def.displayName or def.name or id,
					amount = math.max(0, math.floor(tonumber(entry.amount) or 0)),
					rarity = def.rarity or entry.rarity or "Common",
					bucket = bucket,
					sourceLabel = sourceLabel,
					description = def.description or def.tone or "A crafting material gathered during progression.",
					source = def.source or sourceLabel,
					iconName = def.iconName,
					usedFor = materialUses[id] or {},
				})
			end
		end
	end

	local builder = {}

	function builder.BuildWeaponEntries(raw)
		local out = {}
		for _, entry in ipairs(raw or {}) do
			local instanceId = entry.InstanceId or entry.instanceId or entry.id
			local weaponId = entry.WeaponId or entry.weaponId or entry.weapon
			if typeof(instanceId) == "string" and instanceId ~= "" and typeof(weaponId) == "string" and weaponId ~= "" then
				local def = getWeaponDef(weaponId)
				local prefix = tostring(entry.Prefix or entry.prefix or "Standard")
				local baseName = (def and (def.name or def.displayName)) or weaponId
				local displayName = prefix ~= "Standard" and (prefix .. " " .. baseName) or baseName
				table.insert(out, {
					id = instanceId,
					weaponId = weaponId,
					displayName = displayName,
					prefix = prefix,
					def = def,
					rarity = entry.Rarity or entry.rarity or (def and def.rarity) or "Common",
					level = tonumber(entry.Level or entry.level) or 1,
					maxLevel = tonumber(entry.MaxLevel or entry.maxLevel) or (def and def.maxLevel) or 1,
					stats = entry.Stats or entry.stats or {},
					favorite = entry.Favorite == true or entry.favorite == true,
					sellValue = tonumber(entry.SellValue or entry.sellValue) or (def and tonumber(def.sellValue)) or 0,
					weaponType = entry.WeaponType or entry.weaponType or (def and def.weaponType) or "Weapon",
					element = entry.Element or entry.element or (def and def.element) or "Physical",
					description = entry.Description or (def and def.description) or "",
				})
			end
		end
		return out
	end

	function builder.BuildSpellEntries(raw, spellsSnapshot)
		local byFamily = {}
		local loadoutFamilyOrder = {}
		for index, productId in ipairs((spellsSnapshot and spellsSnapshot.loadout) or {}) do
			local product = SpellDefs.GetProduct and SpellDefs.GetProduct(productId)
			local familyId = product and product.familyId or (SpellDefs.ProductToSpellId and SpellDefs.ProductToSpellId(productId)) or productId
			loadoutFamilyOrder[familyId] = index
		end

		for _, entry in ipairs(raw or {}) do
			local familyId = entry.familyId or (SpellDefs.ProductToSpellId and SpellDefs.ProductToSpellId(entry.productId or entry.id)) or entry.id
			if typeof(familyId) == "string" and familyId ~= "" then
				local def = SpellDefs.GetSpell and SpellDefs.GetSpell(familyId) or nil
				local candidate = {
					id = familyId,
					familyId = familyId,
					productId = entry.productId or entry.id,
					displayName = (def and def.name) or entry.name or entry.displayName or familyId,
					name = (def and def.name) or entry.name or familyId,
					element = entry.element or (def and def.element) or "Physical",
					attackType = entry.attackType or (def and def.attackType) or "Spell",
					spellType = entry.spellType or (def and def.spellType) or "Magic",
					rarity = entry.rarity or "Common",
					unlocked = entry.unlocked == true,
					equipped = loadoutFamilyOrder[familyId] ~= nil or entry.equipped == true,
					loadoutIndex = loadoutFamilyOrder[familyId],
					description = entry.gameplayDescription or entry.description or (def and def.gameplayDescription) or "",
					loreDescription = entry.loreDescription or (def and def.loreDescription) or "",
					gameplayDescription = entry.gameplayDescription or (def and def.gameplayDescription) or entry.description or "",
					visualDirection = entry.visualDirection or (def and def.visualDirection) or "",
					iconGlyph = entry.iconGlyph or (def and def.iconGlyph) or string.upper(string.sub(familyId, 1, 2)),
					statLines = entry.statLines or {},
					upgradeLevels = entry.upgradeLevels or {},
					combinations = entry.combinations or {},
					def = def,
				}
				local current = byFamily[familyId]
				if not current
					or (candidate.equipped and not current.equipped)
					or (candidate.unlocked and not current.unlocked)
				then
					byFamily[familyId] = candidate
				end
			end
		end

		local out = {}
		for _, entry in pairs(byFamily) do
			table.insert(out, entry)
		end
		return out
	end

	function builder.BuildMaterialEntries(resources)
		resources = resources or {}
		local out = {}
		addMaterialEntries(out, resources.mineResources, "Mine", "Mining")
		addMaterialEntries(out, resources.mobMaterials, "Monster", "Monster drops")
		addMaterialEntries(out, resources.upgradeMaterials, "Forge", "Forge progression")
		return out
	end

	function builder.BuildCodexEntries(raw)
		local out = {}
		for _, entry in ipairs(raw or {}) do
			local clean = {}
			for key, value in pairs(entry) do clean[key] = value end
			clean.id = clean.stableId or ((clean.category or "Codex") .. ":" .. tostring(clean.id or clean.displayName))
			clean.entryId = entry.id
			clean.displayName = clean.displayName or clean.name or tostring(entry.id or "Unknown")
			clean.rarity = clean.rarity or "Codex"
			clean.discovered = clean.discovered == true
			clean.iconGlyph = clean.iconText or clean.iconGlyph or string.upper(string.sub(clean.displayName, 1, 1))
			table.insert(out, clean)
		end
		return out
	end

	return builder
end

return InventoryEntryBuilder
