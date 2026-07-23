from pathlib import Path

path = Path('Level/ServerScriptService/ModuleScript/NpcService.lua')
text = path.read_text(encoding='utf-8')
old = '''\tlocal targetInfo = NpcTargeting.FindNearestTarget(npc, alivePlayers, now)
\tif not targetInfo then
\t\tnpc.velocity = Vector3.zero
\t\tsetState(npc, STATE.Idle)
\t\twriteStateAttributes(npc)
\t\treturn
\tend

\tif NpcCombatBehaviorService.Step(npc, targetInfo, dt, now, {
\t\tkill = function(context)
\t\t\tkillNpc(npc, context)
\t\tend,
\t}) then
\t\tif not npc.dead then
\t\t\twriteStateAttributes(npc)
\t\tend
\t\treturn
\tend
'''
new = '''\tlocal targetInfo = NpcTargeting.FindNearestTarget(npc, alivePlayers, now)
\tif NpcCombatBehaviorService.Step(npc, targetInfo, dt, now, {
\t\tkill = function(context)
\t\t\tkillNpc(npc, context)
\t\tend,
\t}) then
\t\tif not npc.dead then
\t\t\twriteStateAttributes(npc)
\t\tend
\t\treturn
\tend

\tif not targetInfo then
\t\tnpc.velocity = Vector3.zero
\t\tsetState(npc, STATE.Idle)
\t\twriteStateAttributes(npc)
\t\treturn
\tend
'''
count = text.count(old)
if count != 1:
    raise RuntimeError(f'expected one target/combat block, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
