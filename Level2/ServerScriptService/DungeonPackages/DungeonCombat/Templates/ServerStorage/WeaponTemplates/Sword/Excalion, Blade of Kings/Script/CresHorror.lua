--//Makes random horrific sounds to compliment the eeriness of Crescendo

local Tool = script.Parent

local Handle = Tool:WaitForChild("Handle")

local soundFolder = script:FindFirstChild("SoundBank")
local SoundBank = (soundFolder and soundFolder:GetChildren()) or {}

local Seed = Random.new()

local FindFirstChildOfClass = script.FindFirstChildOfClass

local Clone, Destroy = script.Clone, script.Destroy

repeat
	task.wait(Seed:NextNumber(10,15))
	if #SoundBank > 0 and FindFirstChildOfClass(Tool.Parent,"Humanoid") then
		local Sound = Clone(SoundBank[Seed:NextInteger(1,#SoundBank)])
		Sound.Parent = Handle
		Sound:Play();Sound.Ended:Wait()
		Destroy(Sound)
	end
until not Tool or not Tool.Parent or not Handle or not Handle.Parent
