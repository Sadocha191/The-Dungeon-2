-- SCRIPT: MissionRemotes.server.lua
-- GDZIE: ServerScriptService/MissionRemotes.server.lua
-- CO: remotes dla systemu misji

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local MissionService = require(serverModules:WaitForChild("MissionService"))
local CurrencyService = require(serverModules:WaitForChild("CurrencyService"))
local PlayerData = require(serverModules:WaitForChild("PlayerData"))

local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctions then
	remoteFunctions = Instance.new("Folder")
	remoteFunctions.Name = "RemoteFunctions"
	remoteFunctions.Parent = ReplicatedStorage
end

local function ensureFunction(name: string): RemoteFunction
	local fn = remoteFunctions:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then return fn end
	fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remoteFunctions
	return fn
end

local RF_GetMissions = ensureFunction("RF_GetMissions")
local RF_ClaimMission = ensureFunction("RF_ClaimMission")

RF_GetMissions.OnServerInvoke = function(player: Player)
	local missions = MissionService.GetMissions(player)
	local currencies = CurrencyService.GetBalances(player)
	return {
		missions = missions,
		currencies = currencies,
	}
end

RF_ClaimMission.OnServerInvoke = function(player: Player, missionId: string)
	if typeof(missionId) ~= "string" then
		return { ok = false, error = "InvalidMission" }
	end

	local ok, err, updatedMission = MissionService.ClaimMission(player, missionId)
	local currencies = CurrencyService.GetBalances(player)
	local data = PlayerData.Get(player)
	local claimCounts = data.Missions and data.Missions.ClaimCounts or {}

	if not ok then
		return {
			ok = false,
			error = err or "Unknown",
			currencies = currencies,
			claimCounts = claimCounts,
		}
	end

	return {
		ok = true,
		currencies = currencies,
		claimCounts = claimCounts,
		updatedMission = updatedMission,
	}
end

print("[MissionRemotes] Ready")
