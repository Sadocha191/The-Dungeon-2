-- SCRIPT: LobbyProgress.server.lua
-- GDZIE: ServerScriptService/LobbyProgress.server.lua
-- CO: wysyła level/xp/nextXp/coins z PlayerData do klienta

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local PlayerProgressEvent = remotes:FindFirstChild("PlayerProgressEvent")
if not PlayerProgressEvent then
	PlayerProgressEvent = Instance.new("RemoteEvent")
	PlayerProgressEvent.Name = "PlayerProgressEvent"
	PlayerProgressEvent.Parent = remotes
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
