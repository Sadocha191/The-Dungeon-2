-- UpgradesClient.localscript.lua (Level1 / StarterGui / UpgradesGUI)
-- Pokazuje 3 oferty ze SpellEvent (server), pozwala Pick/Skip/Reroll/Banish.
-- Blokuje movement podczas okna.

local UIScale = script.Parent:FindFirstChildOfClass("UIScale")
if not UIScale then
	UIScale = Instance.new("UIScale")
	UIScale.Parent = script.Parent
end

local camera = workspace.CurrentCamera
local function updateScale()
	local v = camera.ViewportSize
	local minAxis = math.min(v.X, v.Y)

	-- 720px jako punkt odniesienia; clamp �eby nie by�o mikroskopijne / gigantyczne
	local s = math.clamp(minAxis / 720, 0.75, 1.15)
	UIScale.Scale = s
end

updateScale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpellEvent = Remotes:WaitForChild("SpellEvent")

local PauseState = ReplicatedStorage:WaitForChild("PauseState") -- BoolValue
local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
assert(modFolder and modFolder:IsA("Folder"), "Missing ReplicatedStorage.ModuleScripts/ModuleScript")
local SpellDefs = require(modFolder:WaitForChild("SpellDefinitions"))


local SHORT_LORE_BY_SPELL = {
	FireBolt = "A cinder cast from the first dying sun.",
	EmberOrbit = "Restless embers circle those marked by flame.",
	FlameBurst = "Bottled wrath erupts from a burning sigil.",
	ScorchField = "The earth remembers every fire laid upon it.",
	InfernoBeam = "A furnace opened into one merciless line.",

	VoltNeedle = "A splinter of storm seeking a living heart.",
	StaticHalo = "Captured thunder circles its chosen bearer.",
	ShockBurst = "The air breaks before the thunder arrives.",
	StormField = "A chained tempest claws at the ground.",
	ThunderRay = "Skyfire focused through a forbidden conductor.",

	GaleKnife = "A whisper sharpened into an invisible blade.",
	WindRing = "The old winds guard those who never stand still.",
	WindBlade = "One gesture cleaves the air itself.",
	Tornado = "A hungry wind gathers dust, steel, and bone.",
	Jetstream = "The breath of the high peaks made violent.",

	WaterShard = "A frozen tear drawn from a drowned saint.",
	TideOrbit = "The moonbound tide circles without a shore.",
	FrostSplash = "Winter blooms where the water breaks.",
	RiptidePool = "Still water hides a current without mercy.",
	TidalBeam = "The deep sea forced through a narrow path.",

	StoneSpike = "The mountain answers with a single fang.",
	RockOrbit = "Ancient stones remember their guardian's oath.",
	QuakeBurst = "The sleeping earth lashes out in anger.",
	BramblePatch = "Cursed roots drink deeply from fallen blood.",
	FaultLine = "A buried wound tears open beneath the world.",

	VoidShard = "A fragment chipped from the edge of nothing.",
	AbyssHalo = "A small eclipse worn as forbidden protection.",
	NullBurst = "For one heartbeat, existence forgets itself.",
	Singularity = "A starving wound pulls all things inward.",
	EntropyRay = "The end of all form, narrowed into light.",

	RadiantBolt = "A verdict of light delivered without mercy.",
	HaloOrbit = "Silent halos guard the path of the chosen.",
	Sunburst = "A newborn dawn erupts among the unworthy.",
	ConsecratedGround = "No darkness stands willingly on blessed soil.",
	SolarBeam = "Noon narrowed into a single merciless line.",

	AxeThrow = "The blade remembers the hand that cast it.",
	GuardHammers = "Oathbound hammers circle their final ward.",
	GroundSlam = "One blow wakes the anger beneath all stone.",
	CaltropField = "A hunter's patience scattered across the earth.",
	WhirlwindSlash = "Steel becomes a storm in practiced hands.",

	FireTornado = "Flame learns the hunger of the storm.",
	StormSurge = "Water carries thunder through every living thing.",
	MagmaCrash = "Earth and fire meet in a violent birth.",
	RadiantTempest = "Holy light rides the wrath of the wind.",
	VoidFlood = "The tide returns from somewhere beyond reality.",
	ThunderQuake = "The earth roars with the voice of storms.",
	SolarFlare = "Two suns collide in a blinding judgment.",
}

