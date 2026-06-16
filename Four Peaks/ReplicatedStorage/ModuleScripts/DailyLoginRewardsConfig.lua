-- Daily login reward balance lives here so events and economy tuning can change
-- without touching the service or client UI.

local DailyLoginRewardsConfig = {}

DailyLoginRewardsConfig.CycleLength = 7

DailyLoginRewardsConfig.Rewards = {
	{
		Day = 1,
		RewardType = "Ticket",
		Amount = 1,
		DisplayName = "Ticket",
		Icon = "Ticket",
	},
	{
		Day = 2,
		RewardType = "Souls",
		Amount = 500,
		DisplayName = "Souls",
		Icon = "Souls",
	},
	{
		Day = 3,
		RewardType = "Ticket",
		Amount = 1,
		DisplayName = "Ticket",
		Icon = "Ticket",
	},
	{
		Day = 4,
		RewardType = "MaterialBundle",
		Amount = 1,
		DisplayName = "Materials",
		Icon = "Materials",
		BackendId = "DailyLoginStarterMaterials",
		Materials = {
			{ Id = "Iron Ore", Amount = 5 },
			{ Id = "Coal Chunk", Amount = 3 },
			{ Id = "Emberstone", Amount = 1 },
		},
	},
	{
		Day = 5,
		RewardType = "Ticket",
		Amount = 2,
		DisplayName = "Tickets",
		Icon = "Ticket",
	},
	{
		Day = 6,
		RewardType = "Booster",
		Amount = 1,
		DisplayName = "EXP Booster",
		Icon = "Booster",
		BackendId = "EXPBooster",
	},
	{
		Day = 7,
		RewardType = "Ticket",
		Amount = 2,
		DisplayName = "Tickets",
		Icon = "Ticket",
	},
}

local rewardsByDay = {}
for _, reward in ipairs(DailyLoginRewardsConfig.Rewards) do
	rewardsByDay[reward.Day] = reward
end

local function copyMaterialList(materials)
	local out = {}
	for _, entry in ipairs(materials or {}) do
		table.insert(out, {
			Id = entry.Id,
			Amount = entry.Amount,
		})
	end
	return out
end

function DailyLoginRewardsConfig.CopyReward(reward)
	if typeof(reward) ~= "table" then
		return nil
	end

	local copy = {
		Day = reward.Day,
		RewardType = reward.RewardType,
		Amount = reward.Amount,
		DisplayName = reward.DisplayName,
		Icon = reward.Icon,
		BackendId = reward.BackendId,
	}

	if reward.Materials then
		copy.Materials = copyMaterialList(reward.Materials)
	end

	return copy
end

function DailyLoginRewardsConfig.GetReward(day)
	return DailyLoginRewardsConfig.CopyReward(rewardsByDay[day])
end

function DailyLoginRewardsConfig.GetRewards()
	local out = {}
	for _, reward in ipairs(DailyLoginRewardsConfig.Rewards) do
		table.insert(out, DailyLoginRewardsConfig.CopyReward(reward))
	end
	return out
end

return DailyLoginRewardsConfig
