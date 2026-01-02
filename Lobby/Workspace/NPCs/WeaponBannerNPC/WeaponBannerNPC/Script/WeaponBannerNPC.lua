-- SCRIPT: WeaponBannerNPC.server.lua
-- GDZIE: Workspace/NPCs/WeaponBannerNPC/WeaponBannerNPC/WeaponBannerNPC.server.lua
-- CO: otwiera UI bannerów przez ProximityPrompt

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local npc = script.Parent
local primary = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
assert(primary and primary:IsA("BasePart"), "NPC musi mieć PrimaryPart/BasePart")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local OpenUI = remotes:WaitForChild("OpenWeaponBannerUI")

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

local prompt = ensurePrompt(primary, "WeaponBannerPrompt", "Sprawdź bannery", "Banner Gacha", 0)

prompt.Triggered:Connect(function(player: Player)
	OpenUI:FireClient(player)
end)

print("[WeaponBannerNPC] Ready")
