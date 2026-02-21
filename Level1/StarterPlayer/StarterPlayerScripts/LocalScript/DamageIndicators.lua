-- DamageIndicators.client.lua (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local plr = Players.LocalPlayer
local pg = plr:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local DamageIndicatorEvent = remotes:WaitForChild("DamageIndicatorEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "DamageIndicators"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = pg

local function popText(worldPos: Vector3, amount: number, crit: boolean)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2,0.2,0.2)
	part.CFrame = CFrame.new(worldPos)
	part.Parent = workspace

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(180, 64)
	bb.StudsOffset = Vector3.new(0, 1.1, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = part

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1,1)
	t.Font = crit and Enum.Font.GothamBlack or Enum.Font.GothamSemibold
	t.TextSize = crit and 34 or 30
	t.TextStrokeTransparency = 0
	-- normal: white + black outline, crit: red + black outline
	t.TextColor3 = crit and Color3.fromRGB(235, 60, 60) or Color3.fromRGB(255, 255, 255)
	t.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	t.Text = tostring(amount)
	t.Parent = bb

	local goalPos = worldPos + Vector3.new((math.random()-0.5)*1.2, 1.6 + math.random()*0.6, (math.random()-0.5)*1.2)
	local tween = TweenService:Create(part, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(goalPos) })
	tween:Play()

	local fade = TweenService:Create(t, TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1, TextStrokeTransparency = 1 })
	fade:Play()

	task.delay(1.25, function()
		if part then part:Destroy() end
	end)
end

DamageIndicatorEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local pos = payload.pos
	local amount = payload.amount
	local crit = payload.crit
	if typeof(pos) ~= "Vector3" or typeof(amount) ~= "number" then return end
	popText(pos, amount, crit == true)
end)
