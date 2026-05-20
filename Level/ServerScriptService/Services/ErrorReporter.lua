local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ErrorReporter = {}

local GAME_NAME = "The Dungeon 2"
local DISCORD_WEBHOOK_URL_PLACEHOLDER = "PASTE_YOUR_WEBHOOK_HERE"
local GITHUB_BRIDGE_URL_PLACEHOLDER = "PASTE_YOUR_GITHUB_BRIDGE_URL_HERE"
local GITHUB_BRIDGE_SECRET_PLACEHOLDER = "PASTE_YOUR_ROBLOX_ERROR_SECRET_HERE"
local DISCORD_WEBHOOK_URL = DISCORD_WEBHOOK_URL_PLACEHOLDER
local GITHUB_BRIDGE_URL = GITHUB_BRIDGE_URL_PLACEHOLDER
local GITHUB_BRIDGE_SECRET = GITHUB_BRIDGE_SECRET_PLACEHOLDER

local ERROR_CODE_COOLDOWN_SECONDS = 60
local CLIENT_RATE_LIMIT_WINDOW_SECONDS = 30
local CLIENT_RATE_LIMIT_MAX_EVENTS = 6
local MAX_CONTEXT_ITEMS = 12
local MAX_MESSAGE_LENGTH = 1200
local MAX_SANITIZED_MESSAGE_LENGTH = 700
local MAX_STACK_LENGTH = 3500
local MOD32 = 4294967296

local occurrenceState = {}
local clientRateState = {}
local cachedPlaceInfo = nil
local warnedMissingDiscordWebhook = false
local warnedMissingGithubBridge = false
local warnedMissingGithubBridgeSecret = false
local warnedHttpDisabled = false

local function normalizeText(value)
	if value == nil then
		return nil
	end

	local text = typeof(value) == "string" and value or tostring(value)
	text = text:gsub("\r\n", "\n")
	text = text:gsub("\r", "\n")
	text = text:gsub("[%z\1-\8\11\12\14-\31]", "")
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")

	if text == "" then
		return nil
	end

	return text
end

local function truncateText(value, maxLength)
	local text = normalizeText(value)
	if not text then
		return nil
	end

	if #text <= maxLength then
		return text
	end

	if maxLength <= 3 then
		return string.sub(text, 1, maxLength)
	end

	return string.sub(text, 1, maxLength - 3) .. "..."
end

local function firstLineOf(value)
	local text = normalizeText(value)
	if not text then
		return nil
	end

	local newlineIndex = string.find(text, "\n", 1, true)
	if newlineIndex then
		return string.sub(text, 1, newlineIndex - 1)
	end

	return text
end

local function cloneTable(source)
	local out = {}
	if typeof(source) ~= "table" then
		return out
	end

	for key, value in pairs(source) do
		out[key] = value
	end

	return out
end

local function stringifyScalar(value)
	local valueType = typeof(value)
	if valueType == "string" then
		return normalizeText(value)
	end
	if valueType == "number" or valueType == "boolean" then
		return tostring(value)
	end
	if valueType == "Instance" then
		return truncateText(value:GetFullName(), 240)
	end
	if valueType == "Vector3" or valueType == "Vector2" or valueType == "UDim2" or valueType == "Color3" or valueType == "CFrame" then
		return truncateText(tostring(value), 240)
	end
	if valueType == "table" then
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode(value)
		end)
		if ok then
			return truncateText(encoded, 240)
		end
	end

	return truncateText(tostring(value), 240)
end

local function sanitizeContextTable(contextTable)
	local sanitized = {}
	if typeof(contextTable) ~= "table" then
		return sanitized
	end

	local addedCount = 0
	local keys = {}
	for key in pairs(contextTable) do
		if typeof(key) == "string" then
			table.insert(keys, key)
		end
	end

	table.sort(keys, function(a, b)
		return string.lower(a) < string.lower(b)
	end)

	for _, key in ipairs(keys) do
		if addedCount >= MAX_CONTEXT_ITEMS then
			break
		end

		local normalizedKey = truncateText(key, 80)
		local normalizedValue = stringifyScalar(contextTable[key])
		if normalizedKey and normalizedValue then
			sanitized[normalizedKey] = normalizedValue
			addedCount += 1
		end
	end

	return sanitized
