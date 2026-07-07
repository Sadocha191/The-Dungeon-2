local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local moduleFolder = ServerScriptService:WaitForChild("ModuleScript")
local replicatedModules = ReplicatedStorage:WaitForChild("ModuleScripts")

local PlayerData = require(moduleFolder:WaitForChild("PlayerData"))
local CurrencyService = require(moduleFolder:WaitForChild("CurrencyService"))
local GuildRecordState = require(moduleFolder:WaitForChild("GuildRecordState"))
local GuildConfig = require(replicatedModules:WaitForChild("GuildConfig"))

local GuildService = {}

local guildStore = DataStoreService:GetDataStore("GuildRecords_v1")
local directoryStore = DataStoreService:GetDataStore("GuildDirectory_v1")
local DIRECTORY_KEY = "guilds"

local guildCache = {}
local guildDirty = {}
local directoryLoaded = false
local directory = {
	guilds = {},
}

local roleRank = GuildRecordState.RoleRank
local PRIVACY_PUBLIC = GuildRecordState.PRIVACY_PUBLIC
local PRIVACY_PRIVATE = GuildRecordState.PRIVACY_PRIVATE
local clampInt = GuildRecordState.ClampInt
local copyMap = GuildRecordState.CopyMap
local normalizeName = GuildRecordState.NormalizeName
local directoryNameKey = GuildRecordState.DirectoryNameKey
local validateName = GuildRecordState.ValidateName
local sanitizeDescription = GuildRecordState.SanitizeDescription
local sanitizePrivacy = GuildRecordState.SanitizePrivacy
local memberKey = GuildRecordState.MemberKey
local countMembers = GuildRecordState.CountMembers
local sanitizeCountMap = GuildRecordState.SanitizeCountMap
local ensureTreasury = GuildRecordState.EnsureTreasury
local addTreasuryResource = GuildRecordState.AddTreasuryResource
local addTreasuryHistory = GuildRecordState.AddTreasuryHistory
local ensureUpgrades = GuildRecordState.EnsureUpgrades
local ensureTasks = GuildRecordState.EnsureTasks
local rebuildRoles = GuildRecordState.RebuildRoles
local sanitizeGuildRecord = GuildRecordState.SanitizeGuildRecord

local guildUpdatedRemote = nil

local function loadDirectory()
	if directoryLoaded then
		return
	end
	directoryLoaded = true
	local ok, saved = pcall(function()
		return directoryStore:GetAsync(DIRECTORY_KEY)
	end)
	if ok and typeof(saved) == "table" and typeof(saved.guilds) == "table" then
		directory.guilds = saved.guilds
	else
		if not ok then
			warn("[GuildService] Guild directory DataStore unavailable; using memory for this server:", saved)
		end
		directory.guilds = directory.guilds or {}
	end
end

local function saveDirectory()
	loadDirectory()
	local ok, err = pcall(function()
		directoryStore:SetAsync(DIRECTORY_KEY, directory)
	end)
	if not ok then
		warn("[GuildService] Failed to save guild directory:", err)
	end
	return ok
end

local function updateDirectoryEntry(guild)
	loadDirectory()
	if guild.disbanded then
		directory.guilds[guild.guildId] = nil
		return saveDirectory()
	end
	directory.guilds[guild.guildId] = {
		guildId = guild.guildId,
		name = guild.name,
		nameKey = directoryNameKey(guild.name),
		ownerUserId = guild.ownerUserId,
		level = guild.level,
		memberCount = countMembers(guild),
		privacy = sanitizePrivacy(guild.privacy),
		updatedAt = os.time(),
	}
	return saveDirectory()
end

local function loadGuild(guildId)
	if typeof(guildId) ~= "string" or guildId == "" then
		return nil
	end
	if guildCache[guildId] then
		return guildCache[guildId]
	end
	local ok, saved = pcall(function()
		return guildStore:GetAsync(guildId)
	end)
	if not ok then
		warn("[GuildService] Guild DataStore unavailable; using cached memory only:", saved)
		return nil
	end
	local guild = sanitizeGuildRecord(saved)
	if guild then
		guildCache[guildId] = guild
	end
	return guild
end

local function saveGuild(guild, force)
	if not guild or not guild.guildId then
		return false
	end
	guild.level = GuildConfig.GetLevelFromXp(guild.xp)
	rebuildRoles(guild)
	guildCache[guild.guildId] = guild
	if not force and not guildDirty[guild.guildId] then
		return true
	end
	local ok, err = pcall(function()
		guildStore:SetAsync(guild.guildId, guild)
	end)
	if ok then
		guildDirty[guild.guildId] = nil
	else
		guildDirty[guild.guildId] = true
		warn("[GuildService] Failed to save guild:", guild.guildId, err)
	end
	updateDirectoryEntry(guild)
	return ok
end

local function markGuildDirty(guild)
	if guild and guild.guildId then
		guildDirty[guild.guildId] = true
	end
end

