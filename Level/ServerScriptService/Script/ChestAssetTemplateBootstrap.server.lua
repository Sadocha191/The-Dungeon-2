-- Adapts ReplicatedStorage.Assets.Chest to the legacy workspace template contract
-- consumed by ChestService.server.lua. ChestService clones workspace.skrzynia
-- before falling back to its generated blockout chest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ASSETS_FOLDER_NAME = "Assets"
local SOURCE_TEMPLATE_NAME = "Chest"
local RUNTIME_TEMPLATE_NAME = "skrzynia"
local RUNTIME_TEMPLATE_ATTRIBUTE = "ChestAssetRuntimeTemplate"
local TEMPLATE_STORAGE_Y = -100000
local WAIT_TIMEOUT_SECONDS = 15

local assets = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME, WAIT_TIMEOUT_SECONDS)
assert(assets, "[ChestAssetTemplateBootstrap] Missing ReplicatedStorage.Assets")

local sourceTemplate = assets:WaitForChild(SOURCE_TEMPLATE_NAME, WAIT_TIMEOUT_SECONDS)
assert(
	sourceTemplate and sourceTemplate:IsA("Model"),
	"[ChestAssetTemplateBootstrap] ReplicatedStorage.Assets.Chest must be a Model"
)

local existingTemplate = workspace:FindFirstChild(RUNTIME_TEMPLATE_NAME)
if existingTemplate then
	existingTemplate:Destroy()
end

local wasArchivable = sourceTemplate.Archivable
sourceTemplate.Archivable = true
local runtimeTemplate = sourceTemplate:Clone()
sourceTemplate.Archivable = wasArchivable

assert(runtimeTemplate, "[ChestAssetTemplateBootstrap] Failed to clone ReplicatedStorage.Assets.Chest")

runtimeTemplate.Name = RUNTIME_TEMPLATE_NAME
runtimeTemplate:SetAttribute(RUNTIME_TEMPLATE_ATTRIBUTE, true)
runtimeTemplate:SetAttribute("ChestTemplateSource", "ReplicatedStorage.Assets.Chest")

-- ChestService owns interaction and rewards. Remove any embedded runtime logic
-- or prompts so every spawned chest has exactly one server-authoritative prompt.
for _, descendant in ipairs(runtimeTemplate:GetDescendants()) do
	if descendant:IsA("BaseScript") or descendant:IsA("ProximityPrompt") then
		descendant:Destroy()
	elseif descendant:IsA("BasePart") then
		descendant.Anchored = true
		descendant.CanTouch = false
	end
end

-- ChestService requires the template to be a direct child of Workspace.
-- Keep the source copy far below the playable world; spawned clones are pivoted
-- back onto terrain by ChestService.
local sourcePivot = runtimeTemplate:GetPivot()
local sourceRotation = sourcePivot - sourcePivot.Position
runtimeTemplate:PivotTo(CFrame.new(0, TEMPLATE_STORAGE_Y, 0) * sourceRotation)
runtimeTemplate.Parent = workspace

print("[ChestAssetTemplateBootstrap] Using ReplicatedStorage.Assets.Chest for world chests")