end

local function buildContextSummary(extraContext)
	local keys = {}
	for key in pairs(extraContext) do
		table.insert(keys, key)
	end

	if #keys == 0 then
		return "N/A"
	end

	table.sort(keys, function(a, b)
		return string.lower(a) < string.lower(b)
	end)

	local lines = {}
	for _, key in ipairs(keys) do
		table.insert(lines, string.format("%s: %s", key, tostring(extraContext[key])))
	end

	return truncateText(table.concat(lines, "\n"), 1024) or "N/A"
end

local function splitRawMessageAndStack(rawMessage, explicitStackTrace)
	local message = normalizeText(rawMessage)
	local stackTrace = normalizeText(explicitStackTrace)

	if not stackTrace and message then
		local newlineIndex = string.find(message, "\n", 1, true)
		if newlineIndex then
			local splitMessage = string.sub(message, 1, newlineIndex - 1)
			local splitStack = string.sub(message, newlineIndex + 1)
			message = normalizeText(splitMessage)
			stackTrace = normalizeText(splitStack)
		end
	end

	if not message and stackTrace then
		message = firstLineOf(stackTrace)
	end

	return message, stackTrace
end

local function buildIsoTimestamp()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function readAttribute(instance, attributeNames)
	if typeof(instance) ~= "Instance" then
		return nil
	end

	for _, attributeName in ipairs(attributeNames) do
		local value = instance:GetAttribute(attributeName)
		local valueType = typeof(value)

		if valueType == "string" then
			local text = normalizeText(value)
			if text then
				return text
			end
		elseif valueType == "number" then
			return tostring(value)
		elseif valueType == "boolean" then
			return value and "true" or "false"
		end
	end

	return nil
end

local function getPlaceInfo()
	if cachedPlaceInfo then
		return cachedPlaceInfo
	end

	local rawPlaceName = nil
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)

	if ok and typeof(info) == "table" and typeof(info.Name) == "string" and info.Name ~= "" then
		rawPlaceName = info.Name
	end

	rawPlaceName = normalizeText(rawPlaceName) or normalizeText(game.Name) or "Unknown"
	local lowered = string.lower(rawPlaceName)
	local resolvedPlaceName = rawPlaceName
	local placeSlug = "unknown"

	if string.find(lowered, "poziom", 1, true) or string.find(lowered, "level", 1, true) then
		resolvedPlaceName = "Level"
		placeSlug = "level"
	elseif string.find(lowered, "cztery", 1, true)
		or string.find(lowered, "szczyt", 1, true)
		or string.find(lowered, "four peaks", 1, true)
		or string.find(lowered, "lobby", 1, true)
	then
		resolvedPlaceName = "Four Peaks"
		placeSlug = "lobby"
	end

	cachedPlaceInfo = {
		rawPlaceName = rawPlaceName,
		placeName = resolvedPlaceName,
		placeSlug = placeSlug,
	}

	return cachedPlaceInfo
end

local function parseSourceDetails(text)
	local normalized = normalizeText(text)
	if not normalized then
		return nil, nil, nil
	end

	local sourcePath, lineNumber = string.match(normalized, "([%w%._/%-\\ ]+):(%d+)")
	if not sourcePath then
		return nil, nil, nil
	end

	sourcePath = normalizeText(sourcePath)
	if not sourcePath then
		return nil, nil, nil
	end

	local scriptName = sourcePath:match("([^%.\\/]+)$") or sourcePath
	scriptName = scriptName:gsub("%.lua$", "")
	return scriptName, sourcePath, tonumber(lineNumber)
end

