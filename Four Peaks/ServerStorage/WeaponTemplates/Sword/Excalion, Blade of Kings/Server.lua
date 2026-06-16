--Revamped by TakeoHonorable
--Ultimate Swords: Crescendo the Soul Stealer(Stealer of Souls)

local Properties = {
	SoulSnatch_Range = 175, -- The range the souls can lock on to people
	Health_Regen = 0 -- The amount of health gained per second
}

local Instant,Pairs,Type = Instance.new,pairs,type

local Vec3, Cframe = Vector3.new, CFrame.new

function Create(ty)
	return function(data)
		local obj = Instant(ty)
		for k, v in Pairs(data) do
			if Type(k) == 'number' then
				v.Parent = obj
			else
				obj[k] = v
			end
		end
		return obj
	end
end

local Self,world = script,workspace

local inf = math.huge

local Tool = Self.Parent
Tool.Enabled = true

local WaitForChild,FindFirstChildOfClass,FindFirstChild = Self.WaitForChild,Self.FindFirstChildOfClass,Self.FindFirstChild

local Clone,Destroy = Self.Clone,Self.Destroy

local GetChildren, GetDescendants = Self.GetChildren, Self.GetDescendants

local IsA = Self.IsA

local Handle = WaitForChild(Tool,"Handle",inf)

local SetNetworkOwner = Handle.SetNetworkOwner

local MouseLoc, Remote, SoulRemote = (FindFirstChildOfClass(Tool,"RemoteFunction") or Create("RemoteFunction"){
	Name = "MouseLoc",
	Parent = Tool
})
,(FindFirstChild(Tool,"Remote") or Create("RemoteEvent"){
	Name = "Remote",
	Parent = Tool
}),(FindFirstChild(Tool,"SoulRemote") or Create("RemoteEvent"){
	Name = "SoulRemote",
	Parent = Tool
})


local Player,Character,Humanoid,Root

local Sounds = {
	Consume = WaitForChild(Handle,"Consume"),
	Lunge = WaitForChild(Handle,"Lunge"),
	Purge = WaitForChild(Handle,"Purge"),
	Slash = WaitForChild(Handle,"Slash"),
	Unsheath = WaitForChild(Handle,"Unsheath")
}

