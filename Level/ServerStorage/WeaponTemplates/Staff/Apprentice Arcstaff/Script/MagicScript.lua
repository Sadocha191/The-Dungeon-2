local tool = script.Parent
local core = tool.StaffCore
local handle = tool.Handle

local ChangeEvent = tool.ChangeAbility
local StoneEvent = tool.TurnStone
local ExplodeEvent = tool.ExplodeTarget
local BurnEvent = tool.Burn
local VaporizeEvent = tool.Vaporize
local WaveHit = tool.WaveHit
local ZapEvent = tool.StoneZap
local FireZapEvent = tool.FireZap
local HeatBeam = tool.HeatBeam
local WallEvent = tool.StoneWall
local WaveEvent = tool.EnergyWave
local Charge = tool.Charge
local ChargeEnd = tool.ChargeEnd

local chargeSpeed = 0.025

local looping = false
local debounce = false


function snap(v)
	if math.abs(v.x)>math.abs(v.z) then
		if v.x>0 then
			return Vector3.new(1,0,0)
		else
			return Vector3.new(-1,0,0)
		end
	else
		if v.z>0 then
			return Vector3.new(0,0,1)
		else
			return Vector3.new(0,0,-1)
		end
	end
end

local function CreateBeam(StartPos,EndPos,color)
	local projecttile = Instance.new("Part")
	game.Debris:AddItem(projecttile, 1)
	local distance = (StartPos -EndPos).Magnitude
	local offset = CFrame.new(0,0, -distance / 2)
	projecttile.Size = Vector3.new(1,1,distance)
	projecttile.Anchored = true
	projecttile.CanCollide = false
	projecttile.CFrame = CFrame.new(StartPos,EndPos) * offset
	projecttile.Transparency = 0
	projecttile.Material = Enum.Material.Neon
	projecttile.Color = Color3.fromRGB(255,255,255)
	projecttile.CanQuery = false
	projecttile.CanTouch = false
	projecttile.CastShadow = false
	projecttile.Color = color
	projecttile.Parent = workspace
	game.TweenService:Create(projecttile, TweenInfo.new(1), {Transparency = 1}):Play()
end

local function CreateMovingBeam(StartPos,EndPos,color,speed)
	local distance = (StartPos -EndPos).Magnitude
	local timeDistance = distance/speed
	
	local info = TweenInfo.new(timeDistance,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0)
	
	local projecttile = Instance.new("Part")
	--game.Debris:AddItem(projecttile, 3)
	local distance = (StartPos -EndPos).Magnitude
	local offset = CFrame.new(0,0, -distance / 2)
	projecttile.Size = Vector3.new(1,1,0)
	projecttile.Anchored = true
	projecttile.CanCollide = false
	projecttile.CFrame = CFrame.new(StartPos,EndPos)
	projecttile.Transparency = 0.2
	projecttile.Material = Enum.Material.Neon
	projecttile.CanQuery = false
	projecttile.CanTouch = false
	projecttile.CastShadow = false
	projecttile.Color = color
	projecttile.Parent = workspace
	game.TweenService:Create(projecttile, info, {CFrame = CFrame.new(StartPos,EndPos) * offset}):Play()
	game.TweenService:Create(projecttile, info, {Size = Vector3.new(1,1,distance)}):Play()
	task.wait(timeDistance)
	game.TweenService:Create(projecttile, info, {Position = CFrame.new(EndPos,StartPos).Position}):Play()
	game.TweenService:Create(projecttile, info, {Size = Vector3.new(1,1,0)}):Play()
	task.wait(timeDistance)
	projecttile:Destroy()
end

function placeBrick(cf, pos, color)
	local brick = Instance.new("Part")
	brick.Color = color
	brick.CFrame = cf * CFrame.new(pos + brick.Size / 2)
	brick.Material = Enum.Material.Slate
	brick.Parent = game.Workspace
	brick:MakeJoints()
	CreateBeam(core.Position,brick.Position,brick.Color)
	game.TweenService:Create(brick, TweenInfo.new(1), {Color = Color3.fromRGB(99, 95, 98)}):Play()
	return  brick, pos +  brick.Size
end	

local function PlaySound(music)
	local sound = core:FindFirstChild(music)
	if sound then
		local PlaySound = sound:Clone()
		PlaySound.Parent = core
		PlaySound.TimePosition = 0
		PlaySound:Play()
		game.Debris:AddItem(PlaySound, PlaySound.TimeLength*2)
	end
