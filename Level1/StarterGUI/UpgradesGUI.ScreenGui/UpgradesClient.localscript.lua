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
gui:SetAttribute("Modal", true) -- used by camera/mouse lock script

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

-- Template card (ImageButton) with:
-- CardTemplate
--  ├ DescBox (Frame) -> Desc (TextLabel)
--  └ TitleBox (Frame) -> Title (TextLabel)
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

local function hideMenu()
	main.Visible = false
	lockMovement(false)
	currentToken = nil
	banishMode = false
end

local function showMenu()
	main.Visible = true
	lockMovement(true)
	-- Prevent accidental clicks right as the menu pops up.
	choiceLockedUntil = os.clock() + 2
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

local function nextDescForSpell(spellId: string): string
	local def = SpellDefs.SPELLS[spellId]
	if not def then return "" end
	local lv = plr:GetAttribute(("Spell_%s_Level"):format(spellId)) or 0
	if typeof(def.nextDesc) == "function" then
		return def.nextDesc(lv)
	end
	return ""
end

local function mountCardInSlot(slot: Frame, spellId: string, rarity: string, def)
	clearSlot(slot)

	local card = cardTemplate:Clone()
	card.Name = "Card"
	card.Visible = true
	card.Parent = slot
	card.Size = UDim2.fromScale(1, 1)
	card.Position = UDim2.fromScale(0, 0)
	card.BackgroundTransparency = 1
	card.AutoButtonColor = false

	-- rarity background
	card.Image = rarityImage[rarity] or rarityImage.Common

	-- write into the dedicated boxes
	local titleLabel = card:WaitForChild("TitleBox"):WaitForChild("Title")
	local descLabel = card:WaitForChild("DescBox"):WaitForChild("Desc")

	titleLabel.Text = (def and def.name) or spellId
	descLabel.Text = nextDescForSpell(spellId)

	return card
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

			local cardBtn = mountCardInSlot(slot, spellId, rarity, def)

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
				hideMenu()
			end)
		end
	end

	showMenu()
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
	SpellEvent:FireServer({ type="reroll", token=currentToken })
end)

btnBanish.MouseButton1Click:Connect(function()
	if os.clock() < choiceLockedUntil then return end
	if not currentToken then return end
	banishMode = not banishMode
	setBanishButtonState(banishMode)
end)

main.Visible = false

-- If the player respawns while the menu is open, keep them locked.
plr.CharacterAdded:Connect(function()
	if main.Visible then
		lockMovement(true)
	else
		lockMovement(false)
	end
end)

SpellEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type == "offer" and typeof(payload.token) == "string" and typeof(payload.offers) == "table" then
		renderOffers(payload.token, payload.offers)
	end
end)
