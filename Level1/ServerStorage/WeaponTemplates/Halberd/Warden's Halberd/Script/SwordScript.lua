sp = script.Parent

r = game:service("RunService")
debris = game:GetService("Debris")

anims = {"RightSlash","LeftSlash","OverHeadSwing","LeftSwingFast","RightSwingFast"}

Sounds = {{145180512, "Metal"}, {145180522, "Metal"}, {145180533, "Wood"}, {145180541, "Wood"}, {145180529, "Slash"}, {145180550, "Slash"}}

WoodSounds = {}
MetalSounds = {}
SlashSounds = {}

basedamage = 2
slashdamage = 30
swingdamage = 45
damage = basedamage

sword = sp.Handle
sp.Taunting.Value = false

local UnsheathSound = Instance.new("Sound")
UnsheathSound.SoundId = "http://www.roblox.com/Asset/?id=145180523"
UnsheathSound.Parent = sword
UnsheathSound.Volume = 3

for _,Sound in pairs(Sounds) do
	local S = Instance.new("Sound")
	S.SoundId = "http://www.roblox.com/Asset/?id=" .. Sound[1]
	S.Parent = sword
	S.Volume = 1
	if Sound[2] == "Wood" then
		table.insert(WoodSounds, S)
	elseif Sound[2] == "Metal" then
		table.insert(MetalSounds, S)
	elseif Sound[2] == "Slash" then
		table.insert(SlashSounds, S)
	end
end

function waitfor(parent,name)
	while true do
		local child = parent:FindFirstChild(name)
		if child ~= nil then
			return child
		end
		wait()
	end
end

waitfor(sp,"Taunting")
waitfor(sp,"RunAnim")
local Halt = false;
function blow(hit)
	if hit:findFirstChild("IsShield") then
		damage = 0
		pcall(function()
			if hit.IsShield.Value == "Wood" then
				WoodSounds[math.random(#WoodSounds)]:Play()
			elseif hit.IsShield.Value == "Metal" then
				MetalSounds[math.random(#MetalSounds)]:Play()
			else
				WoodSounds[math.random(#WoodSounds)]:Play()
			end
		end);
		return
	end
	if Halt then return end;
	Halt = true;
	if hit.Parent ~= nil then
		local humanoid = hit.Parent:findFirstChild("Humanoid")
		local vCharacter = sp.Parent
		if vCharacter ~= nil then
			local vPlayer = game.Players:playerFromCharacter(vCharacter)
			if vPlayer ~= nil then
				local hum = vCharacter:findFirstChild("Humanoid")
				if humanoid ~= nil then
					if hum ~= nil and humanoid ~= hum then
						local right_arm = vCharacter:FindFirstChild("Right Arm")
						if right_arm ~= nil then
							local joint = right_arm:FindFirstChild("RightGrip")
							if joint ~= nil and (joint.Part0 == sword or joint.Part1 == sword) then
								tagHumanoid(humanoid,vPlayer)
								humanoid:TakeDamage(damage)
								wait(.3)
							end
						end
					end
				end
			end
		end
	end
	Halt = false;
end

function tagHumanoid(humanoid,player)
	for i,v in ipairs(humanoid:GetChildren()) do
		if v.Name == "creator" then
			v:Destroy()
		end
	end
	local creator_tag = Instance.new("ObjectValue")
	creator_tag.Value = player
	creator_tag.Name = "creator"
	creator_tag.Parent = humanoid
	debris:AddItem(creator_tag,1)
end

sp.Enabled = true
function onActivated()
	if sp.Enabled and not sp.Taunting.Value then
		sp.Enabled = false
		local character = sp.Parent;
		local humanoid = character.Humanoid
		if humanoid == nil then
			print("Humanoid not found")
			return 
		end
		SlashSounds[math.random(#SlashSounds)]:Play()
		newanim = anims[math.random(1,#anims)]
		while newanim == sp.RunAnim.Value do
			newanim = anims[math.random(1,#anims)]
		end
		sp.RunAnim.Value = newanim
		if newanim == "OverHeadSwing" then
			damage = swingdamage
		else
			damage = slashdamage
		end
		wait(.75)
		damage = basedamage
		sp.Enabled = true
	end
end

function onEquipped()
	UnsheathSound:play()
end

sp.Activated:connect(onActivated)
sp.Equipped:connect(onEquipped)

connection = sword.Touched:connect(blow)