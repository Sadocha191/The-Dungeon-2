-- LOCALSCRIPT: CharacterCreationUI.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/CharacterCreationUI (LocalScript)
-- FIX:
-- 1) Animacja "CS skrzynka" zawsze widoczna: czekamy na poprawne AbsoluteSize (RenderStepped)
-- 2) Szanse liczone poprawnie z Twojego Races.lua dla klasy Default (bo klasy nie wybierasz w UI)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenCharacterCreation = remoteEvents:WaitForChild("OpenCharacterCreation")
local CreateProfileRequest = remoteEvents:WaitForChild("CreateProfileRequest")
local CreateProfileResponse = remoteEvents:FindFirstChild("CreateProfileResponse")

local Races = require(ReplicatedStorage:WaitForChild("Races"))

-- ===== Colors =====
local rarityColor = {
	Common = Color3.fromRGB(220,220,220),
	Rare = Color3.fromRGB(34, 197, 94),
	Epic = Color3.fromRGB(168, 85, 247),
	Legendary = Color3.fromRGB(245, 158, 11),
	Mythic = Color3.fromRGB(244, 63, 94),
}

local function tierOf(raceName: string): string
	local def = Races.Defs[raceName]
	return (def and def.tier) or "Common"
end

local function colorOfRace(raceName: string): Color3
	return rarityColor[tierOf(raceName)] or Color3.fromRGB(245,245,245)
end

-- Tu specjalnie Default (bo klasy nie ma w UI)
local function getClassName(): string
	local c = plr:GetAttribute("Class")
	if typeof(c) == "string" and c ~= "" then return c end
	return "Default"
end

-- ===== Probability math =====
local function buildChancesForClass(className: string)
	local tierWeights = Races.ClassTierWeights[className] or Races.ClassTierWeights.Default
	local bias = Races.ClassRaceBias[className] or {}

	local tierTotal = 0
	for _, w in pairs(tierWeights) do tierTotal += w end
	if tierTotal <= 0 then tierTotal = 1 end

	local pTier = {}
	for tierKey, w in pairs(tierWeights) do
		pTier[tierKey] = (w / tierTotal)
	end

	local tierCandidates = {}
	local tierCandTotal = {}

	for raceName, def in pairs(Races.Defs) do
		local t = def.tier or "Common"
		tierCandidates[t] = tierCandidates[t] or {}
		local w = 1.0
		if bias[raceName] then w *= bias[raceName] end
		table.insert(tierCandidates[t], {name = raceName, w = w})
		tierCandTotal[t] = (tierCandTotal[t] or 0) + w
	end

	local list = {}
	for raceName, def in pairs(Races.Defs) do
		local t = def.tier or "Common"
		local pt = pTier[t] or 0
		local total = tierCandTotal[t] or 0

		local w = 1.0
		if bias[raceName] then w *= bias[raceName] end

		local prGivenTier = (total > 0) and (w / total) or 0
		local pr = pt * prGivenTier

		table.insert(list, {
			name = raceName,
			tier = t,
			p = pr,
			percent = pr * 100,
			color = rarityColor[t] or Color3.fromRGB(245,245,245),
		})
	end

	table.sort(list, function(a,b) return a.percent > b.percent end)
	return list
end

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "CharacterCreationUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui:SetAttribute("Modal", true)
gui.Parent = pg

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1,1)
dim.BackgroundColor3 = Color3.fromRGB(0,0,0)
dim.BackgroundTransparency = 0.45
dim.BorderSizePixel = 0
dim.Parent = gui

local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(1040, 460)
root.BackgroundTransparency = 1
root.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.fromOffset(0, -56)
title.Font = Enum.Font.GothamBold
title.TextSize = 32
title.TextColor3 = Color3.fromRGB(20, 20, 22)
title.TextStrokeTransparency = 0.9
title.Text = "Tworzenie postaci"
title.Parent = root

local function makePanel(size: UDim2, pos: UDim2)
	local p = Instance.new("Frame")
	p.Size = size
	p.Position = pos
	p.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	p.BackgroundTransparency = 0.12
	p.BorderSizePixel = 0
	p.Parent = root
	Instance.new("UICorner", p).CornerRadius = UDim.new(0, 14)
	return p
end

local infoPanel   = makePanel(UDim2.fromOffset(320, 360), UDim2.fromOffset(0, 70))
local centerPanel = makePanel(UDim2.fromOffset(380, 360), UDim2.fromOffset(330, 70))
local chancePanel = makePanel(UDim2.fromOffset(320, 360), UDim2.fromOffset(720, 70))

local function header(parent: Instance, text: string)
	local h = Instance.new("TextLabel")
	h.BackgroundTransparency = 1
	h.Size = UDim2.new(1, -24, 0, 34)
	h.Position = UDim2.fromOffset(12, 10)
	h.Font = Enum.Font.GothamBold
	h.TextSize = 24
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.TextColor3 = Color3.fromRGB(245, 245, 245)
	h.Text = text
	h.Parent = parent
	return h
