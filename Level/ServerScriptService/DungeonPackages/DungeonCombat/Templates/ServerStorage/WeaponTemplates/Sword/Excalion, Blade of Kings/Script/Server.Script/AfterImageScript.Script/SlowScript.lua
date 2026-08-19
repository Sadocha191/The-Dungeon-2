local vCharacter = script.Parent
local myHumanoid = vCharacter:FindFirstChildOfClass("Humanoid")

if myHumanoid and myHumanoid.Health > 0 then
	myHumanoid.WalkSpeed = 9.0
	task.wait(2.5)
	myHumanoid.WalkSpeed = 16.0
end

task.wait(2.0)
if script then
	script:Destroy()
end
