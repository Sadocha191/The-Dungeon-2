-- RunDeathHandler.server.lua (Level1)
-- Fix pack v9:
-- - prevents auto respawn mid-wave by setting RespawnTime very high
-- - triggers Game Over via _G.EndRunForPlayer when player dies

local Players = game:GetService("Players")
Players.RespawnTime = 9999

Players.PlayerAdded:Connect(function(plr: Player)
	plr.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 5)
		if not hum then return end
		hum.Died:Connect(function()
			task.defer(function()
				if _G.EndRunForPlayer then
					_G.EndRunForPlayer(plr, "Defeated")
				elseif _G.EndRun then
					_G.EndRun("Defeated")
				end
			end)
		end)
	end)
end)

print("[RunDeathHandler] Ready (v9)")
