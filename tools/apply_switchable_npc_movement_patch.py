from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


repo = Path(__file__).resolve().parents[1]
service_path = repo / "Level/ServerScriptService/ModuleScript/NpcService.lua"
client_path = repo / "Level/StarterPlayer/StarterPlayerScripts/LocalScript/NpcPresentation.client.lua"

service = service_path.read_text(encoding="utf-8")

service = replace_once(
    service,
    '''local NpcNavigationConfig = require(serverModuleFolder:WaitForChild("NpcNavigationConfig"))
local NpcGroundNavigation = require(serverModuleFolder:WaitForChild("NpcGroundNavigation"))
local NpcFlightNavigation = require(serverModuleFolder:WaitForChild("NpcFlightNavigation"))
local NpcNavigationDebug = require(serverModuleFolder:WaitForChild("NpcNavigationDebug"))''',
    '''local NpcNavigationConfig = require(serverModuleFolder:WaitForChild("NpcNavigationConfig"))
local NpcGroundNavigation = require(serverModuleFolder:WaitForChild("NpcGroundNavigation"))
local NpcFlightNavigation = require(serverModuleFolder:WaitForChild("NpcFlightNavigation"))
local NpcNavigationDebug = require(serverModuleFolder:WaitForChild("NpcNavigationDebug"))
local NpcMovementSystemController = require(serverModuleFolder:WaitForChild("NpcMovementSystemController"))
local NpcCombatBehaviorService = require(serverModuleFolder:WaitForChild("NpcCombatBehaviorService"))''',
    "NpcService requires",
)

service = replace_once(
    service,
    '''\tmovementProfile: string?,
\tmovementMode: string?,
\tcanFly: boolean?,''',
    '''\tmovementProfile: string?,
\tmovementMode: string?,
\tmovementSystem: string?,
\tmovementBehavior: string?,
\tcombatBehavior: string?,
\tcanFly: boolean?,''',
    "NpcConfig movement fields",
)

service = replace_once(
    service,
    '''\tisRanged: boolean,
\tmovementProfile: string,
\tmovementMode: string,
\tnavigationProfile: {[string]: any},
\tnavigation: {[string]: any}?,''',
    '''\tisRanged: boolean,
\tmovementSystem: string,
\tmovementBehavior: string,
\tcombatBehavior: string?,
\tmovementProfile: string,
\tmovementMode: string,
\tnavigationProfile: {[string]: any},
\tnavigation: {[string]: any}?,
\tsurfaceNormal: Vector3?,
\tcombatBehaviorState: {[string]: any}?,''',
    "NpcRecord movement fields",
)

service = replace_once(
    service,
    '''local function cleanupNavigation(npc: NpcRecord)
\tif npc.movementMode == "Flying" then
\t\tNpcFlightNavigation.Cleanup(npc)
\telse
\t\tNpcGroundNavigation.Cleanup(npc)
\tend
end''',
    '''local function cleanupNavigation(npc: NpcRecord)
\tNpcMovementSystemController.Cleanup(npc)
\tNpcCombatBehaviorService.Cleanup(npc)
end''',
    "cleanupNavigation",
)

service = replace_once(
    service,
    '''\t\t\tnpc.look = safeUnit(npc.movementMode == "Flying" and lookDelta or flat(lookDelta), npc.look)''',
    '''\t\t\tnpc.look = safeUnit(
\t\t\t\tNpcMovementSystemController.Uses3DTargeting(npc) and lookDelta or flat(lookDelta),
\t\t\t\tnpc.look
\t\t\t)''',
    "AI lock look direction",
)

service = replace_once(
    service,
    '''\tlocal targetPos = targetInfo.hrp.Position
\tlocal toTarget3D = targetPos - npc.position
\tlocal toTarget = npc.movementMode == "Flying" and toTarget3D or flat(toTarget3D)''',
    '''\tif NpcCombatBehaviorService.Step(npc, targetInfo, dt, now, {
\t\tkill = function(context)
\t\t\tkillNpc(npc, context)
\t\tend,
\t}) then
\t\tif not npc.dead then
\t\t\twriteStateAttributes(npc)
\t\tend
\t\treturn
\tend

\tlocal targetPos = targetInfo.hrp.Position
\tlocal toTarget3D = targetPos - npc.position
\tlocal uses3DMovement = NpcMovementSystemController.Uses3DTargeting(npc)
\tlocal toTarget = uses3DMovement and toTarget3D or flat(toTarget3D)''',
    "combat behavior hook",
)

