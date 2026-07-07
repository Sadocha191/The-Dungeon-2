local InventoryFilterSorter = {}

function InventoryFilterSorter.new(deps)
	deps = deps or {}
	local rarityOrder = deps.RarityOrder or {}
	local textContains = deps.TextContains or function(haystack, needle)
		return tostring(haystack or ""):find(tostring(needle or ""), 1, true) ~= nil
	end
	local getSpellDamage = deps.GetSpellDamage or function()
		return 0
	end

	local sorter = {}

	local function passesFilters(entry, tabId, query, tabFilters)
		local searchText = table.concat({
			entry.displayName or "",
			entry.weaponId or "",
			entry.weaponType or "",
			entry.element or "",
			entry.rarity or "",
			entry.category or "",
			entry.description or "",
		}, " ")
		if not textContains(searchText, query) then return false end
		local f = tabFilters or {}
		if tabId == "Weapons" then
			if f.a ~= "All" and entry.weaponType ~= f.a then return false end
			if f.b ~= "All" and entry.rarity ~= f.b then return false end
		elseif tabId == "Spells" then
			if f.a ~= "All" and entry.element ~= f.a then return false end
			if f.b == "Equipped" and not entry.equipped then return false end
			if f.b == "Unlocked" and (not entry.unlocked or entry.equipped) then return false end
			if f.b == "Locked" and entry.unlocked then return false end
		elseif tabId == "Materials" then
			if f.a ~= "All" and entry.bucket ~= f.a then return false end
			if f.b ~= "All" and entry.rarity ~= f.b then return false end
		elseif tabId == "Codex" then
			if f.a ~= "All" and entry.category ~= f.a then return false end
			if f.b == "Discovered" and not entry.discovered then return false end
			if f.b == "Undiscovered" and entry.discovered then return false end
		end
		return true
	end

	local function sortEntries(entries, tabId, mode, equippedWeaponId)
		table.sort(entries, function(a, b)
			if tabId == "Weapons" then
				if mode == "Equipped" then
					local ae, be = a.id == equippedWeaponId, b.id == equippedWeaponId
					if ae ~= be then return ae end
					if a.favorite ~= b.favorite then return a.favorite end
				elseif mode == "Rarity" then
					local ar, br = rarityOrder[a.rarity] or 0, rarityOrder[b.rarity] or 0
					if ar ~= br then return ar > br end
				elseif mode == "Level" and a.level ~= b.level then
					return a.level > b.level
				elseif mode == "ATK" then
					local aa, ba = tonumber(a.stats and a.stats.ATK) or 0, tonumber(b.stats and b.stats.ATK) or 0
					if aa ~= ba then return aa > ba end
				end
			elseif tabId == "Spells" then
				if mode == "Equipped" and a.equipped ~= b.equipped then return a.equipped end
				if mode == "Element" and a.element ~= b.element then return tostring(a.element) < tostring(b.element) end
				if mode == "Damage" then
					local ad, bd = getSpellDamage(a), getSpellDamage(b)
					if ad ~= bd then return ad > bd end
				end
			elseif tabId == "Materials" then
				if mode == "Amount" and a.amount ~= b.amount then return a.amount > b.amount end
				if mode == "Rarity" then
					local ar, br = rarityOrder[a.rarity] or 0, rarityOrder[b.rarity] or 0
					if ar ~= br then return ar > br end
				end
			elseif tabId == "Codex" then
				if mode == "Discovered" and a.discovered ~= b.discovered then return a.discovered end
				if mode == "Category" and a.category ~= b.category then return tostring(a.category) < tostring(b.category) end
			end
			return tostring(a.displayName) < tostring(b.displayName)
		end)
	end

	function sorter.GetFilteredEntries(entries, tabId, query, tabFilters, sortMode, equippedWeaponId)
		local out = {}
		for _, entry in ipairs(entries or {}) do
			if passesFilters(entry, tabId, query, tabFilters) then
				table.insert(out, entry)
			end
		end
		sortEntries(out, tabId, sortMode, equippedWeaponId)
		return out
	end

	return sorter
end

return InventoryFilterSorter
