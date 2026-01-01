local tweenservice = game:GetService("TweenService")
local runservice = game:GetService("RunService")
local players = game:GetService("Players")
local uis = game:GetService("UserInputService")
local guiser = game:GetService("GuiService")
local horizon = Vector3.new(1,0,1)
local tool = script.Parent
local camera = workspace.CurrentCamera
local owner
local character
local charroot
local chartorso
local charhum
local charhead
local renderfunc
local steppedfunc
local animroot
local animrootweld
--
local remote = tool:WaitForChild("gunremote")
local gunmodel = tool:WaitForChild("model")
local handle = gunmodel:WaitForChild("Handle")
local gui = tool:WaitForChild("judgegui")
local handlegui = handle:WaitForChild("handlegui")
local handleframe = handlegui:WaitForChild("Frame")
local amountbox = handleframe:WaitForChild("ammoamount")
local ammotypebox = handleframe:WaitForChild("ammotype")
local bars = gui:WaitForChild("bars")
local cross = gui:WaitForChild("crosshair")
local crit = cross:WaitForChild("crit")
--viewmodel
local modelk = 0.1
local modelfriction = 0.3
local modelvelX, modelvelY = 0,0
local modeldestinationX, modeldestinationY = 0,0
local camX, camY = 0,0
--recoil
local reck = 0.05
local recfriction = 0.15
local recvelX, recvelY, recvelZ = 0,0,0
local recdestX, recdestY, recdestZ = 0,0,0
--
local maxlookdown = -1.25
--
local camfov = 70
local equiptick = tick()
local tfind = table.find
local sin = math.sin
local cos = math.cos
local lastcamcf = camera.CFrame
local startguioffset = handlegui.StudsOffset
local startcamfov = camfov
local aiming = false
--
local guirot = 0
local hitmarkerSoundID = "rbxassetid://6735107335"
local hitmarkerVolume = 2
local hitmarkerPlaybackSpeed = 1
local hitmarkerTimePosition = 0.1
--
local trackmouseY = true
local trackmouselook = true
local holdinglmb = false
--
local currentwelds = {} --dont repeat names
local bartable = {}
local moveoncooldown = {}
local myhats = {}
local animcf = CFrame.new()
local recoilcf = CFrame.new()
local offsetcframes = {
	aimcf = CFrame.new(),
	hipcf = CFrame.new(0.7,-0.6,-0.2) * CFrame.Angles(0,0.03,0)
}
local horriblestates = {Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Flying}
local transparencylimbs = {
	["Head"] = 1,
	["Torso"] = 1,
	["Left Arm"] = 0,
	["Right Arm"] = 0,
	["Left Leg"] = 1,
	["Right Leg"] = 1,
}

local linearlerp = function(a,b,t)
	return a+(b-a)*t
end

local getvel = function(difference, vel, k, friction)
	local offset = (difference*k)
	local vel = (vel * (1 - friction)) + offset
	return vel
end

local tween = function(speed, easingstyle, easingdirection, loopcount, WHAT, goal)
	local info = TweenInfo.new(
		speed,
		easingstyle,
		easingdirection,
		loopcount
	)
	local goals = goal
	local anim = tweenservice:Create(WHAT, info, goals)
	anim:Play()
end

local ws = function()
	return charhum.WalkSpeed/16
end

for i,v in pairs(bars:GetChildren()) do
	bartable[string.gsub(v.Name, "bars", "")] = {
		["shadow"] = v.behindbar,
		["load"] = v.behindbar.loadbar,
		["usetick"] = tick()
	}
	v.behindbar.loadbar.Rotation = 180
	v.behindbar.Visible = false
	v.behindbar.loadbar.Visible = true
end

local mousepos = function(distance, ignore)
	local mpos = uis:GetMouseLocation() - guiser:GetGuiInset()
	local scrpoint = camera:ScreenPointToRay(mpos.X, mpos.Y)
	local filter = RaycastParams.new()
	filter.FilterDescendantsInstances = ignore
	filter.FilterType = Enum.RaycastFilterType.Blacklist
	local ray = workspace:Raycast(scrpoint.Origin, scrpoint.Direction*distance, filter)
	local finishpos = scrpoint.Origin + (scrpoint.Direction*distance)
	if ray then
		finishpos = ray.Position
	end
	return CFrame.new(finishpos)
end

