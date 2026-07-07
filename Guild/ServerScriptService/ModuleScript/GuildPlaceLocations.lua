local GuildPlaceLocations = {}

local LOCATION_STATUS = "Coming soon"

local GUILD_LOCATION_DEFINITIONS = {
	{
		Id = "Dojo",
		Name = "Dojo",
		Description = "Przyszłe ulepszenia bojowe gildii.",
		Hint = "zachodni dziedziniec",
		Position = Vector3.new(-70, 0, 0),
		BaseSize = Vector3.new(24, 1, 18),
		BuildingSize = Vector3.new(15, 8, 11),
		Color = Color3.fromRGB(142, 64, 51),
		AccentColor = Color3.fromRGB(230, 204, 152),
		Accents = {
			{ Name = "TrainingMat", Offset = Vector3.new(0, 1.08, 0), Size = Vector3.new(10, 0.25, 7), Color = Color3.fromRGB(96, 45, 38), Material = Enum.Material.Fabric },
		},
	},
	{
		Id = "Treasury",
		Name = "Skarbiec",
		Description = "Przyszłe zarządzanie zasobami gildii.",
		Hint = "wschodnie skrzydło zamku",
		Position = Vector3.new(70, 0, 0),
		BaseSize = Vector3.new(24, 1, 18),
		BuildingSize = Vector3.new(16, 9, 12),
		Color = Color3.fromRGB(85, 91, 105),
		AccentColor = Color3.fromRGB(218, 172, 75),
		Accents = {
			{ Name = "VaultDoor", Offset = Vector3.new(0, 4.2, -5.9), Size = Vector3.new(6, 6, 0.6), Color = Color3.fromRGB(218, 172, 75), Material = Enum.Material.Metal },
		},
	},
	{
		Id = "HallOfFame",
		Name = "Sala chwały",
		Description = "Przyszłe rankingi i contribution członków.",
		Hint = "północna aleja",
		Position = Vector3.new(0, 0, -70),
		BaseSize = Vector3.new(26, 1, 18),
		BuildingSize = Vector3.new(18, 9, 11),
		Color = Color3.fromRGB(102, 88, 123),
		AccentColor = Color3.fromRGB(228, 215, 164),
		Accents = {
			{ Name = "HonorPlinth", Offset = Vector3.new(0, 2.2, 0), Size = Vector3.new(5, 3, 5), Color = Color3.fromRGB(228, 215, 164), Material = Enum.Material.Marble },
		},
	},
	{
		Id = "Farms",
		Name = "Farmy",
		Description = "Przyszła produkcja zasobów gildii.",
		Hint = "południowo-zachodnie pola",
		Position = Vector3.new(-55, 0, 55),
		BaseSize = Vector3.new(28, 1, 22),
		BuildingSize = Vector3.new(12, 6, 9),
		Color = Color3.fromRGB(92, 124, 72),
		AccentColor = Color3.fromRGB(152, 108, 62),
		Accents = {
			{ Name = "CropRowA", Offset = Vector3.new(-6, 1.12, 2), Size = Vector3.new(4, 0.35, 12), Color = Color3.fromRGB(64, 128, 57), Material = Enum.Material.Grass },
			{ Name = "CropRowB", Offset = Vector3.new(0, 1.12, 2), Size = Vector3.new(4, 0.35, 12), Color = Color3.fromRGB(73, 145, 60), Material = Enum.Material.Grass },
			{ Name = "CropRowC", Offset = Vector3.new(6, 1.12, 2), Size = Vector3.new(4, 0.35, 12), Color = Color3.fromRGB(64, 128, 57), Material = Enum.Material.Grass },
		},
	},
	{
		Id = "Mine",
		Name = "Kopalnia",
		Description = "Przyszła produkcja materiałów gildii.",
		Hint = "południowo-wschodnie skały",
		Position = Vector3.new(55, 0, 55),
		BaseSize = Vector3.new(26, 1, 20),
		BuildingSize = Vector3.new(14, 8, 10),
		Color = Color3.fromRGB(82, 78, 72),
		AccentColor = Color3.fromRGB(144, 126, 92),
		Accents = {
			{ Name = "OreRockA", Offset = Vector3.new(-7, 2.2, 4), Size = Vector3.new(5, 4, 5), Color = Color3.fromRGB(106, 101, 94), Material = Enum.Material.Rock },
			{ Name = "OreRockB", Offset = Vector3.new(7, 1.8, 3), Size = Vector3.new(4, 3, 4), Color = Color3.fromRGB(125, 112, 88), Material = Enum.Material.Slate },
		},
	},
	{
		Id = "Fishing",
		Name = "Łowiska",
		Description = "Przyszła produkcja specjalnych zasobów.",
		Hint = "północno-zachodni staw",
		Position = Vector3.new(-55, 0, -55),
		BaseSize = Vector3.new(28, 1, 22),
		BuildingSize = Vector3.new(11, 5, 8),
		Color = Color3.fromRGB(63, 105, 126),
		AccentColor = Color3.fromRGB(151, 112, 71),
		Accents = {
			{ Name = "FishingPond", Offset = Vector3.new(4, 1.06, 2), Size = Vector3.new(13, 0.2, 10), Color = Color3.fromRGB(58, 131, 159), Material = Enum.Material.SmoothPlastic, Transparency = 0.15 },
			{ Name = "Dock", Offset = Vector3.new(-6, 1.25, 2), Size = Vector3.new(5, 0.5, 12), Color = Color3.fromRGB(130, 91, 55), Material = Enum.Material.WoodPlanks },
		},
	},
	{
		Id = "BossRaid",
		Name = "Boss Raid",
		Description = "Przyszłe raidy gildyjne.",
		Hint = "północno-wschodni plac bojowy",
		Position = Vector3.new(55, 0, -55),
		BaseSize = Vector3.new(28, 1, 22),
		BuildingSize = Vector3.new(16, 8, 10),
		Color = Color3.fromRGB(102, 49, 70),
		AccentColor = Color3.fromRGB(197, 74, 89),
		Accents = {
			{ Name = "RaidPortal", Offset = Vector3.new(0, 4, 0), Size = Vector3.new(7, 7, 1), Color = Color3.fromRGB(197, 74, 89), Material = Enum.Material.Neon },
		},
	},
}

