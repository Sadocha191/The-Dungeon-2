local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AGGREGATE_WINDOW = 0.9
local DEFAULT_LIFETIME = 3.25
local ENTER_TIME = 0.18
local EXIT_TIME = 0.22

local VARIANT_COLORS = {
	silver = Color3.fromRGB(245, 198, 92),
	souls = Color3.fromRGB(154, 112, 255),
	weaponPoints = Color3.fromRGB(94, 201, 255),
	ticket = Color3.fromRGB(255, 203, 86),
	weapon = Color3.fromRGB(255, 151, 94),
	spell = Color3.fromRGB(193, 132, 255),
	mineResource = Color3.fromRGB(90, 203, 145),
	mobMaterial = Color3.fromRGB(241, 170, 94),
	recipe = Color3.fromRGB(117, 176, 255),
	upgradeMaterial = Color3.fromRGB(255, 114, 153),
	material = Color3.fromRGB(210, 210, 210),
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(206, 206, 206),
	Uncommon = Color3.fromRGB(88, 214, 121),
	Rare = Color3.fromRGB(79, 172, 255),
	Epic = Color3.fromRGB(185, 111, 255),
	Legendary = Color3.fromRGB(255, 177, 66),
	Mythical = Color3.fromRGB(255, 84, 129),
}

local DEFAULT_NOTES = {
	silver = "Silver Acquired",
	souls = "Souls Acquired",
	weaponPoints = "Weapon Points",
	ticket = "Ticket Acquired",
	weapon = "Weapon Acquired",
	spell = "Spell Unlocked",
	mineResource = "Mining",
	mobMaterial = "Mob Drop",
	recipe = "Weapon Schematic",
	upgradeMaterial = "Upgrade Material",
	material = "Material Acquired",
}

local activeByKey = {}
local toastSequence = 0
local toastGui = nil
local toastStack = nil
local viewportConnection = nil

local function formatNumber(value)
	local raw = tostring(math.max(0, math.floor(tonumber(value) or 0)))
	local reversed = string.reverse(raw):gsub("(%d%d%d)", "%1,")
	reversed = reversed:gsub(",$", "")
	return string.reverse(reversed)
end

local function waitForRemoteFolder()
	local existing = ReplicatedStorage:FindFirstChild("RemoteEvents") or ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		return existing
	end

	local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 5)
	if remoteEvents then
		return remoteEvents
	end

	return ReplicatedStorage:WaitForChild("Remotes")
end

local remoteFolder = waitForRemoteFolder()
local pickupToastEvent = remoteFolder and remoteFolder:WaitForChild("PickupToastEvent")
if not pickupToastEvent then
	warn("[PickupToastClient] Missing PickupToastEvent")
	return
end

local function createFallbackGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PickupToastGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 35
	gui.Parent = playerGui

	local stack = Instance.new("Frame")
	stack.Name = "ToastStack"
	stack.BackgroundTransparency = 1
	stack.BorderSizePixel = 0
	stack.AnchorPoint = Vector2.new(0, 1)
	stack.Parent = gui

	return gui, stack
end

local function getExistingGui()
	local first = nil
	for _, child in ipairs(playerGui:GetChildren()) do
		if child.Name == "PickupToastGui" then
			if child:IsA("ScreenGui") and not first then
				first = child
			else
				child:Destroy()
			end
		end
	end
	return first
end

local function ensureLayout(stack)
	local layout = stack:FindFirstChildOfClass("UIListLayout")
	if not layout then
		layout = Instance.new("UIListLayout")
		layout.Parent = stack
	end
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 8)
end

