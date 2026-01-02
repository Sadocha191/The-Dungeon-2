--// Takes the souls that you have left and send them out as a last killing resort

local Tool = script.Parent

local Player, Character, Humanoid, Root

local FindFirstChild, FindFirstChildOfClass, WaitForChild = script.FindFirstChild, script.FindFirstChildOfClass, script.WaitForChild

local Destroy, Clone = script.Destroy, script.Clone

local Instant, Vec3 = Instance.new, Vector3.new

local Events = {}

local Services = {
	Players = (game:FindService("Players") or game:GetService("Players")),
}

local SoulColors = {
	{Start = Color3.fromRGB(140, 0, 255),End = Color3.fromRGB(140, 0, 255)},--Purple/Purple
	{Start = Color3.fromRGB(140, 0, 255),End = Color3.fromRGB(140, 0, 255)}--Purple/Purple
}

function IsInTable(Table,Value)
	for _,v in pairs(Table) do
		if v == Value then
			return true
		end
	end
	return false
end

function IsTeamMate(Player1, Player2)
	return (Player1 and Player2 and not Player1.Neutral and not Player2.Neutral and Player1.TeamColor == Player2.TeamColor)
end

function Create(ty)
	return function(data)
		local obj = Instant(ty)
		for k, v in pairs(data) do
			if type(k) == 'number' then
				v.Parent = obj
			else
				obj[k] = v
			end
		end
		return obj
	end
end

local SoulBase = Create("Part"){
	Anchored = false,
	Name = "SoulSnatcher",
	Locked = true,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	Shape = Enum.PartType.Ball,
	Transparency = 0.9,
	CanCollide = false,
	Material = Enum.Material.Neon,
	--Size = Vec3(1,1,1)*.5,
}

local SetNetworkOwner = SoulBase.SetNetworkOwner

local SoulLight = Create("PointLight"){
	Name = "Light",
	--Color = SoulFire.Color,
	Brightness = 35,
	Range = 4,
	Shadows = false,
	Enabled = true,
}

function ExpellSouls(Root)
		--Do the suicide bomb with the remaining souls
		
		--if Humanoid.Health > 0  then return end
		
		--print("Suicide Bomb event trigger")
		
		local SoulCount = FindFirstChild(Tool,"SoulCount")
		
		if not SoulCount then return end
		
		--print("Expelling " .. SoulCount.Value .. " souls")
		
		local LockedTargets = {} --Players that are already targeted
		
		local Seed = Random.new()
		
		for i=1,SoulCount.Value,1 do
			local Target = GetClosestEnemy(280,LockedTargets)
			--Target = Target or Vector3.new(0,0,Seed:NextNumber(-1,1))
			LockedTargets[#LockedTargets+1] = Target -- Can be a character or nil
				local TargetSoul = Clone(SoulBase)
				TargetSoul.Size = Vec3(1,1,1) * 15
				local Fire = Clone(WaitForChild(script,"SoulFire_Large"))
				local Light = Clone(SoulLight)
				local SoulColorBase = SoulColors[Seed:NextInteger(1,#SoulColors)]
				local SoulColorStart,SoulColorEnd = SoulColorBase.Start,SoulColorBase.End
					
				TargetSoul.Color = SoulColorStart
				Fire.Color = ColorSequence.new(SoulColorStart,SoulColorEnd)
				local Light = Clone(SoulLight)
					Light.Color = TargetSoul.Color
					Light.Parent = TargetSoul
				Fire.Parent = TargetSoul
				Fire.Enabled = true
					
				TargetSoul.CFrame = Root.CFrame--(Root.CFrame + Root.CFrame.LookVector * 4)
				
				--(Target and ((Target.Position - Root.CFrame.Position).Unit * 150) ) or Root.Position + Vec3(Seed:NextNumber(-1,1),Seed:NextNumber(-1,1),Seed:NextNumber(-1,1)) * 150
				
				local Propulsion = Instant("BodyVelocity")
					Propulsion.Velocity = (Target and ((Target.Position - Root.Position).Unit * 150) ) or Root.Position + Vec3(Seed:NextNumber(-1,1),Seed:NextNumber(-1,1),Seed:NextNumber(-1,1)) * 150 --(Target.Position - Root.CFrame.Position).Unit * 150
					Propulsion.MaxForce = Vec3(1,1,1) * math.huge
					Propulsion.Parent = TargetSoul
							
				local SoulScript = Clone(WaitForChild(script,"SoulScript"))
				WaitForChild(SoulScript,"Tool").Value = Tool
				WaitForChild(SoulScript,"Creator").Value = Player
				WaitForChild(SoulScript,"SoulCount").Value = WaitForChild(Tool,"SoulCount")
				SoulScript.Parent = TargetSoul
				SoulScript.Disabled = false
				--Debris:AddItem(Part2, 15)
					
				TargetSoul.Parent = workspace
				SetNetworkOwner(TargetSoul,nil)
		end
	end

function Equipped()
	
	Character = Tool.Parent
	
	Player = Services.Players:GetPlayerFromCharacter(Character)
	
	Humanoid = FindFirstChildOfClass(Character,"Humanoid")
	
	Root = FindFirstChild(Character,"HumanoidRootPart")
	
	if not Humanoid or Humanoid.Health <= 0 or Humanoid.Health == math.huge or Humanoid.MaxHealth == math.huge or not Root then return end
	
	--print("Equipped Death bond")
	
	Events[#Events+1] = Humanoid.Changed:Connect(function()
		if Humanoid.Health <= 0 then
			ExpellSouls(Root)
		end
	end)
	
end

function Unequipped()
	
	for i=1, #Events, 1 do
		if Events[i] then
			Events[i]:Disconnect()
		end
	end
	Events = {}
	
end

Tool.Equipped:Connect(Equipped)

Tool.Unequipped:Connect(Unequipped)

function GetClosestEnemy(Range,BlackList)
	for _,player in pairs(Services.Players:GetPlayers()) do
		local Char = player.Character
		local Torso = FindFirstChild(Char,"Torso") or FindFirstChild(Char,"UpperTorso")
		local Hum = FindFirstChildOfClass(Char,"Humanoid")
		if Hum and Hum.Health ~= 0 and Torso and not IsTeamMate(Player,player) and Hum ~= Humanoid and not IsInTable(BlackList,Torso) then
			if (Root.CFrame.Position-Torso.CFrame.Position).Magnitude <= Range  then
				return Torso
			end
		end
	end
	return nil
end