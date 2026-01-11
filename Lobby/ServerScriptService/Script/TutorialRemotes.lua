-- TutorialRemotes.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteFunctions = ReplicatedStorage:FindFirstChild("RemoteFunctions")
if not remoteFunctions then
	remoteFunctions = Instance.new("Folder")
	remoteFunctions.Name = "RemoteFunctions"
	remoteFunctions.Parent = ReplicatedStorage
end

local RF_GetTutorialState = remoteFunctions:FindFirstChild("RF_GetTutorialState")
if not RF_GetTutorialState then
	RF_GetTutorialState = Instance.new("RemoteFunction")
	RF_GetTutorialState.Name = "RF_GetTutorialState"
	RF_GetTutorialState.Parent = remoteFunctions
end

local PlayerStateStore = require(game:GetService("ServerScriptService"):WaitForChild("ModuleScript"):WaitForChild("PlayerStateStore"))

RF_GetTutorialState.OnServerInvoke = function(player)
	local t = PlayerStateStore.GetTutorialState(player)
	return {
		Active = t and t.Active == true,
		Step = t and tonumber(t.Step) or 1,
		Complete = t and t.Complete == true,
	}
end
