--It's raining meteors!
--will auto target depending on how close the meteor is to a player/npc

if script:FindFirstChild("creator") == nil then
	script:Destroy()
end

Running = game:GetService("RunService")
Debree = game:GetService("Debris")

Plyr = script.creator.Value

Char = Plyr.Character
Torso = Char:FindFirstChild("Torso") or Char:FindFirstChild("HumanoidRootPart")
if Torso == nil then
	script:Destroy()
end

--Engage = script.Cast

DS = script.BulletScript

MeteorsLeft = 40

RayConstant = Vector3.new(0, -300, 0)

Dis = math.huge
Target = nil
MaxDis = math.huge
TargetPoint = nil
TargetDir = nil
Point1 = nil
VerDis = nil
Dis2 = nil

function GetTarget(TargetPos)
	Target = nil
	Dis = 500
	MaxDis = 500
	ch = game.Workspace:GetChildren()
	for a = 1, #ch do
		if ch[a] ~= Char and ch[a]:FindFirstChild("Humanoid") ~= nil and ch[a].Humanoid.Health > 0 and ch[a]:FindFirstChild("Head") ~= nil and ch[a]:FindFirstChild("ForceField") == nil and not TeamAlly(ch[a]) and not MinionAlly(ch[a]) and not MinionTeamAlly(ch[a]) then
			Dis = (ch[a].Head.Position - TargetPos).magnitude
			if Dis < MaxDis then
				Point1 = Vector3.new(TargetPos.X, ch[a].Head.Position.Y, TargetPos.Z)
				VerDis = TargetPos.Y - Point1.Y
				Dis2 = (ch[a].Head.Position - Point1).magnitude
				--gives it a full 45 degree angle range
				if Dis2 < VerDis and VerDis > 0 then --prevents going upward
					MaxDis = Dis
					Target = ch[a].Head
				end
			end
		end
	end
end

function TagHumanoid(humanoid, player)
	local Creator_Tag = Instance.new("ObjectValue")
	Creator_Tag.Name = "creator"
	Creator_Tag.Value = player
	Debree:AddItem(Creator_Tag, 2)
	Creator_Tag.Parent = humanoid
end

-- team related stuff do not steal

if script:FindFirstChild("TeamAttack") then
	TeamSwitch = script.TeamAttack
end

--if you want to change the settings on team attack, go to the main script

function TeamAlly(person)
	Plyr2 = game.Players:GetPlayerFromCharacter(person)
	if TeamSwitch and TeamSwitch.Value == false and Plyr and Plyr2 and not Plyr.Neutral and Plyr.TeamColor == Plyr2.TeamColor then
		return true
	end
	return false
end

function MinionAlly(tempChar)
	if tempChar:FindFirstChild("Master") ~= nil and tempChar.Master.ClassName == "ObjectValue" and tempChar.Master.Value == Plyr then
		return true
	end
	return false
end

function MinionTeamAlly(tempMinion) -- NOTE: you need the above function for this to work
	TempMaster = tempMinion:FindFirstChild("Master")
	if TempMaster and TempMaster.ClassName == "ObjectValue" and TempMaster.Value and TeamAlly(TempMaster.Value.Character) then
		return true
	end
	return false
end

-- end team related stuff

NewPart = nil
NewPos = Vector3.new(0, 0, 0)

function SpawnMeteor()
	Rock = Instance.new("Part")
	--Rock.BrickColor = BrickColor.new("Cyan")
	Rock.CanCollide = true
	Rock.Size = Vector3.new(3, 3, 3)
	Rock.Position = Torso.Position + Vector3.new(math.random(-120, 120), 300, math.random(-120, 120))
	Rock.RotVelocity = Vector3.new(math.random(-15, 15), math.random(-15, 15), math.random(-15, 15))
	Rock.Parent = game.Workspace
	Rock.Name = "Meteor"
	Rock:SetNetworkOwner(nil)

	RockMesh = Instance.new("SpecialMesh")
	RockMesh.MeshId = "http://www.roblox.com/asset/?id=1290033"
	RockMesh.TextureId = "http://www.roblox.com/asset/?id=1290030"
	RockMesh.VertexColor = Vector3.new(2, 0.5, 0)
	RockMesh.Scale = Vector3.new(3, 3, 3)
	RockMesh.Parent = Rock

	DSC = DS:Clone()
	DSC.Parent = Rock
	if TeamSwitch then
		TeamSwitch:Clone().Parent = DSC
	end
	TagHumanoid(DSC, Plyr)
	DSC.Disabled = false

	--NewPart,NewPos = game.Workspace:FindPartOnRay(Ray.new(Rock.Position,RayConstant))
	--GetTarget(NewPos)
	GetTarget(Rock.Position)

	BV = Instance.new("BodyVelocity")
	BV.MaxForce = Vector3.new(1, 1, 1) * math.huge
	if Target ~= nil then
		BV.Velocity = CFrame.new(Rock.Position, Target.Position).lookVector * 140
	else
		BV.Velocity = Vector3.new(math.random(-40, 40), -135, math.random(-40, 40))
	end
	BV.Parent = Rock
end

--Engage:Play()
while MeteorsLeft > 0 do
	task.wait(0.3)
	MeteorsLeft = MeteorsLeft - 1
	SpawnMeteor()
	if (Torso == nil or Torso.Parent == nil or Char.Parent == nil) and Plyr.Parent then
		Char = Plyr.Character
		Torso = Char:FindFirstChild("Torso") or Char:FindFirstChild("HumanoidRootPart")
	end
end


task.wait(2)
script:Destroy()
