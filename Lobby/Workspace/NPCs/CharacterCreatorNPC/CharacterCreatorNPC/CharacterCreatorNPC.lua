-- SCRIPT: CharacterCreationNPC.server.lua
-- GDZIE: Workspace/NPCs/CharacterCreationNPC/CharacterCreationNPC.server.lua (Script)
-- CO: Create + Reset (reset działa na live tylko dla whitelisty)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

local AccountReset = require(serverModules:WaitForChild("AccountReset"))
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local ProfilesManager = require(serverModules:WaitForChild("ProfilesManager"))

local npc = script.Parent
local primary = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
assert(primary and primary:IsA("BasePart"), "NPC musi mieć PrimaryPart/BasePart")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenUI = remotes:WaitForChild("OpenCharacterCreation")

local function ensurePrompt(part: BasePart, name: string, actionText: string, objectText: string, hold: number): ProximityPrompt
	local p = part:FindFirstChild(name)
	if p and p:IsA("ProximityPrompt") then return p end
	p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = hold
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = part
	return p
end

local createPrompt = ensurePrompt(primary, "CreateCharacterPrompt", "Stwórz postać", "Twórca postaci", 0)

local resetPart = npc:FindFirstChild("ResetPromptPart") :: BasePart?
if not resetPart then
	resetPart = Instance.new("Part")
	resetPart.Name = "ResetPromptPart"
	resetPart.Size = Vector3.new(1, 1, 1)
	resetPart.Transparency = 1
	resetPart.CanCollide = false
	resetPart.CanTouch = false
	resetPart.CanQuery = false
	resetPart.Massless = true
	resetPart.CFrame = primary.CFrame * CFrame.new(3, 0, 0)
	resetPart.Parent = npc

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = primary
	weld.Part1 = resetPart
	weld.Parent = resetPart
end

local resetPrompt = ensurePrompt(resetPart, "ResetAccountPrompt", "Reset konta", "Tylko dev", 2)

createPrompt.Triggered:Connect(function(player: Player)
	OpenUI:FireClient(player)
end)

resetPrompt.Triggered:Connect(function(player: Player)
	local ok, msg = AccountReset.ResetAllForPlayer(player)
	if not ok then
		warn("[ResetAccount] Blocked/Failed:", player.Name, msg)
		return
	end

	-- runtime reset po udanym DS reset
	PlayerStateStore.Load(player)
	ProfilesManager.LoadIfAny(player)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, inst in ipairs(backpack:GetChildren()) do
			if inst:IsA("Tool") then inst:Destroy() end
		end
	end
	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, inst in ipairs(starterGear:GetChildren()) do
			if inst:IsA("Tool") then inst:Destroy() end
		end
	end

	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		local ui = pg:FindFirstChild("CharacterCreationUI")
		if ui then ui:Destroy() end
	end

	print("[ResetAccount] Done for", player.Name)
end)

print("[CharacterCreationNPC] Ready (Create + Reset live whitelist)")
