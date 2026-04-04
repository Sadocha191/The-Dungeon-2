local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local ErrorReportService = {}

local DISCORD_WEBHOOK_URL = "PASTE_YOUR_WEBHOOK_HERE"

local DEDUPE_WINDOW_SECONDS = 30
local CLIENT_RATE_LIMIT_WINDOW_SECONDS = 30
local CLIENT_RATE_LIMIT_MAX_EVENTS = 6
local MAX_CONTEXT_ITEMS = 10

local recentReports = {}
local clientRateState = {}
local cachedPlaceName = nil
local warnedMissingWebhook = false

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

local function formatFieldValue(value, maxLength)
	return truncateText(value, maxLength) or "N/A"
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

local function cleanupRecentReports(now)
	for key, expiresAt in pairs(recentReports) do
		if expiresAt <= now then
			recentReports[key] = nil
		end
	end
end

local function isDuplicateReport(reportKey)
	local now = os.clock()
	cleanupRecentReports(now)

	local expiresAt = recentReports[reportKey]
	if expiresAt and expiresAt > now then
		return true
	end

	recentReports[reportKey] = now + DEDUPE_WINDOW_SECONDS
	return false
end

local function isClientRateLimited(userId)
	local now = os.clock()
	local state = clientRateState[userId]

	if not state or (now - state.windowStart) >= CLIENT_RATE_LIMIT_WINDOW_SECONDS then
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

local function getPlaceName()
	if cachedPlaceName then
		return cachedPlaceName
	end

	local placeName = nil
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)

	if ok and typeof(info) == "table" and typeof(info.Name) == "string" and info.Name ~= "" then
		placeName = info.Name
	end

	cachedPlaceName = placeName or normalizeText(game.Name) or "N/A"
	return cachedPlaceName
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

local function mergeContextLines(userContext, autoContext)
	local merged = {}
	local seen = {}

	local function addContextEntries(contextTable)
		if typeof(contextTable) ~= "table" then
			return
		end

		local keys = {}
		for key in pairs(contextTable) do
			if typeof(key) == "string" then
				table.insert(keys, key)
			end
		end
		table.sort(keys)

		for _, key in ipairs(keys) do
			if #merged >= MAX_CONTEXT_ITEMS then
				break
			end

			if seen[key] then
				continue
			end

			local text = truncateText(contextTable[key], 180)
			if text then
				seen[key] = true
				table.insert(merged, string.format("%s: %s", key, text))
			end
		end
	end

	addContextEntries(autoContext)
	addContextEntries(userContext)

	if #merged == 0 then
		return "N/A"
	end

	return formatFieldValue(table.concat(merged, "\n"), 1024)
end

local function buildReportRecord(baseReport)
	local player = baseReport.player
	local playerName = player and player.Name or nil
	local userId = player and tostring(player.UserId) or nil
	local placeId = tostring(game.PlaceId)
	local placeName = getPlaceName()
	local jobId = normalizeText(game.JobId)

	local runMode = readAttribute(player, { "RunMode" })
		or readAttribute(workspace, { "RunMode" })
		or truncateText(baseReport.runMode, 80)

	local level = readAttribute(player, { "CurrentLevel", "LevelId", "LevelKey" })
		or readAttribute(workspace, { "CurrentLevel", "LevelId", "LevelKey" })
		or truncateText(baseReport.level, 80)
		or placeName

	local wave = readAttribute(player, { "CurrentWave", "Wave" })
		or readAttribute(workspace, { "CurrentWave", "Wave" })
		or truncateText(baseReport.wave, 80)

	local location = nil
	if player then
		location = (runMode or readAttribute(player, { "CurrentLevel", "LevelId", "LevelKey" })) and "Run" or "Lobby"
	end

	local extraContext = mergeContextLines(baseReport.extraContext, {
		Environment = RunService:IsStudio() and "Studio" or "Live",
		Location = location or "N/A",
	})

	local report = {
		errorType = formatFieldValue(baseReport.errorType, 128),
		title = formatFieldValue(baseReport.title, 128),
		color = baseReport.color or 16711680,
		player = formatFieldValue(playerName, 256),
		userId = formatFieldValue(userId, 64),
		system = formatFieldValue(baseReport.system, 512),
		message = formatFieldValue(baseReport.message, 1024),
		stack = formatFieldValue(baseReport.stack, 1024),
		placeId = formatFieldValue(placeId, 64),
		placeName = formatFieldValue(placeName, 256),
		jobId = formatFieldValue(jobId, 256),
		runMode = formatFieldValue(runMode, 128),
		level = formatFieldValue(level, 256),
		wave = formatFieldValue(wave, 128),
		extraContext = extraContext,
	}

	report.dedupeKey = table.concat({
		report.errorType,
		report.message,
		report.system,
		firstLineOf(report.stack),
		report.placeId,
	}, "|")

	return report