local function ensureGui()
	local gui = getExistingGui()
	if not gui then
		playerGui:WaitForChild("PickupToastGui", 1)
		gui = getExistingGui()
	end
	if not (gui and gui:IsA("ScreenGui")) then
		if gui then
			gui:Destroy()
		end
		gui, toastStack = createFallbackGui()
	else
		local stack = gui:FindFirstChild("ToastStack")
		if not (stack and stack:IsA("Frame")) then
			gui:Destroy()
			gui, toastStack = createFallbackGui()
		else
			toastStack = stack
		end
	end

	toastGui = gui
	toastGui.ResetOnSpawn = false
	toastGui.IgnoreGuiInset = false
	toastGui.DisplayOrder = math.max(35, toastGui.DisplayOrder)

	toastStack.BackgroundTransparency = 1
	toastStack.BorderSizePixel = 0
	toastStack.AnchorPoint = Vector2.new(0, 1)
	toastStack.ClipsDescendants = false

	ensureLayout(toastStack)
end

local function applyResponsiveSizing()
	if not toastStack or not toastStack.Parent then
		return
	end

	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local margin = viewport.X <= 500 and 12 or 18
	local width = math.clamp(math.floor(viewport.X * 0.27), 220, 340)
	local height = math.clamp(math.floor(viewport.Y * 0.42), 180, 420)

	toastStack.Position = UDim2.new(0, margin, 1, -margin)
	toastStack.Size = UDim2.fromOffset(width, height)
end

local function bindViewport()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveSizing)
	end

	applyResponsiveSizing()
end

local function getAccentColor(payload)
	local rarity = tostring(payload.rarity or "")
	if rarity ~= "" and RARITY_COLORS[rarity] then
		return RARITY_COLORS[rarity]
	end
	return VARIANT_COLORS[tostring(payload.variant or "")] or VARIANT_COLORS.material
end

local function isCountVariant(variant)
	return variant == "silver"
		or variant == "souls"
		or variant == "weaponPoints"
		or variant == "ticket"
		or variant == "mineResource"
		or variant == "mobMaterial"
		or variant == "upgradeMaterial"
		or variant == "material"
end

local function buildMainText(payload, amount)
	local variant = tostring(payload.variant or "")
	local label = tostring(payload.label or "")
	if isCountVariant(variant) then
		return string.format("+%s %s", formatNumber(amount), label)
	end
	if amount > 1 then
		return string.format("%s x%s", label, formatNumber(amount))
	end
	return label
end

local function buildNoteText(payload)
	local explicit = tostring(payload.note or "")
	if explicit ~= "" then
		return explicit
	end
	return DEFAULT_NOTES[tostring(payload.variant or "")] or "Collected"
end

local function setTransparency(entry, alpha)
	entry.frame.BackgroundTransparency = 0.08 + (alpha * 0.78)
	entry.stroke.Transparency = 0.16 + (alpha * 0.84)
	entry.accent.BackgroundTransparency = alpha * 0.35
	entry.main.TextTransparency = alpha
	entry.note.TextTransparency = alpha
end

local function refreshEntry(entry)
	local accentColor = getAccentColor(entry.payload)
	entry.accent.BackgroundColor3 = accentColor
	entry.stroke.Color = accentColor
	entry.main.Text = buildMainText(entry.payload, entry.amount)
	entry.note.Text = buildNoteText(entry.payload)
	entry.main.TextColor3 = Color3.fromRGB(245, 245, 245)
	entry.note.TextColor3 = Color3.fromRGB(186, 186, 196)
end

local function destroyEntry(entry)
	if activeByKey[entry.key] == entry then
		activeByKey[entry.key] = nil
	end
	if entry.frame and entry.frame.Parent then
		entry.frame:Destroy()
	end
end

