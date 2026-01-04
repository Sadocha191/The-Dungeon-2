-- ReturnToLobby.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LOBBY_PLACE_ID = 72651938611811

local remote = ReplicatedStorage:FindFirstChild("ReturnToLobby")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "ReturnToLobby"
	remote.Parent = ReplicatedStorage
end

remote.OnServerEvent:Connect(function(player)
	local options = Instance.new("TeleportOptions")
	TeleportService:TeleportAsync(LOBBY_PLACE_ID, { player }, options)
end)
