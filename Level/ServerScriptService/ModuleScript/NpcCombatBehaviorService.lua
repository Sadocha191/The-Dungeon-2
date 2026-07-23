local LeapExplodeBehavior = require(script.Parent:WaitForChild("LeapExplodeBehavior"))

local NpcCombatBehaviorService = {}

local BEHAVIORS = {
	LeapExplode = LeapExplodeBehavior,
}

local function resolveBehavior(npc: any): any
	local behaviorName = npc.combatBehavior
	if type(behaviorName) ~= "string" or behaviorName == "" then
		return nil
	end
	return BEHAVIORS[behaviorName]
end

function NpcCombatBehaviorService.Step(
	npc: any,
	targetInfo: any?,
	dt: number,
	now: number,
	callbacks: {[string]: any}?
): boolean
	local behavior = resolveBehavior(npc)
	if not behavior then
		return false
	end
	return behavior.Step(npc, targetInfo, dt, now, callbacks) == true
end

function NpcCombatBehaviorService.Pause(npc: any, dt: number)
	local behavior = resolveBehavior(npc)
	if behavior and type(behavior.Pause) == "function" then
		behavior.Pause(npc, dt)
	end
end

function NpcCombatBehaviorService.Cleanup(npc: any)
	local behavior = resolveBehavior(npc)
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
