-- PlayerStats (ModuleScript)
local PlayerStats = {}

function PlayerStats.new(player)
	local self = {
		Level = 1,
		EXP = 0,
		Class = "Warrior", -- przykładowa klasa
		EXPToLevel = 100
	}

	function self:AddEXP(amount)
		self.EXP = self.EXP + amount
		while self.EXP >= self.EXPToLevel do
			self.EXP = self.EXP - self.EXPToLevel
			self.Level = self.Level + 1
			self.EXPToLevel = math.floor(self.EXPToLevel * 1.5)
			print(player.Name.." awansował na level "..self.Level)
		end
	end

	return self
end

return PlayerStats
