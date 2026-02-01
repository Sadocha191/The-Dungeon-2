local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local xpBar = gui:WaitForChild("XPBar")
local fill = xpBar:WaitForChild("Fill")
local lvlText = xpBar:WaitForChild("LvlText")
local xpText = xpBar:WaitForChild("XpText")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local progressEvent = remotes:WaitForChild("PlayerProgressEvent")

local function setXP(level: number, xp: number, nextXp: number)
	nextXp = math.max(1, tonumber(nextXp) or 1)
	xp = math.max(0, tonumber(xp) or 0)
	level = tonumber(level) or 0

	local ratio = math.clamp(xp / nextXp, 0, 1)
	fill.Size = UDim2.new(ratio, 0, 1, 0)

	lvlText.Text = ("LVL %d"):format(math.max(1, level))
	xpText.Text = ("%d/%d"):format(math.floor(xp), math.floor(nextXp))
end

-- start default
setXP(0, 0, 100)

progressEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type ~= "progress" then return end
	setXP(payload.level, payload.xp, payload.nextXp)
end)
