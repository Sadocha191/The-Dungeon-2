--Controls the aesthetic souls around you

local FindFirstChild, FindFirstChildOfClass, WaitForChild = script.FindFirstChild, script.FindFirstChildOfClass, script.WaitForChild 

local Clone, Destroy = script.Clone, script.Destroy

function Create(ty)
	return function(data)
		local obj = Instance.new(ty)
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

local Tool = script.Parent

local Character, Root, Humanoid

local SoulCount = FindFirstChild(Tool,"SoulCount") or Instance.new("IntValue",Tool)
SoulCount.Name = "SoulCount"
--SoulCount.MaxValue = 7
--SoulCount.MinValue = 7
SoulCount.Value = 0
SoulCount.Parent = Tool

local SoulBase = Create("Part"){
	Anchored = true,
	Locked = true,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	Shape = Enum.PartType.Ball,
	Transparency = 0.7,
	CanCollide = false,
	Name = "Soul",
	Material = Enum.Material.Neon,
	Size = Vector3.new(1,1,1)*.5,
}

SoulLight = Create("PointLight"){
	Name = "Light",
	--Color = SoulFire.Color,
	Brightness = 10,
	Range = 4,
	Shadows = false,
	Enabled = true,
}

local SoulColors = {
	{Start = Color3.fromRGB(255,0,0),End = Color3.fromRGB(0,0,0)},--Red/Black
	{Start = Color3.fromRGB(255,85,0),End = Color3.fromRGB(255,0,0)}--Orange/Red
}

local Souls = {}

local Services = {
	RunService = (game:FindService("RunService") or game:GetService("RunService")),
	Players = (game:FindService("Players") or game:GetService("Players"))
}

local SoulModel ,Run

local Events = {}

function Clean()
	if SoulModel then Destroy(SoulModel);SoulModel = nil end
	if Run then Run = nil end
	for i=1,#Souls do
		if Souls[i] then
			Destroy(Souls[i])
		end
	end
	Souls = {}
end

function MakeSouls()
	if not Character or not Root then return end
	Clean()
	SoulModel = Create("Model"){
		Name = Character.Name .. "'s Souls",
		Parent = workspace
	}
	local Seed = Random.new()
	local Original_Num = SoulCount.Value
	for i=1,Original_Num,1 do
		if Tool.Parent ~= Character or Original_Num ~= SoulCount.Value then return end
		local Soul = Clone(SoulBase)
		Souls[#Souls+1] = Soul
		local SoulFire = Clone(WaitForChild(script,"SoulFire"))
		
		local SoulColorBase = SoulColors[Seed:NextInteger(1,#SoulColors)]
		local SoulColorStart,SoulColorEnd = SoulColorBase.Start,SoulColorBase.End
		Soul.Color = SoulColorStart
		SoulFire.Color = ColorSequence.new(SoulColorStart,SoulColorEnd)
		local Light = Clone(SoulLight)
		Light.Color = Soul.Color
		Light.Parent = Soul
		SoulFire.Parent = Soul
		SoulFire.Enabled = true
		Soul.Parent = SoulModel
				
				
		coroutine.wrap(function()
			while Soul and Soul.Parent and Character and Root and Humanoid.Health > 0 do
				for i = 1, 60 do
					if Soul and Soul.Parent and Character and Root and Humanoid.Health > 0 then
						Soul.CFrame = (Root.CFrame + CFrame.Angles(0, (2 * i * math.pi / 60), 0) * Root.CFrame.LookVector * (math.sin(tick()*2)+5))
						Services.RunService.Heartbeat:Wait()
					end
				end	
			end		
		end)()
		local Max,Start = .75,tick()
		repeat
			Services.RunService.Heartbeat:Wait()
		until (tick()-Start)>= Max or not Character or not Root or Humanoid.Health <= 0 
		end
	end

function Equipped()
	Character = Tool.Parent
	Humanoid = FindFirstChildOfClass(Character,"Humanoid")
	Root = WaitForChild(Character,"HumanoidRootPart")
	
	Events[#Events+1] = Humanoid.Died:Connect(function()
		Clean()
	end)
	
	local Player = Services.Players:GetPlayerFromCharacter(Character)
	if Player then
		Events[#Events+1] = Player.CharacterRemoving:Connect(function()
			Clean()
		end)
	end
	
	
	SoulCount.Value = math.clamp(SoulCount.Value,0,7)
	MakeSouls()
end

function Unequipped()
	for i=1, #Events,1 do
		if Events[i] and Events[i].Connected then
			Events[i]:Disconnect()
		end
	end
	Events = {}
	Clean()
	Character = nil
	Root = nil
end

local Ignore = false
SoulCount.Changed:Connect(function(changed)
	if Ignore then return end
	Ignore = true
	SoulCount.Value = math.clamp(SoulCount.Value,0,7)
	--warn(SoulCount.Value)
	Ignore = false
	MakeSouls()
	
end)

Tool.Equipped:Connect(Equipped)
Tool.Unequipped:Connect(Unequipped)


