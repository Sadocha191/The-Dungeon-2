-- DamageIndicators.server.lua
-- Emits floating damage numbers for player hits on enemies.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes", 5)
if not remotes then
	warn("[DamageIndicators] Missing ReplicatedStorage.Remotes")
	return
end

local DamageIndicatorEvent = remotes:FindFirstChild("DamageIndicatorEvent")
if not DamageIndicatorEvent then
	DamageIndicatorEvent = Instance.new("RemoteEvent")
	DamageIndicatorEvent.Name = "DamageIndicatorEvent"
	DamageIndicatorEvent.Parent = remotes
end

local lastHealthByHumanoid: {[Humanoid]: number} = {}
local trackedModels: {[Model]: boolean} = {}

local function getNearestPlayer(pos: Vector3, maxDist: number): Player?
	local best: Player? = nil
	local bestDist = maxDist
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - pos).Magnitude
			if d < bestDist then
				bestDist = d
				best = plr
			end
		end
	end
	return best
end

local function getAttackerFromCreator(humanoid: Humanoid): Player?
	local creator = humanoid:FindFirstChild("creator")
	if not creator or not creator:IsA("ObjectValue") then
		return nil
	end
	local value = creator.Value
	if value and value:IsA("Player") then
		return value
	end
	return nil
end

local function fireIndicator(plr: Player, enemyModel: Model, amount: number)
	if amount <= 0 then return end
	local hrp = enemyModel:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	DamageIndicatorEvent:FireClient(plr, {
		pos = hrp.Position + Vector3.new(0, 2, 0),
		amount = math.floor(amount + 0.5),
		crit = false,
	})
end

local function trackHumanoid(enemyModel: Model, humanoid: Humanoid)
	if lastHealthByHumanoid[humanoid] ~= nil then
		return
	end
	lastHealthByHumanoid[humanoid] = humanoid.Health

	humanoid.HealthChanged:Connect(function(newHealth)
		local oldHealth = lastHealthByHumanoid[humanoid]
		if oldHealth == nil then
			lastHealthByHumanoid[humanoid] = newHealth
			return
		end

		if newHealth < oldHealth then
			local dealt = oldHealth - newHealth
			local attacker = getAttackerFromCreator(humanoid)
			if not attacker then
				local hrp = enemyModel:FindFirstChild("HumanoidRootPart")
				if hrp then
					attacker = getNearestPlayer(hrp.Position, 120)
				end
			end
			if attacker and attacker.Parent == Players then
				fireIndicator(attacker, enemyModel, dealt)
			end
		end

		lastHealthByHumanoid[humanoid] = newHealth
	end)

	humanoid.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			lastHealthByHumanoid[humanoid] = nil
		end
	end)
end

local function tryTrackEnemy(enemyModel: Instance)
	if not enemyModel:IsA("Model") then
		return
	end
	if trackedModels[enemyModel] then
		return
	end
	trackedModels[enemyModel] = true

	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	if humanoid then
		trackHumanoid(enemyModel, humanoid)
	end

	enemyModel.ChildAdded:Connect(function(child)
		if child:IsA("Humanoid") then
			trackHumanoid(enemyModel, child)
		end
	end)
end

local function bindEnemiesFolder(folder: Instance)
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("Model") then
			tryTrackEnemy(d)
		end
	end
	folder.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			tryTrackEnemy(d)
		elseif d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
			tryTrackEnemy(d.Parent)
		end
	end)
end

local enemiesFolder = workspace:FindFirstChild("Enemies") or workspace:FindFirstChild("Mobs")
if enemiesFolder then
	bindEnemiesFolder(enemiesFolder)
else
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Enemies" or child.Name == "Mobs" then
			bindEnemiesFolder(child)
		end
	end)
end
