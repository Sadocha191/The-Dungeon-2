-- LoadingClient.client.lua (Level1)
-- Shows a shared loading overlay, preloads critical assets, then notifies the server.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClientReady = remotes:WaitForChild("ClientReady")

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

local function collectPreloadTargets()
	local targets = {}

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		table.insert(targets, assets)
	end

	local enemies = ReplicatedStorage:FindFirstChild("Enemies")
	if enemies then
		table.insert(targets, enemies)
	end

	return targets
end

local targets = collectPreloadTargets()
local instances = {}
for _, root in ipairs(targets) do
	for _, descendant in ipairs(root:GetDescendants()) do
		table.insert(instances, descendant)
	end
end

local total = math.max(#instances, 1)
local chunkSize = 200
local loaded = 0

local function setProgress(n: number, message: string?)
	local progress = math.clamp(n / total, 0, 1)
	LoadingOverlay.Update(overlayToken, {
		title = "Loading...",
		message = message or "Preparing assets",
		progress = progress,
	})
end

local function preloadChunk(chunk)
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(chunk)
	end)
	if not ok then
		warn("[LoadingClient] PreloadAsync error:", err)
	end
end

for i = 1, #instances, chunkSize do
	local chunk = {}
	for j = i, math.min(i + chunkSize - 1, #instances) do
		table.insert(chunk, instances[j])
	end
	preloadChunk(chunk)
	loaded = math.min(loaded + #chunk, total)
	setProgress(loaded)
end

task.wait(0.05)
ClientReady:FireServer()
LoadingOverlay.Release(overlayToken)
