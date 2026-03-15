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

local ok, PortalUIController = pcall(function()
	return require(moduleFolder:WaitForChild("PortalUIController"))
end)

if not ok then
	warn("[PortalUIClient] Failed to load PortalUIController:", PortalUIController)
	return
end

PortalUIController.Start()
