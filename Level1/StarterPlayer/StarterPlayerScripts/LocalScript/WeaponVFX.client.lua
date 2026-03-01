-- WeaponVFX.client.lua (StarterPlayerScripts/LocalScript)
-- Spawns weapon model only when damage tick happens (server fires WeaponSwingVFX).
-- Position is a bit further and lower than before.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local plr = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local evt = Remotes:WaitForChild("WeaponSwingVFX")

local templates = ReplicatedStorage:WaitForChild("WeaponVFXTemplates")

local function getPivot(instance: Instance): CFrame
	if instance:IsA("Model") then
		return instance:GetPivot()
	elseif instance:IsA("Tool") then
		local handle = instance:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle.CFrame
		end
	end
	return CFrame.new()
end

local function setPivot(instance: Instance, cf: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(cf)
	elseif instance:IsA("Tool") then
		local handle = instance:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = cf
		end
	end
end

local function ensurePrimary(instance: Instance)
	if instance:IsA("Model") then
		if not instance.PrimaryPart then
			local pp = instance:FindFirstChild("Handle", true)
			if pp and pp:IsA("BasePart") then
				instance.PrimaryPart = pp
			else
				for _, d in ipairs(instance:GetDescendants()) do
					if d:IsA("BasePart") then
						instance.PrimaryPart = d
						break
					end
				end
			end
		end
	end
end

local function spawnSwingVFX(data)
	local weaponId = data.weaponId
	local origin: CFrame = data.origin
	if typeof(weaponId) ~= "string" or typeof(origin) ~= "CFrame" then return end

	local src = templates:FindFirstChild(weaponId)
	if not src then return end

	local vfx = src:Clone()
	vfx.Name = "VFX_" .. weaponId

	ensurePrimary(vfx)

	-- target position: a bit further and lower (forward = -Z in object space)
	local base = origin * CFrame.new(0.6, -1.1, -4.5)

	-- simple "appear + slash" animation: rotate a bit and fade out quickly
	setPivot(vfx, base * CFrame.Angles(0, math.rad(30), math.rad(-35)))
	vfx.Parent = workspace

	-- if Tool, parent its Handle(s) to workspace visually via tool itself (Tool can be in workspace)
	-- keep it non-interactive
	for _, d in ipairs(vfx:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end

	-- rotate quickly (visual slash)
	local tInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local goalCF = base * CFrame.Angles(0, math.rad(-40), math.rad(35))

	-- We tween via a CFrameValue driving PivotTo
	local driver = Instance.new("CFrameValue")
	driver.Value = getPivot(vfx)
	driver:GetPropertyChangedSignal("Value"):Connect(function()
		if vfx and vfx.Parent then
			setPivot(vfx, driver.Value)
		end
	end)

	local tw = TweenService:Create(driver, tInfo, { Value = goalCF })
	tw:Play()

	-- cleanup
	Debris:AddItem(driver, 0.3)
	Debris:AddItem(vfx, 0.35)
end

evt.OnClientEvent:Connect(spawnSwingVFX)
