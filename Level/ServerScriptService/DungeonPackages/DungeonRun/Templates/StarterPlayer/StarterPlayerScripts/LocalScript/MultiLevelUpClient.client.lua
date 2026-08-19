-- MultiLevelUpClient.client.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local plr = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PartyLevelUp = Remotes:WaitForChild("PartyLevelUp")
local PartyUpgradePicked = Remotes:WaitForChild("PartyUpgradePicked")
local PartyXPUpdate = Remotes:WaitForChild("PartyXPUpdate")

-- Założenie: masz ScreenGui o nazwie "UpgradeGui" w PlayerGui
local playerGui = plr:WaitForChild("PlayerGui")

local function getUpgradeGui()
	return playerGui:FindFirstChild("UpgradeGui")
end

local function showUpgrade(level: number)
	local gui = getUpgradeGui()
	if not gui then
		warn("UpgradeGui not found - zmień nazwę GUI w MultiLevelUpClient.client.lua")
		return
	end

	gui.Enabled = true

	local label = gui:FindFirstChild("LevelLabel", true)
	if label and label:IsA("TextLabel") then
		label.Text = ("LEVEL %d"):format(level)
	end
end

local function hideUpgrade()
	local gui = getUpgradeGui()
	if gui then
		gui.Enabled = false
	end
end

PartyLevelUp.OnClientEvent:Connect(function(level: number)
	showUpgrade(level)
end)

-- Podłącz to do swoich przycisków wyboru upgradu:
_G.OnUpgradeChosen = function()
	PartyUpgradePicked:FireServer()
	hideUpgrade()
end

PartyXPUpdate.OnClientEvent:Connect(function(xp: number, level: number, req: number)
	-- opcjonalnie: podłącz pasek XP jeśli chcesz
end)
