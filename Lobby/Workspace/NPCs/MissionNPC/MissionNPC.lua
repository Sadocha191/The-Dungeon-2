-- SCRIPT: MissionNPC.server.lua
-- GDZIE: Workspace/NPCs/MissionNPC/MissionNPC
-- CO: ProximityPrompt dla UI Missions

local npc = script.Parent

local function findPromptParent(model: Instance)
	if model:IsA("BasePart") then
		return model
	end
	if model:IsA("Model") then
		if model.PrimaryPart then
			return model.PrimaryPart
		end
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				return descendant
			end
		end
	end
	return nil
end

local promptParent = findPromptParent(npc)
if not promptParent then
	warn("[MissionNPC] No BasePart found for ProximityPrompt")
	return
end

local prompt = promptParent:FindFirstChild("MissionPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MissionPrompt"
	prompt.ActionText = "Missions"
	prompt.ObjectText = "NPC"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.Parent = promptParent
end
