--Redone by Noob3713
--Become the ghost-reaper!

Tool = script.Parent
Scythe = Tool.Handle

AnimFolder = Tool.Animations

--this thing has so many particles lol
Trail = Scythe.Trail
Trail.Attachment0 = Scythe.TrailTop
Trail.Attachment1 = Scythe.TrailBottom
Trail.Enabled = false

ScytheFire = Scythe.FireAT.ScytheFire
ScytheFire.Enabled = true

ScytheFire2 = Scythe.FireAT2.ScytheFire
ScytheFire2.Enabled = true

ScytheSparkles = Scythe.ButtonSparkle.Twinkle
ScytheSparkles.Enabled = true --you can still see it if you look hard enough

ScytheStatic = Scythe.StaticAT.Static
ScytheStatic.Enabled = true

Running = game:GetService("RunService")
Debree = game:GetService("Debris")

Remote = (Tool:FindFirstChild("Remote") or Instance.new("RemoteEvent"));Remote.Name = "Remote";Remote.Parent = Tool
MouseInput = Tool.MouseInput

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

if Tool:FindFirstChild("TeamAttack") then
	Tool.TeamAttack:Destroy()
end

TeamSwitch = Instance.new("BoolValue")
TeamSwitch.Value = false
TeamSwitch.Name = "TeamAttack"
TeamSwitch.Parent = Tool

--setting the value to true will allow teammates to damage eachother
--setting the value to false will prevent it
--the value can be changed manually if you want i guess

function TeamAlly(person)
	Plyr2 = game.Players:GetPlayerFromCharacter(person)
	if TeamSwitch.Value == false and Plyr and Plyr2 and not Plyr.Neutral and Plyr.TeamColor == Plyr2.TeamColor then
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

function Ghostify(person,GhostNum)
	ch = person:GetDescendants()
	for g = 1,#ch do
		if ch[g]:IsA("BasePart") and ch[g] ~= Root and not ch[g]:IsDescendantOf(Tool) then
			ch[g].Transparency = GhostNum
		end
	end
end

OrigGrip = nil
OrigGrip2 = nil

function BGEffect()
	BGpart = Instance.new("Attachment")
	BGpart.Parent = Root
	
	partics = Tool.Particles:GetChildren()
	for c = 1,#partics do
		PCC = partics[c]:Clone()
		PCC.Parent = BGpart
		PCC.Enabled = true
	end
end

function UndoBG()
	if BGpart ~= nil and BGpart.Parent ~= nil then
		partics = BGpart:GetChildren()
		for c = 1,#partics do
			partics[c].Enabled = false
		end
	end
	wait(2)
	BGpart:Destroy()
end

CurrentDamage = 26

Special1 = true
Special2 = true
Special3 = true
Special4 = true
DoingSpecial = false

SingularityAOE = Vector3.new(30,30,30)
DeleteAOE = Vector3.new(7,7,7)
SingularityTimer = 600

stuff = {}
moreStuff = {}
closestuff = {}

PartsFound = false

function CheckForForcefield(part)
	if part.Parent == nil or part.Parent == game.Workspace or part.Parent.Parent == nil or (part.Parent ~= game.Workspace and part.Parent:FindFirstChild("ForceField") == nil) or(part.Parent.Parent ~= game.Workspace and part.Parent.Parent:FindFirstChild("ForceField") == nil) then
		return false
	end
	return true
end

RootJoint = nil
OldC = nil

