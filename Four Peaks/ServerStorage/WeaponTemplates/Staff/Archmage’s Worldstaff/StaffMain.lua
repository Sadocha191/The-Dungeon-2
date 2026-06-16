--Redone by Noob3713
--Meteors solve everything!

Tool = script.Parent
Staff = Tool.Handle

Tool.Enabled = true

AnimFolder = Tool.Animations

--Trail = Staff.Trail
--Trail.Attachment0 = Staff.TrailTop
--Trail.Attachment1 = Staff.TrailBottom
--Trail.Enabled = true

SP1 = Staff.StarPartics.Twinkle
--SP2 = Staff.StarParticsBottom.Twinkle
SP1.Enabled = true
--SP2.Enabled = true

--ScytheFire = Scythe.FireAT.ScytheFire
--ScytheFire.Enabled = true

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

OrigGrip = nil
OrigGrip2 = nil

CurrentDamage = 22

Special1 = true
Special2 = true
Special3 = true
DoingSpecial = false

stuff = {}
moreStuff = {}

Deflect = false

function CheckForForcefield(part)
	if part.Parent == game.Workspace or (part.Parent ~= game.Workspace and part.Parent:FindFirstChild("ForceField") == nil) or(part.Parent.Parent ~= game.Workspace and part.Parent.Parent:FindFirstChild("ForceField") == nil) then
		return false
	end
	return true
end

function MeteorStorm()
	DoingSpecial = true
	SpecialAnim = Hum:LoadAnimation(AnimSet.Special)
	if SpecialAnim then SpecialAnim:Play() end
	Tool.Summon:Play()
	DS = script.MeteorStormScript:Clone()
	DS.Parent = game.Workspace
	TeamSwitch:Clone().Parent = DS
	TagHumanoid(DS,Plyr)
	DS.Disabled = false
	DoingSpecial = false
	while DS.Parent ~= nil do
		wait()
	end
end

function ShootingStar()
	--DoingSpecial = true
	--wait(2)
	--DoingSpecial = false
end

InvisoTimer = 600
SaveFire = false

function DoSpecial(Client, Key)
	if not Client or Client ~= Plyr or not Key or not Tool.Enabled or Hum.Health <= 0 or DoingSpecial then return end
	if Key == Enum.KeyCode.Q then
		if Special1 == true then
			Special1 = false
			SP1.Enabled = false
			MeteorStorm()
			wait(30)
			Special1 = true
			SP1.Enabled = true
		end
	elseif Key == Enum.KeyCode.E then
		if Special2 == true then
			Special2 = false
			--ShootingStar()
			wait(25)
			Special2 = true
		end
	elseif Key == Enum.KeyCode.X then
		if Special3 == true then
			Special3 = false
			--Inviso()
			--wait(20)
			Special3 = true
		end
	end
end

function SpawnMeteor()
	MousePosition = MouseInput:InvokeClient(Plyr)
	Rock = Instance.new("Part")
	--Rock.BrickColor = BrickColor.new("Cyan")
	Rock.CanCollide = true
	Rock.Size = Vector3.new(7,7,7)
	Rock.Position = MousePosition + Vector3.new(0,300,0)
	Rock.RotVelocity = Vector3.new(math.random(-15,15),math.random(-15,15),math.random(-15,15))
	Rock.Parent = game.Workspace
	Rock.Name = "Meteor"
	Rock:SetNetworkOwner(nil)

	RockMesh = Instance.new("SpecialMesh")
	RockMesh.MeshId = "http://www.roblox.com/asset/?id=1290033"
	RockMesh.TextureId = "http://www.roblox.com/asset/?id=1290030"
	RockMesh.VertexColor = Vector3.new(2,0.5,0)
	RockMesh.Scale = Vector3.new(6,6,6)
	RockMesh.Parent = Rock

	DSC = script.BigBulletScript:Clone()
	DSC.Parent = Rock
	TeamSwitch:Clone().Parent = DSC
	TagHumanoid(DSC,Plyr)
	DSC.Disabled = false

	--NewPart,NewPos = game.Workspace:FindPartOnRay(Ray.new(Rock.Position,RayConstant))
	GetTarget(MousePosition,40)

	BV = Instance.new("BodyVelocity")
	BV.MaxForce = Vector3.new(1,1,1)*math.huge
	if Target ~= nil then
		BV.Velocity = CFrame.new(Rock.Position,Target.Position).lookVector * 140
	else BV.Velocity = Vector3.new(0,-140,0)
	end
	BV.Parent = Rock
