--// Only the user of the ability will be able to use this

local Remote = script:WaitForChild("RemoteRef",5).Value

--print("Soul Seeker UI Activated")

local Services = {
	Lighting = (game:FindService("Lighting") or game:GetService("Lighting")),
	Debris = (game:FindService("Debris") or game:GetService("Debris")),
	Players = (game:FindService("Players") or game:GetService("Players")),
	RunService = (game:FindService("RunService") or game:GetService("RunService"))
	--Tween = (game:FindService("TweenService") or game:GetService("TweenService"))
}

local Player = Services.Players.LocalPlayer

local Character = Player.Character

local Center = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")

local Seek_UIs, Events = {}, {}

local Soul_UI = script:WaitForChild("SoulUI")

Soul_UI.Parent = nil

local IsA, IsDescendantOf, Clone, Destroy = script.IsA, script.IsDescendantOf, script.Clone, script.Destroy
local function IsAttached(Character)
	for i=1,# Seek_UIs,1 do 
		if Seek_UIs[i] and IsA(Seek_UIs[i],"BillboardGui") and Seek_UIs[i].Adornee and IsDescendantOf(Seek_UIs[i].Adornee,Character) then
			return true
		end
	end
	return false
end

function AttachSeek(Character)
	if not Character or Player.Character == Character or IsAttached(Character) then return end
	Services.RunService.Heartbeat:Wait()
	--print("Attaching UI to " .. Character.Name)
	
	local UI = Clone(Soul_UI)
	
	Seek_UIs[#Seek_UIs+1] = UI
	
	UI.TargetName.Text = Character.Name
	UI.Adornee = Character:FindFirstChild("HumanoidRootPart") or Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
	UI.Parent = script
	UI.Enabled = true
	
	local Connections = {}
	
	local function CleanConnections()
		for i=1,#Connections,1 do
			if Connections[i] and Connections[i].Connected then
				Connections[i]:Disconnect()
			end
		end
		for i=1, #Seek_UIs,1 do
			if Seek_UIs[i] == UI then
				Destroy(Seek_UIs[i])
				table.remove(Seek_UIs,i)
			end
		end
		Destroy(UI)
	end
	
	local Event
	
	Event = Services.RunService.Heartbeat:Connect(function()
		--print("Updating " .. UI.Adornee.Parent.Name .. "'s Position")
		if not UI.Adornee then return CleanConnections() end
		UI.Distance.Text = math.floor((UI.Adornee.Position-Center.Position).Magnitude) .." studs"
	end)
	Connections[#Connections+1] = Event
	Events[#Events+1] = Event
	
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid and Humanoid.Health ~= 0 then
		Event = Humanoid.Died:Connect(CleanConnections)
		Connections[#Connections+1] = Event
		Events[#Events+1] = Event
	end
	
	local player = Services.Players:GetPlayerFromCharacter(Character)
	
	if player then
		Event = player.CharacterRemoving:Connect(CleanConnections)
		Connections[#Connections+1] = Events
		Events[#Events+1] = Event
	end
	
	Event = UI.SoulButton.MouseButton1Click:Connect(function()
		--print("Attempting to send soul after" .. UI.Adornee.Name)
		Remote:FireServer(UI.Adornee)
	end)
	
	Connections[#Connections+1] = Event
	Events[#Events+1] = Event
	
end

for _,v in pairs(Services.Players:GetPlayers()) do
	coroutine.wrap(function()
		local character = v.Character or v.CharacterAdded:Wait()
		AttachSeek(character)
	end)()
	v.CharacterAdded:Connect(AttachSeek)
end

Services.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(AttachSeek)
end)

pcall(function()
	
	script.Finish.Changed:Connect(function()
		if script.Finish.Value then

			--warn("Soul Seeker UI Disabled")
			
			for i=1, #Events,1 do
				if Events[i] then
					Events[i]:Disconnect()
				end
			end
			
			for i=1,#Seek_UIs,1 do
				if Seek_UIs[i] then
					Destroy(Seek_UIs[i])
				end
			end
			
		end
	end)
	
end)