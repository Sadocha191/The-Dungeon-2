-- LOCALSCRIPT: PlayerHudLobby.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/PlayerHudLobby (LocalScript)
-- CO: HUD lobby z monetami + auto-hide gdy istnieje ScreenGui z atrybutem Modal=true i Enabled=true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlayerProgressEvent = remoteEvents:WaitForChild("PlayerProgressEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "PlayerHudGui_Lobby"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = pg

local coinsBox = Instance.new("Frame")
coinsBox.Position = UDim2.fromOffset(18, 150)
coinsBox.Size = UDim2.fromOffset(200, 36)
coinsBox.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
coinsBox.BackgroundTransparency = 0.12
coinsBox.BorderSizePixel = 0
coinsBox.Parent = gui
Instance.new("UICorner", coinsBox).CornerRadius = UDim.new(0, 14)

local padL = Instance.new("UIPadding", coinsBox)
padL.PaddingLeft = UDim.new(0, 12)

local coinsText = Instance.new("TextLabel")
coinsText.BackgroundTransparency = 1
coinsText.Size = UDim2.new(1, 0, 1, 0)
coinsText.Font = Enum.Font.GothamBold
coinsText.TextSize = 14
coinsText.TextXAlignment = Enum.TextXAlignment.Left
coinsText.TextYAlignment = Enum.TextYAlignment.Center
coinsText.TextColor3 = Color3.fromRGB(245, 245, 245)
coinsText.Text = "Silver: 0"
coinsText.Parent = coinsBox

local coins = 0

local function render()
	coinsText.Text = ("Silver: %d"):format(coins)
end

PlayerProgressEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or payload.type ~= "progress" then
		return
	end

	coins = tonumber(payload.silver) or tonumber(payload.coins) or coins
	render()
end)

local function anyModalOpen(): boolean
	for _, inst in ipairs(pg:GetChildren()) do
		if inst:IsA("ScreenGui") and inst.Enabled then
			if inst:GetAttribute("Modal") == true then
				return true
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
		lastHidden = hide
	end
end)

render()
print("[PlayerHudLobby] Ready (coins only, auto-hide on Modal)")