service = replace_once(
    service,
    '''\t\tif speed > 0 and (desiredMove.Magnitude > 0.05 or npc.movementMode == "Flying") then
\t\t\tlocal navigationStatus = "Idle"
\t\t\tif npc.movementMode == "Flying" then
\t\t\t\tbaseMove, navigationStatus = NpcFlightNavigation.Step(npc, targetPos, speed, dt, now)
\t\t\telse
\t\t\t\tlocal separation = NpcGroundNavigation.GetSeparation(npc, spatialGrid)
\t\t\t\tbaseMove, navigationStatus = NpcGroundNavigation.Step(
\t\t\t\t\tnpc,
\t\t\t\t\ttargetPos,
\t\t\t\t\tdesiredPos,
\t\t\t\t\tspeed,
\t\t\t\t\tdt,
\t\t\t\t\tnow,
\t\t\t\t\tseparation
\t\t\t\t)
\t\t\tend''',
    '''\t\tif speed > 0 and (desiredMove.Magnitude > 0.05 or uses3DMovement) then
\t\t\tlocal navigationStatus = "Idle"
\t\t\tbaseMove, navigationStatus = NpcMovementSystemController.Step(
\t\t\t\tnpc,
\t\t\t\ttargetPos,
\t\t\t\tdesiredPos,
\t\t\t\tspeed,
\t\t\t\tdt,
\t\t\t\tnow,
\t\t\t\tspatialGrid
\t\t\t)''',
    "movement dispatcher step",
)

service = replace_once(
    service,
    '''\tlocal impulseMove = (npc.movementMode == "Flying" and npc.impulse or flat(npc.impulse)) * dt
\tlocal nextPos = npc.position + baseMove + impulseMove
\tif npc.movementMode == "Flying" then
\t\tif impulseMove.Magnitude > 0.01 then
\t\t\tnextPos = NpcFlightNavigation.ClampPosition(npc, nextPos)
\t\tend
\telse
\t\tnextPos = NpcGroundNavigation.ConstrainPosition(npc, nextPos, now)
\tend''',
    '''\tlocal impulseMove = NpcMovementSystemController.ProjectImpulse(npc, npc.impulse) * dt
\tlocal nextPos = npc.position + baseMove + impulseMove
\tnextPos = NpcMovementSystemController.ConstrainPosition(npc, nextPos, now)''',
    "movement dispatcher constrain",
)

service = replace_once(
    service,
    '''\tlocal movementProfile, navigationProfile = NpcNavigationConfig.Resolve(model, config)
\tlocal movementMode = navigationProfile.Mode
\tsetAttributeIfChanged(model, "MovementProfile", movementProfile)
\tsetAttributeIfChanged(model, "MovementMode", movementMode)
\tsetAttributeIfChanged(model, "CanFly", movementMode == "Flying")''',
    '''\tlocal movementProfile, navigationProfile = NpcNavigationConfig.Resolve(model, config)
\tlocal movementMode = navigationProfile.Mode
\tlocal movementSystem = navigationProfile.MovementSystem or "Legacy"
\tlocal movementBehavior = navigationProfile.MovementBehavior or "GroundWalker"
\tlocal combatBehavior = navigationProfile.CombatBehavior
\tsetAttributeIfChanged(model, "MovementProfile", movementProfile)
\tsetAttributeIfChanged(model, "MovementMode", movementMode)
\tsetAttributeIfChanged(model, "MovementSystem", movementSystem)
\tsetAttributeIfChanged(model, "MovementBehavior", movementBehavior)
\tsetAttributeIfChanged(model, "CombatBehavior", combatBehavior)
\tsetAttributeIfChanged(model, "CanFly", movementMode == "Flying")''',
    "registration movement metadata",
)

