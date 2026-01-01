-- SCRIPT: WeaponTemplates.server.lua
-- GDZIE: ServerScriptService/WeaponTemplates.server.lua (Script)
-- CO: generuje proste modele broni (placeholdery) poprawnie jako Tool/Handle

local ServerStorage = game:GetService("ServerStorage")

local folder = ServerStorage:FindFirstChild("WeaponTemplates")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "WeaponTemplates"
	folder.Parent = ServerStorage
else
	-- czyścimy stare szablony, żeby nie dublować
	for _, c in ipairs(folder:GetChildren()) do
		c:Destroy()
	end
end

local function makeHandle(size: Vector3): Part
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = size
	h.CanCollide = false
	h.Massless = true
	h.TopSurface = Enum.SurfaceType.Smooth
	h.BottomSurface = Enum.SurfaceType.Smooth

	-- punkt pod efekty / trail / VFX
	local att = Instance.new("Attachment")
	att.Name = "VFX"
	att.Parent = h

	return h
end

local function weld(part0: BasePart, part1: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part0
end

local function makeTool(toolName: string, weaponType: string, baseDamage: number, handleSize: Vector3, extrasBuilder, sellValue: number?)
	local tool = Instance.new("Tool")
	tool.Name = toolName
	tool.CanBeDropped = false

	tool:SetAttribute("WeaponType", weaponType)
	tool:SetAttribute("BaseDamage", baseDamage)
	tool:SetAttribute("Rarity", "Common")
	tool:SetAttribute("SellValue", sellValue or math.max(1, math.floor(baseDamage * 3)))

	local handle = makeHandle(handleSize)
	handle.Parent = tool

	if extrasBuilder then
		extrasBuilder(tool, handle)
	end

	tool.Parent = folder
end

-- ===== MODELE (placeholdery) =====

-- Rusty Sword: ostrze + jelec
makeTool("Rusty Sword", "Sword", 10, Vector3.new(0.3, 3.2, 0.3), function(tool, handle)
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.25, 3.8, 0.18)
	blade.CanCollide = false
	blade.Massless = true
	blade.Parent = tool
	blade.CFrame = handle.CFrame * CFrame.new(0, 3.0, 0)
	weld(handle, blade)

	local guard = Instance.new("Part")
	guard.Name = "Guard"
	guard.Size = Vector3.new(1.2, 0.2, 0.2)
	guard.CanCollide = false
	guard.Massless = true
	guard.Parent = tool
	guard.CFrame = handle.CFrame * CFrame.new(0, 1.2, 0)
	weld(handle, guard)
end, 30)

-- Apprentice Staff: kij + “główka”
makeTool("Apprentice Staff", "Staff", 8, Vector3.new(0.35, 4.4, 0.35), function(tool, handle)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(0.9, 0.9, 0.9)
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool
	head.CFrame = handle.CFrame * CFrame.new(0, 2.6, 0)
	weld(handle, head)
end, 24)

-- Worn Dagger: krótkie ostrze
makeTool("Worn Dagger", "Dagger", 9, Vector3.new(0.25, 1.7, 0.25), function(tool, handle)
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.18, 2.0, 0.12)
	blade.CanCollide = false
	blade.Massless = true
	blade.Parent = tool
	blade.CFrame = handle.CFrame * CFrame.new(0, 1.4, 0)
	weld(handle, blade)
end, 27)

-- Old Spear
makeTool("Old Spear", "Spear", 10, Vector3.new(0.22, 5.0, 0.22), function(tool, handle)
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.35, 0.8, 0.35)
	tip.CanCollide = false
	tip.Massless = true
	tip.Parent = tool
	tip.CFrame = handle.CFrame * CFrame.new(0, 3.0, 0)
	weld(handle, tip)
end, 30)

-- Simple Bow (placeholder: łuk jako 2 “ramiona”)
makeTool("Simple Bow", "Bow", 8, Vector3.new(0.25, 2.8, 0.25), function(tool, handle)
	local arm1 = Instance.new("Part")
	arm1.Name = "Arm1"
	arm1.Size = Vector3.new(0.2, 1.6, 0.2)
	arm1.CanCollide = false
	arm1.Massless = true
	arm1.Parent = tool
	arm1.CFrame = handle.CFrame * CFrame.new(0.5, 0.8, 0) * CFrame.Angles(0, 0, math.rad(20))
	weld(handle, arm1)

	local arm2 = Instance.new("Part")
	arm2.Name = "Arm2"
	arm2.Size = Vector3.new(0.2, 1.6, 0.2)
	arm2.CanCollide = false
	arm2.Massless = true
	arm2.Parent = tool
	arm2.CFrame = handle.CFrame * CFrame.new(0.5, -0.8, 0) * CFrame.Angles(0, 0, math.rad(-20))
	weld(handle, arm2)
end, 24)

-- Training Mace (kij + kula)
makeTool("Training Mace", "Mace", 10, Vector3.new(0.35, 3.0, 0.35), function(tool, handle)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.0, 1.0, 1.0)
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool
	head.CFrame = handle.CFrame * CFrame.new(0, 2.1, 0)
	weld(handle, head)
end, 30)

print("[WeaponTemplates] Generated:", #folder:GetChildren())
