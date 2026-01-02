-- MODULE: MissionService.lua
-- GDZIE: ServerScriptService/ModuleScript/MissionService.lua
-- CO: obsługa misji (daily/weekly/test)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MissionConfigs = require(ReplicatedStorage:WaitForChild("MissionConfigs"))
local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))
local PlayerData = require(ServerScriptService:WaitForChild("PlayerData"))

local MissionService = {}

local function ensureMissionState(player: Player)
	local data = PlayerData.Get(player)
	data.Missions = data.Missions or {}
	data.Missions.ClaimCounts = data.Missions.ClaimCounts or {}
	data.Missions.Progress = data.Missions.Progress or {}
	data.Missions.LastResetDaily = tonumber(data.Missions.LastResetDaily) or 0
	data.Missions.LastResetWeekly = tonumber(data.Missions.LastResetWeekly) or 0
	return data.Missions
end

local function isClaimable(mission, _state)
	if mission.Goal == "AlwaysClaimable" then
		return true
	end
	return false
end

local function buildMissionPayload(mission, state)
	local claimCount = tonumber(state.ClaimCounts[mission.Id]) or 0
	local progress = state.Progress[mission.Id]
	return {
		Id = mission.Id,
		Type = mission.Type,
		Title = mission.Title,
		Description = mission.Description,
		Reward = mission.Reward,
		Repeatable = mission.Repeatable,
		Goal = mission.Goal,
		Claimable = isClaimable(mission, state),
		ClaimCount = claimCount,
		Progress = progress,
	}
end

function MissionService.GetMissions(player: Player)
	local state = ensureMissionState(player)
	local missions = {}
	for _, mission in ipairs(MissionConfigs.GetAll()) do
		table.insert(missions, buildMissionPayload(mission, state))
	end
	return missions
end

function MissionService.ClaimMission(player: Player, missionId: string)
	local mission = MissionConfigs.Get(missionId)
	if not mission then
		return false, "MissionNotFound"
	end

	local state = ensureMissionState(player)
	local claimCount = tonumber(state.ClaimCounts[missionId]) or 0
	if not mission.Repeatable and claimCount > 0 then
		return false, "AlreadyClaimed"
	end

	if not isClaimable(mission, state) then
		return false, "NotClaimable"
	end

	local reward = mission.Reward or {}
	local coins = tonumber(reward.Coins) or 0
	local weaponPoints = tonumber(reward.WeaponPoints) or 0

	if coins > 0 then
		CurrencyService.AddCoins(player, coins)
	end
	if weaponPoints > 0 then
		CurrencyService.AddWeaponPoints(player, weaponPoints)
	end

	state.ClaimCounts[missionId] = claimCount + 1
	PlayerData.MarkDirty(player)

	return true, nil, buildMissionPayload(mission, state)
end

return MissionService
