-- ReturnToLobby.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local LOBBY_PLACE_ID = 88516424167732
local RunProgressApi = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("RunProgressApi"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local teleportStatus = remotes:FindFirstChild("TeleportStatus")
if not teleportStatus then
	teleportStatus = Instance.new("RemoteEvent")
	teleportStatus.Name = "TeleportStatus"
	teleportStatus.Parent = remotes
end

local remote = ReplicatedStorage:FindFirstChild("ReturnToLobby")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "ReturnToLobby"
	remote.Parent = ReplicatedStorage
end

local runFinalizationInProgress = {}

local function fireTeleportStatus(player: Player, statusType: string, reason: string?)
	teleportStatus:FireClient(player, {
		type = statusType,
		reason = reason,
		message = "Teleporting...",
	})
end

local function teleportToLobby(player: Player)
	local options = Instance.new("TeleportOptions")
	fireTeleportStatus(player, "teleporting")
	task.wait(0.18)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID, { player }, options)
	end)
	if not ok then
		warn("[ReturnToLobby] TeleportAsync failed:", err)
		fireTeleportStatus(player, "failed", "teleport_failed")
	end
end

remote.OnServerEvent:Connect(function(player)
	if not player or player.Parent ~= Players then
		return
	end

	local userId = player.UserId
	if runFinalizationInProgress[userId] then
		return
	end

	if player:GetAttribute("RunEnded") ~= true then
		if RunProgressApi.IsConfigured("EndRunForPlayer") then
			runFinalizationInProgress[userId] = true
			local ok, err = pcall(RunProgressApi.EndRunForPlayer, player, "Surrendered")
			runFinalizationInProgress[userId] = nil
			if ok then
				-- EndRunForPlayer returns only after mission finalization and its save attempts.
				-- A second click can teleport only after that work has completed.
				return
			end
			warn("[ReturnToLobby] EndRunForPlayer failed:", err)
		end
	end

	teleportToLobby(player)
end)

Players.PlayerRemoving:Connect(function(player)
	runFinalizationInProgress[player.UserId] = nil
end)
