local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local EventsConfig = require(replicatedModules:WaitForChild("EventsConfig"))
local EventUtil = require(replicatedModules:WaitForChild("EventUtil"))
local PlayerData = require(moduleFolder:WaitForChild("PlayerData"))
local CurrencyService = require(moduleFolder:WaitForChild("CurrencyService"))
local PickupToastService = require(moduleFolder:WaitForChild("PickupToastService"))

local EventService = {}

local CLAIM_RATE_LIMIT_SECONDS = 0.65
local claimLocks = {}
local lastClaimRequestAt = {}
local craftingService = nil
local warnedRewardTypes = {}

local function clampInt(value)
	value = math.floor(tonumber(value) or 0)
	if value < 0 then
		return 0
	end
	return value
end

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, nested in pairs(value) do
		copy[key] = deepCopy(nested)
	end
	return copy
end

local function copyRewards(rewards)
	local out = {}
	for _, reward in ipairs(rewards or {}) do
		if typeof(reward) == "table" then
			table.insert(out, deepCopy(reward))
		end
	end
	return out
end

local function findEvent(eventId)
	for _, eventConfig in ipairs(EventsConfig or {}) do
		if typeof(eventConfig) == "table" and eventConfig.Id == eventId then
			return eventConfig
		end
	end
	return nil
end

local function findTask(eventConfig, taskId)
	for _, taskDef in ipairs(eventConfig.Tasks or {}) do
		if taskDef.Id == taskId then
			return taskDef
		end
	end
	return nil
end

local function findMilestone(eventConfig, milestoneId)
	for _, milestoneDef in ipairs(eventConfig.Milestones or {}) do
		if milestoneDef.Id == milestoneId then
			return milestoneDef
		end
	end
	return nil
end

local function sanitizeBoolMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" and value == true then
			out[key] = true
		end
	end
	return out
end