local function getGuildUpdatedRemote()
	if guildUpdatedRemote and guildUpdatedRemote.Parent then
		return guildUpdatedRemote
	end

	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEvents then
		remoteEvents = Instance.new("Folder")
		remoteEvents.Name = "RemoteEvents"
		remoteEvents.Parent = ReplicatedStorage
	end

	local event = remoteEvents:FindFirstChild("GuildUpdated")
	if event and event:IsA("RemoteEvent") then
		guildUpdatedRemote = event
		return event
	end
	if event then
		event:Destroy()
	end

	event = Instance.new("RemoteEvent")
	event.Name = "GuildUpdated"
	event.Parent = remoteEvents
	guildUpdatedRemote = event
	return event
end

local function fireGuildUpdated(player, payload, sent)
	if not player or not player.Parent then
		return
	end
	if sent[player.UserId] then
		return
	end
	sent[player.UserId] = true

	local remote = getGuildUpdatedRemote()
	pcall(function()
		remote:FireClient(player, payload)
	end)
end

local function broadcastGuildUpdated(guild, reason, extraPlayers)
	if not guild or typeof(guild.guildId) ~= "string" then
		return
	end

	local payload = {
		GuildId = guild.guildId,
		Reason = reason or "Updated",
		ServerNowUnix = os.time(),
	}
	local sent = {}

	for _, member in pairs(guild.members or {}) do
		if typeof(member) == "table" then
			fireGuildUpdated(Players:GetPlayerByUserId(member.userId), payload, sent)
		end
	end

	for _, player in ipairs(extraPlayers or {}) do
		fireGuildUpdated(player, payload, sent)
	end
end

local function clearPlayerMembership(player)
	local data = PlayerData.Get(player)
	data.Guild = {
		GuildId = nil,
		Role = nil,
		JoinedAt = 0,
		Contribution = 0,
	}
	PlayerData.MarkDirty(player)
end

local function setPlayerMembership(player, guild, member)
	local data = PlayerData.Get(player)
	data.Guild = {
		GuildId = guild.guildId,
		Role = member.role,
		JoinedAt = member.joinedAt,
		Contribution = clampInt(member.contribution),
	}
	PlayerData.MarkDirty(player)
end

local function syncOnlineMember(userId, guild, member)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		if guild and member then
			setPlayerMembership(player, guild, member)
		else
			clearPlayerMembership(player)
		end
	end
end

local function getMembership(player)
	local data = PlayerData.Get(player)
	local membership = typeof(data.Guild) == "table" and data.Guild or nil
	local guildId = membership and membership.GuildId
	if typeof(guildId) ~= "string" or guildId == "" then
		return nil, nil
	end

	local guild = loadGuild(guildId) or guildCache[guildId]
	local member = guild and guild.members and guild.members[memberKey(player.UserId)] or nil
	if not guild or guild.disbanded or not member then
		clearPlayerMembership(player)
		return nil, nil
	end

	if membership.Role ~= member.role or clampInt(membership.Contribution) ~= clampInt(member.contribution) then
		setPlayerMembership(player, guild, member)
	end

	return guild, member
end

local function hasOwnerRole(member)
	return member and member.role == "Owner"
end

local function hasJoinManagerRole(member)
	return member and roleRank[member.role] and roleRank[member.role] >= roleRank.Officer
end

local function buildUserRecordList(records)
	local list = {}
	if typeof(records) ~= "table" then
		return list
	end
	for _, record in pairs(records) do
		if typeof(record) == "table" then
			table.insert(list, {
				UserId = clampInt(record.userId),
				Username = tostring(record.username or ("Player " .. tostring(record.userId or ""))),
				InvitedByUserId = record.invitedByUserId and clampInt(record.invitedByUserId) or nil,
				CreatedAt = clampInt(record.createdAt),
			})
		end
	end
	table.sort(list, function(a, b)
		if (a.CreatedAt or 0) == (b.CreatedAt or 0) then
			return tostring(a.Username) < tostring(b.Username)
		end
		return (a.CreatedAt or 0) < (b.CreatedAt or 0)
	end)
	return list
end

local function buildPlayerInviteList(player)
	loadDirectory()
	local invites = {}
	local key = memberKey(player.UserId)
	for guildId, entry in pairs(directory.guilds) do
		if typeof(entry) == "table" then
			local guild = loadGuild(guildId) or guildCache[guildId]
			local invite = guild and guild.invites and guild.invites[key] or nil
			if guild and not guild.disbanded and typeof(invite) == "table" then
				table.insert(invites, {
					GuildId = guild.guildId,
					GuildName = guild.name,
					Privacy = sanitizePrivacy(guild.privacy),
					Level = clampInt(guild.level, 1),
					MemberCount = countMembers(guild),
					MaxMembers = GuildConfig.MAX_MEMBERS,
					InvitedByUserId = clampInt(invite.invitedByUserId),
					CreatedAt = clampInt(invite.createdAt),
				})
			end
		end
	end
	table.sort(invites, function(a, b)
		return (a.CreatedAt or 0) < (b.CreatedAt or 0)
	end)
	return invites
