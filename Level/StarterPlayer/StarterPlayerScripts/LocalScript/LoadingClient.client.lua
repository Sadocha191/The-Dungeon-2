-- LoadingClient.client.lua (Level1)
-- Keeps one shared loading overlay alive while server world preparation and
-- a small, targeted client preload run in parallel.

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local loadingStartedAt = os.clock()

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
	message = "Starting level",
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

local function collectSharedPreloadInstances()
	local instances = {}

	-- Only preload reusable content containers. ModuleScripts do not contain
	-- renderable content and preloading the full Workspace scales badly with
	-- foliage, generated chests, drops, enemies, and streamed map geometry.
	appendDescendants(instances, ReplicatedStorage:FindFirstChild("Assets"))
	appendDescendants(instances, ReplicatedStorage:FindFirstChild("Enemies"))

	return instances
end

local function collectFinalPreloadInstances()
	local instances = {}

	-- UI and lighting are immediately visible when the overlay disappears.
	-- Workspace content is left to normal streaming/content loading.
	appendDescendants(instances, Lighting)
	appendDescendants(instances, localPlayer:FindFirstChild("PlayerGui"))

	return instances
end

local function runYieldingWithTimeout(timeoutSec: number, callback): (boolean, any, boolean)
	local completed = false
	local callOk = false
	local callResult = nil
	local worker = task.spawn(function()
		callOk, callResult = pcall(callback)
		completed = true
	end)
	local deadline = os.clock() + math.max(0.05, timeoutSec)

	while not completed and os.clock() <= deadline do
		task.wait(0.05)
	end

	if not completed then
		local cancelOk, cancelError = pcall(task.cancel, worker)
		if not cancelOk then
			warn("[LoadingClient] Could not cancel timed-out loading worker:", cancelError)
		end
		return false, "Timeout", true
	end

	return callOk, callResult, false
end

local function preloadInstances(
	instances,
	startProgress: number,
	endProgress: number,
	message: string,
	maxDurationSec: number
)
	local total = math.max(#instances, 1)
	local chunkSize = 120
	local loaded = 0
	local deadline = os.clock() + math.max(0.05, maxDurationSec)

	if #instances == 0 then
		updateOverlay(endProgress, message)
		return
	end

	for i = 1, #instances, chunkSize do
		local chunk = {}

		for j = i, math.min(i + chunkSize - 1, #instances) do
			table.insert(chunk, instances[j])
		end

		local remaining = deadline - os.clock()
		if remaining <= 0 then
			warn(string.format("[LoadingClient] %s preload budget exhausted", message))
			break
		end

		local ok, err, timedOut = runYieldingWithTimeout(remaining, function()
			ContentProvider:PreloadAsync(chunk)
		end)

		if not ok then
			warn(string.format("[LoadingClient] %s preload %s:", message, timedOut and "timed out" or "failed"), err)
			if timedOut then
				break
			end
		end

		loaded += #chunk
		local alpha = loaded / total
		updateOverlay(startProgress + ((endProgress - startProgress) * alpha), message)

		-- Yield between chunks so the loading UI remains responsive.
		task.wait()
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
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		if root and root:IsA("BasePart") then
			return root
		end

		task.wait(0.05)
	end

	return nil
end

local function requestInitialStream()
	if Workspace.StreamingEnabled ~= true or not hasRequestStreamAround then
		return
	end

	local root = waitForCharacterRoot(5)

	if not root then
		warn("[LoadingClient] Character root unavailable for initial streaming request")
		return
	end

	local ok, err, timedOut = runYieldingWithTimeout(3, function()
		Workspace:RequestStreamAroundAsync(root.Position)
	end)

	if not ok then
		warn("[LoadingClient] RequestStreamAroundAsync", timedOut and "timed out:" or "failed:", err)
	end
end

local function waitForRequestQueue(timeoutSec: number, acceptableQueueSize: number)
	local deadline = os.clock() + timeoutSec

	while os.clock() <= deadline do
		if ContentProvider.RequestQueueSize <= acceptableQueueSize then
			return
		end

		task.wait(0.1)
	end
end

-- Start server world generation immediately. Client preloading now overlaps
-- chest/shrine/structure preparation instead of delaying it.
ClientReady:FireServer()

updateOverlay(0.04, "Preparing shared assets")
preloadInstances(collectSharedPreloadInstances(), 0.04, 0.38, "Preparing shared assets", 6)

updateOverlay(0.42, "Waiting for level generation")
local prepared = waitForPhase(15)

if not prepared then
	warn("[LoadingClient] Timed out while waiting for world preparation; continuing")
end

updateOverlay(0.58, "Streaming spawn area")
requestInitialStream()

updateOverlay(0.76, "Preparing interface")
preloadInstances(collectFinalPreloadInstances(), 0.76, 0.95, "Preparing interface", 4)

updateOverlay(0.98, "Finalizing level")

-- RequestQueueSize can include unrelated background/streaming requests and
-- may never reach zero on a large map. Keep this as a short best-effort wait.
waitForRequestQueue(1.25, 8)
task.wait(0.05)

-- A slow server preparation may outlive the optimistic wait above. Do not send
-- the one generation-scoped readiness signal until the server can accept it.
while true do
	local phase = tostring(RunLoadingState:GetAttribute("Phase") or "")
	if phase == "prepared" or phase == "running" then
		break
	end
	updateOverlay(0.98, "Waiting for level generation")
	task.wait(0.1)
end

local generation = math.max(
	0,
	math.floor(tonumber(RunLoadingState:GetAttribute("Generation")) or 0)
)

ClientWorldLoaded:FireServer(generation)

while not RunStarted.Value do
	RunStarted.Changed:Wait()
end

updateOverlay(1, "Entering level")
task.wait(0.05)
LoadingOverlay.Release(overlayToken)

print(string.format(
	"[LoadingClient] Loading gate completed in %.2fs",
	os.clock() - loadingStartedAt
))
