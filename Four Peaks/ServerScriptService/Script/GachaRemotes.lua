-- SCRIPT: GachaRemotes.server.lua
-- Remotes for server-authoritative banner operations with confirmed persistence.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local GachaService = require(serverModules:WaitForChild("GachaService"))
local CurrencyService = require(serverModules:WaitForChild("CurrencyService"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctions then
	remoteFunctions = Instance.new("Folder")
	remoteFunctions.Name = "RemoteFunctions"
	remoteFunctions.Parent = ReplicatedStorage
end

local function ensureEvent(name: string): RemoteEvent
	local event = remoteEvents:FindFirstChild(name)
	if event and event:IsA("RemoteEvent") then return event end
	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remoteEvents
	return event
end

local function ensureFunction(name: string): RemoteFunction
	local remoteFunction = remoteFunctions:FindFirstChild(name)
	if remoteFunction and remoteFunction:IsA("RemoteFunction") then return remoteFunction end
	remoteFunction = Instance.new("RemoteFunction")
	remoteFunction.Name = name
	remoteFunction.Parent = remoteFunctions
	return remoteFunction
end

ensureEvent("OpenWeaponBannerUI")

local GetActiveBanners = ensureFunction("GetActiveBanners")
local GetGachaState = ensureFunction("GetGachaState")
local RollBanner = ensureFunction("RollBanner")
local ConvertWeaponPoints = ensureFunction("ConvertWeaponPoints")

local REQUEST_COOLDOWN_SECONDS = 0.35
local activeEconomyRequest = {}
local lastEconomyRequest = {}
local persistenceBlocked = {}

local function canStartEconomyRequest(player: Player): (boolean, string?)
	local userId = player.UserId
	if persistenceBlocked[userId] then return false, "PersistenceUnavailable" end
	if activeEconomyRequest[userId] then return false, "Busy" end
	local current = os.clock()
	if current - (lastEconomyRequest[userId] or 0) < REQUEST_COOLDOWN_SECONDS then
		return false, "RateLimited"
	end
	lastEconomyRequest[userId] = current
	activeEconomyRequest[userId] = true
	return true
end

local function finishEconomyRequest(player: Player)
	activeEconomyRequest[player.UserId] = nil
end

local function blockAfterSaveFailure(player: Player, reason)
	local userId = player.UserId
	persistenceBlocked[userId] = true
	player:SetAttribute("PersistenceBlocked", true)
	warn("[GachaRemotes] Confirmed save failed; blocking further economy requests:", player.Name, reason)
	if not RunService:IsStudio() then
		task.defer(function()
			if player.Parent == Players then
				player:Kick("Your latest account change could not be confirmed safely. Please rejoin.")
			end
		end)
	end
end

local function confirmMutation(player: Player, reason: string): (boolean, string?)
	local saved, saveError = PlayerData.SaveBarrier(player, reason)
	if saved then return true end
	blockAfterSaveFailure(player, saveError)
	return false, "PersistenceUnavailable"
end

GetActiveBanners.OnServerInvoke = function(_player: Player)
	return GachaService.GetActiveBanners()
end

GetGachaState.OnServerInvoke = function(player: Player)
	return GachaService.GetPlayerState(player)
end

RollBanner.OnServerInvoke = function(player: Player, bannerId: string, count: number)
	local allowed, rejection = canStartEconomyRequest(player)
	if not allowed then return false, rejection end

	local callOk, rolled, result = pcall(GachaService.Roll, player, bannerId, count)
	if not callOk then
		finishEconomyRequest(player)
		warn("[GachaRemotes] Roll failed with an exception:", player.Name, rolled)
		return false, "ServerError"
	end
	if rolled == true then
		local saved, saveReason = confirmMutation(player, "gacha_roll")
		if not saved then
			finishEconomyRequest(player)
			return false, saveReason
		end
	end

	finishEconomyRequest(player)
	return rolled, result
end

ConvertWeaponPoints.OnServerInvoke = function(player: Player, amountWeaponPoints: number)
	local allowed, rejection = canStartEconomyRequest(player)
	if not allowed then return { ok = false, error = rejection } end

	local callOk, result = pcall(CurrencyService.ConvertWeaponPointsToTickets, player, amountWeaponPoints)
	if not callOk then
		finishEconomyRequest(player)
		warn("[GachaRemotes] Currency conversion failed with an exception:", player.Name, result)
		return { ok = false, error = "ServerError" }
	end
	if typeof(result) == "table" and result.ok == true then
		local saved, saveReason = confirmMutation(player, "weapon_points_conversion")
		if not saved then
			finishEconomyRequest(player)
			return { ok = false, error = saveReason }
		end
	end

	finishEconomyRequest(player)
	return result
end

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	activeEconomyRequest[userId] = nil
	lastEconomyRequest[userId] = nil
	persistenceBlocked[userId] = nil
end)

print("[GachaRemotes] Ready (confirmed persistence)")
