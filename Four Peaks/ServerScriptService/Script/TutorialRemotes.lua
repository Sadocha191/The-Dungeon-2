-- TutorialRemotes.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end
	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remoteFunctions = ensureFolder(ReplicatedStorage, "RemoteFunctions")
local RF_GetTutorialState = ensureRemoteFunction(remoteFunctions, "RF_GetTutorialState")

local PlayerStateStore = require(game:GetService("ServerScriptService"):WaitForChild("ModuleScript"):WaitForChild("PlayerStateStore"))

RF_GetTutorialState.OnServerInvoke = function(player)
	local t = PlayerStateStore.GetTutorialState(player)
	return {
		Active = t and t.Active == true,
		Step = t and tonumber(t.Step) or 1,
		Complete = t and t.Complete == true,
	}
end