local function sanitizeStats(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = clampInt(value)
			if amount > 0 then
				out[key] = amount
			end
		end
	end
	return out
end

local function sanitizeEventEntry(raw)
	if typeof(raw) ~= "table" then
		raw = {}
	end
	return {
		Stats = sanitizeStats(raw.Stats),
		ClaimedTasks = sanitizeBoolMap(raw.ClaimedTasks),
		ClaimedMilestones = sanitizeBoolMap(raw.ClaimedMilestones),
		ClaimedFinalRewards = raw.ClaimedFinalRewards == true,
	}
end

local function ensureEventsData(player)
	if not player then
		return nil
	end
	local data = PlayerData.Get(player)
	if typeof(data) ~= "table" then
		return nil
	end

	if typeof(data.Events) ~= "table" then
		data.Events = { Progress = {} }
	end
	if typeof(data.Events.Progress) ~= "table" then
		data.Events.Progress = {}
	end

	for eventId, eventEntry in pairs(data.Events.Progress) do
		if typeof(eventId) ~= "string" or eventId == "" then
			data.Events.Progress[eventId] = nil
		else
			data.Events.Progress[eventId] = sanitizeEventEntry(eventEntry)
		end
	end

	return data.Events
end

local function getEventProgress(player, eventId)
	local eventsData = ensureEventsData(player)
	if not eventsData then
		return nil
	end

	local progress = eventsData.Progress[eventId]
	if typeof(progress) ~= "table" then
		progress = sanitizeEventEntry(nil)
		eventsData.Progress[eventId] = progress
	end
	return progress
end

local function getCompletedTaskCount(eventConfig, eventProgress)
	local completed = 0
	for _, taskDef in ipairs(eventConfig.Tasks or {}) do
		local progressKey = tostring(taskDef.ProgressKey or "")
		local required = math.max(1, clampInt(taskDef.RequiredAmount))
		local current = clampInt(eventProgress.Stats[progressKey])
		if current >= required then
			completed += 1
		end
	end
	return completed
end

local function buildTaskState(taskDef, eventProgress, eventActive)
	local progressKey = tostring(taskDef.ProgressKey or "")
	local required = math.max(1, clampInt(taskDef.RequiredAmount))
	local current = math.min(clampInt(eventProgress.Stats[progressKey]), required)
	local claimed = eventProgress.ClaimedTasks[tostring(taskDef.Id or "")] == true
	local completed = current >= required

	return {
		Id = tostring(taskDef.Id or ""),
		DisplayName = tostring(taskDef.DisplayName or taskDef.Id or "Task"),
		Description = tostring(taskDef.Description or ""),
		ProgressKey = progressKey,
		RequiredAmount = required,
		Rewards = copyRewards(taskDef.Rewards),
		Progress = {
			Current = current,
			Required = required,
			Percent = required > 0 and math.clamp(current / required, 0, 1) or 0,
		},
		Completed = completed,
		Claimed = claimed,
		Claimable = eventActive and completed and not claimed,
	}
end

local function buildMilestoneState(milestoneDef, completedTasks, eventProgress, eventActive)
	local required = math.max(1, clampInt(milestoneDef.RequiredCompletedTasks))
	local claimed = eventProgress.ClaimedMilestones[tostring(milestoneDef.Id or "")] == true
	local completed = completedTasks >= required

	return {
		Id = tostring(milestoneDef.Id or ""),
		DisplayName = tostring(milestoneDef.DisplayName or milestoneDef.Id or "Milestone"),
		RequiredCompletedTasks = required,
		CompletedTasks = completedTasks,
		Rewards = copyRewards(milestoneDef.Rewards),
		Completed = completed,
		Claimed = claimed,
		Claimable = eventActive and completed and not claimed,
	}
end

local function buildEventState(player, eventConfig, nowUnix)
	local eventProgress = getEventProgress(player, tostring(eventConfig.Id or "")) or sanitizeEventEntry(nil)
	local publicConfig = EventUtil.BuildPublicEventConfig(eventConfig)
	local status = EventUtil.GetEventStatus(eventConfig, nowUnix)
	local timeTarget = EventUtil.GetTimeTargetUnix(eventConfig, nowUnix)
	local eventActive = status == "Active"
	local completedTasks = getCompletedTaskCount(eventConfig, eventProgress)
	local totalTasks = #(eventConfig.Tasks or {})

	publicConfig.Status = status
	publicConfig.TimeTargetUnix = timeTarget
	publicConfig.TimeRemainingText = EventUtil.FormatTimeRemaining((timeTarget or 0) - nowUnix)
	publicConfig.CompletedTasks = completedTasks
	publicConfig.TotalTasks = totalTasks
	publicConfig.Tasks = {}

	for _, taskDef in ipairs(eventConfig.Tasks or {}) do
		table.insert(publicConfig.Tasks, buildTaskState(taskDef, eventProgress, eventActive))
	end

	publicConfig.Milestones = {}
	for _, milestoneDef in ipairs(eventConfig.Milestones or {}) do
		table.insert(publicConfig.Milestones, buildMilestoneState(milestoneDef, completedTasks, eventProgress, eventActive))
	end

	local allTasksCompleted = totalTasks > 0 and completedTasks >= totalTasks
	publicConfig.FinalRewards = copyRewards(eventConfig.FinalRewards)
	publicConfig.FinalCompleted = allTasksCompleted
	publicConfig.FinalClaimed = eventProgress.ClaimedFinalRewards == true
	publicConfig.FinalClaimable = eventActive and allTasksCompleted and eventProgress.ClaimedFinalRewards ~= true

	return publicConfig
end

local function getCraftingService()
	if craftingService ~= nil then
		return craftingService
	end
	local module = moduleFolder:FindFirstChild("CraftingService")
	if not module then
		craftingService = false
		return nil
	end
	local ok, service = pcall(require, module)
	if ok then
		craftingService = service
		return service
	end
	warn("[EventService] Failed to load CraftingService:", service)
	craftingService = false
	return nil
end

local function pushCurrencyToast(player, variant, label, amount)
	if amount <= 0 or not PickupToastService or typeof(PickupToastService.Push) ~= "function" then
		return
	end
	PickupToastService.Push(player, {
		variant = variant,
		label = label,
		amount = amount,
		note = "Event Reward",
	})
end

local function rewardSummary(reward)
	local rewardType = tostring(reward.Type or "")
	local amount = math.max(0, clampInt(reward.Amount))
	if rewardType == "Ticket" then
		return string.format("%d Tickets", amount)
	elseif rewardType == "WP" then
		return string.format("%d WP", amount)
	elseif rewardType == "Souls" then
		return string.format("%d Souls", amount)
	elseif rewardType == "Material" then
		return string.format("%s x%d", tostring(reward.MaterialId or reward.Id or "Material"), amount)
	elseif rewardType == "MaterialBundle" then
		return tostring(reward.DisplayName or "Material Bundle")
	elseif rewardType == "Title" or rewardType == "CosmeticPlaceholder" or rewardType == "Booster" then
		return tostring(reward.DisplayName or reward.BackendId or rewardType)
	end
	return rewardType ~= "" and rewardType or "Reward"
end

local function summarizeRewards(rewards)
	local parts = {}
	for _, reward in ipairs(rewards or {}) do
		table.insert(parts, rewardSummary(reward))
	end
	return table.concat(parts, ", ")
end

function EventService.ApplyReward(player, reward)
	if typeof(reward) ~= "table" then
		return false, "InvalidReward"
	end

	local rewardType = tostring(reward.Type or "")
	local amount = math.max(0, clampInt(reward.Amount))

	if rewardType == "Ticket" then
		CurrencyService.AddTickets(player, amount)
		pushCurrencyToast(player, "ticket", "Ticket", amount)
		return true
	elseif rewardType == "WP" then
		CurrencyService.AddWeaponPoints(player, amount)
		if PickupToastService and typeof(PickupToastService.PushWeaponPoints) == "function" then
			PickupToastService.PushWeaponPoints(player, amount, "Event Reward")
		else
			pushCurrencyToast(player, "weaponPoints", "Weapon Points", amount)
		end
		return true
	elseif rewardType == "Souls" then
		CurrencyService.AddSouls(player, amount)
		pushCurrencyToast(player, "souls", "Souls", amount)
		return true
	elseif rewardType == "Material" then
		local materialId = tostring(reward.MaterialId or reward.Id or "")
		local service = getCraftingService()
		if materialId == "" or not (service and typeof(service.AddMaterial) == "function") then
			return false, "MaterialBackendUnavailable"
		end
		local ok, err = service.AddMaterial(player, materialId, amount, { toastNote = "Event Reward" })
		return ok == true, err or "MaterialGrantFailed"
	elseif rewardType == "MaterialBundle" then
		local service = getCraftingService()
		if not (service and typeof(service.AddMaterial) == "function") then
			return false, "MaterialBackendUnavailable"
		end
		for _, entry in ipairs(reward.Materials or {}) do
			local materialId = tostring(entry.MaterialId or entry.Id or "")
			local materialAmount = math.max(0, clampInt(entry.Amount))
			if materialId ~= "" and materialAmount > 0 then
				local ok, err = service.AddMaterial(player, materialId, materialAmount, { toastNote = "Event Reward" })
				if not ok then
					return false, err or "MaterialGrantFailed"
				end
			end
		end
		return true
	elseif rewardType == "Title" or rewardType == "CosmeticPlaceholder" or rewardType == "Booster" then
		local key = rewardType .. ":" .. tostring(reward.BackendId or reward.DisplayName or "")
		if not warnedRewardTypes[key] then
			warn(string.format("[EventService] TODO: Reward backend for %s is not implemented. Placeholder claimed: %s", rewardType, tostring(reward.DisplayName or reward.BackendId or "")))
			warnedRewardTypes[key] = true
		end
		return true
	end

	return false, "UnknownRewardType"
end

local function applyRewards(player, rewards)
	local granted = {}
	for _, reward in ipairs(rewards or {}) do
		local rewardCopy = deepCopy(reward)
		local ok, err = EventService.ApplyReward(player, rewardCopy)
		if not ok then
			return false, err or "RewardGrantFailed", granted
		end
		table.insert(granted, rewardCopy)
	end
	return true, nil, granted
end

function EventService.GetState(player)
	local nowUnix = EventUtil.GetUTCNow()
	local eventsData = ensureEventsData(player)
	if not eventsData then
		return {
			Success = false,
			Message = "Player data is not ready.",
			ServerNowUnix = nowUnix,
			Events = {},
		}
	end

	local events = {}
	for _, eventConfig in ipairs(EventUtil.GetEnabledEvents()) do
		table.insert(events, buildEventState(player, eventConfig, nowUnix))
	end

	return {
		Success = true,
		Message = "OK",
		ServerNowUnix = nowUnix,
		Events = events,
	}
end

local function failure(player, message, rewards)
	return {
		Success = false,
		Message = message,
		Reward = rewards and rewards[1] or nil,
		Rewards = rewards or {},
		State = EventService.GetState(player),
	}
end

local function success(player, message, rewards)
	return {
		Success = true,
		Message = message,
		Reward = rewards and rewards[1] or nil,
		Rewards = rewards or {},
		State = EventService.GetState(player),
	}
end

local function validateActiveEvent(eventConfig)
	if not eventConfig then
		return false, "EventNotFound"
	end
	if EventUtil.GetEventStatus(eventConfig, EventUtil.GetUTCNow()) ~= "Active" then
		return false, "Event is not active."
	end
	return true
end

local function claimTaskUnlocked(player, eventId, taskId)
	local eventConfig = findEvent(eventId)
	local active, activeMessage = validateActiveEvent(eventConfig)
	if not active then
		return failure(player, activeMessage)
	end

	local taskDef = findTask(eventConfig, taskId)
	if not taskDef then
		return failure(player, "TaskNotFound")
	end

	local eventProgress = getEventProgress(player, eventId)
	if not eventProgress then
		return failure(player, "Player data is not ready.")
	end

	if eventProgress.ClaimedTasks[taskId] == true then
		return failure(player, "Reward already claimed.")
	end

	local progressKey = tostring(taskDef.ProgressKey or "")
	local required = math.max(1, clampInt(taskDef.RequiredAmount))
	local current = clampInt(eventProgress.Stats[progressKey])
	if current < required then
		return failure(player, "Not enough progress.")
	end

	local ok, err, grantedRewards = applyRewards(player, taskDef.Rewards)
	if not ok then
		return failure(player, err or "RewardGrantFailed", grantedRewards)
	end

	eventProgress.ClaimedTasks[taskId] = true
	PlayerData.MarkDirty(player)
	PlayerData.Save(player, false)
	return success(player, "Claimed: " .. summarizeRewards(grantedRewards), grantedRewards)
end

local function claimMilestoneUnlocked(player, eventId, milestoneId)
	local eventConfig = findEvent(eventId)
	local active, activeMessage = validateActiveEvent(eventConfig)
	if not active then
		return failure(player, activeMessage)
	end

	local milestoneDef = findMilestone(eventConfig, milestoneId)
	if not milestoneDef then
		return failure(player, "MilestoneNotFound")
	end

	local eventProgress = getEventProgress(player, eventId)
	if not eventProgress then
		return failure(player, "Player data is not ready.")
	end

	if eventProgress.ClaimedMilestones[milestoneId] == true then
		return failure(player, "Reward already claimed.")
	end

	local completedTasks = getCompletedTaskCount(eventConfig, eventProgress)
	local required = math.max(1, clampInt(milestoneDef.RequiredCompletedTasks))
	if completedTasks < required then
		return failure(player, "Milestone is not ready.")
	end

	local ok, err, grantedRewards = applyRewards(player, milestoneDef.Rewards)
	if not ok then
		return failure(player, err or "RewardGrantFailed", grantedRewards)
	end

	eventProgress.ClaimedMilestones[milestoneId] = true
	PlayerData.MarkDirty(player)
	PlayerData.Save(player, false)
	return success(player, "Claimed: " .. summarizeRewards(grantedRewards), grantedRewards)
end

local function claimFinalUnlocked(player, eventId)
	local eventConfig = findEvent(eventId)
	local active, activeMessage = validateActiveEvent(eventConfig)
	if not active then
		return failure(player, activeMessage)
	end

	local eventProgress = getEventProgress(player, eventId)
	if not eventProgress then
		return failure(player, "Player data is not ready.")
	end

	if eventProgress.ClaimedFinalRewards == true then
		return failure(player, "Reward already claimed.")
	end

	local completedTasks = getCompletedTaskCount(eventConfig, eventProgress)
	local totalTasks = #(eventConfig.Tasks or {})
	if totalTasks <= 0 or completedTasks < totalTasks then
		return failure(player, "Final reward is not ready.")
	end

	local ok, err, grantedRewards = applyRewards(player, eventConfig.FinalRewards)
	if not ok then
		return failure(player, err or "RewardGrantFailed", grantedRewards)
	end

	eventProgress.ClaimedFinalRewards = true
	PlayerData.MarkDirty(player)
	PlayerData.Save(player, false)
	return success(player, "Claimed: " .. summarizeRewards(grantedRewards), grantedRewards)
end

local function withClaimLock(player, callback)
	if not player then
		return { Success = false, Message = "Invalid player.", Rewards = {} }
	end

	local userId = player.UserId
	local nowClock = os.clock()
	local lastRequestAt = tonumber(lastClaimRequestAt[userId]) or 0
	if nowClock - lastRequestAt < CLAIM_RATE_LIMIT_SECONDS then
		return failure(player, "Please wait before claiming again.")
	end
	lastClaimRequestAt[userId] = nowClock

	if claimLocks[userId] then
		return failure(player, "Claim already in progress.")
	end

	claimLocks[userId] = true
	local ok, result = pcall(callback)
	claimLocks[userId] = nil
	if not ok then
		warn("[EventService] Claim failed:", result)
		return failure(player, "Claim failed.")
	end
	return result
end

function EventService.ClaimTaskReward(player, eventId, taskId)
	eventId = tostring(eventId or "")
	taskId = tostring(taskId or "")
	return withClaimLock(player, function()
		return claimTaskUnlocked(player, eventId, taskId)
	end)
end

function EventService.ClaimMilestoneReward(player, eventId, milestoneId)
	eventId = tostring(eventId or "")
	milestoneId = tostring(milestoneId or "")
	return withClaimLock(player, function()
		return claimMilestoneUnlocked(player, eventId, milestoneId)
	end)
end

function EventService.ClaimFinalReward(player, eventId)
	eventId = tostring(eventId or "")
	return withClaimLock(player, function()
		return claimFinalUnlocked(player, eventId)
	end)
end

function EventService.Claim(player, eventId, claimType, targetId)
	claimType = tostring(claimType or "")
	if claimType == "Task" then
		return EventService.ClaimTaskReward(player, tostring(eventId or ""), tostring(targetId or ""))
	elseif claimType == "Milestone" then
		return EventService.ClaimMilestoneReward(player, tostring(eventId or ""), tostring(targetId or ""))
	elseif claimType == "Final" then
		return EventService.ClaimFinalReward(player, tostring(eventId or ""))
	end
	return failure(player, "Invalid claim type.")
end

local function requiredForProgressKey(eventConfig, progressKey)
	local maxRequired = 0
	for _, taskDef in ipairs(eventConfig.Tasks or {}) do
		if taskDef.ProgressKey == progressKey then
			maxRequired = math.max(maxRequired, math.max(1, clampInt(taskDef.RequiredAmount)))
		end
	end
	return maxRequired
end

function EventService.AddProgress(player, progressKey, amount, source)
	if not player then
		return { Success = false, Message = "InvalidPlayer", Applied = 0 }
	end
	progressKey = tostring(progressKey or "")
	amount = math.max(0, clampInt(amount))
	if progressKey == "" or amount <= 0 then
		return { Success = false, Message = "InvalidProgress", Applied = 0 }
	end

	local eventsData = ensureEventsData(player)
	if not eventsData then
		return { Success = false, Message = "PlayerDataUnavailable", Applied = 0 }
	end

	local changed = false
	local applied = 0
	local nowUnix = EventUtil.GetUTCNow()
	for _, eventConfig in ipairs(EventUtil.GetEnabledEvents()) do
		if EventUtil.IsEventActive(eventConfig, nowUnix) then
			local required = requiredForProgressKey(eventConfig, progressKey)
			if required > 0 then
				local eventProgress = getEventProgress(player, tostring(eventConfig.Id or ""))
				local current = clampInt(eventProgress.Stats[progressKey])
				local nextValue = math.min(required, current + amount)
				if nextValue > current then
					eventProgress.Stats[progressKey] = nextValue
					changed = true
					applied += 1
				end
			end
		end
	end

	if changed then
		PlayerData.MarkDirty(player)
	end

	return {
		Success = true,
		Message = changed and "ProgressAdded" or "NoActiveMatchingEvent",
		Applied = applied,
		ProgressKey = progressKey,
		Amount = amount,
		Source = source,
	}
end

return EventService
