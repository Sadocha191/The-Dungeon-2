-- WeaponClient.client.lua (StarterPlayerScripts)
-- Cosmetic floating weapon visuals (player does NOT hold Tool in hand)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local PauseState = ReplicatedStorage:WaitForChild("PauseState")

local visualModel: Model? = nil
local sourceTool: Tool? = nil
local rsConn: RBXScriptConnection? = nil

local Profiles = {
	Sword    = { radius = 3.2, height = 1.6, halfAngleDeg = 45,  spin = 3.0 },
	Scythe   = { radius = 3.6, height = 1.7, halfAngleDeg = 90,  spin = 2.2 },
	Halberd  = { radius = 3.8, height = 1.8, halfAngleDeg = 35,  spin = 2.4 },
	Claymore = { radius = 3.4, height = 1.7, halfAngleDeg = 65,  spin = 2.0 },
	Greataxe = { radius = 3.5, height = 1.7, halfAngleDeg = 75,  spin = 1.8 },
}

local function isWeaponTool(inst: Instance): boolean
	return inst:IsA("Tool") and typeof(inst:GetAttribute("WeaponType")) == "string"
end

local function getActiveWeaponTool(): Tool?
	local backpack = plr:FindFirstChildOfClass("Backpack")
	if not backpack then return nil end
	for _, child in ipairs(backpack:GetChildren()) do
		if isWeaponTool(child) then
			return child
		end
	end
	return nil
end

local function cleanupVisual()
	if rsConn then
		rsConn:Disconnect()
		rsConn = nil
	end
	if visualModel then
		visualModel:Destroy()
		visualModel = nil
	end
	sourceTool = nil
end

local function stripForVisual(inst: Instance)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Anchored = true
			d.Massless = true
		end
	end
end

local function ensurePrimaryPart(model: Model)
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then return end
	local handle = model:FindFirstChild("Handle", true)
	if handle and handle:IsA("BasePart") then
		model.PrimaryPart = handle
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			model.PrimaryPart = d
			return
		end
	end
end

local function buildVisualFromTool(tool: Tool): Model?
	local clone = tool:Clone()
	clone.Name = "WeaponVisual"
	clone.Parent = nil

	stripForVisual(clone)

	-- Wrap Tool into Model for easier CFrame setting
	local model = Instance.new("Model")
	model.Name = "WeaponVisualModel"
	model.Parent = workspace

	for _, child in ipairs(clone:GetChildren()) do
		child.Parent = model
	end
	clone:Destroy()

	ensurePrimaryPart(model)
	if not model.PrimaryPart then
		model:Destroy()
		return nil
	end

	return model
end

local function updateVisualLoop(tool: Tool, model: Model)
	local wType = tool:GetAttribute("WeaponType")
	if typeof(wType) ~= "string" then return end
	local prof = Profiles[wType]
	if not prof then return end

	rsConn = RunService.RenderStepped:Connect(function()
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not model.Parent or not model.PrimaryPart then return end

		-- Keep visible even on pause, but stop "swing" animation
		local t = os.clock()
		local swingT = PauseState.Value and 0 or t

		local half = math.rad(prof.halfAngleDeg)
		local ang = math.sin(swingT * prof.spin) * half

		-- Center in front of player, then swing within sector
		local base = hrp.CFrame
		local cf = base
			* CFrame.Angles(0, ang, 0)
			* CFrame.new(0, prof.height, -prof.radius)
			* CFrame.Angles(0, math.pi, 0) -- face roughly toward player

		model:PivotTo(cf)
	end)
end

local function refresh()
	local tool = getActiveWeaponTool()
	if tool == sourceTool and visualModel then
		return
	end

	cleanupVisual()

	if not tool then return end
	sourceTool = tool

	local model = buildVisualFromTool(tool)
	if not model then
		sourceTool = nil
		return
	end
	visualModel = model

	updateVisualLoop(tool, model)
end

local function onCharacterAdded()
	task.wait(0.2)
	refresh()
end

-- React to backpack changes
local function bindBackpack()
	local backpack = plr:WaitForChild("Backpack", 10)
	if not backpack then return end
	backpack.ChildAdded:Connect(function() task.defer(refresh) end)
	backpack.ChildRemoved:Connect(function() task.defer(refresh) end)
end

bindBackpack()
plr.CharacterAdded:Connect(onCharacterAdded)
if plr.Character then
	onCharacterAdded()
end

-- Also refresh when pause toggles (so visual doesn't break)
PauseState.Changed:Connect(function()
	task.defer(refresh)
end)
