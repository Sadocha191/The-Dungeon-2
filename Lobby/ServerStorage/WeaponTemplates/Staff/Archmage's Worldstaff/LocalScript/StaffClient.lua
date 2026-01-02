--majority of code by TakeoHonorable
local Tool = script.Parent

local Remote = Tool:WaitForChild("Remote",10)

local MouseInput = Tool:WaitForChild("MouseInput",10)

local Services = {
	Players = (game:FindService("Players") or game:GetService("Players")),
	TweenService = (game:FindService("TweenService") or game:GetService("TweenService")),
	RunService = (game:FindService("RunService") or game:GetService("RunService")),
	Input = (game:FindService("ContextActionService") or game:GetService("ContextActionService"))
}

local Player,Character,Humanoid

function StaffPrimary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.Q)
	end
end

function StaffSecondary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.E)
	end
end

function StaffTertiary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.X)
	end
end

function Equipped()
	Player = Services.Players.LocalPlayer
	Character = Player.Character
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or not Humanoid.Parent or Humanoid.Health <= 0 then return end

	Services.Input:BindAction("StaffPrimary",StaffPrimary,true,Enum.KeyCode.Q,Enum.KeyCode.ButtonX)
	--Services.Input:BindAction("StaffSecondary",StaffSecondary,true,Enum.KeyCode.E,Enum.KeyCode.ButtonY)
	--Services.Input:BindAction("StaffTertiary",StaffTertiary,true,Enum.KeyCode.X,Enum.KeyCode.ButtonL1)
	Services.Input:SetTitle("StaffPrimary","Meteor Storm")
	--Services.Input:SetTitle("StaffSecondary","none")
	--Services.Input:SetTitle("StaffTertiary","none")
	Services.Input:SetPosition("StaffPrimary",UDim2.new(.5,0,-.5,0))
	--Services.Input:SetPosition("StaffSecondary",UDim2.new(.5,0,-.25,0))
	--Services.Input:SetPosition("StaffTertiary",UDim2.new(.5,0,0,0))
end

function Unequipped()
	Services.Input:UnbindAction("StaffPrimary")
	--Services.Input:UnbindAction("StaffSecondary")	
	--Services.Input:UnbindAction("StaffTertiary")		
end

Tool.Equipped:Connect(Equipped)
Tool.Unequipped:Connect(Unequipped)


function MouseInput.OnClientInvoke()
	return game.Players.LocalPlayer:GetMouse().Hit.p
end