-- RunReadyGate.server.lua (Level1)
-- Blocks gameplay until each client preloads assets and fires Remotes.ClientReady.
-- When all current players are ready -> sets ReplicatedStorage.RunStarted = true.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClientReady = remotes:WaitForChild("ClientReady")

local RunStarted = ReplicatedStorage:FindFirstChild("RunStarted")
if not RunStarted then
	RunStarted = Instance.new("BoolValue")
	RunStarted.Name = "RunStarted"
	RunStarted.Value = false
	RunStarted.Parent = ReplicatedStorage
end

local ready: {[Player]: boolean} = {}

local function freeze(plr: Player, state: boolean)
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if hum then
		if state then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		else
			-- Default values (adjust if you override elsewhere)
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		end
	end

	if hrp then
		hrp.Anchored = state
	end
end

local function allReadyNow(): boolean
	for _, plr in ipairs(Players:GetPlayers()) do
		if ready[plr] ~= true then
			return false
		end
	end
	return true
end

local function tryStart()
	if RunStarted.Value then return end
	if #Players:GetPlayers() == 0 then return end
	if allReadyNow() then
		RunStarted.Value = true
		-- Unfreeze everyone
		for _, plr in ipairs(Players:GetPlayers()) do
			freeze(plr, false)
		end
	end
end

Players.PlayerAdded:Connect(function(plr)
	ready[plr] = false

	plr.CharacterAdded:Connect(function()
		-- Freeze immediately until client preloads
		if not RunStarted.Value then
			freeze(plr, true)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	ready[plr] = nil
	-- If someone leaves mid-load, we can still start for remaining
	task.defer(tryStart)
end)

ClientReady.OnServerEvent:Connect(function(plr)
	ready[plr] = true
	tryStart()
end)

-- If server starts with players already in (rare), init them:
for _, plr in ipairs(Players:GetPlayers()) do
	ready[plr] = false
end
