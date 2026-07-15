-- LOCALSCRIPT: PlayerHudLobby.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/PlayerHudLobby (LocalScript)
-- CO: HUD lobby z walutami + auto-hide gdy istnieje ScreenGui z atrybutem Modal=true i Enabled=true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlayerProgressEvent = remoteEvents:WaitForChild("PlayerProgressEvent")
local NumberFormatter = require(
	ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("NumberFormatter")
)

local gui = pg:WaitForChild("PlayerHudGui_Lobby")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false

local coinsBox = gui:WaitForChild("coinsBox")
coinsBox.Position = UDim2.fromOffset(18, 150)
coinsBox.Size = UDim2.fromOffset(280, 36)
coinsBox.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
coinsBox.BackgroundTransparency = 0.12
coinsBox.BorderSizePixel = 0
coinsBox.Parent = gui
Instance.new("UICorner", coinsBox).CornerRadius = UDim.new(0, 14)

local padL = Instance.new("UIPadding", coinsBox)
padL.PaddingLeft = UDim.new(0, 12)

local coinsText = coinsBox:WaitForChild("coinsText")
coinsText.BackgroundTransparency = 1
coinsText.Size = UDim2.new(1, 0, 1, 0)
coinsText.Font = Enum.Font.GothamBold
coinsText.TextSize = 14
coinsText.TextXAlignment = Enum.TextXAlignment.Left
coinsText.TextYAlignment = Enum.TextYAlignment.Center
coinsText.TextColor3 = Color3.fromRGB(245, 245, 245)
coinsText.Text = "Silver: 0  |  Souls: 0"
coinsText.Parent = coinsBox

local silver = 0
local souls = 0

local function render()
	coinsText.Text = string.format(
		"Silver: %s  |  Souls: %s",
		NumberFormatter.Format(silver),
		NumberFormatter.Format(souls)
	)
end

local function applyCoreGuiState(hideModal: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not hideModal)
	end)
end

PlayerProgressEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "progress" then
		return
	end

	silver = tonumber(payload.silver) or tonumber(payload.coins) or silver
	souls = tonumber(payload.souls) or souls
	render()
end)

local function anyModalOpen(): boolean
	for _, inst in ipairs(pg:GetChildren()) do
		if inst:IsA("ScreenGui") and inst.Enabled then
			if inst:GetAttribute("Modal") == true then
				return true
			end

			if inst.Name == "PartyGui" then
				local overlay = inst:FindFirstChild("overlay")
				if overlay and overlay:IsA("GuiObject") and overlay.Visible then
					return true
				end
			end
		end
	end
	return false
end

local lastHidden = false
RunService.RenderStepped:Connect(function()
	local hide = anyModalOpen()
	if hide ~= lastHidden then
		gui.Enabled = not hide
		applyCoreGuiState(hide)
		lastHidden = hide
	end
end)

applyCoreGuiState(false)
render()
print("[PlayerHudLobby] Ready (compact Silver/Souls, lobby backpack hidden)")
