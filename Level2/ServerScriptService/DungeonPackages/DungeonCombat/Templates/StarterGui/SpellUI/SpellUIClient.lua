local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = script.Parent

if gui and gui:IsA("ScreenGui") then
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
end

local frame = gui:WaitForChild("SpellUI")
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
assert(moduleFolder and moduleFolder:IsA("Folder"), "[SpellUI] Missing ReplicatedStorage.ModuleScripts/ModuleScript")

local SpellDefs = require(moduleFolder:WaitForChild("SpellDefinitions"))
local PauseState = ReplicatedStorage:FindFirstChild("PauseState") or ReplicatedStorage:WaitForChild("PauseState")

local SLOT_COUNT = SpellDefs.MAX_RUN_SPELLS or 10
local EMPTY_STROKE_COLOR = Color3.fromRGB(60, 60, 60)
local MIN_BAR_COOLDOWN = 0.60
local MIN_FULL_COOLDOWN = 1.25

local slots = table.create(SLOT_COUNT)
local levelLabels = table.create(SLOT_COUNT)
local slotTextLabels = table.create(SLOT_COUNT)
local cooldownWidgets = table.create(SLOT_COUNT)
local slotStrokes = table.create(SLOT_COUNT)
local displayedSpellIds = table.create(SLOT_COUNT)
local cooldownState = {}
local activeSpellOrder = {}
local allSpellIds = SpellDefs.GetSpellIds and SpellDefs.GetSpellIds() or {}

local pauseAccum = 0
local pauseStart = nil

local function spellClock()
	local realNow = os.clock()
	if PauseState.Value then
		if not pauseStart then
			pauseStart = realNow
		end
		return pauseStart - pauseAccum
	end
	if pauseStart then
		pauseAccum += (realNow - pauseStart)
		pauseStart = nil
	end
	return realNow - pauseAccum
end

local function getSpellState(spellId)
	return {
		level = tonumber(player:GetAttribute(("Spell_%s_Level"):format(spellId))) or 0,
		upgradePower = tonumber(player:GetAttribute(("Spell_%s_UpgradePower"):format(spellId))) or 0,
		baseMultiplier = tonumber(player:GetAttribute(("Spell_%s_BaseMultiplier"):format(spellId))) or 1,
		basePower = tonumber(player:GetAttribute(("Spell_%s_BasePower"):format(spellId))) or 0,
	}
end

local function getSpellDef(spellId)
	return SpellDefs.SPELLS and SpellDefs.SPELLS[spellId] or nil
end

local function getSpellColor(spellId)
	local def = getSpellDef(spellId)
	return SpellDefs.GetSpellColor and SpellDefs.GetSpellColor(def) or Color3.fromRGB(220, 220, 220)
end

