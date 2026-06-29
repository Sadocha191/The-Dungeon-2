local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local debugFolder = ReplicatedStorage:FindFirstChild("DebugSettings")
if not debugFolder then
	debugFolder = Instance.new("Folder")
	debugFolder.Name = "DebugSettings"
	debugFolder.Parent = ReplicatedStorage
end

local function ensureValue(className: string, name: string, defaultValue)
	local value = debugFolder:FindFirstChild(name)
	if value and value.ClassName ~= className then
		value:Destroy()
		value = nil
	end
	if not value then
		value = Instance.new(className)
		value.Name = name
		value.Parent = debugFolder
	end
	value.Value = defaultValue
	return value
end

local godModeEnabled = ensureValue("BoolValue", "GodModeEnabled", true)
ensureValue("BoolValue", "AutoMobSpawnsEnabled", true)
ensureValue("BoolValue", "SpawnStressMode", true)
ensureValue("IntValue", "SpawnBurstSize", 3)
ensureValue("NumberValue", "SpawnIntervalScale", 0.55)
ensureValue("NumberValue", "MaxAliveScale", 2.6)
ensureValue("BoolValue", "PerfHudEnabled", true)

local wrappedDamage = false
local originalApplyDamage = nil

local function installDamageWrapper()
	if wrappedDamage then
		return
	end
	local base = _G.ApplyDamageToPlayer
	if type(base) ~= "function" then
		return
	end
	originalApplyDamage = base
	_G.ApplyDamageToPlayer = function(plr, amount)
		if godModeEnabled.Value == true then
			return 0
		end
		return originalApplyDamage(plr, amount)
	end
	wrappedDamage = true
end

local function syncHumanoidState(humanoid: Humanoid)
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, godModeEnabled.Value ~= true)
	end)
	if godModeEnabled.Value == true and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end
end

local function hookCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid then
		syncHumanoidState(humanoid)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then
		hookCharacter(player.Character)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then
		hookCharacter(player.Character)
	end
end

RunService.Heartbeat:Connect(function()
	installDamageWrapper()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			syncHumanoidState(humanoid)
		end
	end
end)
