-- ReturnToLobby.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local LOBBY_PLACE_ID = 88516424167732
local FINALIZATION_TIMEOUT = 30
local TELEPORT_LOCK_TIMEOUT = 15
local RunProgressApi = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("RunProgressApi"))

local pendingReturns: {[number]: boolean} = {}
local teleporting: {[number]: number} = {}
local nextTeleportAttempt = 0

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

local function fireTeleportStatus(player: Player, statusType: string, reason: string?)
	teleportStatus:FireClient(player, {
		type = statusType,
		reason = reason,
		message = "Teleporting...",
	})
end

local function releaseTeleportLock(player: Player, attemptToken: number?)
	local userId = player.UserId
	if attemptToken ~= nil and teleporting[userId] ~= attemptToken then
		return
	end
	teleporting[userId] = nil
end

local function acquireTeleportLock(player: Player): number?
	local userId = player.UserId
	if teleporting[userId] ~= nil then
		return nil
	end

	nextTeleportAttempt += 1
	local attemptToken = nextTeleportAttempt
	teleporting[userId] = attemptToken
	task.delay(TELEPORT_LOCK_TIMEOUT, function()
		if teleporting[userId] == attemptToken then
			teleporting[userId] = nil
		end
	end)
	return attemptToken
end

local function teleportToLobby(player: Player)
	local attemptToken = acquireTeleportLock(player)
	if not attemptToken then
		return
	end

	local options = Instance.new("TeleportOptions")
	fireTeleportStatus(player, "teleporting")
	task.wait(0.18)
	if player.Parent ~= Players then
		releaseTeleportLock(player, attemptToken)
		return
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID, { player }, options)
	end)
	if not ok then
		releaseTeleportLock(player, attemptToken)
		warn("[ReturnToLobby] TeleportAsync failed:", err)
		fireTeleportStatus(player, "failed", "teleport_failed")
	end
end

local function queueReturnAfterFinalization(player: Player)
	local userId = player.UserId
	if pendingReturns[userId] then
		return
	end
	pendingReturns[userId] = true

	task.spawn(function()
		local deadline = os.clock() + FINALIZATION_TIMEOUT
		while player.Parent == Players and RunProgressApi.IsEndRunFinalizing(player) and os.clock() < deadline do
			task.wait(0.05)
		end

		pendingReturns[userId] = nil
		if player.Parent ~= Players then
			return
		end
		if RunProgressApi.IsEndRunFinalizing(player) then
			fireTeleportStatus(player, "failed", "run_finalization_timeout")
			return
		end
		if player:GetAttribute("RunEnded") ~= true then
			fireTeleportStatus(player, "failed", "run_finalization_failed")
			return
		end

		teleportToLobby(player)
	end)
end

TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage, placeId)
	if placeId ~= LOBBY_PLACE_ID or teleporting[player.UserId] == nil then
		return
	end

	releaseTeleportLock(player)
	warn("[ReturnToLobby] Teleport initialization failed:", teleportResult, errorMessage)
	if player.Parent == Players then
		fireTeleportStatus(player, "failed", "teleport_failed")
	end
end)

remote.OnServerEvent:Connect(function(player)
	if not player or player.Parent ~= Players then
		return
	end

	if RunProgressApi.IsEndRunFinalizing(player) then
		queueReturnAfterFinalization(player)
		return
	end

	if player:GetAttribute("RunEnded") ~= true then
		if RunProgressApi.IsConfigured("EndRunForPlayer") then
			local ok, err = pcall(RunProgressApi.EndRunForPlayer, player, "Surrendered")
			if ok then
				-- Preserve the existing two-step flow: this request ends and banks the run;
				-- the summary's later Return action performs the teleport.
				return
			end
			warn("[ReturnToLobby] EndRunForPlayer failed:", err)
		end
	end

	teleportToLobby(player)
end)

Players.PlayerRemoving:Connect(function(player)
	pendingReturns[player.UserId] = nil
	releaseTeleportLock(player)
end)