end

tool.SeverTranstition.OnServerEvent:Connect(function(plr, event)
	if tool:FindFirstChild(event) then
		tool:FindFirstChild(event):Fire()
	end
end)

ZapEvent.OnServerEvent:Connect(function(plr, pos)
	PlaySound("MagicalExit")


	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {tool.Parent}

	local RayCast = workspace:Raycast(core.Position, (pos - core.Position)*2, params)

	if RayCast then
		CreateBeam(core.Position, RayCast.Position, Color3.new(1, 1, 1))
		local part = RayCast.Instance
		local model = part:FindFirstAncestorOfClass("Model")
		if model then
		else	
			part:FindFirstAncestorOfClass("Tool")
		end
		if model then
			if tool.EnergyLevel.Value < 25 then
				tool.TurnStone:Fire(model)
				core.MovingAttachment.WorldCFrame = CFrame.new(RayCast.Position)
				core.MovingAttachment.ParticleEmitter:Emit(100)
			end
		end
		if tool.EnergyLevel.Value > 25 then
			tool.ExplodeTarget:Fire(RayCast.Position)
		end
	end

	--core.MovingAttachment.WorldCFrame = core.CFrame
end)

FireZapEvent.OnServerEvent:Connect(function(plr, pos)
	PlaySound("MagicalExit2")

	if tool.EnergyLevel.Value < 25 then
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {tool.Parent}

	local RayCast = workspace:Raycast(core.Position, (pos - core.Position)*2, params)

	if RayCast then
		CreateBeam(core.Position, RayCast.Position, Color3.new(1, 0.1, 0))
		local part = RayCast.Instance
			tool.Burn:Fire(part)
			core.MovingAttachment.WorldCFrame = CFrame.new(RayCast.Position)
			core.MovingAttachment.ParticleEmitter:Emit(100)
	end
	else
		HeatBeam:Fire(pos)
    end
	--core.MovingAttachment.WorldCFrame = core.CFrame
end)

WallEvent.OnServerEvent:Connect(function(plr, pos)
	local lookAt = snap( (pos - plr.Character.Head.Position).unit )
	local cf = CFrame.new(pos, pos + lookAt)
	
	local wallWidth = 1.5*tool.EnergyLevel.Value
	local wallHeight = 0.75*tool.EnergyLevel.Value
	
	local color = Color3.new(1,1,1)
	local bricks = {}

	assert(wallWidth>0)
	local y = 0
	while y < wallHeight do
		PlaySound("Sparkle2")
		local p
		local x = -wallWidth/2
		while x < wallWidth/2 do
			local brick
			brick, p = placeBrick(cf, Vector3.new(x, y, 0), color)
			x = p.x
			table.insert(bricks, brick)
			wait()
		end
		y = p.y
	end

	
end)

WaveEvent.OnServerEvent:Connect(function(plr, pos)
	PlaySound("Charge")
	local range = tool.EnergyLevel.Value*3
	
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {plr.Character}
	local Part = Instance.new("Part")
	game.Debris:AddItem(Part,1)
	Part.Position = core.Position
	Part.CanCollide = false
	Part.CanQuery = false
	Part.CanTouch = false
	Part.Anchored = true
	Part.CastShadow = false
	Part.Shape = Enum.PartType.Ball
	Part.Material = Enum.Material.ForceField
	Part.Color = Color3.new(1,1,10)
	Part.Size = Vector3.new(1,1,1)
	Part.Transparency = 0
	Part.Parent = workspace
	game.TweenService:Create(Part, TweenInfo.new(1), {Size = Vector3.new(range,range,range)}):Play()
	game.TweenService:Create(Part, TweenInfo.new(1), {Transparency = 1}):Play()
	core.Attachment.TeleportParticle:Emit(100)
	for _, part in workspace:GetPartBoundsInRadius(Part.Position,range/2, params) do
		WaveHit:Fire(part)
    end
end)


ChangeEvent.Event:Connect(function()
	if debounce == false then
		PlaySound("SparkleDeep")
		core.Attachment.ChangeParticle:Emit(1)
		if tool.Ability.Value == "StoneZap" then
			tool.Ability.Value = "FireZap"
		elseif tool.Ability.Value == "FireZap" then
			tool.Ability.Value = "EnergyWave"
		elseif tool.Ability.Value == "EnergyWave" then
			tool.Ability.Value = "StoneWall"	
		elseif tool.Ability.Value == "StoneWall" then
			tool.Ability.Value = "StoneZap"
		end
		debounce = true
		task.wait(1)
		debounce = false
	end
end)

