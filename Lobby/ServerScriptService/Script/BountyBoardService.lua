local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local CraftingService = require(serverModules:WaitForChild("CraftingService"))
local CurrencyService = require(serverModules:WaitForChild("CurrencyService"))
local PickupToastService = require(serverModules:WaitForChild("PickupToastService"))

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local CraftingConfig = require(moduleFolder:WaitForChild("CraftingConfig"))

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

local BountyBoardEvent = ensureRemote("BountyBoardEvent")

local MAX_ACTIVE_PER_PLAYER = 5
local MAX_ACTIVE_TOTAL = 60
local MIN_AMOUNT = 1
local MAX_AMOUNT = 99
local MIN_REWARD_PER_UNIT = 1
local MAX_REWARD_PER_UNIT = 50000

local activeBounties = {}
local nextBountyId = 0

local function clampInt(value)
	value = math.floor(tonumber(value) or 0)
	if value < 0 then
		return 0
	end
	return value
end

local function parseBoundedInt(value, minValue, maxValue)
	local parsed = math.floor(tonumber(value) or 0)
	if parsed < minValue or parsed > maxValue then
		return nil
	end
	return parsed
end

local function getPlayerLabel(player)
	local displayName = tostring(player.DisplayName or "")
	if displayName ~= "" then
		return displayName
	end
	return player.Name
end

local function getNextBountyId()
	nextBountyId += 1
	return string.format("bounty_%d_%d", os.time(), nextBountyId)
end

local function getActiveCount()
	local total = 0
	for _ in pairs(activeBounties) do
		total += 1
	end
	return total
end

local function getPosterActiveCount(userId)
	local total = 0
	for _, bounty in pairs(activeBounties) do
		if bounty.posterUserId == userId then
			total += 1
		end
	end
	return total
end

local function getSortedBounties()
	local list = {}
	for _, bounty in pairs(activeBounties) do
		table.insert(list, bounty)
	end
	table.sort(list, function(a, b)
		if a.totalReward ~= b.totalReward then
			return a.totalReward > b.totalReward
		end
		if a.rewardPerUnit ~= b.rewardPerUnit then
			return a.rewardPerUnit > b.rewardPerUnit
		end
		if a.createdAt ~= b.createdAt then
			return a.createdAt > b.createdAt
		end
		return tostring(a.id) < tostring(b.id)
	end)
	return list
end

local function buildBountyEntry(player, bounty)
	local materialDef = CraftingConfig.GetMaterialDef(bounty.materialId) or {}
	local owned = select(1, CraftingService.GetMaterialCount(player, bounty.materialId))
	return {
		id = bounty.id,
		posterUserId = bounty.posterUserId,
		posterName = bounty.posterName,
		posterUsername = bounty.posterUsername,
		materialId = bounty.materialId,
		materialName = materialDef.name or bounty.materialId,
		bucket = materialDef.bucket,
		source = materialDef.source or "",
		rarity = materialDef.rarity,
		amount = bounty.amount,
		rewardPerUnit = bounty.rewardPerUnit,
		totalReward = bounty.totalReward,
		createdAt = bounty.createdAt,
		owned = owned,
		isOwn = bounty.posterUserId == player.UserId,
		canFulfill = bounty.posterUserId ~= player.UserId and owned >= bounty.amount,
	}
end

local function buildSnapshot(player, result)
	local inventory = CraftingService.BuildMaterialInventorySnapshot(player)
	local bounties = {}
	for _, bounty in ipairs(getSortedBounties()) do
		table.insert(bounties, buildBountyEntry(player, bounty))
	end
	return {
		silver = clampInt(inventory.silver),
		materials = inventory.materials,
		mineResources = inventory.mineResources,
		mobMaterials = inventory.mobMaterials,
		bounties = bounties,
		activeOwnedCount = getPosterActiveCount(player.UserId),
		maxActivePerPlayer = MAX_ACTIVE_PER_PLAYER,
		maxAmount = MAX_AMOUNT,
		maxRewardPerUnit = MAX_REWARD_PER_UNIT,
		lastResult = result,
	}
end

local function syncPlayer(player, result)
	if not player or not player.Parent then
		return
	end
	BountyBoardEvent:FireClient(player, {
		type = "SYNC",
		data = buildSnapshot(player, result),
	})
end

local function syncAll(resultByUserId)
	for _, player in ipairs(Players:GetPlayers()) do
		local result = resultByUserId and resultByUserId[player.UserId] or nil
		syncPlayer(player, result)
	end
end

local function openBoard(player)
	if not player or not player.Parent then
		return
	end
	BountyBoardEvent:FireClient(player, { type = "OPEN" })
	syncPlayer(player)
end

local function findAnyBasePart(model)
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

local function findBoardModel()
	local directMatch = workspace:FindFirstChild("BountyBoard")
	if directMatch and directMatch:IsA("Model") then
		return directMatch
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "BountyBoard" and descendant:IsA("Model") then
			return descendant
		end
	end

	return nil
end

local function setupPrompt()
	local boardModel = findBoardModel()
	if not boardModel then
		warn("[BountyBoardService] Missing BountyBoard model in Workspace")
		return
	end

	local boardPart = boardModel:FindFirstChild("Board")
	if not (boardPart and boardPart:IsA("BasePart")) then
		boardPart = boardModel:FindFirstChild("Board", true)
	end
	if not (boardPart and boardPart:IsA("BasePart")) then
		boardPart = findAnyBasePart(boardModel)
	end
	if not boardPart then
		warn("[BountyBoardService] BountyBoard has no BasePart")
		return
	end

	local prompt = boardPart:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = boardPart
	end

	prompt.ObjectText = "Bounty Board"
	prompt.ActionText = "Browse Bounties"
	prompt.Triggered:Connect(openBoard)
