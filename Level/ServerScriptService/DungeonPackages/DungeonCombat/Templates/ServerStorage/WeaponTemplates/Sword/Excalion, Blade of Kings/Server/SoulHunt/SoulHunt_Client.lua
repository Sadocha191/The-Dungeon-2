--warn("Soul_Hunt Client Active")

local Clone, Destroy = script.Clone, script.Destroy

local Services = {
	Lighting = (game:FindService("Lighting") or game:GetService("Lighting")),
	Debris = (game:FindService("Debris") or game:GetService("Debris")),
	Tween = (game:FindService("TweenService") or game:GetService("TweenService"))
}

local ScarySky = script:WaitForChild("ScarySky")

local Original_Sky = Services.Lighting:FindFirstChildOfClass("Sky")

if Original_Sky then
	Original_Sky.Parent = nil -- temporarily move the skybox
end

ScarySky.Parent = Services.Lighting

local Original_Time, Original_Ambient, Original_ColorS_Bottom, Original_ColorS_Top  = Services.Lighting.ClockTime, Services.Lighting.Ambient, Services.Lighting.ColorShift_Bottom, Services.Lighting.ColorShift_Top
pcall(function()
	local Purple = Color3.fromRGB(136, 0, 255)
	local Tween = Services.Tween:Create(Services.Lighting,TweenInfo.new(1.5,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,0),{ClockTime = 17.7, Ambient = Purple, ColorShift_Bottom = Purple, ColorShift_Top = Purple}):Play()
	
end)

pcall(function()
	
	script:WaitForChild("Finish",10).Changed:Connect(function()
		if script.Finish.Value then
			
			if Original_Sky then
				Original_Sky.Parent = Services.Lighting -- temporarily move the skybox
			end

			local Tween = Services.Tween:Create(Services.Lighting,TweenInfo.new(1.5,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,0),{ClockTime = Original_Time, Ambient = Original_Ambient, ColorShift_Bottom = Original_ColorS_Bottom, ColorShift_Top = Original_ColorS_Top}):Play()
			Services.Debris:AddItem(ScarySky,.5)
			--Destroy(ScarySky)
			
		end
	end)
	
end)