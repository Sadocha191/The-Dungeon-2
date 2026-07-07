local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GuildUpdateBroadcaster = {}

local guildUpdatedRemote = nil

local function getGuildUpdatedRemote()
	if guildUpdatedRemote and guildUpdatedRemote.Parent then
		return guildUpdatedRemote
	end

	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = ReplicatedStorage
	end

	local event = remoteEvents:FindFirstChild("GuildUpdated")
	if event and event:IsA("RemoteEvent") then
		guildUpdatedRemote = event
		return event
	end
	if event then
		event:Destroy()
	end

	event = Instance.new("RemoteEvent")
	event.Name = "GuildUpdated"
	event.Parent = remoteEvents
	guildUpdatedRemote = event
	return event
end

local function fireGuildUpdated(player, payload, sent)
	if not player or not player.Parent then
		return
	end
	if sent[player.UserId] then
		return
	end
	sent[player.UserId] = true

	local remote = getGuildUpdatedRemote()
	pcall(function()
		remote:FireClient(player, payload)
	end)
end

function GuildUpdateBroadcaster.Broadcast(guild, reason, extraPlayers)
	if not guild or typeof(guild.guildId) ~= "string" then
		return
	end

	local payload = {
		GuildId = guild.guildId,
		Reason = reason or "Updated",
		ServerNowUnix = os.time(),
	}
	local sent = {}

	for _, member in pairs(guild.members or {}) do
		if typeof(member) == "table" then
			fireGuildUpdated(Players:GetPlayerByUserId(member.userId), payload, sent)
		end
	end

	for _, player in ipairs(extraPlayers or {}) do
		fireGuildUpdated(player, payload, sent)
	end
end

return GuildUpdateBroadcaster
