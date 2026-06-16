local Tool = script.Parent

local Remote = Tool:WaitForChild("Remote",10)

local Events = {}

local MouseInput = Tool:WaitForChild("MouseLoc",10)

local Services = {
	Players = (game:FindService("Players") or game:GetService("Players")),
	TweenService = (game:FindService("TweenService") or game:GetService("TweenService")),
	RunService = (game:FindService("RunService") or game:GetService("RunService")),
	Input = (game:FindService("ContextActionService") or game:GetService("ContextActionService"))
}

local Player = Services.Players.LocalPlayer

local Character,Humanoid


function CresPrimary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.E)
	end
end

function CresSecondary(actionName, inputState, inputObj)
	if inputState == Enum.UserInputState.Begin then 
		Remote:FireServer(Enum.KeyCode.X)
	end
end


function Equipped()
	Player = Services.Players.LocalPlayer
	Character = Player.Character
	Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or not Humanoid.Parent or Humanoid.Health <= 0 then return end
	
	Events[#Events+1] = Humanoid.Died:Connect(Unequipped)
	
	Services.Input:BindAction("CresPrimary",CresPrimary,true,Enum.KeyCode.E,Enum.KeyCode.ButtonX)
	Services.Input:BindAction("CresSecondary",CresSecondary,true,Enum.KeyCode.X,Enum.KeyCode.ButtonY)
	Services.Input:SetTitle("CresPrimary","Soul Reap")
	Services.Input:SetTitle("CresSecondary","Soul Hunt")
	Services.Input:SetPosition("CresPrimary",UDim2.new(.5,0,-.5,0))
	Services.Input:SetPosition("CresSecondary",UDim2.new(.5,0,0,0))
end

function Unequipped()
	Services.Input:UnbindAction("CresPrimary")
	Services.Input:UnbindAction("CresSecondary")
	for i=1,#Events,1 do
		if Events[i] then
			Events[i]:Disconnect()
		end
	end		
end

Tool.Equipped:Connect(Equipped)
Tool.Unequipped:Connect(Unequipped)
Player.CharacterRemoving:Connect(Unequipped)--Should help with the issues of input blocking

function MouseInput.OnClientInvoke()
	return game.Players.LocalPlayer:GetMouse().Hit.p
end