local function resolvePlayerContext(context)
	local player = context.player
	local playerName = nil
	local playerUserId = nil

	if typeof(player) == "Instance" and player:IsA("Player") then
		playerName = player.Name
		playerUserId = player.UserId
	elseif typeof(player) == "table" then
		playerName = normalizeText(player.name or player.playerName)
		if typeof(player.userId) == "number" then
			playerUserId = player.userId
		elseif typeof(player.userId) == "string" then
			playerUserId = tonumber(player.userId)
		end
	end

	if not playerName then
		playerName = normalizeText(context.playerName)
	end

	if playerUserId == nil then
		if typeof(context.playerUserId) == "number" then
			playerUserId = context.playerUserId
		elseif typeof(context.playerUserId) == "string" then
			playerUserId = tonumber(context.playerUserId)
		end
	end

	return playerName, playerUserId
end

local function resolveSourceContext(message, stackTrace, context)
	local scriptName = normalizeText(context.scriptName)
	local scriptFullName = normalizeText(context.scriptFullName)
	local lineNumber = tonumber(context.lineNumber)
	local system = normalizeText(context.system)

	local scriptInstance = context.scriptInstance
	if typeof(scriptInstance) == "Instance" then
		scriptName = scriptName or scriptInstance.Name
		scriptFullName = scriptFullName or scriptInstance:GetFullName()
		system = system or scriptInstance:GetFullName()
	end

	local parsedScriptName, parsedScriptPath, parsedLineNumber = parseSourceDetails(message)
	if parsedScriptName then
		scriptName = scriptName or parsedScriptName
		scriptFullName = scriptFullName or parsedScriptPath
		lineNumber = lineNumber or parsedLineNumber
	end

	if stackTrace then
		local firstStackLine = firstLineOf(stackTrace)
		local stackScriptName, stackScriptPath, stackLineNumber = parseSourceDetails(firstStackLine or stackTrace)
		if stackScriptName then
			scriptName = scriptName or stackScriptName
			scriptFullName = scriptFullName or stackScriptPath
			lineNumber = lineNumber or stackLineNumber
		end
	end

	if not scriptName and system then
		scriptName = system:match("([^%.\\/]+)$") or system
		scriptName = scriptName:gsub("%.lua$", "")
	end

	if not system then
		system = scriptName or "UnknownSystem"
	end

	return scriptName or "UnknownScript", scriptFullName, lineNumber, system
end

local function getLocationContext(context, placeInfo)
	local runMode = truncateText(readAttribute(context.player, { "RunMode" }) or readAttribute(workspace, { "RunMode" }) or context.runMode, 80)
	local level = truncateText(
		readAttribute(context.player, { "CurrentLevel", "LevelId", "LevelKey" })
			or readAttribute(workspace, { "CurrentLevel", "LevelId", "LevelKey" })
			or context.level,
		120
	)
	local wave = truncateText(
		readAttribute(context.player, { "CurrentWave", "Wave" })
			or readAttribute(workspace, { "CurrentWave", "Wave" })
			or context.wave,
		80
	)
	local phase = truncateText(context.phase, 80)

	if not phase then
		if placeInfo.placeName == "Level" then
			phase = "combat"
		elseif placeInfo.placeName == "Four Peaks" then
			phase = "lobby"
		end
	end

	return runMode, level, wave, phase
end

local function computeHash(value)
	local hash = 2166136261
	for index = 1, #value do
		hash = bit32.bxor(hash, string.byte(value, index))
		hash = (hash * 16777619) % MOD32
	end
	return string.format("%08X", hash)
end

local function warnHttpDisabled()
	if warnedHttpDisabled then
		return
	end

	warnedHttpDisabled = true
	warn(
		"[ErrorReporter] HttpService is disabled. Enable Allow HTTP Requests in Home > Game Settings > Security before using Discord or GitHub error reporting."
	)
end

local function isHttpEnabled()
	local ok, enabled = pcall(function()
		return HttpService.HttpEnabled
	end)

	if ok and enabled == false then
		warnHttpDisabled()
		return false
	end

	return true
end

local function cleanupClientRateState(now)
	for userId, state in pairs(clientRateState) do
		if (now - state.windowStart) >= CLIENT_RATE_LIMIT_WINDOW_SECONDS then
			clientRateState[userId] = nil
		end
	end
