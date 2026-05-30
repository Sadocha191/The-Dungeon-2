local sp=script.Parent

originalgrip=CFrame.new(.15,-2,0)*CFrame.Angles(0,math.pi/2,0)
currentgrip=originalgrip

enabled=true
taunting=false
local mouseButtonConnection = nil
local mouseKeyConnection = nil

local function disconnectMouseConnections()
	if mouseButtonConnection then
		mouseButtonConnection:Disconnect()
		mouseButtonConnection = nil
	end
	if mouseKeyConnection then
		mouseKeyConnection:Disconnect()
		mouseKeyConnection = nil
	end
end

function waitfor(parent,name)
	while true do
		local child=parent:FindFirstChild(name)
		if child~=nil then
			return child
		end
		task.wait()
	end
end

waitfor(sp,"Handle")

function onButton1Down(mouse)
	if not enabled then
		return
	end
	enabled=false
	mouse.Icon="rbxasset://textures\\GunWaitCursor.png"
	task.wait(.75)
	mouse.Icon="rbxasset://textures\\GunCursor.png"
	enabled=true
end

function swordUp()
	currentgrip=originalgrip
end

function swordOut()
	currentgrip=originalgrip*CFrame.Angles(math.pi/4,.4,0)
end


function onEquippedLocal(mouse)
	local currentlast=lastequipped
	if mouse==nil then
		print("Mouse not found")
		return 
	end
	disconnectMouseConnections()
	mouse.Icon="rbxasset://textures\\GunCursor.png"
	mouseButtonConnection = mouse.Button1Down:connect(function()
		onButton1Down(mouse)
	end)
	waitfor(sp,"Taunting")
	waitfor(sp,"Taunt")
	mouseKeyConnection = mouse.KeyDown:connect(function(key)
		key=string.lower(key)
		if key=="l" or key=="t" or key=="g" then	-- :3
			local h=sp.Parent:FindFirstChild("Humanoid")
			if h~=nil then
				sp.Taunting.Value=true
				h.WalkSpeed=0
				tauntanim=h:LoadAnimation(sp.Taunt)
				tauntanim:Play()
				task.wait(1)
				swordOut()
				sp.Grip=currentgrip
				task.wait(1.4)
				swordUp()
				sp.Grip=currentgrip
				task.wait(1)
				h.WalkSpeed=16
				sp.Taunting.Value=false
			end
		end
	end)
end
sp.Equipped:connect(onEquippedLocal)
sp.Unequipped:connect(disconnectMouseConnections)

waitfor(sp,"RunAnim")
sp.RunAnim.Changed:connect(function()
	local h=sp.Parent:FindFirstChild("Humanoid")
	local t=sp.Parent:FindFirstChild("Torso")
	local anim=sp:FindFirstChild(sp.RunAnim.Value)
	if anim and t and h then
		theanim=h:LoadAnimation(anim)
		if theanim and h.Health>0 then
			theanim:Play()
			if sp.RunAnim.Value=="RightSlash" or sp.RunAnim.Value=="LeftSlash" or sp.RunAnim.Value=="OverHeadSwing" then
				spinsword(.5)
			end
			if sp.RunAnim.Value=="OverHeadSwing" then
				task.wait(.25)
				swordOut()
				task.wait(.5)
				swordUp()
				sp.Grip=currentgrip
			elseif sp.RunAnim.Value=="OverHeadSwingFast" then
				task.wait(.125)
				swordOut()
				task.wait(.25)
				swordUp()
				sp.Grip=currentgrip
			end
		end
	end
end)