local cooldownbehavior = {
	["reload"] = function()
		if not aiming then
			offsetcframes.hipcf = CFrame.new(0,-0.6,-0.2)
		else
			offsetcframes.hipcf = CFrame.new(1,-0.6,-0.2)
		end
	end,
	["ENDreload"] = function()
		offsetcframes.hipcf = CFrame.new(0.7,-0.6,-0.2) * CFrame.Angles(0,0.03,0)
	end,
}

local remotebehavior = {
	["showdata"] = function(amount, name)
		amountbox.Text = amount or amountbox.Text
		ammotypebox.Text = name or ammotypebox.Text
	end,
	["showcross"] = function(speed, color, customvolume)
		local ht = Instance.new("Sound", gui)
		ht.SoundId = hitmarkerSoundID
		ht.Volume = customvolume or hitmarkerVolume
		ht.PlaybackSpeed = hitmarkerPlaybackSpeed
		ht.TimePosition = hitmarkerTimePosition
		ht:Play()
		crit.ImageColor3 = color
		crit.Visible = true
		crit.ImageTransparency = 0
		tween(speed, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, crit, {ImageTransparency = 1})
		game:GetService("Debris"):AddItem(ht, 6)
	end,
	["isholding"] = function()
		if holdinglmb then
			remote:FireServer("lmb", mousepos(200, {character}))
		end
	end,
	["stopbar"] = function(name)
		if bartable[name] then
			bartable[name].usetick = tick()
			bartable[name].shadow.Visible = false
			if tfind(moveoncooldown, name) then
				table.remove(moveoncooldown, tfind(moveoncooldown, name))
			end
		else
			print(name,"bar was not found")
		end
	end,
	["bar"] = function(name, duration, fill)
		if bartable[name] then
			bartable[name].usetick = tick()
			local backuptick = bartable[name].usetick
			bartable[name].shadow.Visible = true
			local endsiz = UDim2.new(1,0,1,0)
			local startsiz = UDim2.new(1,0,0,0)
			if not fill then
				startsiz = UDim2.new(1,0,1,0)
				endsiz = UDim2.new(1,0,0,0)
			end
			if not tfind(moveoncooldown, name) then
				table.insert(moveoncooldown, name)
			end
			if cooldownbehavior[name] then
				cooldownbehavior[name]()
			end
			bartable[name].load.Size = startsiz
			bartable[name].load:TweenSize(endsiz, Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, duration, true)
			task.spawn(function()
				task.wait(duration)
				if backuptick == bartable[name].usetick then
					bartable[name].shadow.Visible = false
					table.remove(moveoncooldown, tfind(moveoncooldown, name))
					if cooldownbehavior["END"..name] then
						cooldownbehavior["END"..name]()
					end
				end
			end)
		else
			print(name, "bar not found")
		end
	end,
	["recoilsupaaction"] = function(rec)
		recdestZ, recdestX, recdestY = 0,0,0
		if aiming then
			recoilcf = CFrame.new():Lerp(rec, 0.3)
		else
			recoilcf = rec
		end
	end,
}

local keyholder
local lookpart
local wasautorotated
local renderfunc

local inputpressholder
local inputreleaseholder

local keybehavior = {
	["r"] = function()
		remote:FireServer("keypress", "r")
	end,
	["e"] = function()
		remote:FireServer("keypress", "e")
	end,
}

local uispressbehavior = {
	[Enum.UserInputType.Keyboard] = function(input)
		if keybehavior[string.lower(input.KeyCode.Name)] then
			keybehavior[string.lower(input.KeyCode.Name)]()
		end
	end,
	[Enum.UserInputType.MouseButton1] = function()
		holdinglmb = true
		remote:FireServer("lmb", mousepos(200, {character}))
	end,
	[Enum.UserInputType.MouseButton2] = function()
		if (camera.CFrame.Position - (charroot.Position + (charroot.CFrame.UpVector*1.5))).Magnitude < 1.5 and not aiming then
			offsetcframes.aimcf = CFrame.new(-0.79,0.45,0.25) * CFrame.Angles(0,-0.03,-0.15)
			camfov = 30
			uis.MouseDeltaSensitivity = 0.35
			remote:FireServer("aimin")
			aiming = true
		end
	end,
}
local uisreleasebehavior = {
	[Enum.UserInputType.MouseButton1] = function()
		holdinglmb = false
	end,
	[Enum.UserInputType.MouseButton2] = function()
		if aiming then
			offsetcframes.aimcf = CFrame.new()
			uis.MouseDeltaSensitivity = 1
			camfov = 70
			remote:FireServer("notaimin")
			aiming = false
		end
	end,
}

