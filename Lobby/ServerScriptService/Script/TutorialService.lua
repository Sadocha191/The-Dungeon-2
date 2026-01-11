-- SCRIPT: TutorialService.server.lua
-- CO: prowadzenie tutorialu lobby jako state machine na graczu
-- ZMIANA (KROK 3): tutorial NIE daje już starterowego miecza (broń jest od Kowala).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local PlayerStateStore = require(serverModules:WaitForChild("PlayerStateStore"))
local WeaponCatalog = require(serverModules:WaitForChild("WeaponCatalog"))

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name: string): RemoteEvent
	local ev = remotesFolder:FindFirstChild(name)
	if ev and ev:IsA("RemoteEvent") then return ev end
	ev = Instance.new("RemoteEvent")
	ev.Name = name
	ev.Parent = remotesFolder
	return ev
end

local OpenDialogueEvent = ensureRemote("OpenDialogueEvent")
local DialogueFinishedEvent = ensureRemote("DialogueFinishedEvent")
local TutorialTargetEvent = ensureRemote("TutorialTargetEvent")

local function findNpcsFolder(): Instance?
	local direct = Workspace:FindFirstChild("NPCs")
	if direct then
		return direct
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst.Name == "NPCs" then
			return inst
		end
	end
	return nil
end

local NPCS_FOLDER = findNpcsFolder()

local STARTER_SWORD_NAME = "StarterSword"
local FALLBACK_SWORD_NAME = "Knight's Oath"
local STARTER_SPELL_ID = "Spellbook"
local REQUIRE_EQUIPPED = false

local stepConfig = {
	[1] = { npcId = "Knight", dialogueKey = "Knight_Intro", objective = "Talk to the Knight" },
	[2] = { npcId = "Blacksmith", dialogueKey = "Blacksmith_Intro", objective = "Talk to the Blacksmith" },
	[3] = { npcId = "Knight", dialogueKey = "Knight_AfterBlacksmith", objective = "Return to the Knight" },
	[4] = { npcId = "Witch", dialogueKey = "Witch_Intro", objective = "Talk to the Witch" },
	[5] = { npcId = "Knight", dialogueKey = "Knight_Final", objective = "Speak with the Knight" },
}

local npcById: {[string]: {model: Model, prompt: ProximityPrompt?}} = {}

local function resolveNpcId(model: Model): string?
	local attr = model:GetAttribute("TutorialNpcId")
	if typeof(attr) == "string" and attr ~= "" then
		return attr
	end
	for _, cfg in pairs(stepConfig) do
		if cfg.npcId == model.Name then
			return model.Name
		end
	end
	return nil
end

local function findAnyBasePart(model: Model): BasePart?
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			return d
		end
	end
	return nil
end

local function ensureTalkPrompt(model: Model, npcId: string): ProximityPrompt?
	local part = findAnyBasePart(model)
	if not part then return nil end

	local p = part:FindFirstChild("TalkPrompt")
	if p and p:IsA("ProximityPrompt") then return p end

	p = Instance.new("ProximityPrompt")
	p.Name = "TalkPrompt"
	p.ActionText = "Porozmawiaj"
	p.ObjectText = npcId
	p.HoldDuration = 0
	p.MaxActivationDistance = 10
	p.RequiresLineOfSight = false
	p.Parent = part
	return p
end

local function registerNpc(model: Model)
	local npcId = resolveNpcId(model)
	if not npcId then return end

	local prompt: ProximityPrompt?
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("ProximityPrompt") then
			prompt = inst
			break
		end
	end
	if not prompt then
		prompt = ensureTalkPrompt(model, npcId)
	end

	npcById[npcId] = { model = model, prompt = prompt }

	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			local tutorial = PlayerStateStore.GetTutorialState(player)
			if not tutorial or tutorial.Complete or not tutorial.Active then return end
			local current = stepConfig[tutorial.Step]
			if not current or current.npcId ~= npcId then return end
			OpenDialogueEvent:FireClient(player, current.dialogueKey)
		end)
	else
		warn("[TutorialService] NPC without BasePart for prompt:", model:GetFullName())
	end
end

local function scanNpcs()
	if NPCS_FOLDER then
		for _, inst in ipairs(NPCS_FOLDER:GetChildren()) do
			if inst:IsA("Model") then
				registerNpc(inst)
			end
		end
	end
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and typeof(inst:GetAttribute("TutorialNpcId")) == "string" then
			registerNpc(inst)
		end
	end
