tool = script.Parent
local cd = false

tool.Equipped:Connect(function()
	for _, n in pairs(tool:GetChildren()) do
		if n.ClassName == "Part" or n.ClassName == "MeshPart" or n.ClassName == "UnionOperation" then
			n.CanCollide = false
			n.Massless = true
			n.Anchored = false
		end
	end
end)