-- MODULE: GachaService.lua
-- GDZIE: ServerScriptService/ModuleScript/GachaService.lua
-- CO: serwerowy gacha + pity + featured guarantee

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))
local PlayerStateStore = require(ServerScriptService:WaitForChild("PlayerStateStore"))
local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))

local bannerConfigsModule = ReplicatedStorage:WaitForChild("BannerConfigs")
local BannerConfigs = require(bannerConfigsModule)

local GachaService = {}

local function now()
	return os.time()
end

local function isActive(banner: any): boolean
	if banner.Active == false then
		return false
	end
	local current = now()
	if banner.StartTime and current < banner.StartTime then
		return false
	end
	if banner.EndTime and current > banner.EndTime then
		return false
	end
	return true
end

local function ensurePity(data: any, bannerId: string)
	data.Pity = data.Pity or {}
	local pity = data.Pity[bannerId]
	if typeof(pity) ~= "table" then
		pity = { Count = 0, FeaturedFail = false }
		data.Pity[bannerId] = pity
	end
	pity.Count = math.max(0, math.floor(tonumber(pity.Count) or 0))
	pity.FeaturedFail = pity.FeaturedFail == true
	return pity
end

local function copyBannerForClient(bannerId: string, banner: any)
	return {
		Id = bannerId,
		DisplayName = banner.DisplayName,
		Description = banner.Description,
		Icon = banner.Icon,
		Active = isActive(banner),
		StartTime = banner.StartTime,
		EndTime = banner.EndTime,
		Cost = banner.Cost,
		RarityRates = banner.RarityRates,
		FeaturedWeaponIds = banner.FeaturedWeaponIds,
		FeaturedRate = banner.FeaturedRate,
		Pity = banner.Pity,
	}
end

local function rollFromWeights(entries: {{ weight: number, value: any }}): any
	local total = 0
	for _, entry in ipairs(entries) do
		total += entry.weight
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	local acc = 0
	for _, entry in ipairs(entries) do
		acc += entry.weight
		if roll <= acc then
			return entry.value
		end
	end
	return entries[#entries].value
end

local function rollRarity(banner: any, pity: any): string
	local rates = banner.RarityRates or {}
	local pityConfig = banner.Pity or {}
	local target = pityConfig.TargetRarity
	local baseTargetRate = tonumber(rates[target]) or 0

	local hardPity = tonumber(pityConfig.HardPity) or math.huge
	if pity.Count == hardPity - 1 then
		return target
	end

	local pTarget = baseTargetRate
	local softStart = tonumber(pityConfig.SoftPityStart) or math.huge
	local softStep = tonumber(pityConfig.SoftPityStep) or 0
	if pity.Count >= softStart then
		pTarget = math.clamp(baseTargetRate + (pity.Count - softStart + 1) * softStep, 0, 1)
	end

	if target and pTarget > 0 then
		if math.random() < pTarget then
			return target
		end
	end

	local weighted = {}
	for rarity, rate in pairs(rates) do
		if rarity ~= target then
			local weight = tonumber(rate) or 0
			if weight > 0 then
				table.insert(weighted, { weight = weight, value = rarity })
			end
		end
	end
	local picked = rollFromWeights(weighted)
	return picked or target or "Common"
end

local function buildPool(banner: any, rarity: string, featuredIds: {[string]: boolean}?)
	local pool = {}
	for _, entry in ipairs(banner.Pool or {}) do
		if entry.Rarity == rarity then
			if not featuredIds or not featuredIds[entry.WeaponId] then
				local weight = tonumber(entry.Weight) or 0
				if weight > 0 and typeof(entry.WeaponId) == "string" then
					table.insert(pool, { weight = weight, value = entry.WeaponId })
				end
			end
		end
	end
	return pool
end

local function pickFeatured(banner: any): string?
	local featured = banner.FeaturedWeaponIds or {}
	if #featured == 0 then
		return nil
	end
	return featured[math.random(1, #featured)]
end

local function rollItem(banner: any, rarity: string, pity: any)
	local pityConfig = banner.Pity or {}
	local target = pityConfig.TargetRarity
	local featuredIds = {}
	for _, id in ipairs(banner.FeaturedWeaponIds or {}) do
		featuredIds[id] = true
	end

	local isTarget = rarity == target
	local featuredHit = false
	local weaponId
	if isTarget and #banner.FeaturedWeaponIds > 0 then
		if pity.FeaturedFail then
			featuredHit = true
		else
			local rate = tonumber(banner.FeaturedRate) or 0
			featuredHit = math.random() < rate
		end

		if featuredHit then
			weaponId = pickFeatured(banner)
			pity.FeaturedFail = false
		else
			pity.FeaturedFail = true
		end
	end

	if not weaponId then
		local pool = buildPool(banner, rarity, featuredHit and nil or featuredIds)
		weaponId = rollFromWeights(pool)
		if not weaponId then
			local fallbackPool = buildPool(banner, rarity)
			weaponId = rollFromWeights(fallbackPool)
		end
	end

	return weaponId, featuredHit
end

local function ensureWeaponList(data: any)
	data.Weapons = data.Weapons or {}
	return data.Weapons
end

function GachaService.GetActiveBanners()
	local result = {}
	for id, banner in pairs(BannerConfigs.Banners or {}) do
		result[id] = copyBannerForClient(id, banner)
	end
	return result
end

function GachaService.GetPlayerState(player: Player)
	local data = PlayerData.Get(player)
	return {
		Currencies = CurrencyService.GetBalances(player),
		Pity = data.Pity or {},
	}
end

function GachaService.Roll(player: Player, bannerId: string, count: number)
	local banner = BannerConfigs.Banners and BannerConfigs.Banners[bannerId]
	if not banner then
		return false, "InvalidBanner"
	end
	if not isActive(banner) then
		return false, "BannerInactive"
	end

	count = tonumber(count) or 1
	count = math.clamp(math.floor(count), 1, 10)

	local cost = banner.Cost or { Currency = "Tickets", Amount = 1 }
	if cost.Currency ~= "Tickets" then
		return false, "InvalidCostCurrency"
	end
	local totalCost = (tonumber(cost.Amount) or 1) * count
	if totalCost <= 0 then
		return false, "InvalidCost"
	end

	local balances = CurrencyService.GetBalances(player)
	if (balances.Tickets or 0) < totalCost then
		return false, "NotEnoughTickets"
	end

	if not CurrencyService.RemoveCurrency(player, "Tickets", totalCost) then
		return false, "NotEnoughTickets"
	end

	local data = PlayerData.Get(player)
	local pity = ensurePity(data, bannerId)
	local weapons = ensureWeaponList(data)
	local results = {}

	for _ = 1, count do
		local rarity = rollRarity(banner, pity)
		if rarity == (banner.Pity and banner.Pity.TargetRarity) then
			pity.Count = 0
		else
			pity.Count += 1
		end

		local weaponId, featured = rollItem(banner, rarity, pity)
		if weaponId then
			table.insert(weapons, weaponId)
			PlayerStateStore.EnsureOwnedWeapon(player, weaponId)
		end

		table.insert(results, {
			WeaponId = weaponId,
			Rarity = rarity,
			Featured = featured,
		})
	end

	PlayerData.MarkDirty(player)

	return true, {
		Results = results,
		Pity = data.Pity,
		Currencies = balances,
	}
end

return GachaService
