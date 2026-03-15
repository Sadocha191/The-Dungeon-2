-- LoadingClient.client.lua (Level1)
-- Keeps one shared loading overlay alive until the run world is prepared, streamed,
-- and its replicated textures / lighting finish preloading on the client.

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClientReady = remotes:WaitForChild("ClientReady")
local ClientWorldLoaded = remotes:WaitForChild("ClientWorldLoaded")

local RunStarted = ReplicatedStorage:WaitForChild("RunStarted")
local RunLoadingState = ReplicatedStorage:WaitForChild("RunLoadingState")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local LoadingOverlay = require(moduleFolder:WaitForChild("ClientLoadingOverlay"))

local overlayToken = LoadingOverlay.Acquire({
	title = "Loading...",
	message = "Preparing assets",
	progress = 0,
})

local hasRequestStreamAround = pcall(function()
	return Workspace.RequestStreamAroundAsync
end)

local function updateOverlay(progress: number?, message: string)
	LoadingOverlay.Update(overlayToken, {
		title = "Loading...",
		message = message,
		progress = progress,
	})
end

local function appendDescendants(list, root: Instance?)
	if not root or not root.Parent then
		return
	end

	table.insert(list, root)
	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(list, descendant)
	end
end

local function collectBasePreloadInstances()
	local instances = {}

	appendDescendants(instances, ReplicatedStorage:FindFirstChild("Assets"))
	appendDescendants(instances, ReplicatedStorage:FindFirstChild("Enemies"))
	appendDescendants(instances, moduleFolder)

	return instances
end

local function collectWorldPreloadInstances()
	local instances = {}

	appendDescendants(instances, Workspace)
	appendDescendants(instances, Lighting)
	appendDescendants(instances, localPlayer:FindFirstChild("PlayerGui"))

	return instances
end

local function preloadInstances(instances, startProgress: number, endProgress: number, message: string)
	local total = math.max(#instances, 1)
	local chunkSize = 180
	local loaded = 0

	if #instances == 0 then
		updateOverlay(endProgress, message)
		return
	end

	for i = 1, #instances, chunkSize do
		local chunk = {}
		for j = i, math.min(i + chunkSize - 1, #instances) do
			table.insert(chunk, instances[j])
		end

		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(chunk)
		end)
		if not ok then
			warn("[LoadingClient] PreloadAsync error:", err)
		end

		loaded += #chunk
		local alpha = loaded / total
		updateOverlay(startProgress + ((endProgress - startProgress) * alpha), message)
	end
end

local function waitForPhase(timeoutSec: number): boolean
	local deadline = os.clock() + timeoutSec
	while os.clock() <= deadline do
		local phase = tostring(RunLoadingState:GetAttribute("Phase") or "")
		if phase == "prepared" or phase == "running" then
			return true
		end
		task.wait(0.05)
	end
	return false
end

local function waitForCharacterRoot(timeoutSec: number): BasePart?
	local deadline = os.clock() + timeoutSec
	while os.clock() <= deadline do
		local char = localPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return hrp
		end
		task.wait(0.05)
	end
	return nil
end

local function requestInitialStream()
	if Workspace.StreamingEnabled ~= true or not hasRequestStreamAround then
		return
	end

	local hrp = waitForCharacterRoot(10)
	if not hrp then
		return
	end

	local ok, err = pcall(function()
		Workspace:RequestStreamAroundAsync(hrp.Position)
	end)
	if not ok then
		warn("[LoadingClient] RequestStreamAroundAsync error:", err)
	end
end

local function readExpectedCount(name: string): number
	return math.max(0, math.floor(tonumber(RunLoadingState:GetAttribute(name)) or 0))
end

local function getFolderCount(name: string): number
	local folder = Workspace:FindFirstChild(name)
	if not folder then
		return 0
	end
	return #folder:GetChildren()
end

local function waitForWorldReplication(generation: number, timeoutSec: number)
	local deadline = os.clock() + timeoutSec
	local expectedChests = readExpectedCount("ChestsCount")
	local expectedShrines = readExpectedCount("ShrinesCount")
	local expectedStatues = readExpectedCount("StatuesCount")
	local expectedMonuments = readExpectedCount("MonumentsCount")

	while os.clock() <= deadline do
		if tonumber(RunLoadingState:GetAttribute("Generation")) ~= generation then
			return
		end

		local chestsReady = getFolderCount("Chests") >= expectedChests
		local shrinesReady = getFolderCount("Shrines") >= expectedShrines
		local statuesReady = getFolderCount("Statues") >= (expectedStatues + expectedMonuments)
		if chestsReady and shrinesReady and statuesReady then
			return
		end

		task.wait(0.1)
	end

	warn("[LoadingClient] Timed out while waiting for full replicated world counts; continuing with available instances")
end

local function waitForRequestQueue(timeoutSec: number)
	local deadline = os.clock() + timeoutSec
	while os.clock() <= deadline do
		if ContentProvider.RequestQueueSize <= 0 then
			break
		end
		task.wait(0.1)
	end
end

preloadInstances(collectBasePreloadInstances(), 0, 0.4, "Preparing shared assets")

updateOverlay(0.42, "Waiting for level generation")
ClientReady:FireServer()

local prepared = waitForPhase(20)
if not prepared then
	warn("[LoadingClient] Timed out while waiting for world preparation")
end

local generation = math.max(0, math.floor(tonumber(RunLoadingState:GetAttribute("Generation")) or 0))

updateOverlay(0.5, "Streaming level")
requestInitialStream()
waitForWorldReplication(generation, 10)

updateOverlay(0.72, "Preloading textures and lighting")
preloadInstances(collectWorldPreloadInstances(), 0.72, 0.96, "Preloading textures and lighting")

updateOverlay(0.98, "Finalizing level")
waitForRequestQueue(8)
task.wait(0.15)

ClientWorldLoaded:FireServer(generation)

if not RunStarted.Value then
	RunStarted.Changed:Wait()
end

updateOverlay(1, "Entering level")
task.wait(0.08)
LoadingOverlay.Release(overlayToken)
