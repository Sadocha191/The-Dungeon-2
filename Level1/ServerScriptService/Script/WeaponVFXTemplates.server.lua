-- WeaponVFXTemplates.server.lua
-- Copies weapon tool templates from ServerStorage to ReplicatedStorage for client-side VFX cloning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local templatesRoot = ServerStorage:WaitForChild("WeaponTemplates")
local outFolder = ReplicatedStorage:FindFirstChild("WeaponVFXTemplates")
if not outFolder then
	outFolder = Instance.new("Folder")
	outFolder.Name = "WeaponVFXTemplates"
	outFolder.Parent = ReplicatedStorage
end

local function stripScripts(tool: Instance)
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
end

local function sanitizeParts(model: Instance)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanTouch = false
			inst.CanQuery = false
		end
	end
end

-- Clone every weapon variant by name into ReplicatedStorage/WeaponVFXTemplates/<weaponName>
-- This matches PlayerData loadout ids (usually same as template name).
local function indexTemplates()
	outFolder:ClearAllChildren()

	for _, cat in ipairs(templatesRoot:GetChildren()) do
		if cat:IsA("Folder") then
			for _, weapon in ipairs(cat:GetChildren()) do
				if weapon:IsA("Tool") then
					local clone = weapon:Clone()
					stripScripts(clone)
					sanitizeParts(clone)
					clone.Parent = outFolder
				elseif weapon:IsA("Folder") then
					-- some categories store weapon as Folder/Tool nested
					for _, maybeTool in ipairs(weapon:GetChildren()) do
						if maybeTool:IsA("Tool") then
							local clone = maybeTool:Clone()
							stripScripts(clone)
							sanitizeParts(clone)
							clone.Name = maybeTool.Name
							clone.Parent = outFolder
						end
					end
				end
			end
		end
	end
end

indexTemplates()