end

local function addTaskProgressToGuild(guild, taskId, amount)
	if not guild or typeof(taskId) ~= "string" then
		return false
	end
	local taskState = guild.tasks and guild.tasks[taskId]
	if not taskState then
		return false
	end
	local target = 1
	for _, def in ipairs(GuildConfig.TASKS) do
		if def.id == taskId then
			target = math.max(1, clampInt(def.target, 1))
			break
		end
	end
	if taskState.completed == true then
		return true
	end
	taskState.progress = math.min(target, clampInt(taskState.progress) + math.max(0, clampInt(amount)))
	taskState.completed = taskState.progress >= target
	markGuildDirty(guild)
	return true
end

local function setTaskProgress(guild, taskId, progress)
	if not guild or typeof(taskId) ~= "string" then
		return false
	end
	local taskState = guild.tasks and guild.tasks[taskId]
	if not taskState then
		return false
	end
	local target = 1
	for _, def in ipairs(GuildConfig.TASKS) do
		if def.id == taskId then
			target = math.max(1, clampInt(def.target, 1))
			break
		end
	end
	taskState.progress = math.min(target, math.max(0, clampInt(progress)))
	taskState.completed = taskState.progress >= target
	markGuildDirty(guild)
	return true
end

local function getCompletedTaskCount(guild)
	local completed = 0
	for _, def in ipairs(GuildConfig.TASKS) do
		local taskState = guild.tasks and guild.tasks[def.id]
		if taskState and taskState.completed == true then
			completed += 1
		end
	end
	return completed
end

local function buildTaskList(guild)
	local tasks = {}
	for index, def in ipairs(GuildConfig.TASKS) do
		local taskState = guild.tasks and guild.tasks[def.id] or {}
		local progress = math.min(def.target, clampInt(taskState.progress))
		table.insert(tasks, {
			Id = def.id,
			DisplayName = def.displayName,
			Description = def.description,
			Current = progress,
			Target = def.target,
			Completed = taskState.completed == true or progress >= def.target,
			LayoutOrder = index,
		})
	end
	return tasks
end

local function buildMemberList(guild)
	local members = {}
	for _, member in pairs(guild.members or {}) do
		table.insert(members, {
			UserId = member.userId,
			Name = member.name,
			Role = member.role,
			JoinedAt = member.joinedAt,
			Contribution = clampInt(member.contribution),
		})
	end
	table.sort(members, function(a, b)
		if (a.Contribution or 0) == (b.Contribution or 0) then
			return tostring(a.Name) < tostring(b.Name)
		end
		return (a.Contribution or 0) > (b.Contribution or 0)
	end)
	return members
end

local function buildUpgradeList(guild)
	local upgrades = {}
	for upgradeId, def in pairs(GuildConfig.UPGRADES) do
		local level = clampInt(guild.upgrades and guild.upgrades[upgradeId])
		table.insert(upgrades, {
			Id = upgradeId,
			DisplayName = def.displayName,
			Description = def.description,
			Level = level,
			MaxLevel = def.maxLevel,
			CostSilver = GuildConfig.GetUpgradeCost(upgradeId, level),
		})
	end
	table.sort(upgrades, function(a, b)
		return tostring(a.DisplayName) < tostring(b.DisplayName)
	end)
	return upgrades
end

local function buildGuildSnapshot(guild, includeJoinManagement)
	if not guild then
		return nil
	end
	local snapshot = {
		GuildId = guild.guildId,
		Name = guild.name,
		Description = guild.description,
		Privacy = sanitizePrivacy(guild.privacy),
		OwnerUserId = guild.ownerUserId,
		CreatedAt = guild.createdAt,
		Level = guild.level,
		XP = guild.xp,
		Treasury = copyMap(guild.treasury),
		TotalContribution = clampInt(guild.totalContribution),
		TreasuryHistory = copyMap(guild.treasuryHistory),
		Upgrades = copyMap(guild.upgrades),
		UpgradeList = buildUpgradeList(guild),
		Members = buildMemberList(guild),
		MemberCount = countMembers(guild),
		MaxMembers = GuildConfig.MAX_MEMBERS,
		Tasks = buildTaskList(guild),
		CompletedTasks = getCompletedTaskCount(guild),
		TotalTasks = #GuildConfig.TASKS,
	}
	if includeJoinManagement then
		snapshot.JoinRequests = buildUserRecordList(guild.joinRequests)
		snapshot.Invites = buildUserRecordList(guild.invites)
	end
	return snapshot
end

local function buildConfigSnapshot()
	local donationResources = {}
	for _, resource in ipairs(GuildConfig.DONATION_RESOURCES) do
		table.insert(donationResources, copyMap(resource))
	end
	return {
		GuildPlaceId = GuildConfig.GUILD_PLACE_ID,
		DonationResources = donationResources,
		TreasuryKeys = table.clone(GuildConfig.TREASURY_KEYS),
	}
