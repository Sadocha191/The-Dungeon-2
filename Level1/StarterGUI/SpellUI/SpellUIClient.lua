local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local gui = script.Parent

if gui and gui:IsA("ScreenGui") then
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
end

local frame = gui:WaitForChild("Frame")
local moduleFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
assert(moduleFolder and moduleFolder:IsA("Folder"), "[SpellUI] Missing ReplicatedStorage.ModuleScripts/ModuleScript")

local SpellDefs = require(moduleFolder:WaitForChild("SpellDefinitions"))
local PauseState = ReplicatedStorage:FindFirstChild("PauseState") or ReplicatedStorage:WaitForChild("PauseState")

local SLOT_COUNT = 12

local EMPTY_SLOT_TEXT = ""
local EMPTY_LEVEL_TEXT = ""
local READY_STROKE_COLOR = Color3.fromRGB(255, 214, 102)
local COOLING_STROKE_COLOR = Color3.fromRGB(95, 110, 135)
local EMPTY_STROKE_COLOR = Color3.fromRGB(60, 60, 60)

local RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(220, 220, 220),
	Uncommon = Color3.fromRGB(120, 255, 175),
	Rare = Color3.fromRGB(120, 175, 255),
	Epic = Color3.fromRGB(255, 165, 120),
}

local COOLDOWN_RESOLVERS = {
	ShadowDagger = function(level)
		if level <= 0 then return nil end
		local cd = 0.8
		if level >= 2 then
			cd *= 0.9
			cd *= 0.9 ^ (level - 1)
		end
		return cd
	end,
	BoneSpear = function(level)
		if level <= 0 then return nil end
		return 1.4
	end,
	IceShards = function(level)
		if level <= 0 then return nil end
		return 2.0
	end,
	PoisonCloud = function(level)
		if level <= 0 then return nil end
		return 2.5
	end,
	EmberSpirits = function(level)
		if level <= 0 then return nil end
		local cd = 1.2
		if level >= 4 then
			cd *= 0.9
		end
		return cd
	end,
	FlameTrail = function(level)
		if level <= 0 then return nil end
		return 0.35
	end,
	FrostNova = function(level)
		if level <= 0 then return nil end
		local cd = 6.0
		if level >= 3 then
			cd *= 0.9
		end
		return cd
	end,
	GravityPulse = function(level)
		if level <= 0 then return nil end
		local cd = 5.0
		if level >= 4 then
			cd *= 0.9
		end
		return cd
	end,
	ArcaneMissile = function(level)
		if level <= 0 then return nil end
		return 2.2
	end,
	CrystalBarrage = function(level)
		if level <= 0 then return nil end
		return 2.6
	end,
	ChainHooks = function(level)
		if level <= 0 then return nil end
		return 4.0
	end,
	IceWall = function(level)
		if level <= 0 then return nil end
		return 8.0
	end,
	ThunderTotem = function(level)
		if level <= 0 then return nil end
		return 10.0
	end,
	NecroSwarm = function(level)
		if level <= 0 then return nil end
		return 1.6
	end,
	ArcaneMine = function(level)
		if level <= 0 then return nil end
		return 3.5
	end,
	DarkRift = function(level)
		if level <= 0 then return nil end
		return 7.0
	end,
	MeteorStrike = function(level)
		if level <= 0 then return nil end
		local cd = 4.5
		if level >= 4 then
			cd *= 0.9
		end
		return cd
	end,
	SolarBeam = function(level)
		if level <= 0 then return nil end
		return 6.5
	end,
	VoidRing = function(level)
		if level <= 0 then return nil end
		return 5.5
	end,
	BloodNova = function(level)
		if level <= 0 then return nil end
		local cd = 7.0
		if level >= 3 then
			cd *= 0.9
		end
		return cd
	end,
	TimeFracture = function(level)
		if level <= 0 then return nil end
		return 10.0
	end,
	SoulLink = function(level)
		if level <= 0 then return nil end
		return 9.0
	end,
	Starfall = function(level)
		if level <= 0 then return nil end
		return 8.5
	end,
}

local slots = table.create(SLOT_COUNT)
local levelLabels = table.create(SLOT_COUNT)
local slotTextLabels = table.create(SLOT_COUNT)
local cooldownOverlays = table.create(SLOT_COUNT)
local slotStrokes = table.create(SLOT_COUNT)
local displayedSpellIds = table.create(SLOT_COUNT)

local allSpellIds = {}
local ownedSpellOrder = {}
local ownedLookup = {}
local cooldownState = {}
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

local function getSpellLevel(spellId)
	return tonumber(player:GetAttribute(("Spell_%s_Level"):format(spellId))) or 0
end