ChargeEnd.Event:Connect(function()
	game.TweenService:Create(core.Attachment.BillboardGui.ImageLabel, TweenInfo.new(1), {Size = UDim2.new(0,0,0,0)}):Play()
	game.TweenService:Create(core.SparkleShimmer, TweenInfo.new(1), {PlaybackSpeed = 0}):Play()
	game.TweenService:Create(core, TweenInfo.new(1), {Color = Color3.fromRGB(128, 187, 219)}):Play()
	game.TweenService:Create(core.Attachment.BillboardGui, TweenInfo.new(1), {Brightness = 3}):Play()
	game.TweenService:Create(core.PointLight, TweenInfo.new(1), {Brightness = 0}):Play()
	game.TweenService:Create(core.PointLight, TweenInfo.new(1), {Range = 0}):Play()
	game.TweenService:Create(core.Attachment.BillboardGui.Speed, TweenInfo.new(1), {Value = 0}):Play()
	looping = false
	core.IdleScript.Enabled = false
end)

Charge.Event:Connect(function()
	core.SparkleShimmer.Playing = true
	core.SparkleShimmer.PlaybackSpeed = 0
	tool.EnergyLevel.Value = 0
	core.Attachment.BillboardGui.ImageLabel.Size = UDim2.new(0,0,0,0)
	core.Attachment.BillboardGui.Brightness = 3
	core.Attachment.BillboardGui.SpinningScript.Enabled = true
	core.Color = Color3.fromRGB(128, 187, 219)
	game.TweenService:Create(core.Attachment.BillboardGui.ImageLabel, TweenInfo.new(1), {Size = UDim2.new(1,0,1,0)}):Play()
	local colorTween = game.TweenService:Create(core, TweenInfo.new(12), {Color = Color3.fromRGB(255,255,255)})
	colorTween:Play()
	tool.EnergyNameScript.Enabled = true
	looping = true
	repeat
		
		if core.SparkleShimmer.PlaybackSpeed > 6 then
		else
			core.SparkleShimmer.PlaybackSpeed += 0.05
			core.Attachment.BillboardGui.Speed.Value += 0.1
			core.PointLight.Range += 0.1
		end
		core.Attachment.BillboardGui.Brightness += 0.1
		core.PointLight.Brightness += 0.1
		tool.EnergyLevel.Value += 0.1
		task.wait(chargeSpeed)
	until looping == false
	colorTween:Pause()
	tool.EnergyNameScript.Enabled = false
	tool.Name = "Magic-Staff"
end)

StoneEvent.Event:Connect(function(target)
    --local target = workspace:FindFirstChildOfClass("Part")

	
	local root = nil

	for _, object in target:GetDescendants() do
		if object:IsA("Part") or object:IsA("UnionOperation") or object:IsA("MeshPart") or object:IsA("WedgePart") or object:IsA("CornerWedgePart") or object:IsA("Seat") or object:IsA("VehicleSeat") then
			if root == nil then
				root = object
			end
			
		    object.Material = Enum.Material.Slate
		    if object:IsA("UnionOperation") then
			    object.UsePartColor = true
		    end
			game.TweenService:Create(object, TweenInfo.new(1), {Color = Color3.fromRGB(99, 95, 98)}):Play()
			object.CanCollide = true
			object:MakeJoints()
			task.wait(.1)
		end
		if object:IsA("PointLight") or object:IsA("SurfaceLight") or object:IsA("SpotLight") or object:IsA("Script") or object:IsA("ModuleScript") or object:IsA("LocalScript") or object:IsA("Trail") or object:IsA("BodyVelocity") or object:IsA("BodyForce") or object:IsA("BodyThrust") or object:IsA("Sound") or target:IsA("BodyGyro") or target:IsA("ParticleEmitter") or target:IsA("AngularVelocity") then
			object:Destroy()		
		end
		if object:IsA("Shirt") or object:IsA("Pants") then
			object:Destroy()
		end
		
	end
	local hum = target:FindFirstChildOfClass("Humanoid")
	
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		hum.PlatformStand = true
		hum.AutoRotate = false
	end
	
	
end)