end

local function buildPlayerResources(player)
	local balances = CurrencyService.GetBalances(player)
	return {
		Silver = clampInt(balances.Silver),
		Souls = clampInt(balances.Souls),
		Tickets = clampInt(balances.Tickets),
		WeaponPoints = clampInt(balances.WeaponPoints),
	}
end

local function buildState(player, message, success)
	local guild, member = getMembership(player)
	local role = member and member.role or nil
	local canManageJoin = hasJoinManagerRole(member)
	return {
		Success = success ~= false,
		Message = message or "",
		ServerNowUnix = os.time(),
		Guild = buildGuildSnapshot(guild, canManageJoin),
		Membership = member and {
			GuildId = guild.guildId,
			Role = role,
			JoinedAt = member.joinedAt,
			Contribution = clampInt(member.contribution),
		} or nil,
		CanManage = role == "Owner",
		CanManageJoin = canManageJoin,
		CanDisband = role == "Owner",
		Invites = buildPlayerInviteList(player),
		PlayerResources = buildPlayerResources(player),
		Config = buildConfigSnapshot(),
	}
end

local function failState(player, message)
	return buildState(player, message, false)
end

local function findGuildByName(name)
	loadDirectory()
	local key = directoryNameKey(name)
	for guildId, entry in pairs(directory.guilds) do
		if typeof(entry) == "table" and entry.nameKey == key then
			return guildId, entry
		end
	end
	return nil, nil
end

function GuildService.GetState(player)
	return buildState(player)
end

function GuildService.Search(player, query)
	loadDirectory()
	local text = normalizeName(query)
	local key = string.lower(text)
	local results = {}
	for guildId, entry in pairs(directory.guilds) do
		if typeof(entry) == "table" then
			local name = tostring(entry.name or "")
			if key == "" or string.find(string.lower(name), key, 1, true) then
				local guild = loadGuild(guildId) or guildCache[guildId]
				local playerKey = memberKey(player.UserId)
				table.insert(results, {
					GuildId = guildId,
					Name = name,
					Level = clampInt(entry.level, 1),
					MemberCount = clampInt(entry.memberCount),
					MaxMembers = GuildConfig.MAX_MEMBERS,
					OwnerUserId = clampInt(entry.ownerUserId),
					Privacy = sanitizePrivacy((guild and guild.privacy) or entry.privacy),
					RequestPending = guild and guild.joinRequests and guild.joinRequests[playerKey] ~= nil or false,
					InvitePending = guild and guild.invites and guild.invites[playerKey] ~= nil or false,
				})
			end
		end
	end
	table.sort(results, function(a, b)
		return tostring(a.Name) < tostring(b.Name)
	end)
	while #results > 20 do
		table.remove(results)
	end
	local state = buildState(player)
	state.SearchResults = results
	return state
end

local function addPlayerToGuild(player, guild, message, reason)
	if not player or not guild then
		return failState(player, "Invalid guild.")
	end
	if countMembers(guild) >= GuildConfig.MAX_MEMBERS then
		return failState(player, "Guild is full.")
	end
	local currentGuild = getMembership(player)
	if currentGuild then
		return failState(player, "Leave your current guild first.")
	end

	local key = memberKey(player.UserId)
	if guild.members[key] then
		return failState(player, "You are already in this guild.")
	end

	local member = {
		userId = player.UserId,
		name = player.DisplayName ~= "" and player.DisplayName or player.Name,
		role = "Member",
		joinedAt = os.time(),
		contribution = 0,
	}
	guild.members[key] = member
	if guild.joinRequests then
		guild.joinRequests[key] = nil
	end
	if guild.invites then
		guild.invites[key] = nil
	end
	rebuildRoles(guild)
	setTaskProgress(guild, "recruit_members", countMembers(guild))
	markGuildDirty(guild)
	saveGuild(guild, true)
	setPlayerMembership(player, guild, member)
	PlayerData.Save(player, false)
	broadcastGuildUpdated(guild, reason or "MemberJoined", { player })
	return buildState(player, message or "Joined guild.")
end

