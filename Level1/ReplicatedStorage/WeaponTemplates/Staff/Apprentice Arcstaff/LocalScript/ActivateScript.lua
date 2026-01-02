local tool = script.Parent
local plr = game.Players.LocalPlayer
local mouse = plr:GetMouse()

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Equipped = false

tool.Equipped:Connect(function()
	Equipped = true
end)

tool.Unequipped:Connect(function()
	Equipped = false
end)

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F and Equipped == true then
		tool.SeverTranstition:FireServer("ChangeAbility")
	end
end)

tool.Equipped:Connect(function()
	plr = game.Players.LocalPlayer
	mouse = plr:GetMouse()
end)

tool.Activated:Connect(function()
	tool.SeverTranstition:FireServer("Charge")
end)

tool.Deactivated:Connect(function()
	tool.SeverTranstition:FireServer("ChargeEnd")
	if tool.EnergyLevel.Value > 10 then
		tool:FindFirstChild(tool.Ability.Value):FireServer(mouse.Hit.Position)
	end
end)

tool.Unequipped:Connect(function()
	tool.SeverTranstition:FireServer("ChargeEnd")
end)