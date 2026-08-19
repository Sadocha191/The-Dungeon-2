--Black hole shield!(also prevents being pushed by other stuff)

task.wait(0.2)

Char = script.Parent
Hum = Char:FindFirstChild("Humanoid")
Head = Char:FindFirstChild("Head")
Torso = Char:FindFirstChild("Torso")or Char:FindFirstChild("HumanoidRootPart")

Plyr = game.Players:GetPlayerFromCharacter(Char)


if Hum == nil or Head == nil or Torso == nil then
	script:Destroy()
end

forces = {}

--function Shield(part)
ch = Char:GetDescendants()
for a = 1, #ch do
	if ch[a]:IsA("BodyMover") then
		ch[a]:Destroy()
	end
	if ch[a]:IsA("BasePart") and ch[a]:FindFirstChild("FAKE") == nil then
		BP = Instance.new("BodyPosition")
		BP.MaxForce = Vector3.new(0, 0, 0)
		BP.D = 0
		BP.P = 0
		BP.Parent = ch[a]
		BP.Name = "FAKE"
		table.insert(forces, BP)

		BV = Instance.new("BodyVelocity")
		BV.MaxForce = Vector3.new(0, 0, 0)
		BV.P = 0
		BV.Parent = ch[a]
		BV.Name = "FAKE"
		table.insert(forces, BV)

		BF = Instance.new("BodyForce")
		BF.Force = Vector3.new(0, 0, 0)
		BF.Parent = ch[a]
		BF.Name = "FAKE"
		table.insert(forces, BF)

		BT = Instance.new("BodyThrust")
		BT.Force = Vector3.new(0, 0, 0)
		BT.Parent = ch[a]
		BT.Name = "FAKE"
		table.insert(forces, BT)

		RP = Instance.new("RocketPropulsion")
		RP.MaxTorque = Vector3.new(0, 0, 0)
		RP.MaxSpeed = 0
		RP.MaxThrust = 0
		RP.ThrustD = 0
		RP.ThrustP = 0
		RP.TurnD = 0
		RP.TurnP = 0
		RP.Parent = ch[a]
		RP.Name = "FAKE"
		table.insert(forces, RP)

		BG = Instance.new("BodyGyro")
		BG.MaxTorque = Vector3.new(0, 0, 0)
		BG.D = 0
		BG.P = 0
		BG.Parent = ch[a]
		BG.Name = "FAKE"
		table.insert(forces, BG)

		BAV = Instance.new("BodyAngularVelocity")
		BAV.MaxTorque = Vector3.new(0, 0, 0)
		BAV.P = 0
		BAV.Parent = ch[a]
		BAV.Name = "FAKE"
		table.insert(forces, BAV)
	end
	end
--end

while Char:FindFirstChild("GravityShieldPart") do
	task.wait()
	ch = Char:GetDescendants()
	for a = 1, #ch do
		if ch[a]:IsA("BodyMover") and ch[a].Name ~= "FAKE" then
			ch[a]:Destroy()
		end
	end
end

for b = 1, #forces do
	forces[b]:Destroy()
end

script:Destroy()
