--Decimation of the character

local Character = script:WaitForChild("Character").Value

local Torso, Hum, FF = Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso"), Character:FindFirstChildOfClass("Humanoid"), Character:FindFirstChildOfClass("ForceField")

local Creator,SoulCount = script:WaitForChild("Creator").Value,script:WaitForChild("SoulCount").Value

local SoulFire = script:WaitForChild("SoulFire")

if FF then script:Destroy() end

function IsTeamMate(Player1, Player2)
	return (Player1 and Player2 and not Player1.Neutral and not Player2.Neutral and Player1.TeamColor == Player2.TeamColor)
end

function TagHumanoid(humanoid, player)
	local Creator_Tag = Instance.new("ObjectValue")
	Creator_Tag.Name = "creator"
	Creator_Tag.Value = player
	game:GetService("Debris"):AddItem(Creator_Tag, 2)
	Creator_Tag.Parent = humanoid
end

function UntagHumanoid(humanoid)
	for i, v in pairs(humanoid:GetChildren()) do
		if v:IsA("ObjectValue") and v.Name == "creator" then
			v:Destroy()
		end
	end
end


local Anim = Hum:LoadAnimation(script:FindFirstChild("SoulRise_"..Hum.RigType.Name))
Anim:Play(2,nil,1)

local Lift = Instance.new("BodyVelocity")
Lift.MaxForce = Vector3.new(1,1,1)*math.huge
Lift.Velocity = Vector3.new(0,1,0)*3

SoulFire.Parent = Torso
SoulFire.Enabled = true

Lift.Parent = Torso

local Tool = Character:FindFirstChildOfClass("Tool")

if Tool then
	Tool.Parent = nil
	Tool:Destroy()
end

wait(2.75)

Lift:Destroy()

local Touch

if not IsTeamMate(Creator,game:GetService("Players"):GetPlayerFromCharacter(Character)) then
	
	
	local SnatchedHealth = Hum.Health
	
	UntagHumanoid(Hum)
	TagHumanoid(Hum,Creator)
	Character:BreakJoints() -- End them already


	if game:GetService("Players"):GetPlayerFromCharacter(Character) then
		local SnatchedSoul = Instance.new("Part")
		SnatchedSoul.Name = "SnatchedSoul"
		SnatchedSoul.Anchored = false
		SnatchedSoul.CanCollide = false
		SnatchedSoul.Locked = true
		SnatchedSoul.Shape = Enum.PartType.Ball
		SnatchedSoul.Color = Color3.fromRGB(140, 0, 255)
		SnatchedSoul.TopSurface = Enum.SurfaceType.Smooth
		SnatchedSoul.BottomSurface = Enum.SurfaceType.Smooth
		SnatchedSoul.Material = Enum.Material.Neon
		SnatchedSoul.Size = Vector3.new(1,1,1)*.3
		SnatchedSoul.Transparency = 0.7
		SnatchedSoul.Position = Torso.Position
		SoulFire.Parent = SnatchedSoul
		SoulFire.Enabled = true
		
		local SoulFloat = Instance.new("BodyForce")
		
		SoulFloat.Force = Vector3.new(0,SnatchedSoul:GetMass()*workspace.Gravity,0)
		SoulFloat.Parent = SnatchedSoul
		
		SnatchedSoul.Parent = workspace
	
		SnatchedSoul:SetNetworkOwner(nil)
		
		Touch = SnatchedSoul.Touched:Connect(function(hit)
			if not hit or not hit.Parent then return end
			local Hum = hit.Parent:FindFirstChildOfClass("Humanoid")
			if not Hum or game:GetService("Players"):GetPlayerFromCharacter(Hum.Parent) ~= Creator then return end
			if SoulCount then
				SoulCount.Value = SoulCount.Value + 1 --award the killer the soul
			end
			Hum.Health = Hum.Health + SnatchedHealth -- Heal from the soul
			Touch:Disconnect();Touch = nil
		end)
		
		local CreatorTorso = Creator.Character:FindFirstChild("Torso") or Creator.Character:FindFirstChild("UpperTorso")
		repeat
			SnatchedSoul.Velocity = (CreatorTorso.Position-SnatchedSoul.Position).Unit * 55
			game:GetService("RunService").Heartbeat:Wait()
		until not Touch or not CreatorTorso:IsDescendantOf(workspace)
		
		--print("Reached Target")
		SnatchedSoul:Destroy()
	end	
	
end	

if SoulFire then
	SoulFire:Destroy()
end
script:Destroy()