end

if NPCS_FOLDER then
	scanNpcs()

	NPCS_FOLDER.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			registerNpc(child)
		end
	end)
else
	warn("[TutorialService] NPCs folder not found.")
	scanNpcs()
end

Workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and typeof(inst:GetAttribute("TutorialNpcId")) == "string" then
		registerNpc(inst)
	end
end)

local function getNpcTarget(npcId: string): Vector3?
	local entry = npcById[npcId]
	if not entry or not entry.model then return nil end
	local model = entry.model
	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end
	return model:GetPivot().Position
end

local function sendObjective(player: Player, step: number?, active: boolean)
	if not active then
		TutorialTargetEvent:FireClient(player, nil, "")
		return
	end
	local config = step and stepConfig[step]
	if not config then
		TutorialTargetEvent:FireClient(player, nil, "")
		return
	end
	local target = getNpcTarget(config.npcId)
	if target then
		TutorialTargetEvent:FireClient(player, target, config.objective)
	else
		TutorialTargetEvent:FireClient(player, nil, config.objective)
	end
end

TutorialTargetEvent.OnServerEvent:Connect(function(player: Player)
	local tutorial = PlayerStateStore.GetTutorialState(player)
	if not tutorial then return end
	sendObjective(player, tutorial.Step, tutorial.Active)
end)

local function applyAttributes(player: Player, tutorial: {Active: boolean, Step: number, Complete: boolean})
	player:SetAttribute("TutorialActive", tutorial.Active == true)
	player:SetAttribute("TutorialStep", tutorial.Step or 1)
	player:SetAttribute("TutorialComplete", tutorial.Complete == true)
end

-- ZMIANA: nie dajemy już miecza (broń jest od kowala)
local function giveStarterSword(_player: Player)
	return
end

local function giveStarterSpell(player: Player)
	PlayerStateStore.EnsureOwnedSpell(player, STARTER_SPELL_ID)
end

local function advanceStep(player: Player, nextStep: number?)
	if nextStep then
		PlayerStateStore.SetTutorialState(player, {
			Active = true,
			Step = nextStep,
			Complete = false,
		})
	else
		PlayerStateStore.SetTutorialState(player, {
			Active = false,
			Complete = true,
		})
	end

	local tutorial = PlayerStateStore.GetTutorialState(player)
	applyAttributes(player, tutorial)
	sendObjective(player, tutorial.Step, tutorial.Active)
end

local function ensureDefaults(player: Player)
	local tutorial = PlayerStateStore.GetTutorialState(player)
	tutorial = tutorial or { Active = true, Step = 1, Complete = false }
	if tutorial.Complete then
		tutorial.Active = false
	end
	PlayerStateStore.SetTutorialState(player, {
		Active = tutorial.Active,
		Step = tutorial.Step,
		Complete = tutorial.Complete,
	})
	return PlayerStateStore.GetTutorialState(player)
end

DialogueFinishedEvent.OnServerEvent:Connect(function(player: Player, dialogueKey: string)
	if typeof(dialogueKey) ~= "string" then return end
	local tutorial = PlayerStateStore.GetTutorialState(player)
	if not tutorial or tutorial.Complete or not tutorial.Active then return end
	local current = stepConfig[tutorial.Step]
	if not current or current.dialogueKey ~= dialogueKey then return end

	if tutorial.Step == 2 then
		-- ZMIANA: bez miecza
		advanceStep(player, 3)
		return
	end
	if tutorial.Step == 4 then
		giveStarterSpell(player)
		advanceStep(player, 5)
		return
	end
	if tutorial.Step == 5 then
		advanceStep(player, nil)
		return
	end

	advanceStep(player, tutorial.Step + 1)
end)

Players.PlayerAdded:Connect(function(player: Player)
	local tutorial = ensureDefaults(player)
	applyAttributes(player, tutorial)
	sendObjective(player, tutorial.Step, tutorial.Active)

	player.CharacterAdded:Connect(function()
		local current = PlayerStateStore.GetTutorialState(player)
		applyAttributes(player, current)
		sendObjective(player, current.Step, current.Active)
	end)
end)

print("[TutorialService] Ready")
