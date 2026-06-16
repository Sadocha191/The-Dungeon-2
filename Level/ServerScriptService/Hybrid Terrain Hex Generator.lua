-- Smooth Dune Terrain + Hex Border Generator Plugin
-- Save as:
-- %LOCALAPPDATA%/Roblox/Plugins/SmoothDuneTerrainHexBorder.plugin.lua
-- Restart Roblox Studio after saving.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local PLUGIN_NAME = "Smooth Dune Terrain + Hex Border"
local GENERATED_FOLDER_NAME = "GeneratedSmoothDuneMap"
local HEX_BORDER_FOLDER_NAME = "HexBorder"
local COLLISION_FOLDER_NAME = "InvisibleCollision"
local TERRAIN_RESOLUTION = 4

local toolbar = plugin:CreateToolbar("Terrain Tools")
local toggleButton = toolbar:CreateButton(
	"Smooth Dunes + Border",
	"Generate smooth terrain with hex border, invisible walls and height limit",
	"rbxassetid://4458901886"
)
toggleButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Left,
	false,
	false,
	420,
	720,
	340,
	460
)

local widget = plugin:CreateDockWidgetPluginGui("SmoothDuneTerrainHexBorder", widgetInfo)
widget.Title = PLUGIN_NAME

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local selectedHexModel = nil
local isGenerating = false
local largeMapConfirm = false

local function make(className, props, parent)
	local inst = Instance.new(className)

	for key, value in pairs(props or {}) do
		inst[key] = value
	end

	inst.Parent = parent
	return inst
end

local root = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(32, 32, 36),
	BorderSizePixel = 0,
}, widget)

make("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
}, root)

make("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, root)

make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Text = "Smooth Dunes + Hex Border",
	TextColor3 = Color3.fromRGB(245, 245, 245),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1,
}, root)

local statusLabel = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 58),
	BackgroundColor3 = Color3.fromRGB(42, 42, 48),
	BorderSizePixel = 0,
	Text = "Ready. Select hex model, click Use Selected Hex Model, then Generate.",
	TextColor3 = Color3.fromRGB(220, 220, 220),
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Center,
	LayoutOrder = 2,
}, root)

make("UIPadding", {
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
}, statusLabel)

local scroll = make("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -100),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 8,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	LayoutOrder = 3,
}, root)

make("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 7),
}, scroll)

local order = 0

local function setStatus(text)
	statusLabel.Text = tostring(text)
end