end

local function createBounty(player, payload)
	if getActiveCount() >= MAX_ACTIVE_TOTAL then
		return false, "BoardFull"
	end
	if getPosterActiveCount(player.UserId) >= MAX_ACTIVE_PER_PLAYER then
		return false, "TooManyActiveBounties"
	end

	local materialId = tostring(payload.materialId or "")
	local materialDef = CraftingConfig.GetMaterialDef(materialId)
	if not materialDef or not materialDef.bucket then
		return false, "UnknownMaterial"
	end

	local amount = parseBoundedInt(payload.amount, MIN_AMOUNT, MAX_AMOUNT)
	if not amount then
		return false, "BadAmount"
	end

	local rewardPerUnit = parseBoundedInt(payload.rewardPerUnit, MIN_REWARD_PER_UNIT, MAX_REWARD_PER_UNIT)
	if not rewardPerUnit then
		return false, "BadReward"
	end

	local totalReward = amount * rewardPerUnit
	if not CurrencyService.SpendSilver(player, totalReward) then
		return false, "NotEnoughSilver"
	end

	local bounty = {
		id = getNextBountyId(),
		posterUserId = player.UserId,
		posterName = getPlayerLabel(player),
		posterUsername = player.Name,
		materialId = materialId,
		amount = amount,
		rewardPerUnit = rewardPerUnit,
		totalReward = totalReward,
		createdAt = os.time(),
	}
	activeBounties[bounty.id] = bounty
	return true, bounty
end

local function cancelBounty(player, bountyId)
	local bounty = activeBounties[bountyId]
	if not bounty then
		return false, "UnknownBounty"
	end
	if bounty.posterUserId ~= player.UserId then
		return false, "Forbidden"
	end

	activeBounties[bountyId] = nil
	CurrencyService.AddSilver(player, bounty.totalReward)
	PickupToastService.PushSilver(player, bounty.totalReward, "Bounty Refund")
	return true, bounty
end

local function fulfillBounty(player, bountyId)
	local bounty = activeBounties[bountyId]
	if not bounty then
		return false, "UnknownBounty"
	end
	if bounty.posterUserId == player.UserId then
		return false, "OwnBounty"
	end

	local poster = Players:GetPlayerByUserId(bounty.posterUserId)
	if not poster then
		activeBounties[bountyId] = nil
		return false, "PosterUnavailable"
	end

	local spent, reason = CraftingService.TrySpendMaterial(player, bounty.materialId, bounty.amount)
	if not spent then
		return false, reason
	end

	local delivered, deliverReason = CraftingService.AddMaterial(poster, bounty.materialId, bounty.amount, {
		toastNote = "Bounty Delivery",
	})
	if not delivered then
		CraftingService.AddMaterial(player, bounty.materialId, bounty.amount, {
			silentToast = true,
		})
		return false, deliverReason or "DeliveryFailed"
	end

	CurrencyService.AddSilver(player, bounty.totalReward)
	PickupToastService.PushSilver(player, bounty.totalReward, "Bounty Reward")
	activeBounties[bountyId] = nil

	return true, {
		bounty = bounty,
		poster = poster,
	}
end

local function refundPlayerBounties(player)
	local refund = 0
	for bountyId, bounty in pairs(activeBounties) do
		if bounty.posterUserId == player.UserId then
			refund += bounty.totalReward
			activeBounties[bountyId] = nil
		end
	end
	if refund > 0 then
		CurrencyService.AddSilver(player, refund)
	end
	return refund
end

setupPrompt()

BountyBoardEvent.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then
		return
	end

	local actionType = tostring(payload.type or "")
	if actionType == "REQUEST_SYNC" then
		syncPlayer(player)
		return
	end

	if actionType == "OPEN" then
		openBoard(player)
		return
	end

	if actionType == "CREATE" then
		local ok, result = createBounty(player, payload)
		if ok then
			syncAll({
				[player.UserId] = {
					type = "CREATE",
					ok = true,
					message = "Bounty posted.",
					bountyId = result.id,
				},
			})
		else
			syncPlayer(player, {
				type = "CREATE",
				ok = false,
				reason = result,
			})
		end
		return
	end

	if actionType == "CANCEL" then
		local ok, result = cancelBounty(player, tostring(payload.bountyId or ""))
		if ok then
			syncAll({
				[player.UserId] = {
					type = "CANCEL",
					ok = true,
					message = "Bounty cancelled. Silver refunded.",
					bountyId = result.id,
				},
			})
		else
			syncPlayer(player, {
				type = "CANCEL",
				ok = false,
				reason = result,
			})
		end
		return
	end

	if actionType == "FULFILL" then
		local ok, result = fulfillBounty(player, tostring(payload.bountyId or ""))
		if ok then
			local bounty = result.bounty
			local poster = result.poster
			syncAll({
				[player.UserId] = {
					type = "FULFILL",
					ok = true,
					message = string.format("Delivered %d x %s for %d silver.", bounty.amount, bounty.materialId, bounty.totalReward),
					bountyId = bounty.id,
				},
				[poster.UserId] = {
					type = "FULFILL",
					ok = true,
					message = string.format("%s completed your bounty for %d x %s.", player.Name, bounty.amount, bounty.materialId),
					bountyId = bounty.id,
				},
			})
		else
			syncPlayer(player, {
				type = "FULFILL",
				ok = false,
				reason = result,
			})
		end
		return
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		syncPlayer(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local refunded = refundPlayerBounties(player)
	if refunded > 0 then
		syncAll()
	end
end)

print("[BountyBoardService] Ready")
