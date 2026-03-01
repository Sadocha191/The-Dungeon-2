-- WeaponVFX.client.lua (StarterPlayerScripts)
-- Wyświetla "latającą" broń tylko w momencie ataku (tick dmg) i dokładnie tam gdzie trafiła.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WeaponSwingVFX = Remotes:WaitForChild("WeaponSwingVFX")

local assets = ReplicatedStorage:WaitForChild("Assets")
local vfxFolder = assets:WaitForChild("WeaponVFX")

local function setAllParts(inst: Instance)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.Massless = true
		end
	end
end

local function pivotToToolOrModel(inst: Instance, cf: CFrame)
	if inst:IsA("Tool") then
		local handle = inst:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = cf
		else
			-- fallback: ustaw wszystkie partsy
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CFrame = cf
					break
				end
			end
		end
	else
		-- Model/Folder
		if inst:IsA("Model") and inst.PrimaryPart then
			inst:PivotTo(cf)
		else
			for _, d in ipairs(inst:GetDescendants()) do
				if d:IsA("BasePart") then
					local delta = d.CFrame.Position - d.Position
					d.CFrame = cf
					break
				end
			end
		end
	end
end

local function spawnWeaponVFX(weaponId: string, weaponType: string, hitPos: Vector3, dir: Vector3)
	local template = vfxFolder:FindFirstChild(weaponId)
	if not template then
		-- fallback: spróbuj po typie
		template = vfxFolder:FindFirstChild(weaponType)
	end
	if not template then
		return
	end

	local inst = template:Clone()
	inst.Name = "WeaponVFX_" .. weaponId

	setAllParts(inst)

	-- broń ma być w miejscu trafienia, minimalny offset: lekko niżej + lekko w kierunku ciosu
	dir = (dir.Magnitude > 0.001) and dir.Unit or Vector3.new(0, 0, -1)
	local pos = hitPos + (dir * 1.0) + Vector3.new(0, -0.35, 0)

	local yaw = math.atan2(-dir.Z, dir.X) -- orientacja “na wprost” kierunku ataku
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, math.rad(90), 0)

	inst.Parent = workspace
	pivotToToolOrModel(inst, cf)

	Debris:AddItem(inst, 0.35)
end

WeaponSwingVFX.OnClientEvent:Connect(function(weaponId: string, weaponType: string, hitPos: Vector3, dir: Vector3)
	spawnWeaponVFX(weaponId, weaponType, hitPos, dir)
end)
