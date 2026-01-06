-- SCRIPT: SetupRemotes.server.lua
-- GDZIE: ServerScriptService/SetupRemotes.server.lua (Script)
-- Robi: tworzy RemoteEvent do otwierania kreatora z NPC oraz do losowania ras

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "RemoteEvents"
	folder.Parent = ReplicatedStorage
end

local function ensureRemote(name: string): RemoteEvent
	local re = folder:FindFirstChild(name)
	if not re then
		re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = folder
	end
	return re
end

ensureRemote("OpenCharacterCreation")
ensureRemote("CreateProfileRequest")
ensureRemote("CreateProfileResponse")
ensureRemote("RerollRaceRequest")
ensureRemote("RerollRaceResponse")
ensureRemote("RaceUpdated")
print("[SetupRemotes] Character creation remotes ready")
