-- SCRIPT: ChatRESetup.server.lua
-- GDZIE: ServerScriptService/ChatRESetup.server.lua (Script)
-- Cel: naprawia "Infinite yield possible on ReplicatedStorage:WaitForChild('ChatRE')"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local re = ReplicatedStorage:FindFirstChild("ChatRE")
if not re then
	re = Instance.new("RemoteEvent")
	re.Name = "ChatRE"
	re.Parent = ReplicatedStorage
end

print("[Server] ChatRE exists")
-- SCRIPT: ChatRESetup.server.lua
-- GDZIE: ServerScriptService/ChatRESetup.server.lua (Script)
-- Cel: naprawia "Infinite yield possible on ReplicatedStorage:WaitForChild('ChatRE')"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local re = ReplicatedStorage:FindFirstChild("ChatRE")
if not re then
	re = Instance.new("RemoteEvent")
	re.Name = "ChatRE"
	re.Parent = ReplicatedStorage
end

print("[Server] ChatRE exists")