local GUILD_LOCATION_BY_ID = {}
for _, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
	GUILD_LOCATION_BY_ID[definition.Id] = definition
end

function GuildPlaceLocations.GetDefinitions()
	return GUILD_LOCATION_DEFINITIONS
end

function GuildPlaceLocations.GetDefinition(locationId)
	return GUILD_LOCATION_BY_ID[locationId]
end

function GuildPlaceLocations.GetStatus(definition)
	return definition.Id == "Treasury" and "Open" or LOCATION_STATUS
end

function GuildPlaceLocations.BuildState()
	local locations = {}
	for index, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
		locations[index] = {
			Id = definition.Id,
			Name = definition.Name,
			Description = definition.Description,
			Status = GuildPlaceLocations.GetStatus(definition),
			Hint = definition.Hint,
		}
	end
	return locations
end

local function getFlatDirectionToCenter(position)
	local direction = Vector3.new(-position.X, 0, -position.Z)
	if direction.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return direction.Unit
end

local function ensurePart(parent, name, props)
	local part = parent:FindFirstChild(name)
	if part and not part:IsA("BasePart") then
		part:Destroy()
		part = nil
	end
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

local function ensureLocationBillboard(sign, definition)
	local billboard = sign:FindFirstChild("LocationBillboard")
	if billboard and not billboard:IsA("BillboardGui") then
		billboard:Destroy()
		billboard = nil
	end
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "LocationBillboard"
		billboard.Parent = sign
	end
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Size = UDim2.fromOffset(230, 72)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)

	local label = billboard:FindFirstChild("NameLabel")
	if label and not label:IsA("TextLabel") then
		label:Destroy()
		label = nil
	end
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "NameLabel"
		label.Parent = billboard
	end
	label.BackgroundColor3 = Color3.fromRGB(18, 20, 23)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = definition.Name
	label.TextColor3 = Color3.fromRGB(255, 239, 201)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.45
	label.TextWrapped = true
end

local function ensureLocationPrompt(model, entrance, definition)
	local prompt = nil
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			if not prompt and descendant.Name == "GuildLocationPrompt" then
				prompt = descendant
			else
				descendant:Destroy()
			end
		end
	end
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GuildLocationPrompt"
	end
	prompt.ActionText = "Open"
	prompt.ObjectText = definition.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("GuildLocationId", definition.Id)
	prompt.Parent = entrance
	return prompt
end

