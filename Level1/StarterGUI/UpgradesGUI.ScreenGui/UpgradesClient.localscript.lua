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

	-- 720px jako punkt odniesienia; clamp żeby nie było mikroskopijne / gigantyczne
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

local modFolder = ReplicatedStorage:FindFirstChild("ModuleScripts") or ReplicatedStorage:FindFirstChild("ModuleScript")
assert(modFolder and modFolder:IsA("Folder"), "Missing ReplicatedStorage.ModuleScripts/ModuleScript")
local SpellDefs = require(modFolder:WaitForChild("SpellDefinitions"))

-- GUI refs (Twoja struktura)
local gui = script.Parent
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local main = gui:WaitForChild("Main") -- ImageLabel
local bottom = main:WaitForChild("BottomButtons")
local btnSkip = bottom:WaitForChild("Skip")
local btnReroll = bottom:WaitForChild("Reroll")
local btnBanish = bottom:WaitForChild("Banish")

-- kontener ofert: u Ciebie jest UpgradeOffers
local offersContainer = main:FindFirstChild("UpgradeOffers") or main:FindFirstChild("Cards")
assert(offersContainer, "Missing UpgradeOffers/Cards container under Main")

local slot1 = offersContainer:WaitForChild("CardSlot1")
local slot2 = offersContainer:WaitForChild("CardSlot2")
local slot3 = offersContainer:WaitForChild("CardSlot3")
local slots = { slot1, slot2, slot3 }

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

-- movement lock
local savedWalkSpeed, savedJumpPower, savedJumpHeight

local function getHumanoid()
	local char = plr.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function lockMovement(on: boolean)
	if on then
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
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.JumpHeight = 0
		end
	else
		ContextActionService:UnbindAction("UpgradeMenuLock")
		local hum = getHumanoid()
		if hum then
			if savedWalkSpeed then hum.WalkSpeed = savedWalkSpeed end
			if savedJumpPower then hum.JumpPower = savedJumpPower end
			if savedJumpHeight then hum.JumpHeight = savedJumpHeight end
		end
	end
end

local function hideMenu()
	main.Visible = false
	lockMovement(false)
	currentToken = nil
	banishMode = false
end

local function showMenu()
	main.Visible = true
	lockMovement(true)
end

local function clearSlot(slot: Instance)
	for _, ch in ipairs(slot:GetChildren()) do
		if ch.Name == "CardButton" or ch.Name == "Title" or ch.Name == "Desc" or ch.Name == "RarityText" then
			ch:Destroy()
		end
	end
end

local function makeCardInSlot(slot: Frame)
	clearSlot(slot)

	local cardBtn = Instance.new("ImageButton")
	cardBtn.Name = "CardButton"
	cardBtn.Size = UDim2.fromScale(1, 1)
	cardBtn.Position = UDim2.fromScale(0, 0)
	cardBtn.BackgroundTransparency = 1
	cardBtn.AutoButtonColor = false
	cardBtn.ScaleType = Enum.ScaleType.Stretch
	cardBtn.Parent = slot

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 16, 0, 16)
	title.Size = UDim2.new(1, -32, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(245,245,245)
	title.Text = ""
	title.Parent = cardBtn

	local rarityText = Instance.new("TextLabel")
	rarityText.Name = "RarityText"
	rarityText.BackgroundTransparency = 1
	rarityText.Position = UDim2.new(0, 16, 0, 46)
	rarityText.Size = UDim2.new(1, -32, 0, 20)
	rarityText.Font = Enum.Font.Gotham
	rarityText.TextSize = 14
	rarityText.TextXAlignment = Enum.TextXAlignment.Left
	rarityText.TextColor3 = Color3.fromRGB(210,210,210)
	rarityText.Text = ""
	rarityText.Parent = cardBtn

	local desc = Instance.new("TextLabel")
	desc.Name = "Desc"
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.new(0, 16, 0, 74)
	desc.Size = UDim2.new(1, -32, 1, -90)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 14
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextColor3 = Color3.fromRGB(235,235,235)
	desc.Text = ""
	desc.Parent = cardBtn

	return cardBtn, title, desc, rarityText
end

-- Card copy rules:
-- Title: spell name
-- Desc:
--   - if player doesn't own the spell yet (level 0): show full spell description (what it does)
--   - if player already owns it (level 1+): show ONLY the next upgrade benefit
--   - if max level: show MAX LEVEL
local function cardDescForSpell(spellId: string): string
	local def = SpellDefs.SPELLS[spellId]
	if not def then return "" end

	local lv = plr:GetAttribute(("Spell_%s_Level"):format(spellId)) or 0
	local maxLv = def.maxLevel or 6

	-- Maxed
	if lv >= maxLv then
		return "MAX LEVEL"
	end

	-- Unlock (level 0 -> picking level 1)
	if lv <= 0 then
		return def.description or ""
	end

	-- Upgrade (level 1+): show next level upgrade only
	local nextLv = lv + 1
	if def.upgrades and def.upgrades[nextLv] then
		return def.upgrades[nextLv]
	end
	if typeof(def.nextDesc) == "function" then
		local t = def.nextDesc(lv)
		if t and t ~= "" then
			return t
		end
	end

	return "Upgrade available"
end

local function setBanishButtonState(on: boolean)
	-- Prosty feedback bez przebudowy UI: przyciemnij/rozjaśnij
	if on then
		btnBanish.ImageTransparency = 0
	else
		btnBanish.ImageTransparency = 0
	end
end

local function renderOffers(token: string, offers: {any})
	currentToken = token

	for i = 1, 3 do
		local slot = slots[i]
		local off = offers[i]
		if not off then
			clearSlot(slot)
			slot.Visible = false
		else
			slot.Visible = true

			local spellId = tostring(off.spellId)
			local rarity = tostring(off.rarity or "Common")
			local def = SpellDefs.SPELLS[spellId]

			local cardBtn, title, desc, rarityText = makeCardInSlot(slot)
			cardBtn.Image = rarityImage[rarity] or rarityImage.Common

			title.Text = (def and def.name) or spellId
			rarityText.Text = rarity
			desc.Text = cardDescForSpell(spellId)

			cardBtn.MouseButton1Click:Connect(function()
				if not currentToken then return end

				if banishMode then
					SpellEvent:FireServer({ type="banish", token=currentToken, spellId=spellId })
					banishMode = false
					setBanishButtonState(false)
					return
				end

				SpellEvent:FireServer({ type="pick", token=currentToken, spellId=spellId })
				hideMenu()
			end)
		end
	end

	showMenu()
end

btnSkip.MouseButton1Click:Connect(function()
	if not currentToken then return end
	SpellEvent:FireServer({ type="skip", token=currentToken })
	hideMenu()
end)

btnReroll.MouseButton1Click:Connect(function()
	if not currentToken then return end
	SpellEvent:FireServer({ type="reroll", token=currentToken })
end)

btnBanish.MouseButton1Click:Connect(function()
	if not currentToken then return end
	banishMode = not banishMode
	setBanishButtonState(banishMode)
end)

main.Visible = false

SpellEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type == "offer" and typeof(payload.token) == "string" and typeof(payload.offers) == "table" then
		renderOffers(payload.token, payload.offers)
	end
end)
