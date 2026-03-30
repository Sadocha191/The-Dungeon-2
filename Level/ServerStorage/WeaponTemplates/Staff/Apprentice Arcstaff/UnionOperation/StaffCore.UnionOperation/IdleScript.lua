local part = script.Parent
local tool = part.Parent

local FireLightning = part.FireLightning



while task.wait(.01) do
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude


	local character = tool.Parent
	if character:IsA("Workspace") then
		params.FilterDescendantsInstances = {tool}
	else
		params.FilterDescendantsInstances = {character}
	end

	local RayCast = workspace:Raycast(part.Position, part.LookAt.Value.LookVector*25, params)
	if RayCast then
		FireLightning:Fire(RayCast.Position, RayCast.Instance)
	end
	part.LookAt.Value = part.LookAt.Value * CFrame.Angles(math.rad(math.random(-360, 360)), math.rad(math.random(-360, 360)), math.rad(math.random(-360, 360)))
end
