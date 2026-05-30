local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DEBUG_PREFIXES = {
	";debug",
	";td",
}

local HELP_LINES = {
	";debug errorconfig",
	";debug errorreport [message]",
}

local function log(player: Player, message: string)
	print(("[ErrorReporterDebug][%s] %s"):format(player.Name, message))
end

local function tokenize(message: string): { string }
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

local function printHelp(player: Player)
	for _, line in ipairs(HELP_LINES) do
		log(player, line)
	end
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

print("[ErrorReporterDebug] Ready (Studio only)")
