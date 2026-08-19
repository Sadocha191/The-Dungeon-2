local EventDefinitions = {}

local RAW_EVENTS = {
	{
		Id = "SpringAssault_2026",
		Name = "Spring Assault",
		Description = "Push through the spring invasion and secure rewards for clearing enemies, elites and full runs.",
		StartTimeUtc = "2026-04-01 00:00",
		EndTimeUtc = "2026-04-30 23:59",
		Active = true,
		Theme = {
			Accent = Color3.fromRGB(120, 205, 120),
			Soft = Color3.fromRGB(50, 104, 62),
			Dark = Color3.fromRGB(17, 35, 24),
		},
		Objectives = {
			{
				Id = "Kills_200",
				Title = "Thin the Horde",
				Description = "Kill 200 enemies during the event.",
				Goal = { Key = "KILLS", Target = 200 },
				Reward = { Silver = 1800, WeaponPoints = 120 },
			},
			{
				Id = "EliteKills_18",
				Title = "Crush the Elites",
				Description = "Defeat 18 elite enemies.",
				Goal = { Key = "ELITE_KILLS", Target = 18 },
				Reward = { Silver = 2400, Tickets = 1 },
			},
			{
				Id = "RunsCompleted_3",
				Title = "Finish the Hunt",
				Description = "Complete 3 victorious runs.",
				Goal = { Key = "RUNS_COMPLETED", Target = 3 },
				Reward = { Silver = 3200, WeaponPoints = 220, Tickets = 1 },
			},
		},
	},
	{
		Id = "TreasureRush_2026",
		Name = "Treasure Rush",
		Description = "Dig deep into every run and cash in on coins, chests and boss clears before the vault closes.",
		StartTimeUtc = "2026-04-01 00:00",
		EndTimeUtc = "2026-04-18 23:59",
		Active = true,
		Theme = {
			Accent = Color3.fromRGB(255, 198, 92),
			Soft = Color3.fromRGB(118, 83, 28),
			Dark = Color3.fromRGB(33, 23, 10),
		},
		Objectives = {
			{
				Id = "CoinsEarned_15000",
				Title = "Silver Flood",
				Description = "Earn 15,000 run coins across completed or failed runs.",
				Goal = { Key = "COINS_EARNED", Target = 15000 },
				Reward = { Silver = 2800, WeaponPoints = 150 },
			},
			{
				Id = "ChestsOpened_12",
				Title = "Treasure Diver",
				Description = "Open 12 treasure chests.",
				Goal = { Key = "CHESTS_OPENED", Target = 12 },
				Reward = { Silver = 2200, Tickets = 1 },
			},
			{
				Id = "Bosses_2",
				Title = "Boss Payday",
				Description = "Defeat 2 bosses in victorious runs.",
				Goal = { Key = "BOSSES", Target = 2 },
				Reward = { Silver = 3600, WeaponPoints = 260, Tickets = 2 },
			},
		},
	},
	{
		Id = "BossStorm_2026",
		Name = "Boss Storm",
		Description = "A future placeholder event kept in config to prove the schedule supports inactive entries.",
		StartTimeUtc = "2026-05-01 00:00",
		EndTimeUtc = "2026-05-14 23:59",
		Active = true,
		Theme = {
			Accent = Color3.fromRGB(236, 111, 124),
			Soft = Color3.fromRGB(104, 44, 54),
			Dark = Color3.fromRGB(41, 14, 19),
		},
		Objectives = {
			{
				Id = "Bosses_4",
				Title = "Boss Pressure",
				Description = "Defeat 4 bosses during the event.",
				Goal = { Key = "BOSSES", Target = 4 },
				Reward = { Silver = 4200, Tickets = 2 },
			},
		},
	},
}

local DEFAULT_THEME = {
	Accent = Color3.fromRGB(111, 157, 255),
	Soft = Color3.fromRGB(45, 72, 120),
	Dark = Color3.fromRGB(15, 21, 36),
}

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

local function parseUtcTimestamp(value)
	if typeof(value) == "number" then
		return math.floor(value)
	end
	if typeof(value) ~= "string" then
		return nil
	end

	local year, month, day, hour, minute, second = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d):(%d%d)$")
	if not year then
		year, month, day, hour, minute = value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d)$")
		second = 0
	end
	if not year then
		return nil
	end

	local ok, dateTime = pcall(function()
		return DateTime.fromUniversalTime(
			tonumber(year),
			tonumber(month),
			tonumber(day),
			tonumber(hour),
			tonumber(minute),
			tonumber(second) or 0
		)
	end)
	if ok and dateTime then
		return dateTime.UnixTimestamp
	end
	return nil
