-- SCRIPT: TutorialService.server.lua
-- GDZIE: ServerScriptService/TutorialService.server.lua
-- CO: prowadzenie tutorialu lobby jako state machine na graczu

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

local NPCS_FOLDER = Workspace:WaitForChild("NPCs", 10)

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

local function registerNpc(model: Model)
	local npcId = model:GetAttribute("TutorialNpcId")
	if typeof(npcId) ~= "string" or npcId == "" then
		return
	end

	local prompt: ProximityPrompt?
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("ProximityPrompt") then
			prompt = inst
			break
		end
	end

	npcById[npcId] = {
		model = model,
		prompt = prompt,
	}

	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			local tutorial = PlayerStateStore.GetTutorialState(player)
			if not tutorial or tutorial.Complete or not tutorial.Active then return end
			local current = stepConfig[tutorial.Step]
			if not current or current.npcId ~= npcId then return end
			OpenDialogueEvent:FireClient(player, current.dialogueKey)
		end)
	end
end

local function scanNpcs()
	if not NPCS_FOLDER then return end
	for _, inst in ipairs(NPCS_FOLDER:GetChildren()) do
		if inst:IsA("Model") then
			registerNpc(inst)
		end
	end
end

scanNpcs()

if NPCS_FOLDER then
	NPCS_FOLDER.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			registerNpc(child)
		end
	end)
end

local function getNpcTarget(npcId: string): Vector3?
	local entry = npcById[npcId]
	if not entry or not entry.model then return nil end
	local model = entry.model
	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end
	local pivot = model:GetPivot()
	return pivot.Position
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

local function giveStarterSword(player: Player)
	local weaponName = STARTER_SWORD_NAME
	local template = WeaponCatalog.FindTemplate(weaponName)
	if not template and FALLBACK_SWORD_NAME then
		weaponName = FALLBACK_SWORD_NAME
		template = WeaponCatalog.FindTemplate(weaponName)
	end
	if not template then
		warn("[TutorialService] Missing starter sword template:", STARTER_SWORD_NAME)
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if not backpack then
		warn("[TutorialService] Missing Backpack for", player.Name)
		return
	end

	local clone = template:Clone()
	WeaponCatalog.PrepareTool(clone, weaponName)
	clone.Parent = backpack

	PlayerStateStore.SetStarterWeaponClaimed(player, weaponName)
	PlayerStateStore.EnsureOwnedWeapon(player, weaponName)

	if REQUIRE_EQUIPPED then
		local character = player.Character or player.CharacterAdded:Wait()
		if not character then return end
		if character:FindFirstChild(weaponName) then
			return
		end

		local equipped = false
		local connection
		connection = character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and child.Name == weaponName then
				equipped = true
				connection:Disconnect()
			end
		end)

		local startTime = os.clock()
		while not equipped and (os.clock() - startTime) < 10 do
			task.wait(0.1)
		end

		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
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
	tutorial = tutorial or {
		Active = true,
		Step = 1,
		Complete = false,
	}
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
		giveStarterSword(player)
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
