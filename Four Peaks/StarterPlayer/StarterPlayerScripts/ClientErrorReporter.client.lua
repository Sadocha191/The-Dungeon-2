local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local reportClientErrorRemote = remotesFolder:WaitForChild("ReportClientError")

local DUPLICATE_WINDOW_SECONDS = 10
local recentErrors = {}

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

local function buildPayload(rawMessage)
	local message, stack = splitMessageAndStack(rawMessage)
	if not message then
		return nil
	end

	local runMode = readContextValue({ "RunMode" })
	local level = readContextValue({ "CurrentLevel", "LevelId", "LevelKey" })
	local wave = readContextValue({ "CurrentWave", "Wave" })
	local location = (runMode or level) and "Run" or "Lobby"

	return {
		message = truncateText(message, 700),
		stack = truncateText(stack, 1000),
		system = truncateText(inferSystem(message, stack), 256),
		runMode = truncateText(runMode, 80),
		level = truncateText(level, 120),
		wave = truncateText(wave, 80),
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
