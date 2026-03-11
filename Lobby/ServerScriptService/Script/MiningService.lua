local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CraftingService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("CraftingService"))

local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEvents then
	remoteEvents = Instance.new("Folder")
	remoteEvents.Name = "RemoteEvents"
	remoteEvents.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local remote = remoteEvents:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remoteEvents
	return remote
end

local OpenMineUI = ensureRemote("OpenMineUI")
local MineSync = ensureRemote("MineSync")
local MineAction = ensureRemote("MineAction")

local function findAnyBasePart(model)
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function ensureMinePrompt()
	local existing = workspace:FindFirstChild("LobbyMine")
	local promptPart = nil

	if existing and existing:IsA("BasePart") then
		promptPart = existing
	else
		local npcs = workspace:FindFirstChild("NPCs")
		local blacksmith = npcs and npcs:FindFirstChild("Blacksmith")
		local anchor = blacksmith and findAnyBasePart(blacksmith)

		promptPart = Instance.new("Part")
		promptPart.Name = "LobbyMine"
		promptPart.Size = Vector3.new(8, 6, 8)
		promptPart.Anchored = true
		promptPart.Material = Enum.Material.Slate
		promptPart.Color = Color3.fromRGB(74, 78, 89)
		promptPart.TopSurface = Enum.SurfaceType.Smooth
		promptPart.BottomSurface = Enum.SurfaceType.Smooth
		promptPart.Parent = workspace

		if anchor then
			promptPart.CFrame = anchor.CFrame * CFrame.new(14, 0, 0)
		else
			local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
			if spawnLocation then
				promptPart.CFrame = spawnLocation.CFrame * CFrame.new(12, 0, 0)
			else
				promptPart.Position = Vector3.new(0, 4, 0)
			end
		end
	end

	local prompt = promptPart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptPart
	end

	prompt.ObjectText = "Mine"
	prompt.ActionText = "Start Mining"
	prompt.Triggered:Connect(function(player)
		OpenMineUI:FireClient(player)
	end)
end

local function sync(player, result)
	local snapshot = CraftingService.GetMiningSnapshot(player)
	if result then
		snapshot.lastResult = result
	end
	MineSync:FireClient(player, snapshot)
end

ensureMinePrompt()

MineAction.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	local actionType = tostring(payload.type or "")
	if actionType == "request" then
		sync(player)
		return
	end

	local ok = false
	local details = nil
	local reason = nil

	if actionType == "start" then
		ok, details = CraftingService.StartMining(player, tonumber(payload.durationSec) or 0, payload.priority)
		if ok ~= true then
			reason = details
		end
	elseif actionType == "stop" then
		ok, details = CraftingService.StopMining(player)
		if ok ~= true then
			reason = details
		end
	else
		reason = "UnknownAction"
	end

	sync(player, {
		type = actionType,
		ok = ok == true,
		reason = reason,
		details = ok == true and details or nil,
	})
end)

print("[MiningService] Ready")
