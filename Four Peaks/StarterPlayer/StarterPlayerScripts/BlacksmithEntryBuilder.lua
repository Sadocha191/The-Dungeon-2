local BlacksmithEntryBuilder = {}

function BlacksmithEntryBuilder.new(deps)
	deps = deps or {}
	local weaponConfigs = deps.WeaponConfigs
	local clampInt = deps.ClampInt or function(value, minValue)
		value = math.floor(tonumber(value) or 0)
		if minValue ~= nil and value < minValue then
			return minValue
		end
		return value
	end

	local builder = {}

	local function getWeaponDef(weaponId)
		if weaponConfigs and weaponConfigs.Get then
			return weaponConfigs.Get(weaponId)
		end
		return nil
	end

	function builder.BuildEntriesByCategory(craftEntries, categoryOrder)
		local byCategory = {}
		for _, category in ipairs(categoryOrder or {}) do
			byCategory[category] = {}
		end

		for _, entry in ipairs(craftEntries or {}) do
			local weaponDef = getWeaponDef(entry.weaponId)
			local category = tostring(entry.weaponType or (weaponDef and weaponDef.weaponType) or "")
			if byCategory[category] then
				table.insert(byCategory[category], entry)
			end
		end

		return byCategory
	end

	function builder.ResolveSelectedCategory(byCategory, selectedCategory, categoryOrder)
		if byCategory[selectedCategory] and #byCategory[selectedCategory] > 0 then
			return selectedCategory
		end

		for _, category in ipairs(categoryOrder or {}) do
			if byCategory[category] and #byCategory[category] > 0 then
				return category
			end
		end

		return selectedCategory
	end

	function builder.GetSelectedEntry(entries, selectedRecipeId)
		for _, entry in ipairs(entries or {}) do
			if entry.recipeId == selectedRecipeId then
				return entry, selectedRecipeId
			end
		end
		if entries and entries[1] then
			return entries[1], entries[1].recipeId
		end
		return nil, selectedRecipeId
	end

	function builder.GetWeaponDisplayName(weaponDef, entry)
		local value = (weaponDef and (weaponDef.weaponName or weaponDef.name or weaponDef.displayName)) or (entry and (entry.name or entry.weaponId)) or ""
		return tostring(value)
	end

	function builder.GetWeaponTypeLabel(weaponDef, entry, normalizedElement)
		local value = weaponDef and weaponDef.weaponTypeLabel or nil
		if typeof(value) == "string" and value ~= "" then
			return value
		end

		local category = (weaponDef and (weaponDef.category or weaponDef.weaponType)) or (entry and entry.weaponType) or ""
		category = tostring(category or "")
		if category == "" then
			return tostring(normalizedElement or "")
		end

		return string.format("%s %s", tostring(normalizedElement or ""), category)
	end

	function builder.BuildStatLines(weaponDef)
		local lines = {}
		if not weaponDef then
			return { "-", "-", "-", "-" }
		end

		local stats = weaponDef.stats or {}
		local combat = weaponDef.combat or {}
		lines[#lines + 1] = string.format("ATK %d", clampInt(combat.baseAtk or weaponDef.baseDamage, 0))

		local candidates = {
			{ label = "HP", value = clampInt(stats.HP, 0), suffix = "" },
			{ label = "DEF", value = clampInt(stats.DEF, 0), suffix = "" },
			{ label = "SPD", value = clampInt(stats.SPD, 0), suffix = "%" },
			{ label = "CRIT", value = clampInt(stats.CRIT_RATE, 0), suffix = "%" },
			{ label = "CRIT DMG", value = clampInt(stats.CRIT_DMG, 0), suffix = "%" },
			{ label = "LIFESTEAL", value = clampInt(stats.LIFESTEAL, 0), suffix = "%" },
		}

		for _, candidate in ipairs(candidates) do
			if candidate.value > 0 then
				lines[#lines + 1] = string.format("%s +%d%s", candidate.label, candidate.value, candidate.suffix)
			end
			if #lines >= 4 then
				break
			end
		end

		while #lines < 4 do
			lines[#lines + 1] = "-"
		end

		return lines
	end

	return builder
end

return BlacksmithEntryBuilder
