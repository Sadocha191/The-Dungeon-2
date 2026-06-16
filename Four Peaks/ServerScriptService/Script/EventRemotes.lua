local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local servicesFolder = ServerScriptService:FindFirstChild("Services")
local ErrorReporter = servicesFolder and servicesFolder:FindFirstChild("ErrorReporter") and require(servicesFolder.ErrorReporter) or nil

local EventService = require(serverModules:WaitForChild("EventService"))

local function protect(callbackName, context, callback)
	if ErrorReporter then
		return ErrorReporter.WrapCallback(callbackName, callback, context)
	end
	return callback
end

local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctions then
	remoteFunctions = Instance.new("Folder")
	remoteFunctions.Name = "RemoteFunctions"
	remoteFunctions.Parent = ReplicatedStorage
end

local function ensureFunction(name)
	local fn = remoteFunctions:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then
		return fn
	end
	if fn then
		fn:Destroy()
	end
	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remoteFunctions
	return fn
end

local GetEventsState = ensureFunction("GetEventsState")
local ClaimEventReward = ensureFunction("ClaimEventReward")

local function fallbackState(message)
	return {
		Success = false,
		Message = message or "Events unavailable.",
		ServerNowUnix = os.time(),
		Events = {},
	}
end

GetEventsState.OnServerInvoke = protect("EventService.GetState", {
	system = "EventService",
	phase = "lobby",
}, function(player)
	local ok, result = pcall(function()
		return EventService.GetState(player)
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	warn("[EventRemotes] GetEventsState failed:", result)
	return fallbackState("Events are unavailable.")
end)

ClaimEventReward.OnServerInvoke = protect("EventService.Claim", {
	system = "EventService",
	phase = "lobby",
}, function(player, eventId, claimType, targetId)
	if typeof(eventId) ~= "string" or typeof(claimType) ~= "string" then
		return {
			Success = false,
			Message = "Invalid claim request.",
			Rewards = {},
			State = fallbackState("Invalid claim request."),
		}
	end
	local ok, result = pcall(function()
		return EventService.Claim(player, eventId, claimType, targetId)
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	warn("[EventRemotes] ClaimEventReward failed:", result)
	return {
		Success = false,
		Message = "Claim failed.",
		Rewards = {},
		State = fallbackState("Claim failed."),
	}
end)

print("[EventRemotes] Ready")
