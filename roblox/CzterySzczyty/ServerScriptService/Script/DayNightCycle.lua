-- ServerScriptService/DayNightCycle.server.lua

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- USTAWIENIA
local START_TIME = 6

local BASE_FULL_DAY_LENGTH = 20 * 60 -- na początku pełny cykl trwa 20 minut
local MIN_FULL_DAY_LENGTH = 20 * 60 -- maksymalnie przyspieszy do 5 minut na cykl

local ACCELERATION_PER_MINUTE = 0
-- 0.08 = co minutę czas przyspiesza o 8%

local currentTime = START_TIME
local elapsedRealTime = 0

Lighting.ClockTime = START_TIME
Lighting.Brightness = 2
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.4
Lighting.GlobalShadows = true

local function updateLighting(clockTime)
	if clockTime >= 6 and clockTime < 18 then
		-- DZIEŃ
		Lighting.Brightness = 2
		Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120)
		Lighting.Ambient = Color3.fromRGB(90, 90, 90)
		Lighting.FogColor = Color3.fromRGB(180, 180, 170)
		Lighting.FogStart = 80
		Lighting.FogEnd = 700

	elseif clockTime >= 18 and clockTime < 20 then
		-- ZACHÓD
		Lighting.Brightness = 1.4
		Lighting.OutdoorAmbient = Color3.fromRGB(95, 70, 70)
		Lighting.Ambient = Color3.fromRGB(70, 55, 60)
		Lighting.FogColor = Color3.fromRGB(120, 80, 80)
		Lighting.FogStart = 60
		Lighting.FogEnd = 500

	elseif clockTime >= 20 or clockTime < 5 then
		-- NOC
		Lighting.Brightness = 0.45
		Lighting.OutdoorAmbient = Color3.fromRGB(35, 40, 65)
		Lighting.Ambient = Color3.fromRGB(25, 30, 50)
		Lighting.FogColor = Color3.fromRGB(25, 30, 45)
		Lighting.FogStart = 40
		Lighting.FogEnd = 350

	else
		-- ŚWIT
		Lighting.Brightness = 1.2
		Lighting.OutdoorAmbient = Color3.fromRGB(90, 85, 95)
		Lighting.Ambient = Color3.fromRGB(70, 65, 80)
		Lighting.FogColor = Color3.fromRGB(130, 120, 140)
		Lighting.FogStart = 60
		Lighting.FogEnd = 500
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	elapsedRealTime += deltaTime

	local elapsedMinutes = elapsedRealTime / 60
	local accelerationMultiplier = 1 + (elapsedMinutes * ACCELERATION_PER_MINUTE)

	local currentFullDayLength = BASE_FULL_DAY_LENGTH / accelerationMultiplier
	currentFullDayLength = math.max(currentFullDayLength, MIN_FULL_DAY_LENGTH)

	local timeSpeed = 24 / currentFullDayLength

	currentTime += deltaTime * timeSpeed

	if currentTime >= 24 then
		currentTime -= 24
	end

	Lighting.ClockTime = currentTime
	updateLighting(currentTime)
end)