local function resolveInviteTarget(raw)
	local text = tostring(raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local userId = math.floor(tonumber(text) or 0)
	local username = ""
	if userId > 0 then
		local online = Players:GetPlayerByUserId(userId)
		if online then
			username = online.DisplayName ~= "" and online.DisplayName or online.Name
		else
			local ok, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			username = ok and tostring(name) or ("Player " .. tostring(userId))
		end
	elseif text ~= "" then
		local ok, resolvedUserId = pcall(function()
			return Players:GetUserIdFromNameAsync(text)
		end)
		if ok and tonumber(resolvedUserId) then
			userId = math.floor(tonumber(resolvedUserId) or 0)
			username = text
		end
	end
	if userId <= 0 then
		return nil, nil, "Player not found."
	end
	if username == "" then
		username = "Player " .. tostring(userId)
	end
	return userId, username, nil
end

function GuildService.CreateGuild(player, name)
	local existingGuild = getMembership(player)
	if existingGuild then
		return failState(player, "You are already in a guild.")
	end

	local cleanName, nameError = validateName(name)
	if not cleanName then
		return failState(player, nameError)
	end
	if findGuildByName(cleanName) then
		return failState(player, "A guild with that name already exists.")
	end

	local guildId = "guild_" .. HttpService:GenerateGUID(false):gsub("%-", ""):sub(1, 16)
	local now = os.time()
	local member = {
		userId = player.UserId,
		name = player.DisplayName ~= "" and player.DisplayName or player.Name,
		role = "Owner",
		joinedAt = now,
		contribution = 0,
	}
	local guild = {
		guildId = guildId,
		name = cleanName,
		description = "",
		privacy = PRIVACY_PUBLIC,
		ownerUserId = player.UserId,
		members = {
			[memberKey(player.UserId)] = member,
		},
		joinRequests = {},
		invites = {},
		roles = {},
		createdAt = now,
		level = 1,
		xp = 0,
		treasury = ensureTreasury(nil),
		upgrades = ensureUpgrades(nil),
		tasks = ensureTasks(nil),
		disbanded = false,
	}
	rebuildRoles(guild)
	setTaskProgress(guild, "recruit_members", countMembers(guild))
	guildCache[guildId] = guild
	markGuildDirty(guild)
	saveGuild(guild, true)
	setPlayerMembership(player, guild, member)
	PlayerData.Save(player, false)
	broadcastGuildUpdated(guild, "Created")
	return buildState(player, "Guild created.")
end

function GuildService.RequestJoin(player, guildId)
	local currentGuild = getMembership(player)
	if currentGuild then
		return failState(player, "Leave your current guild first.")
	end
	if typeof(guildId) ~= "string" or guildId == "" then
		return failState(player, "Invalid guild.")
	end

	local guild = loadGuild(guildId) or guildCache[guildId]
	if not guild or guild.disbanded then
		return failState(player, "Guild not found.")
	end
	if countMembers(guild) >= GuildConfig.MAX_MEMBERS then
		return failState(player, "Guild is full.")
	end
	local key = memberKey(player.UserId)
	if guild.members[key] then
		return failState(player, "You are already in this guild.")
	end
	if guild.joinRequests[key] then
		return failState(player, "Join request already sent.")
	end
	if guild.invites[key] then
		return failState(player, "You already have an invite. Accept it from Invites.")
	end

	guild.joinRequests[key] = {
		userId = player.UserId,
		username = player.DisplayName ~= "" and player.DisplayName or player.Name,
		createdAt = os.time(),
	}
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "JoinRequestCreated", { player })
	return buildState(player, "Join request sent.")
end

function GuildService.JoinGuild(player, guildId)
	if typeof(guildId) ~= "string" or guildId == "" then
		return failState(player, "Invalid guild.")
	end

	local guild = loadGuild(guildId) or guildCache[guildId]
	if not guild or guild.disbanded then
		return failState(player, "Guild not found.")
	end
	if countMembers(guild) >= GuildConfig.MAX_MEMBERS then
		return failState(player, "Guild is full.")
	end
	if sanitizePrivacy(guild.privacy) == PRIVACY_PRIVATE then
		return GuildService.RequestJoin(player, guildId)
	end

	return addPlayerToGuild(player, guild, "Joined guild.", "MemberJoined")
end

function GuildService.SetPrivacy(player, privacy)
	local guild, member = getMembership(player)
	if not guild or not hasJoinManagerRole(member) then
		return failState(player, "Only the owner or officers can change guild privacy.")
	end
	local nextPrivacy = sanitizePrivacy(privacy)
	if guild.privacy == nextPrivacy then
		return buildState(player, "Guild is already " .. nextPrivacy .. ".")
	end
	guild.privacy = nextPrivacy
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "PrivacyChanged")
	return buildState(player, "Guild privacy set to " .. nextPrivacy .. ".")
end

function GuildService.AcceptJoinRequest(player, targetUserId)
	local guild, member = getMembership(player)
	if not guild or not hasJoinManagerRole(member) then
		return failState(player, "Only the owner or officers can accept requests.")
	end
	local targetKey = memberKey(targetUserId)
	local request = guild.joinRequests and guild.joinRequests[targetKey]
	if not request then
		return failState(player, "Join request not found.")
	end
	if countMembers(guild) >= GuildConfig.MAX_MEMBERS then
		return failState(player, "Guild is full.")
	end
	if guild.members[targetKey] then
		guild.joinRequests[targetKey] = nil
		markGuildDirty(guild)
		saveGuild(guild, true)
		return buildState(player, "Player is already a member.")
	end

	local targetPlayer = Players:GetPlayerByUserId(clampInt(request.userId))
	if not targetPlayer then
		return failState(player, "Player must be online to accept this request.")
	end
	local currentGuild = getMembership(targetPlayer)
	if currentGuild then
		return failState(player, "Player is already in a guild.")
	end

	local joinedState = addPlayerToGuild(targetPlayer, guild, "Joined guild.", "JoinRequestAccepted")
	if joinedState and joinedState.Success == false then
		return failState(player, joinedState.Message or "Could not accept request.")
	end
	return buildState(player, "Join request accepted.")
