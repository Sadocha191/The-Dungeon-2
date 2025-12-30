-- SCRIPT: CombatRemotes.server.lua
-- GDZIE: ServerScriptService/CombatRemotes.server.lua (Script)
-- CO: RemoteEvent do ataku (na razie tylko walidacja + throttling). Damage dodamy później.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "RemoteEvents"
	folder.Parent = ReplicatedStorage
end

local function ensure(name: string): RemoteEvent
	local re = folder:FindFirstChild(name)
	if not re then
		re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = folder
	end
	return re
end

ensure("AttackRequest")
print("[CombatRemotes] AttackRequest ready")