end

header(infoPanel, "Informacje")
header(centerPanel, "Losowanie (jak skrzynka)")
header(chancePanel, "Szanse na rasy")

local infoText = Instance.new("TextLabel")
infoText.BackgroundTransparency = 1
infoText.Position = UDim2.fromOffset(12, 52)
infoText.Size = UDim2.new(1, -24, 1, -80)
infoText.Font = Enum.Font.Gotham
infoText.TextSize = 18
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Top
infoText.TextColor3 = Color3.fromRGB(220, 220, 220)
infoText.TextWrapped = true
infoText.Text = "Kliknij Losuj aby stworzyć postać.\nMożesz to zrobić tylko raz."
infoText.Parent = infoPanel

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(140, 40)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, -10, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(245,245,245)
closeBtn.Text = "Zamknij"
closeBtn.Parent = root
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 14)

-- Current race
local current = Instance.new("TextLabel")
current.BackgroundTransparency = 1
current.Position = UDim2.fromOffset(12, 52)
current.Size = UDim2.new(1, -24, 0, 36)
current.Font = Enum.Font.GothamBold
current.TextSize = 20
current.TextXAlignment = Enum.TextXAlignment.Left
current.TextColor3 = Color3.fromRGB(245,245,245)
current.Text = "Aktualna rasa: -"
current.Parent = centerPanel

-- Strip frame
local stripFrame = Instance.new("Frame")
stripFrame.Position = UDim2.fromOffset(12, 96)
stripFrame.Size = UDim2.new(1, -24, 0, 92)
stripFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
stripFrame.BackgroundTransparency = 0.25
stripFrame.BorderSizePixel = 0
stripFrame.Parent = centerPanel
Instance.new("UICorner", stripFrame).CornerRadius = UDim.new(0, 14)

local stripClip = Instance.new("Frame")
stripClip.Position = UDim2.fromOffset(10, 10)
stripClip.Size = UDim2.new(1, -20, 1, -20)
stripClip.BackgroundTransparency = 1
stripClip.ClipsDescendants = true
stripClip.Parent = stripFrame

local pointer = Instance.new("Frame")
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Position = UDim2.new(0.5, 0, 0.5, 0)
pointer.Size = UDim2.fromOffset(4, 58)
pointer.BackgroundColor3 = Color3.fromRGB(245,245,245)
pointer.BorderSizePixel = 0
pointer.Parent = stripFrame
Instance.new("UICorner", pointer).CornerRadius = UDim.new(0, 999)

local strip = Instance.new("Frame")
strip.BackgroundTransparency = 1
strip.Size = UDim2.fromOffset(1, 1)
strip.Position = UDim2.fromOffset(0, 0)
strip.Parent = stripClip

local CARD_W = 180
local CARD_H = 64
local GAP = 12

local function makeCard(text: string)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(CARD_W, CARD_H)
	f.BackgroundColor3 = Color3.fromRGB(14,14,16)
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 14)

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1,1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 20
	t.TextColor3 = colorOfRace(text)
	t.Text = text
	t.Parent = f
	return f
end

local function clearStrip()
	for _, c in ipairs(strip:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

local rollBtn = Instance.new("TextButton")
rollBtn.Size = UDim2.fromOffset(240, 44)
rollBtn.AnchorPoint = Vector2.new(0.5, 1)
rollBtn.Position = UDim2.new(0.5, 0, 1, -18)
rollBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
rollBtn.BorderSizePixel = 0
rollBtn.Font = Enum.Font.GothamBold
rollBtn.TextSize = 20
rollBtn.TextColor3 = Color3.fromRGB(245,245,245)
rollBtn.Text = "Losuj"
rollBtn.Parent = centerPanel
Instance.new("UICorner", rollBtn).CornerRadius = UDim.new(0, 14)

local okBtn = Instance.new("TextButton")
okBtn.Size = UDim2.fromOffset(240, 44)
okBtn.AnchorPoint = Vector2.new(0.5, 1)
okBtn.Position = UDim2.new(0.5, 0, 1, -18)
okBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 44)
okBtn.BorderSizePixel = 0
okBtn.Font = Enum.Font.GothamBold
okBtn.TextSize = 20
okBtn.TextColor3 = Color3.fromRGB(245,245,245)
okBtn.Text = "OK"
okBtn.Visible = false
okBtn.Parent = centerPanel
Instance.new("UICorner", okBtn).CornerRadius = UDim.new(0, 14)

local list = Instance.new("ScrollingFrame")
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(12, 52)
list.Size = UDim2.new(1, -24, 1, -70)
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.fromOffset(0,0)
list.Parent = chancePanel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = list

