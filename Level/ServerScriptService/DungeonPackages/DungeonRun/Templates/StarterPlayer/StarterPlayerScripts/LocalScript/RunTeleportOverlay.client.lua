local ReplicatedStorage = game:GetService("ReplicatedStorage")

local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts")
	or ReplicatedStorage:FindFirstChild("ModuleScript")
	or ReplicatedStorage:WaitForChild("ModuleScripts", 5)
	or ReplicatedStorage:WaitForChild("ModuleScript", 5)

local TeleportOverlayController = require(moduleFolder:WaitForChild("TeleportOverlayController"))
TeleportOverlayController.Init()
