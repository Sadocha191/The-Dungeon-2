local ReplicatedStorage = game:GetService("ReplicatedStorage")

local moduleRoot = script.Parent
local SpellDefs = require(moduleRoot:WaitForChild("SpellDefinitions"))

local function safeRequire(name)
	local mod = moduleRoot:FindFirstChild(name)
	if not mod and ReplicatedStorage:FindFirstChild("ModuleScript") then
		mod = ReplicatedStorage.ModuleScript:FindFirstChild(name)
	end
	if not mod or not mod:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, mod)
	return ok and result or nil
end

local WeaponConfigs = safeRequire("WeaponConfigs")
local CraftingConfig = safeRequire("CraftingConfig")

local CodexDefinitions = {}

CodexDefinitions.CATEGORY_ORDER = {
	"Spells",
	"Combinations",
	"Enemies",
	"Elites",
	"Bosses",
	"Weapons",
	"Materials",
}

local CATEGORY_LABELS = {
	Spells = "Spells",
	Combinations = "Combinations",
	Enemies = "Enemies",
	Elites = "Elites",
	Bosses = "Bosses",
	Weapons = "Weapons",
	Materials = "Materials",
}

local entriesByCategory = nil
local entriesByKey = nil

local function formatName(id)
	return tostring(id or "Unknown"):gsub("_", " ")
end

local function cloneEntry(entry)
	local out = {}
	for key, value in pairs(entry or {}) do
		if typeof(value) == "table" then
			local nested = {}
			for k, v in pairs(value) do
				nested[k] = v
			end
			out[key] = nested
		else
			out[key] = value
		end
	end
	return out
end

local function addEntry(category, id, entry)
	if typeof(id) ~= "string" or id == "" then
		return
	end
	entriesByCategory[category] = entriesByCategory[category] or {}
	local clean = cloneEntry(entry)
	clean.id = id
	clean.category = category
	clean.stableId = ("%s:%s"):format(category, id)
	clean.displayName = clean.displayName or formatName(id)
	clean.description = clean.description or ""
	clean.iconText = clean.iconText or string.upper(string.sub(clean.displayName, 1, 1))
	table.insert(entriesByCategory[category], clean)
	entriesByKey[clean.stableId] = clean
end

