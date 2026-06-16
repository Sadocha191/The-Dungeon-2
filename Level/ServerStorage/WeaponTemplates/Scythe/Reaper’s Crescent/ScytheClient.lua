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

function ScythePrimary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.Q)
	end
end

function ScytheSecondary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.E)
	end
end

function ScytheTertiary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.X)
	end
end

function ScytheQuadruary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.Z)
	end
end

function Equipped()
	Player = Services.Players.LocalPlayer
	Character = Player.Character
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or not Humanoid.Parent or Humanoid.Health <= 0 then return end

	Services.Input:BindAction("ScythePrimary",ScythePrimary,true,Enum.KeyCode.Q,Enum.KeyCode.ButtonX)
	Services.Input:BindAction("ScytheSecondary",ScytheSecondary,true,Enum.KeyCode.E,Enum.KeyCode.ButtonY)
	Services.Input:BindAction("ScytheTertiary",ScytheTertiary,true,Enum.KeyCode.X,Enum.KeyCode.ButtonL1)
	Services.Input:BindAction("ScytheQuadruary",ScytheQuadruary,true,Enum.KeyCode.Z,Enum.KeyCode.ButtonR1)
	Services.Input:SetTitle("ScythePrimary","Black Hole")
	Services.Input:SetTitle("ScytheSecondary","Scythe Bomb")
	Services.Input:SetTitle("ScytheTertiary","Ghost Hunt")
	Services.Input:SetTitle("ScytheQuadruary","Gravity Shield")
	Services.Input:SetPosition("ScythePrimary",UDim2.new(.5,0,-.5,0))
	Services.Input:SetPosition("ScytheSecondary",UDim2.new(.5,0,-.25,0))
	Services.Input:SetPosition("ScytheTertiary",UDim2.new(.25,0,0.5,0))
	Services.Input:SetPosition("ScytheQuadruary",UDim2.new(.25,0,0.25,0))
end

function Unequipped()
	Services.Input:UnbindAction("ScythePrimary")
	Services.Input:UnbindAction("ScytheSecondary")	
	Services.Input:UnbindAction("ScytheTertiary")
	Services.Input:UnbindAction("ScytheQuadruary")		
end

Tool.Equipped:Connect(Equipped)
Tool.Unequipped:Connect(Unequipped)


function MouseInput.OnClientInvoke()
	return game.Players.LocalPlayer:GetMouse().Hit.p
end