game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char)
		local aura = game.ServerStorage.Aura:WaitForChild("Aura")
		local hrp = char:WaitForChild("HumanoidRootPart")
		local clone = aura:Clone()
		for i, v in pairs(clone:GetChildren()) do
			v.Parent = hrp
		end
	end)
end)