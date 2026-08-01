--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local currencyGui = script.Parent

assert(currencyGui:IsA("ScreenGui"), "[CurrencyClient] Script must be parented to StarterGui.Currency")

local frame = currencyGui:WaitForChild("Frame")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local playerProgressEvent = remoteEvents:WaitForChild("PlayerProgressEvent")

local function resolveCounterLabel(counterName: string): TextLabel
	local container = frame:WaitForChild(counterName)
	if container:IsA("TextLabel") then
		return container
	end

	local namedLabel = container:FindFirstChild(counterName)
	if namedLabel and namedLabel:IsA("TextLabel") then
		return namedLabel
	end

	local fallback = container:FindFirstChildWhichIsA("TextLabel", true)
	assert(fallback and fallback:IsA("TextLabel"), string.format(
		"[CurrencyClient] Missing TextLabel at Currency.Frame.%s.%s",
		counterName,
		counterName
	))
	return fallback
end

local silverLabel = resolveCounterLabel("Silver")
local soulsLabel = resolveCounterLabel("Souls")

local silver = 0
local souls = 0

local function formatWholeNumber(value: any): string
	local amount = math.max(0, math.floor(tonumber(value) or 0))
	local reversed = string.reverse(tostring(amount))
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1 ")
	grouped = string.gsub(grouped, " $", "")
	return string.reverse(grouped)
end

local function render()
	silverLabel.Text = formatWholeNumber(silver)
	soulsLabel.Text = formatWholeNumber(souls)
end

local function disableLegacyCurrencyGui(instance: Instance)
	if instance.Name == "PlayerHudGui_Lobby" and instance:IsA("ScreenGui") then
		instance.Enabled = false
	end
end

for _, instance in ipairs(playerGui:GetChildren()) do
	disableLegacyCurrencyGui(instance)
end

local observedGuis: {[ScreenGui]: {RBXScriptConnection}} = {}
local observedPartyOverlays: {[ScreenGui]: GuiObject} = {}
local refreshQueued = false

local function isModalOpen(): boolean
	for _, instance in ipairs(playerGui:GetChildren()) do
		if instance ~= currencyGui and instance:IsA("ScreenGui") and instance.Enabled then
			if instance.Name ~= "PlayerHudGui_Lobby" and instance:GetAttribute("Modal") == true then
				return true
			end

			if instance.Name == "PartyGui" then
				local overlay = instance:FindFirstChild("overlay")
				if overlay and overlay:IsA("GuiObject") and overlay.Visible then
					return true
				end
			end
		end
	end
	return false
end

local function applyCoreGuiState(modalOpen: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not modalOpen)
	end)
end

local function refreshVisibility()
	local modalOpen = isModalOpen()
	currencyGui.Enabled = not modalOpen
	applyCoreGuiState(modalOpen)
end

local function queueVisibilityRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refreshVisibility()
	end)
end

local function bindPartyOverlay(gui: ScreenGui, connections: {RBXScriptConnection})
	if gui.Name ~= "PartyGui" then
		return
	end

	local overlay = gui:FindFirstChild("overlay")
	if not (overlay and overlay:IsA("GuiObject")) then
		return
	end
	if observedPartyOverlays[gui] == overlay then
		return
	end

	observedPartyOverlays[gui] = overlay
	table.insert(connections, overlay:GetPropertyChangedSignal("Visible"):Connect(queueVisibilityRefresh))
end

local function observeGui(gui: ScreenGui)
	if gui == currencyGui or observedGuis[gui] then
		return
	end

	local connections: {RBXScriptConnection} = {}
	observedGuis[gui] = connections

	table.insert(connections, gui:GetPropertyChangedSignal("Enabled"):Connect(queueVisibilityRefresh))
	table.insert(connections, gui:GetAttributeChangedSignal("Modal"):Connect(queueVisibilityRefresh))
	table.insert(connections, gui.ChildAdded:Connect(function(child)
		if child.Name == "overlay" then
			bindPartyOverlay(gui, connections)
		end
		queueVisibilityRefresh()
	end))
	table.insert(connections, gui.AncestryChanged:Connect(function(_, parent)
		if parent then
			return
		end

		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		observedGuis[gui] = nil
		observedPartyOverlays[gui] = nil
		queueVisibilityRefresh()
	end))

	bindPartyOverlay(gui, connections)
end

for _, instance in ipairs(playerGui:GetChildren()) do
	if instance:IsA("ScreenGui") then
		observeGui(instance)
	end
end

playerGui.ChildAdded:Connect(function(instance)
	disableLegacyCurrencyGui(instance)
	if instance:IsA("ScreenGui") then
		observeGui(instance)
	end
	queueVisibilityRefresh()
end)

playerGui.ChildRemoved:Connect(queueVisibilityRefresh)

playerProgressEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "progress" then
		return
	end

	silver = tonumber(payload.silver) or tonumber(payload.coins) or silver
	souls = tonumber(payload.souls) or souls
	render()
end)

currencyGui.ResetOnSpawn = false
render()
refreshVisibility()
playerProgressEvent:FireServer({ type = "requestSync" })

print("[CurrencyClient] Ready (authored Silver/Souls counters, full values)")
