local RunProgressApi = {}

local implementations = {}
local pendingWrappers = {}
local warnedMissing = {}
local endRunFinalizingCounts = {}

local function assertFunction(name: string, fn: any)
	assert(type(fn) == "function", string.format("[RunProgressApi] %s must be a function", name))
end

local function applyPendingWrappers(name: string, fn)
	local wrappers = pendingWrappers[name]
	if not wrappers then
		return fn
	end

	for _, wrapper in ipairs(wrappers) do
		fn = wrapper(fn)
		assertFunction(name, fn)
	end

	pendingWrappers[name] = nil
	return fn
end

function RunProgressApi.SetImplementation(name: string, fn)
	assert(type(name) == "string" and name ~= "", "[RunProgressApi] implementation name is required")
	assertFunction(name, fn)
	implementations[name] = applyPendingWrappers(name, fn)
	warnedMissing[name] = nil
end

function RunProgressApi.Configure(map)
	assert(type(map) == "table", "[RunProgressApi] Configure expects a table")
	for name, fn in pairs(map) do
		RunProgressApi.SetImplementation(name, fn)
	end
end

function RunProgressApi.Wrap(name: string, wrapper)
	assert(type(name) == "string" and name ~= "", "[RunProgressApi] wrapper name is required")
	assertFunction(name .. " wrapper", wrapper)

	local current = implementations[name]
	if type(current) == "function" then
		local wrapped = wrapper(current)
		assertFunction(name, wrapped)
		implementations[name] = wrapped
		return
	end

	local wrappers = pendingWrappers[name]
	if not wrappers then
		wrappers = {}
		pendingWrappers[name] = wrappers
	end
	table.insert(wrappers, wrapper)
end

function RunProgressApi.IsConfigured(name: string): boolean
	return type(implementations[name]) == "function"
end

local function call(name: string, ...)
	local fn = implementations[name]
	if type(fn) ~= "function" then
		if not warnedMissing[name] then
			warn(string.format("[RunProgressApi] %s called before implementation was configured", name))
			warnedMissing[name] = true
		end
		return nil
	end
	return fn(...)
end

function RunProgressApi.AwardPlayer(player: Player, xp: number, coins: number)
	return call("AwardPlayer", player, xp, coins)
end

function RunProgressApi.AwardSouls(player: Player, souls: number)
	return call("AwardSouls", player, souls)
end

function RunProgressApi.GetRunCoins(player: Player): number
	return tonumber(call("GetRunCoins", player)) or 0
end

function RunProgressApi.TrySpendRunCoins(player: Player, coins: number): boolean
	return call("TrySpendRunCoins", player, coins) == true
end

function RunProgressApi.RegisterEnemyKill(position: Vector3?, killer: Player?)
	return call("RegisterEnemyKill", position, killer)
end

function RunProgressApi.NotifyBossSpawn()
	return call("NotifyBossSpawn")
end

function RunProgressApi.GetAverageRunLevel(): number
	return tonumber(call("GetAverageRunLevel")) or 0
end

function RunProgressApi.SetRunSecondsProvider(fn)
	RunProgressApi.SetImplementation("GetRunSeconds", fn)
end

function RunProgressApi.GetRunSeconds(): number
	return tonumber(call("GetRunSeconds")) or 0
end

function RunProgressApi.IsEndRunFinalizing(player: Player): boolean
	if not player then
		return false
	end
	return (endRunFinalizingCounts[player.UserId] or 0) > 0
end

function RunProgressApi.EndRunForPlayer(player: Player, reason: string)
	local userId = player and player.UserId
	if userId then
		endRunFinalizingCounts[userId] = (endRunFinalizingCounts[userId] or 0) + 1
	end

	local results = table.pack(pcall(call, "EndRunForPlayer", player, reason))

	if userId then
		local remaining = (endRunFinalizingCounts[userId] or 1) - 1
		endRunFinalizingCounts[userId] = remaining > 0 and remaining or nil
	end

	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

return RunProgressApi
