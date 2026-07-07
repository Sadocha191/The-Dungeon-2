local ReplicatedStorage = game:GetService("ReplicatedStorage")

local replicatedModules = ReplicatedStorage:WaitForChild("ModuleScripts")
local GuildConfig = require(replicatedModules:WaitForChild("GuildConfig"))

local GuildRecordState = {}

local roleRank = {
	Owner = 3,
	Officer = 2,
	Member = 1,
}

local PRIVACY_PUBLIC = "Public"
local PRIVACY_PRIVATE = "Private"

GuildRecordState.RoleRank = roleRank
GuildRecordState.PRIVACY_PUBLIC = PRIVACY_PUBLIC
GuildRecordState.PRIVACY_PRIVATE = PRIVACY_PRIVATE

function GuildRecordState.ClampInt(value, minValue)
	local n = math.floor(tonumber(value) or 0)
	if minValue ~= nil and n < minValue then
		return minValue
	end
	if n < 0 then
		return 0
	end
	return n
end

function GuildRecordState.CopyMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" then
			if typeof(value) == "table" then
				out[key] = GuildRecordState.CopyMap(value)
			else
				out[key] = value
			end
		end
	end
	return out
end

function GuildRecordState.NormalizeName(name)
	local text = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	text = text:gsub("%s+", " ")
	return text
end

function GuildRecordState.DirectoryNameKey(name)
	return string.lower(GuildRecordState.NormalizeName(name)):gsub("%s+", "")
end

function GuildRecordState.ValidateName(name)
	local text = GuildRecordState.NormalizeName(name)
	if #text < GuildConfig.MIN_NAME_LENGTH then
		return nil, "Guild name is too short."
	end
	if #text > GuildConfig.MAX_NAME_LENGTH then
		return nil, "Guild name is too long."
	end
	if not text:match("^[%w%s%-_'%.]+$") then
		return nil, "Use letters, numbers, spaces, dash, underscore, apostrophe, or dot."
	end
	return text, nil
end

