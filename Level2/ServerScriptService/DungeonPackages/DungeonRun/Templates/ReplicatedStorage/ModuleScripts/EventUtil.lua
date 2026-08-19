local RunService = game:GetService("RunService")

local EventsConfig = require(script.Parent:WaitForChild("EventsConfig"))

local EventUtil = {}
local ZERO_DATE_WARNED = {}

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, nested in pairs(value) do
		copy[key] = deepCopy(nested)
	end
	return copy
end

local function asUnix(value)
	return math.floor(tonumber(value) or 0)
end

local function warnZeroDates(eventConfig)
	local eventId = tostring(eventConfig and eventConfig.Id or "UnknownEvent")
	if ZERO_DATE_WARNED[eventId] then
		return
	end
	ZERO_DATE_WARNED[eventId] = true
	warn(string.format("[EventUtil] Event %s has StartUnix/EndUnix set to 0. It is active only in Studio/dev mode; live servers treat it as ended.", eventId))
end

function EventUtil.GetUTCNow()
	return os.time()
end

function EventUtil.GetEventStatus(eventConfig, nowUnix)
	if typeof(eventConfig) ~= "table" or eventConfig.IsEnabled == false then
		return "Ended"
	end
	local now = math.floor(tonumber(nowUnix) or EventUtil.GetUTCNow())
	local startUnix = asUnix(eventConfig.StartUnix)
	local endUnix = asUnix(eventConfig.EndUnix)
	if startUnix <= 0 or endUnix <= 0 then
		warnZeroDates(eventConfig)
		if RunService:IsStudio() then
			return "Active"
		end
		return "Ended"
	end
	if now < startUnix then
		return "ComingSoon"
	end
	if now <= endUnix then
		return "Active"
	end
	return "Ended"
end

function EventUtil.IsEventActive(eventConfig, nowUnix)
	return EventUtil.GetEventStatus(eventConfig, nowUnix) == "Active"
end

function EventUtil.GetTimeTargetUnix(eventConfig, nowUnix)
	local status = EventUtil.GetEventStatus(eventConfig, nowUnix)
	if status == "ComingSoon" then
		return asUnix(eventConfig.StartUnix)
	elseif status == "Active" then
		local endUnix = asUnix(eventConfig.EndUnix)
		if endUnix <= 0 then
			return math.floor(tonumber(nowUnix) or EventUtil.GetUTCNow()) + 86400
		end
		return endUnix
	end
	return 0
end

function EventUtil.FormatTimeRemaining(seconds)
	seconds = math.floor(tonumber(seconds) or 0)
	if seconds <= 0 then
		return "Ended"
	end
	local days = math.floor(seconds / 86400)
	if days > 0 then
		return string.format("%dd %dh", days, math.floor((seconds % 86400) / 3600))
	end
	local hours = math.floor(seconds / 3600)
	if hours > 0 then
		return string.format("%dh %dm", hours, math.floor((seconds % 3600) / 60))
	end
	return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
end

function EventUtil.SortEvents(events)
	local sorted = {}
	for _, eventConfig in ipairs(events or {}) do
		if typeof(eventConfig) == "table" then
			table.insert(sorted, eventConfig)
		end
	end
	table.sort(sorted, function(a, b)
		local aOrder = tonumber(a.SortOrder) or 0
		local bOrder = tonumber(b.SortOrder) or 0
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
		local aStart = asUnix(a.StartUnix)
		local bStart = asUnix(b.StartUnix)
		if aStart ~= bStart then
			return aStart < bStart
		end
		return tostring(a.Id or "") < tostring(b.Id or "")
	end)
	return sorted
end

function EventUtil.GetEnabledEvents()
	local enabled = {}
	for _, eventConfig in ipairs(EventsConfig or {}) do
		if typeof(eventConfig) == "table" and eventConfig.IsEnabled ~= false then
			table.insert(enabled, eventConfig)
		end
	end
	return EventUtil.SortEvents(enabled)
end

function EventUtil.BuildPublicEventConfig(eventConfig)
	if typeof(eventConfig) ~= "table" then
		return nil
	end
	return {
		Id = tostring(eventConfig.Id or ""),
		DisplayName = tostring(eventConfig.DisplayName or eventConfig.Id or "Event"),
		Description = tostring(eventConfig.Description or ""),
		StartUnix = asUnix(eventConfig.StartUnix),
		EndUnix = asUnix(eventConfig.EndUnix),
		Icon = tostring(eventConfig.Icon or ""),
		BannerImage = tostring(eventConfig.BannerImage or ""),
		EventType = tostring(eventConfig.EventType or "Event"),
		SortOrder = tonumber(eventConfig.SortOrder) or 0,
		IsEnabled = eventConfig.IsEnabled ~= false,
		Tasks = deepCopy(eventConfig.Tasks or {}),
		Milestones = deepCopy(eventConfig.Milestones or {}),
		FinalRewards = deepCopy(eventConfig.FinalRewards or {}),
	}
end

return EventUtil