local function getSpellInitials(spellId)
	local def = getSpellDef(spellId)
	local source = (def and def.name) or spellId
	local initials = {}
	for token in string.gmatch(source, "[A-Za-z]+") do
		initials[#initials + 1] = string.sub(string.upper(token), 1, 1)
	end
	if #initials == 0 then
		local compact = string.gsub(tostring(source), "%s+", "")
		return string.upper(string.sub(compact, 1, 2))
	end
	return table.concat(initials, "", 1, math.min(2, #initials))
end

local function findSlotTextLabel(slot)
	local label = slot:FindFirstChild("TextLabel")
	if label and label:IsA("TextLabel") then
		return label
	end
	return slot:FindFirstChildWhichIsA("TextLabel", true)
end

local function ensureStroke(slot)
	local stroke = slot:FindFirstChild("SpellUIStroke")
	if stroke and stroke:IsA("UIStroke") then
		return stroke
	end
	stroke = Instance.new("UIStroke")
	stroke.Name = "SpellUIStroke"
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Color = EMPTY_STROKE_COLOR
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = slot
	return stroke
end

local function ensureCooldownWidget(slot)
	if slot:IsA("GuiObject") then
		slot.ClipsDescendants = true
	end

	local overlay = slot:FindFirstChild("CooldownOverlay")
	if overlay and overlay:IsA("Frame") then
		local barBg = overlay:FindFirstChild("CooldownBarBg")
		local barFill = barBg and barBg:FindFirstChild("CooldownBarFill")
		local gradient = overlay:FindFirstChildOfClass("UIGradient")
		return { root = overlay, barBg = barBg, barFill = barFill, gradient = gradient }
	end

	overlay = Instance.new("Frame")
	overlay.Name = "CooldownOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BorderSizePixel = 0
	overlay.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
	overlay.BackgroundTransparency = 0.25
	overlay.Visible = false
	overlay.ZIndex = (slot:IsA("GuiObject") and slot.ZIndex + 1) or 1
	overlay.Parent = slot

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 26, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(48, 72, 110)),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	gradient.Rotation = 90
	gradient.Parent = overlay

	local barBg = Instance.new("Frame")
	barBg.Name = "CooldownBarBg"
	barBg.AnchorPoint = Vector2.new(0.5, 1)
	barBg.Position = UDim2.fromScale(0.5, 1)
	barBg.Size = UDim2.fromScale(1, 0.18)
	barBg.BorderSizePixel = 0
	barBg.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	barBg.BackgroundTransparency = 0.1
	barBg.ZIndex = overlay.ZIndex + 1
	barBg.Parent = overlay

	local barFill = Instance.new("Frame")
	barFill.Name = "CooldownBarFill"
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BorderSizePixel = 0
	barFill.ZIndex = barBg.ZIndex + 1
	barFill.Parent = barBg

	return { root = overlay, barBg = barBg, barFill = barFill, gradient = gradient }
end

local function setSlotEmpty(index)
	local textLabel = slotTextLabels[index]
	local levelLabel = levelLabels[index]
	local widget = cooldownWidgets[index]
	local stroke = slotStrokes[index]

	displayedSpellIds[index] = nil
	if textLabel then
		textLabel.Text = ""
		textLabel.TextTransparency = 0.45
		textLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end
	if levelLabel then
		levelLabel.Text = ""
		levelLabel.TextTransparency = 0.45
		levelLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end
	if widget and widget.root then
		widget.root.Visible = false
		widget.root.BackgroundTransparency = 1
		if widget.barFill then
			widget.barFill.Size = UDim2.fromScale(0, 1)
		end
	end
	if stroke then
		stroke.Color = EMPTY_STROKE_COLOR
		stroke.Transparency = 0.45
	end
end

local function setSlotSpell(index, spellId, state)
	local def = getSpellDef(spellId)
	local color = getSpellColor(spellId)
	local textLabel = slotTextLabels[index]
	local levelLabel = levelLabels[index]
	local stroke = slotStrokes[index]

	displayedSpellIds[index] = spellId
	if textLabel then
		textLabel.Text = getSpellInitials(spellId)
		textLabel.TextTransparency = 0
		textLabel.TextColor3 = color
		textLabel.TextScaled = true
	end
	if levelLabel then
		local prefix = def and def.spellType == "Physical" and "P" or "M"
		levelLabel.Text = string.format("%s Lv.%d", prefix, state.level)
		levelLabel.TextTransparency = 0
		levelLabel.TextColor3 = color
	end
	if stroke then
		stroke.Color = color
		stroke.Transparency = 0.1
	end
end

local function rebuildActiveSpellOrder()
	local active = {}
	for _, spellId in ipairs(allSpellIds) do
		if getSpellState(spellId).level > 0 then
			active[#active + 1] = spellId
		end
	end
	activeSpellOrder = SpellDefs.SortSpellIds and SpellDefs.SortSpellIds(active) or active
end

local function refreshCooldownRecord(spellId, forceRestart)
	local state = getSpellState(spellId)
	if state.level <= 0 then
		cooldownState[spellId] = nil
		return
	end

	local def = getSpellDef(spellId)
	local runtime = def and SpellDefs.ComputeRuntimeStats and SpellDefs.ComputeRuntimeStats(def, state) or nil
	local duration = runtime and runtime.cooldown or nil
	if not duration or duration <= 0 then
		cooldownState[spellId] = nil
		return
	end

	local record = cooldownState[spellId]
	local now = spellClock()
	if not record then
		record = { startClock = now, duration = duration }
		cooldownState[spellId] = record
		return
	end

	record.duration = duration
	if forceRestart then
		record.startClock = now
	end
end

local function refreshSlots()
	for index = 1, SLOT_COUNT do
		local spellId = activeSpellOrder[index]
		if spellId then
			setSlotSpell(index, spellId, getSpellState(spellId))
		else
			setSlotEmpty(index)
		end
	end
end

local function onSpellChanged(spellId)
	local state = getSpellState(spellId)
	refreshCooldownRecord(spellId, state.level > 0)
	rebuildActiveSpellOrder()
	refreshSlots()
end

local function refreshCooldownVisuals(now)
	for index = 1, SLOT_COUNT do
		local spellId = displayedSpellIds[index]
		local widget = cooldownWidgets[index]
		local stroke = slotStrokes[index]
		local textLabel = slotTextLabels[index]
		local levelLabel = levelLabels[index]

		if not spellId or not widget or not widget.root then
			continue
		end

		local record = cooldownState[spellId]
		local accentColor = getSpellColor(spellId)
		if not record or not record.duration or record.duration <= 0 then
			widget.root.Visible = false
			widget.root.BackgroundTransparency = 1
			if widget.barFill then
				widget.barFill.Size = UDim2.fromScale(0, 1)
			end
			if stroke then
				stroke.Color = accentColor
			end
			continue
		end

		local elapsed = now - record.startClock
		if elapsed >= record.duration then
			record.startClock = now
			elapsed = 0
		end

		local progress = math.clamp(elapsed / record.duration, 0, 1)
		if record.duration < MIN_BAR_COOLDOWN then
			widget.root.Visible = false
			widget.root.BackgroundTransparency = 1
			if widget.barFill then
				widget.barFill.Size = UDim2.fromScale(0, 1)
			end
		else
			local fullMode = record.duration >= MIN_FULL_COOLDOWN
			widget.root.Visible = true
			widget.root.BackgroundTransparency = fullMode and 0.28 or 1
			if widget.gradient then
				widget.gradient.Enabled = fullMode
			end
			if widget.barBg then
				widget.barBg.Visible = true
				widget.barBg.BackgroundTransparency = fullMode and 0.15 or 0.05
			end
			if widget.barFill then
				widget.barFill.BackgroundColor3 = accentColor
				widget.barFill.Size = UDim2.fromScale(1 - progress, 1)
			end
			if textLabel then
				textLabel.TextTransparency = fullMode and 0.2 or 0
			end
			if levelLabel then
				levelLabel.TextTransparency = fullMode and 0.2 or 0
			end
		end

		if stroke then
			stroke.Color = accentColor
			stroke.Transparency = 0.1
		end
	end
end

for index = 1, SLOT_COUNT do
	local slot = frame:WaitForChild(("Slot%d"):format(index))
	local levelLabel = frame:WaitForChild(("Lvl%d"):format(index))
	local textLabel = findSlotTextLabel(slot)
	slots[index] = slot
	levelLabels[index] = levelLabel
	slotTextLabels[index] = textLabel
	slotStrokes[index] = ensureStroke(slot)
	cooldownWidgets[index] = ensureCooldownWidget(slot)
end

for _, spellId in ipairs(allSpellIds) do
	refreshCooldownRecord(spellId, true)
	for _, suffix in ipairs({ "Level", "UpgradePower", "BaseMultiplier", "BasePower" }) do
		player:GetAttributeChangedSignal(("Spell_%s_%s"):format(spellId, suffix)):Connect(function()
			onSpellChanged(spellId)
		end)
	end
end

rebuildActiveSpellOrder()
refreshSlots()
refreshCooldownVisuals(spellClock())

RunService.RenderStepped:Connect(function()
	refreshCooldownVisuals(spellClock())
end)
