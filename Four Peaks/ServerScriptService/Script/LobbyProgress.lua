-- SCRIPT: LobbyProgress.server.lua
-- GDZIE: ServerScriptService/LobbyProgress.server.lua
-- CO: wysyła level/xp/nextXp/coins z PlayerData do klienta

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local PlayerData = require(serverModules:WaitForChild("PlayerData"))

local ACCOUNT_LEVEL_ATTRIBUTE = "AccountLevel"
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
local presentationConfigModule = moduleFolder and moduleFolder:FindFirstChild("LobbyPresentationConfig")
if presentationConfigModule then
	local ok, presentationConfig = pcall(require, presentationConfigModule)
	if ok and typeof(presentationConfig) == "table" and typeof(presentationConfig.AccountLevelAttribute) == "string" then
		ACCOUNT_LEVEL_ATTRIBUTE = presentationConfig.AccountLevelAttribute
	end
end

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local PlayerProgressEvent = remoteEvents:FindFirstChild("PlayerProgressEvent")
if not PlayerProgressEvent then
	PlayerProgressEvent = Instance.new("RemoteEvent")
	PlayerProgressEvent.Name = "PlayerProgressEvent"
	PlayerProgressEvent.Parent = remoteEvents
end

local function send(plr: Player)
	local d = PlayerData.Get(plr)
	local levelRecords = PlayerData.GetLevelRecordsSnapshot and PlayerData.GetLevelRecordsSnapshot(plr) or {}
	local accountLevel = math.max(1, math.floor(tonumber(d.level) or 1))
	if plr:GetAttribute(ACCOUNT_LEVEL_ATTRIBUTE) ~= accountLevel then
		plr:SetAttribute(ACCOUNT_LEVEL_ATTRIBUTE, accountLevel)
	end

	PlayerProgressEvent:FireClient(plr, {
		type = "progress",
		level = accountLevel,
		xp = d.xp,
		nextXp = d.nextXp,
		silver = d.silver,
		coins = d.silver,
		souls = d.souls,
		levelRecords = levelRecords,
	})
end

PlayerProgressEvent.OnServerEvent:Connect(function(plr: Player, payload: any)
	if not plr or not plr.Parent then
		return
	end

	if payload == nil then
		send(plr)
		return
	end

	if typeof(payload) ~= "table" then
		return
	end

	local requestType = tostring(payload.type or "")
	if requestType == "request" or requestType == "requestSync" or requestType == "sync" then
		send(plr)
	end
end)

Players.PlayerAdded:Connect(function(plr)
	task.defer(function()
		send(plr)
	end)
end)

-- opcjonalnie: odświeżaj co kilka sekund (jeśli coins będą się zmieniać w lobby)
task.spawn(function()
	while true do
		for _, plr in ipairs(Players:GetPlayers()) do
			send(plr)
		end
		task.wait(2)
	end
end)

print("[LobbyProgress] Ready (PlayerData -> HUD)")
