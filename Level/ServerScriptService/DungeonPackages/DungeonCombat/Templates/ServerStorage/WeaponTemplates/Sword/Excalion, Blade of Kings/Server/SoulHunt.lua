--//The Soul Hunt begins..

--// EVERYBODY TAKE COVER!! (If you can..)

local FindFirstChildOfClass, WaitForChild = script.FindFirstChildOfClass, script.WaitForChild

local Clone, Destroy = script.Clone, script.Destroy

local Services = {
	Players = (game:FindService("Players") or game:GetService("Players")),
	Debris = (game:FindService("Debris") or game:GetService("Debris")),
	RunService = (game:FindService("RunService") or game:GetService("RunService"))
}

local ScriptQueue = {}
function CastToPlayer(player,CurrentScript)
	
	if not player or not CurrentScript then return end
	
	pcall(function()
		local GUI = Instance.new("ScreenGui")
		GUI.ResetOnSpawn = false
		GUI.Name = "SoulHunt_Client"
		GUI.Parent = FindFirstChildOfClass(player,"PlayerGui")
		CurrentScript = Clone(CurrentScript)
		ScriptQueue[#ScriptQueue+1] = CurrentScript
		CurrentScript.Parent = GUI
		CurrentScript.Disabled = false
	end)
	
end

local SoulHunt_Client, SoulHunt_Seeker = WaitForChild(script,"SoulHunt_Client",5), WaitForChild(script,"SoulHunt_Seeker",5)

local RemoteRef = WaitForChild(script,"RemoteRef",5)

local Creator = WaitForChild(script,"Creator",5).Value

local Finish = Instance.new("BoolValue")
Finish.Name = "Finish"
Finish.Value = false
Finish.Parent = SoulHunt_Client

Clone(Finish).Parent = SoulHunt_Seeker

Clone(RemoteRef).Parent = SoulHunt_Seeker

function IsTeamMate(Player1, Player2)
	return (Player1 and Player2 and not Player1.Neutral and not Player2.Neutral and Player1.TeamColor == Player2.TeamColor)
end

local Affected_Humanoids, Events = {}, {}
function Cripple(Character)
	coroutine.wrap(function()
	if not Character  or Character == Creator.Character then return end
	local Hum  = FindFirstChildOfClass(Character,"Humanoid")
	
	if not Hum or Hum.Health <= 0 then return end
	
	Affected_Humanoids[#Affected_Humanoids+1] = Hum
	
	Hum.WalkSpeed = 8
	Events[#Events+1] = Hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if not FindFirstChildOfClass(Character,"ForceField") then
			Hum.WalkSpeed = 8
		end
	end)
	
	Character.ChildRemoved:Connect(function(child)
		if not child or not child:IsA("ForceField") then return end
		
		Hum.WalkSpeed = 8
		
	end)
	
	while Hum and Hum.Health > 0 do
		local delta = Services.RunService.Heartbeat:Wait()
		Hum:TakeDamage((Hum.Health <= (Hum.MaxHealth*.05) and 0) or ((Hum.MaxHealth*.95)/35 * delta))
	end
	end)()
end


Services.Players.PlayerAdded:Connect(function(player)
	CastToPlayer(player, SoulHunt_Client)
	if not IsTeamMate(player,Creator) then
		player.CharacterAdded:Connect(Cripple)
	end
end)

for _,v in pairs(Services.Players:GetPlayers()) do
	CastToPlayer(v, SoulHunt_Client)
	if v and v.Character and not IsTeamMate(v,Creator) then
		Cripple(v.Character)
	end
	v.CharacterAdded:Connect(Cripple)
end

if Creator then --Give the user the soul seek UI system
	CastToPlayer(Creator, SoulHunt_Seeker)
end

local GlobalSound = script:WaitForChild("Gong",5)

GlobalSound.Parent = workspace

GlobalSound:Play()

function Clean()
	--/warn("Ending special")
	for i=1,#Events,1 do
		if Events[i] then
			Events[i]:Disconnect()
		end
	end
	
	for i=1, #ScriptQueue,1 do
		if ScriptQueue[i] then
			pcall(function()
				ScriptQueue[i].Finish.Value = true
			end)
			Services.Debris:AddItem(ScriptQueue[i].Parent,5)
		end
	end
	
	for i=1,#Affected_Humanoids,1 do
		if Affected_Humanoids[i] then
			Affected_Humanoids[i].WalkSpeed = 16
		end
	end
	
	Destroy(script)
end

if Creator and Creator.Character then
	local Humanoid = FindFirstChildOfClass(Creator.Character,"Humanoid")
	
	Humanoid.Died:Connect(Clean)
	
	Creator.CharacterRemoving:Connect(Clean)
	
end

wait(45 + GlobalSound.TimeLength)

Clean()