local function getShortLore(spellId: string, def): string
	local authored = SHORT_LORE_BY_SPELL[spellId]
	if authored then
		return authored
	end

	local lore = tostring((def and def.loreDescription) or "")
	if lore ~= "" then
		return lore
	end

	return "An old power awakened once more."
end

-- GUI refs (Twoja struktura)
local gui = script.Parent
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui:SetAttribute("Modal", true) -- used by camera/mouse lock script

local main = gui:WaitForChild("Main") -- ImageLabel
main.Visible = true
local bottom = main:WaitForChild("BottomButtons")
local btnSkip = bottom:WaitForChild("Skip")
local btnReroll = bottom:WaitForChild("Reroll")
local btnBanish = bottom:WaitForChild("Banish")

-- waiting overlay (created if missing)
local waitingLabel = main:FindFirstChild("WaitingLabel")
if not waitingLabel then
	waitingLabel = Instance.new("TextLabel")
	waitingLabel.Name = "WaitingLabel"
	waitingLabel.BackgroundTransparency = 0.35
	waitingLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
	waitingLabel.TextColor3 = Color3.fromRGB(255,255,255)
	waitingLabel.Font = Enum.Font.GothamBold
	waitingLabel.TextScaled = true
	waitingLabel.Size = UDim2.new(0.6, 0, 0.12, 0)
	waitingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	waitingLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	waitingLabel.Visible = false
	waitingLabel.ZIndex = 50
	waitingLabel.Parent = main
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = waitingLabel
end

local function isMultiRun()
	local v = plr:GetAttribute("RunMode")
	return typeof(v) == "string" and string.lower(v) == "multi"
end

-- kontener ofert: u Ciebie jest UpgradeOffers
local offersContainer = main:FindFirstChild("UpgradeOffers") or main:FindFirstChild("Cards")
assert(offersContainer, "Missing UpgradeOffers/Cards container under Main")

local slot1 = offersContainer:WaitForChild("CardSlot1")
local slot2 = offersContainer:WaitForChild("CardSlot2")
local slot3 = offersContainer:WaitForChild("CardSlot3")
local slots = { slot1, slot2, slot3 }

-- Template card (ImageButton) with:
-- CardTemplate
--  + DescBox (Frame) -> Desc (TextLabel)
--  L TitleBox (Frame) -> Title (TextLabel)
local cardTemplate = offersContainer:WaitForChild("CardTemplate")
cardTemplate.Visible = false

-- rarity images: ReplicatedStorage/Assets/UpgradeIcons/(Common/Uncommon/Rare/Epic)
local iconsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UpgradeIcons")
local rarityImage = {
	Common = iconsFolder:WaitForChild("Common").Image,
	Uncommon = iconsFolder:WaitForChild("Uncommon").Image,
	Rare = iconsFolder:WaitForChild("Rare").Image,
	Epic = iconsFolder:WaitForChild("Epic").Image,
}

local currentToken: string? = nil
local banishMode = false
local choiceLockedUntil = 0 -- os.clock() time

