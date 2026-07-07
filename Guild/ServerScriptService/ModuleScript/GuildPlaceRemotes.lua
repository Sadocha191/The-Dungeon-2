local GuildPlaceRemotes = {}

local REMOTE_EVENT_NAMES = {
	"RequestLobbyReturn",
	"LobbyReturnStatus",
	"GuildLocationOpened",
	"GuildTreasuryUpdated",
}

local REMOTE_FUNCTION_NAMES = {
	"GetGuildCastleState",
	"GetTreasury",
	"DepositToTreasury",
	"SpendFromTreasury",
}

local function getOrCreateFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemoteEvent(remoteEvents, name)
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

local function ensureRemoteFunction(remoteFunctions, name)
	local remoteFunction = remoteFunctions:FindFirstChild(name)
	if remoteFunction and remoteFunction:IsA("RemoteFunction") then
		return remoteFunction
	end
	if remoteFunction then
		remoteFunction:Destroy()
	end

	remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = remoteFunctions
	return remoteFunction
end

function GuildPlaceRemotes.EnsureAll(replicatedStorage)
	assert(replicatedStorage and replicatedStorage:IsA("ReplicatedStorage"), "[GuildPlaceRemotes] ReplicatedStorage is required")

	local remoteEvents = getOrCreateFolder(replicatedStorage, "RemoteEvents")
	local remoteFunctions = getOrCreateFolder(replicatedStorage, "RemoteFunctions")
	local remotes = {}

	for _, name in ipairs(REMOTE_EVENT_NAMES) do
		remotes[name] = ensureRemoteEvent(remoteEvents, name)
	end
	for _, name in ipairs(REMOTE_FUNCTION_NAMES) do
		remotes[name] = ensureRemoteFunction(remoteFunctions, name)
	end

	return remotes
end

return GuildPlaceRemotes
