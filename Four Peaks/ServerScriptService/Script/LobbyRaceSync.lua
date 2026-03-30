-- SCRIPT: LobbyRaceSync.server.lua
-- GDZIE: ServerScriptService/LobbyRaceSync.server.lua
-- CO: utrzymuje atrybut Race jako fallback przy joinie.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

ReplicatedStorage:WaitForChild("RemoteEvents")

-- na wszelki wypadek: ustaw Race przy joinie, jeśli już jest gdzieś w atrybutach/GUI (fallback)
Players.PlayerAdded:Connect(function(plr)
	if plr:GetAttribute("Race") == nil then
		plr:SetAttribute("Race", "-")
	end
end)

print("[LobbyRaceSync] Ready (Race attribute handled elsewhere)")