service = replace_once(
    service,
    '''\t\tisRanged = config and config.isRanged == true or false,
\t\tmovementProfile = movementProfile,
\t\tmovementMode = movementMode,
\t\tnavigationProfile = navigationProfile,
\t\tnavigation = nil,''',
    '''\t\tisRanged = config and config.isRanged == true or false,
\t\tmovementSystem = movementSystem,
\t\tmovementBehavior = movementBehavior,
\t\tcombatBehavior = combatBehavior,
\t\tmovementProfile = movementProfile,
\t\tmovementMode = movementMode,
\t\tnavigationProfile = navigationProfile,
\t\tnavigation = nil,
\t\tsurfaceNormal = movementMode == "Surface" and Vector3.yAxis or nil,
\t\tcombatBehaviorState = nil,''',
    "NpcRecord registration values",
)

service = replace_once(
    service,
    '''\tsetAttributeIfChanged(model, "MovementProfile", npc.movementProfile)
\tsetAttributeIfChanged(model, "MovementMode", npc.movementMode)
\tsetAttributeIfChanged(model, "CanFly", npc.movementMode == "Flying")''',
    '''\tsetAttributeIfChanged(model, "MovementProfile", npc.movementProfile)
\tsetAttributeIfChanged(model, "MovementMode", npc.movementMode)
\tsetAttributeIfChanged(model, "MovementSystem", npc.movementSystem)
\tsetAttributeIfChanged(model, "MovementBehavior", npc.movementBehavior)
\tsetAttributeIfChanged(model, "CombatBehavior", npc.combatBehavior)
\tsetAttributeIfChanged(model, "CanFly", npc.movementMode == "Flying")''',
    "registered model attributes",
)

service = replace_once(
    service,
    '''\tif npc.movementMode == "Flying" then
\t\tNpcFlightNavigation.Invalidate(npc, "external_set_position")
\telse
\t\tNpcGroundNavigation.Invalidate(npc, "external_set_position")
\tend''',
    '''\tNpcMovementSystemController.Invalidate(npc, "external_set_position")''',
    "SetPosition invalidation",
)

service = replace_once(
    service,
    '''\tlocal ground = NpcGroundNavigation.GetMetrics()
\tlocal flight = NpcFlightNavigation.GetMetrics()
\tlocal combat = NpcMelee.GetMetrics()
\tlocal elapsed = math.max(0.001, os.clock() - navigationStartedAt)
\tlocal castCount = ground.raycastCount
\t\t+ ground.blockcastCount
\t\t+ flight.spherecastCount
\t\t+ flight.groundRaycastCount
\t\t+ combat.lineOfSightRaycasts''',
    '''\tlocal ground = NpcGroundNavigation.GetMetrics()
\tlocal flight = NpcFlightNavigation.GetMetrics()
\tlocal movementSystems = NpcMovementSystemController.GetMetrics()
\tlocal combat = NpcMelee.GetMetrics()
\tlocal combatBehaviors = NpcCombatBehaviorService.GetMetrics()
\tlocal elapsed = math.max(0.001, os.clock() - navigationStartedAt)
\tlocal castCount = ground.raycastCount
\t\t+ ground.blockcastCount
\t\t+ flight.spherecastCount
\t\t+ flight.groundRaycastCount
\t\t+ (movementSystems.surface.raycastCount or 0)
\t\t+ combat.lineOfSightRaycasts''',
    "navigation metrics locals",
)

service = replace_once(
    service,
    '''\t\tground = ground,
\t\tflight = flight,
\t\tcombat = combat,''',
    '''\t\tground = ground,
\t\tflight = flight,
\t\tmovementSystems = movementSystems,
\t\tcombat = combat,
\t\tcombatBehaviors = combatBehaviors,''',
    "navigation metrics result",
)

service = replace_once(
    service,
    '''\tlocal result = npc.movementMode == "Flying"
\t\tand NpcFlightNavigation.GetDebug(npc)
\t\tor NpcGroundNavigation.GetDebug(npc)''',
    '''\tlocal result = NpcMovementSystemController.GetDebug(npc)''',
    "navigation debug resolver",
)

service = replace_once(
    service,
    '''\t\t\tNpcNavigationDebug.Render(NpcRegistry.Pairs, function(npc)
\t\t\t\treturn npc.movementMode == "Flying"
\t\t\t\t\tand NpcFlightNavigation.GetDebug(npc)
\t\t\t\t\tor NpcGroundNavigation.GetDebug(npc)
\t\t\tend, NpcService.GetNavigationMetrics())''',
    '''\t\t\tNpcNavigationDebug.Render(NpcRegistry.Pairs, function(npc)
\t\t\t\treturn NpcMovementSystemController.GetDebug(npc)
\t\t\tend, NpcService.GetNavigationMetrics())''',
    "navigation debug render",
)

