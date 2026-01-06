-- SCRIPT: CharacterCreationNPC.server.lua
-- GDZIE: Workspace/NPCs/CharacterCreationNPC/CharacterCreationNPC.server.lua (Script)
-- CO: Create + Reset (reset działa na live tylko dla whitelisty)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")

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

createPrompt.Triggered:Connect(function(player: Player)
	OpenUI:FireClient(player)
end)

print("[CharacterCreationNPC] Ready (Create)")
