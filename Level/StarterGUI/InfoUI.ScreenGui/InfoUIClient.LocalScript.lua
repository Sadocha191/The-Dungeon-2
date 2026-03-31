local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gui = script.Parent
if gui and gui:IsA("ScreenGui") then
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
end

local frame = gui:WaitForChild("Frame")

local timerFrame = frame:WaitForChild("Timer")
local timerText = timerFrame:WaitForChild("TimerText")

local killFrame = frame:WaitForChild("KillCount")
local killText = killFrame:WaitForChild("KillCountText")

local coinFrame = frame:WaitForChild("Coin")
local coinText = coinFrame:WaitForChild("CoinText")

local soulsFrame = frame:WaitForChild("Souls")
local soulsText = soulsFrame:WaitForChild("SoulText")

-- Config: 20:00 countdown -> then count up
local RUN_TARGET_SECONDS = 20 * 60

local function fmtMMSS(totalSeconds: number)
	totalSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
	local m = math.floor(totalSeconds / 60)
	local s = totalSeconds % 60
	return string.format("%02d:%02d", m, s)
end

local function setTimerFromElapsed(elapsedSeconds: number)
	elapsedSeconds = math.max(0, math.floor(tonumber(elapsedSeconds) or 0))
	if elapsedSeconds < RUN_TARGET_SECONDS then
		timerText.Text = fmtMMSS(RUN_TARGET_SECONDS - elapsedSeconds)
	else
		local overtime = elapsedSeconds - RUN_TARGET_SECONDS
		-- Po 15:00 licznik leci w górę
		timerText.Text = "+" .. fmtMMSS(overtime)
	end
end

-- Defaults
setTimerFromElapsed(0)
killText.Text = "0"
coinText.Text = "0"
soulsText.Text = "0"

-- Coins + kills come from PlayerProgressEvent
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local progressEvent = remotes:WaitForChild("PlayerProgressEvent")
progressEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.type ~= "progress" then return end
    if payload.kills ~= nil then
        killText.Text = tostring(math.floor(tonumber(payload.kills) or 0))
    end
    if payload.coins ~= nil then
        coinText.Text = tostring(math.floor(tonumber(payload.coins) or 0))
    end
    if payload.souls ~= nil then
        soulsText.Text = tostring(math.floor(tonumber(payload.souls) or 0))
    end
end)


-- Pull initial snapshot (first server push can happen before this UI binds).
local function requestProgressSync()
	progressEvent:FireServer({ type = "requestSync" })
end

task.defer(requestProgressSync)
task.delay(1, requestProgressSync)

-- Time comes from WaveStatusEvent (seconds elapsed on server; respects PauseState)
local function getWaveStatusEvent()
    local rem = ReplicatedStorage:FindFirstChild("Remotes")
    if rem then
        local ev = rem:FindFirstChild("WaveStatusEvent")
        if ev and ev:IsA("RemoteEvent") then
            return ev
        end
    end
    local ev = ReplicatedStorage:FindFirstChild("WaveStatusEvent")
    if ev and ev:IsA("RemoteEvent") then
        return ev
    end
    return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WaveStatusEvent")
end

local waveEvent = getWaveStatusEvent()
waveEvent.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    if payload.type == "timeUpdate" and payload.seconds ~= nil then
        setTimerFromElapsed(payload.seconds)
    end
end)