function Singularity()
	DoingSpecial = true
	SpinAnim = Hum:LoadAnimation(AnimSet.Spin)
	if SpinAnim then SpinAnim:Play() end
	OrigGrip = Tool.Grip
	Tool.Grip = Tool.Grip * CFrame.Angles(math.rad(70),math.rad(-20),math.rad(90))
	BGEffect()
	Scythe.BlackHole:Play()
	Scythe.EvilLaugh:Play()
	Trail.Enabled = true
	RootJoint = Root:FindFirstChild("RootJoint") or Char:FindFirstChild("LowerTorso"):FindFirstChild("Root")
	if RootJoint ~= nil then
		OldC = RootJoint.C0
	else OldC = nil
	end -- allows spinning even with gravity shield active
	DamageReducer = 1
	Hum.WalkSpeed = 35
	Hum.AutoRotate = false
	SingularityTimer = 600
	while SingularityTimer > 0 do
		Running.Heartbeat:wait()
		SingularityTimer = SingularityTimer - 1
		if RootJoint then
			if Hum.RigType == Enum.HumanoidRigType.R6 then
				RootJoint.C0 = RootJoint.C0 * CFrame.Angles(0,0,0.4)
			else RootJoint.C0 = RootJoint.C0 * CFrame.Angles(0,0.4,0)
			end
		end
		DeleteRegion = Region3.new(Root.Position - DeleteAOE,Root.Position + DeleteAOE)
		stuff = game.Workspace:FindPartsInRegion3(DeleteRegion,Char,math.huge)
		for a = 1,#stuff do
			if stuff[a] and stuff[a].Anchored == false and not stuff[a]:IsDescendantOf(Char) and stuff[a].Parent and stuff[a].Parent:FindFirstChild("ForceField") == nil and stuff[a].Name ~= "Handle" and not TeamAlly(stuff[a].Parent) and not MinionAlly(stuff[a].Parent) and not MinionTeamAlly(stuff[a].Parent) then
				if stuff[a].Parent:FindFirstChild("Humanoid") ~= nil then
					UntagHumanoid(stuff[a].Parent.Humanoid)
					TagHumanoid(stuff[a].Parent.Humanoid,Plyr)
				end
				stuff[a]:Destroy() -- potential for breaking games but whatever lol
			end
		end
		
		BHregion = Region3.new(Root.Position - SingularityAOE,Root.Position + SingularityAOE)
		stuff = game.Workspace:FindPartsInRegion3(BHregion,Char,math.huge)
		for a = 1,#stuff do
			if stuff[a] and not stuff[a]:IsDescendantOf(Char) and stuff[a].Anchored == false and stuff[a].Parent ~= nil and stuff[a].Parent:FindFirstChild("ForceField") == nil and stuff[a].Name ~= "Handle" and stuff[a].Name ~= "ScytheBomb" and not TeamAlly(stuff[a].Parent) and not MinionAlly(stuff[a].Parent) and not MinionTeamAlly(stuff[a].Parent) then
				moreStuff = stuff[a]:GetChildren()
				for b = 1,#moreStuff do
					if moreStuff[b]:IsA("BodyMover") or moreStuff[b].ClassName == "Script" then
						moreStuff[b]:Destroy() --neutralizes projectiles
					end
				end
				BV = Instance.new("BodyVelocity")
				BV.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
				BV.Velocity = (CFrame.new(stuff[a].Position,Root.Position)).lookVector * 50
				BV.Parent = stuff[a]
				Debree:AddItem(BV,0.1)
			end
		end
	end
	if SpinAnim then SpinAnim:Stop() end
	Tool.Grip = OrigGrip
	RootJoint.C0 = OldC
	Scythe.BlackHole:Stop()
	Trail.Enabled = false
	Hum.WalkSpeed = 16
	Hum.AutoRotate = true
	UndoBG()
	DamageReducer = 0.6
	DoingSpecial = false
end

FakeScythe = Instance.new("Part")
FakeScythe.CanCollide = false
FakeScythe.Size = Vector3.new(6,2,6)

Scythe.Mesh:Clone().Parent = FakeScythe

ATtop = Instance.new("Attachment")
ATtop.Parent = FakeScythe
ATtop.Position = Vector3.new(0,0,1.5)
ATtop.Name = "trailTop"

