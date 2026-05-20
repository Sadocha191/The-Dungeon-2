local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local reportClientErrorRemote = remotesFolder:WaitForChild("ReportClientError")

local CLIENT_TEST_ATTRIBUTE = "ErrorWebhookClientTestToken"
local CLIENT_TEST_TARGET_ATTRIBUTE = "ErrorWebhookClientTestUserId"
local DUPLICATE_WINDOW_SECONDS = 10
local recentErrors = {}
local lastClientTestToken = nil

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
		return ""
	end

	local newlineIndex = string.find(text, "\n", 1, true)
	if newlineIndex then
		return string.sub(text, 1, newlineIndex - 1)
	end

	return text
end

local function cleanupRecentErrors(now)
	for key, expiresAt in pairs(recentErrors) do
		if expiresAt <= now then
			recentErrors[key] = nil
		end
	end
end

local function normalizeTriggerToken(value)
	if value == nil then
		return nil
	end

	local valueType = typeof(value)
	if valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" then
		return nil
	end

	return normalizeText(valueType == "string" and value or tostring(value))
end

local function isMatchingClientTestTarget(targetValue)
	local valueType = typeof(targetValue)
	if valueType == "number" then
		return targetValue == player.UserId
	end

	if valueType == "string" then
		local maybeUserId = tonumber(targetValue)
		if maybeUserId then
			return maybeUserId == player.UserId
		end
		return string.lower(targetValue) == string.lower(player.Name)
	end

	return targetValue == nil
end

local function triggerClientErrorTest(rawToken)
	local token = normalizeTriggerToken(rawToken)
	if not token or token == lastClientTestToken then
		return
	end

	if not isMatchingClientTestTarget(ReplicatedStorage:GetAttribute(CLIENT_TEST_TARGET_ATTRIBUTE)) then
		return
	end

	lastClientTestToken = token

	task.defer(function()
		error(
			string.format(
				"[ErrorWebhookTest][Client][%s][PlaceId=%d][JobId=%s][UserId=%d] token=%s",
				game.Name,
				game.PlaceId,
				game.JobId,
				player.UserId,
				token
			),
			0
		)
	end)
end

local function readContextValue(attributeNames)
	for _, attributeName in ipairs(attributeNames) do
		local value = player:GetAttribute(attributeName)
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

		local workspaceValue = workspace:GetAttribute(attributeName)
		local workspaceValueType = typeof(workspaceValue)

		if workspaceValueType == "string" then
			local text = normalizeText(workspaceValue)
			if text then
				return text
			end
		elseif workspaceValueType == "number" then
			return tostring(workspaceValue)
		elseif workspaceValueType == "boolean" then
			return workspaceValue and "true" or "false"
		end
	end

	return nil
end

local function splitMessageAndStack(rawMessage)
	local normalized = normalizeText(rawMessage)
	if not normalized then
		return nil, nil
	end

	local newlineIndex = string.find(normalized, "\n", 1, true)
	if not newlineIndex then
		return normalized, nil
	end

	local message = string.sub(normalized, 1, newlineIndex - 1)
	local stack = string.sub(normalized, newlineIndex + 1)
	return message, stack
end

local function inferSystem(message, stack)
	local source = string.match(message or "", "^(.-):%d+")
	if source then
		source = normalizeText(source)
		if source then
			return source
		end
	end

	source = string.match(stack or "", "^(.-):%d+")
	if source then
		source = normalizeText(source)
		if source then
			return source
		end
	end

	return "Client"
end

local function inferScriptDetails(message, stack)
	local scriptPath, lineNumber = string.match(message or "", "([%w%._/%-\\ ]+):(%d+)")
	if not scriptPath then
		scriptPath, lineNumber = string.match(stack or "", "([%w%._/%-\\ ]+):(%d+)")
	end
	if not scriptPath then
		return nil, nil
	end

	local scriptName = scriptPath:match("([^%.\\/]+)$") or scriptPath
	scriptName = scriptName:gsub("%.lua$", "")
	return scriptName, tonumber(lineNumber)
end

local function buildPayload(rawMessage)
	local message, stack = splitMessageAndStack(rawMessage)
	if not message then
		return nil
	end

	local runMode = readContextValue({ "RunMode" })
	local level = readContextValue({ "CurrentLevel", "LevelId", "LevelKey" })
	local wave = readContextValue({ "CurrentWave", "Wave" })
	local location = (runMode or level) and "Run" or "Lobby"
	local scriptName, lineNumber = inferScriptDetails(message, stack)
	local phase = location == "Run" and "combat" or "lobby"

	return {
		rawMessage = truncateText(rawMessage, 1600),
		message = truncateText(message, 700),
		stack = truncateText(stack, 1000),
		stackTrace = truncateText(stack, 1000),
		system = truncateText(inferSystem(message, stack), 256),
		scriptName = truncateText(scriptName, 256),
		lineNumber = lineNumber,
		runMode = truncateText(runMode, 80),
		level = truncateText(level, 120),
		wave = truncateText(wave, 80),
		phase = phase,
		extraContext = {
			Location = location,
		},
	}
end

local function buildDedupKey(payload)
	return table.concat({
		payload.message or "",
		payload.system or "",
		firstLineOf(payload.stack),
	}, "|")
end

ReplicatedStorage:GetAttributeChangedSignal(CLIENT_TEST_ATTRIBUTE):Connect(function()
	triggerClientErrorTest(ReplicatedStorage:GetAttribute(CLIENT_TEST_ATTRIBUTE))
end)

triggerClientErrorTest(ReplicatedStorage:GetAttribute(CLIENT_TEST_ATTRIBUTE))

LogService.MessageOut:Connect(function(message, messageType)
	if messageType ~= Enum.MessageType.MessageError then
		return
	end

	local payload = buildPayload(message)
	if not payload then
		return
	end

	local now = os.clock()
	cleanupRecentErrors(now)

	local dedupeKey = buildDedupKey(payload)
	local expiresAt = recentErrors[dedupeKey]
	if expiresAt and expiresAt > now then
		return
	end

	recentErrors[dedupeKey] = now + DUPLICATE_WINDOW_SECONDS
	reportClientErrorRemote:FireServer(payload)
end)
