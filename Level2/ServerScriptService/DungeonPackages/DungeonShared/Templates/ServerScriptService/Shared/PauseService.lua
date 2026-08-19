-- PauseService.lua
local Players = game:GetService("Players")

local PauseService = {}

function PauseService.SetPaused(paused: boolean)
	workspace:SetAttribute("Paused", paused)

	-- opcjonalnie: atrybut per gracz (przydaje się w UI / local checks)
	for _, plr in ipairs(Players:GetPlayers()) do
		plr:SetAttribute("Paused", paused)
	end
end

function PauseService.IsPaused(): boolean
	return workspace:GetAttribute("Paused") == true
end

return PauseService