end

local function normalizeReward(raw)
	local reward = {
		Silver = math.max(0, math.floor(tonumber(raw and raw.Silver) or 0)),
		WeaponPoints = math.max(0, math.floor(tonumber(raw and raw.WeaponPoints) or 0)),
		Tickets = math.max(0, math.floor(tonumber(raw and raw.Tickets) or 0)),
	}
	return reward
end

local function normalizeTheme(raw)
	local theme = deepCopy(DEFAULT_THEME)
	if typeof(raw) ~= "table" then
		return theme
	end

	for key, value in pairs(raw) do
		if typeof(value) == "Color3" then
			theme[key] = value
		end
	end
	return theme
end

local function buildObjective(entry, index)
	if typeof(entry) ~= "table" then
		return nil
	end

	local goal = typeof(entry.Goal) == "table" and entry.Goal or entry.Progress or {}
	local key = entry.Key or goal.Key
	local target = tonumber(entry.Target or goal.Target) or 0
	if typeof(key) ~= "string" or key == "" or target <= 0 then
		return nil
	end

	return {
		Id = tostring(entry.Id or ("Objective_" .. index)),
		Title = tostring(entry.Title or entry.Name or ("Objective " .. index)),
		Description = tostring(entry.Description or ""),
		Key = key,
		Target = math.max(1, math.floor(target)),
		Reward = normalizeReward(entry.Reward),
	}
end

local function buildEvent(entry, index)
	local startTime = parseUtcTimestamp(entry.StartTimeUtc or entry.StartsAtUtc or entry.StartTime)
	local endTime = parseUtcTimestamp(entry.EndTimeUtc or entry.EndsAtUtc or entry.EndTime)
	local objectives = {}
	local objectiveMap = {}

	for objectiveIndex, objectiveEntry in ipairs(entry.Objectives or {}) do
		local objective = buildObjective(objectiveEntry, objectiveIndex)
		if objective then
			table.insert(objectives, objective)
			objectiveMap[objective.Id] = objective
		end
	end

	return {
		Id = tostring(entry.Id or ("Event_" .. index)),
		Name = tostring(entry.Name or entry.Title or ("Event " .. index)),
		Description = tostring(entry.Description or ""),
		StartTime = startTime,
		EndTime = endTime,
		Active = entry.Active ~= false,
		Theme = normalizeTheme(entry.Theme),
		Objectives = objectives,
		ObjectiveMap = objectiveMap,
		RewardPreview = normalizeReward(entry.RewardPreview or entry.Reward),
		Currencies = deepCopy(entry.Currencies or {}),
		RewardTrack = deepCopy(entry.RewardTrack or {}),
		Shop = deepCopy(entry.Shop or {}),
	}
end

local compiled = {}
local byId = {}
for index, entry in ipairs(RAW_EVENTS) do
	if typeof(entry) == "table" then
		local eventDef = buildEvent(entry, index)
		if #eventDef.Objectives > 0 then
			table.insert(compiled, eventDef)
			byId[eventDef.Id] = eventDef
		end
	end
end

table.sort(compiled, function(a, b)
	local aStart = a.StartTime or 0
	local bStart = b.StartTime or 0
	if aStart == bStart then
		return a.Id < b.Id
	end
	return aStart < bStart
end)

function EventDefinitions.IsActive(eventDef, now)
	if typeof(eventDef) ~= "table" then
		return false
	end

	now = math.floor(tonumber(now) or os.time())
	if eventDef.Active == false then
		return false
	end
	if eventDef.StartTime and now < eventDef.StartTime then
		return false
	end
	if eventDef.EndTime and now > eventDef.EndTime then
		return false
	end
	return true
end

function EventDefinitions.GetAll()
	return compiled
end

function EventDefinitions.Get(id)
	return byId[id]
end

function EventDefinitions.GetObjective(eventId, objectiveId)
	local eventDef = byId[eventId]
	if not eventDef then
		return nil
	end
	return eventDef.ObjectiveMap[objectiveId]
end

function EventDefinitions.GetActiveEvents(now)
	now = math.floor(tonumber(now) or os.time())
	local events = {}
	for _, eventDef in ipairs(compiled) do
		if EventDefinitions.IsActive(eventDef, now) then
			table.insert(events, eventDef)
		end
	end
	return events
end

return EventDefinitions
