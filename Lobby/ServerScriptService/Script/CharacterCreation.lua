-- SCRIPT: CharacterCreation.server.lua
-- GDZIE: ServerScriptService/CharacterCreation.server.lua (Script)
-- FIX: jak klient wysyła nil, ustawiamy domyślną klasę "Warrior"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfilesManager = require(ServerScriptService:WaitForChild("ProfilesManager"))
local Races = require(ReplicatedStorage:WaitForChild("Races"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local CreateReq = remotes:WaitForChild("CreateProfileRequest")
local CreateRes = remotes:WaitForChild("CreateProfileResponse")
local RerollReq = remotes:WaitForChild("RerollRaceRequest")
local RerollRes = remotes:WaitForChild("RerollRaceResponse")

local lastCall: {[number]: number} = {}
local COOLDOWN = 0.8

local CARDS_COUNT = 45
local TARGET_INDEX = CARDS_COUNT - 6

local function buildRollPreview(className: string, finalRace: string?)
	if typeof(className) ~= "string" then
		className = "Default"
	end

	local sequence = table.create(CARDS_COUNT)
	for i = 1, CARDS_COUNT do
		if i == TARGET_INDEX and typeof(finalRace) == "string" then
			sequence[i] = finalRace
		else
			sequence[i] = Races.RollForClass(className)
		end
	end

	return {
		sequence = sequence,
		cardsCount = CARDS_COUNT,
		targetIndex = TARGET_INDEX,
	}
end

local function canCall(player)
	local now = os.clock()
	local last = lastCall[player.UserId] or 0
	if (now - last) < COOLDOWN then return false end
	lastCall[player.UserId] = now
	return true
end

CreateReq.OnServerEvent:Connect(function(player: Player, className)
	if not canCall(player) then return end

	local picked = className
	if typeof(picked) ~= "string" then
		picked = player:GetAttribute("PendingClass")
		if typeof(picked) ~= "string" then
			picked = "Warrior" -- ✅ domyślnie
		end
	end

	local ok, payload = ProfilesManager.CreateProfile(player, picked)
	local response = {
		ok = ok,
		error = (ok and nil or payload),
		profile = ok and payload or nil,
		race = (ok and payload and payload.Race) or nil,
		rollPreview = ok and buildRollPreview(picked, payload and payload.Race) or nil,
	}
	CreateRes:FireClient(player, response)
end)

RerollReq.OnServerEvent:Connect(function(player: Player)
	if not canCall(player) then return end
	local ok, payload = ProfilesManager.RerollRaceOnce(player)
	local response = {
		ok = ok,
		error = (ok and nil or payload),
		profile = ok and payload or nil,
		race = (ok and payload and payload.Race) or nil,
	}
	RerollRes:FireClient(player, response)
end)

print("[CharacterCreation] Server READY")
