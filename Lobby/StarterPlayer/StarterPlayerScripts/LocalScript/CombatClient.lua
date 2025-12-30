-- LOCALSCRIPT: CombatClient.client.lua
-- GDZIE: StarterPlayer/StarterPlayerScripts/CombatClient.client.lua
-- CO: LPM = atak (wysyła request do serwera)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local AttackRequest = remotes:WaitForChild("AttackRequest")

local COOLDOWN = 0.45
local lastAttack = 0

local function canAttack()
	local now = os.clock()
	if (now - lastAttack) < COOLDOWN then
		return false
	end
	lastAttack = now
	return true
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if canAttack() then
			AttackRequest:FireServer()
		end
	end
end)

print("[CombatClient] LPM attack ready")
