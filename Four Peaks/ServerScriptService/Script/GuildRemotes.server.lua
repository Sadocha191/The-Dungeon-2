local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local servicesFolder = ServerScriptService:FindFirstChild("Services")
local ErrorReporter = servicesFolder and servicesFolder:FindFirstChild("ErrorReporter") and require(servicesFolder.ErrorReporter) or nil

local GuildService = require(serverModules:WaitForChild("GuildService"))

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

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
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

local function ensureEvent(name)
	local event = remoteEvents:FindFirstChild(name)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	if event then
		event:Destroy()
	end
	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remoteEvents
	return event
end

local GetGuildState = ensureFunction("GetGuildState")
local SearchGuilds = ensureFunction("SearchGuilds")
local GuildAction = ensureFunction("GuildAction")
local GuildUpdated = ensureEvent("GuildUpdated")

local function fallbackState(message)
	return {
		Success = false,
		Message = message or "Guilds are unavailable.",
		ServerNowUnix = os.time(),
		Guild = nil,
		Membership = nil,
		CanManage = false,
		CanManageJoin = false,
		PlayerResources = {},
		Invites = {},
		Config = {},
	}
end

GetGuildState.OnServerInvoke = protect("GuildService.GetState", {
	system = "GuildService",
	phase = "lobby",
}, function(player)
	local ok, result = pcall(function()
		return GuildService.GetState(player)
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	warn("[GuildRemotes] GetGuildState failed:", result)
	return fallbackState("Guild state failed.")
end)

SearchGuilds.OnServerInvoke = protect("GuildService.Search", {
	system = "GuildService",
	phase = "lobby",
}, function(player, query)
	local ok, result = pcall(function()
		return GuildService.Search(player, query)
	end)
	if ok and typeof(result) == "table" then
		return result
	end
	warn("[GuildRemotes] SearchGuilds failed:", result)
	return fallbackState("Guild search failed.")
end)

GuildAction.OnServerInvoke = protect("GuildService.Action", {
	system = "GuildService",
	phase = "lobby",
}, function(player, action, payload)
	if typeof(action) ~= "string" then
		return fallbackState("Invalid guild action.")
	end
	payload = typeof(payload) == "table" and payload or {}

	local ok, result = pcall(function()
		if action == "CreateGuild" then
			return GuildService.CreateGuild(player, payload.name)
		elseif action == "JoinGuild" then
			return GuildService.JoinGuild(player, payload.guildId)
		elseif action == "RequestJoin" then
			return GuildService.RequestJoin(player, payload.guildId)
		elseif action == "LeaveGuild" then
			return GuildService.LeaveGuild(player)
		elseif action == "EditDescription" then
			return GuildService.EditDescription(player, payload.description)
		elseif action == "SetPrivacy" then
			return GuildService.SetPrivacy(player, payload.privacy)
		elseif action == "AcceptJoinRequest" then
			return GuildService.AcceptJoinRequest(player, payload.userId)
		elseif action == "RejectJoinRequest" then
			return GuildService.RejectJoinRequest(player, payload.userId)
		elseif action == "SendInvite" then
			return GuildService.SendInvite(player, payload.target)
		elseif action == "CancelInvite" then
			return GuildService.CancelInvite(player, payload.userId)
		elseif action == "AcceptInvite" then
			return GuildService.AcceptInvite(player, payload.guildId)
		elseif action == "DeclineInvite" then
			return GuildService.DeclineInvite(player, payload.guildId)
		elseif action == "PromoteMember" then
			return GuildService.SetMemberRole(player, payload.userId, "Officer")
		elseif action == "DemoteMember" then
			return GuildService.SetMemberRole(player, payload.userId, "Member")
		elseif action == "KickMember" then
			return GuildService.KickMember(player, payload.userId)
		elseif action == "DisbandGuild" then
			return GuildService.DisbandGuild(player)
		elseif action == "Donate" then
			return GuildService.Donate(player, payload.resourceId, payload.amount)
		elseif action == "Upgrade" then
			return GuildService.Upgrade(player, payload.upgradeId)
		elseif action == "TeleportToCastle" then
			return GuildService.TeleportToCastle(player)
		elseif action == "Refresh" then
			return GuildService.GetState(player)
		end
		return fallbackState("Unknown guild action.")
	end)

	if ok and typeof(result) == "table" then
		return result
	end

	warn("[GuildRemotes] GuildAction failed:", action, result)
	return fallbackState("Guild action failed.")
end)

print("[GuildRemotes] Ready")
