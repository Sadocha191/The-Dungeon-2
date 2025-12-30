-- SCRIPT: CombatServer.server.lua
-- GDZIE: ServerScriptService/CombatServer.server.lua (Script)
-- CO: serwerowa walidacja ataku (Tool, cooldown). Na razie tylko logi.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local AttackRequest = remotes:WaitForChild("AttackRequest")

local lastAtk: {[number]: number} = {}
local BASE_COOLDOWN = 0.45

local function getEquippedTool(player: Player): Tool?
	local char = player.Character
	if not char then return nil end
	for _, inst in ipairs(char:GetChildren()) do
		if inst:IsA("Tool") then
			return inst
		end
	end
	return nil
end

AttackRequest.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	local last = lastAtk[player.UserId] or 0
	if (now - last) < BASE_COOLDOWN then
		return
	end

	local tool = getEquippedTool(player)
	if not tool then return end

	-- prosta walidacja: musi mieć atrybuty broni
	local weaponType = tool:GetAttribute("WeaponType")
	local baseDmg = tool:GetAttribute("BaseDamage")
	if typeof(weaponType) ~= "string" or typeof(baseDmg) ~= "number" then
		return
	end

	lastAtk[player.UserId] = now
	-- damage w następnym kroku
	-- print("[Attack] ", player.Name, weaponType, baseDmg)
end)

print("[CombatServer] Ready")
