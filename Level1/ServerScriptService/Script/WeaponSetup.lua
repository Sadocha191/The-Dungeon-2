-- WeaponSetup.server.lua (ServerScriptService)
-- Tworzy broń testową jeśli jej nie ma (Sword/Scythe/Halberd/Bow/Staff/Pistol)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponTemplates = ReplicatedStorage:FindFirstChild("WeaponTemplates")
if not WeaponTemplates then
	WeaponTemplates = Instance.new("Folder")
	WeaponTemplates.Name = "WeaponTemplates"
	WeaponTemplates.Parent = ReplicatedStorage
end

local function ensureTool(toolName: string, weaponType: string, handleSize: Vector3, handleColor: Color3, stats: {[string]: number}?)
	local existing = WeaponTemplates:FindFirstChild(toolName)
	if existing and existing:IsA("Tool") then
		existing:SetAttribute("WeaponType", weaponType)
		if stats then
			for key, value in pairs(stats) do
				existing:SetAttribute(key, value)
			end
		end
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = toolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("WeaponType", weaponType)
	tool:SetAttribute("WeaponLevel", 1)

	if stats then
		for key, value in pairs(stats) do
			tool:SetAttribute(key, value)
		end
	end

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

ensureTool("Sword", "Sword", Vector3.new(0.35, 3.6, 0.35), Color3.fromRGB(210, 210, 220), {
	BaseATK = 18,
	ATKPerLevel = 2,
	BonusCritRate = 0.03,
	BonusDefense = 2,
})
ensureTool("Scythe", "Scythe", Vector3.new(0.45, 3.9, 0.45), Color3.fromRGB(160, 160, 170), {
	BaseATK = 22,
	ATKPerLevel = 2.4,
	BonusHP = 40,
	BonusLifesteal = 0.02,
})
ensureTool("Halberd", "Halberd", Vector3.new(0.4, 4.4, 0.4), Color3.fromRGB(185, 185, 200), {
	BaseATK = 20,
	ATKPerLevel = 2.2,
	BonusDefense = 3,
})
ensureTool("Bow", "Bow", Vector3.new(0.35, 2.8, 0.35), Color3.fromRGB(140, 90, 50), {
	BaseATK = 16,
	ATKPerLevel = 1.8,
	BonusCritRate = 0.05,
})
ensureTool("Staff", "Staff", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(120, 80, 200), {
	BaseATK = 17,
	ATKPerLevel = 2.0,
	BonusCritDmg = 0.1,
})
ensureTool("Wand", "Staff", Vector3.new(0.35, 3.2, 0.35), Color3.fromRGB(120, 80, 200), {
	BaseATK = 17,
	ATKPerLevel = 2.0,
	BonusCritDmg = 0.1,
})
ensureTool("Pistol", "Pistol", Vector3.new(0.45, 1.6, 0.7), Color3.fromRGB(80, 80, 90), {
	BaseATK = 15,
	ATKPerLevel = 1.6,
	BonusCritRate = 0.04,
	BonusSpeed = 0.03,
})

print("[WeaponSetup] WeaponTemplates ready:", WeaponTemplates:GetFullName())