end

local function isClientRateLimited(userId)
	local now = os.clock()
	cleanupClientRateState(now)

	local state = clientRateState[userId]
	if not state then
		state = {
			windowStart = now,
			count = 0,
		}
		clientRateState[userId] = state
	end

	if state.count >= CLIENT_RATE_LIMIT_MAX_EVENTS then
		return true
	end

	state.count += 1
	return false
end

local function deliverJson(url, payload, requestLabel, extraHeaders)
	if not isHttpEnabled() then
		return false, "HttpDisabled"
	end

	local encodeOk, encodedPayload = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not encodeOk then
		warn(string.format("[ErrorReporter] Failed to encode %s payload: %s", requestLabel, tostring(encodedPayload)))
		return false, "EncodeFailed"
	end

	local requestOk, response = pcall(function()
		local headers = {
			["Content-Type"] = "application/json",
		}
		if typeof(extraHeaders) == "table" then
			for key, value in pairs(extraHeaders) do
				if typeof(key) == "string" and typeof(value) == "string" then
					headers[key] = value
				end
			end
		end

		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = headers,
			Body = encodedPayload,
		})
	end)

	if not requestOk then
		if string.find(string.lower(tostring(response)), "http", 1, true)
			and string.find(string.lower(tostring(response)), "enable", 1, true)
		then
			warnHttpDisabled()
		end

		warn(string.format("[ErrorReporter] %s request failed: %s", requestLabel, tostring(response)))
		return false, "RequestFailed"
	end

	if not response.Success then
		warn(
			string.format(
				"[ErrorReporter] %s request returned %s %s",
				requestLabel,
				tostring(response.StatusCode),
				tostring(response.StatusMessage)
			)
		)
		return false, "Rejected"
	end

	return true, "Delivered"
end

function ErrorReporter.SanitizeMessage(message)
	local sanitized = normalizeText(message)
	if not sanitized then
		return "unknown error"
	end

	sanitized = string.lower(sanitized)
	sanitized = sanitized:gsub(
		"%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x",
		"<guid>"
	)
	sanitized = sanitized:gsub("rbxassetid://%-?%d+", "rbxassetid://<id>")
	sanitized = sanitized:gsub("[Uu]ser[Ii][Dd]%s*[:=]%s*%-?%d+", "userid=<id>")
	sanitized = sanitized:gsub("[Pp]layer[Ii][Dd]%s*[:=]%s*%-?%d+", "playerid=<id>")
	sanitized = sanitized:gsub("[Jj]ob[Ii][Dd]%s*[:=]%s*[%w%-]+", "jobid=<id>")
	sanitized = sanitized:gsub("[Tt]imestamp%s*[:=]%s*%-?%d+%.?%d*", "timestamp=<n>")
	sanitized = sanitized:gsub("(%a[%w_]*)%s*=%s*%-?%d+%.?%d*", "%1=<n>")
	sanitized = sanitized:gsub("(%a[%w_]*)%s*:%s*%-?%d+%.?%d*", "%1:<n>")
	sanitized = sanitized:gsub("%-?%d+%.?%d*", "<n>")
	sanitized = sanitized:gsub("%s+", " ")
	sanitized = sanitized:gsub("^%s+", "")
	sanitized = sanitized:gsub("%s+$", "")

	return sanitized ~= "" and sanitized or "unknown error"
end

function ErrorReporter.BuildErrorCode(errorData)
	local placeId = tostring(errorData.placeId or game.PlaceId)
	local scriptName = string.lower(normalizeText(errorData.scriptName) or "unknownscript")
	local lineNumber = tostring(tonumber(errorData.lineNumber) or 0)
	local sanitizedMessage = string.lower(
		normalizeText(errorData.sanitizedMessage) or ErrorReporter.SanitizeMessage(errorData.message)
	)
	local hashInput = table.concat({
		placeId,
		scriptName,
		lineNumber,
		sanitizedMessage,
	}, "|")

	return "TD2-ERR-" .. computeHash(hashInput)
end

