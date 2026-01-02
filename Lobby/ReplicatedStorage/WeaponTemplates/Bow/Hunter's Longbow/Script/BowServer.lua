local cooldown = false


script.Parent.BowRE.OnServerEvent:Connect(function(plr, instruction, charge, mHit)
	
	if script.Parent.Parent == plr.Character and not cooldown and instruction == "shoot" then
		
		cooldown = true
		
		local newArrow = script.Parent.Arrow:Clone()
		newArrow.Parent = workspace
		
		script.Parent.Arrow.Transparency = 1
		
		
		newArrow.CFrame = CFrame.new(newArrow.Position, mHit.Position)
		
		newArrow.Velocity = mHit.LookVector * charge * 200
		
		
		game:GetService("Debris"):AddItem(newArrow, 30)
		
		
		local touched = false
		
		newArrow.Touched:Connect(function(hit)
			
			if hit.Parent ~= plr.Character and hit.Parent.Parent ~= plr.Character and not touched then
				
				touched = true
				
				newArrow:Destroy()
				
				local humanoid = hit.Parent:FindFirstChild("Humanoid")
				
				if humanoid then
					humanoid:TakeDamage(charge * 30)
				end
			end
		end)
		
		
		script.Parent.BowRE:FireClient(plr, newArrow, charge)
		
		
		wait(1)
		
		script.Parent.Arrow.Transparency = 0
		
		cooldown = false
		
		
	elseif instruction == "string" then
		
		script.Parent.Bow.Middle.Position = charge
		script.Parent.Bow.Weld.C1 = mHit
	end
end)