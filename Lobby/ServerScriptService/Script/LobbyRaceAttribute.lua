-- SCRIPT: LobbyRaceAttribute.server.lua
-- GDZIE: ServerScriptService/LobbyRaceAttribute.server.lua
-- CO: ustawia player:SetAttribute("Race") z profilu, po join i po utworzeniu profilu (polling prosty)

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfilesManager = require(ServerScriptService:WaitForChild("ProfilesManager"))

local function trySet(plr: Player)
	local profile = ProfilesManager.GetActiveProfile(plr)
	if profile and typeof(profile.Race) == "string" then
		plr:SetAttribute("Race", profile.Race)
		return true
	end
	return false
end

Players.PlayerAdded:Connect(function(plr)
	task.spawn(function()
		for _ = 1, 60 do
			if not plr.Parent then return end
			if trySet(plr) then return end
			task.wait(1)
		end
	end)
end)

print("[LobbyRaceAttribute] Ready")
