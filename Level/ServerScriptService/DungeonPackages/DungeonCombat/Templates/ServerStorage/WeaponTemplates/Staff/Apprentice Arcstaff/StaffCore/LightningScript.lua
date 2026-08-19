local part = script.Parent

local Attachments = {}

local Beams = {}

local Sounds = {}

table.insert(Attachments, part.MovingAttachment1)
table.insert(Attachments, part.MovingAttachment2)
table.insert(Attachments, part.MovingAttachment3)
table.insert(Attachments, part.MovingAttachment4)

table.insert(Beams, part.Beam1)
table.insert(Beams, part.Beam2)
table.insert(Beams, part.Beam3)
table.insert(Beams, part.Beam4)

table.insert(Sounds, part.Burst)
table.insert(Sounds, part.Flash)
table.insert(Sounds, part.Zap)

part.FireLightning.Event:Connect(function(position, TaggedPart)
	--local TaggedPart = workspace:FindFirstChildOfClass("Part")
	local model = TaggedPart:FindFirstAncestorOfClass("Model")
	if model then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:TakeDamage(10)
			local effectPart = Instance.new("Part")
			effectPart.CanCollide = false
			effectPart.CanTouch = false
			effectPart.CanQuery = false
			effectPart.Anchored = true
			effectPart.Size = TaggedPart.Size+Vector3.new(.5,.5,.5)
			effectPart.Transparency = 0.5
			effectPart.CFrame = TaggedPart.CFrame
			effectPart.Material = Enum.Material.Neon
			game.TweenService:Create(effectPart, TweenInfo.new(1), {Transparency = 1}):Play()
			game.Debris:AddItem(effectPart, 1)
			effectPart.Parent = workspace
		end
	end
	TaggedPart:BreakJoints()
	
	local randomAttachment = Attachments[math.random(1, #Attachments)]
	local randomBeam = Beams[math.random(1, #Beams)]
	local randomSound = Sounds[math.random(1, #Sounds)]
	randomSound:Play()
	randomBeam.TextureLength = math.random(1, 20)/10
	randomAttachment.WorldPosition = position
	task.wait(.2)
	randomAttachment.WorldPosition = part.Position
end)

