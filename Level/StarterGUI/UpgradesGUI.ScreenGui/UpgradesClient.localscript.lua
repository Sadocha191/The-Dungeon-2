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

local PauseState = ReplicatedStorage:WaitForChild("PauseState") -- BoolValue
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

local function hideMenu()
	main.Visible = false
	lockMovement(false)
	currentToken = nil
	banishMode = false
	setBanishButtonState(false)
	updateRerollButtonState()
end

local function showMenu()
	main.Visible = true
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

	-- rarity background
	card.Image = rarityImage[tostring(offer.cardQuality or offer.quality or "Common")] or rarityImage.Common

	-- write into the dedicated boxes
	local titleLabel = card:WaitForChild("TitleBox"):WaitForChild("Title")
	local descLabel = card:WaitForChild("DescBox"):WaitForChild("Desc")
	local accent = typeof(offer.color) == "Color3" and offer.color or Color3.fromRGB(255, 255, 255)

	titleLabel.Text = string.format("%s\n%s", tostring(offer.name or offer.spellId or "Spell"), tostring(offer.subtitle or "Upgrade"))
	titleLabel.TextColor3 = accent
	descLabel.Text = tostring(offer.desc or "")

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
					-- pokazuj waiting aż serwer zwolni pauzę (PauseState=false)
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

main.Visible = false
updateRerollButtonState()

-- If the player respawns while the menu is open, keep them locked.
plr.CharacterAdded:Connect(function()
	if main.Visible then
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
	if PauseState.Value == false and main.Visible == true then
		for _, s in ipairs(slots) do s.Visible = true end
		btnSkip.Active = true; btnReroll.Active = true; btnBanish.Active = true
		hideMenu()
	end
end)
