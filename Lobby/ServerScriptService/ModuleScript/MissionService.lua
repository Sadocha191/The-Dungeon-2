-- MODULE: MissionService.lua
-- GDZIE: ServerScriptService/ModuleScript/MissionService.lua
-- CO: nagrody z daily/weekly (WeaponPoints)

local ServerScriptService = game:GetService("ServerScriptService")

local CurrencyService = require(ServerScriptService:WaitForChild("CurrencyService"))

local MissionService = {}

MissionService.Rewards = {
	DailyWeaponPoints = 150,
	WeeklyWeaponPoints = 750,
}

function MissionService.GrantDailyReward(player: Player)
	return CurrencyService.AddCurrency(player, "WeaponPoints", MissionService.Rewards.DailyWeaponPoints)
end

function MissionService.GrantWeeklyReward(player: Player)
	return CurrencyService.AddCurrency(player, "WeaponPoints", MissionService.Rewards.WeeklyWeaponPoints)
end

return MissionService
