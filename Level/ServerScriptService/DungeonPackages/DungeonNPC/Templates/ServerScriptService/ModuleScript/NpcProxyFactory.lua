local CollectionService = game:GetService("CollectionService")

local NpcProxyFactory = {}

local function resolveRoot(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function partYExtents(part: BasePart): (number, number)
	local half = part.Size * 0.5
	local lowest = math.huge
	local highest = -math.huge
	for _, x in ipairs({ -half.X, half.X }) do
		for _, y in ipairs({ -half.Y, half.Y }) do
			for _, z in ipairs({ -half.Z, half.Z }) do
				local worldPoint = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
				lowest = math.min(lowest, worldPoint.Y)
				highest = math.max(highest, worldPoint.Y)
			end
		end
	end
	return lowest, highest
end

local function copyComputedGrounding(template: Model, model: Model)
	if model:GetAttribute("NpcGroundOffset") ~= nil then
		return
	end
	local templateRoot = resolveRoot(template)
	if not templateRoot then
		return
	end
	local lowest = math.huge
	local highest = -math.huge
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
			local partLowest, partHighest = partYExtents(descendant)
			lowest = math.min(lowest, partLowest)
			highest = math.max(highest, partHighest)
		end
	end
	if lowest == math.huge then
		return
	end
	local groundOffset = templateRoot.Position.Y - lowest
	model:SetAttribute("NpcGroundOffset", groundOffset)
	if model:GetAttribute("SpawnEmergeDepth") == nil then
		local height = math.max(1, highest - lowest)
		model:SetAttribute("SpawnEmergeDepth", math.clamp(math.max(5.75, groundOffset + 2.75, height * 0.65), 5.75, 16))
	end
end

function NpcProxyFactory.GetTemplateRootCFrame(template: Model, templatePivotCFrame: CFrame): CFrame
	local root = resolveRoot(template)
	if not root then
		return templatePivotCFrame
	end
	local rootLocalCFrame = template:GetPivot():ToObjectSpace(root.CFrame)
	return templatePivotCFrame * rootLocalCFrame
end

function NpcProxyFactory.Create(template: Model, templatePivotCFrame: CFrame, modelName: string?): Model
	assert(template and template:IsA("Model"), "[NpcProxyFactory] visual template is required")
	assert(typeof(templatePivotCFrame) == "CFrame", "[NpcProxyFactory] template pivot CFrame is required")

	local model = Instance.new("Model")
	model.Name = modelName or template.Name
	model:SetAttribute("NpcServerProxy", true)
	model:SetAttribute("NpcVisualType", template.Name)

	for attributeName, value in pairs(template:GetAttributes()) do
		-- Package/import metadata such as RBX_ReimportId is visible through
		-- GetAttributes(), but ordinary game scripts are not allowed to write it.
		if string.sub(attributeName, 1, 4) ~= "RBX_" then
			model:SetAttribute(attributeName, value)
		end
	end
	copyComputedGrounding(template, model)

	for _, tag in ipairs(CollectionService:GetTags(template)) do
		CollectionService:AddTag(model, tag)
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.Massless = true
	root.CFrame = NpcProxyFactory.GetTemplateRootCFrame(template, templatePivotCFrame)
	root.Parent = model
	model.PrimaryPart = root

	return model
end

return NpcProxyFactory
