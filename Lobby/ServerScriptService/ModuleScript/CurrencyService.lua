-- MODULE: CurrencyService.lua
-- GDZIE: ServerScriptService/ModuleScript/CurrencyService.lua
-- CO: obsługa walut (Coins / WeaponPoints / Tickets)

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local CurrencyService = {}

local function ensureCurrencies(data: any)
	data.Currencies = data.Currencies or { Coins = 0, WeaponPoints = 0, Tickets = 0 }
	data.Currencies.Coins = math.max(0, math.floor(tonumber(data.Currencies.Coins) or 0))
	data.Currencies.WeaponPoints = math.max(0, math.floor(tonumber(data.Currencies.WeaponPoints) or 0))
	data.Currencies.Tickets = math.max(0, math.floor(tonumber(data.Currencies.Tickets) or 0))
	data.coins = data.Currencies.Coins
	return data.Currencies
end

local function clampAmount(amount: number): number
	amount = tonumber(amount) or 0
	amount = math.floor(amount)
	if amount < 0 then amount = 0 end
	return amount
end

function CurrencyService.GetBalances(player: Player)
	local data = PlayerData.Get(player)
	return ensureCurrencies(data)
end

function CurrencyService.AddCurrency(player: Player, currency: string, amount: number)
	local data = PlayerData.Get(player)
	local currencies = ensureCurrencies(data)
	amount = clampAmount(amount)
	if amount == 0 then return currencies end
	if currencies[currency] == nil then return currencies end
	currencies[currency] += amount
	if currency == "Coins" then
		data.coins = currencies.Coins
	end
	PlayerData.MarkDirty(player)
	return currencies
end

function CurrencyService.RemoveCurrency(player: Player, currency: string, amount: number): boolean
	local data = PlayerData.Get(player)
	local currencies = ensureCurrencies(data)
	amount = clampAmount(amount)
	if amount == 0 then return true end
	if currencies[currency] == nil then return false end
	if currencies[currency] < amount then
		return false
	end
	currencies[currency] -= amount
	if currency == "Coins" then
		data.coins = currencies.Coins
	end
	PlayerData.MarkDirty(player)
	return true
end

function CurrencyService.ConvertWeaponPointsToTickets(player: Player, amountWeaponPoints: number)
	local data = PlayerData.Get(player)
	local currencies = ensureCurrencies(data)
	local amount = clampAmount(amountWeaponPoints)
	if amount <= 0 then
		return false, "InvalidAmount", currencies
	end

	local conversion = math.floor(amount / 100)
	if conversion <= 0 then
		return false, "NotEnoughWeaponPoints", currencies
	end

	local required = conversion * 100
	if currencies.WeaponPoints < required then
		return false, "NotEnoughWeaponPoints", currencies
	end

	currencies.WeaponPoints -= required
	currencies.Tickets += conversion
	PlayerData.MarkDirty(player)
	return true, { converted = conversion, spent = required }, currencies
end

return CurrencyService
