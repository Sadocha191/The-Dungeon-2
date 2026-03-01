-- WeaponVFXTemplates.server.lua (ServerScriptService/Script)
-- Kopiuje template broni do ReplicatedStorage, żeby klient mógł je klonować jako VFX w świecie.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local templatesFolder = ServerStorage:FindFirstChild("WeaponTemplates")
if not templatesFolder then
	warn("[WeaponVFXTemplates] Missing ServerStorage.WeaponTemplates")
	return
end

local assets = ReplicatedStorage:FindFirstChild("Assets")
if not assets then
	assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = ReplicatedStorage
end

local vfxFolder = assets:FindFirstChild("WeaponVFX")
if not vfxFolder then
	vfxFolder = Instance.new("Folder")
	vfxFolder.Name = "WeaponVFX"
	vfxFolder.Parent = assets
end

-- Odśwież folder (żeby nie dublować)
for _, c in ipairs(vfxFolder:GetChildren()) do
	c:Destroy()
end

local function sanitize(inst: Instance)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.Massless = true
		end
	end
end

for _, tool in ipairs(templatesFolder:GetChildren()) do
	if tool:IsA("Tool") then
		local clone = tool:Clone()
		clone.Parent = vfxFolder
		sanitize(clone)
	end
end

print(("[WeaponVFXTemplates] Copied %d weapon templates to ReplicatedStorage.Assets.WeaponVFX"):format(#vfxFolder:GetChildren()))