local function closeEntry(entry)
	if entry.closing then
		return
	end

	entry.closing = true
	if activeByKey[entry.key] == entry then
		activeByKey[entry.key] = nil
	end

	TweenService:Create(entry.scale, TweenInfo.new(EXIT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.94,
	}):Play()
	TweenService:Create(entry.frame, TweenInfo.new(EXIT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0.92,
	}):Play()
	TweenService:Create(entry.stroke, TweenInfo.new(EXIT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	TweenService:Create(entry.accent, TweenInfo.new(EXIT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(entry.main, TweenInfo.new(EXIT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	TweenService:Create(entry.note, TweenInfo.new(EXIT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()

	task.delay(EXIT_TIME + 0.03, function()
		destroyEntry(entry)
	end)
end

local function scheduleClose(entry)
	entry.revision += 1
	local revision = entry.revision
	local lifetime = math.max(1.2, tonumber(entry.payload.duration) or DEFAULT_LIFETIME)
	task.delay(lifetime, function()
		if entry.closing or entry.revision ~= revision then
			return
		end
		closeEntry(entry)
	end)
end

local function popEntry(entry)
	if entry.closing then
		return
	end

	entry.scale.Scale = 1.05
	TweenService:Create(entry.scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

local function createEntry(payload, amount, key, now)
	toastSequence += 1

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.Size = UDim2.new(1, 0, 0, 58)
	frame.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	frame.BackgroundTransparency = 0.86
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.LayoutOrder = toastSequence
	frame.Parent = toastStack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 1
	stroke.Parent = frame

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 5, 1, -16)
	accent.Position = UDim2.new(0, 8, 0, 8)
	accent.BackgroundTransparency = 1
	accent.BorderSizePixel = 0
	accent.Parent = frame

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(1, 0)
	accentCorner.Parent = accent

	local main = Instance.new("TextLabel")
	main.Name = "Main"
	main.BackgroundTransparency = 1
	main.Position = UDim2.new(0, 24, 0, 7)
	main.Size = UDim2.new(1, -36, 0, 22)
	main.Font = Enum.Font.GothamBold
	main.TextSize = 15
	main.TextXAlignment = Enum.TextXAlignment.Left
	main.TextYAlignment = Enum.TextYAlignment.Center
	main.TextTransparency = 1
	main.TextTruncate = Enum.TextTruncate.AtEnd
	main.Parent = frame

	local note = Instance.new("TextLabel")
	note.Name = "Note"
	note.BackgroundTransparency = 1
	note.Position = UDim2.new(0, 24, 0, 29)
	note.Size = UDim2.new(1, -36, 0, 15)
	note.Font = Enum.Font.Gotham
	note.TextSize = 11
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextYAlignment = Enum.TextYAlignment.Center
	note.TextTransparency = 1
	note.TextTruncate = Enum.TextTruncate.AtEnd
	note.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.94
	scale.Parent = frame

	local entry = {
		key = key,
		payload = payload,
		amount = amount,
		frame = frame,
		stroke = stroke,
		accent = accent,
		main = main,
		note = note,
		scale = scale,
		lastAt = now,
		revision = 0,
		closing = false,
	}

	activeByKey[key] = entry
	refreshEntry(entry)
	setTransparency(entry, 1)

	TweenService:Create(scale, TweenInfo.new(ENTER_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(frame, TweenInfo.new(ENTER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.08,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(ENTER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0.16,
	}):Play()
	TweenService:Create(accent, TweenInfo.new(ENTER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0,
	}):Play()
	TweenService:Create(main, TweenInfo.new(ENTER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
	TweenService:Create(note, TweenInfo.new(ENTER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()

	scheduleClose(entry)
	return entry
end

local function handleToast(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local label = tostring(payload.label or "")
	if label == "" then
		return
	end

	local amount = math.max(1, math.floor(tonumber(payload.amount) or 1))
	local variant = tostring(payload.variant or "material")
	local note = tostring(payload.note or "")
	local key = tostring(payload.key or (variant .. "|" .. label .. "|" .. note))
	local now = os.clock()

	local existing = activeByKey[key]
	if existing and not existing.closing and (now - existing.lastAt) <= AGGREGATE_WINDOW then
		existing.amount += amount
		existing.lastAt = now
		existing.payload = payload
		refreshEntry(existing)
		popEntry(existing)
		scheduleClose(existing)
		return
	end

	createEntry(payload, amount, key, now)
end

ensureGui()
bindViewport()

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
playerGui.ChildAdded:Connect(function(child)
	if child.Name == "PickupToastGui" then
		task.defer(function()
			ensureGui()
			bindViewport()
		end)
	end
end)

pickupToastEvent.OnClientEvent:Connect(handleToast)
