local ServerScriptService = game:GetService("ServerScriptService")

local DamageService = require(ServerScriptService:WaitForChild("ModuleScript"):WaitForChild("DamageService"))

local function normalizeContext(source)
	local context = {
		source = source,
	}

	if typeof(source) == "Instance" then
		context.sourceModel = source
	elseif typeof(source) == "table" then
		context.sourceModel = source.Model or source.model or source.SourceModel or source.sourceModel
	end

	return context
end

_G.ApplyDamageToPlayer = function(player, amount, source)
	return DamageService.Apply(player, amount, normalizeContext(source))
end
