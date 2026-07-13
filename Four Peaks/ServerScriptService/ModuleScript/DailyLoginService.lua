local ReplicatedStorage = game:GetService("ReplicatedStorage")

local moduleFolder = script.Parent
local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local CraftingConfig = require(replicatedModules:WaitForChild("CraftingConfig"))
local DailyLoginRewardsConfig = require(replicatedModules:WaitForChild("DailyLoginRewardsConfig"))
local PlayerData = require(moduleFolder:WaitForChild("PlayerData"))
local CurrencyService = require(moduleFolder:WaitForChild("CurrencyService"))
local PickupToastService = require(moduleFolder:WaitForChild("PickupToastService"))

local DailyLoginService = {}

local SECONDS_PER_DAY = 24 * 60 * 60
local CLAIM_RATE_LIMIT_SECONDS = 1.5
local claimLocks = {}
local lastClaimRequestAt = {}
local craftingService
local craftingServiceLoadAttempted = false

local function utcDayNumber(now)
	return math.floor((now or os.time()) / SECONDS_PER_DAY)
end

local function ensureDailyLogin(data)
	if typeof(data.DailyLogin) ~= "table" then
		data.DailyLogin = {
			LastClaimDayUTC = 0,
			CurrentDay = 1,
			TotalClaims = 0,
		}
	end

	local daily = data.DailyLogin
	daily.LastClaimDayUTC = math.max(0, math.floor(tonumber(daily.LastClaimDayUTC) or 0))
	daily.CurrentDay = math.clamp(math.floor(tonumber(daily.CurrentDay) or 1), 1, 7)
	daily.TotalClaims = math.max(0, math.floor(tonumber(daily.TotalClaims) or 0))
	return daily
end

local function nextDay(day)
	day = math.clamp(math.floor(tonumber(day) or 1), 1, 7)
	if day >= 7 then
		return 1
	end
	return day + 1
end

local function summarizeReward(reward)
	if typeof(reward) ~= "table" then
		return "Reward"
	end

	local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
	local name = tostring(reward.DisplayName or reward.RewardType or "Reward")
	if reward.RewardType == "MaterialBundle" then
		return name
	end
	if amount > 1 then
		return tostring(amount) .. " " .. name
	end
	return tostring(amount) .. " " .. name
end

local function buildDayStatuses(currentDay, canClaim)
	local days = {}
	for day = 1, 7 do
		local status = "Locked"
		if day < currentDay then
			status = "ClaimedInCurrentCycle"
		elseif day == currentDay then
			status = "Current"
		end

		table.insert(days, {
			Day = day,
			Status = status,
			CanClaim = day == currentDay and canClaim == true,
		})
	end
	return days
end

local function getCraftingService()
	if craftingServiceLoadAttempted then
		return craftingService
	end

	craftingServiceLoadAttempted = true
	local ok, service = pcall(function()
		return require(moduleFolder:WaitForChild("CraftingService"))
	end)

	if ok and typeof(service) == "table" then
		craftingService = service
	else
		warn("[DailyLoginService] CraftingService unavailable for material rewards:", service)
	end

	return craftingService
end

local function validateMaterialBundle(entries)
	for _, entry in ipairs(entries or {}) do
		local materialId = tostring(entry.Id or "")
		local materialAmount = math.max(0, math.floor(tonumber(entry.Amount) or 0))
		if materialAmount > 0 then
			if materialId == "" or not CraftingConfig.GetMaterialBucket(materialId) then
				return false, "UnknownMaterial:" .. materialId
			end
		end
	end
	return true
end

function DailyLoginService.GetState(player)
	local data = PlayerData.Get(player)
	if typeof(data) ~= "table" then
		return {
			CurrentDay = 1,
			CanClaim = false,
			LastClaimDayUTC = 0,
			NextClaimDayUTC = utcDayNumber(os.time()) + 1,
			TotalClaims = 0,
			Rewards = DailyLoginRewardsConfig.GetRewards(),
			Days = buildDayStatuses(1, false),
		}
	end

	local daily = ensureDailyLogin(data)
	local today = utcDayNumber(os.time())
	local canClaim = today > daily.LastClaimDayUTC

	return {
		CurrentDay = daily.CurrentDay,
		CanClaim = canClaim,
		LastClaimDayUTC = daily.LastClaimDayUTC,
		NextClaimDayUTC = today + 1,
		TotalClaims = daily.TotalClaims,
		Rewards = DailyLoginRewardsConfig.GetRewards(),
		Days = buildDayStatuses(daily.CurrentDay, canClaim),
	}
end

local function pushCurrencyToast(player, reward)
	local rewardType = reward.RewardType
	local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))
	if amount <= 0 then
		return
	end

	if rewardType == "Ticket" then
		PickupToastService.Push(player, {
			variant = "ticket",
			label = reward.DisplayName or "Ticket",
			amount = amount,
			note = "Daily Login",
		})
	elseif rewardType == "Souls" then
		PickupToastService.Push(player, {
			variant = "souls",
			label = reward.DisplayName or "Souls",
			amount = amount,
			note = "Daily Login",
		})
	end
