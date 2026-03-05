-- CurrencyService.lua
-- Spójne waluty dla Lobby:
-- Silver -> PlayerData.silver
-- WeaponPoints -> PlayerData.weaponPoints
-- Tickets -> PlayerData.tickets
-- (100 WP = 1 Ticket)

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local CurrencyService = {}

local function utcDayKey(t: number?): number
	local dt = os.date("!*t", t or os.time())
	return (dt.year * 1000) + (dt.yday or 0)
end

local function utcWeekKey(t: number?): number
	local dt = os.date("!*t", t or os.time())
	local week = math.floor(((dt.yday or 1) - 1) / 7) + 1
	return (dt.year * 100) + week
end

local function addMissionCounter(player: Player, key: string, amount: number)
	if amount == 0 then return end
	local data = getData(player)
	data.Missions = data.Missions or {}
	local m = data.Missions
	m.DailyKey = tonumber(m.DailyKey) or 0
	m.WeeklyKey = tonumber(m.WeeklyKey) or 0
	m.CountersDaily = (typeof(m.CountersDaily) == "table") and m.CountersDaily or {}
	m.CountersWeekly = (typeof(m.CountersWeekly) == "table") and m.CountersWeekly or {}

	local dk = utcDayKey()
	if m.DailyKey ~= dk then
		m.DailyKey = dk
		m.CountersDaily = {}
	end
	local wk = utcWeekKey()
	if m.WeeklyKey ~= wk then
		m.WeeklyKey = wk
		m.CountersWeekly = {}
	end

	m.CountersDaily[key] = (tonumber(m.CountersDaily[key]) or 0) + amount
	m.CountersWeekly[key] = (tonumber(m.CountersWeekly[key]) or 0) + amount
	PlayerData.MarkDirty(player)
end

local function getData(player: Player)
	return PlayerData.Get(player)
end

local function clamp0(n)
	n = math.floor(tonumber(n) or 0)
	if n < 0 then n = 0 end
	return n
end

local function ensure(data)
	data.silver = clamp0(data.silver)
	data.weaponPoints = clamp0(data.weaponPoints)
	data.tickets = clamp0(data.tickets)
end

function CurrencyService.GetBalances(player: Player)
	local data = getData(player)
	ensure(data)
	return {
		Silver = data.silver,
		Coins = data.silver,
		WeaponPoints = data.weaponPoints,
		Tickets = data.tickets,
	}
end

function CurrencyService.GetCoins(player: Player): number
	local data = getData(player); ensure(data)
	return data.silver
end

function CurrencyService.AddCoins(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)
	if amount == 0 then return end
	local data = getData(player); ensure(data)
	data.silver = math.max(0, data.silver + amount)
	PlayerData.MarkDirty(player)
end

function CurrencyService.SpendCoins(player: Player, amount: number): boolean
	amount = clamp0(amount)
	if amount == 0 then return true end
	local data = getData(player); ensure(data)
	if data.silver < amount then return false end
	data.silver -= amount
	PlayerData.MarkDirty(player)
	pcall(function()
		addMissionCounter(player, "COINS_SPENT", amount)
	end)
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

	if currency == "Coins" or currency == "Silver" then
		data.silver += amount
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

	if currency == "Coins" or currency == "Silver" then
		if data.silver < amount then return false end
		data.silver -= amount
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


-- Silver API (canonical)
function CurrencyService.GetSilver(plr)
	local data = PlayerData.Get(plr)
	return data.silver
end

function CurrencyService.AddSilver(plr, amount)
	amount = clamp0(amount)
	local data = PlayerData.Get(plr)
	data.silver = math.max(0, (data.silver or 0) + amount)
	PlayerData.MarkDirty(plr)
	return data.silver
end

function CurrencyService.SpendSilver(plr, amount)
	amount = clamp0(amount)
	local data = PlayerData.Get(plr)
	if (data.silver or 0) < amount then return false end
	data.silver -= amount
	PlayerData.MarkDirty(plr)
	return true
end

return CurrencyService