local inputpressfunc = function(input, cored)
	if cored then return end
	if uispressbehavior[input.UserInputType] then
		uispressbehavior[input.UserInputType](input)
	end
end
local inputreleasefunc = function(input)
	if uisreleasebehavior[input.UserInputType] then
		uisreleasebehavior[input.UserInputType](input)
	end
end

tool.Equipped:Connect(function()
	owner = players.LocalPlayer
	character = owner.Character
	charroot = character.HumanoidRootPart
	charhead = character.Head
	chartorso = character.Torso
	startcamfov = camera.FieldOfView
	charhum = character:FindFirstChildOfClass("Humanoid")
	wasautorotated = charhum.AutoRotate
	charhum.AutoRotate = false
	uis.MouseIconEnabled = false
	gui.Parent = owner:FindFirstChildOfClass("PlayerGui")
	handlegui.Enabled = true
	inputpressholder = uis.InputBegan:Connect(inputpressfunc)
	inputreleaseholder = uis.InputEnded:Connect(inputreleasefunc)
	renderfunc = runservice.RenderStepped:Connect(function(delta) --nightmare to read 
		--crosshair
		local absvel = charroot.CFrame:VectorToObjectSpace(charroot.Velocity)
		local absx,absy,absz = math.clamp(absvel.x,-20,20), math.clamp(absvel.y,-50,50), math.clamp(absvel.z,-20,20)
		local absmag = math.clamp(absvel.Magnitude,0,20)
		local aim,_ = mousepos(500, {character})
		local mpos = uis:GetMouseLocation() - guiser:GetGuiInset()
		cross.Position = UDim2.new(0,mpos.X,0,mpos.Y)
		guirot = linearlerp(guirot, absvel.X/15, delta*2)
		cross.Rotation = cross.Rotation + guirot
		if cross.Rotation > 90 or cross.Rotation < -90 then
			cross.Rotation = 0
		end
		--bars
		for i,v in pairs(bartable) do
			local baroffset = tfind(moveoncooldown, i) or 0
			v.shadow.Position = UDim2.new(-0.014-((baroffset-1)/200),mpos.X,0,mpos.Y) --lua starting tables at first index once again
		end	
		--character lookat
		if lookpart then
			local lookatspeed = 15
			local headpos = charroot.Position + (charroot.CFrame.UpVector*1.5)
			if trackmouselook then
				lookpart.CFrame = CFrame.new(headpos - (headpos - aim.p).Unit)
			else
				lookpart.CFrame = CFrame.new((headpos + charroot.CFrame.LookVector*2), headpos)
			end
			if trackmouseY and not charhum.PlatformStand and not tfind(horriblestates, charhum:GetState()) then
				charroot.CFrame = charroot.CFrame:lerp(CFrame.new(charroot.Position, Vector3.new(aim.x,charroot.Position.y,aim.z)), (delta*lookatspeed))
			end
		end
		--fps body
		local unvisiblityvalue = 0
		local camdistance = (camera.CFrame.Position - (charroot.Position + (charroot.CFrame.UpVector*1.5))).Magnitude
		charhum.CameraOffset = Vector3.new()
		camera.FieldOfView = linearlerp(camera.FieldOfView, camfov, delta*3)
		if animroot and camdistance < 1.5 then
			unvisiblityvalue = 1
			handlegui.StudsOffset = startguioffset + Vector3.new(-(1-(camera.FieldOfView/startcamfov))/1.7,-0.05,0)
			charhum.CameraOffset = Vector3.new(0,0.35,0.3)
			charroot.CFrame = CFrame.new(charroot.Position, Vector3.new(aim.x,charroot.Position.y,aim.z)) --snap instantly instead
			local holdcf = CFrame.Angles(0,cos(tick()*ws()*8)*(absmag/140),(-cos(tick()*ws()*8)*(absmag/140))) * CFrame.new(0,(-(absmag/65)+sin(tick()*ws()*16)*(absmag/160))+sin(tick())/35,0)
			for i,v in pairs(offsetcframes) do
				holdcf = holdcf * v
			end
			animcf = animcf:Lerp(holdcf, delta*5)
			--
			local objspace = chartorso.CFrame:ToObjectSpace(camera.CFrame * animcf) --the offset
			local objX,objY,_ = objspace:ToOrientation()
			local rcamX,_,_ = camera.CFrame:ToOrientation()
			local _,hrpY,_ = charroot.CFrame:ToObjectSpace(chartorso.CFrame):ToOrientation()
			animrootweld.C0 = objspace * CFrame.Angles(modelvelX*1.5,(modelvelY/2)+hrpY,-modelvelY/2)
			if rcamX < maxlookdown then
				camera.CFrame = camera.CFrame * CFrame.Angles(maxlookdown+math.abs(rcamX),0,0)
			end
		elseif camdistance >= 1.5 and aiming then
			uisreleasebehavior[Enum.UserInputType.MouseButton2]()
		end
		for i,v in pairs(transparencylimbs) do
			character[i].LocalTransparencyModifier = v*unvisiblityvalue
		end
		for i,v in pairs(myhats) do
			v.LocalTransparencyModifier = unvisiblityvalue
		end
		camera.CFrame = camera.CFrame * CFrame.Angles(0,0,recvelZ)
	end)
	local ogdelta = 0
	steppedfunc = runservice.Stepped:Connect(function(_, delta)
		ogdelta = ogdelta + delta
		if ogdelta < 0.01666 then return end --throttled at roughly 60 fps incase of fps unlocker users
		ogdelta = 0
		camera.CFrame = camera.CFrame * CFrame.Angles(recvelX,recvelY,0):Inverse()
		local camrotX,camrotY,_ = camera.CFrame:ToObjectSpace(lastcamcf):ToOrientation()
		local recoilrotX,_,_ = recoilcf:ToOrientation()
		local _,recoilrotY,recoilrotZ = recoilcf:ToEulerAnglesXYZ()
		--\viewmodel spring\
		camX = (camX + camrotX)
		camY = (camY + camrotY)
		--
		modelvelX = getvel((camX - modeldestinationX), modelvelX, modelk, modelfriction)
		modelvelY = getvel((camY - modeldestinationY), modelvelY, modelk, modelfriction)
		--
		modeldestinationX = (modeldestinationX + modelvelX)
		modeldestinationY = (modeldestinationY + modelvelY)
		--\recoil viewmodel\
		recvelX = getvel((recoilrotX - recdestX), recvelX, reck, recfriction)
		recvelY = getvel((recoilrotY - recdestY), recvelY, reck, recfriction)
		recvelZ = getvel((recoilrotZ - recdestZ), recvelZ, reck, recfriction)
		--
		recdestX = (recdestX + recvelX)
		recdestY = (recdestY + recvelY)
		recdestZ = (recdestZ + recvelZ)
		--
		lastcamcf = camera.CFrame
		camera.CFrame = camera.CFrame * CFrame.Angles(recvelX,recvelY,0)
	end)
	lookpart = character:WaitForChild("aimpartjudge")
	animroot = charhead:WaitForChild("lrp")
	animrootweld = chartorso:WaitForChild("lookrootweld")
	local lpvel = Instance.new("BodyVelocity", lookpart)
	lpvel.MaxForce = Vector3.new(1/0,1/0,1/0)
	lpvel.Velocity = Vector3.new()
	for i,v in pairs(character:GetDescendants()) do
		if v:IsA("BasePart") and v.Name == "Handle" then
			table.insert(myhats, v)
		end
	end
end)
tool.Unequipped:Connect(function()
	gui.Parent = tool
	uis.MouseIconEnabled = true
	charhum.CameraOffset = Vector3.new()
	uis.MouseDeltaSensitivity = 1
	holdinglmb = false
	if aiming then
		uisreleasebehavior[Enum.UserInputType.MouseButton2]()
	end
	camera.FieldOfView = startcamfov
	renderfunc:Disconnect()
	steppedfunc:Disconnect()
	inputpressholder:Disconnect()
	inputreleaseholder:Disconnect()
	charhum.AutoRotate = wasautorotated
	table.clear(myhats)
	if lookpart then
		lookpart:Destroy()
		lookpart = nil
	end
	animroot = nil
	animrootweld = nil
end)
remote.OnClientEvent:Connect(function(WHAT, ...)
	if remotebehavior[WHAT] then
		remotebehavior[WHAT](...)
	end
end)