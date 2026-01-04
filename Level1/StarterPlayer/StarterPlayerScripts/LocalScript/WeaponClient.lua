-- WeaponClient.client.lua (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local PauseState = ReplicatedStorage:WaitForChild("PauseState")
local WeaponEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponEvent")

local mouse = plr:GetMouse()
local activeTool: Tool? = nil
local activeConn: RBXScriptConnection? = nil

local function getEquippedTool()
	local char = plr.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Tool")
end

local function fireWeapon(tool: Tool)
	if PauseState.Value then return end

	local wType = tool:GetAttribute("WeaponType")
	if typeof(wType) ~= "string" then return end

	if wType == "Melee" or wType == "Sword" or wType == "Scythe" or wType == "Halberd" or wType == "Claymore" or wType == "Greataxe" then
		WeaponEvent:FireServer({ action = "MELEE" })
	elseif wType == "Bow" or wType == "Wand" or wType == "Staff" or wType == "Pistol" then
		local hitPos = mouse.Hit and mouse.Hit.Position
		if typeof(hitPos) ~= "Vector3" then return end
		WeaponEvent:FireServer({ action = "SHOOT", aim = hitPos })
	end
end

local function bindTool(tool: Tool?)
	if activeConn then
		activeConn:Disconnect()
		activeConn = nil
	end
	activeTool = tool
	if not activeTool then return end
	activeConn = activeTool.Activated:Connect(function()
		fireWeapon(activeTool)
	end)
end

local function onCharacterAdded(char: Model)
	bindTool(char:FindFirstChildOfClass("Tool"))
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
	char.ChildRemoved:Connect(function(child)
		if child == activeTool then
			bindTool(char:FindFirstChildOfClass("Tool"))
		end
	end)
end

if plr.Character then
	onCharacterAdded(plr.Character)
end
plr.CharacterAdded:Connect(onCharacterAdded)
