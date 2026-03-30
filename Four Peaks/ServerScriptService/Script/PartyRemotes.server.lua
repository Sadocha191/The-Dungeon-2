-- PartyRemotes.server.lua (Lobby)
-- Binds RemoteEvents for party actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local modules = ServerScriptService:WaitForChild("ModuleScript")
local PartyService = require(modules:WaitForChild("PartyService"))

local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "RemoteEvents"
	folder.Parent = ReplicatedStorage
end

local function ensureRE(name: string): RemoteEvent
	local re = folder:FindFirstChild(name)
	if re and re:IsA("RemoteEvent") then return re end
	re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = folder
	return re
end

local function ensureRF(name: string): RemoteFunction
	local rf = folder:FindFirstChild(name)
	if rf and rf:IsA("RemoteFunction") then return rf end
	rf = Instance.new("RemoteFunction")
	rf.Name = name
	rf.Parent = folder
	return rf
end

local PartyAction = ensureRE("PartyAction")
local PartyQuery = ensureRF("PartyQuery")

PartyQuery.OnServerInvoke = function(plr: Player, queryType: any)
	if queryType == "GetParty" then
		local party = PartyService.GetPartyForPlayer(plr)
		if not party then return { id = nil } end
		-- reuse serializer via PartyUpdated broadcast: we can just fire a PartyUpdated soon,
		-- but RF needs immediate payload so we build minimal.
		local members = {}
		for userId, _ in pairs(party.members) do
			local p = game:GetService("Players"):GetPlayerByUserId(userId)
			local name = p and p.Name or tostring(userId)
			table.insert(members, { userId = userId, name = name })
		end
		table.sort(members, function(a,b) return a.userId < b.userId end)
		return { id = party.id, leaderUserId = party.leaderUserId, members = members, maxMembers = 5 }
	end
	return nil
end

PartyAction.OnServerEvent:Connect(function(plr: Player, action: any, a: any)
	if typeof(action) ~= "string" then return end
	if action == "Invite" then
		local targetUserId = tonumber(a)
		if not targetUserId then return end
		local target = game:GetService("Players"):GetPlayerByUserId(targetUserId)
		if not target then return end
		PartyService.Invite(plr, target)
	elseif action == "Accept" then
		local fromUserId = tonumber(a)
		if not fromUserId then return end
		PartyService.AcceptInvite(plr, fromUserId)
	elseif action == "Decline" then
		local fromUserId = tonumber(a)
		if not fromUserId then return end
		PartyService.DeclineInvite(plr, fromUserId)
	elseif action == "Leave" then
		PartyService.Leave(plr)
	elseif action == "Kick" then
		local targetUserId = tonumber(a)
		if not targetUserId then return end
		PartyService.Kick(plr, targetUserId)
	elseif action == "Disband" then
		PartyService.Disband(plr)
	end
end)

print("[PartyRemotes] Ready")
