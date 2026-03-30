-- PartyService.lua (Lobby / ServerScriptService / ModuleScript)
-- Lightweight party system for multiplayer teleports.
-- Server-authoritative. Clients call via remotes; server broadcasts PartyUpdated/PartyInvite.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_MEMBERS = 5
local INVITE_TTL_SECONDS = 25

local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name: string): RemoteEvent
	local re = remoteFolder:FindFirstChild(name)
	if re and re:IsA("RemoteEvent") then return re end
	re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = remoteFolder
	return re
end

local PartyUpdated = ensureRemoteEvent("PartyUpdated")
local PartyInvite = ensureRemoteEvent("PartyInvite")

local PartyService = {}

-- state
local partiesById: {[string]: any} = {}
local partyIdByUser: {[number]: string} = {}
local pendingInvites: {[number]: {[number]: number}} = {} -- toUserId -> { fromUserId = expiresAt }

local function now(): number
	return os.clock()
end

local function newPartyId(leaderUserId: number): string
	return string.format("p_%d_%d", leaderUserId, math.floor(os.time()))
end

local function getPlayer(userId: number): Player?
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then return p end
	end
	return nil
end

local function serializeParty(party: any)
	local members = {}
	for userId, _ in pairs(party.members) do
		local plr = getPlayer(userId)
		local name = plr and plr.Name or tostring(userId)
		table.insert(members, { userId = userId, name = name })
	end
	table.sort(members, function(a,b) return a.userId < b.userId end)
	return {
		id = party.id,
		leaderUserId = party.leaderUserId,
		members = members,
		maxMembers = MAX_MEMBERS,
	}
end

local function broadcastParty(party: any)
	local payload = serializeParty(party)
	for userId, _ in pairs(party.members) do
		local plr = getPlayer(userId)
		if plr then
			PartyUpdated:FireClient(plr, payload)
		end
	end
end

local function clearPartyForUser(userId: number)
	partyIdByUser[userId] = nil
end

local function removeParty(party: any)
	partiesById[party.id] = nil
	for userId, _ in pairs(party.members) do
		clearPartyForUser(userId)
	end
end

function PartyService.GetPartyForPlayer(plr: Player)
	local pid = partyIdByUser[plr.UserId]
	if not pid then return nil end
	return partiesById[pid]
end

function PartyService.GetPartyIdForUserId(userId: number): string?
	return partyIdByUser[userId]
end

function PartyService.GetOnlinePartyPlayers(party: any): {Player}
	local list = {}
	for userId, _ in pairs(party.members) do
		local plr = getPlayer(userId)
		if plr then table.insert(list, plr) end
	end
	-- leader first
	table.sort(list, function(a,b)
		if a.UserId == party.leaderUserId then return true end
		if b.UserId == party.leaderUserId then return false end
		return a.UserId < b.UserId
	end)
	return list
end

local function ensurePartyForLeader(leader: Player)
	local existing = PartyService.GetPartyForPlayer(leader)
	if existing then return existing end
	local party = {
		id = newPartyId(leader.UserId),
		leaderUserId = leader.UserId,
		members = { [leader.UserId] = true },
		createdAt = now(),
	}
	partiesById[party.id] = party
	partyIdByUser[leader.UserId] = party.id
	return party
end

local function isMember(party: any, userId: number): boolean
	return party and party.members and party.members[userId] == true
end

local function memberCount(party: any): number
	local c = 0
	for _, _ in pairs(party.members) do c += 1 end
	return c
end

function PartyService.Leave(plr: Player)
	local party = PartyService.GetPartyForPlayer(plr)
	if not party then return end

	party.members[plr.UserId] = nil
	clearPartyForUser(plr.UserId)

	local count = memberCount(party)
	if count <= 0 then
		removeParty(party)
		return
	end

	-- if leader left, promote lowest userId to leader
	if party.leaderUserId == plr.UserId then
		local newLeader
		for userId, _ in pairs(party.members) do
			if not newLeader or userId < newLeader then
				newLeader = userId
			end
		end
		party.leaderUserId = newLeader
	end

	broadcastParty(party)
