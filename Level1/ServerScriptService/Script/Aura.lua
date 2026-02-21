local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local function shouldAttachAura(plr: Player): boolean
	-- Aura hitbox should never be active by default on spawn.
	return plr:GetAttribute("AuraEnabled") == true
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		if not shouldAttachAura(plr) then
			return
		end

		local auraFolder = ServerStorage:FindFirstChild("Aura")
		local aura = auraFolder and auraFolder:FindFirstChild("Aura")
		if not aura then
			return
		end

		local hrp = char:WaitForChild("HumanoidRootPart")
		local clone = aura:Clone()
		for _, v in ipairs(clone:GetChildren()) do
			v.Parent = hrp
		end
	end)
end)
