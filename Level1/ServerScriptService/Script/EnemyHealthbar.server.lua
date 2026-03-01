-- EnemyHealthbar.server.lua
-- Shows a simple health bar above enemies only after they take damage.

local EnemiesFolder = workspace:WaitForChild("Enemies")

local function ensureHealthbar(enemy: Model)
	local hum = enemy:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local head = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") then return end

	local existing = enemy:FindFirstChild("_DamageHealthbar")
	if existing then return end

	local holder = Instance.new("Folder")
	holder.Name = "_DamageHealthbar"
	holder.Parent = enemy

	local bb = Instance.new("BillboardGui")
	bb.Name = "Healthbar"
	bb.Size = UDim2.fromOffset(120, 16)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Enabled = true
	bb.Parent = holder
	bb.Adornee = head

	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = bb

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 2)
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 2)
	pad.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 120)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = bg
	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 3)
	corner2.Parent = fill

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Transparency = 0.4
	stroke.Parent = bg

	local function update()
		local ratio = 0
		if hum.MaxHealth > 0 then
			ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		end
		fill.Size = UDim2.fromScale(ratio, 1)
	end

	update()
	hum.HealthChanged:Connect(update)
end

local function hook(enemy: Instance)
	if not enemy:IsA("Model") then return end
	local hum = enemy:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local started = false
	local last = hum.Health

	hum.HealthChanged:Connect(function(newHealth)
		if not started and newHealth < hum.MaxHealth then
			started = true
			ensureHealthbar(enemy)
		end
		last = newHealth
	end)
end

for _, e in ipairs(EnemiesFolder:GetChildren()) do
	hook(e)
end

EnemiesFolder.ChildAdded:Connect(hook)
