-- WeaponSetup.server.lua (ServerScriptService)
-- Tworzy broń testową jeśli jej nie ma (Sword/Scythe/Halberd/Bow/Staff/Pistol)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponTemplates = ReplicatedStorage:FindFirstChild("WeaponTemplates")
if not WeaponTemplates then
	WeaponTemplates = Instance.new("Folder")
	WeaponTemplates.Name = "WeaponTemplates"
	WeaponTemplates.Parent = ReplicatedStorage
end

local function ensureTool(toolName: string, handleSize: Vector3, handleColor: Color3)
	local existing = WeaponTemplates:FindFirstChild(toolName)
	if existing and existing:IsA("Tool") then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = toolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false

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

ensureTool("Sword", Vector3.new(0.35, 3.6, 0.35), Color3.fromRGB(210, 210, 220))
ensureTool("Scythe", Vector3.new(0.45, 3.9, 0.45), Color3.fromRGB(160, 160, 170))
ensureTool("Halberd", Vector3.new(0.4, 4.4, 0.4), Color3.fromRGB(185, 185, 200))
ensureTool("Bow", Vector3.new(0.35, 2.8, 0.35), Color3.fromRGB(140, 90, 50))
ensureTool("Staff", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(120, 80, 200))
ensureTool("Wand", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(120, 80, 200))
ensureTool("Pistol", Vector3.new(0.45, 1.6, 0.7), Color3.fromRGB(80, 80, 90))

print("[WeaponSetup] WeaponTemplates ready:", WeaponTemplates:GetFullName())