local function buildErrorData(rawMessage, stackTrace, context)
	context = typeof(context) == "table" and context or {}

	local message, normalizedStackTrace = splitRawMessageAndStack(rawMessage, stackTrace)
	local placeInfo = getPlaceInfo()
	local scriptName, scriptFullName, lineNumber, system = resolveSourceContext(message, normalizedStackTrace, context)
	local playerName, playerUserId = resolvePlayerContext(context)
	local runMode, level, wave, phase = getLocationContext(context, placeInfo)
	local extraContext = sanitizeContextTable(context.extra or context.extraContext)

	extraContext.Environment = extraContext.Environment or (RunService:IsStudio() and "Studio" or "Live")
	extraContext.Location = extraContext.Location or (placeInfo.placeName == "Level" and "Run" or "Lobby")
	if placeInfo.rawPlaceName ~= placeInfo.placeName then
		extraContext.PlaceDisplayName = extraContext.PlaceDisplayName or placeInfo.rawPlaceName
	end
	if runMode then
		extraContext.RunMode = extraContext.RunMode or runMode
	end
	if level then
		extraContext.Level = extraContext.Level or level
	end
	if wave then
		extraContext.Wave = extraContext.Wave or wave
	end

	local errorData = {
		source = "roblox",
		game = GAME_NAME,
		placeId = game.PlaceId,
		placeName = placeInfo.placeName,
		jobId = normalizeText(game.JobId) or "N/A",
		serverTime = buildIsoTimestamp(),
		scriptName = truncateText(scriptName, 255) or "UnknownScript",
		scriptFullName = truncateText(scriptFullName, 512),
		lineNumber = lineNumber,
		message = truncateText(message, MAX_MESSAGE_LENGTH) or "Unknown error",
		sanitizedMessage = truncateText(ErrorReporter.SanitizeMessage(message), MAX_SANITIZED_MESSAGE_LENGTH) or "unknown error",
		stackTrace = truncateText(normalizedStackTrace, MAX_STACK_LENGTH),
		playerName = truncateText(playerName, 120),
		playerUserId = playerUserId,
		system = truncateText(system, 255) or "UnknownSystem",
		phase = truncateText(phase, 80),
		runMode = runMode,
		level = level,
		wave = wave,
		extraContext = extraContext,
		errorType = truncateText(context.errorType, 80) or (context.sourceType == "client" and "ClientError" or "ServerError"),
	}

	errorData.errorCode = ErrorReporter.BuildErrorCode(errorData)
	return errorData
end

local function touchOccurrence(errorData)
	local state = occurrenceState[errorData.errorCode]
	if not state then
		state = {
			count = 0,
			firstSeen = errorData.serverTime,
			lastSeen = errorData.serverTime,
			lastDispatchedAt = nil,
		}
		occurrenceState[errorData.errorCode] = state
	end

	state.count += 1
	state.lastSeen = errorData.serverTime
	errorData.occurrenceCount = state.count
	errorData.firstSeen = state.firstSeen
	errorData.lastSeen = state.lastSeen
	return state
end

local function shouldDispatch(state, forceSend)
	if forceSend == true then
		return true
	end

	if state.lastDispatchedAt == nil then
		return true
	end

	return (os.clock() - state.lastDispatchedAt) >= ERROR_CODE_COOLDOWN_SECONDS
end

