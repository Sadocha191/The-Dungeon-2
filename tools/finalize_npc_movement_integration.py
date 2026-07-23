from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, found {count}')
    return text.replace(old, new, 1)


service_path = Path('Level/ServerScriptService/ModuleScript/NpcService.lua')
service = service_path.read_text(encoding='utf-8')
service = replace_once(
    service,
    '''\tif pauseState.Value then
\t\tnpc.velocity = Vector3.zero
\t\tnpc.impulse = Vector3.zero
\t\tnpc.attackUntil = 0
\t\tnpc.nextAttackAt = math.max(npc.nextAttackAt, now + 0.1)
\t\tsetState(npc, STATE.Idle)''',
    '''\tif pauseState.Value then
\t\tnpc.velocity = Vector3.zero
\t\tnpc.impulse = Vector3.zero
\t\tnpc.attackUntil = 0
\t\tnpc.nextAttackAt = math.max(npc.nextAttackAt, now + 0.1)
\t\tNpcCombatBehaviorService.Pause(npc, dt)
\t\tsetState(npc, STATE.Idle)''',
    'NpcService pause hook',
)
service_path.write_text(service, encoding='utf-8')

wave_path = Path('Level/ServerScriptService/Script/Model/WaveController.lua')
wave = wave_path.read_text(encoding='utf-8')
wave = replace_once(
    wave,
    '''\tsetOptionalMobAttribute(mob, "MovementProfile", stats.movementProfile)
\tsetOptionalMobAttribute(mob, "MovementMode", stats.movementMode)
\tsetOptionalMobAttribute(mob, "CanFly", stats.canFly)''',
    '''\tsetOptionalMobAttribute(mob, "MovementProfile", stats.movementProfile)
\tsetOptionalMobAttribute(mob, "MovementMode", stats.movementMode)
\tsetOptionalMobAttribute(mob, "MovementSystem", stats.movementSystem)
\tsetOptionalMobAttribute(mob, "MovementBehavior", stats.movementBehavior)
\tsetOptionalMobAttribute(mob, "CombatBehavior", stats.combatBehavior)
\tsetOptionalMobAttribute(mob, "CanFly", stats.canFly)''',
    'WaveController attributes',
)
wave = replace_once(
    wave,
    '''\t\tmovementProfile = stats.movementProfile,
\t\tmovementMode = stats.movementMode,
\t\tcanFly = stats.canFly,''',
    '''\t\tmovementProfile = stats.movementProfile,
\t\tmovementMode = stats.movementMode,
\t\tmovementSystem = stats.movementSystem,
\t\tmovementBehavior = stats.movementBehavior,
\t\tcombatBehavior = stats.combatBehavior,
\t\tcanFly = stats.canFly,''',
    'WaveController registration config',
)
wave = replace_once(
    wave,
    '''\t\tmovementProfile = cfg.movementProfile,
\t\tmovementMode = cfg.movementMode,
\t\tcanFly = cfg.canFly,
\t\tgroundOffset = cfg.groundOffset,''',
    '''\t\tmovementProfile = cfg.movementProfile,
\t\tmovementMode = cfg.movementMode,
\t\tmovementSystem = cfg.movementSystem,
\t\tmovementBehavior = cfg.movementBehavior,
\t\tcombatBehavior = cfg.combatBehavior,
\t\tcanFly = cfg.canFly,
\t\tgroundOffset = cfg.groundOffset,''',
    'WaveController spawn config',
)
wave_path.write_text(wave, encoding='utf-8')

leap_path = Path('Level/ServerScriptService/ModuleScript/LeapExplodeBehavior.lua')
leap = leap_path.read_text(encoding='utf-8')
leap = replace_once(
    leap,
    '''function LeapExplodeBehavior.Cleanup(npc: any)
\tnpc.combatBehaviorState = nil
end''',
    '''function LeapExplodeBehavior.Pause(npc: any, dt: number)
\tlocal state = npc.combatBehaviorState
\tif not state or state.kind ~= "LeapExplode" or state.phase == "Chase" then
\t\treturn
\tend
\tlocal pausedFor = math.max(0, tonumber(dt) or 0)
\tstate.phaseEndsAt += pausedFor
\tstate.leapStartedAt += pausedFor
\tstate.leapEndsAt += pausedFor
end

function LeapExplodeBehavior.Cleanup(npc: any)
\tnpc.combatBehaviorState = nil
end''',
    'LeapExplode pause function',
)
leap_path.write_text(leap, encoding='utf-8')