local function setButtonEnabled(btn: GuiObject, enabled: boolean)
	if btn:IsA("GuiButton") then
		btn.Active = enabled
		btn.AutoButtonColor = enabled
	end
	if btn:IsA("ImageButton") then
		btn.ImageTransparency = enabled and 0 or 0.45
	end
	if btn:IsA("TextButton") then
		btn.TextTransparency = enabled and 0 or 0.35
	end
	for _, d in ipairs(btn:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			d.TextTransparency = enabled and 0 or 0.35
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			d.ImageTransparency = enabled and 0 or 0.45
		end
	end
end

local function updateRerollButtonState()
	local rerollsUsed = math.max(0, math.floor(tonumber(plr:GetAttribute("RunRerollsUsed")) or 0))
	local available = currentToken ~= nil and rerollsUsed < 1
	setButtonEnabled(btnReroll, available)
end

-- movement lock
local savedWalkSpeed, savedJumpPower, savedJumpHeight
local movementLocked = false

local function getHumanoid()
	local char = plr.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end


local function applyHumanoidLock(hum, on)
	if not hum then return end
	if on then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
	else
		if savedWalkSpeed ~= nil then hum.WalkSpeed = savedWalkSpeed end
		if savedJumpPower ~= nil then hum.JumpPower = savedJumpPower end
		if savedJumpHeight ~= nil then hum.JumpHeight = savedJumpHeight end
	end
end

local function lockMovement(on: boolean)
	if on then
		if movementLocked then
			-- already locked (e.g. reroll re-renders offers). Don't overwrite saved values.
			applyHumanoidLock(getHumanoid(), true)
			return
		end
		movementLocked = true
		-- Sink standard movement inputs
		ContextActionService:BindActionAtPriority(
			"UpgradeMenuLock",
			function() return Enum.ContextActionResult.Sink end,
			false,
			9999,
			Enum.PlayerActions.CharacterForward,
			Enum.PlayerActions.CharacterBackward,
			Enum.PlayerActions.CharacterLeft,
			Enum.PlayerActions.CharacterRight,
			Enum.PlayerActions.CharacterJump
		)

		local hum = getHumanoid()
		if hum then
			savedWalkSpeed = hum.WalkSpeed
			savedJumpPower = hum.JumpPower
			savedJumpHeight = hum.JumpHeight
			applyHumanoidLock(hum, true)
		end
	else
		movementLocked = false
		ContextActionService:UnbindAction("UpgradeMenuLock")
		applyHumanoidLock(getHumanoid(), false)
		savedWalkSpeed, savedJumpPower, savedJumpHeight = nil, nil, nil
	end
end

local function setBanishButtonState(on: boolean)
	-- Prosty feedback bez przebudowy UI: przyciemnij/rozja�nij
	if on then
		btnBanish.ImageTransparency = 0
	else
		btnBanish.ImageTransparency = 0
	end
end

local function hideMenu()
	gui.Enabled = false
	main.Visible = true
	lockMovement(false)
	currentToken = nil
	banishMode = false
	setBanishButtonState(false)
	updateRerollButtonState()
end

local function showMenu()
	main.Visible = true
	gui.Enabled = true
	lockMovement(true)
	choiceLockedUntil = os.clock()
end

local function clearSlot(slot: Instance)
	for _, ch in ipairs(slot:GetChildren()) do
		-- keep constraints/layout helpers that belong to the slot
		if ch:IsA("UIAspectRatioConstraint") or ch:IsA("UIListLayout") or ch:IsA("UIGridLayout") or ch:IsA("UIPadding") then
			continue
		end
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
end

local STAT_FIELDS = {
	{ key = "damage", label = "Damage", decimals = 1 },
	{ key = "cooldown", label = "Cooldown", decimals = 2, suffix = "s" },
	{ key = "count", label = "Count", integer = true },
	{ key = "pierce", label = "Pierce", integer = true },
	{ key = "radius", label = "Radius", decimals = 1 },
	{ key = "duration", label = "Duration", decimals = 1, suffix = "s" },
	{ key = "range", label = "Range", decimals = 1 },
	{ key = "width", label = "Width", decimals = 1 },
}

local function escapeRichText(value: any): string
	local text = tostring(value or "")
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	return text
end

local function colorToHex(color: Color3): string
	local r = math.clamp(math.floor(color.R * 255 + 0.5), 0, 255)
	local g = math.clamp(math.floor(color.G * 255 + 0.5), 0, 255)
	local b = math.clamp(math.floor(color.B * 255 + 0.5), 0, 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

local function compactText(value: any, maxLength: number): string
	local text = tostring(value or "")
	text = string.gsub(text, "[\r\n]+", " ")
	text = string.gsub(text, "%s+", " ")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	if #text <= maxLength then
		return text
	end
	local shortened = string.sub(text, 1, maxLength - 1)
	local lastSpace = string.match(shortened, "^.*()%s")
	if lastSpace and lastSpace > math.floor(maxLength * 0.65) then
		shortened = string.sub(shortened, 1, lastSpace - 1)
	end
	return shortened .. "…"
end

local function formatStatValue(value: any, field): string
	local numberValue = tonumber(value) or 0
	local formatted
	if field.integer then
		formatted = tostring(math.max(0, math.floor(numberValue + 0.5)))
	else
		local decimals = tonumber(field.decimals) or 1
		if math.abs(numberValue - math.floor(numberValue + 0.5)) < 0.01 then
			formatted = tostring(math.floor(numberValue + 0.5))
		else
			formatted = string.format("%." .. tostring(decimals) .. "f", numberValue)
		end
	end
	return formatted .. tostring(field.suffix or "")
end

local function getSpellState(spellId: string)
	local level = math.max(0, math.floor(tonumber(plr:GetAttribute(("Spell_%s_Level"):format(spellId))) or 0))
	local baseMultiplier = tonumber(plr:GetAttribute(("Spell_%s_BaseMultiplier"):format(spellId))) or 1
	if baseMultiplier <= 0 then
		baseMultiplier = 1
	end
	return {
		level = level,
		upgradePower = math.max(0, tonumber(plr:GetAttribute(("Spell_%s_UpgradePower"):format(spellId))) or 0),
		baseMultiplier = baseMultiplier,
		basePower = math.max(0, tonumber(plr:GetAttribute(("Spell_%s_BasePower"):format(spellId))) or 0),
	}
end

local function buildStartingStatLines(stats): {string}
	local lines = {}
	for _, field in ipairs(STAT_FIELDS) do
		local value = tonumber(stats and stats[field.key]) or 0
		local shouldShow = field.key == "damage" or field.key == "cooldown" or value > 0
		if shouldShow then
			table.insert(lines, string.format(
				"<font color=\"#AEB4C2\">%s</font>  <b>%s</b>",
				escapeRichText(field.label),
				escapeRichText(formatStatValue(value, field))
				))
		end
		if #lines >= 4 then
			break
		end
	end
	return lines
end

local function buildChangedStatLines(beforeStats, afterStats): {string}
	local lines = {}
	for _, field in ipairs(STAT_FIELDS) do
		local beforeValue = tonumber(beforeStats and beforeStats[field.key]) or 0
		local afterValue = tonumber(afterStats and afterStats[field.key]) or 0
		local threshold = field.integer and 0.49 or 0.005
		if math.abs(afterValue - beforeValue) > threshold then
			table.insert(lines, string.format(
				"<font color=\"#AEB4C2\">%s</font>  %s  →  <font color=\"#9DFFB4\"><b>%s</b></font>",
				escapeRichText(field.label),
				escapeRichText(formatStatValue(beforeValue, field)),
				escapeRichText(formatStatValue(afterValue, field))
				))
		end
		if #lines >= 4 then
			break
		end
	end
	if #lines == 0 then
		table.insert(lines, "<font color=\"#9DFFB4\"><b>Improves the spell's core power.</b></font>")
	end
	return lines
end

local function getCombinationForOffer(offer, spellId: string)
	if offer.combinationId and SpellDefs.GetCombinationById then
		local byId = SpellDefs.GetCombinationById(tostring(offer.combinationId))
		if byId then
			return byId
		end
	end
	if SpellDefs.GetCombinationForResult then
		return SpellDefs.GetCombinationForResult(spellId)
	end
	return nil
end

local function buildComboState(combo)
	local state = {
		level = 1,
		upgradePower = 1.25,
		baseMultiplier = 1,
		basePower = 1.0,
	}
	for _, ingredientId in ipairs((combo and combo.ingredients) or {}) do
		local ingredientState = getSpellState(tostring(ingredientId))
		state.upgradePower += ingredientState.upgradePower
		state.baseMultiplier = math.max(state.baseMultiplier, ingredientState.baseMultiplier)
		state.basePower = math.max(state.basePower, ingredientState.basePower)
	end
	state.baseMultiplier += 0.08
	state.basePower += 0.75
	return state
end

local function buildSynergyLine(offer, spellId: string): string?
	if offer.offerType == "combination" then
		local combo = getCombinationForOffer(offer, spellId)
		if combo then
			local ingredientNames = {}
			for _, ingredientId in ipairs(combo.ingredients or {}) do
				local ingredientDef = SpellDefs.GetSpell and SpellDefs.GetSpell(tostring(ingredientId)) or nil
				table.insert(ingredientNames, ingredientDef and ingredientDef.name or tostring(ingredientId))
			end
			if #ingredientNames > 0 then
				return "FUSION: " .. table.concat(ingredientNames, " + ")
			end
		end
		return "FUSION SPELL"
	end

	local resultId = tostring(offer.synergyResult or "")
	if resultId == "" then
		return nil
	end
	local resultDef = SpellDefs.GetSpell and SpellDefs.GetSpell(resultId) or nil
	local otherName
	if SpellDefs.GetSynergiesFor then
		for _, synergy in ipairs(SpellDefs.GetSynergiesFor(spellId) or {}) do
			if synergy.resultId == resultId then
				for _, ingredientId in ipairs(synergy.ingredients or {}) do
					if ingredientId ~= spellId and getSpellState(tostring(ingredientId)).level > 0 then
						local ingredientDef = SpellDefs.GetSpell(tostring(ingredientId))
						otherName = ingredientDef and ingredientDef.name or tostring(ingredientId)
						break
					end
				end
			end
		end
	end
	if otherName then
		return string.format("COMBO: + %s → %s", otherName, resultDef and resultDef.name or resultId)
	end
	return string.format("COMBO AVAILABLE: %s", resultDef and resultDef.name or resultId)
end

local function buildOfferBody(offer): (string, string)
	local spellId = tostring(offer.spellId or "")
	local def = SpellDefs.GetSpell and SpellDefs.GetSpell(spellId) or nil
	if not def then
		return escapeRichText(tostring(offer.desc or "")), tostring(offer.subtitle or "Upgrade")
	end

	local accent = typeof(offer.color) == "Color3" and offer.color or SpellDefs.GetSpellColor(def)
	local accentHex = colorToHex(accent)
	local meta = string.upper(string.format("%s  •  %s  •  %s", def.element or "Spell", def.spellType or "Magic", def.attackType or "Effect"))
	local description = compactText(getShortLore(spellId, def), 90)
	local comboLine = buildSynergyLine(offer, spellId)
	local statLines = {}
	local levelLine = ""
	local sectionTitle = ""
	local subtitle = tostring(offer.subtitle or "Upgrade")

	if offer.offerType == "new" then
		local product = SpellDefs.GetProduct and SpellDefs.GetProduct(tostring(offer.productId or "")) or nil
		local state = {
			level = 1,
			upgradePower = 0,
			baseMultiplier = tonumber(product and product.baseMultiplier) or 1,
			basePower = tonumber(product and product.basePower) or 0,
		}
		local stats = SpellDefs.ComputeRuntimeStats(def, state)
		statLines = buildStartingStatLines(stats)
		levelLine = "LV. 1"
		sectionTitle = "STATS"
	elseif offer.offerType == "combination" then
		local combo = getCombinationForOffer(offer, spellId)
		local stats = SpellDefs.ComputeRuntimeStats(def, buildComboState(combo))
		statLines = buildStartingStatLines(stats)
		levelLine = "LV. 1"
		sectionTitle = "STATS"
		subtitle = "COMBINATION"
	else
		local currentState = getSpellState(spellId)
		local nextState = {
			level = math.clamp(currentState.level + 1, 1, tonumber(def.maxLevel) or 6),
			upgradePower = currentState.upgradePower,
			baseMultiplier = currentState.baseMultiplier,
			basePower = currentState.basePower,
		}
		local qualityId = tostring(offer.quality or "Common")
		local qualityDef = SpellDefs.UPGRADE_QUALITIES and SpellDefs.UPGRADE_QUALITIES[qualityId] or nil
		nextState.upgradePower += tonumber(qualityDef and qualityDef.power) or 1
		local beforeStats = SpellDefs.ComputeRuntimeStats(def, currentState)
		local afterStats = SpellDefs.ComputeRuntimeStats(def, nextState)
		statLines = buildChangedStatLines(beforeStats, afterStats)
		levelLine = string.format("LV. %d  →  LV. %d", currentState.level, nextState.level)
		sectionTitle = "WHAT CHANGES"
	end

	local parts = {
		string.format("<font color=\"%s\"><b>%s</b></font>", accentHex, escapeRichText(meta)),
		string.format("<font color=\"#FFFFFF\"><b>%s</b></font>", escapeRichText(levelLine)),
		"",
		escapeRichText(description),
		"",
		string.format("<font color=\"#D9C9FF\"><b>%s</b></font>", escapeRichText(sectionTitle)),
	}
	for _, line in ipairs(statLines) do
		table.insert(parts, line)
	end
	if comboLine then
		table.insert(parts, "")
		table.insert(parts, string.format("<font color=\"#FFD477\"><b>%s</b></font>", escapeRichText(comboLine)))
	end
	return table.concat(parts, "\n"), subtitle
end

local function fitDescriptionText(label: TextLabel)
	task.defer(function()
		if not label.Parent then return end
		for size = 14, 10, -1 do
			label.TextSize = size
			task.wait()
			if label.TextFits then
				break
			end
		end
	end)
end

local function mountCardInSlot(slot: Frame, offer)
	clearSlot(slot)

	local card = cardTemplate:Clone()
	card.Name = "Card"
	card.Visible = true
	card.Parent = slot
	card.Size = UDim2.fromScale(1, 1)
	card.Position = UDim2.fromScale(0, 0)
	card.BackgroundTransparency = 1
	card.AutoButtonColor = false

	-- Rarity controls only the card frame. Element color is used inside the content.
	card.Image = rarityImage[tostring(offer.cardQuality or offer.quality or "Common")] or rarityImage.Common

	local titleLabel = card:WaitForChild("TitleBox"):WaitForChild("Title")
	local descLabel = card:WaitForChild("DescBox"):WaitForChild("Desc")
	local accent = typeof(offer.color) == "Color3" and offer.color or Color3.fromRGB(255, 255, 255)
	local bodyText, subtitle = buildOfferBody(offer)

	titleLabel.Text = string.format("%s\n%s", tostring(offer.name or offer.spellId or "Spell"), string.upper(subtitle))
	titleLabel.TextColor3 = accent
	titleLabel.TextWrapped = true

	descLabel.RichText = true
	descLabel.Text = bodyText
	descLabel.TextColor3 = Color3.fromRGB(235, 237, 244)
	descLabel.TextScaled = false
	descLabel.TextSize = 14
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.BackgroundTransparency = 1
	if descLabel:IsA("TextLabel") then
		descLabel.LineHeight = 1.05
	end
	fitDescriptionText(descLabel)

	return card
end

local function renderOffers(token: string, offers: {any})
	currentToken = token
	banishMode = false
	setBanishButtonState(false)

	for i = 1, 3 do
		local slot = slots[i]
		local off = offers[i]
		if not off then
			clearSlot(slot)
			slot.Visible = false
		else
			slot.Visible = true

			local spellId = tostring(off.spellId)

			local cardBtn = mountCardInSlot(slot, off)

			cardBtn.MouseButton1Click:Connect(function()
				if os.clock() < choiceLockedUntil then return end
				if not currentToken then return end

				if banishMode then
					SpellEvent:FireServer({ type="banish", token=currentToken, spellId=spellId })
					banishMode = false
					setBanishButtonState(false)
					return
				end

				SpellEvent:FireServer({ type="pick", token=currentToken, spellId=spellId })

				if isMultiRun() then
					-- pokazuj waiting a� serwer zwolni pauz� (PauseState=false)
					choiceLockedUntil = os.clock() + 9999
					if waitingLabel then
						waitingLabel.Text = "Waiting for other players..."
						waitingLabel.Visible = true
					end

					-- schowaj sloty, zablokuj guziki
					for _, s in ipairs(slots) do s.Visible = false end
					btnSkip.Active = false; btnReroll.Active = false; btnBanish.Active = false
					return
				end

				hideMenu()
			end)
		end
	end

	showMenu()
	updateRerollButtonState()
end

btnSkip.MouseButton1Click:Connect(function()
	if os.clock() < choiceLockedUntil then return end
	if not currentToken then return end
	SpellEvent:FireServer({ type="skip", token=currentToken })
	hideMenu()
end)

btnReroll.MouseButton1Click:Connect(function()
	if os.clock() < choiceLockedUntil then return end
	if not currentToken then return end
	if (tonumber(plr:GetAttribute("RunRerollsUsed")) or 0) >= 1 then return end
	SpellEvent:FireServer({ type="reroll", token=currentToken })
end)

btnBanish.MouseButton1Click:Connect(function()
	if os.clock() < choiceLockedUntil then return end
	if not currentToken then return end
	banishMode = not banishMode
	setBanishButtonState(banishMode)
end)

gui.Enabled = false
main.Visible = true
updateRerollButtonState()

-- If the player respawns while the menu is open, keep them locked.
plr.CharacterAdded:Connect(function()
	if gui.Enabled then
		lockMovement(true)
	else
		lockMovement(false)
	end
end)

plr:GetAttributeChangedSignal("RunRerollsUsed"):Connect(function()
	updateRerollButtonState()
end)

SpellEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type == "offer" and typeof(payload.token) == "string" and typeof(payload.offers) == "table" then
		renderOffers(payload.token, payload.offers)
	end
end)


-- auto-close waiting when pause ends
PauseState:GetPropertyChangedSignal("Value"):Connect(function()
	if PauseState.Value == false and gui.Enabled == true then
		for _, s in ipairs(slots) do s.Visible = true end
		btnSkip.Active = true; btnReroll.Active = true; btnBanish.Active = true
		hideMenu()
	end
end)