service = replace_once(
    service,
    '''\t\tNpcGroundNavigation.BeginTick(cachedAlivePlayers)
\t\tNpcFlightNavigation.BeginTick(cachedAlivePlayers)
\t\tNpcGroundNavigation.StepScheduler(now)
\t\tlocal spatialGrid = NpcGroundNavigation.BuildSpatialGrid(NpcRegistry.Pairs)''',
    '''\t\tNpcMovementSystemController.BeginTick(cachedAlivePlayers)
\t\tNpcMovementSystemController.StepScheduler(now)
\t\tlocal spatialGrid = NpcMovementSystemController.BuildSpatialGrid(NpcRegistry.Pairs)''',
    "movement scheduler begin",
)

service = replace_once(
    service,
    '''\t\tNpcGroundNavigation.StepScheduler(os.clock())''',
    '''\t\tNpcMovementSystemController.StepScheduler(os.clock())''',
    "movement scheduler finish",
)

service_path.write_text(service, encoding="utf-8")

client = client_path.read_text(encoding="utf-8")

client = replace_once(
    client,
    '''local function movementDir(v: Vector3?, movementMode: string?): Vector3
\tif movementMode ~= "Flying" then
\t\treturn flatDir(v)
\tend
\tif typeof(v) ~= "Vector3" or v.Magnitude <= 1e-4 then
\t\treturn Vector3.new(0, 0, -1)
\tend
\treturn v.Unit
end

local function movementSpeed(v: Vector3?, movementMode: string?): number
\tif movementMode == "Flying" and typeof(v) == "Vector3" then
\t\treturn v.Magnitude
\tend
\treturn flatSpeed(v)
end''',
    '''local function surfaceUp(v: Vector3?): Vector3
\tif typeof(v) == "Vector3" and v.Magnitude > 1e-4 then
\t\treturn v.Unit
\tend
\treturn Vector3.yAxis
end

local function movementDir(v: Vector3?, movementMode: string?, surfaceNormal: Vector3?): Vector3
\tif movementMode == "Surface" then
\t\tlocal up = surfaceUp(surfaceNormal)
\t\tlocal source = typeof(v) == "Vector3" and v or Vector3.new(0, 0, -1)
\t\tlocal tangent = source - up * source:Dot(up)
\t\tif tangent.Magnitude <= 1e-4 then
\t\t\tlocal fallback = math.abs(up:Dot(Vector3.zAxis)) < 0.95 and Vector3.zAxis or Vector3.xAxis
\t\t\ttangent = fallback - up * fallback:Dot(up)
\t\tend
\t\treturn tangent.Unit
\tend
\tif movementMode ~= "Flying" then
\t\treturn flatDir(v)
\tend
\tif typeof(v) ~= "Vector3" or v.Magnitude <= 1e-4 then
\t\treturn Vector3.new(0, 0, -1)
\tend
\treturn v.Unit
end

local function movementSpeed(v: Vector3?, movementMode: string?): number
\tif (movementMode == "Flying" or movementMode == "Surface") and typeof(v) == "Vector3" then
\t\treturn v.Magnitude
\tend
\treturn flatSpeed(v)
end''',
    "client movement helpers",
)

client = replace_once(
    client,
    '''\t\tmovementMode = "Ground",
\t\tmovementProfile = "GroundSmall",
\t\thp = 0,''',
    '''\t\tmovementMode = "Ground",
\t\tmovementProfile = "GroundSmall",
\t\tmovementSystem = "Legacy",
\t\tmovementBehavior = "GroundWalker",
\t\tcombatBehavior = nil,
\t\tsurfaceNormal = Vector3.yAxis,
\t\trenderSurfaceNormal = Vector3.yAxis,
\t\thp = 0,''',
    "client entry movement defaults",
)

