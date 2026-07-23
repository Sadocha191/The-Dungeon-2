local LeapExplodeBehavior = require(script.Parent:WaitForChild("LeapExplodeBehavior"))

local NpcCombatBehaviorService = {}

local BEHAVIORS = {
	LeapExplode = LeapExplodeBehavior,
}

function NpcCombatBehaviorService.Step(
	npc: any,
	targetInfo: any,
	dt: number,
	now: number,
	callbacks: {[string]: any}?
): boolean
	local behaviorName = npc.combatBehavior
	if type(behaviorName) ~= "string" or behaviorName == "" then
		return false
	end
	local behavior = BEHAVIORS[behaviorName]
	if not behavior then
		return false
	end
	return behavior.Step(npc, targetInfo, dt, now, callbacks) == true
end

function NpcCombatBehaviorService.Cleanup(npc: any)
	local behavior = BEHAVIORS[npc.combatBehavior]
	if behavior and type(behavior.Cleanup) == "function" then
		behavior.Cleanup(npc)
	else
		npc.combatBehaviorState = nil
	end
end

function NpcCombatBehaviorService.GetMetrics(): {[string]: any}
	local result = {}
	for name, behavior in pairs(BEHAVIORS) do
		if type(behavior.GetMetrics) == "function" then
			result[name] = behavior.GetMetrics()
		end
	end
	return result
end

return NpcCombatBehaviorService
