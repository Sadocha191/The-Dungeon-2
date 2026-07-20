local Players = game:GetService("Players")

local MissionService = require(script.Parent:WaitForChild("MissionService"))

local MissionClaimService = {}
local claimLocks: {[number]: boolean} = {}

function MissionClaimService.GetMissions(player: Player)
	return MissionService.GetMissions(player)
end

function MissionClaimService.ClaimMission(player: Player, missionId: string)
	if not player or player.Parent ~= Players then
		return false, "InvalidPlayer"
	end

	local userId = player.UserId
	if claimLocks[userId] then
		return false, "ClaimInProgress"
	end
	claimLocks[userId] = true

	local callOk, claimOk, claimError, updatedMission = xpcall(function()
		return MissionService.ClaimMission(player, missionId)
	end, debug.traceback)

	claimLocks[userId] = nil

	if not callOk then
		warn("[MissionClaimService] ClaimMission failed:", claimOk)
		return false, "InternalError"
	end

	return claimOk, claimError, updatedMission
end

Players.PlayerRemoving:Connect(function(player)
	claimLocks[player.UserId] = nil
end)

return MissionClaimService