ATbottom = Instance.new("Attachment")
ATbottom.Parent = FakeScythe
ATbottom.Position = Vector3.new(0,0,-1.5)
ATbottom.Name = "trailBottom"

function ThrowScythe()
	DoingSpecial = true
	ThrowAnim = Hum:LoadAnimation(AnimSet.Throw)
	if ThrowAnim then ThrowAnim:Play() end
	wait(0.5)
	Scythe.Transparency = 1
	ScytheFire.Parent = Tool.Particles
	ScytheFire2.Parent = Tool.Particles
	ScytheSparkles.Parent = Tool.Particles
	ScytheStatic.Parent = Tool.Particles
	
	MousePosition = MouseInput:InvokeClient(Plyr)
	Bullet = FakeScythe:Clone()
	Bullet.CFrame = CFrame.new(Scythe.Position,MousePosition) * CFrame.Angles(0,0,math.pi/2)
	Bullet.Parent = game.Workspace
	Bullet.Name = "ScytheBomb"
	Bullet:SetNetworkOwner(Plyr)
	
	BV = Instance.new("BodyVelocity")
	BV.Velocity = Bullet.CFrame.lookVector * 50
	BV.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
	BV.Parent = Bullet
	BV.Name = "scythefloat"
	
	BulletTrail = Scythe.Trail:Clone()
	BulletTrail.Attachment0 = Bullet.trailTop
	BulletTrail.Attachment1 = Bullet.trailBottom
	BulletTrail.Enabled = true
	BulletTrail.Parent = Bullet
	
	BS = script.BulletScript:Clone()
	BS.Parent = Bullet
	TeamSwitch:Clone().Parent = BS
	TagHumanoid(BS,Plyr)
	BS.Disabled = false
	
	wait(2)
	
	if InvisoTimer == 0 then
		for s = 1,20 do
			Running.Heartbeat:wait()
			Scythe.Transparency = Scythe.Transparency - 0.05
		end
		ScytheFire.Parent = Scythe.FireAT
		ScytheFire2.Parent = Scythe.FireAT2
		ScytheSparkles.Parent = Scythe.ButtonSparkle
		ScytheStatic.Parent = Scythe.StaticAT
		Scythe.Transparency = 0
	end
	DoingSpecial = false
end

InvisoTimer = 0
SaveFire = false

Face = nil

function Inviso()
	--DoingSpecial = true
	DamageReducer = 0.8
	CurrentDamage = 35
	InvisoTimer = 600
	Scythe.Disappear:Play()
	for z = 1,40 do
		if Tool.Parent == Char then
			Running.Heartbeat:wait()
			Ghostify(Char,0.5 + (z/80))
			Scythe.Transparency = z/40
		else Ghostify(Char,0)
			Scythe.Transparency = 0
		end
	end
	ScytheFire.Parent = Tool.Particles --Prevent giving our position away!
	ScytheFire2.Parent = Tool.Particles
	ScytheSparkles.Parent = Tool.Particles
	ScytheStatic.Parent = Tool.Particles
	Face = Char.Head:FindFirstChildOfClass("Decal")
	if Face ~= nil then
		Face.Transparency = 1
	end
	Hum.WalkSpeed = 35
	while InvisoTimer > 0 do
		Running.Heartbeat:wait()
		InvisoTimer = InvisoTimer - 1
	end
	Hum.WalkSpeed = 16
	for z = 1,40 do
		if Tool.Parent == Char then
			Running.Heartbeat:wait()
			Ghostify(Char,1 - (z/80))
			Scythe.Transparency = 1 - z/40
		else Ghostify(Char,0)
			Scythe.Transparency = 0
		end
	end
	ScytheFire.Parent = Scythe.FireAT
	ScytheFire2.Parent = Scythe.FireAT2
	ScytheSparkles.Parent = Scythe.ButtonSparkle
	ScytheStatic.Parent = Scythe.StaticAT
	if Face ~= nil then
		Face.Transparency = 0
	end
	DamageReducer = 0.6
	CurrentDamage = 26
	--DoingSpecial = false
