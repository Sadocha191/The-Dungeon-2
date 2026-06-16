--Used for the expelled souls that have the ability to decimate non-teamates
--Can possibly snatch the soul of someone caught in the crossfire

local FindFirstChild, FindFirstChildOfClass, WaitForChild = script.FindFirstChild, script.FindFirstChildOfClass, script.WaitForChild

local Soul = script.Parent

local Creator = WaitForChild(script,"Creator")


local Tool, SoulCount = WaitForChild( script,"Tool"), WaitForChild(script,"SoulCount")

local IsA = script.IsA

local Clone, Destroy = script.Clone, script.Destroy

local Services = {
	Players = (game:FindService("Players") or game:GetService("Players")),
	ServerScriptService = (game:FindService("ServerScriptService") or game:GetService("ServerScriptService")),
	RunService = (game:FindService("RunService") or game:GetService("RunService"))
}

function IsTeamMate(Player1, Player2)
	return (Player1 and Player2 and not Player1.Neutral and not Player2.Neutral and Player1.TeamColor == Player2.TeamColor)
end

local Touch

function Decimate(Target)
	if not Target or IsTeamMate(Creator.Value,Services.Players:GetPlayerFromCharacter(Target)) then return end
	local Hum, FF = FindFirstChildOfClass(Target,"Humanoid"), FindFirstChildOfClass(Target,"ForceField")
	if not Hum or Services.Players:GetPlayerFromCharacter(Hum.Parent) == Creator.Value then return end
	
	if FF then Destroy(script) end
	
	local function Decimated(Character) -- Quick check to see if they're not affected
		for _,v in pairs(Services.ServerScriptService:GetChildren()) do
			if IsA(v,"Script") and v.Name == "Decimate" and FindFirstChild(v,"Character") and FindFirstChild(v,"Character").Value == Hum.Parent then
				return true
			end
		end
		return false
	end
	if Decimated(Target) then return end
	if Touch then Touch:Disconnect();Touch = nil end
	local DecimationScript = Clone(WaitForChild(script,"Decimate"))
	Creator.Parent = DecimationScript
	Tool.Parent = DecimationScript
	SoulCount.Parent = DecimationScript
	local CharacterTag = Instance.new("ObjectValue")
	CharacterTag.Name = "Character"
	CharacterTag.Value = Target
	CharacterTag.Parent = DecimationScript
	DecimationScript.Parent = Target
	DecimationScript.Disabled = false
	Destroy(Soul)
end


	coroutine.wrap(function()
		Services.RunService.Heartbeat:Wait()
		
		local Target = FindFirstChild(script,"Target")
		local PropellingForce = FindFirstChildOfClass(Soul,"BodyForce") or FindFirstChildOfClass(Soul,"BodyMover")
		
		if PropellingForce and IsA(PropellingForce,"BodyForce") then
			--Progressively speed up
			--print("Speed up")
			local Speed = 125
			while Soul and not Soul.Anchored and PropellingForce and PropellingForce.Parent and Target and Target.Value do
				local delta = Services.RunService.Heartbeat:Wait()
				Soul.Velocity = (Target.Value.Position-Soul.Position).Unit * Speed
				Speed = Speed + (125/7 * delta)
				--print("Increasing speed")
			end 
		end
	end)()
	--[[PropellingForce.TargetReached:Connect(function()
		Decimate(PropellingForce.Target.Parent)
	end)]]


delay(15,function()
	Destroy(Soul)
end)

Touch = Soul.Touched:Connect(function(hit)
	if hit and hit.Parent then
		Decimate(hit.Parent)
	end
end)