end

function ErrorReportService.BuildDiscordPayload(report)
	local footerTimestamp = os.date("!%Y-%m-%d %H:%M:%S UTC")

	return {
		username = "Roblox Error Reporter",
		embeds = {
			{
				title = report.title,
				color = report.color,
				fields = {
					{ name = "Error Type", value = report.errorType, inline = true },
					{ name = "Player", value = report.player, inline = true },
					{ name = "UserId", value = report.userId, inline = true },
					{ name = "System", value = report.system, inline = false },
					{ name = "Message", value = report.message, inline = false },
					{ name = "Stack", value = report.stack, inline = false },
					{ name = "PlaceId", value = report.placeId, inline = true },
					{ name = "PlaceName", value = report.placeName, inline = true },
					{ name = "JobId", value = report.jobId, inline = false },
					{ name = "RunMode", value = report.runMode, inline = true },
					{ name = "Level", value = report.level, inline = true },
					{ name = "Wave", value = report.wave, inline = true },
					{ name = "Extra Context", value = report.extraContext, inline = false },
				},
				footer = {
					text = string.format(
						"PlaceId: %s | JobId: %s | %s",
						report.placeId,
						report.jobId,
						footerTimestamp
					),
				},
			},
		},
	}
end

function ErrorReportService.SendReportToDiscord(report)
	if DISCORD_WEBHOOK_URL == "" or DISCORD_WEBHOOK_URL == "PASTE_YOUR_WEBHOOK_HERE" then
		if not warnedMissingWebhook then
			warn("[ErrorReportService] Set DISCORD_WEBHOOK_URL before enabling Discord error reporting.")
			warnedMissingWebhook = true
		end
		return false, "WebhookMissing"
	end

	local payload = ErrorReportService.BuildDiscordPayload(report)
	local encodeOk, encodedPayload = pcall(function()
		return HttpService:JSONEncode(payload)
	end)

	if not encodeOk then
		warn("[ErrorReportService] Failed to encode Discord payload:", encodedPayload)
		return false, "EncodeFailed"
	end

	local requestOk, response = pcall(function()
		return HttpService:RequestAsync({
			Url = DISCORD_WEBHOOK_URL,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = encodedPayload,
		})
	end)

	if not requestOk then
		warn("[ErrorReportService] Discord webhook request failed:", response)
		return false, "RequestFailed"
	end

	if not response.Success then
		warn(
			"[ErrorReportService] Discord webhook returned an error:",
			response.StatusCode,
			response.StatusMessage
		)
		return false, "WebhookRejected"
	end

	return true
end

function ErrorReportService.ReportServerError(message, stack, system, extraContext)
	local report = buildReportRecord({
		errorType = "ServerError",
		title = "Server Error",
		color = 16711680,
		message = message,
		stack = stack,
		system = system,
		extraContext = extraContext,
	})

	if isDuplicateReport(report.dedupeKey) then
		return false, "Duplicate"
	end

	return ErrorReportService.SendReportToDiscord(report)
end

function ErrorReportService.ReportClientError(player, payload)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false, "InvalidPlayer"
	end

	payload = typeof(payload) == "table" and payload or {}

	local report = buildReportRecord({
		errorType = "ClientError",
		title = "Client Error",
		color = 16711680,
		player = player,
		message = payload.message,
		stack = payload.stack,
		system = payload.system,
		runMode = payload.runMode,
		level = payload.level,
		wave = payload.wave,
		extraContext = payload.extraContext,
	})

	if isDuplicateReport(report.dedupeKey) then
		return false, "Duplicate"
	end

	if isClientRateLimited(player.UserId) then
		return false, "RateLimited"
	end

	return ErrorReportService.SendReportToDiscord(report)
end

function ErrorReportService.ReportSystemWarning(message, system, extraContext)
	local report = buildReportRecord({
		errorType = "SystemWarning",
		title = "System Warning",
		color = 16776960,
		message = message,
		stack = "N/A",
		system = system,
		extraContext = extraContext,
	})

	if isDuplicateReport(report.dedupeKey) then
		return false, "Duplicate"
	end

	return ErrorReportService.SendReportToDiscord(report)
end

return ErrorReportService
