-- BlacksmithConfig.lua (ReplicatedStorage)
-- Config: forge cost, rarity rolls, prefixes, upgrade costs.

local BlacksmithConfig = {}

BlacksmithConfig.ForgeCost = 500

-- Forge can only produce up to Epic.
BlacksmithConfig.AllowedRarities = { "Common", "Rare", "Epic" }

-- Weighted rarity roll for forge.
BlacksmithConfig.RarityWeights = {
	Common = 65,
	Rare = 25,
	Epic = 10,
}

-- Prefixes = quality roll that scales ALL stats (atk + bonuses).
-- rollMult is picked uniformly in [minMult, maxMult].
BlacksmithConfig.Prefixes = {
	{ key = "Flawed",     name = "Flawed",      minMult = 0.85, maxMult = 0.92, weight = 12 },
	{ key = "Shoddy",     name = "Shoddy",      minMult = 0.92, maxMult = 0.97, weight = 18 },
	{ key = "Balanced",   name = "Balanced",    minMult = 0.98, maxMult = 1.02, weight = 40 },
	{ key = "Fine",       name = "Fine",        minMult = 1.03, maxMult = 1.09, weight = 18 },
	{ key = "Masterwork", name = "Masterwork",  minMult = 1.10, maxMult = 1.18, weight = 10 },
	{ key = "WorkOfArt",  name = "Work of Art", minMult = 1.19, maxMult = 1.28, weight = 2 },
}

-- Upgrade costs: "to i to" (stała baza + skalowanie levelem).
-- Cost to upgrade from level L -> L+1:
-- cost = base + perLevel * L
BlacksmithConfig.UpgradeCosts = {
	Common = { base = 120, perLevel = 60 },
	Rare   = { base = 220, perLevel = 110 },
	Epic   = { base = 360, perLevel = 180 },
}

local function weightedPick(mapOrList)
	-- map: {key=weight,...} OR list: {{key/name/weight},...}
	local total = 0
	if typeof(mapOrList) == "table" and mapOrList[1] == nil then
		for _, w in pairs(mapOrList) do
			w = tonumber(w) or 0
			if w > 0 then total += w end
		end
		if total <= 0 then return nil end
		local r = math.random() * total
		for k, w in pairs(mapOrList) do
			w = tonumber(w) or 0
			if w > 0 then
				r -= w
				if r <= 0 then return k end
			end
		end
		return nil
	end

	for _, it in ipairs(mapOrList) do
		local w = tonumber(it.weight) or 0
		if w > 0 then total += w end
	end
	if total <= 0 then return nil end

	local r = math.random() * total
	for _, it in ipairs(mapOrList) do
		local w = tonumber(it.weight) or 0
		if w > 0 then
			r -= w
			if r <= 0 then return it end
		end
	end
	return nil
end

function BlacksmithConfig.RollRarity()
	return weightedPick(BlacksmithConfig.RarityWeights)
end

function BlacksmithConfig.RollPrefix()
	local picked = weightedPick(BlacksmithConfig.Prefixes)
	if not picked then
		return { key = "Balanced", name = "Balanced", minMult = 1.0, maxMult = 1.0, weight = 1 }, 1.0
	end
	local minMult = tonumber(picked.minMult) or 1.0
	local maxMult = tonumber(picked.maxMult) or minMult
	if maxMult < minMult then
		minMult, maxMult = maxMult, minMult
	end
	local roll = minMult + (maxMult - minMult) * math.random()
	return picked, roll
end

function BlacksmithConfig.GetUpgradeCost(rarity: string, currentLevel: number)
	currentLevel = math.max(1, math.floor(tonumber(currentLevel) or 1))
	local cfg = BlacksmithConfig.UpgradeCosts[rarity]
	if not cfg then
		cfg = { base = 200, perLevel = 100 }
	end
	local base = tonumber(cfg.base) or 0
	local perLevel = tonumber(cfg.perLevel) or 0
	return math.max(0, math.floor(base + perLevel * currentLevel))
end

return BlacksmithConfig
