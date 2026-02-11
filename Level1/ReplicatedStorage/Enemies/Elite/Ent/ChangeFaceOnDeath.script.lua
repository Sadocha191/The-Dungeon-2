print("Face Change on Death Script loaded")

while true do
	wait(0.1)
	if script.Parent.Humanoid ~= nil then
		if script.Parent.Humanoid.Health ==0 then
			script.Parent.Head.face.Texture = "http://www.roblox.com/asset/?id=15399729"
			wait(0.1)
			script:remove()
		end
	end
end