function GuildPlaceLocations.EnsureWorkspace(workspaceService)
	local folder = workspaceService:FindFirstChild("GuildLocations")
	if folder and not folder:IsA("Folder") then
		folder:Destroy()
		folder = nil
	end
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GuildLocations"
		folder.Parent = workspaceService
	end

	for _, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
		local model = folder:FindFirstChild(definition.Id)
		if model and not model:IsA("Model") then
			model:Destroy()
			model = nil
		end
		if not model then
			model = Instance.new("Model")
			model.Name = definition.Id
			model.Parent = folder
		end
		model:SetAttribute("GuildLocationId", definition.Id)
		model:SetAttribute("DisplayName", definition.Name)
		model:SetAttribute("Status", GuildPlaceLocations.GetStatus(definition))

		local center = definition.Position
		local front = getFlatDirectionToCenter(center)
		local baseSize = definition.BaseSize
		local buildingSize = definition.BuildingSize
		local frontDistance = math.max(baseSize.X, baseSize.Z) * 0.5 - 2

		ensurePart(model, "Ground", {
			Anchored = true,
			BottomSurface = Enum.SurfaceType.Smooth,
			BrickColor = BrickColor.new("Dark stone grey"),
			CanCollide = true,
			Color = Color3.fromRGB(47, 54, 48),
			Material = Enum.Material.Cobblestone,
			Position = center + Vector3.new(0, baseSize.Y * 0.5, 0),
			Size = baseSize,
			TopSurface = Enum.SurfaceType.Smooth,
		})
		ensurePart(model, "Building", {
			Anchored = true,
			BottomSurface = Enum.SurfaceType.Smooth,
			CanCollide = true,
			Color = definition.Color,
			Material = Enum.Material.WoodPlanks,
			Position = center + Vector3.new(0, baseSize.Y + buildingSize.Y * 0.5, 0),
			Size = buildingSize,
			TopSurface = Enum.SurfaceType.Smooth,
		})
		local entrance = ensurePart(model, "Entrance", {
			Anchored = true,
			BottomSurface = Enum.SurfaceType.Smooth,
			CanCollide = false,
			Color = Color3.fromRGB(28, 24, 22),
			Material = Enum.Material.Wood,
			Position = center + front * frontDistance + Vector3.new(0, baseSize.Y + 3, 0),
			Size = Vector3.new(6, 6, 1.25),
			TopSurface = Enum.SurfaceType.Smooth,
			Transparency = 0.08,
		})
		local sign = ensurePart(model, "Sign", {
			Anchored = true,
			BottomSurface = Enum.SurfaceType.Smooth,
			CanCollide = false,
			Color = definition.AccentColor,
			Material = Enum.Material.Wood,
			Position = center + front * (frontDistance + 1.4) + Vector3.new(0, baseSize.Y + 7.3, 0),
			Size = Vector3.new(10, 2.25, 0.5),
			TopSurface = Enum.SurfaceType.Smooth,
		})
		ensureLocationBillboard(sign, definition)

		for _, accent in ipairs(definition.Accents or {}) do
			ensurePart(model, accent.Name, {
				Anchored = true,
				BottomSurface = Enum.SurfaceType.Smooth,
				CanCollide = accent.CanCollide ~= false,
				Color = accent.Color or definition.AccentColor,
				Material = accent.Material or Enum.Material.SmoothPlastic,
				Position = center + accent.Offset,
				Size = accent.Size,
				TopSurface = Enum.SurfaceType.Smooth,
				Transparency = accent.Transparency or 0,
			})
		end

		model.PrimaryPart = entrance
	end

	return folder
end

function GuildPlaceLocations.BindPrompts(workspaceService, onTriggered)
	assert(typeof(onTriggered) == "function", "[GuildPlaceLocations] onTriggered callback is required")

	local folder = GuildPlaceLocations.EnsureWorkspace(workspaceService)
	for _, definition in ipairs(GUILD_LOCATION_DEFINITIONS) do
		local model = folder:FindFirstChild(definition.Id)
		local entrance = model and model:FindFirstChild("Entrance")
		if model and entrance and entrance:IsA("BasePart") then
			local prompt = ensureLocationPrompt(model, entrance, definition)
			prompt.Triggered:Connect(function(player)
				onTriggered(player, definition.Id)
			end)
		else
			warn("[GuildPlace] Failed to bind guild location prompt:", definition.Id)
		end
	end

	return folder
end

return GuildPlaceLocations
