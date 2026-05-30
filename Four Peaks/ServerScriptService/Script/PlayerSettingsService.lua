local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))

local DEFAULTS = {
	ShowFPSCounter = false,
	ShowScreenButtons = true,
	CameraZoomPreset = "Medium",
}

local VALID_CAMERA_PRESETS = {
	Close = true,
	Medium = true,
	Far = true,
}

local function ensureFolder(name: string): Folder
	local folder = ReplicatedStorage:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = ReplicatedStorage
	return folder
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end

	remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remoteEvents = ensureFolder("RemoteEvents")
local remoteFunctions = ensureFolder("RemoteFunctions")

local PlayerSettingsEvent = ensureRemoteEvent(remoteEvents, "PlayerSettingsEvent")
local RF_GetPlayerSettings = ensureRemoteFunction(remoteFunctions, "RF_GetPlayerSettings")

local function sanitizeSetting(name: string, value: any)
	if name == "ShowFPSCounter" or name == "ShowScreenButtons" then
		if typeof(value) == "boolean" then
			return value
		end
	elseif name == "CameraZoomPreset" then
		if typeof(value) == "string" and VALID_CAMERA_PRESETS[value] then
			return value
		end
	end

	return DEFAULTS[name]
end

local function getRawSettings(player: Player)
	local state = PlayerStateStore.Get(player) or PlayerStateStore.Load(player)
	if typeof(state.Settings) ~= "table" then
		state.Settings = {}
	end

	return state.Settings
end

local function buildSnapshot(rawSettings: any)
	local snapshot = {}
	for name in pairs(DEFAULTS) do
		snapshot[name] = sanitizeSetting(name, rawSettings and rawSettings[name])
	end
	return snapshot
end

local function applySettings(player: Player, values: any)
	if typeof(values) ~= "table" then
		return
	end

	local rawSettings = getRawSettings(player)
	local changed = false

	for name in pairs(DEFAULTS) do
		if values[name] ~= nil then
			local nextValue = sanitizeSetting(name, values[name])
			if rawSettings[name] ~= nextValue then
				rawSettings[name] = nextValue
				changed = true
			end
		end
	end

	if changed then
		PlayerStateStore.MarkDirty(player, "settings")
	end
end

RF_GetPlayerSettings.OnServerInvoke = function(player: Player)
	return buildSnapshot(getRawSettings(player))
end

PlayerSettingsEvent.OnServerEvent:Connect(function(player: Player, payload: any)
	if typeof(payload) ~= "table" or payload.type ~= "set" then
		return
	end

	applySettings(player, payload.values)
end)