end

function PartyService.Kick(leader: Player, targetUserId: number)
	local party = PartyService.GetPartyForPlayer(leader)
	if not party then return false, "no_party" end
	if party.leaderUserId ~= leader.UserId then return false, "not_leader" end
	if targetUserId == leader.UserId then return false, "cant_kick_self" end
	if not isMember(party, targetUserId) then return false, "not_member" end

	party.members[targetUserId] = nil
	clearPartyForUser(targetUserId)
	broadcastParty(party)

	local targetPlr = getPlayer(targetUserId)
	if targetPlr then
		PartyUpdated:FireClient(targetPlr, { id = nil })
	end
	return true
end

function PartyService.Invite(leader: Player, targetPlr: Player)
	if not targetPlr or not targetPlr.Parent then return false, "no_target" end
	if targetPlr.UserId == leader.UserId then return false, "self" end

	local party = PartyService.GetPartyForPlayer(leader)
	if party then
		if party.leaderUserId ~= leader.UserId then return false, "not_leader" end
	else
		party = ensurePartyForLeader(leader)
	end

	if memberCount(party) >= MAX_MEMBERS then
		return false, "full"
	end

	-- target already in a party
	if partyIdByUser[targetPlr.UserId] then
		return false, "target_in_party"
	end

	pendingInvites[targetPlr.UserId] = pendingInvites[targetPlr.UserId] or {}
	pendingInvites[targetPlr.UserId][leader.UserId] = now() + INVITE_TTL_SECONDS

	PartyInvite:FireClient(targetPlr, {
		type = "invite",
		fromUserId = leader.UserId,
		fromName = leader.Name,
		partyId = party.id,
		expiresIn = INVITE_TTL_SECONDS,
	})

	broadcastParty(party)
	return true
end

function PartyService.AcceptInvite(plr: Player, fromUserId: number)
	local invites = pendingInvites[plr.UserId]
	local exp = invites and invites[fromUserId]
	if not exp then return false, "no_invite" end
	if exp < now() then
		invites[fromUserId] = nil
		return false, "expired"
	end

	-- cannot join if already in party
	if partyIdByUser[plr.UserId] then
		invites[fromUserId] = nil
		return false, "already_in_party"
	end

	local leaderPlr = getPlayer(fromUserId)
	if not leaderPlr then
		invites[fromUserId] = nil
		return false, "leader_offline"
	end

	local party = PartyService.GetPartyForPlayer(leaderPlr)
	if not party or party.leaderUserId ~= fromUserId then
		invites[fromUserId] = nil
		return false, "party_missing"
	end

	if memberCount(party) >= MAX_MEMBERS then
		invites[fromUserId] = nil
		return false, "full"
	end

	party.members[plr.UserId] = true
	partyIdByUser[plr.UserId] = party.id
	invites[fromUserId] = nil

	broadcastParty(party)
	return true
end

function PartyService.DeclineInvite(plr: Player, fromUserId: number)
	local invites = pendingInvites[plr.UserId]
	if invites then
		invites[fromUserId] = nil
	end
	return true
end

function PartyService.Disband(leader: Player)
	local party = PartyService.GetPartyForPlayer(leader)
	if not party then return false, "no_party" end
	if party.leaderUserId ~= leader.UserId then return false, "not_leader" end

	local payload = { id = nil }
	for userId, _ in pairs(party.members) do
		local plr = getPlayer(userId)
		if plr then PartyUpdated:FireClient(plr, payload) end
	end
	removeParty(party)
	return true
end

-- cleanup
Players.PlayerRemoving:Connect(function(plr)
	pendingInvites[plr.UserId] = nil
	PartyService.Leave(plr)
end)

return PartyService
