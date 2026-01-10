-- CurrencyService.lua
-- Modyfikuje tylko stan w pamięci + MarkDirty. Nie zapisuje do DS bezpośrednio.

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local CurrencyService = {}

local function ensureProfile(data)
	data.Profile = data.Profile or {}
	data.Profile.Coins = tonumber(data.Profile.Coins) or 0
	data.Profile.WeaponPoints = tonumber(data.Profile.WeaponPoints) or 0
	return data.Profile
end

function CurrencyService.GetCoins(player: Player): number
	local data = PlayerData.Get(player)
	local p = ensureProfile(data)
	return p.Coins
end

function CurrencyService.GetWeaponPoints(player: Player): number
	local data = PlayerData.Get(player)
	local p = ensureProfile(data)
	return p.WeaponPoints
end

function CurrencyService.AddCoins(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return end

	local data = PlayerData.Get(player)
	local p = ensureProfile(data)
	p.Coins = math.max(0, p.Coins + amount)

	PlayerData.MarkDirty(player, "coins")
end

function CurrencyService.AddWeaponPoints(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return end

	local data = PlayerData.Get(player)
	local p = ensureProfile(data)
	p.WeaponPoints = math.max(0, p.WeaponPoints + amount)

	PlayerData.MarkDirty(player, "wp")
end

function CurrencyService.SpendCoins(player: Player, amount: number): boolean
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return true end

	local data = PlayerData.Get(player)
	local p = ensureProfile(data)

	if p.Coins < amount then
		return false
	end

	p.Coins -= amount
	PlayerData.MarkDirty(player, "coins_spend")
	return true
end

return CurrencyService