local function getSpellDef(spellId)
	return SpellDefs.SPELLS and SpellDefs.SPELLS[spellId] or nil
end

local function rarityRank(spellId)
	local def = getSpellDef(spellId)
	return RARITY_ORDER[(def and def.rarity) or "Common"] or 99
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

local function ensureCooldownOverlay(slot, stroke)
	if slot:IsA("GuiObject") then
		slot.ClipsDescendants = true
	end

	local overlay = slot:FindFirstChild("CooldownOverlay")
	if overlay and overlay:IsA("Frame") then
		return overlay
	end

	overlay = Instance.new("Frame")
	overlay.Name = "CooldownOverlay"
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 0)
	overlay.BorderSizePixel = 0
	overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	overlay.BackgroundTransparency = 0.35
	overlay.ZIndex = (slot:IsA("GuiObject") and slot.ZIndex + 1) or 1
	overlay.Parent = slot

	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(135, 170, 255)),
	})
	shine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(1, 0.55),
	})
	shine.Rotation = 90
	shine.Parent = overlay

	return overlay
end

local function getSpellInitials(spellId)
	local def = getSpellDef(spellId)
	local source = (def and def.name) or spellId
	local initials = {}

	for token in string.gmatch(source, "[A-Za-z]+") do
		table.insert(initials, string.sub(string.upper(token), 1, 1))
	end

	if #initials == 0 then
		local compact = string.gsub(tostring(source), "%s+", "")
		return string.upper(string.sub(compact, 1, 2))
	end

	if #initials == 1 then
		local compact = string.gsub(tostring(source), "%s+", "")
		return string.upper(string.sub(compact, 1, math.min(2, #compact)))
	end

	return table.concat(initials, "", 1, math.min(2, #initials))
end

local function genericCooldown(spellId, level)
	if level <= 0 then
		return nil
	end

	local def = getSpellDef(spellId)
	local params = def and def.params
	if type(params) ~= "table" then
		return nil
	end

	for _, key in ipairs({ "interval", "spawnInterval", "spawnRate", "launchInterval", "spawnEvery", "fireRate" }) do
		local value = tonumber(params[key])
		if value and value > 0 then
			return value
		end
	end

	return nil
end

local function getCooldownDuration(spellId, level)
	local resolver = COOLDOWN_RESOLVERS[spellId]
	if resolver then
		return resolver(level)
	end
	return genericCooldown(spellId, level)
end

local function setSlotEmpty(index)
	local slot = slots[index]
	local textLabel = slotTextLabels[index]
	local levelLabel = levelLabels[index]
	local overlay = cooldownOverlays[index]
	local stroke = slotStrokes[index]

	displayedSpellIds[index] = nil

	if textLabel then
		textLabel.Text = EMPTY_SLOT_TEXT
		textLabel.TextTransparency = 0.4
		textLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end

	if levelLabel then
		levelLabel.Text = EMPTY_LEVEL_TEXT
		levelLabel.TextTransparency = 0.45
		levelLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end

	if overlay then
		overlay.Visible = false
		overlay.Size = UDim2.fromScale(1, 0)
	end

	if slot and slot:IsA("GuiObject") then
		slot.BackgroundTransparency = 0.25
	end

	if stroke then
		stroke.Color = EMPTY_STROKE_COLOR
		stroke.Transparency = 0.45
	end
end

local function setSlotSpell(index, spellId, level)
	local slot = slots[index]
	local textLabel = slotTextLabels[index]
	local levelLabel = levelLabels[index]
	local stroke = slotStrokes[index]
	local def = getSpellDef(spellId)
	local rarity = (def and def.rarity) or "Common"
	local color = RARITY_COLORS[rarity] or RARITY_COLORS.Common

	displayedSpellIds[index] = spellId

	if textLabel then
		textLabel.Text = getSpellInitials(spellId)
		textLabel.TextTransparency = 0
		textLabel.TextColor3 = color
		textLabel.TextScaled = true
		textLabel.BackgroundTransparency = 1
	end

	if levelLabel then
		levelLabel.Text = ("Lv. %d"):format(level)
		levelLabel.TextTransparency = 0
		levelLabel.TextColor3 = color
	end

	if slot and slot:IsA("GuiObject") then
		slot.BackgroundTransparency = 0.1
	end

	if stroke then
		stroke.Transparency = 0.1
	end
end

local function removeOwnedSpell(spellId)
	if not ownedLookup[spellId] then
		return
	end

	ownedLookup[spellId] = nil
	for index, ownedId in ipairs(ownedSpellOrder) do
		if ownedId == spellId then
			table.remove(ownedSpellOrder, index)
			break
		end
	end
end

local function addOwnedSpell(spellId)
	if ownedLookup[spellId] then
		return
	end

	ownedLookup[spellId] = true
	table.insert(ownedSpellOrder, spellId)
end

local function updateCooldownRecord(spellId, level, forceRestart)
	local duration = getCooldownDuration(spellId, level)
	if not duration or duration <= 0 then
		cooldownState[spellId] = nil
		return
	end

	local record = cooldownState[spellId]
	local now = spellClock()
	if not record then
		record = {
			startClock = now,
			duration = duration,
		}
		cooldownState[spellId] = record
		return
	end

	record.duration = duration
	if forceRestart then
		record.startClock = now
	end
end

local function rebuildOwnedSpellOrder()
	table.clear(ownedSpellOrder)
	table.clear(ownedLookup)

	for _, spellId in ipairs(allSpellIds) do
		if getSpellLevel(spellId) > 0 then
			addOwnedSpell(spellId)
		end
	end
end

local function refreshSlots()
	for index = 1, SLOT_COUNT do
		local spellId = ownedSpellOrder[index]
		if spellId then
			setSlotSpell(index, spellId, getSpellLevel(spellId))
		else
			setSlotEmpty(index)
		end
	end
end

local function onSpellLevelChanged(spellId)
	local level = getSpellLevel(spellId)

	if level > 0 then
		local isNewSpell = not ownedLookup[spellId]
		if isNewSpell then
			addOwnedSpell(spellId)
		end
		updateCooldownRecord(spellId, level, isNewSpell)
	else
		removeOwnedSpell(spellId)
		cooldownState[spellId] = nil
	end

	refreshSlots()
end

local function refreshCooldownVisuals(now)
	for index = 1, SLOT_COUNT do
		local spellId = displayedSpellIds[index]
		local overlay = cooldownOverlays[index]
		local stroke = slotStrokes[index]

		if not spellId or not overlay then
			continue
		end

		local record = cooldownState[spellId]
		if not record or not record.duration or record.duration <= 0 then
			overlay.Visible = false
			if stroke then
				local def = getSpellDef(spellId)
				local rarity = (def and def.rarity) or "Common"
				stroke.Color = RARITY_COLORS[rarity] or RARITY_COLORS.Common
			end
			continue
		end

		local elapsed = now - record.startClock
		if elapsed >= record.duration then
			record.startClock = now
			elapsed = 0
		end

		local progress = math.clamp(elapsed / record.duration, 0, 1)
		local remainingFill = 1 - progress

		overlay.Visible = remainingFill > 0.02
		overlay.Size = UDim2.fromScale(1, remainingFill)
		overlay.BackgroundTransparency = 0.2 + (progress * 0.45)

		if stroke then
			if progress >= 0.98 then
				stroke.Color = READY_STROKE_COLOR
			else
				stroke.Color = COOLING_STROKE_COLOR
			end
		end
	end
end

for index = 1, SLOT_COUNT do
	local slot = frame:WaitForChild(("Slot%d"):format(index))
	local levelLabel = frame:WaitForChild(("Lvl%d"):format(index))
	local textLabel = findSlotTextLabel(slot)

	if textLabel and slot:IsA("GuiObject") then
		textLabel.ZIndex = math.max(textLabel.ZIndex, slot.ZIndex + 2)
	end

	slots[index] = slot
	levelLabels[index] = levelLabel
	slotTextLabels[index] = textLabel
	slotStrokes[index] = ensureStroke(slot)
	cooldownOverlays[index] = ensureCooldownOverlay(slot, slotStrokes[index])
end

for spellId in pairs(SpellDefs.SPELLS or {}) do
	table.insert(allSpellIds, spellId)
end

table.sort(allSpellIds, function(a, b)
	local defA = getSpellDef(a)
	local defB = getSpellDef(b)

	local baseA = defA and defA.base == true
	local baseB = defB and defB.base == true
	if baseA ~= baseB then
		return baseA
	end

	local rankA = rarityRank(a)
	local rankB = rarityRank(b)
	if rankA ~= rankB then
		return rankA < rankB
	end

	local nameA = string.lower((defA and defA.name) or a)
	local nameB = string.lower((defB and defB.name) or b)
	return nameA < nameB
end)

rebuildOwnedSpellOrder()
for _, spellId in ipairs(allSpellIds) do
	local level = getSpellLevel(spellId)
	if level > 0 then
		updateCooldownRecord(spellId, level, true)
	end

	local watchedSpellId = spellId
	player:GetAttributeChangedSignal(("Spell_%s_Level"):format(watchedSpellId)):Connect(function()
		onSpellLevelChanged(watchedSpellId)
	end)
end

refreshSlots()
refreshCooldownVisuals(spellClock())

RunService.RenderStepped:Connect(function()
	refreshCooldownVisuals(spellClock())
end)
