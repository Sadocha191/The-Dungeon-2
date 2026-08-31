local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local inventoryGui = playerGui:WaitForChild("InventoryGui")

local function waitDeep(parent, name, timeout)
	local deadline = os.clock() + (timeout or 10)
	repeat
		local found = parent:FindFirstChild(name, true)
		if found then return found end
		task.wait(0.1)
	until os.clock() >= deadline
	return nil
end

local panel = waitDeep(inventoryGui, "RemakePanel", 12)
local center = panel and panel:FindFirstChild("ContentColumn", true)
local detailsColumn = panel and panel:FindFirstChild("DetailsColumn", true)
local tabBar = center and center:FindFirstChild("TabBar")
local gridScroll = center and center:FindFirstChild("GridScroll", true)
if not (panel and center and detailsColumn and tabBar and gridScroll) then
	warn("[InventorySpellTabReference] Inventory layout contract is incomplete")
	return
end

local spellTab = nil
local tabButtons = {}
for _, child in ipairs(tabBar:GetChildren()) do
	if child:IsA("TextButton") then
		table.insert(tabButtons, child)
		if child.Text == "Spell Loadout" or child.Text == "Spells" then
			spellTab = child
		end
	end
end
if not spellTab then
	warn("[InventorySpellTabReference] Spells tab is missing")
	return
end

-- The old reference view used to replace the inventory with a second loadout UI.
-- The documented spell roster has no pre-run spell loadout, so this script now
-- only removes the remaining legacy presentation from the canonical inventory UI.
spellTab.Text = "Spells"

local spellAccent = spellTab:FindFirstChild("Accent")
local cleanupQueued = false

local function isSpellTabActive()
	if spellAccent and spellAccent:IsA("GuiObject") then
		return spellAccent.Visible
	end
	return spellTab.TextColor3 ~= Color3.fromRGB(153, 165, 186)
end

local function trim(text)
	return tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

local function cleanSpellView()
	cleanupQueued = false
	spellTab.Text = "Spells"
	if not isSpellTabActive() then
		return
	end

	-- InventoryController shrinks the collection card to make room for six
	-- loadout slots. Restore the normal collection layout and hide that panel.
	local contentCard = gridScroll.Parent
	if contentCard and contentCard:IsA("GuiObject") then
		contentCard.Size = UDim2.new(1, 0, 1, -100)
	end

	for _, descendant in ipairs(center:GetDescendants()) do
		if descendant:IsA("TextLabel") and trim(descendant.Text) == "EQUIPPED LOADOUT" then
			local legacyPanel = descendant.Parent
			if legacyPanel and legacyPanel:IsA("GuiObject") then
				legacyPanel.Visible = false
				legacyPanel.Size = UDim2.new(1, 0, 0, 0)
			end
		elseif descendant:IsA("TextButton") then
			local text = trim(descendant.Text)
			if string.match(text, "^Status:") then
				descendant.Visible = false
			elseif text == "Sort: Equipped" then
				-- With no equipped spell state every entry ties on the old default
				-- comparator, which falls back to name. Label that behavior honestly.
				descendant.Text = "Sort: Name"
			end
		end
	end

	-- Old details still build Equip/Unequip/Move buttons locally. The server no
	-- longer accepts those actions, so remove the controls instead of showing a
	-- dead loadout workflow.
	local legacyActions = {
		["Equip"] = true,
		["Unequip"] = true,
		["Move Up"] = true,
		["Move Down"] = true,
	}
	for _, descendant in ipairs(detailsColumn:GetDescendants()) do
		if descendant:IsA("TextButton") and legacyActions[trim(descendant.Text)] then
			descendant:Destroy()
		elseif descendant:IsA("TextLabel") then
			local text = trim(descendant.Text)
			if string.match(text, "^Slot %d+$") then
				descendant.Text = "  Unlocked  "
			elseif string.find(text, "Equipped", 1, true) and string.find(text, "Slot", 1, true) then
				descendant.Text = "Unlocked"
			end
		end
	end

	for _, descendant in ipairs(gridScroll:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			local text = trim(descendant.Text)
			if string.match(text, "^SLOT %d+$") then
				descendant:Destroy()
			elseif string.find(text, "Equipped", 1, true) and string.find(text, "Slot", 1, true) then
				descendant.Text = "Unlocked"
			end
		end
	end
end

local function queueCleanup()
	if cleanupQueued then return end
	cleanupQueued = true
	task.defer(function()
		task.wait()
		if panel.Parent then
			cleanSpellView()
		end
	end)
end

if spellAccent and spellAccent:IsA("GuiObject") then
	spellAccent:GetPropertyChangedSignal("Visible"):Connect(queueCleanup)
end
for _, button in ipairs(tabButtons) do
	button.MouseButton1Click:Connect(queueCleanup)
end

panel.DescendantAdded:Connect(function()
	if isSpellTabActive() then
		queueCleanup()
	end
end)

inventoryGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if inventoryGui.Enabled then
		queueCleanup()
	end
end)

queueCleanup()
