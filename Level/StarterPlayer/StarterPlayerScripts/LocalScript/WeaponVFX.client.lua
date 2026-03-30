-- WeaponVFX.client.lua (StarterPlayerScripts)
-- Spawns a short-lived visible weapon model at the hit position, based on ReplicatedStorage/WeaponVFXTemplates.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local VFXEvent = Remotes:WaitForChild("WeaponSwingVFX")

local templates = ReplicatedStorage:WaitForChild("WeaponVFXTemplates")

local function getTemplate(weaponId: string)
	local t = templates:FindFirstChild(weaponId)
	if t then return t end
	-- fallback: first child
	return templates:FindFirstChildWhichIsA("Tool")
end

local function spawnVFX(payload)
	local weaponId = tostring(payload.weaponId or "")
	local pos = payload.pos
	local lookAt = payload.lookAt

	if typeof(pos) ~= "Vector3" then return end

	local template = getTemplate(weaponId)
	if not template then return end

	local clone = template:Clone()
	-- convert Tool to Model-like placement
	local handle = clone:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		clone:Destroy()
		return
	end

	clone.Parent = workspace
	-- place a bit lower and offset so it doesn't clip
	local offset = Vector3.new(0, -1.0, 0)
	local cf
	if typeof(lookAt) == "Vector3" then
		cf = CFrame.lookAt(pos + offset, lookAt)
	else
		cf = CFrame.new(pos + offset)
	end

	-- Put handle at cf, move rest relative
	local delta = cf * handle.CFrame:Inverse()
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CFrame = delta * p.CFrame
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
		end
	end

	-- lifetime
	Debris:AddItem(clone, 0.35)
end

VFXEvent.OnClientEvent:Connect(spawnVFX)
