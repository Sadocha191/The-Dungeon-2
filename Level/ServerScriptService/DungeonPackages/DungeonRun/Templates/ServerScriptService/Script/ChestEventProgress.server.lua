local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local EventProgress = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("EventProgress"))

local lastOpenedCount: {[number]: number} = {}
local countConnections: {[number]: RBXScriptConnection} = {}

local function getOpenedCount(player: Player): number
	return math.max(0, math.floor(tonumber(player:GetAttribute("ChestOpenedCount")) or 0))
end

local function reportOpenedChests(player: Player, amount: number)
	if amount <= 0 or player.Parent ~= Players then
		return
	end

	local ok, err = pcall(EventProgress.Add, player, "ChestsOpened", amount, "ChestService")
	if not ok then
		warn("[ChestEventProgress] Failed to update event progress:", err)
	end
end

local function attachPlayer(player: Player)
	local userId = player.UserId
	lastOpenedCount[userId] = getOpenedCount(player)

	local previousConnection = countConnections[userId]
	if previousConnection then
		previousConnection:Disconnect()
	end

	countConnections[userId] = player:GetAttributeChangedSignal("ChestOpenedCount"):Connect(function()
		local previous = lastOpenedCount[userId] or 0
		local current = getOpenedCount(player)
		lastOpenedCount[userId] = current

		local added = current - previous
		if added > 0 then
			reportOpenedChests(player, added)
		end
	end)
end

Players.PlayerAdded:Connect(attachPlayer)
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	local connection = countConnections[userId]
	if connection then
		connection:Disconnect()
	end
	countConnections[userId] = nil
	lastOpenedCount[userId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	attachPlayer(player)
end

print("[ChestEventProgress] Ready")
