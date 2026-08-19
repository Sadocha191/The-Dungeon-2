local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

if not RunService:IsStudio() then
	return
end

local RunProgressApi = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("RunProgressApi"))

local DEBUG_PREFIXES = {
	";debug",
	";td",
}

local function ensureDebugFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("DebugSettings")
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = "DebugSettings"
	folder.Parent = ReplicatedStorage
	return folder
end

local function ensureValue(className: string, name: string, defaultValue)
	local folder = ensureDebugFolder()
	local value = folder:FindFirstChild(name)
	if value and value.ClassName ~= className then
		value:Destroy()
		value = nil
	end
	if not value then
		value = Instance.new(className)
		value.Name = name
		value.Value = defaultValue
		value.Parent = folder
	end
	return value
end

local godModeEnabled = ensureValue("BoolValue", "GodModeEnabled", true)
local autoMobSpawnsEnabled = ensureValue("BoolValue", "AutoMobSpawnsEnabled", true)
local spawnStressMode = ensureValue("BoolValue", "SpawnStressMode", true)
local spawnBurstSize = ensureValue("IntValue", "SpawnBurstSize", 3)
local spawnIntervalScale = ensureValue("NumberValue", "SpawnIntervalScale", 0.55)
local maxAliveScale = ensureValue("NumberValue", "MaxAliveScale", 2.6)

local function log(player: Player, message: string)
	print(("[DebugCommand][%s] %s"):format(player.Name, message))
end

local function tokenize(message: string): {string}
	local tokens = {}
	for token in string.gmatch(message, "%S+") do
		table.insert(tokens, token)
	end
	return tokens
end