end

function DoShield()
	DoingSpecial = true
	SummonAnim = Hum:LoadAnimation(AnimSet.Summon)
	if SummonAnim then SummonAnim:Play() end
	Scythe.Deploy:Play()
	GS = script.GravityShield:Clone()
	GS.Parent = Char
	GS.Disabled = false
	GSL = script.GravityShieldLocal:Clone()
	GSL.Parent = Char
	GSL.Disabled = false
	wait(1)
	DoingSpecial = false
	while GS.Parent do
		Running.Heartbeat:wait()
	end
end

function DoSpecial(Client, Key)
	if not Client or Client ~= Plyr or not Key or not Tool.Enabled or Hum.Health <= 0 or DoingSpecial then return end
	if Key == Enum.KeyCode.Q then
		if Special1 == true and Scythe.Transparency == 0 then
			Special1 = false
			ScytheFire.Enabled = false
			ScytheFire2.Enabled = false
			Singularity()
			wait(20)
			Special1 = true
			ScytheFire.Enabled = true
			ScytheFire2.Enabled = true
		end
	elseif Key == Enum.KeyCode.E then
		if Special2 == true then
			Special2 = false
			ScytheStatic.Enabled = false
			ThrowScythe()
			wait(20)
			Special2 = true
			ScytheStatic.Enabled = true
		end
	elseif Key == Enum.KeyCode.X then
		if Special3 == true and not Entering then
			Special3 = false
			ScytheSparkles.Enabled = false
			Inviso()
			wait(15)
			ScytheSparkles.Enabled = true
			Special3 = true
		end
	elseif Key == Enum.KeyCode.Z then
		if Special4 == true then
			Special4 = false
			DoShield()
			wait(15)
			Special4 = true
		end
	end
end

function Slash()
	if Tool.Enabled == true and DoingSpecial == false then
		Tool.Enabled = false
		SlashAnim = Hum:LoadAnimation(AnimSet.DualSlash)
		if SlashAnim then SlashAnim:Play() end
		Scythe.Slash:Play()
		wait(1)
		Tool.Enabled = true
	end
end

Hand = nil
TempHum = nil

function ScytheHit(hit)
	if hit == nil or hit.Parent == nil or hit:IsDescendantOf(Char) or TeamAlly(hit.Parent) or MinionAlly(hit.Parent) or MinionTeamAlly(hit.Parent) then return end
	
	Hand = (Char:FindFirstChild("Right Arm") or Char:FindFirstChild("RightHand"))
	if Hand ~= nil then
		if Hand:FindFirstChildOfClass("Weld") ~= nil then --problematic but lol
			TempHum = hit.Parent:FindFirstChildOfClass("Humanoid")
			if TempHum ~= nil and TempHum.Health > 0 then
				UntagHumanoid(TempHum)
				TagHumanoid(TempHum,Plyr)
				if Scythe.Transparency == 1 and TempHum.Health - CurrentDamage <= 0 then
					Scythe.GhostSound:Play()
				end
				TempHum:TakeDamage(CurrentDamage)
			end
		end
	end
end

IgnoreDamage = false
NewHealth = 100

DamageReducer = .6

function ReduceDamage()
	NewHealth = Hum.Health
	if not IgnoreDamage and NewHealth ~= Hum.MaxHealth then
		if NewHealth < CurrentHealth then
			local DamageDealt = (CurrentHealth - NewHealth)
			IgnoreDamage = true
			Hum.Health = Hum.Health + (DamageDealt * DamageReducer)
			IgnoreDamage = false
		end
	end
	CurrentHealth = NewHealth
end

FakeRing = Instance.new("Part")
FakeRing.BrickColor = BrickColor.new("Really black")
FakeRing.Size = Vector3.new(0,0,0)
FakeRing.CanCollide = false