ExplodeEvent.Event:Connect(function(pos)
	--local target = workspace:FindFirstChildOfClass("Model")
	local part = Instance.new("Part")
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Anchored = true
	part.Transparency = 1
	part.Position = pos
	part.Parent = workspace
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://18893204466"
	sound.PlayOnRemove = true
	sound.Volume = 5
	sound.Parent = part
	part:Destroy()
	
	local explosion = Instance.new("Explosion")
	explosion.Position = pos
	explosion.BlastPressure = tool.EnergyLevel.Value*100000
	explosion.BlastRadius = tool.EnergyLevel.Value/3
	explosion.Parent = workspace
	
end)

BurnEvent.Event:Connect(function(part)
	if part:IsA("UnionOperation") then
		part.UsePartColor = true
	end
	part.Material = Enum.Material.Slate
	part.Color = Color3.new(0,0,0)
	local fire = Instance.new("Fire")
	fire.Parent = part
	game.Debris:AddItem(fire, tool.EnergyLevel.Value)
	local sound = BurnEvent.Burning:Clone()
	sound.Parent = part
	sound.Playing = true
	game.Debris:AddItem(sound, tool.EnergyLevel.Value)
	local burnScript = BurnEvent.BurnScript:Clone()
	burnScript.Parent = part
	burnScript.Enabled = true
	game.Debris:AddItem(burnScript, tool.EnergyLevel.Value)
end)

WaveHit.Event:Connect(function(part)
	local model = part:FindFirstAncestorOfClass("Model")
	if model then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:UnequipTools()
		end
	end

	local strength = tool.EnergyLevel.Value*50
	
	local LookAt = CFrame.lookAt(core.Position, part.Position)

if part.Anchored == false then
	part.AssemblyLinearVelocity = LookAt.LookVector * strength
end
		
	
end)

HeatBeam.Event:Connect(function(pos)
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {tool.Parent}

	local RayCast = workspace:Raycast(core.Position, (pos - core.Position)*2, params)

	if RayCast then
		PlaySound("Sparkle4")
		CreateMovingBeam(core.Position, RayCast.Position, Color3.new(1, 0.2, 0), 250)
		local range = tool.EnergyLevel.Value

		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {tool.Parent}
		
		local Part = Instance.new("Part")
		game.Debris:AddItem(Part,1)
		Part.Position = RayCast.Position
		Part.CanCollide = false
		Part.CanQuery = false
		Part.CanTouch = false
		Part.Anchored = true
		Part.CastShadow = false
		Part.Shape = Enum.PartType.Ball
		Part.Material = Enum.Material.Neon
		Part.Color = Color3.new(1,.2,0)
		Part.Size = Vector3.new(1,1,1)
		Part.Transparency = 0
		Part.Parent = workspace
		game.TweenService:Create(Part, TweenInfo.new(1), {Size = Vector3.new(range,range,range)}):Play()
		game.TweenService:Create(Part, TweenInfo.new(1), {Transparency = 1}):Play()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://2699594712"
		sound.PlayOnRemove = true
		sound.Volume = 5
		sound.Parent = Part
		sound:Destroy()
		
		for _, part in workspace:GetPartBoundsInRadius(RayCast.Position,range, params) do
			VaporizeEvent:Fire(part, range*15)
		end
		
	end
end)

VaporizeEvent.Event:Connect(function(part, limit)
	--local part = workspace:FindFirstChildOfClass("Part")
	if part.Mass < limit then
		
		part.Parent = workspace
		part.CanCollide = true
		part.Transparency = 0
		if part:IsA("UnionOperation") then
			part.UsePartColor = true
		end
		local particle = VaporizeEvent.VaporizeParticle:Clone()
		particle.Parent = part
		particle.Enabled = true
	    game.TweenService:Create(part, TweenInfo.new(1), {Color = Color3.new(0,0,0)}):Play()
		local sound = VaporizeEvent.Vaporize:Clone()
		sound.Parent = part
		sound:Play()
		game.Debris:AddItem(part, sound.TimeLength)
		game.TweenService:Create(part, TweenInfo.new(sound.TimeLength), {Size = Vector3.new(0,0,0)}):Play()
		task.wait(2)
		part:BreakJoints()
		particle.Enabled = false
		part.Anchored = false
	end
end)

tool.EnergyLevel.Changed:Connect(function()
	if tool.EnergyLevel.Value > 100 then
		core.IdleScript.Enabled = true
	else
		core.IdleScript.Enabled = false
	end
end)