end

function GuildService.RejectJoinRequest(player, targetUserId)
	local guild, member = getMembership(player)
	if not guild or not hasJoinManagerRole(member) then
		return failState(player, "Only the owner or officers can reject requests.")
	end
	local targetKey = memberKey(targetUserId)
	local request = guild.joinRequests and guild.joinRequests[targetKey]
	if not request then
		return failState(player, "Join request not found.")
	end
	guild.joinRequests[targetKey] = nil
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "JoinRequestRejected", { Players:GetPlayerByUserId(clampInt(request.userId)) })
	return buildState(player, "Join request rejected.")
end

function GuildService.SendInvite(player, rawTarget)
	local guild, member = getMembership(player)
	if not guild or not hasJoinManagerRole(member) then
		return failState(player, "Only the owner or officers can send invites.")
	end
	local userId, username, resolveError = resolveInviteTarget(rawTarget)
	if not userId then
		return failState(player, resolveError)
	end
	local key = memberKey(userId)
	if guild.members[key] then
		return failState(player, "Player is already in this guild.")
	end
	if guild.invites[key] then
		return failState(player, "Invite already exists.")
	end
	local targetPlayer = Players:GetPlayerByUserId(userId)
	if targetPlayer then
		local currentGuild = getMembership(targetPlayer)
		if currentGuild then
			return failState(player, "Player is already in a guild.")
		end
	end

	guild.invites[key] = {
		userId = userId,
		username = username,
		invitedByUserId = player.UserId,
		createdAt = os.time(),
	}
	if guild.joinRequests then
		guild.joinRequests[key] = nil
	end
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "InviteSent", { targetPlayer })
	return buildState(player, "Invite sent.")
end

function GuildService.CancelInvite(player, targetUserId)
	local guild, member = getMembership(player)
	if not guild or not hasJoinManagerRole(member) then
		return failState(player, "Only the owner or officers can cancel invites.")
	end
	local targetKey = memberKey(targetUserId)
	local invite = guild.invites and guild.invites[targetKey]
	if not invite then
		return failState(player, "Invite not found.")
	end
	guild.invites[targetKey] = nil
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "InviteCancelled", { Players:GetPlayerByUserId(clampInt(invite.userId)) })
	return buildState(player, "Invite cancelled.")
end

function GuildService.AcceptInvite(player, guildId)
	local currentGuild = getMembership(player)
	if currentGuild then
		return failState(player, "Leave your current guild first.")
	end
	if typeof(guildId) ~= "string" or guildId == "" then
		return failState(player, "Invalid invite.")
	end
	local guild = loadGuild(guildId) or guildCache[guildId]
	if not guild or guild.disbanded then
		return failState(player, "Guild not found.")
	end
	local key = memberKey(player.UserId)
	if not (guild.invites and guild.invites[key]) then
		return failState(player, "Invite not found.")
	end
	return addPlayerToGuild(player, guild, "Invite accepted.", "InviteAccepted")
end

function GuildService.DeclineInvite(player, guildId)
	if typeof(guildId) ~= "string" or guildId == "" then
		return failState(player, "Invalid invite.")
	end
	local guild = loadGuild(guildId) or guildCache[guildId]
	if not guild or guild.disbanded then
		return failState(player, "Guild not found.")
	end
	local key = memberKey(player.UserId)
	if not (guild.invites and guild.invites[key]) then
		return failState(player, "Invite not found.")
	end
	guild.invites[key] = nil
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "InviteDeclined", { player })
	return buildState(player, "Invite declined.")
end

local function disbandGuild(guild, reason)
	guild.disbanded = true
	for _, member in pairs(guild.members or {}) do
		syncOnlineMember(member.userId, nil, nil)
	end
	markGuildDirty(guild)
	saveGuild(guild, true)
	updateDirectoryEntry(guild)
	broadcastGuildUpdated(guild, reason or "Disbanded")
end