function GuildRecordState.SanitizeDescription(description)
	local text = tostring(description or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
	if #text > GuildConfig.MAX_DESCRIPTION_LENGTH then
		text = text:sub(1, GuildConfig.MAX_DESCRIPTION_LENGTH)
	end
	return text
end

function GuildRecordState.SanitizePrivacy(value)
	return tostring(value or PRIVACY_PUBLIC) == PRIVACY_PRIVATE and PRIVACY_PRIVATE or PRIVACY_PUBLIC
end

function GuildRecordState.MemberKey(userId)
	return tostring(math.floor(tonumber(userId) or 0))
end

function GuildRecordState.CountMembers(guild)
	local count = 0
	for _, member in pairs(guild.members or {}) do
		if typeof(member) == "table" then
			count += 1
		end
	end
	return count
end

function GuildRecordState.SanitizeCountMap(raw)
	local out = {}
	if typeof(raw) ~= "table" then
		return out
	end
	for key, value in pairs(raw) do
		if typeof(key) == "string" and key ~= "" then
			local amount = GuildRecordState.ClampInt(value)
			if amount > 0 then
				out[key] = amount
			end
		end
	end
	return out
end

function GuildRecordState.SanitizeTreasuryHistory(raw)
	local history = {}
	if typeof(raw) ~= "table" then
		return history
	end
	local startIndex = math.max(1, #raw - 24)
	for index = startIndex, #raw do
		local entry = raw[index]
		if typeof(entry) == "table" then
			table.insert(history, {
				userId = GuildRecordState.ClampInt(entry.userId or entry.UserId),
				username = tostring(entry.username or entry.Username or "Player"),
				resourceId = tostring(entry.resourceId or entry.ResourceId or ""),
				amount = GuildRecordState.ClampInt(entry.amount or entry.Amount),
				createdAt = GuildRecordState.ClampInt(entry.createdAt or entry.CreatedAt),
				action = tostring(entry.action or entry.Action or "Deposit"),
				reason = tostring(entry.reason or entry.Reason or ""),
			})
		end
	end
	return history
end

function GuildRecordState.EnsureTreasury(raw)
	local treasury = {}
	if typeof(raw) == "table" then
		for _, key in ipairs(GuildConfig.TREASURY_KEYS) do
			treasury[key] = GuildRecordState.ClampInt(raw[key])
		end
		treasury.resources = GuildRecordState.SanitizeCountMap(raw.resources or raw.Resources)
	end
	for _, key in ipairs(GuildConfig.TREASURY_KEYS) do
		treasury[key] = GuildRecordState.ClampInt(treasury[key])
	end
	treasury.resources = GuildRecordState.SanitizeCountMap(treasury.resources)
	return treasury
end

function GuildRecordState.AddTreasuryResource(guild, resourceId, amount)
	if typeof(guild.treasury) ~= "table" then
		guild.treasury = GuildRecordState.EnsureTreasury(nil)
	end
	guild.treasury.resources = GuildRecordState.SanitizeCountMap(guild.treasury.resources)
	local id = tostring(resourceId or "")
	if id == "" then
		return
	end
	guild.treasury.resources[id] = GuildRecordState.ClampInt(guild.treasury.resources[id]) + GuildRecordState.ClampInt(amount)
end

function GuildRecordState.AddTreasuryHistory(guild, player, resourceId, amount, action, reason)
	guild.treasuryHistory = GuildRecordState.SanitizeTreasuryHistory(guild.treasuryHistory)
	table.insert(guild.treasuryHistory, {
		userId = player.UserId,
		username = player.Name,
		resourceId = tostring(resourceId or ""),
		amount = GuildRecordState.ClampInt(amount),
		createdAt = os.time(),
		action = tostring(action or "Deposit"),
		reason = tostring(reason or ""),
	})
	while #guild.treasuryHistory > 25 do
		table.remove(guild.treasuryHistory, 1)
	end
end

function GuildRecordState.EnsureUpgrades(raw)
	local upgrades = {}
	for upgradeId in pairs(GuildConfig.UPGRADES) do
		upgrades[upgradeId] = GuildRecordState.ClampInt(typeof(raw) == "table" and raw[upgradeId] or 0)
	end
	return upgrades
end

function GuildRecordState.EnsureTasks(raw)
	local tasks = {}
	for _, def in ipairs(GuildConfig.TASKS) do
		local existing = typeof(raw) == "table" and raw[def.id] or nil
		tasks[def.id] = {
			progress = GuildRecordState.ClampInt(typeof(existing) == "table" and existing.progress or 0),
			completed = typeof(existing) == "table" and existing.completed == true or false,
		}
		if tasks[def.id].progress >= def.target then
			tasks[def.id].progress = def.target
			tasks[def.id].completed = true
		end
	end
	return tasks
end

function GuildRecordState.SanitizeUserRecords(raw, includeInviter)
	local records = {}
	if typeof(raw) ~= "table" then
		return records
	end
	for key, value in pairs(raw) do
		if typeof(value) == "table" then
			local userId = math.floor(tonumber(value.userId or value.UserId or key) or 0)
			if userId > 0 then
				local record = {
					userId = userId,
					username = tostring(value.username or value.Username or value.name or value.Name or ("Player " .. tostring(userId))),
					createdAt = GuildRecordState.ClampInt(value.createdAt or value.CreatedAt),
				}
				if includeInviter then
					record.invitedByUserId = GuildRecordState.ClampInt(value.invitedByUserId or value.InvitedByUserId)
				end
				records[GuildRecordState.MemberKey(userId)] = record
			end
		end
	end
	return records
end

function GuildRecordState.SanitizeMembers(raw)
	local members = {}
	if typeof(raw) ~= "table" then
		return members
	end
	for key, value in pairs(raw) do
		if typeof(value) == "table" then
			local userId = math.floor(tonumber(value.userId or key) or 0)
			if userId > 0 then
				local role = tostring(value.role or value.Role or "Member")
				if not roleRank[role] then
					role = "Member"
				end
				members[GuildRecordState.MemberKey(userId)] = {
					userId = userId,
					name = tostring(value.name or value.Name or ("Player " .. tostring(userId))),
					role = role,
					joinedAt = GuildRecordState.ClampInt(value.joinedAt or value.JoinedAt),
					contribution = GuildRecordState.ClampInt(value.contribution or value.Contribution),
				}
			end
		end
	end
	return members
end

function GuildRecordState.RebuildRoles(guild)
	guild.roles = {}
	for key, member in pairs(guild.members or {}) do
		if typeof(member) == "table" then
			guild.roles[key] = member.role
		end
	end
end

function GuildRecordState.SanitizeGuildRecord(raw)
	if typeof(raw) ~= "table" then
		return nil
	end
	local guildId = raw.guildId or raw.GuildId
	if typeof(guildId) ~= "string" or guildId == "" then
		return nil
	end

	local guild = {
		guildId = guildId,
		name = GuildRecordState.NormalizeName(raw.name or raw.Name or "Guild"),
		description = GuildRecordState.SanitizeDescription(raw.description or raw.Description or ""),
		privacy = GuildRecordState.SanitizePrivacy(raw.privacy or raw.Privacy),
		ownerUserId = math.floor(tonumber(raw.ownerUserId or raw.OwnerUserId) or 0),
		members = GuildRecordState.SanitizeMembers(raw.members or raw.Members),
		joinRequests = GuildRecordState.SanitizeUserRecords(raw.joinRequests or raw.JoinRequests, false),
		invites = GuildRecordState.SanitizeUserRecords(raw.invites or raw.Invites, true),
		roles = {},
		createdAt = GuildRecordState.ClampInt(raw.createdAt or raw.CreatedAt),
		level = math.max(1, GuildRecordState.ClampInt(raw.level or raw.Level, 1)),
		xp = GuildRecordState.ClampInt(raw.xp or raw.Xp or raw.XP),
		treasury = GuildRecordState.EnsureTreasury(raw.treasury or raw.Treasury),
		memberContributions = GuildRecordState.SanitizeCountMap(raw.memberContributions or raw.MemberContributions),
		totalContribution = GuildRecordState.ClampInt(raw.totalContribution or raw.TotalContribution),
		treasuryHistory = GuildRecordState.SanitizeTreasuryHistory(raw.treasuryHistory or raw.TreasuryHistory),
		upgrades = GuildRecordState.EnsureUpgrades(raw.upgrades or raw.Upgrades),
		tasks = GuildRecordState.EnsureTasks(raw.tasks or raw.Tasks),
		disbanded = raw.disbanded == true,
	}

	local owner = guild.members[GuildRecordState.MemberKey(guild.ownerUserId)]
	if owner then
		owner.role = "Owner"
	else
		for _, member in pairs(guild.members) do
			if member.role == "Owner" then
				guild.ownerUserId = member.userId
				owner = member
				break
			end
		end
	end

	guild.level = GuildConfig.GetLevelFromXp(guild.xp)
	GuildRecordState.RebuildRoles(guild)
	return guild
end

return GuildRecordState
