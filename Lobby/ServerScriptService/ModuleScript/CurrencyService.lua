-- CurrencyService.lua
-- Spójne waluty dla Lobby:
-- Coins -> PlayerData.coins
-- WeaponPoints -> PlayerData.weaponPoints
-- Tickets -> PlayerData.tickets
-- (100 WP = 1 Ticket)

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local CurrencyService = {}

local function getData(player: Player)
	return PlayerData.Get(player)
end

local function clamp0(n)
	n = math.floor(tonumber(n) or 0)
	if n < 0 then n = 0 end
	return n
end

local function ensure(data)
	data.coins = clamp0(data.coins)
	data.weaponPoints = clamp0(data.weaponPoints)
	data.tickets = clamp0(data.tickets)
end

function CurrencyService.GetBalances(player: Player)
	local data = getData(player)
	ensure(data)
	return {
		Coins = data.coins,
		WeaponPoints = data.weaponPoints,
		Tickets = data.tickets,
	}
end

function CurrencyService.GetCoins(player: Player): number
	local data = getData(player); ensure(data)
	return data.coins
end

function CurrencyService.AddCoins(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return end
	local data = getData(player); ensure(data)
	data.coins = math.max(0, data.coins + amount)
	PlayerData.MarkDirty(player)
end

function CurrencyService.SpendCoins(player: Player, amount: number): boolean
	amount = clamp0(amount)
	if amount == 0 then return true end
	local data = getData(player); ensure(data)
	if data.coins < amount then return false end
	data.coins -= amount
	PlayerData.MarkDirty(player)
	return true
end

function CurrencyService.GetWeaponPoints(player: Player): number
	local data = getData(player); ensure(data)
	return data.weaponPoints
end

function CurrencyService.AddWeaponPoints(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return end
	local data = getData(player); ensure(data)
	data.weaponPoints = math.max(0, data.weaponPoints + amount)
	PlayerData.MarkDirty(player)
end

function CurrencyService.GetTickets(player: Player): number
	local data = getData(player); ensure(data)
	return data.tickets
end

function CurrencyService.AddTickets(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return end
	local data = getData(player); ensure(data)
	data.tickets = math.max(0, data.tickets + amount)
	PlayerData.MarkDirty(player)
end

-- Generic add/remove used by GachaService
function CurrencyService.AddCurrency(player: Player, currency: string, amount: number)
	amount = clamp0(amount)
	if amount == 0 then return true end
	local data = getData(player); ensure(data)

	if currency == "Coins" then
		data.coins += amount
	elseif currency == "WeaponPoints" then
		data.weaponPoints += amount
	elseif currency == "Tickets" then
		data.tickets += amount
	else
		return false
	end

	PlayerData.MarkDirty(player)
	return true
end

function CurrencyService.RemoveCurrency(player: Player, currency: string, amount: number): boolean
	amount = clamp0(amount)
	if amount == 0 then return true end
	local data = getData(player); ensure(data)

	if currency == "Coins" then
		if data.coins < amount then return false end
		data.coins -= amount
	elseif currency == "WeaponPoints" then
		if data.weaponPoints < amount then return false end
		data.weaponPoints -= amount
	elseif currency == "Tickets" then
		if data.tickets < amount then return false end
		data.tickets -= amount
	else
		return false
	end

	PlayerData.MarkDirty(player)
	return true
end

-- 100 WP = 1 Ticket
function CurrencyService.ConvertWeaponPointsToTickets(player: Player, amountWeaponPoints: number)
	local amount = clamp0(amountWeaponPoints)
	if amount < 100 then
		return { ok = false, error = "Min100" }
	end

	local data = getData(player); ensure(data)
	local available = data.weaponPoints
	if available < 100 then
		return { ok = false, error = "NotEnoughWP" }
	end

	local usable = math.min(amount, available)
	local tickets = math.floor(usable / 100)
	if tickets <= 0 then
		return { ok = false, error = "Min100" }
	end

	local spendWp = tickets * 100
	data.weaponPoints -= spendWp
	data.tickets += tickets
	PlayerData.MarkDirty(player)

	return {
		ok = true,
		converted = tickets,
		spentWP = spendWp,
		balances = CurrencyService.GetBalances(player),
	}
end

return CurrencyService
