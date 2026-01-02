-- WeaponSetup.server.lua (ServerScriptService)
-- Tworzy broń testową jeśli jej nie ma (wg WeaponConfigs)

local ServerStorage = game:GetService("ServerStorage")

local WeaponTemplates = ServerStorage:FindFirstChild("WeaponTemplates")
if not WeaponTemplates then
	WeaponTemplates = Instance.new("Folder")
	WeaponTemplates.Name = "WeaponTemplates"
	WeaponTemplates.Parent = ServerStorage
end

local function ensureTool(toolName: string, handleSize: Vector3, handleColor: Color3)
	local existing = WeaponTemplates:FindFirstChild(toolName, true)
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

ensureTool("Knight's Oath", Vector3.new(0.35, 3.6, 0.35), Color3.fromRGB(210, 210, 220))
ensureTool("Excalion, Blade of Kings", Vector3.new(0.35, 3.6, 0.35), Color3.fromRGB(255, 180, 110))
ensureTool("Reaper's Crescent", Vector3.new(0.45, 3.9, 0.45), Color3.fromRGB(160, 160, 170))
ensureTool("Harvest of the End", Vector3.new(0.45, 3.9, 0.45), Color3.fromRGB(255, 140, 120))
ensureTool("Warden's Halberd", Vector3.new(0.4, 4.4, 0.4), Color3.fromRGB(185, 185, 200))
ensureTool("Dragonspear Halberd", Vector3.new(0.4, 4.4, 0.4), Color3.fromRGB(200, 120, 120))
ensureTool("Hunter's Longbow", Vector3.new(0.35, 2.8, 0.35), Color3.fromRGB(140, 90, 50))
ensureTool("Stormwind Recurve", Vector3.new(0.35, 2.8, 0.35), Color3.fromRGB(110, 170, 220))
ensureTool("Apprentice Arcstaff", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(120, 80, 200))
ensureTool("Archmage's Worldstaff", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(255, 120, 120))
ensureTool("Blackpowder Flintlock", Vector3.new(0.45, 1.6, 0.7), Color3.fromRGB(80, 80, 90))
ensureTool("Kingslayer Handcannon", Vector3.new(0.45, 1.6, 0.7), Color3.fromRGB(255, 160, 60))

print("[WeaponSetup] WeaponTemplates ready:", WeaponTemplates:GetFullName())
