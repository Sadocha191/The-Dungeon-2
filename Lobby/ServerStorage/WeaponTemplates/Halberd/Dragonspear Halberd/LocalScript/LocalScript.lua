Tool = script.Parent
local replicatedstorage = game:GetService("ReplicatedStorage")
local arrowevent = replicatedstorage.Arrow
local cd = false

Tool.Activated:Connect(function()
	if cd == true then return end
	cd = true
	local plr = game.Players.LocalPlayer
	local char = plr.Character
	local hum = char.Humanoid
	wait(0.5)	
	if plr.Data.Stand.Value > 1 then return end	
	local anim = hum:LoadAnimation(script.Parent.Handle.Use)
	anim:Play()
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	wait(0.55)
	Tool.Handle.Swing:Play()
	wait(0.3)
	Tool.Handle.Stab:Play()
	Tool.Handle.StandEnergy:Play()
	wait(1.15)
	arrowevent:FireServer()
end)