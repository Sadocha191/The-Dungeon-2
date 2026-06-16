Scythe = script.Parent

if script:FindFirstChild("creator") == nil then
	Scythe:Destroy()
end

ScytheBV = Scythe:FindFirstChild("scythefloat")

Running = game:GetService("RunService")
Debree = game:GetService("Debris")

Plyr = script.creator.Value

Char = Plyr.Character

Tag = script.creator:Clone()
Tag.Parent = Scythe
Tag.Changed:connect(function(thing)
	if Tag.Value and Tag.Value.ClassName == "Player" and not Scythe.Anchored then
		Plyr = Tag.Value
		Char = Plyr.Character
	end
end)

Boom = script.BOOM
Boom.Parent = Scythe
Beep = script.Beep
Beep.Parent = Scythe
Fire = script.Firenova
Fire.Parent = Scythe
Static = script.Static
Static.Parent = Scythe
Static.Enabled = true

BG = Instance.new("BodyGyro")
BG.MaxTorque = Vector3.new(math.huge,math.huge,math.huge)
BG.P = 100000
BG.CFrame = Scythe.CFrame
BG.Parent = Scythe

SingularityAOE = Vector3.new(30,30,30)
DeleteRegion = Vector3.new(7,7,7)
SingularityTimer = 600

stuff = {}
moreStuff = {}

Wave = Instance.new("Part")
Wave.Transparency = 1
Wave.Anchored = true
Wave.CanCollide = false

script.WaveTop.Parent = Wave
script.WaveBottom.Parent = Wave

function BoomBoom(hit)
	if not hit:IsDescendantOf(Char) and hit.Anchored == false and hit.Parent:FindFirstChild("ForceField") == nil and hit.Parent.Parent:FindFirstChild("ForceField") == nil and not TeamAlly(hit.Parent) and not MinionAlly(hit.Parent) and not MinionTeamAlly(hit.Parent) then
		if hit.Parent:FindFirstChild("Humanoid") ~= nil then
			UntagHumanoid(hit.Parent.Humanoid)
			TagHumanoid(hit.Parent.Humanoid,Plyr)
			--hit.Parent.Humanoid:TakeDamage(hit.Parent.Humanoid.MaxHealth)
		end
		hit:BreakJoints()
	end
end

function CheckForForcefield(part)
	if part.Parent == nil or part.Parent == game.Workspace or part.Parent.Parent == nil or (part.Parent ~= game.Workspace and part.Parent:FindFirstChild("ForceField") == nil) or(part.Parent.Parent ~= game.Workspace and part.Parent.Parent:FindFirstChild("ForceField") == nil) then
		return false
	end
	return true
end

function TagHumanoid(humanoid, player)
	local Creator_Tag = Instance.new("ObjectValue")
	Creator_Tag.Name = "creator"
	Creator_Tag.Value = player
	Debree:AddItem(Creator_Tag, 2)
	Creator_Tag.Parent = humanoid
end

function UntagHumanoid(humanoid)
	for i, v in pairs(humanoid:GetChildren()) do
		if v:IsA("ObjectValue") and v.Name == "creator" then
			v:Destroy()
		end
	end
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

SingularityTimer = 300
while SingularityTimer > 0 do
	Running.Heartbeat:wait()
	SingularityTimer = SingularityTimer - 1
	if SingularityTimer == 80 or SingularityTimer == 60 or SingularityTimer == 40 or SingularityTimer == 20 then
		Beep:Play()
		Scythe.Mesh.VertexColor = Vector3.new(1,0,0)
	elseif SingularityTimer == 70 or SingularityTimer == 50 or SingularityTimer == 30 or SingularityTimer == 10 then
		--Beep:Play()
		Scythe.Mesh.VertexColor = Vector3.new(1,1,1)
	end
	if ScytheBV == nil or ScytheBV.Parent == nil then
		Scythe.CanCollide = true --just in case
	end
	BG.CFrame = BG.CFrame * CFrame.Angles(0,0.4,0)
	BHregion = Region3.new(Scythe.Position - SingularityAOE,Scythe.Position + SingularityAOE)
	stuff = game.Workspace:FindPartsInRegion3(BHregion,Char,math.huge)
	for a = 1,#stuff do
		if stuff[a] and not stuff[a]:IsDescendantOf(Char) and stuff[a] ~= Scythe and stuff[a].Anchored == false and stuff[a].Parent ~= nil and stuff[a].Parent:FindFirstChild("ForceField") == nil and stuff[a].Name ~= "Handle" and stuff[a].Name ~= "ScytheBomb" and not TeamAlly(stuff[a].Parent) and not MinionAlly(stuff[a].Parent) and not MinionTeamAlly(stuff[a].Parent) then
			moreStuff = stuff[a]:GetChildren()
			for b = 1,#moreStuff do
				if moreStuff[b]:IsA("BodyMover") or moreStuff[b].ClassName == "Script" then
					moreStuff[b]:Destroy()
				end
			end
			if stuff[a].Parent:FindFirstChild("Humanoid") ~= nil then
				UntagHumanoid(stuff[a].Parent.Humanoid)
				TagHumanoid(stuff[a].Parent.Humanoid,Plyr)
			end
			BV = Instance.new("BodyVelocity")
			BV.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
			BV.Velocity = (CFrame.new(stuff[a].Position,Scythe.Position)).lookVector * 55
			BV.Parent = stuff[a]
			Debree:AddItem(BV,0.1)
		end
	end
end

Scythe.Anchored = true
Scythe.Transparency = 1
Static.Enabled = false

E = Instance.new("Explosion")
E.Position = Scythe.Position
E.BlastRadius = 15
E.BlastPressure = 1000000
E.DestroyJointRadiusPercent = 0
E.Parent = game.Workspace
E.Hit:Connect(BoomBoom)

P = Instance.new("Part")
P.BrickColor = BrickColor.new("Really black")
P.Material = "Neon"
P.Anchored = true
P.CanCollide = false
P.Shape = "Ball"
P.Size = Vector3.new(1,1,1)
P.Position = Scythe.Position
P.Parent = Scythe

Wave.Parent = Scythe

Fire:Emit(1000)

Boom:Play()
for a = 1,40 do
	Running.Heartbeat:wait()
	--BaseAmb = (300-a)/300
	--game.Lighting.OutdoorAmbient = Color3.new(BaseAmb,BaseAmb,BaseAmb)
	Wave.Size = Vector3.new(4*a,0,4*a)
	Wave.Position = Scythe.Position
	P.Size = Vector3.new(2,2,2)*a
	P.Transparency = P.Transparency + 0.025
	Wave.WaveTop.Transparency = P.Transparency
	Wave.WaveBottom.Transparency = P.Transparency
	--Fire:Emit(50)
end
Wave:Destroy()
P:Destroy()

wait(3)
Scythe:Destroy()