local function extractCommandBody(message: string): string?
	local lowerMessage = string.lower(message)
	for _, prefix in ipairs(DEBUG_PREFIXES) do
		if string.sub(lowerMessage, 1, #prefix) == prefix then
			local body = string.sub(message, #prefix + 1)
			return string.gsub(body, "^%s+", "")
		end
	end
	return nil
end

local function parseToggleArg(raw: string?, currentValue: boolean): boolean?
	local token = string.lower(tostring(raw or "toggle"))
	if token == "toggle" then
		return not currentValue
	end
	if token == "on" or token == "true" or token == "1" then
		return true
	end
	if token == "off" or token == "false" or token == "0" then
		return false
	end
	return nil
end

local function parsePositiveInt(raw: string?): number?
	local value = tonumber(raw)
	if not value then
		return nil
	end
	return math.max(0, math.floor(value))
end

local function parsePositiveNumber(raw: string?): number?
	local value = tonumber(raw)
	if not value then
		return nil
	end
	return math.max(0, value)
end

local HELP_LINES = {
	";debug help",
	";debug status",
	";debug god [on/off/toggle]",
	";debug spawns [on/off/toggle]",
	";debug stress [on/off/toggle]",
	";debug elite [name] [count]",
	";debug miniboss [name] [count]",
	";debug normal [name] [count]",
	";debug boss",
	";debug clear",
	";debug xp <amount>",
	";debug coins <amount>",
	";debug burst <count>",
	";debug interval <scale>",
	";debug maxalive <scale>",
	";debug errorconfig",
	";debug errorreport [message]",
}

local function printHelp(player: Player)
	for _, line in ipairs(HELP_LINES) do
		log(player, line)
	end
end

local function reportStatus(player: Player)
	log(
		player,
		("god=%s autoSpawns=%s stress=%s burst=%d interval=%.2f maxAlive=%.2f"):format(
			tostring(godModeEnabled.Value),
			tostring(autoMobSpawnsEnabled.Value),
			tostring(spawnStressMode.Value),
			math.floor(spawnBurstSize.Value),
			spawnIntervalScale.Value,
			maxAliveScale.Value
		)
	)
end

local function handleSpawnRequest(player: Player, enemyRank: string, args: {string})
	local count = 1
	local name = args[2]
	if #args == 2 then
		local maybeCount = parsePositiveInt(args[2])
		if maybeCount and maybeCount >= 1 then name = nil count = maybeCount end
	elseif #args >= 3 then
		local explicitCount = parsePositiveInt(args[3])
		if explicitCount and explicitCount >= 1 then
			count = explicitCount
		else
			log(player, ("Use: ;debug %s [name] [count]"):format(string.lower(enemyRank)))
			return
		end
	end

	local spawnFn = enemyRank == "Elite" and _G.DebugForceEliteSpawn
		or (enemyRank == "MiniBoss" and _G.DebugForceMiniBossSpawn)
		or _G.DebugForceSpawnMob
	if type(spawnFn) ~= "function" then
		log(player, "Spawn hook is not ready yet.")
		return
	end
	local ok, result = pcall(function()
		if enemyRank == "Normal" then return spawnFn(name, false, count) end
		return spawnFn(name, count)
	end)
	if not ok then
		log(player, ("Spawn failed: %s"):format(tostring(result)))
		return
	end
	local spawnedCount = typeof(result) == "table" and #result or 0
	log(player, ("Spawned %d %s mob(s)."):format(spawnedCount, enemyRank))
end

local function handleCommand(player: Player, message: string)
	local body = extractCommandBody(message)
	if not body then
		return
	end

	local args = tokenize(body)
	local command = string.lower(args[1] or "help")

	if command == "" or command == "help" then
		printHelp(player)
		return
	end

	if command == "status" then
		reportStatus(player)
		return
	end

	if command == "errorconfig" then
		if typeof(_G.ErrorReporterTest) ~= "table" or type(_G.ErrorReporterTest.PrintConfig) ~= "function" then
			log(player, "ErrorReporter test hook is not ready yet.")
			return
		end

		local ok, status = pcall(function()
			return _G.ErrorReporterTest.PrintConfig()
		end)
		if not ok then
			log(player, ("Error config failed: %s"):format(tostring(status)))
			return
		end

		log(
			player,
			("github=%s url=%s secret=%s discord=%s githubReason=%s discordReason=%s"):format(
				tostring(status.githubBridgeEnabled),
				tostring(status.githubBridgeUrlConfigured),
				tostring(status.githubBridgeSecretConfigured),
				tostring(status.discordEnabled),
				tostring(status.githubBridgeReason),
				tostring(status.discordReason)
			)
		)
		return
	end

	if command == "errorreport" then
		if typeof(_G.ErrorReporterTest) ~= "table" or type(_G.ErrorReporterTest.TriggerServer) ~= "function" then
			log(player, "ErrorReporter test hook is not ready yet.")
			return
		end

		local reportMessage = #args >= 2 and table.concat(args, " ", 2) or "Debug command GitHub bridge test"
		local callOk, triggerOk, reason, errorData = pcall(function()
			return _G.ErrorReporterTest.TriggerServer(reportMessage)
		end)
		if not callOk then
			log(player, ("Error report failed: %s"):format(tostring(triggerOk)))
			return
		end

		log(
			player,
			("Error report sent: ok=%s reason=%s errorCode=%s"):format(
				tostring(triggerOk),
				tostring(reason),
				tostring(errorData and errorData.errorCode or "N/A")
			)
		)
		return
	end

	if command == "god" then
		local nextValue = parseToggleArg(args[2], godModeEnabled.Value)
		if nextValue == nil then
			log(player, "Use: ;debug god on|off|toggle")
			return
		end
		godModeEnabled.Value = nextValue
		log(player, ("God mode = %s"):format(tostring(nextValue)))
		return
	end

	if command == "spawns" then
		local nextValue = parseToggleArg(args[2], autoMobSpawnsEnabled.Value)
		if nextValue == nil then
			log(player, "Use: ;debug spawns on|off|toggle")
			return
		end
		autoMobSpawnsEnabled.Value = nextValue
		if type(_G.DebugSetAutoMobSpawnsEnabled) == "function" then
			pcall(function()
				_G.DebugSetAutoMobSpawnsEnabled(nextValue)
			end)
		end
		log(player, ("Auto mob spawns = %s"):format(tostring(nextValue)))
		return
	end

	if command == "stress" then
		local nextValue = parseToggleArg(args[2], spawnStressMode.Value)
		if nextValue == nil then
			log(player, "Use: ;debug stress on|off|toggle")
			return
		end
		spawnStressMode.Value = nextValue
		log(player, ("Spawn stress mode = %s"):format(tostring(nextValue)))
		return
	end

	if command == "burst" then
		local count = parsePositiveInt(args[2])
		if not count or count < 1 then
			log(player, "Use: ;debug burst <count>")
			return
		end
		spawnBurstSize.Value = count
		log(player, ("Spawn burst size = %d"):format(count))
		return
	end

	if command == "interval" then
		local scale = parsePositiveNumber(args[2])
		if not scale or scale <= 0 then
			log(player, "Use: ;debug interval <scale>")
			return
		end
		spawnIntervalScale.Value = scale
		log(player, ("Spawn interval scale = %.2f"):format(scale))
		return
	end

	if command == "maxalive" then
		local scale = parsePositiveNumber(args[2])
		if not scale or scale <= 0 then
			log(player, "Use: ;debug maxalive <scale>")
			return
		end
		maxAliveScale.Value = scale
		log(player, ("Max alive scale = %.2f"):format(scale))
		return
	end

	if command == "elite" then
		handleSpawnRequest(player, "Elite", args)
		return
	end

	if command == "normal" then
		handleSpawnRequest(player, "Normal", args)
		return
	end

	if command == "miniboss" then
		handleSpawnRequest(player, "MiniBoss", args)
		return
	end

	if command == "boss" then
		if type(_G.DebugForceBossSpawn) ~= "function" then
			log(player, "Boss spawn hook is not ready yet.")
			return
		end
		local ok, result = pcall(function()
			return _G.DebugForceBossSpawn()
		end)
		if not ok then
			log(player, ("Boss spawn failed: %s"):format(tostring(result)))
			return
		end
		log(player, result and "Boss spawned." or "Boss spawn returned nil.")
		return
	end

	if command == "clear" then
		if type(_G.DebugClearEnemies) ~= "function" then
			log(player, "Clear hook is not ready yet.")
			return
		end
		local ok, result = pcall(function()
			return _G.DebugClearEnemies()
		end)
		if not ok then
			log(player, ("Clear failed: %s"):format(tostring(result)))
			return
		end
		log(player, ("Cleared %d enemy model(s)."):format(tonumber(result) or 0))
		return
	end

	if command == "xp" or command == "coins" then
		local amount = parsePositiveInt(args[2])
		if not amount or amount <= 0 then
			log(player, ("Use: ;debug %s <amount>"):format(command))
			return
		end
		if not RunProgressApi.IsConfigured("AwardPlayer") then
			log(player, "Award hook is not ready yet.")
			return
		end
		if command == "xp" then
			RunProgressApi.AwardPlayer(player, amount, 0)
		else
			RunProgressApi.AwardPlayer(player, 0, amount)
		end
		log(player, ("Granted %d %s."):format(amount, command))
		return
	end

	log(player, ("Unknown command: %s"):format(command))
	printHelp(player)
end

local function hookPlayer(player: Player)
	player.Chatted:Connect(function(message)
		handleCommand(player, message)
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end

Players.PlayerAdded:Connect(hookPlayer)

print("[DebugCommandService] Ready (Studio only)")
