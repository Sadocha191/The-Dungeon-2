-- WeaponIconReplicator.server.lua
-- Tworzy lekkie modele ikon broni w ReplicatedStorage, żeby klient mógł robić ViewportFrame.
-- Klient NIE ma dostępu do ServerStorage, więc ikony muszą być zreplikowane.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local serverModules = ServerScriptService:WaitForChild("ModuleScript")
local WeaponCatalog = require(serverModules:WaitForChild("WeaponCatalog"))

local WeaponConfigs = require(ReplicatedStorage:WaitForChild("ModuleScripts"):WaitForChild("WeaponConfigs"))

local iconsFolder = ReplicatedStorage:FindFirstChild("WeaponIcons")
if not iconsFolder then
	iconsFolder = Instance.new("Folder")
	iconsFolder.Name = "WeaponIcons"
	iconsFolder.Parent = ReplicatedStorage
end

local function clearOld()
	for _, ch in ipairs(iconsFolder:GetChildren()) do
		ch:Destroy()
	end
end

local function stripToIconModel(templateTool: Tool, weaponId: string): Model
	local iconModel = Instance.new("Model")
	iconModel.Name = weaponId
	iconModel:SetAttribute("WeaponId", weaponId)

	-- kopiujemy tylko części wizualne (BaseParty z meshem/texture zostają)
	local anyPart: BasePart? = nil
	for _, d in ipairs(templateTool:GetDescendants()) do
		if d:IsA("BasePart") then
			local p = d:Clone()
			p.Anchored = true
			p.CanCollide = false
			p.Massless = true
			p.Parent = iconModel
			anyPart = anyPart or p
		end
	end

	if anyPart then
		iconModel.PrimaryPart = anyPart
	end

	-- wycentruj model wokół (0,0,0) żeby kamera w ViewportFrame była stabilna
	local cf, _ = iconModel:GetBoundingBox()
	iconModel:PivotTo(CFrame.new(-cf.Position))

	return iconModel
end

local function buildAll()
	clearOld()

	local count = 0
	for _, def in ipairs(WeaponConfigs.GetAll()) do
		local weaponId = def.id
		if typeof(weaponId) == "string" and weaponId ~= "" then
			local template = WeaponCatalog.FindTemplate(weaponId)
			if template then
				local toolClone = template:Clone()
				-- skrypty w klonie niepotrzebne w ikonie
				for _, inst in ipairs(toolClone:GetDescendants()) do
					if inst:IsA("Script") or inst:IsA("LocalScript") then
						inst:Destroy()
					end
				end

				local model = stripToIconModel(toolClone, weaponId)
				model.Parent = iconsFolder
				toolClone:Destroy()
				count += 1
			end
		end
	end

	print(("[WeaponIconReplicator] Built %d icons in ReplicatedStorage.WeaponIcons"):format(count))
end

buildAll()
