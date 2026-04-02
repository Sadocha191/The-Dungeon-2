--this is just for effect

Char = script.Parent
Hum = Char:FindFirstChild("Humanoid")
Head = Char:FindFirstChild("Head")
Torso = Char:FindFirstChild("Torso")or Char:FindFirstChild("UpperTorso")
Root = Char:FindFirstChild("HumanoidRootPart")

Plyr = game.Players:GetPlayerFromCharacter(Char)

Debree = game:GetService("Debris")
Run = game:GetService("RunService")

if Hum == nil or Head == nil or Torso == nil then
	script:Destroy()
end

GSL = Char:FindFirstChild("GravityScriptLocal")

function AntiMover(force) --we don't need this
	if force:IsA("BodyMover") then
		Debree:AddItem(force, 0)
	end
end

ShieldPart = Instance.new("Part")
ShieldPart.BrickColor = BrickColor.new("Really black")
ShieldPart.Material = "ForceField"
ShieldPart.Transparency = Torso.Transparency
ShieldPart.Size = Vector3.new(1, 1, 1)
ShieldPart.Position = Root.Position
ShieldPart.Parent = Char
ShieldPart.Name = "GravityShieldPart"

ShieldMesh = Instance.new("SpecialMesh")
ShieldMesh.MeshId = "http://www.roblox.com/asset?id=147831825"
ShieldMesh.TextureId = "http://www.roblox.com/asset/?id=94257533"
ShieldMesh.Scale = Vector3.new(0, 0, 0)
ShieldMesh.VertexColor = Vector3.new(0, 0, 0)
ShieldMesh.Parent = ShieldPart

ShieldWeld = Instance.new("Weld")
ShieldWeld.Part0 = Root or Torso
ShieldWeld.Part1 = ShieldPart
ShieldWeld.C0 = CFrame.new(Vector3.new(0, 0, 0))
ShieldWeld.Parent = ShieldPart

--ch = Char:GetDescendants()
--for a = 1,#ch do
	--if ch[a]:IsA("BasePart") then
		--ch[a].ChildAdded:connect(AntiMover)
	--end
--end

for b = 1, 40 do
	Run.Heartbeat:wait()
	ShieldMesh.Scale = ShieldMesh.Scale + Vector3.new(1, 1, 1) * 0.25
end

--Run = game:GetService("RunService")

ShieldTimer = 1500
OrbAngle = 0

while ShieldTimer > 0 do
	Run.Heartbeat:wait()
	ShieldTimer = ShieldTimer - 1
	OrbAngle = OrbAngle + 1
	ShieldWeld.C0 = CFrame.new(Vector3.new(0, 0, 0)) * CFrame.Angles(OrbAngle/20, OrbAngle/-40, OrbAngle/25)
end

ShieldPart:Destroy()

task.wait(1)
if GSL and GSL.Parent then
	GSL:Destroy()
end

script:Destroy()
