-- SCRIPT: LobbyProgress.server.lua
-- GDZIE: ServerScriptService/LobbyProgress.server.lua
-- CO: wysyła level/xp/nextXp/coins z PlayerData do klienta

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local PlayerData = require(serverModules:WaitForChild("PlayerData"))

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
	PlayerProgressEvent:FireClient(plr, {
		type = "progress",
		level = d.level,
		xp = d.xp,
		nextXp = d.nextXp,
		coins = d.coins,
	})
end

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
