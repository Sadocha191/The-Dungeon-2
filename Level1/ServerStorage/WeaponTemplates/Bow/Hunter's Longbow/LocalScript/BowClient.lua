local mouse = game.Players.LocalPlayer:GetMouse()
local buttonDown = false

mouse.Button1Down:Connect(function()
	buttonDown = true
end)

mouse.Button1Up:Connect(function()
	
	script.Parent.BowRE:FireServer("shoot", script.Parent.Bow.Middle.Position.Z, mouse.Hit)
	
	buttonDown = false
end)


game:GetService("RunService").RenderStepped:Connect(function()
	
	if buttonDown then
		script.Parent.Bow.Middle.Position = script.Parent.Bow.Middle.Position:Lerp(Vector3.new(0, 0, 1.998), 0.1)
		
	else	
		script.Parent.Bow.Middle.Position = script.Parent.Bow.Middle.Position:Lerp(Vector3.new(0, 0, 0.637), 0.7)
	end
	
	script.Parent.Bow.Weld.C1 = CFrame.new(-Vector3.new(0, 0, script.Parent.Bow.Middle.Position.Z - 0.7))
end)


script.Parent.BowRE.OnClientEvent:Connect(function(arrow, charge)
	
	arrow:Destroy()
	
	local newArrow = script.Parent.Arrow:Clone()
	newArrow.Parent = workspace

	newArrow.Transparency = 0

	newArrow.CFrame = CFrame.new(newArrow.Position, mouse.Hit.Position)

	newArrow.Velocity = mouse.Hit.LookVector * charge * 200
	
	
	newArrow.Touched:Connect(function(hit)

		if hit.Parent ~= game.Players.LocalPlayer.Character and hit.Parent.Parent ~= game.Players.LocalPlayer.Character then

			newArrow:Destroy()
		end
	end)
end)


while wait(0.1) do
	
	script.Parent.BowRE:FireServer("string", script.Parent.Bow.Middle.Position, script.Parent.Bow.Weld.C1)
end