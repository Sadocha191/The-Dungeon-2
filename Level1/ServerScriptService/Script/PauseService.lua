-- PauseService.server.lua (ServerScriptService)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpgradeEvent = remotes:WaitForChild("UpgradeEvent")

-- Global pause state visible to other scripts (WaveController, itp.)
local PauseState = ReplicatedStorage:FindFirstChild("PauseState")
if not PauseState then
	PauseState = Instance.new("BoolValue")
	PauseState.Name = "PauseState"
	PauseState.Value = false
	PauseState.Parent = ReplicatedStorage
end

local enemiesFolder = workspace:FindFirstChild("Enemies")
if not enemiesFolder then
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = workspace
end

-- Kto trzyma pauzę (jeśli masz multi, to pauza dotyczy wszystkich)
local holders: {[number]: boolean} = {}

-- Backup humanoidów (gracze + moby)
local playerBackup: {[number]: {ws:number, jp:number, useJP:boolean?, ar:boolean?}} = {}
local mobBackup: {[Instance]: {ws:number, jp:number, useJP:boolean?, ar:boolean?}} = {}

local function freezeHumanoid(h: Humanoid, backupTable, key)
	if not h or h.Health <= 0 then return end
	if backupTable[key] then return end

	local rec = {
		ws = h.WalkSpeed,
		jp = h.JumpPower,
		useJP = (pcall(function() return h.UseJumpPower end) and h.UseJumpPower) or nil,
		ar = h.AutoRotate,
	}
	backupTable[key] = rec

	h.WalkSpeed = 0
	pcall(function()
		h.UseJumpPower = true
		h.JumpPower = 0
	end)
	h.AutoRotate = false

	-- zatrzymaj MoveTo / animacje ruchu jak się da
	h:Move(Vector3.zero, false)
end

local function unfreezeHumanoid(h: Humanoid, backupTable, key)
	local rec = backupTable[key]
	if not rec or not h then return end

	h.WalkSpeed = rec.ws
	pcall(function()
		if rec.useJP ~= nil then h.UseJumpPower = rec.useJP end
		h.JumpPower = rec.jp
	end)
	if rec.ar ~= nil then h.AutoRotate = rec.ar end

	backupTable[key] = nil
end

local function freezeAllPlayers()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			freezeHumanoid(hum, playerBackup, plr.UserId)
		end
	end
end

local function unfreezeAllPlayers()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			unfreezeHumanoid(hum, playerBackup, plr.UserId)
		end
	end
end

local function freezeAllMobs()
	for _, m in ipairs(enemiesFolder:GetChildren()) do
		if m:IsA("Model") then
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum then
				freezeHumanoid(hum, mobBackup, hum)
			end
		end
	end
end

local function unfreezeAllMobs()
	for _, m in ipairs(enemiesFolder:GetChildren()) do
		if m:IsA("Model") then
			local hum = m:FindFirstChildOfClass("Humanoid")
			if hum then
				unfreezeHumanoid(hum, mobBackup, hum)
			end
		end
	end
end

local function anyHolders()
	for _, v in pairs(holders) do
		if v then return true end
	end
	return false
end

local function applyPauseState()
	local shouldPause = anyHolders()
	if PauseState.Value == shouldPause then return end

	PauseState.Value = shouldPause
	if shouldPause then
		freezeAllPlayers()
		freezeAllMobs()
	else
		unfreezeAllPlayers()
		unfreezeAllMobs()
	end
end

-- Jeśli w trakcie pauzy zrespawnuje się mob albo gracz – natychmiast go zamroź
Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.1)
		if PauseState.Value then
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if hum then freezeHumanoid(hum, playerBackup, plr.UserId) end
		end
	end)
end)

enemiesFolder.ChildAdded:Connect(function(child)
	if not PauseState.Value then return end
	if child:IsA("Model") then
		task.wait(0.05)
		local hum = child:FindFirstChildOfClass("Humanoid")
		if hum then freezeHumanoid(hum, mobBackup, hum) end
	end
end)

-- Pause requests z klienta (Upgrade menu)
local throttle: {[number]: number} = {}
UpgradeEvent.OnServerEvent:Connect(function(plr, msg)
	if typeof(msg) ~= "table" then return end
	if msg.type ~= "PAUSE" then return end

	local now = os.clock()
	if throttle[plr.UserId] and (now - throttle[plr.UserId]) < 0.15 then return end
	throttle[plr.UserId] = now

	local open = msg.open == true
	holders[plr.UserId] = open
	applyPauseState()
end)
