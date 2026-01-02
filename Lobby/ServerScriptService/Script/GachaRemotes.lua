-- SCRIPT: GachaRemotes.server.lua
-- GDZIE: ServerScriptService/GachaRemotes.server.lua
-- CO: remotes dla systemu bannerów

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GachaService = require(ServerScriptService:WaitForChild("GachaService"))
local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))

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
	local ev = remoteEvents:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remoteEvents
	return ev
end

local function ensureFunction(name: string): RemoteFunction
	local fn = remoteFunctions:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then return fn end
	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remoteFunctions
	return fn
end

ensureEvent("OpenWeaponBannerUI")

local GetActiveBanners = ensureFunction("GetActiveBanners")
local GetGachaState = ensureFunction("GetGachaState")
local RollBanner = ensureFunction("RollBanner")
local ConvertWeaponPoints = ensureFunction("ConvertWeaponPoints")

GetActiveBanners.OnServerInvoke = function(_player: Player)
	return GachaService.GetActiveBanners()
end

GetGachaState.OnServerInvoke = function(player: Player)
	return GachaService.GetPlayerState(player)
end

RollBanner.OnServerInvoke = function(player: Player, bannerId: string, count: number)
	return GachaService.Roll(player, bannerId, count)
end

ConvertWeaponPoints.OnServerInvoke = function(player: Player, amountWeaponPoints: number)
	return CurrencyService.ConvertWeaponPointsToTickets(player, amountWeaponPoints)
end

print("[GachaRemotes] Ready")