client = replace_once(
    client,
    '''\t\t\tif typeof(item.movementProfile) == "string" then
\t\t\t\tentry.movementProfile = item.movementProfile
\t\t\tend
\t\t\tif seen then''',
    '''\t\t\tif typeof(item.movementProfile) == "string" then
\t\t\t\tentry.movementProfile = item.movementProfile
\t\t\tend
\t\t\tif typeof(item.movementSystem) == "string" then
\t\t\t\tentry.movementSystem = item.movementSystem
\t\t\tend
\t\t\tif typeof(item.movementBehavior) == "string" then
\t\t\t\tentry.movementBehavior = item.movementBehavior
\t\t\tend
\t\t\tif typeof(item.combatBehavior) == "string" then
\t\t\t\tentry.combatBehavior = item.combatBehavior
\t\t\tend
\t\t\tif typeof(item.surfaceNormal) == "Vector3" then
\t\t\t\tentry.surfaceNormal = surfaceUp(item.surfaceNormal)
\t\t\t\tif fullSnapshot or not entry.renderSurfaceNormal then
\t\t\t\t\tentry.renderSurfaceNormal = entry.surfaceNormal
\t\t\t\tend
\t\t\tend
\t\t\tif seen then''',
    "client snapshot metadata",
)

client = replace_once(
    client,
    '''\t\t\t\tentry.targetDir = movementDir(item.dir, entry.movementMode)''',
    '''\t\t\t\tentry.targetDir = movementDir(item.dir, entry.movementMode, entry.surfaceNormal)''',
    "client snapshot direction",
)

client = replace_once(
    client,
    '''\t\tlocal goalDir = movementDir(entry.targetDir or entry.velocity, entry.movementMode)
\t\tif typeof(entry.velocity) == "Vector3" and entry.velocity.Magnitude > 0.2 then
\t\t\tgoalDir = movementDir(entry.velocity, entry.movementMode)
\t\tend

\t\tentry.renderPos = entry.renderPos and entry.renderPos:Lerp(goalPos, math.clamp(dt * 12, 0, 1)) or goalPos
\t\tentry.renderDir = entry.renderDir and entry.renderDir:Lerp(goalDir, math.clamp(dt * 14, 0, 1)) or goalDir
\t\tentry.renderDir = movementDir(entry.renderDir, entry.movementMode)''',
    '''\t\tlocal goalDir = movementDir(entry.targetDir or entry.velocity, entry.movementMode, entry.surfaceNormal)
\t\tif typeof(entry.velocity) == "Vector3" and entry.velocity.Magnitude > 0.2 then
\t\t\tgoalDir = movementDir(entry.velocity, entry.movementMode, entry.surfaceNormal)
\t\tend

\t\tentry.renderPos = entry.renderPos and entry.renderPos:Lerp(goalPos, math.clamp(dt * 12, 0, 1)) or goalPos
\t\tentry.renderSurfaceNormal = surfaceUp(
\t\t\tentry.renderSurfaceNormal and entry.renderSurfaceNormal:Lerp(entry.surfaceNormal, math.clamp(dt * 12, 0, 1))
\t\t\t\tor entry.surfaceNormal
\t\t)
\t\tentry.renderDir = entry.renderDir and entry.renderDir:Lerp(goalDir, math.clamp(dt * 14, 0, 1)) or goalDir
\t\tentry.renderDir = movementDir(entry.renderDir, entry.movementMode, entry.renderSurfaceNormal)''',
    "client render interpolation",
)

client = replace_once(
    client,
    '''\t\tlocal displayPos = entry.renderPos + getSpawnRiseOffset(entry, now)
\t\tlocal up = math.abs(entry.renderDir:Dot(Vector3.yAxis)) > 0.98 and Vector3.xAxis or Vector3.yAxis
\t\tlocal rootFrame = CFrame.lookAt(displayPos, displayPos + entry.renderDir, up)''',
    '''\t\tlocal displayPos = entry.renderPos + getSpawnRiseOffset(entry, now)
\t\tlocal up = entry.movementMode == "Surface"
\t\t\tand surfaceUp(entry.renderSurfaceNormal)
\t\t\tor (math.abs(entry.renderDir:Dot(Vector3.yAxis)) > 0.98 and Vector3.xAxis or Vector3.yAxis)
\t\tlocal forward = movementDir(entry.renderDir, entry.movementMode, up)
\t\tlocal rootFrame = CFrame.lookAt(displayPos, displayPos + forward, up)''',
    "client surface orientation",
)

client_path.write_text(client, encoding="utf-8")
print("Applied switchable NPC movement integration patch")