function ErrorReporter.BuildDiscordPayload(errorData)
	local systemLabel = errorData.system or errorData.scriptName or "UnknownSystem"
	local title = string.format("[%s] %s error in %s", errorData.errorCode, systemLabel, errorData.placeName)
	local playerValue = errorData.playerName or "N/A"
	local userIdValue = errorData.playerUserId and tostring(errorData.playerUserId) or "N/A"
	local lineValue = errorData.lineNumber and tostring(errorData.lineNumber) or "N/A"

	return {
		username = "Roblox Error Reporter",
		embeds = {
			{
				title = title,
				color = errorData.errorType == "SystemWarning" and 16776960 or 16711680,
				fields = {
					{ name = "Error Code", value = errorData.errorCode, inline = false },
					{ name = "Error Type", value = errorData.errorType or "ServerError", inline = true },
					{ name = "Occurrences", value = tostring(errorData.occurrenceCount or 1), inline = true },
					{ name = "Place", value = errorData.placeName, inline = true },
					{ name = "Player", value = playerValue, inline = true },
					{ name = "UserId", value = userIdValue, inline = true },
					{ name = "System", value = errorData.system or "N/A", inline = false },
					{ name = "Script", value = errorData.scriptName or "N/A", inline = true },
					{ name = "Line", value = lineValue, inline = true },
					{ name = "Phase", value = errorData.phase or "N/A", inline = true },
					{ name = "Message", value = errorData.message or "N/A", inline = false },
					{ name = "Sanitized Message", value = errorData.sanitizedMessage or "N/A", inline = false },
					{ name = "Stack Trace", value = truncateText(errorData.stackTrace, 1000) or "N/A", inline = false },
					{ name = "Context", value = buildContextSummary(errorData.extraContext), inline = false },
					{ name = "JobId", value = errorData.jobId or "N/A", inline = false },
				},
				footer = {
					text = string.format(
						"First seen: %s | Last seen: %s",
						errorData.firstSeen or errorData.serverTime,
						errorData.lastSeen or errorData.serverTime
					),
				},
			},
		},
	}
end

function ErrorReporter.BuildGithubBridgePayload(errorData)
	local playerPayload = nil
	if errorData.playerUserId ~= nil or errorData.playerName ~= nil then
		playerPayload = {
			userId = errorData.playerUserId,
			name = errorData.playerName,
		}
	end

	return {
		source = errorData.source,
		game = errorData.game,
		errorCode = errorData.errorCode,
		errorType = errorData.errorType,
		placeId = errorData.placeId,
		placeName = errorData.placeName,
		jobId = errorData.jobId,
		serverTime = errorData.serverTime,
		firstSeen = errorData.firstSeen,
		lastSeen = errorData.lastSeen,
		scriptName = errorData.scriptName,
		scriptFullName = errorData.scriptFullName,
		lineNumber = errorData.lineNumber,
		message = errorData.message,
		sanitizedMessage = errorData.sanitizedMessage,
		stackTrace = errorData.stackTrace,
		occurrenceCount = errorData.occurrenceCount,
		player = playerPayload,
		context = {
			system = errorData.system,
			phase = errorData.phase,
			runMode = errorData.runMode,
			level = errorData.level,
			wave = errorData.wave,
			extra = cloneTable(errorData.extraContext),
		},
	}
end

function ErrorReporter.SendToDiscord(errorData)
	if DISCORD_WEBHOOK_URL == "" or DISCORD_WEBHOOK_URL == DISCORD_WEBHOOK_URL_PLACEHOLDER then
		if not warnedMissingDiscordWebhook then
			warn("[ErrorReporter] Set DISCORD_WEBHOOK_URL before enabling Discord error reporting.")
			warnedMissingDiscordWebhook = true
		end
		return false, "DiscordWebhookMissing"
	end

	return deliverJson(DISCORD_WEBHOOK_URL, ErrorReporter.BuildDiscordPayload(errorData), "Discord webhook")
end

function ErrorReporter.SendToGithubBridge(errorData)
	if GITHUB_BRIDGE_URL == "" or GITHUB_BRIDGE_URL == GITHUB_BRIDGE_URL_PLACEHOLDER then
		if not warnedMissingGithubBridge then
			warn("[ErrorReporter] Set GITHUB_BRIDGE_URL before enabling GitHub bridge error reporting.")
			warnedMissingGithubBridge = true
		end
		return false, "GithubBridgeMissing"
	end

	if GITHUB_BRIDGE_SECRET == "" or GITHUB_BRIDGE_SECRET == GITHUB_BRIDGE_SECRET_PLACEHOLDER then
		if not warnedMissingGithubBridgeSecret then
			warn("[ErrorReporter] Set GITHUB_BRIDGE_SECRET before enabling GitHub bridge error reporting.")
			warnedMissingGithubBridgeSecret = true
		end
		return false, "GithubBridgeSecretMissing"
	end

	return deliverJson(
		GITHUB_BRIDGE_URL,
		ErrorReporter.BuildGithubBridgePayload(errorData),
		"GitHub bridge",
		{
			["X-Roblox-Error-Secret"] = GITHUB_BRIDGE_SECRET,
		}
	)