end

local function grantReward(player, reward)
	local rewardType = tostring(reward.RewardType or "")
	local amount = math.max(0, math.floor(tonumber(reward.Amount) or 0))

	if rewardType == "Ticket" then
		CurrencyService.AddTickets(player, amount)
		pushCurrencyToast(player, reward)
		return true
	elseif rewardType == "Souls" then
		if typeof(CurrencyService.AddSouls) == "function" then
			CurrencyService.AddSouls(player, amount)
		else
			local data = PlayerData.Get(player)
			data.souls = math.max(0, math.floor(tonumber(data.souls) or 0) + amount)
			PlayerData.MarkDirty(player)
		end
		pushCurrencyToast(player, reward)
		return true
	elseif rewardType == "MaterialBundle" then
		local service = getCraftingService()
		if not (service and typeof(service.AddMaterial) == "function") then
			warn("[DailyLoginService] Material backend unavailable. Claim was not advanced:", reward.BackendId or reward.DisplayName)
			return false, "MaterialBackendUnavailable"
		end

		local valid, validationError = validateMaterialBundle(reward.Materials)
		if not valid then
			warn("[DailyLoginService] Material bundle validation failed. Claim was not advanced:", validationError)
			return false, validationError
		end

		for _, entry in ipairs(reward.Materials or {}) do
			local materialId = tostring(entry.Id or "")
			local materialAmount = math.max(0, math.floor(tonumber(entry.Amount) or 0))
			if materialAmount > 0 then
				local ok, err = service.AddMaterial(player, materialId, materialAmount, {
					toastNote = "Daily Login",
				})
				if not ok then
					warn("[DailyLoginService] Material reward failed after validation:", materialId, err)
					return false, err or "MaterialGrantFailed"
				end
			end
		end
		return true
	elseif rewardType == "Booster" then
		warn("[DailyLoginService] TODO: Booster backend is not implemented yet. Placeholder claimed:", reward.BackendId or reward.DisplayName)
		return true
	end

	return false, "UnknownRewardType"
end

function DailyLoginService.Claim(player)
	if not player then
		return {
			Success = false,
			Message = "Invalid player.",
			State = nil,
		}
	end

	local userId = player.UserId
	local nowClock = os.clock()
	if claimLocks[userId] == true then
		return {
			Success = false,
			Message = "Claim already in progress.",
			State = DailyLoginService.GetState(player),
		}
	end

	local lastRequestAt = tonumber(lastClaimRequestAt[userId]) or 0
	if nowClock - lastRequestAt < CLAIM_RATE_LIMIT_SECONDS then
		return {
			Success = false,
			Message = "Please wait before claiming again.",
			State = DailyLoginService.GetState(player),
		}
	end

	lastClaimRequestAt[userId] = nowClock
	claimLocks[userId] = true

	local ok, result = pcall(function()
		local data = PlayerData.Get(player)
		if typeof(data) ~= "table" then
			return {
				Success = false,
				Message = "Player profile is not ready.",
				State = nil,
			}
		end

		local daily = ensureDailyLogin(data)
		local today = utcDayNumber(os.time())
		if today <= daily.LastClaimDayUTC then
			return {
				Success = false,
				Message = "Come back tomorrow.",
				State = DailyLoginService.GetState(player),
			}
		end

		local reward = DailyLoginRewardsConfig.GetReward(daily.CurrentDay)
		if not reward then
			return {
				Success = false,
				Message = "Reward config is missing.",
				State = DailyLoginService.GetState(player),
			}
		end

		local granted, err = grantReward(player, reward)
		if not granted then
			return {
				Success = false,
				Message = err or "Reward could not be granted.",
				Reward = reward,
				State = DailyLoginService.GetState(player),
			}
		end

		daily.LastClaimDayUTC = today
		daily.TotalClaims = math.max(0, math.floor(tonumber(daily.TotalClaims) or 0)) + 1
		daily.CurrentDay = nextDay(daily.CurrentDay)
		PlayerData.MarkDirty(player)
		PlayerData.Save(player, false)

		return {
			Success = true,
			Message = "Claimed: " .. summarizeReward(reward),
			Reward = reward,
			State = DailyLoginService.GetState(player),
			Animation = {
				Type = "DailyLoginClaim",
				RewardType = reward.RewardType,
			},
		}
	end)

	claimLocks[userId] = nil

	if not ok then
		warn("[DailyLoginService] Claim failed:", result)
		return {
			Success = false,
			Message = "Daily login claim failed.",
			State = DailyLoginService.GetState(player),
		}
	end

	return result
end

return DailyLoginService
