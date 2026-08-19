-- WeaponVFX.client.lua (StarterPlayerScripts)
-- Lightweight code-generated impact flash for server-confirmed weapon attacks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WeaponSwingVFX = Remotes:WaitForChild("WeaponSwingVFX")

local ELEMENT_COLORS = {
	Physical = Color3.fromRGB(230, 230, 230),
	Fire = Color3.fromRGB(255, 105, 55),
	Electricity = Color3.fromRGB(125, 185, 255),
	Air = Color3.fromRGB(150, 255, 220),
	Water = Color3.fromRGB(65, 165, 255),
	Earth = Color3.fromRGB(155, 110, 65),
	Void = Color3.fromRGB(155, 80, 255),
	Light = Color3.fromRGB(255, 235, 130),
}

local function makePart(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

local function spawnImpact(payload)
	if typeof(payload) ~= "table" or payload.kind == "equip" then
		return
	end

	local position = payload.pos
	if typeof(position) ~= "Vector3" then
		return
	end

	local element = typeof(payload.element) == "string" and payload.element or "Physical"
	local color = ELEMENT_COLORS[element] or ELEMENT_COLORS.Physical
	local lookAt = payload.lookAt
	local direction = Vector3.new(0, 0, -1)
	if typeof(lookAt) == "Vector3" then
		local delta = position - lookAt
		if delta.Magnitude > 0.1 then
			direction = delta.Unit
		end
	end

	local center = position + Vector3.new(0, 1.1, 0)
	local basis = CFrame.lookAt(center, center + direction)

	local flash = makePart("WeaponImpactFlash", color)
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.45, 0.45, 0.45)
	flash.Transparency = 0.12
	flash.CFrame = CFrame.new(center)
	flash.Parent = workspace

	TweenService:Create(
		flash,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(1.8, 1.8, 1.8),
			Transparency = 1,
		}
	):Play()
	Debris:AddItem(flash, 0.22)

	for index, angle in ipairs({ -48, 48 }) do
		local streak = makePart("WeaponImpactStreak" .. index, color)
		streak.Size = Vector3.new(3.8, 0.12, 0.12)
		streak.Transparency = 0.08
		streak.CFrame = basis * CFrame.Angles(0, 0, math.rad(angle))
		streak.Parent = workspace

		TweenService:Create(
			streak,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = Vector3.new(5.2, 0.04, 0.04),
				Transparency = 1,
			}
		):Play()
		Debris:AddItem(streak, 0.2)
	end
end

WeaponSwingVFX.OnClientEvent:Connect(spawnImpact)
