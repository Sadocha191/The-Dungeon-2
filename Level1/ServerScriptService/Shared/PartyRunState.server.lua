-- PartyRunState.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PauseService = require(script.Parent:WaitForChild("PauseService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PartyLevelUp = Remotes:WaitForChild("PartyLevelUp")
local PartyUpgradePicked = Remotes:WaitForChild("PartyUpgradePicked")
local PartyXPUpdate = Remotes:WaitForChild("PartyXPUpdate")

-- Konfiguracja progu XP (prosto i czytelnie)
local function requiredXPForLevel(level: number): number
	return 100 + (level - 1) * 50
end

local RunMode = workspace:GetAttribute("RunMode") -- "Single" / "Multi"
local PartyXP = 0
local PartyLevel = 1

-- Kto jeszcze NIE wybrał upgradu
local WaitingFor: {[number]: boolean} = {}

local function getRunPlayers()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		-- Minimalne założenie:
		if plr:GetAttribute("InRun") == true then
			table.insert(list, plr)
		end
	end
	return list
end

local function broadcastXP()
	local players = getRunPlayers()
	for _, plr in ipairs(players) do
		PartyXPUpdate:FireClient(plr, PartyXP, PartyLevel, requiredXPForLevel(PartyLevel))
	end
end

local function beginLevelUp()
	local players = getRunPlayers()
	if #players == 0 then return end

	WaitingFor = {}
	PauseService.SetPaused(true)

	for _, plr in ipairs(players) do
		WaitingFor[plr.UserId] = true
		PartyLevelUp:FireClient(plr, PartyLevel)
	end
end

local function tryUnpauseIfAllPicked()
	for _, waiting in pairs(WaitingFor) do
		if waiting then
			return
		end
	end
	PauseService.SetPaused(false)
end

_G.PartyRunState = _G.PartyRunState or {}

function _G.PartyRunState.AddXP(amount: number)
	if RunMode ~= "Multi" then
		return
	end

	if amount <= 0 then return end

	PartyXP += amount

	-- Multi: jeden level-up na raz
	if PauseService.IsPaused() then
		broadcastXP()
		return
	end

	local req = requiredXPForLevel(PartyLevel)
	if PartyXP >= req then
		PartyXP -= req
		PartyLevel += 1
		broadcastXP()
		beginLevelUp()
	else
		broadcastXP()
	end
end

function _G.PartyRunState.GetState()
	return PartyXP, PartyLevel, requiredXPForLevel(PartyLevel)
end

PartyUpgradePicked.OnServerEvent:Connect(function(plr)
	if RunMode ~= "Multi" then return end
	if WaitingFor[plr.UserId] ~= true then return end

	WaitingFor[plr.UserId] = false
	tryUnpauseIfAllPicked()
end)

Players.PlayerRemoving:Connect(function(plr)
	if WaitingFor[plr.UserId] == true then
		WaitingFor[plr.UserId] = false
		tryUnpauseIfAllPicked()
	end
end)