RingMesh = Instance.new("SpecialMesh")
RingMesh.MeshId = "http://www.roblox.com/asset/?id=3270017"
RingMesh.Scale = Vector3.new(4,4,4)
RingMesh.Parent = FakeRing

Ring1 = nil
Ring2 = nil

Entering = false

function CoolEntrance()
	Entering = true
	Ring1 = FakeRing:Clone()
	Ring1.Position = Root.Position
	Ring1.Parent = Tool
	
	W1 = Instance.new("Weld")
	W1.Part0 = Root
	W1.Part1 = Ring1
	W1.C0 = CFrame.new(Vector3.new(0,0,0)) * CFrame.Angles(math.pi/2,0,0)
	W1.Parent = Ring1
	
	Ring2 = FakeRing:Clone()
	Ring2.Position = Root.Position
	Ring2.Parent = Tool

	W2 = Instance.new("Weld")
	W2.Part0 = Root
	W2.Part1 = Ring2
	W2.C0 = CFrame.new(Vector3.new(0,0,0)) * CFrame.Angles(math.pi/2,0,0)
	W2.Parent = Ring2
	
	Tube = FakeRing:Clone()
	Tube.Position = Root.Position
	Tube.Parent = Tool
	
	W3 = Instance.new("Weld")
	W3.Part0 = Root
	W3.Part1 = Tube
	W3.C0 = CFrame.new(Vector3.new(0,0,0)) * CFrame.Angles(math.pi/2,0,0)
	W3.Parent = Tube
	
	Scythe.Magic:Play()
	for m = 1,40 do
		if Tool.Parent == Char then
			Running.Heartbeat:wait()
			W1.C0 = W1.C0 + Vector3.new(0,0.07,0)
			W2.C0 = W2.C0 + Vector3.new(0,-0.07,0)
			Tube.Mesh.Scale = Vector3.new(4,4,m*.98)
		end
	end
	for m = 1,20 do
		if Tool.Parent == Char then
			Running.Heartbeat:wait()
			Tube.Transparency = Tube.Transparency + 0.05
			Ghostify(Char,m/40)
		else Ghostify(Char,0)
		end
	end
	for m = 1,40 do
		if Tool.Parent == Char then
			Running.Heartbeat:wait()
			--Ring1.Transparency = Ring1.Transparency + 0.02
			Ring1.Mesh.Scale = Vector3.new(1,1,1)*((40 - m)/10)
			--Ring2.Transparency = Ring2.Transparency + 0.02
			Ring2.Mesh.Scale = Vector3.new(1,1,1)*((40 - m)/10)
		end
	end
	Ring1:Destroy()
	Ring2:Destroy()
	Tube:Destroy()
	Entering = false
end

CurrentHeath = 100

Char = nil
Hum = nil
Plyr = nil
Root = nil
AnimSet = nil
function Equip()
	Char = Tool.Parent
	Hum = Char:FindFirstChild("Humanoid")
	Plyr = game.Players:GetPlayerFromCharacter(Char)
	Root = Char:FindFirstChild("HumanoidRootPart") or Char:FindFirstChild("Torso")
	AnimSet = AnimFolder:FindFirstChild(Hum.RigType)

	HoldAnim = Hum:LoadAnimation(AnimSet.Hold)
	if HoldAnim then HoldAnim:Play() end
	
	DamageDodge = Hum.Changed:connect(ReduceDamage)
	CurrentHealth = Hum.Health
	if Entering == false then
		CoolEntrance()
	end
end

function Unequip()
	DamageDodge:Disconnect()
	Ghostify(Char,0)
	SingularityTimer = 0
	InvisoTimer = 0
	if HoldAnim then HoldAnim:Stop() end
end

Tool.Equipped:Connect(Equip)
Tool.Unequipped:Connect(Unequip)
Tool.Activated:Connect(Slash)
Scythe.Touched:Connect(ScytheHit)
Remote.OnServerEvent:Connect(DoSpecial)