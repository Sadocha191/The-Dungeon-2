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
    '''\tlocal nextPos = npc.position + baseMove + impulseMove
\tnextPos = NpcMovementSystemController.ConstrainPosition(npc, nextPos, now)''',
    '''\tlocal nextPos = npc.position + baseMove + impulseMove
\tnextPos = NpcMovementSystemController.ConstrainPosition(npc, nextPos, now, impulseMove)''',
    'flight constraint parity',
)
service_path.write_text(service, encoding='utf-8')

client_path = Path('Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua')
client = client_path.read_text(encoding='utf-8')
client = replace_once(
    client,
    '''\t\tentry.renderPos = entry.renderPos and entry.renderPos:Lerp(goalPos, math.clamp(dt * 12, 0, 1)) or goalPos
\t\tentry.renderSurfaceNormal = surfaceUp(
\t\t\tentry.renderSurfaceNormal and entry.renderSurfaceNormal:Lerp(entry.surfaceNormal, math.clamp(dt * 12, 0, 1))
\t\t\t\tor entry.surfaceNormal
\t\t)
\t\tentry.renderDir = entry.renderDir and entry.renderDir:Lerp(goalDir, math.clamp(dt * 14, 0, 1)) or goalDir''',
    '''\t\tentry.renderPos = entry.renderPos and entry.renderPos:Lerp(goalPos, math.clamp(dt * 12, 0, 1)) or goalPos
\t\tif entry.movementMode == "Surface" then
\t\t\tentry.renderSurfaceNormal = surfaceUp(
\t\t\t\tentry.renderSurfaceNormal and entry.renderSurfaceNormal:Lerp(entry.surfaceNormal, math.clamp(dt * 12, 0, 1))
\t\t\t\t\tor entry.surfaceNormal
\t\t\t)
\t\tend
\t\tentry.renderDir = entry.renderDir and entry.renderDir:Lerp(goalDir, math.clamp(dt * 14, 0, 1)) or goalDir''',
    'surface-only client interpolation',
)
client_path.write_text(client, encoding='utf-8')
