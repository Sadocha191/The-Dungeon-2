Meteor = script.Parent

if script:FindFirstChild("creator") == nil then
	Meteor:Destroy()
end

Running = game:GetService("RunService")
Debree = game:GetService("Debris")

Plyr = script.creator.Value

Char = Plyr.Character

Tag = script.creator:Clone()
Tag.Parent = Meteor
Tag.Changed:connect(function(thing)
	if Tag.Value and Tag.Value.ClassName == "Player" then
		Plyr = Tag.Value
		Char = Plyr.Character
	end
end)

--FlySound = script.Projectile_Fly
ImpactSound = script.Explosion
Fire = script.MeteorFire
Sparkles = script.ExplosionFire

--FlySound.Parent = Diamond
ImpactSound.Parent = Meteor
Fire.Parent = Meteor
Fire.Enabled = true
Sparkles.Parent = Meteor
Sparkles.Enabled = true

A1 = Instance.new("Attachment")
A1.Position = Vector3.new(0, 3, 0)
A1.Parent = Meteor

A2 = Instance.new("Attachment")
A2.Position = Vector3.new(0, -3, 0)
A2.Parent = Meteor

Trail = script.MeteorTrail
Trail.Parent = Meteor
Trail.Attachment0 = A1
Trail.Attachment1 = A2
Trail.Enabled = true

--character detection stuff do not steal

DetectionAOE = Vector3.new(30, 30, 30)
TempHums = {}
parts = {}
TempRoot = nil
TempChar = nil
TempHum = nil
Ignore = false
Targets = {}
Distance = 999

function FindCharacters(rangePoint, maxRange)
	TempHums = {}
	Targets = {}
	DetectionAOE = Vector3.new(maxRange, maxRange, maxRange)
	DetectRegion = Region3.new(rangePoint - DetectionAOE, rangePoint + DetectionAOE)
	parts = game.Workspace:FindPartsInRegion3(DetectRegion, Char, math.huge)
	for a = 1, #parts do
		if parts[a].Parent ~= nil and parts[a].Parent:FindFirstChild("Humanoid") and not parts[a].Parent:FindFirstChild("ForceField") and not TeamAlly(parts[a].Parent) and not MinionAlly(parts[a].Parent) and not MinionTeamAlly(parts[a].Parent) then
			TempRoot = parts[a].Parent:FindFirstChild("HumanoidRootPart") or parts[a].Parent:FindFirstChild("Torso")
			TempHum = parts[a].Parent.Humanoid
			TempChar = parts[a].Parent
			Ignore = false
			for h = 1, #TempHums do
				if TempHums[h] == TempHum then
					Ignore = true
				end
			end
			if Ignore == false and TempRoot and TempHum.Health > 0 then
				Distance = (rangePoint - TempRoot.Position).magnitude
				if Distance <= maxRange then
					table.insert(TempHums, TempHum)
					UntagHumanoid(TempHum)
					TagHumanoid(TempHum, Plyr)
					TempHum:TakeDamage(200 - Distance)
				end
			end
		end
	end
end

-- end character detection stuff

function BulletHit(hit)
	if hit.Parent ~= nil and hit.Name ~= "Meteor" and not hit:IsDescendantOf(Char) and not TeamAlly(hit.Parent) and not MinionAlly(hit.Parent) and not MinionTeamAlly(hit.Parent) and Meteor.Anchored == false and hit.CanCollide == true then
		Meteor.Anchored = true
		Meteor.Transparency = 1
		Meteor.CanCollide = false
		ImpactSound:Play()
		--FlySound:Stop()
		Trail.Enabled = false
		Fire.Enabled = false
		Sparkles.Enabled = false
		Sparkles:Emit(1000)
		FindCharacters(Meteor.Position, 30)
		wait(3)
		Meteor:Destroy()
	end
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

StarImpact = Meteor.Touched:Connect(BulletHit)
--FlySound:Play()

wait(5)
if Meteor.Anchored == false then
	Meteor:Destroy()
end