end

-- target detection stuff do not steal

DetectionAOE = Vector3.new(30,30,30)
TempHums = {}
parts = {}
TempRoot = nil
TempChar = nil
TempHum = nil
Ignore = false
Target = nil
Targets = {}
Distance = 999
MaxDis = 50

function GetTarget(rangePoint,maxRange)
	TempHums = {}
	Targets = {}
	Target = nil
	MaxDis = maxRange
	DetectionAOE = Vector3.new(maxRange,maxRange,maxRange)
	DetectRegion = Region3.new(rangePoint - DetectionAOE,rangePoint + DetectionAOE)
	parts = game.Workspace:FindPartsInRegion3(DetectRegion,Char,math.huge)
	for a = 1,#parts do
		if parts[a].Parent ~= nil and parts[a].Parent:FindFirstChild("Humanoid") and not parts[a]:IsDescendantOf(Char) and not parts[a].Parent:FindFirstChild("ForceField") and not TeamAlly(parts[a].Parent) and not MinionAlly(parts[a].Parent) and not MinionTeamAlly(parts[a].Parent)then
			TempRoot = parts[a].Parent:FindFirstChild("HumanoidRootPart") or parts[a].Parent:FindFirstChild("Torso")
			TempHum = parts[a].Parent.Humanoid
			TempChar = parts[a].Parent
			Ignore = false
			for h = 1,#TempHums do
				if TempHums[h] == TempHum then
					Ignore = true
				end
			end
			if Ignore == false and TempRoot and TempHum.Health > 0 then
				Distance = (rangePoint - TempRoot.Position).magnitude
				if Distance <= maxRange and Distance <= MaxDis then
					table.insert(TempHums,TempHum)
					MaxDis = Distance
					Target = TempRoot
				end
			end
		end
	end
end

-- end target detection stuff

RayConstant = Vector3.new(0,-200,0)

Dis = math.huge
Target = nil
MaxDis = math.huge
TargetPoint = nil
TargetDir = nil

NewAnim = nil
SummonAnim = nil
AnimSpeed = 1

NewPart = nil
NewPos = Vector3.new(0,0,0)

function Summon()
	if Tool.Enabled == true and DoingSpecial == false then
		Tool.Enabled = false
		SummonAnim = Hum:LoadAnimation(AnimSet.Summon)
		if SummonAnim then SummonAnim:Play(nil,nil,AnimSpeed) end
		Tool.Summon:Play()
		SpawnMeteor()
		wait(8)
		Tool.Enabled = true
	end
end

IgnoreDamage = false
NewHealth = 100

DamageReducer = .3

function ReduceDamage()
	NewHealth = Hum.Health
	if not IgnoreDamage and NewHealth ~= Hum.MaxHealth and NewHealth > 0 then
		if NewHealth < CurrentHealth then
			local DamageDealt = (CurrentHealth - NewHealth)
			IgnoreDamage = true
			Hum.Health = Hum.Health + (DamageDealt * DamageReducer)
			IgnoreDamage = false
		end
	end
	CurrentHealth = NewHealth
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
	
end

function Unequip()
	--DamageDodge:Disconnect()
	--if EquipAnim then EquipAnim:Stop() end
end

Tool.Equipped:Connect(Equip)
Tool.Unequipped:Connect(Unequip)
Tool.Activated:Connect(Summon)
--Sword.Touched:Connect(SwordHit)
Remote.OnServerEvent:Connect(DoSpecial)