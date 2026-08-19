local tool = script.Parent

tool.EnergyLevel.Changed:Connect(function(energy)
	tool.Name = "Magic Level: "..math.floor(energy)
end)