local function build()
	entriesByCategory = {}
	entriesByKey = {}
	for _, category in ipairs(CodexDefinitions.CATEGORY_ORDER) do
		entriesByCategory[category] = {}
	end

	for _, spellId in ipairs(SpellDefs.GetSpellIds()) do
		local def = SpellDefs.GetSpell(spellId)
		if def and not def.isCombo then
			local presentation = SpellDefs.GetPresentation(def)
			addEntry("Spells", spellId, {
				displayName = def.name,
				description = def.loreDescription or def.description,
				element = def.element,
				rarity = def.spellType or "Spell",
				tags = { def.spellType, def.element, def.attackType, def.codexCategory },
				iconText = def.iconGlyph,
				artMotif = def.artMotif,
				loreDescription = def.loreDescription,
				gameplayDescription = def.gameplayDescription,
				visualDirection = def.visualDirection,
				frameStyle = def.frameStyle,
				witchbookAccent = def.witchbookAccent,
				presentation = presentation,
			})
		end
	end

	for _, combo in ipairs(SpellDefs.GetCombinationList()) do
		local result = SpellDefs.GetSpell(combo.resultId)
		local presentation = result and SpellDefs.GetPresentation(result) or {}
		addEntry("Combinations", combo.id, {
			displayName = result and result.name or combo.id,
			description = result and (result.loreDescription or result.description) or SpellDefs.DescribeCombination(combo),
			element = result and result.element or nil,
			rarity = "Combination",
			tags = combo.ingredients,
			iconText = result and result.iconGlyph or presentation.iconGlyph,
			artMotif = result and result.artMotif or presentation.artMotif,
			loreDescription = result and result.loreDescription or presentation.loreDescription,
			gameplayDescription = result and result.gameplayDescription or presentation.gameplayDescription,
			visualDirection = result and result.visualDirection or presentation.visualDirection,
			frameStyle = result and result.frameStyle or presentation.frameStyle,
			witchbookAccent = result and result.witchbookAccent or presentation.witchbookAccent,
			presentation = presentation,
			hiddenDetailsUntilDiscovered = SpellDefs.CODEX_HIDE_UNDISCOVERED_COMBO_DETAILS == true,
			resultId = combo.resultId,
			ingredients = combo.ingredients,
		})
	end

	if WeaponConfigs and WeaponConfigs.GetAll then
		for _, def in ipairs(WeaponConfigs.GetAll()) do
			local id = def.id or def.weaponId or def.name
			addEntry("Weapons", id, {
				displayName = def.name or def.displayName or id,
				description = def.description or def.passiveDescription or def.abilityDescription or "",
				rarity = def.rarity or "Weapon",
				tags = { def.weaponType, def.element },
			})
		end
	end

	if CraftingConfig then
		for _, def in ipairs(CraftingConfig.MOB_MATERIAL_DEFS or {}) do
			local mobType = def.mobType
			if typeof(mobType) == "string" and mobType ~= "" then
				addEntry("Enemies", mobType, {
					displayName = formatName(mobType),
					description = ("Encountered in runs. Drops %s."):format(def.id or "materials"),
					rarity = "Enemy",
					tags = { def.id },
				})
				addEntry("Elites", mobType, {
					displayName = ("%s Elite"):format(formatName(mobType)),
					description = ("Elite encounter variant of %s."):format(formatName(mobType)),
					rarity = "Elite",
					tags = { def.id, "Elite" },
				})
				addEntry("Bosses", mobType, {
					displayName = ("%s Boss"):format(formatName(mobType)),
					description = ("Boss encounter variant of %s."):format(formatName(mobType)),
					rarity = "Boss",
					tags = { def.id, "Boss" },
				})
			end
		end

		local materialsSeen = {}
		local function addMaterial(id, def)
			if typeof(id) ~= "string" or id == "" or materialsSeen[id] then
				return
			end
			materialsSeen[id] = true
			addEntry("Materials", id, {
				displayName = def and (def.displayName or def.name or def.id) or id,
				description = def and (def.description or def.tone or "") or "",
				rarity = def and def.rarity or "Material",
				tags = { def and def.bucket or nil },
			})
		end

		if CraftingConfig.GetAllMaterials then
			for _, def in ipairs(CraftingConfig.GetAllMaterials()) do
				addMaterial(def.id, def)
			end
		else
			for _, def in ipairs(CraftingConfig.MINE_RESOURCE_DEFS or {}) do
				addMaterial(def.id, def)
			end
			for _, def in ipairs(CraftingConfig.MOB_MATERIAL_DEFS or {}) do
				addMaterial(def.id, def)
			end
		end
		addMaterial(CraftingConfig.UPGRADE_CRYSTAL_ID or "Upgrade Crystal", { rarity = "Rare" })
		addMaterial(CraftingConfig.ELITE_SPECIAL_ID or "Elite Sigil", { rarity = "Epic" })
		addMaterial(CraftingConfig.BOSS_SPECIAL_ID or "Boss Core", { rarity = "Legendary" })
	end

	for _, category in ipairs(CodexDefinitions.CATEGORY_ORDER) do
		table.sort(entriesByCategory[category], function(a, b)
			return tostring(a.displayName) < tostring(b.displayName)
		end)
	end
end

local function ensureBuilt()
	if not entriesByCategory then
		build()
	end
end

function CodexDefinitions.NormalizeCategory(category)
	category = tostring(category or "")
	for _, known in ipairs(CodexDefinitions.CATEGORY_ORDER) do
		if string.lower(known) == string.lower(category) then
			return known
		end
	end
	return nil
end

function CodexDefinitions.GetCategoryOrder()
	local out = {}
	for _, category in ipairs(CodexDefinitions.CATEGORY_ORDER) do
		table.insert(out, category)
	end
	return out
end

function CodexDefinitions.GetCategoryLabel(category)
	return CATEGORY_LABELS[category] or tostring(category or "")
end

function CodexDefinitions.GetEntriesForCategory(category)
	ensureBuilt()
	category = CodexDefinitions.NormalizeCategory(category)
	if not category then
		return {}
	end
	local out = {}
	for _, entry in ipairs(entriesByCategory[category] or {}) do
		table.insert(out, cloneEntry(entry))
	end
	return out
end

function CodexDefinitions.GetEntries()
	ensureBuilt()
	local out = {}
	for _, category in ipairs(CodexDefinitions.CATEGORY_ORDER) do
		for _, entry in ipairs(entriesByCategory[category] or {}) do
			table.insert(out, cloneEntry(entry))
		end
	end
	return out
end

function CodexDefinitions.GetEntry(category, id)
	ensureBuilt()
	category = CodexDefinitions.NormalizeCategory(category)
	if not category or typeof(id) ~= "string" or id == "" then
		return nil
	end
	local entry = entriesByKey[("%s:%s"):format(category, id)]
	return entry and cloneEntry(entry) or nil
end

return CodexDefinitions