function GuildService.LeaveGuild(player)
	local guild, member = getMembership(player)
	if not guild or not member then
		return failState(player, "You are not in a guild.")
	end

	if member.role == "Owner" then
		local replacement = nil
		for _, candidate in pairs(guild.members) do
			if candidate.userId ~= player.UserId and (not replacement or roleRank[candidate.role] > roleRank[replacement.role]) then
				replacement = candidate
			end
		end
		if replacement then
			replacement.role = "Owner"
			guild.ownerUserId = replacement.userId
			syncOnlineMember(replacement.userId, guild, replacement)
			guild.members[memberKey(player.UserId)] = nil
			clearPlayerMembership(player)
			rebuildRoles(guild)
			setTaskProgress(guild, "recruit_members", countMembers(guild))
			markGuildDirty(guild)
			saveGuild(guild, true)
			PlayerData.Save(player, false)
			broadcastGuildUpdated(guild, "MemberLeft", { player })
			return buildState(player, "You left the guild. Ownership was transferred.")
		end
		disbandGuild(guild, "Disbanded")
		clearPlayerMembership(player)
		PlayerData.Save(player, false)
		return buildState(player, "Guild disbanded because you were the last member.")
	end

	guild.members[memberKey(player.UserId)] = nil
	clearPlayerMembership(player)
	rebuildRoles(guild)
	setTaskProgress(guild, "recruit_members", countMembers(guild))
	markGuildDirty(guild)
	saveGuild(guild, true)
	PlayerData.Save(player, false)
	broadcastGuildUpdated(guild, "MemberLeft", { player })
	return buildState(player, "You left the guild.")
end

function GuildService.EditDescription(player, description)
	local guild, member = getMembership(player)
	if not guild or not hasOwnerRole(member) then
		return failState(player, "Only the owner can edit the description.")
	end
	guild.description = sanitizeDescription(description)
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "DescriptionChanged")
	return buildState(player, "Description updated.")
end

function GuildService.SetMemberRole(player, targetUserId, role)
	local guild, member = getMembership(player)
	if not guild or not hasOwnerRole(member) then
		return failState(player, "Only the owner can manage roles.")
	end
	local targetKey = memberKey(targetUserId)
	local target = guild.members[targetKey]
	if not target then
		return failState(player, "Member not found.")
	end
	if target.userId == player.UserId or target.role == "Owner" then
		return failState(player, "Owner role cannot be changed here.")
	end
	if role ~= "Officer" and role ~= "Member" then
		return failState(player, "Invalid role.")
	end
	target.role = role
	rebuildRoles(guild)
	syncOnlineMember(target.userId, guild, target)
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "RoleChanged")
	return buildState(player, "Role updated.")
end

function GuildService.KickMember(player, targetUserId)
	local guild, member = getMembership(player)
	if not guild or not hasOwnerRole(member) then
		return failState(player, "Only the owner can kick members.")
	end
	local targetKey = memberKey(targetUserId)
	local target = guild.members[targetKey]
	if not target then
		return failState(player, "Member not found.")
	end
	if target.role == "Owner" or target.userId == player.UserId then
		return failState(player, "Owner cannot be kicked.")
	end
	local targetPlayer = Players:GetPlayerByUserId(target.userId)
	guild.members[targetKey] = nil
	rebuildRoles(guild)
	setTaskProgress(guild, "recruit_members", countMembers(guild))
	syncOnlineMember(target.userId, nil, nil)
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "MemberKicked", { targetPlayer })
	return buildState(player, "Member kicked.")
end

function GuildService.DisbandGuild(player)
	local guild, member = getMembership(player)
	if not guild or not hasOwnerRole(member) then
		return failState(player, "Only the owner can disband the guild.")
	end
	disbandGuild(guild, "Disbanded")
	clearPlayerMembership(player)
	PlayerData.Save(player, false)
	return buildState(player, "Guild disbanded.")
end

function GuildService.Donate(player, resourceId, amount)
	local guild, member = getMembership(player)
	if not guild or not member then
		return failState(player, "Join a guild before donating.")
	end
	local resource = GuildConfig.GetDonationResource(tostring(resourceId or ""))
	if not resource then
		return failState(player, "Unknown donation resource.")
	end
	local donation = clampInt(amount)
	if donation < resource.minAmount then
		return failState(player, "Donation amount is too small.")
	end

	if not CurrencyService.RemoveCurrency(player, resource.id, donation) then
		return failState(player, "Not enough " .. resource.displayName .. ".")
	end

	guild.treasury[resource.id] = clampInt(guild.treasury[resource.id]) + donation
	local xpGain = math.max(1, math.floor(donation * resource.xpPerUnit + 0.5))
	local contributionGain = math.max(1, math.floor(donation * resource.contributionPerUnit + 0.5))
	local totalContributionBase = clampInt(guild.totalContribution)
	local memberContributionTotal = 0
	for _, guildMember in pairs(guild.members or {}) do
		if typeof(guildMember) == "table" then
			memberContributionTotal += clampInt(guildMember.contribution)
		end
	end
	guild.xp = clampInt(guild.xp) + xpGain
	guild.level = GuildConfig.GetLevelFromXp(guild.xp)
	member.contribution = clampInt(member.contribution) + contributionGain
	guild.memberContributions = sanitizeCountMap(guild.memberContributions)
	guild.memberContributions[memberKey(player.UserId)] = clampInt(guild.memberContributions[memberKey(player.UserId)]) + contributionGain
	guild.totalContribution = math.max(totalContributionBase, memberContributionTotal) + contributionGain
	addTreasuryResource(guild, resource.id, donation)
	addTreasuryHistory(guild, player, resource.id, donation, "Deposit", "Lobby donation")

	addTaskProgressToGuild(guild, "donate_any", contributionGain)
	if resource.id == "Silver" then
		addTaskProgressToGuild(guild, "donate_silver", donation)
	end

	setPlayerMembership(player, guild, member)
	markGuildDirty(guild)
	saveGuild(guild, true)
	PlayerData.Save(player, false)
	broadcastGuildUpdated(guild, "DonationChanged")
	return buildState(player, "Donation accepted.")
