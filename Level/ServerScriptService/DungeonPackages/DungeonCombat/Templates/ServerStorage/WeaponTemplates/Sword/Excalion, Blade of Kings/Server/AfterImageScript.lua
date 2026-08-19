
local FindFirstChild, WaitForChild, FindFirstChildOfClass = script.FindFirstChild, script.WaitForChild, script.FindFirstChildOfClass

local Instant = Instance.new

local GetChildren = script.GetChildren

local IsA = script.IsA

local Clone, Destroy = script.Clone, script.Destroy

local Creator = WaitForChild(script,"Creator").Value

local ToolRef = WaitForChild(script,"ToolRef").Value

local CreatorHum = WaitForChild(script,"CreatorHum").Value

local ServerScriptService = (game:FindService("ServerScriptService") or game:GetService("ServerScriptService"))

local Players = (game:FindService("Players") or game:GetService("Players"))

local Debris = (game:FindService("Debris") or game:GetService("Debris"))

function IsTeamMate(Player1, Player2)
	return (Player1 and Player2 and not Player1.Neutral and not Player2.Neutral and Player1.TeamColor == Player2.TeamColor)
end

function TagHumanoid(humanoid, player)
	local Creator_Tag = Instance.new("ObjectValue")
	Creator_Tag.Name = "creator"
	Creator_Tag.Value = player
	Debris:AddItem(Creator_Tag, 2)
	Creator_Tag.Parent = humanoid
end

function UntagHumanoid(humanoid)
	for i, v in pairs(humanoid:GetChildren()) do
		if IsA(v,"ObjectValue") and v.Name == "creator" then
			Destroy(v)
		end
	end
end

function Attack(hit,Damage)
	if not hit or not hit.Parent then return end
	local Hum,FF = FindFirstChildOfClass(hit.Parent,"Humanoid"),FindFirstChildOfClass(hit.Parent,"ForceField")
	if not Hum or Hum.Health <= 0 or FF or Hum == CreatorHum or IsTeamMate(Creator,Players:GetPlayerFromCharacter(Hum.Parent)) then return end
	local function Decimated(Character) -- Quick check to see if they're not decimated
		for _,v in pairs(GetChildren(ServerScriptService)) do
			if IsA(v,"Script") and v.Name == "Decimate" and FindFirstChild(v,"Character") and FindFirstChild(v,"Character").Value == Hum.Parent then
				return true
			end
		end
		return false
	end
	
	if (Hum.Health/Hum.MaxHealth)*100 <= 30 then
		--Take their soul already
		if Decimated(Hum.Parent) then return end
		local DecimateScript = Clone(WaitForChild(script,"Decimate"))
		local ToolObj = Instant("ObjectValue")
			ToolObj.Name = "Tool"
			ToolObj.Value = ToolRef
			ToolObj.Parent = DecimateScript
		
		local Creator = Instant("ObjectValue")
			Creator.Name = "Creator"
			Creator.Value = Creator
			Creator.Parent = DecimateScript
		
		local Character = Instant("ObjectValue")
			Character.Name = "Character"
			Character.Value = Hum.Parent
			Character.Parent = DecimateScript
			
		local SoulCount = Instant("ObjectValue")
			SoulCount.Name = "SoulCount"
			SoulCount.Value = WaitForChild(ToolRef,"SoulCount")
			SoulCount.Parent = DecimateScript
		
		DecimateScript.Parent = ServerScriptService
		DecimateScript.Disabled = false
	else
		UntagHumanoid(Hum)
		TagHumanoid(Hum,Creator)
		Hum:TakeDamage(Damage or 0)
	end
	
	if not FindFirstChild(Hum.Parent,"SlowScript") then
		local Slow = Clone(WaitForChild(script,"SlowScript"))
		Slow.Parent = Hum.Parent
		Slow.Disabled = false
	end
end

script.Parent.Touched:Connect(function(hit)
	Attack(hit,5)
end)