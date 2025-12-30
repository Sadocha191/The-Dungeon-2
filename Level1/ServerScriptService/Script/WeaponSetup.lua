-- WeaponSetup.server.lua (ServerScriptService)
-- Tworzy broń testową jeśli jej nie ma (Sword/Bow/Wand)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponTemplates = ReplicatedStorage:FindFirstChild("WeaponTemplates")
if not WeaponTemplates then
	WeaponTemplates = Instance.new("Folder")
	WeaponTemplates.Name = "WeaponTemplates"
	WeaponTemplates.Parent = ReplicatedStorage
end

local function ensureTool(toolName: string, weaponType: string, handleSize: Vector3, handleColor: Color3)
	local existing = WeaponTemplates:FindFirstChild(toolName)
	if existing and existing:IsA("Tool") then
		existing:SetAttribute("WeaponType", weaponType)
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = toolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponType", weaponType)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = handleSize
	handle.Color = handleColor
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Parent = tool

	tool.Parent = WeaponTemplates
end

ensureTool("Sword", "Melee", Vector3.new(0.35, 3.6, 0.35), Color3.fromRGB(210, 210, 220))
ensureTool("Bow", "Bow", Vector3.new(0.35, 2.8, 0.35), Color3.fromRGB(140, 90, 50))
ensureTool("Wand", "Wand", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(120, 80, 200))

print("[WeaponSetup] WeaponTemplates ready:", WeaponTemplates:GetFullName())