end

function GuildService.Upgrade(player, upgradeId)
	local guild, member = getMembership(player)
	if not guild or not hasOwnerRole(member) then
		return failState(player, "Only the owner can buy guild upgrades.")
	end
	local def = GuildConfig.GetUpgrade(tostring(upgradeId or ""))
	if not def then
		return failState(player, "Unknown upgrade.")
	end
	local currentLevel = clampInt(guild.upgrades[def.id])
	local cost = GuildConfig.GetUpgradeCost(def.id, currentLevel)
	if not cost then
		return failState(player, "Upgrade is already maxed.")
	end
	if clampInt(guild.treasury.Silver) < cost then
		return failState(player, "Not enough guild Silver in treasury.")
	end

	guild.treasury.Silver -= cost
	guild.treasury.resources = sanitizeCountMap(guild.treasury.resources)
	guild.treasury.resources.Silver = math.max(0, clampInt(guild.treasury.resources.Silver) - cost)
	addTreasuryHistory(guild, player, "Silver", cost, "Spend", def.displayName .. " upgrade")
	guild.upgrades[def.id] = currentLevel + 1
	guild.xp += math.max(1, math.floor(cost * 0.25))
	guild.level = GuildConfig.GetLevelFromXp(guild.xp)
	addTaskProgressToGuild(guild, "upgrade_any", 1)
	markGuildDirty(guild)
	saveGuild(guild, true)
	broadcastGuildUpdated(guild, "UpgradeChanged")
	return buildState(player, def.displayName .. " upgraded.")
end

function GuildService.TeleportToCastle(player)
	local guild = getMembership(player)
	if not guild then
		return failState(player, "Join a guild before entering the castle.")
	end
	local placeId = tonumber(GuildConfig.GUILD_PLACE_ID) or 0
	if placeId <= 0 then
		return failState(player, "Guild place is not configured yet.")
	end

	local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
	local teleportStatus = remoteEvents and remoteEvents:FindFirstChild("TeleportStatus")
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		guildId = guild.guildId,
		GuildId = guild.guildId,
		sourcePlace = "Four Peaks",
	})

	addTaskProgressToGuild(guild, "visit_castle", 1)
	markGuildDirty(guild)
	saveGuild(guild, true)
	PlayerData.Save(player, false)
	broadcastGuildUpdated(guild, "CastleTeleport")

	if teleportStatus and teleportStatus:IsA("RemoteEvent") then
		teleportStatus:FireClient(player, { type = "teleporting", target = "guild" })
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, { player }, options)
	end)
	if not ok then
		warn("[GuildService] Guild teleport failed:", err)
		if teleportStatus and teleportStatus:IsA("RemoteEvent") then
			teleportStatus:FireClient(player, { type = "failed", reason = "guild_teleport_failed" })
		end
		return failState(player, "Teleport failed.")
	end

	return buildState(player, "Teleporting to guild castle.")
end

function GuildService.AddTaskProgress(player, taskId, amount)
	local guild = getMembership(player)
	if not guild then
		return false, "NoGuild"
	end
	local ok = addTaskProgressToGuild(guild, taskId, amount)
	if ok then
		saveGuild(guild, true)
		broadcastGuildUpdated(guild, "TaskProgress")
	end
	return ok, ok and nil or "UnknownTask"
end

function GuildService.AddTaskProgressForGuild(guildId, taskId, amount)
	local guild = loadGuild(guildId) or guildCache[guildId]
	if not guild or guild.disbanded then
		return false, "GuildNotFound"
	end
	local ok = addTaskProgressToGuild(guild, taskId, amount)
	if ok then
		saveGuild(guild, true)
		broadcastGuildUpdated(guild, "TaskProgress")
	end
	return ok, ok and nil or "UnknownTask"
end

function GuildService.GetGuildRecord(guildId)
	local guild = loadGuild(guildId) or guildCache[guildId]
	if not guild or guild.disbanded then
		return nil
	end
	return buildGuildSnapshot(guild)
end

Players.PlayerRemoving:Connect(function(player)
	local guild = getMembership(player)
	if guild then
		saveGuild(guild, false)
	end
end)

game:BindToClose(function()
	for _, guild in pairs(guildCache) do
		saveGuild(guild, true)
	end
	saveDirectory()
end)

return GuildService