local function rebuildChancesUI(chances)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	local totalH = 0
	for _, r in ipairs(chances) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 24)
		t.Font = Enum.Font.GothamBold
		t.TextSize = 18
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = r.color
		t.Text = ("%s (%.2f%%)"):format(r.name, r.percent)
		t.Parent = list
		totalH += 30
	end
	list.CanvasSize = UDim2.fromOffset(0, math.max(0, totalH))
end

-- ===== state =====
local rolling = false
local createdOnce = false
local finalRace: string? = nil

local function setCurrentRaceText(raceName: string)
	current.Text = ("Aktualna rasa: %s"):format(raceName)
	current.TextColor3 = colorOfRace(raceName)
end

local function waitForNonZeroSize(frame: GuiObject, maxFrames: number)
	for _ = 1, maxFrames do
		if frame.AbsoluteSize.X > 50 and frame.AbsoluteSize.Y > 20 then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return frame.AbsoluteSize.X > 50
end

local function playCaseAnimation(targetRace: string, chances)
	clearStrip()

	-- WAŻNE: poczekaj aż layout się policzy
	waitForNonZeroSize(stripClip, 60)
	local visibleW = stripClip.AbsoluteSize.X

	local cardsCount = 45
	local targetIndex = cardsCount - 6

	local function weightedPick()
		local total = 0
		for _, r in ipairs(chances) do total += r.p end
		local roll = math.random() * total
		local acc = 0
		for _, r in ipairs(chances) do
			acc += r.p
			if roll <= acc then return r.name end
		end
		return chances[#chances].name
	end

	local x = 0
	for i = 1, cardsCount do
		local name = (i == targetIndex) and targetRace or weightedPick()
		local card = makeCard(name)
		card.Position = UDim2.fromOffset(x, 0)
		card.Parent = strip
		x += CARD_W + GAP
	end
	strip.Size = UDim2.fromOffset(x, CARD_H)

	local pointerX = visibleW * 0.5
	local targetCenterX = ((targetIndex-1) * (CARD_W + GAP)) + (CARD_W * 0.5)
	local targetOffset = pointerX - targetCenterX

	strip.Position = UDim2.fromOffset(pointerX + 80, 0)

	local tween = TweenService:Create(strip, TweenInfo.new(2.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(targetOffset, 0)
	})
	tween:Play()
	tween.Completed:Wait()
end

local function openUI()
	gui.Enabled = true
	rolling = false
	finalRace = nil
	rollBtn.Active = true
	rollBtn.Text = "Losuj"

	local cls = getClassName()
	local chances = buildChancesForClass(cls)
	rebuildChancesUI(chances)

	local r = plr:GetAttribute("Race")
	setCurrentRaceText(typeof(r) == "string" and r or "-")

	local hasChar = plr:GetAttribute("HasCharacter")
	if hasChar == true then
		createdOnce = true
		rollBtn.Visible = false
		okBtn.Visible = true
	else
		createdOnce = false
		rollBtn.Visible = true
		okBtn.Visible = false
	end

	clearStrip()
end

local function closeUI()
	gui.Enabled = false
	rolling = false
end

closeBtn.MouseButton1Click:Connect(closeUI)
okBtn.MouseButton1Click:Connect(closeUI)
OpenCharacterCreation.OnClientEvent:Connect(openUI)

plr:GetAttributeChangedSignal("Race"):Connect(function()
	if not gui.Enabled then return end
	local r = plr:GetAttribute("Race")
	if typeof(r) ~= "string" or r == "" then return end
	setCurrentRaceText(r)
	if rolling then
		finalRace = r
		rolling = false
		rollBtn.Visible = false
		okBtn.Visible = true
	end
end)

if CreateProfileResponse and CreateProfileResponse:IsA("RemoteEvent") then
	CreateProfileResponse.OnClientEvent:Connect(function(payload)
		if not gui.Enabled then return end
		if typeof(payload) == "table" and typeof(payload.race) == "string" then
			plr:SetAttribute("Race", payload.race)
		end
	end)
end

rollBtn.MouseButton1Click:Connect(function()
	if rolling or createdOnce then return end

	rolling = true
	rollBtn.Active = false
	rollBtn.Text = "Losowanie..."

	local cls = getClassName()
	local chances = buildChancesForClass(cls)

	CreateProfileRequest:FireServer({})

	-- czekamy na final race z serwera
	local start = os.clock()
	local before = plr:GetAttribute("Race")
	while os.clock() - start < 6 do
		local now = plr:GetAttribute("Race")
		if typeof(now) == "string" and now ~= "" and now ~= before then
			finalRace = now
			break
		end
		task.wait(0.05)
	end

	if typeof(finalRace) == "string" then
		playCaseAnimation(finalRace, chances)
		createdOnce = true
		rollBtn.Visible = false
		okBtn.Visible = true
	else
		rolling = false
		rollBtn.Active = true
		rollBtn.Text = "Losuj"
	end
end)

print("[CharacterCreationUI] Ready (fixed animation sizing)")
