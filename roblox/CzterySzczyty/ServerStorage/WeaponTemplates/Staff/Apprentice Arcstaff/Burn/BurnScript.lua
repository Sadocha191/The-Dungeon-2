local model = script.Parent.Parent
local humanoid = model:FindFirstChildOfClass("Humanoid")

if not humanoid then
	print("has no humanoid")
    script:Destroy()
end

while task.wait(.1) do
	humanoid:TakeDamage(1)
end