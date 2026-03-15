local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local moduleFolder = (
	ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)
)

if not moduleFolder then
	warn("[PortalUIClient] ModuleScripts folder not found in ReplicatedStorage.")
	return
end

print("[PortalUIClient] Boot")

local player = Players.LocalPlayer
local screenGui = script:FindFirstAncestorOfClass("ScreenGui")

local ok, PortalUIController = pcall(function()
	return require(moduleFolder:WaitForChild("PortalUIController"))
end)

if not ok then
	warn("[PortalUIClient] Failed to load PortalUIController:", PortalUIController)
	return
end

PortalUIController.Start({
	gui = screenGui,
})

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeredPlayer)
	if not PortalUIController.MatchesPortalPrompt(prompt, triggeredPlayer) then
		return
	end

	if typeof(triggeredPlayer) == "Instance" and triggeredPlayer:IsA("Player") and triggeredPlayer ~= player then
		return
	end

	print("[PortalUIClient] Opening from local portal prompt:", prompt:GetFullName())
	PortalUIController.Open()
end)