local function addSeparator(text)
	order += 1

	return make("TextLabel", {
		Size = UDim2.new(1, -8, 0, 24),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.fromRGB(180, 180, 190),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, scroll)
end

local function addButton(text, height, color)
	order += 1

	return make("TextButton", {
		Size = UDim2.new(1, -8, 0, height or 34),
		BackgroundColor3 = color or Color3.fromRGB(74, 88, 120),
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		LayoutOrder = order,
	}, scroll)
end

local function normalizeChoice(choice)
	if typeof(choice) == "table" then
		return choice
	end

	return {
		value = choice,
		label = tostring(choice),
	}
end

local function addChoiceControl(labelText, choices, defaultIndex)
	order += 1

	local normalizedChoices = {}

	for _, choice in ipairs(choices) do
		table.insert(normalizedChoices, normalizeChoice(choice))
	end

	local index = math.clamp(defaultIndex or 1, 1, #normalizedChoices)

	local row = make("Frame", {
		Size = UDim2.new(1, -8, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, scroll)

	make("TextLabel", {
		Size = UDim2.new(0.43, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = labelText,
		TextColor3 = Color3.fromRGB(230, 230, 230),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	local previousButton = make("TextButton", {
		Size = UDim2.new(0, 30, 1, 0),
		Position = UDim2.new(0.43, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(58, 58, 66),
		BorderSizePixel = 0,
		Text = "<",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, row)

	local valueButton = make("TextButton", {
		Size = UDim2.new(0.57, -66, 1, 0),
		Position = UDim2.new(0.43, 34, 0, 0),
		BackgroundColor3 = Color3.fromRGB(52, 52, 60),
		BorderSizePixel = 0,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextWrapped = true,
	}, row)

	local nextButton = make("TextButton", {
		Size = UDim2.new(0, 30, 1, 0),
		Position = UDim2.new(1, -30, 0, 0),
		BackgroundColor3 = Color3.fromRGB(58, 58, 66),
		BorderSizePixel = 0,
		Text = ">",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
	}, row)

	local control = {}

	function control.update()
		valueButton.Text = normalizedChoices[index].label or tostring(normalizedChoices[index].value)
	end

	function control.get()
		return normalizedChoices[index].value
	end

	function control.setValue(value)
		for i, choice in ipairs(normalizedChoices) do
			if tostring(choice.value) == tostring(value) then
				index = i
				control.update()
				return
			end
		end
	end

	function control.next()
		index += 1

		if index > #normalizedChoices then
			index = 1
		end

		control.update()
	end

	function control.previous()
		index -= 1

		if index < 1 then
			index = #normalizedChoices
		end

		control.update()
	end

	previousButton.MouseButton1Click:Connect(control.previous)
	nextButton.MouseButton1Click:Connect(control.next)
	valueButton.MouseButton1Click:Connect(control.next)

	control.update()

	return control
end

local function getMaterial(name)
	name = tostring(name or "Sand")

	for _, item in ipairs(Enum.Material:GetEnumItems()) do
		if string.lower(item.Name) == string.lower(name) then
			return item
		end
	end

	return Enum.Material.Sand
end

addSeparator("Map")

local mapXChoice = addChoiceControl("Map Size X", {256, 384, 512, 768, 1024, 1536, 2048}, 3)
local mapZChoice = addChoiceControl("Map Size Z", {256, 384, 512, 768, 1024, 1536, 2048}, 3)
local baseYChoice = addChoiceControl("Base Y", {-40, -20, 0, 20, 50, 100}, 3)

local materialChoice = addChoiceControl("Material", {
	"Sand",
	"Ground",
	"Grass",
	"Mud",
	"Rock",
	"Snow",
}, 1)

local clearTerrainChoice = addChoiceControl("Clear Terrain Too", {
	{ value = false, label = "No" },
	{ value = true, label = "Yes" },
}, 1)

addSeparator("Dune Shape")

local maxHeightChoice = addChoiceControl("Max Height", {15, 25, 35, 50, 65, 85, 120}, 3)

local heightMultiplierChoice = addChoiceControl("Height Multiplier", {
	{ value = 0.35, label = "Very Low" },
	{ value = 0.5, label = "Low" },
	{ value = 0.6, label = "Normal" },
	{ value = 0.75, label = "High" },
	{ value = 1, label = "Full" },
}, 3)

local smoothingChoice = addChoiceControl("Smoothing", {
	{ value = 0, label = "Off" },
	{ value = 16, label = "Low" },
	{ value = 24, label = "Medium" },
	{ value = 36, label = "High" },
	{ value = 48, label = "Very High" },
	{ value = 64, label = "Ultra Smooth" },
}, 3)

local stretchXChoice = addChoiceControl("Stretch X", {
	{ value = 0.75, label = "0.75" },
	{ value = 1, label = "1.0" },
	{ value = 1.25, label = "1.25" },
	{ value = 1.5, label = "1.5" },
	{ value = 2, label = "2.0" },
}, 2)

local stretchZChoice = addChoiceControl("Stretch Z", {
	{ value = 1, label = "1.0" },
	{ value = 1.5, label = "1.5" },
	{ value = 2, label = "2.0" },
	{ value = 2.5, label = "2.5" },
	{ value = 3, label = "3.0" },
}, 4)

addSeparator("Noise")

local seedChoice = addChoiceControl("Seed", {
	{ value = 12345, label = "Seed 12345" },
	{ value = 777, label = "Seed 777" },
	{ value = 2026, label = "Seed 2026" },
	{ value = 9999, label = "Seed 9999" },
	{ value = 54321, label = "Seed 54321" },
	{ value = "random", label = "Random Each Generate" },
}, 1)

local noiseScaleChoice = addChoiceControl("Noise Scale", {
	{ value = 180, label = "Small" },
	{ value = 240, label = "Medium Small" },
	{ value = 300, label = "Dunes" },
	{ value = 360, label = "Large" },
	{ value = 420, label = "Very Large" },
	{ value = 520, label = "Huge" },
}, 3)

local octavesChoice = addChoiceControl("Octaves", {
	{ value = 1, label = "Very Smooth" },
	{ value = 2, label = "Smooth" },
	{ value = 3, label = "Normal" },
	{ value = 4, label = "More Detail" },
}, 3)

local persistenceChoice = addChoiceControl("Persistence", {
	{ value = 0.3, label = "Soft" },
	{ value = 0.35, label = "Soft+" },
	{ value = 0.4, label = "Dunes" },
	{ value = 0.45, label = "Detail" },
	{ value = 0.5, label = "More Detail" },
}, 3)

local lacunarityChoice = addChoiceControl("Lacunarity", {
	{ value = 1.4, label = "Soft" },
	{ value = 1.6, label = "Smooth" },
	{ value = 1.8, label = "Dunes" },
	{ value = 2.0, label = "Detail" },
	{ value = 2.2, label = "More Detail" },
}, 3)

addSeparator("Hex Border")

local useSelectedHexButton = addButton("Use Selected Hex Model", 36, Color3.fromRGB(74, 88, 120))

local borderEnabledChoice = addChoiceControl("Border Enabled", {
	{ value = true, label = "Yes" },
	{ value = false, label = "No" },
}, 1)

local detailRingsChoice = addChoiceControl("Inner Detail Rings", {
	{ value = 0, label = "Off" },
	{ value = 1, label = "1 Ring" },
	{ value = 2, label = "2 Rings" },
	{ value = 3, label = "3 Rings" },
}, 3)

local detailHexRadiusChoice = addChoiceControl("Small Hex Size", {
	{ value = 6, label = "Tiny" },
	{ value = 8, label = "Small" },
	{ value = 10, label = "Medium" },
	{ value = 12, label = "Large" },
}, 2)

local detailHexHeightChoice = addChoiceControl("Small Hex Height", {
	{ value = 4, label = "Low" },
	{ value = 8, label = "Medium" },
	{ value = 12, label = "High" },
	{ value = 18, label = "Tall" },
}, 2)

local wallRingsChoice = addChoiceControl("Tall Border Rings", {
	{ value = 1, label = "1 Ring" },
	{ value = 2, label = "2 Rings" },
	{ value = 3, label = "3 Rings" },
	{ value = 4, label = "4 Rings" },
}, 3)

local wallHexRadiusChoice = addChoiceControl("Tall Hex Size", {
	{ value = 14, label = "Small" },
	{ value = 18, label = "Medium" },
	{ value = 22, label = "Large" },
	{ value = 28, label = "Huge" },
}, 2)

local wallHeightChoice = addChoiceControl("Tall Border Height", {
	{ value = 80, label = "80" },
	{ value = 120, label = "120" },
	{ value = 160, label = "160" },
	{ value = 220, label = "220" },
	{ value = 300, label = "300" },
}, 3)

local wallRoughnessChoice = addChoiceControl("Border Roughness", {
	{ value = 0, label = "Flat" },
	{ value = 8, label = "Low" },
	{ value = 18, label = "Medium" },
	{ value = 32, label = "High" },
	{ value = 48, label = "Very High" },
}, 3)

addSeparator("Invisible Collision")

local invisibleWallsChoice = addChoiceControl("Invisible Walls", {
	{ value = true, label = "Yes" },
	{ value = false, label = "No" },
}, 1)

local invisibleWallHeightChoice = addChoiceControl("Wall Height", {
	{ value = 120, label = "120" },
	{ value = 180, label = "180" },
	{ value = 240, label = "240" },
	{ value = 320, label = "320" },
	{ value = 500, label = "500" },
}, 3)

local heightLimitChoice = addChoiceControl("Height Limit", {
	{ value = 0, label = "Off" },
	{ value = 100, label = "100" },
	{ value = 140, label = "140" },
	{ value = 180, label = "180" },
	{ value = 240, label = "240" },
	{ value = 320, label = "320" },
}, 4)

addSeparator("Presets")

local presetSoftButton = addButton("Preset: Soft Dunes", 34, Color3.fromRGB(90, 92, 120))
local presetFlatButton = addButton("Preset: Low Flat Dunes", 34, Color3.fromRGB(90, 92, 120))
local presetBigButton = addButton("Preset: Big Dunes", 34, Color3.fromRGB(90, 92, 120))
local presetBorderButton = addButton("Preset: Strong Hex Border", 34, Color3.fromRGB(90, 92, 120))

addSeparator("Actions")

local generateButton = addButton("Generate", 42, Color3.fromRGB(54, 120, 78))
local clearButton = addButton("Clear Generated Map", 36, Color3.fromRGB(126, 64, 64))

useSelectedHexButton.MouseButton1Click:Connect(function()
	local selected = Selection:Get()

	if #selected == 0 then
		setStatus("Select a hex Model or Part first.")
		return
	end

	local inst = selected[1]

	if inst:IsA("Model") or inst:IsA("BasePart") then
		selectedHexModel = inst
		setStatus("Selected hex model: " .. inst:GetFullName())
	else
		setStatus("Selected object must be a Model or BasePart.")
	end
end)

local function applyPreset(name)
	if name == "soft" then
		maxHeightChoice.setValue(35)
		heightMultiplierChoice.setValue(0.6)
		noiseScaleChoice.setValue(300)
		octavesChoice.setValue(3)
		persistenceChoice.setValue(0.4)
		lacunarityChoice.setValue(1.8)
		stretchXChoice.setValue(1)
		stretchZChoice.setValue(2.5)
		smoothingChoice.setValue(24)
		materialChoice.setValue("Sand")
		setStatus("Preset applied: Soft Dunes.")
	elseif name == "flat" then
		maxHeightChoice.setValue(25)
		heightMultiplierChoice.setValue(0.5)
		noiseScaleChoice.setValue(360)
		octavesChoice.setValue(2)
		persistenceChoice.setValue(0.35)
		lacunarityChoice.setValue(1.6)
		stretchXChoice.setValue(1)
		stretchZChoice.setValue(3)
		smoothingChoice.setValue(36)
		materialChoice.setValue("Sand")
		setStatus("Preset applied: Low Flat Dunes.")
	elseif name == "big" then
		maxHeightChoice.setValue(65)
		heightMultiplierChoice.setValue(0.75)
		noiseScaleChoice.setValue(420)
		octavesChoice.setValue(3)
		persistenceChoice.setValue(0.4)
		lacunarityChoice.setValue(1.8)
		stretchXChoice.setValue(1)
		stretchZChoice.setValue(2)
		smoothingChoice.setValue(36)
		materialChoice.setValue("Sand")
		setStatus("Preset applied: Big Dunes.")
	elseif name == "border" then
		borderEnabledChoice.setValue(true)
		detailRingsChoice.setValue(2)
		detailHexRadiusChoice.setValue(8)
		detailHexHeightChoice.setValue(8)
		wallRingsChoice.setValue(3)
		wallHexRadiusChoice.setValue(18)
		wallHeightChoice.setValue(160)
		wallRoughnessChoice.setValue(18)
		invisibleWallsChoice.setValue(true)
		invisibleWallHeightChoice.setValue(240)
		heightLimitChoice.setValue(180)
		setStatus("Preset applied: Strong Hex Border.")
	end
end

presetSoftButton.MouseButton1Click:Connect(function()
	applyPreset("soft")
end)

presetFlatButton.MouseButton1Click:Connect(function()
	applyPreset("flat")
end)

presetBigButton.MouseButton1Click:Connect(function()
	applyPreset("big")
end)

presetBorderButton.MouseButton1Click:Connect(function()
	applyPreset("border")
end)

local function getOrCreateGeneratedFolder()
	local folder = Workspace:FindFirstChild(GENERATED_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = GENERATED_FOLDER_NAME
		folder.Parent = Workspace
	end

	return folder
end

local function getOrCreateChildFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end

	return folder
end

local function smoothStep(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function random01(x, z, seed)
	local n = math.noise(
		x * 0.073 + seed * 0.011,
		z * 0.073 + seed * 0.019,
		seed * 0.003
	)

	return math.clamp((n + 1) * 0.5, 0, 1)
end

local function fractalNoise(x, z, settings)
	local amplitude = 1
	local frequency = 1
	local total = 0
	local maxValue = 0

	local scaleX = math.max(1, settings.noiseScale * settings.stretchX)
	local scaleZ = math.max(1, settings.noiseScale * settings.stretchZ)

	for _ = 1, settings.octaves do
		local nx = (x / scaleX) * frequency + settings.seed * 0.013
		local nz = (z / scaleZ) * frequency + settings.seed * 0.017

		local n = math.noise(nx, nz, settings.seed * 0.001)

		total += n * amplitude
		maxValue += amplitude

		amplitude *= settings.persistence
		frequency *= settings.lacunarity
	end

	if maxValue <= 0 then
		return 0
	end

	return total / maxValue
end

local function rawHeightAt(x, z, settings)
	local n = fractalNoise(x, z, settings)
	local normalized = math.clamp((n + 1) * 0.5, 0, 1)

	normalized = smoothStep(normalized)
	normalized = smoothStep(normalized)

	return settings.baseY + normalized * settings.maxY * settings.heightMultiplier
end

local function heightAt(x, z, settings)
	local radius = settings.smoothingRadius

	if radius <= 0 then
		return rawHeightAt(x, z, settings)
	end

	local center = rawHeightAt(x, z, settings) * 4

	local sides =
		rawHeightAt(x + radius, z, settings)
		+ rawHeightAt(x - radius, z, settings)
		+ rawHeightAt(x, z + radius, settings)
		+ rawHeightAt(x, z - radius, settings)

	local diagonals =
		rawHeightAt(x + radius, z + radius, settings)
		+ rawHeightAt(x - radius, z + radius, settings)
		+ rawHeightAt(x + radius, z - radius, settings)
		+ rawHeightAt(x - radius, z - radius, settings)

	return (center + sides * 2 + diagonals) / 16
end

local function createTerrainRegion(settings)
	local topY = settings.baseY + settings.maxY * settings.heightMultiplier + TERRAIN_RESOLUTION * 8

	local minPos = Vector3.new(
		-settings.mapX / 2,
		settings.baseY - TERRAIN_RESOLUTION * 2,
		-settings.mapZ / 2
	)

	local maxPos = Vector3.new(
		settings.mapX / 2,
		topY,
		settings.mapZ / 2
	)

	return Region3.new(minPos, maxPos):ExpandToGrid(TERRAIN_RESOLUTION)
end

local function generateTerrain(settings)
	local terrain = Workspace.Terrain
	local region = createTerrainRegion(settings)

	local rMin = region.CFrame.Position - region.Size / 2
	local rSize = region.Size

	local sizeX = math.floor(rSize.X / TERRAIN_RESOLUTION + 0.5)
	local sizeY = math.floor(rSize.Y / TERRAIN_RESOLUTION + 0.5)
	local sizeZ = math.floor(rSize.Z / TERRAIN_RESOLUTION + 0.5)

	local chunkX = 48
	local chunkZ = 48

	for sx = 1, sizeX, chunkX do
		for sz = 1, sizeZ, chunkZ do
			local ex = math.min(sx + chunkX - 1, sizeX)
			local ez = math.min(sz + chunkZ - 1, sizeZ)

			local chunkMin = Vector3.new(
				rMin.X + (sx - 1) * TERRAIN_RESOLUTION,
				rMin.Y,
				rMin.Z + (sz - 1) * TERRAIN_RESOLUTION
			)

			local chunkMax = Vector3.new(
				rMin.X + ex * TERRAIN_RESOLUTION,
				rMin.Y + sizeY * TERRAIN_RESOLUTION,
				rMin.Z + ez * TERRAIN_RESOLUTION
			)

			local chunkRegion = Region3.new(chunkMin, chunkMax):ExpandToGrid(TERRAIN_RESOLUTION)
			local cMin = chunkRegion.CFrame.Position - chunkRegion.Size / 2
			local cSize = chunkRegion.Size

			local cxCount = math.floor(cSize.X / TERRAIN_RESOLUTION + 0.5)
			local cyCount = math.floor(cSize.Y / TERRAIN_RESOLUTION + 0.5)
			local czCount = math.floor(cSize.Z / TERRAIN_RESOLUTION + 0.5)

			local heights = table.create(cxCount)

			for x = 1, cxCount do
				heights[x] = table.create(czCount)

				local worldX = cMin.X + (x - 0.5) * TERRAIN_RESOLUTION

				for z = 1, czCount do
					local worldZ = cMin.Z + (z - 0.5) * TERRAIN_RESOLUTION
					heights[x][z] = heightAt(worldX, worldZ, settings)
				end
			end

			local materials = table.create(cxCount)
			local occupancies = table.create(cxCount)

			for x = 1, cxCount do
				materials[x] = table.create(cyCount)
				occupancies[x] = table.create(cyCount)

				for y = 1, cyCount do
					materials[x][y] = table.create(czCount)
					occupancies[x][y] = table.create(czCount)

					local worldY = cMin.Y + (y - 0.5) * TERRAIN_RESOLUTION
					local cellBottomY = worldY - TERRAIN_RESOLUTION / 2

					for z = 1, czCount do
						local h = heights[x][z]
						local occupancy = math.clamp((h - cellBottomY) / TERRAIN_RESOLUTION, 0, 1)

						if occupancy > 0 then
							materials[x][y][z] = settings.terrainMaterial
							occupancies[x][y][z] = occupancy
						else
							materials[x][y][z] = Enum.Material.Air
							occupancies[x][y][z] = 0
						end
					end
				end
			end

			terrain:WriteVoxels(chunkRegion, TERRAIN_RESOLUTION, materials, occupancies)

			setStatus(string.format("Generating terrain: X %d/%d, Z %d/%d", ex, sizeX, ez, sizeZ))
			task.wait()
		end
	end
end

local function getBoundingSize(inst)
	if inst:IsA("Model") then
		local _, size = inst:GetBoundingBox()
		return size
	end

	if inst:IsA("BasePart") then
		return inst.Size
	end

	return Vector3.new(1, 1, 1)
end

local function setPhysics(inst, canCollide)
	if inst:IsA("BasePart") then
		inst.Anchored = true
		inst.CanCollide = canCollide
		inst.CanTouch = false
		inst.CastShadow = true
	end

	for _, obj in ipairs(inst:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = canCollide
			obj.CanTouch = false
			obj.CastShadow = true
		end
	end
end

local function scaleInstance(inst, scaleVector)
	if inst:IsA("BasePart") then
		inst.Size = Vector3.new(
			math.max(0.05, inst.Size.X * scaleVector.X),
			math.max(0.05, inst.Size.Y * scaleVector.Y),
			math.max(0.05, inst.Size.Z * scaleVector.Z)
		)

		return
	end

	if not inst:IsA("Model") then
		return
	end

	local pivot = inst:GetPivot()

	for _, obj in ipairs(inst:GetDescendants()) do
		if obj:IsA("BasePart") then
			local relative = pivot:ToObjectSpace(obj.CFrame)
			local relativePosition = relative.Position

			local scaledPosition = Vector3.new(
				relativePosition.X * scaleVector.X,
				relativePosition.Y * scaleVector.Y,
				relativePosition.Z * scaleVector.Z
			)

			obj.Size = Vector3.new(
				math.max(0.05, obj.Size.X * scaleVector.X),
				math.max(0.05, obj.Size.Y * scaleVector.Y),
				math.max(0.05, obj.Size.Z * scaleVector.Z)
			)

			local rotationOnly = relative - relative.Position
			obj.CFrame = pivot * CFrame.new(scaledPosition) * rotationOnly
		end
	end
end

local function placeHexClone(source, parent, name, x, z, bottomY, targetRadius, targetHeight)
	local clone = source:Clone()
	clone.Name = name
	clone.Parent = parent

	local originalSize = getBoundingSize(clone)

	local targetX = targetRadius * 2
	local targetZ = math.sqrt(3) * targetRadius

	local scaleVector = Vector3.new(
		targetX / math.max(originalSize.X, 0.01),
		targetHeight / math.max(originalSize.Y, 0.01),
		targetZ / math.max(originalSize.Z, 0.01)
	)

	scaleInstance(clone, scaleVector)

	local newSize = getBoundingSize(clone)
	clone:PivotTo(CFrame.new(x, bottomY + newSize.Y / 2, z))

	setPhysics(clone, true)

	return clone
end

local function distanceToMapEdge(x, z, settings)
	local halfX = settings.mapX / 2
	local halfZ = settings.mapZ / 2

	local insideX = halfX - math.abs(x)
	local insideZ = halfZ - math.abs(z)

	if insideX >= 0 and insideZ >= 0 then
		return math.min(insideX, insideZ)
	end

	local outsideX = math.max(math.abs(x) - halfX, 0)
	local outsideZ = math.max(math.abs(z) - halfZ, 0)

	return -math.sqrt(outsideX * outsideX + outsideZ * outsideZ)
end

local function iterateHexGrid(radius, minX, maxX, minZ, maxZ, callback)
	local xStep = radius * 1.5
	local zStep = math.sqrt(3) * radius

	local cols = math.ceil((maxX - minX) / xStep) + 2
	local rows = math.ceil((maxZ - minZ) / zStep) + 2

	for col = 0, cols do
		local x = minX + col * xStep

		for row = 0, rows do
			local z = minZ + row * zStep + ((col % 2 == 1) and zStep / 2 or 0)

			if x >= minX and x <= maxX and z >= minZ and z <= maxZ then
				callback(x, z, col, row)
			end
		end

		if col % 6 == 0 then
			task.wait()
		end
	end
end

local function generateInnerDetailHexes(settings, borderFolder)
	if settings.detailRings <= 0 then
		return 0
	end

	local radius = settings.detailHexRadius
	local detailDepth = settings.detailRings * radius * 1.75

	local minX = -settings.mapX / 2
	local maxX = settings.mapX / 2
	local minZ = -settings.mapZ / 2
	local maxZ = settings.mapZ / 2

	local made = 0

	iterateHexGrid(radius, minX, maxX, minZ, maxZ, function(x, z)
		local edgeDistance = distanceToMapEdge(x, z, settings)

		if edgeDistance >= 0 and edgeDistance <= detailDepth then
			local surfaceY = heightAt(x, z, settings)
			local noiseValue = random01(x, z, settings.seed)
			local height = settings.detailHexHeight * (0.75 + noiseValue * 0.5)

			placeHexClone(
				selectedHexModel,
				borderFolder,
				"InnerDetailHex",
				x,
				z,
				surfaceY - 2,
				radius,
				height
			)

			made += 1
		end
	end)

	return made
end

local function generateTallBorderHexes(settings, borderFolder)
	local radius = settings.wallHexRadius
	local wallDepth = settings.wallRings * radius * 1.75

	local minX = -settings.mapX / 2 - wallDepth - radius * 2
	local maxX = settings.mapX / 2 + wallDepth + radius * 2
	local minZ = -settings.mapZ / 2 - wallDepth - radius * 2
	local maxZ = settings.mapZ / 2 + wallDepth + radius * 2

	local made = 0

	iterateHexGrid(radius, minX, maxX, minZ, maxZ, function(x, z)
		local edgeDistance = distanceToMapEdge(x, z, settings)

		if edgeDistance <= 2 and edgeDistance >= -wallDepth then
			local noiseValue = random01(x, z, settings.seed + 999)
			local roughness = (noiseValue - 0.5) * settings.wallRoughness
			local height = math.max(settings.wallHeight * 0.75, settings.wallHeight + roughness)

			placeHexClone(
				selectedHexModel,
				borderFolder,
				"TallBorderHex",
				x,
				z,
				settings.baseY - 8,
				radius,
				height
			)

			made += 1
		end
	end)

	return made
end

local function generateHexBorder(settings, borderFolder)
	if not selectedHexModel then
		setStatus("Border enabled, but no hex model selected.")
		return
	end

	setStatus("Generating inner detail hexes...")
	local detailCount = generateInnerDetailHexes(settings, borderFolder)

	setStatus("Generating tall border hexes...")
	local wallCount = generateTallBorderHexes(settings, borderFolder)

	setStatus(string.format("Generated border: %d detail hexes, %d tall hexes.", detailCount, wallCount))
end

local function getOuterHalfExtents(settings)
	local wallDepth = 0

	if settings.borderEnabled then
		wallDepth = settings.wallRings * settings.wallHexRadius * 1.75
	end

	local margin = wallDepth + 32

	return settings.mapX / 2 + margin, settings.mapZ / 2 + margin
end

local function createInvisiblePart(name, size, cframe, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent

	return part
end

local function createInvisibleWalls(settings, collisionFolder)
	local halfX, halfZ = getOuterHalfExtents(settings)
	local thickness = 12
	local height = settings.invisibleWallHeight
	local centerY = settings.baseY + height / 2

	createInvisiblePart(
		"InvisibleWall_North",
		Vector3.new(halfX * 2 + thickness * 2, height, thickness),
		CFrame.new(0, centerY, halfZ + thickness / 2),
		collisionFolder
	)

	createInvisiblePart(
		"InvisibleWall_South",
		Vector3.new(halfX * 2 + thickness * 2, height, thickness),
		CFrame.new(0, centerY, -halfZ - thickness / 2),
		collisionFolder
	)

	createInvisiblePart(
		"InvisibleWall_East",
		Vector3.new(thickness, height, halfZ * 2 + thickness * 2),
		CFrame.new(halfX + thickness / 2, centerY, 0),
		collisionFolder
	)

	createInvisiblePart(
		"InvisibleWall_West",
		Vector3.new(thickness, height, halfZ * 2 + thickness * 2),
		CFrame.new(-halfX - thickness / 2, centerY, 0),
		collisionFolder
	)
end

local function createHeightLimit(settings, collisionFolder)
	if settings.heightLimit <= 0 then
		return
	end

	local halfX, halfZ = getOuterHalfExtents(settings)
	local thickness = 4

	createInvisiblePart(
		"HeightLimitCeiling",
		Vector3.new(halfX * 2 + 64, thickness, halfZ * 2 + 64),
		CFrame.new(0, settings.baseY + settings.heightLimit, 0),
		collisionFolder
	)
end

local function getClearRegion(settings)
	local halfX, halfZ = getOuterHalfExtents(settings)

	local topY = settings.baseY + math.max(
		settings.maxY * settings.heightMultiplier + 128,
		settings.wallHeight + 128,
		settings.invisibleWallHeight + 64,
		settings.heightLimit + 64
	)

	local minPos = Vector3.new(
		-halfX - 64,
		settings.baseY - 80,
		-halfZ - 64
	)

	local maxPos = Vector3.new(
		halfX + 64,
		topY,
		halfZ + 64
	)

	return Region3.new(minPos, maxPos):ExpandToGrid(TERRAIN_RESOLUTION)
end

local function clearGenerated(settings)
	local folder = Workspace:FindFirstChild(GENERATED_FOLDER_NAME)

	if folder then
		folder:Destroy()
	end

	if settings.clearTerrain then
		Workspace.Terrain:ClearVoxels(getClearRegion(settings))
	end
end

local function readSettings()
	local seed = seedChoice.get()

	if seed == "random" then
		seed = math.random(1, 999999)
	end

	return {
		mapX = mapXChoice.get(),
		mapZ = mapZChoice.get(),
		baseY = baseYChoice.get(),
		terrainMaterial = getMaterial(materialChoice.get()),
		clearTerrain = clearTerrainChoice.get(),

		maxY = maxHeightChoice.get(),
		heightMultiplier = heightMultiplierChoice.get(),
		smoothingRadius = smoothingChoice.get(),
		stretchX = stretchXChoice.get(),
		stretchZ = stretchZChoice.get(),

		seed = seed,
		noiseScale = noiseScaleChoice.get(),
		octaves = octavesChoice.get(),
		persistence = persistenceChoice.get(),
		lacunarity = lacunarityChoice.get(),

		borderEnabled = borderEnabledChoice.get(),
		detailRings = detailRingsChoice.get(),
		detailHexRadius = detailHexRadiusChoice.get(),
		detailHexHeight = detailHexHeightChoice.get(),
		wallRings = wallRingsChoice.get(),
		wallHexRadius = wallHexRadiusChoice.get(),
		wallHeight = wallHeightChoice.get(),
		wallRoughness = wallRoughnessChoice.get(),

		invisibleWallsEnabled = invisibleWallsChoice.get(),
		invisibleWallHeight = invisibleWallHeightChoice.get(),
		heightLimit = heightLimitChoice.get(),
	}
end

clearButton.MouseButton1Click:Connect(function()
	local settings = readSettings()

	clearGenerated(settings)

	ChangeHistoryService:SetWaypoint("Clear Smooth Dune Terrain")
	setStatus("Generated map cleared.")
end)

generateButton.MouseButton1Click:Connect(function()
	if isGenerating then
		setStatus("Already generating. Wait until it finishes.")
		return
	end

	local settings = readSettings()

	if settings.borderEnabled and not selectedHexModel then
		setStatus("Border Enabled = Yes, but no hex model selected. Select hex model and click Use Selected Hex Model.")
		return
	end

	if settings.mapX * settings.mapZ > 1200000 and not largeMapConfirm then
		largeMapConfirm = true
		setStatus("Large map selected. Click Generate again within 5 seconds to confirm.")

		local oldText = generateButton.Text
		generateButton.Text = "Generate Large Map Anyway"

		task.delay(5, function()
			largeMapConfirm = false

			if generateButton then
				generateButton.Text = oldText
			end
		end)

		return
	end

	largeMapConfirm = false
	isGenerating = true
	generateButton.Text = "Generating..."

	ChangeHistoryService:SetWaypoint("Before Smooth Dune Terrain Generation")

	local ok, err = pcall(function()
		clearGenerated(settings)

		local generatedFolder = getOrCreateGeneratedFolder()
		local borderFolder = getOrCreateChildFolder(generatedFolder, HEX_BORDER_FOLDER_NAME)
		local collisionFolder = getOrCreateChildFolder(generatedFolder, COLLISION_FOLDER_NAME)

		setStatus("Generating smooth dune terrain...")
		generateTerrain(settings)

		if settings.borderEnabled then
			generateHexBorder(settings, borderFolder)
		end

		if settings.invisibleWallsEnabled then
			setStatus("Creating invisible walls...")
			createInvisibleWalls(settings, collisionFolder)
		end

		if settings.heightLimit > 0 then
			setStatus("Creating height limit...")
			createHeightLimit(settings, collisionFolder)
		end
	end)

	if ok then
		ChangeHistoryService:SetWaypoint("Generate Smooth Dune Terrain + Hex Border")
		setStatus("Done. Terrain, hex border, invisible walls and height limit generated.")
	else
		warn(err)
		setStatus("Error: " .. tostring(err))
	end

	generateButton.Text = "Generate"
	isGenerating = false
end)
