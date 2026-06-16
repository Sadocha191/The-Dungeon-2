local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local servicesFolder = ServerScriptService:FindFirstChild("Services")
local ErrorReporter = servicesFolder and servicesFolder:FindFirstChild("ErrorReporter") and require(servicesFolder.ErrorReporter) or nil

local DailyLoginService = require(serverModules:WaitForChild("DailyLoginService"))

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

	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remoteFunctions
	return fn
end

local GetDailyLoginState = ensureFunction("GetDailyLoginState")
local ClaimDailyLoginReward = ensureFunction("ClaimDailyLoginReward")

GetDailyLoginState.OnServerInvoke = protect("DailyLoginService.GetState", {
	system = "DailyLoginService",
	phase = "lobby",
}, function(player)
	return DailyLoginService.GetState(player)
end)

ClaimDailyLoginReward.OnServerInvoke = protect("DailyLoginService.Claim", {
	system = "DailyLoginService",
	phase = "lobby",
}, function(player)
	return DailyLoginService.Claim(player)
end)

print("[DailyLoginRemotes] Ready")