local Grips = {
	Up = Cframe(0, -2.3, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
	Out = Cframe(0, -2.3, 0, 1, 0, 0, 0, 0, -1, -0, 1, 0),
}

local SoulColors = {
	{Start = Color3.fromRGB(140, 0, 255),End = Color3.fromRGB(140, 0, 255)},--Purple/Purple
	{Start = Color3.fromRGB(140, 0, 255),End = Color3.fromRGB(140, 0, 255)}--Purple/Purple
}

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

local SoulLight = Create("PointLight"){
	Name = "Light",
	--Color = SoulFire.Color,
	Brightness = 35,
	Range = 4,
	Shadows = false,
	Enabled = true,
}

local Events, Deletables = {}, {}

local Services = {
	Players = (game:FindService("Players") or game:GetService("Players")),
	TweenService = (game:FindService("TweenService") or game:GetService("TweenService")),
	RunService = (game:FindService("RunService") or game:GetService("RunService")),
	Debris = (game:FindService("Debris") or game:GetService("Debris")),
	ReplicatedStorage = (game:FindService("ReplicatedStorage") or game:GetService("ReplicatedStorage")),
	Lighting = (game:FindService("Lighting") or game:GetService("Lighting")),
	ServerScriptService = (game:FindService("ServerScriptService") or game:GetService("ServerScriptService"))
}

local Berserk = false
function ChangeState(State)
	--Has the be either 'Normal' or 'Berserk'
	Berserk = (State == "Berserk")
	
	pcall(function()
		Handle.Animated_Eye.Eye_Normal.Enabled = not Berserk
		Handle.Animated_Eye.Eye_Normal2.Enabled = not Berserk
		Handle.Animated_Eye.Eye_Berserk.Enabled = Berserk
		Handle.Animated_Eye.Eye_Berserk2.Enabled = Berserk
	end)
	
	pcall(function()
		Handle.Effect.Fire.Color = (Berserk and Color3.fromRGB(140, 0, 255)) or Color3.fromRGB(140, 0, 255)
		Handle.Light.Color = (Berserk and Color3.fromRGB(140, 0, 255)) or Color3.fromRGB(140, 0, 255)
	end)
end

ChangeState("Normal")

function IsInTable(Table,Value)
	for _,v in Pairs(Table) do
		if v == Value then
			return true
		end
	end
	return false
end

local function Wait(para) -- bypasses the latency
	local Initial = tick()
	repeat
		Services.RunService.Heartbeat:Wait()
	until tick()-Initial >= para
end

function IsTeamMate(Player1, Player2)
	return (Player1 and Player2 and not Player1.Neutral and not Player2.Neutral and Player1.TeamColor == Player2.TeamColor)
end

function TagHumanoid(humanoid, player)
	local Creator_Tag = Instance.new("ObjectValue")
	Creator_Tag.Name = "creator"
	Creator_Tag.Value = player
	Services.Debris:AddItem(Creator_Tag, 2)
	Creator_Tag.Parent = humanoid
end

function UntagHumanoid(humanoid)
	for i, v in pairs(humanoid:GetChildren()) do
		if IsA(v,"ObjectValue") and v.Name == "creator" then
			Destroy(v)
		end
	end
end

local Abilities = {
	[Enum.KeyCode.E] = {
		Ready = true,
		Reload = 15,
		Function = function()--Sends out souls to snatch the souls of the unfortunate
			local LockedTargets = {} --Players that are already targeted
			
			Sounds.Consume:Play()
			local Sucess,MousePos = pcall(function() return MouseLoc:InvokeClient(Player) end)
			MousePos = (Sucess and MousePos) or Vec3(0,0,0)
			
			local Seed = Random.new()
			
			for i=1,5,1 do
				local Target = GetClosestEnemy(Properties.SoulSnatch_Range*((Berserk and 1.60) or 1),LockedTargets)
				LockedTargets[#LockedTargets+1] = Target -- Can be a character or nil
				local TargetSoul = Clone(SoulBase)
				TargetSoul.Size = Vec3(1,1,1) * .5
				if Target then
					--Create a soul that targets the specific entity
					local Fire = Clone(WaitForChild(Self,"SoulFire"))
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
					
					TargetSoul.CFrame = (Root.CFrame + Root.CFrame.LookVector * 4)
					local Propulsion = Instance.new('BodyForce')
					Propulsion.Name = "SoulFloat"
					Propulsion.Force = Vec3(0,TargetSoul:GetMass() * workspace.Gravity,0)
					Propulsion.Parent = TargetSoul
					
					local TargetValue = Instance.new("ObjectValue")
					TargetValue.Name = "Target"
					TargetValue.Value = FindFirstChild(Target,"Torso") or FindFirstChild(Target,"UpperTorso")
					
							
					local SoulScript = Clone(WaitForChild(Self,"SoulScript"))
					
					TargetValue.Parent = SoulScript
					
					WaitForChild(SoulScript,"Tool").Value = Tool
					WaitForChild(SoulScript,"Creator").Value = Player
					WaitForChild(SoulScript,"SoulCount").Value = WaitForChild(Tool,"SoulCount")
					SoulScript.Parent = TargetSoul
					SoulScript.Disabled = false
					
					TargetSoul.Parent = world
					--Propulsion:Fire()
					SetNetworkOwner(TargetSoul,nil)
					
					else
					--Creates a soul that shoots to your mouse position
					local Fire = Clone(WaitForChild(Self,"SoulFire"))
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
					
					TargetSoul.CFrame = (Root.CFrame + Root.CFrame.LookVector * 4)
					local Propulsion = Instant("BodyVelocity")
						Propulsion.Velocity = (MousePos - Root.CFrame.Position).Unit * 150
						Propulsion.MaxForce = Vec3(1,1,1) * inf
						Propulsion.Parent = TargetSoul
							
					local SoulScript = Clone(WaitForChild(Self,"SoulScript"))
					WaitForChild(SoulScript,"Tool").Value = Tool
					WaitForChild(SoulScript,"Creator").Value = Player
					WaitForChild(SoulScript,"SoulCount").Value = WaitForChild(Tool,"SoulCount")
					SoulScript.Parent = TargetSoul
					SoulScript.Disabled = false
					--Debris:AddItem(Part2, 15)
					
					TargetSoul.Parent = world
					SetNetworkOwner(TargetSoul,nil)
					
				end
			end
			return true
		end
	},
	[Enum.KeyCode.X] = {
		Ready = true,
		Reload = 45,
		Function = function()
			
			if Berserk then return end
			
			local SoulsRequired = 0
			
			local SoulCount = FindFirstChild(Tool,"SoulCount")
			
			if not SoulCount or SoulCount.Value < SoulsRequired then return end --Need 0 souls to perform this ability
			
			if FindFirstChild(Services.ServerScriptService,"SoulHunt") then return end
			
			SoulCount.Value = SoulCount.Value - SoulsRequired
			
			--print("Soul Seeker ability activated")
			ChangeState("Berserk")
			
			pcall(function()
				local SoulHunt = Clone(script.SoulHunt)
				
				local Creator = Instant("ObjectValue")
				Creator.Name = "Creator"
				Creator.Value = Player
				Creator.Parent = SoulHunt
				
				local RemoteRef = Instant("ObjectValue")
				RemoteRef.Name = "RemoteRef"
				RemoteRef.Value = SoulRemote
				RemoteRef.Parent = SoulHunt
				
				SoulHunt.Parent = Services.ServerScriptService
				SoulHunt.Disabled = false
				
				local Auras = {}
				
				pcall(function()
					local clone = Clone(script.Berserk_Aura)
					Auras[#Auras+1] = clone
					clone.Parent = Handle
					clone.Enabled = true
					
					for _,v in pairs(GetChildren(Character)) do
						if IsA(v,"BasePart") then
							clone = Clone(script.Berserk_Aura)
							Auras[#Auras+1] = clone
							clone.Parent = v
							clone.Enabled = true
						end
					end
				end)
				SoulHunt.AncestryChanged:Connect(function(child, parent)
					--print(child, parent)
					if child ~= SoulHunt then return end
					
					if parent then return end 
					
					for i=1,#Auras,1 do
						if Auras[i] then
							Auras[i].Enabled = false
							Services.Debris:AddItem(Auras[i],Auras[i].Lifetime.Max)
							--Destroy(Auras[i])
						end
					end
					
					ChangeState("Normal")
				end)
			end)
			
			return true
		end
	}
}

function Attack(hit,Damage)
	if not hit or not hit.Parent then return end
	if (Handle.Position-hit.Position).Magnitude > math.max(Handle.Size.X,Handle.Size.Y,Handle.Size.Z) then return end
	
	local Hum,FF = FindFirstChildOfClass(hit.Parent,"Humanoid"),FindFirstChildOfClass(hit.Parent,"ForceField")
	if not Hum or Hum.Health <= 0 or FF or Hum == Humanoid or IsTeamMate(Player,Services.Players:GetPlayerFromCharacter(Hum.Parent)) then return end
	local function Decimated(Character) -- Quick check to see if they're not decimated
		for _,v in pairs(GetChildren(Services.ServerScriptService)) do
			if IsA(v,"Script") and v.Name == "Decimate" and FindFirstChild(v,"Character") and FindFirstChild(v,"Character").Value == Hum.Parent then
				return true
			end
		end
		return false
	end
	
	if (Hum.Health/Hum.MaxHealth)*100 <= 30 then
		--Take their soul already
		if Decimated(Hum.Parent) then return end
		local DecimateScript = Clone(WaitForChild(Self,"Decimate"))
		local ToolObj = Instant("ObjectValue")
			ToolObj.Name = "Tool"
			ToolObj.Value = Tool
			ToolObj.Parent = DecimateScript
		
		local Creator = Instant("ObjectValue")
			Creator.Name = "Creator"
			Creator.Value = Player
			Creator.Parent = DecimateScript
		
		local Character = Instant("ObjectValue")
			Character.Name = "Character"
			Character.Value = Hum.Parent
			Character.Parent = DecimateScript
			
		local SoulCount = Instant("ObjectValue")
			SoulCount.Name = "SoulCount"
			SoulCount.Value = WaitForChild(Tool,"SoulCount")
			SoulCount.Parent = DecimateScript
		
		DecimateScript.Parent = Services.ServerScriptService
		DecimateScript.Disabled = false
	else
		UntagHumanoid(Hum)
		TagHumanoid(Hum,Player)
		Hum:TakeDamage(Damage or 0)
	end
end

local Touch
function Equipped()
	Character = Tool.Parent
	
	if not Character then return end
		
	Player = Services.Players:GetPlayerFromCharacter(Character)
	
	Humanoid = FindFirstChildOfClass(Character,"Humanoid")
	
	if not Humanoid or Humanoid.Health <= 0 or Humanoid.Health == math.huge or Humanoid.MaxHealth == math.huge then return end
	
	Humanoid.WalkSpeed = 20
	
	Root = FindFirstChild(Character,"HumanoidRootPart") or FindFirstChild(Character,"Torso")
	
	Events[#Events+1] = Tool.Activated:Connect(Activated)
	
	Events[#Events+1] = Handle.Touched:Connect(function(hit)
		Attack(hit,25)
	end)
	
	Events[#Events+1] = Remote.OnServerEvent:Connect(function(Client,Key)
		if Client ~= Player or not Tool.Enabled or not Humanoid or Humanoid.Health <= 0 or not Key then return end

		if not Abilities[Key] or not Abilities[Key].Ready then return end
		
		local success = Abilities[Key].Function(Character)
		
		if not success then return end
		
		Abilities[Key].Ready = false

		delay(Abilities[Key].Reload ,function()
			Abilities[Key].Ready = true
		end)
		

	end)
	
	Events[#Events+1] = SoulRemote.OnServerEvent:Connect(function(Client,Target)
		local SoulCount = FindFirstChild(Tool,"SoulCount")
		
		if not Berserk or Client ~= Player or not Tool.Enabled or not Humanoid or Humanoid.Health <= 0 or not Target or not Target.Parent then return end
		
		local Hum = FindFirstChildOfClass(Target.Parent,"Humanoid")
		
		if Hum == Humanoid or not Hum or Hum.Health <= 0 or IsTeamMate(Player,Services.Players:GetPlayerFromCharacter(Hum.Parent)) then return end
				
		if not SoulCount or SoulCount.Value < 1 then return end
		
		SoulCount.Value = SoulCount.Value - 5 --// A soul for a soul
		
		Tool.Enabled = false
		
		delay(3,function()
			Tool.Enabled = true
		end)
		
		Sounds.Consume:Play()

		local Seed = Random.new()

		--Create a soul that targets the specific entity
		local TargetSoul = Clone(SoulBase)
		TargetSoul.Size = Vec3(1,1,1) * 2
		
		local Fire = Clone(WaitForChild(Self,"SoulFire"))
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
					
		TargetSoul.CFrame = (Root.CFrame + Root.CFrame.LookVector * 4)
		local Propulsion = Instance.new('BodyForce')
		Propulsion.Name = "SoulFloat"
		Propulsion.Force = Vec3(0,TargetSoul:GetMass() * workspace.Gravity,0)
		Propulsion.Parent = TargetSoul
					
		local TargetValue = Instance.new("ObjectValue")
		TargetValue.Name = "Target"
		TargetValue.Value = Target--FindFirstChild(Target,"Torso") or FindFirstChild(Target,"UpperTorso")
					
							
		local SoulScript = Clone(WaitForChild(Self,"SoulScript"))
					
		TargetValue.Parent = SoulScript
					
		WaitForChild(SoulScript,"Tool").Value = Tool
		WaitForChild(SoulScript,"Creator").Value = Player
		WaitForChild(SoulScript,"SoulCount").Value = WaitForChild(Tool,"SoulCount")
		SoulScript.Parent = TargetSoul
		SoulScript.Disabled = false
					
		TargetSoul.Parent = world
		--Propulsion:Fire()
		SetNetworkOwner(TargetSoul,nil)
		
	end)
	
	local Current_Time = 0
	Events[#Events+1] = Services.RunService.Heartbeat:Connect(function(step) -- Health Regen
		if Current_Time >= 1 and Humanoid and Humanoid.Health > 0 and (Humanoid.Health + Properties.Health_Regen) <= Humanoid.MaxHealth then
			Current_Time = 0
			Humanoid.Health = Humanoid.Health + Properties.Health_Regen
		end
		Current_Time = Current_Time + step
	end)
	
	local IgnoreHealthChange = false
	local CurrentHealth = Humanoid.Health
	local SoulCount = FindFirstChild(Tool,"SoulCount")
	
	--SoulCount.Value = math.clamp(SoulCount.Value,0,7)
	if SoulCount then
		Events[#Events+1] = SoulCount.Changed:Connect(function()
			--SoulCount.Value = math.clamp(SoulCount.Value,0,7)
			--print(SoulCount.Value)
			Properties.Health_Regen = (SoulCount.Value/7)*10
		end)
	end
	
	local Died = false
	Events[#Events+1] = Humanoid:GetPropertyChangedSignal("Health"):Connect(function(Property)
		local NewHealth = Humanoid.Health
		if not IgnoreHealthChange and NewHealth ~= Humanoid.MaxHealth then
			if NewHealth < CurrentHealth then
				local DamageDealt = (CurrentHealth - NewHealth)
				IgnoreHealthChange = true
				Humanoid.Health = Humanoid.Health + (DamageDealt * (((Berserk and .95) or 0) + ((SoulCount and (SoulCount.Value/7)*.7) or 0) ))
				IgnoreHealthChange = false
			end
		end
		CurrentHealth = NewHealth
		--[[if Humanoid.Health <= 0 then
			print("Humanoid is dead")
			if not Died then
				print("Expelling Souls")
				Died = true
				ExpellSouls(Root)
			end
		end]]
	end)
	
	
	Sounds.Unsheath:Play()
end

function Unequipped()
	
	for i=1, #Events, 1 do
		if Events[i] then
			Events[i]:Disconnect()
		end
	end
	Events = {}
	
	for i=1, #Deletables, 1 do
		if Deletables[i] then
			Destroy(Deletables[i])
		end
	end
	Deletables = {}
	
	if Humanoid then
		Humanoid.WalkSpeed = 16
	end

end

local LastAttack = 0
local Lunging = false

function Activated()
	if not Tool.Enabled then return end
	
	Tool.Enabled = false
	
	local Time = Services.RunService.Stepped:Wait()
	
	if (Time-LastAttack) < 0.2 then
		--Lunge
	local Anim = Instant("StringValue")
		Anim.Name = "toolanim"
		Anim.Value = "Lunge"
		Anim.Parent = Tool
		
	local Sucess,Target = pcall(function() return MouseLoc:InvokeClient(Player) end)
	Target = (Sucess and Target) or Vec3(0,0,0)
	
	local TargetPosition = Target
	local Direction = (Cframe(Root.Position, TargetPosition).LookVector * Vec3(1, 0, 1))
	Tool.Grip = Grips.Out
	Sounds.Lunge:Play()
	if Direction.Magnitude > 0.01 then
		Direction = Direction.Unit 
		local NewBV = Instant("BodyVelocity")
			NewBV.P = 100000
			NewBV.MaxForce = Vec3(inf, 0, inf)
			NewBV.Velocity = (Direction * 100)
			
		Services.Debris:AddItem(NewBV, 0.75)
		NewBV.Parent = Root
		Root.CFrame = Cframe(Root.Position, (TargetPosition * Vec3(1, 0, 1) + Vec3(0, Root.Position.Y, 0)))
	end
	
	local Lunging = true
	
	coroutine.wrap(function()
		local After = Clone(Handle)
		for _,stuff in pairs(GetDescendants(After)) do
			if IsA(stuff,"Sound") or IsA(stuff,"BaseScript") then
				Destroy(stuff)
			end
		end
		local AfterImageScript = Clone(script.AfterImageScript)
		
		local Creator = Instant("ObjectValue")
		Creator.Name = "Creator"
		Creator.Value = Player
		Creator.Parent = AfterImageScript
		
		local ToolRef = Instant("ObjectValue")
		ToolRef.Name = "ToolRef"
		ToolRef.Value = Tool
		ToolRef.Parent = AfterImageScript
		
		local CreatorHum = Instant("ObjectValue")
		CreatorHum.Name = "CreatorHum"
		CreatorHum.Value = Humanoid
		CreatorHum.Parent = AfterImageScript
		
		AfterImageScript.Parent = After
		repeat
			local AfterImage = Clone(After)
			AfterImage.Name = "AfterImage"
			AfterImage.Anchored = true
			AfterImage.Transparency = 0.5
			AfterImage.CFrame = Handle.CFrame
			AfterImage.Parent = world
			AfterImage.AfterImageScript.Disabled = false
			Services.Debris:AddItem(AfterImage,2)
			Wait(1/30)
		until not Lunging
	end)()
	
	wait(0.75)
	Lunging = false
	Tool.Grip = Grips.Up
	wait(0.5)
	
	
	else
		--Slash
		local Anim = Instant("StringValue")
		Anim.Name = "toolanim"
		Anim.Value = "Slash"
		Anim.Parent = Tool
		
		coroutine.wrap(function()
			local After = Clone(Handle)
			for _,stuff in pairs(GetDescendants(After)) do
				if IsA(stuff,"Sound") or IsA(stuff,"BaseScript") then
					Destroy(stuff)
				end
			end
			local AfterImageScript = Clone(script.AfterImageScript)
			
			
			local Creator = Instant("ObjectValue")
			Creator.Name = "Creator"
			Creator.Value = Player
			Creator.Parent = AfterImageScript
			
			local ToolRef = Instant("ObjectValue")
			ToolRef.Name = "ToolRef"
			ToolRef.Value = Tool
			ToolRef.Parent = AfterImageScript
			
			local CreatorHum = Instant("ObjectValue")
			CreatorHum.Name = "CreatorHum"
			CreatorHum.Value = Humanoid
			CreatorHum.Parent = AfterImageScript
			
			AfterImageScript.Parent = After
			
			for i=1,4,1 do
				local AfterImage = Clone(After)
				AfterImage.Name = "AfterImage"
				AfterImage.Anchored = true
				AfterImage.Transparency = 0.5
				AfterImage.CFrame = Handle.CFrame
				AfterImage.Parent = workspace
				AfterImage.AfterImageScript.Disabled = false
				Services.Debris:AddItem(AfterImage,2)
				Wait(0.06)
			end
		end)()
		
		Sounds.Slash:Play()
	end
	LastAttack = Time
	
	Tool.Enabled = true
end

Tool.Equipped:Connect(Equipped)

Tool.Unequipped:Connect(Unequipped)

function GetClosestEnemy(Range,BlackList)
	for _,player in pairs(Services.Players:GetPlayers()) do
		local Char = player.Character
		local Torso = FindFirstChild(Char,"Torso") or FindFirstChild(Char,"UpperTorso")
		local Hum, FF = FindFirstChildOfClass(Char,"Humanoid"), FindFirstChildOfClass(Char,"ForceField") 
		if Hum and not FF and Hum.Health ~= 0 and Torso and not IsTeamMate(Player,player) and Hum ~= Humanoid and not IsInTable(BlackList,Char) then
			if (Root.CFrame.Position-Torso.CFrame.Position).Magnitude <= Range  then
				return Char
			end
		end
	end
	return nil
end

