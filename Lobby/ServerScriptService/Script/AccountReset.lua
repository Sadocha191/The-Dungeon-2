-- MODULE: AccountReset.lua
-- GDZIE: ServerScriptService/AccountReset.lua (ModuleScript)
-- CO: shim dla starej ścieżki w ServerScriptService.

local ServerScriptService = game:GetService("ServerScriptService")

local moduleFolder = ServerScriptService:WaitForChild("ModuleScript")
return require(moduleFolder:WaitForChild("AccountReset"))
