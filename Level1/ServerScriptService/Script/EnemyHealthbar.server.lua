-- EnemyHealthbar.server.lua (ServerScriptService/Script)
-- Shows a small health bar above enemies after they take damage.

local EnemiesFolder = workspace:WaitForChild("Enemies")

local function makeBillboard(enemy: Model, hum: Humanoid, adornee: BasePart)
	local bb = Instance.new("BillboardGui")
	bb.Name = "EnemyHealthBar"
	bb.Adornee = adornee
	bb.Size = UDim2.new(4, 0, 0.6, 0)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Enabled = false

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundTransparency = 0.25
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BorderSizePixel = 0
	bg.Parent = bb

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
	fill.Parent = bg

	local uic = Instance.new("UICorner")
	uic.CornerRadius = UDim.new(0, 4)
	uic.Parent = bg

	local uic2 = Instance.new("UICorner")
	uic2.CornerRadius = UDim.new(0, 4)
	uic2.Parent = fill

	local lastDamageAt = 0
	local hideDelay = 6.0
	local max = math.max(1, hum.MaxHealth)

	local function updateBar()
		local hp = math.max(0, hum.Health)
		local pct = hp / max
		fill.Size = UDim2.new(pct, 0, 1, 0)
	end

	local function showTemporarily()
		lastDamageAt = os.clock()
		bb.Enabled = true
		updateBar()

		task.delay(hideDelay, function()
			if not bb.Parent then return end
			if os.clock() - lastDamageAt >= hideDelay - 0.05 then
				-- Keep visible if still not full HP; otherwise hide
				if hum.Health >= hum.MaxHealth then
					bb.Enabled = false
				else
					-- still injured: keep on
					bb.Enabled = true
				end
			end
		end)
	end

	local prev = hum.Health
	hum.HealthChanged:Connect(function(newHp)
		-- Only react when taking damage (not healing)
		if newHp < prev then
			showTemporarily()
		else
			updateBar()
		end
		prev = newHp
	end)

	hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		max = math.max(1, hum.MaxHealth)
		updateBar()
	end)

	bb.Parent = enemy
	return bb
end

local function attach(enemy: Model)
	if not enemy or not enemy:IsA("Model") then return end
	if enemy:FindFirstChild("EnemyHealthBar") then return end

	local hum = enemy:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local adornee = enemy:FindFirstChild("Head") or enemy:FindFirstChild("HumanoidRootPart")
	if not (adornee and adornee:IsA("BasePart")) then return end

	makeBillboard(enemy, hum, adornee)
end

for _, enemy in ipairs(EnemiesFolder:GetChildren()) do
	attach(enemy)
end

EnemiesFolder.ChildAdded:Connect(function(enemy)
	task.defer(function()
		attach(enemy)
	end)
end)