end

function ErrorReporter.ReportError(rawMessage, stackTrace, context)
	local errorData = buildErrorData(rawMessage, stackTrace, context)
	local state = touchOccurrence(errorData)

	if not shouldDispatch(state, context and context.forceSend) then
		return false, "Cooldown", errorData
	end

	state.lastDispatchedAt = os.clock()

	local discordOk, discordReason = ErrorReporter.SendToDiscord(errorData)
	local githubOk, githubReason = ErrorReporter.SendToGithubBridge(errorData)

	errorData.delivery = {
		discord = discordReason,
		github = githubReason,
	}

	if discordOk or githubOk then
		return true, "Delivered", errorData
	end

	if discordReason == "DiscordWebhookMissing"
		and (githubReason == "GithubBridgeMissing" or githubReason == "GithubBridgeSecretMissing")
	then
		return false, "NoChannelsConfigured", errorData
	end

	if discordReason == "HttpDisabled" and githubReason == "HttpDisabled" then
		return false, "HttpDisabled", errorData
	end

	return false, "DispatchFailed", errorData
end

function ErrorReporter.ReportServerError(message, stackTrace, system, extraContext)
	return ErrorReporter.ReportError(message, stackTrace, {
		sourceType = "server",
		errorType = "ServerError",
		system = system,
		extra = extraContext,
	})
end

function ErrorReporter.ReportClientError(player, payload)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false, "InvalidPlayer"
	end

	payload = typeof(payload) == "table" and payload or {}
	if isClientRateLimited(player.UserId) then
		return false, "RateLimited"
	end

	return ErrorReporter.ReportError(payload.rawMessage or payload.message, payload.stackTrace or payload.stack, {
		sourceType = "client",
		errorType = "ClientError",
		player = player,
		system = payload.system,
		scriptName = payload.scriptName,
		lineNumber = payload.lineNumber,
		runMode = payload.runMode,
		level = payload.level,
		wave = payload.wave,
		phase = payload.phase,
		extra = payload.extraContext,
	})
end

function ErrorReporter.ReportSystemWarning(message, system, extraContext)
	return ErrorReporter.ReportError(message, nil, {
		sourceType = "server",
		errorType = "SystemWarning",
		system = system,
		extra = extraContext,
	})
end

function ErrorReporter.WarnIfHttpDisabled()
	return not isHttpEnabled()
end

function ErrorReporter.RunProtected(callbackName, callback, contextTemplate, ...)
	local args = table.pack(...)
	local results = nil
	local ok, errorMessage = xpcall(function()
		results = table.pack(callback(table.unpack(args, 1, args.n)))
	end, function(rawError)
		local context = cloneTable(contextTemplate)
		local extraContext = sanitizeContextTable(context.extra or context.extraContext)
		extraContext.Callback = extraContext.Callback or callbackName
		context.extra = extraContext

		if context.player == nil then
			for index = 1, args.n do
				local candidate = args[index]
				if typeof(candidate) == "Instance" and candidate:IsA("Player") then
					context.player = candidate
					break
				end
			end
		end

		ErrorReporter.ReportError(rawError, debug.traceback(nil, 2), context)
		return tostring(rawError)
	end)

	if not ok then
		return false, errorMessage
	end

	return true, table.unpack(results, 1, results.n)
end

function ErrorReporter.WrapCallback(callbackName, callback, contextTemplate)
	return function(...)
		local ok, resultOrError, extraA, extraB, extraC, extraD, extraE = ErrorReporter.RunProtected(
			callbackName,
			callback,
			contextTemplate,
			...
		)

		if not ok then
			return nil
		end

		return resultOrError, extraA, extraB, extraC, extraD, extraE
	end
end

return ErrorReporter
