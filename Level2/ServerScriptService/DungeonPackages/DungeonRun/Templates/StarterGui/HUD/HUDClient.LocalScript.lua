local TweenService = game:GetService("TweenService")
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
local XP_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local fillTween: Tween? = nil

local function stopFillTween()
	if fillTween then
		fillTween:Cancel()
		fillTween = nil
	end
end

local function setFillRatio(ratio: number, animated: boolean)
	local targetSize = UDim2.new(ratio, 0, 1, 0)
	if fill.Size == targetSize then
		stopFillTween()
		return
	end

	stopFillTween()
	if not animated then
		fill.Size = targetSize
		return
	end

	fillTween = TweenService:Create(fill, XP_TWEEN_INFO, {
		Size = targetSize,
	})
	fillTween.Completed:Connect(function()
		if fillTween then
			fillTween = nil
		end
	end)
	fillTween:Play()
end

local function setXP(level: number, xp: number, nextXp: number, animated: boolean?)
	nextXp = math.max(1, tonumber(nextXp) or 1)
	xp = math.max(0, tonumber(xp) or 0)
	level = tonumber(level) or 0

	local ratio = math.clamp(xp / nextXp, 0, 1)
	setFillRatio(ratio, animated == true)

	lvlText.Text = ("LVL %d"):format((level or 0) + 1)
	xpText.Text = ("%d/%d"):format(math.floor(xp), math.floor(nextXp))
end

-- start default
setXP(0, 0, 100, false)

progressEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type ~= "progress" then return end
	setXP(payload.level, payload.xp, payload.nextXp, true)
end)

-- Pull initial snapshot (first server push can happen before this UI binds).
task.defer(function()
	progressEvent:FireServer({ type = "requestSync" })
end)
