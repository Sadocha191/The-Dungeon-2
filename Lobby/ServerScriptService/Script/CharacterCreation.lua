-- SCRIPT: CharacterCreation.server.lua
-- GDZIE: ServerScriptService/CharacterCreation.server.lua (Script)
-- FIX: jak klient wysyła nil, ustawiamy domyślną klasę "Warrior"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfilesManager = require(ServerScriptService:WaitForChild("ProfilesManager"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local CreateReq = remotes:WaitForChild("CreateProfileRequest")
local CreateRes = remotes:WaitForChild("CreateProfileResponse")
local RerollReq = remotes:WaitForChild("RerollRaceRequest")
local RerollRes = remotes:WaitForChild("RerollRaceResponse")

local lastCall: {[number]: number} = {}
local COOLDOWN = 0.8

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
	CreateRes:FireClient(player, ok, payload)
end)

RerollReq.OnServerEvent:Connect(function(player: Player)
	if not canCall(player) then return end
	local ok, payload = ProfilesManager.RerollRaceOnce(player)
	RerollRes:FireClient(player, ok, payload)
end)

print("[CharacterCreation] Server READY")
