# Nawigacja NPC

System nadal używa serwerowo autorytatywnej, kinematycznej symulacji i klientowej interpolacji batcha. `NpcService` pozostaje właścicielem rekordów NPC, targetowania, walki, statusów i replikacji. Zmienił się właściciel tras naziemnych: `NpcGroundNavigation` zawsze zamawia trasę przez natywny Roblox `PathfindingService`, a następnie prowadzi rekord NPC po zwróconych `PathWaypointach`.

Nie używamy `Humanoid:MoveTo()`. Modele NPC są celowo zakotwiczone, niekolizyjne i replikowane przez istniejący `NpcBatchEvent`. Odkotwiczenie całej hordy oraz uruchomienie fizyki, network ownership i połączeń `MoveToFinished` dla każdego moba byłoby inną architekturą i pogorszyłoby skalowanie survivorsowego runu.

## Zakres refaktoryzacji

Dla wszystkich naziemnych mobów, niezależnie od tagu `Legacy`/`MovementV2`:

1. `NpcGroundNavigation` próbuje od razu zamówić natywną trasę do aktualnego slotu/formacji przy graczu.
2. `PathfindingService:CreatePath()` dostaje parametry aktywnego profilu (`AgentRadius`, `AgentHeight`, `AgentCanJump`, `AgentCanClimb`, `WaypointSpacing`, `Costs`).
3. `Path:ComputeAsync()` wyznacza trasę, a `Path:GetWaypoints()` staje się jedynym źródłem dalekiego routingu naziemnego.
4. Centralny scheduler `NpcService` przesuwa rekord NPC w stronę bieżącego waypointa i replikuje pozycję istniejącym batchem.
5. Jeżeli bieżący krok jest zablokowany, trasa jest unieważniana, odpowiadający jej wpis cache jest wyrzucany i NPC zamawia nową trasę.

Usunięto z ground routingu własne dalekie sondowanie `CanTraverse`, lokalne omijanie przeszkód i automatyczne wymyślanie hopów/stride nad wykrytą geometrią. Podczas oczekiwania na ograniczony budżetem wynik `ComputeAsync` NPC może wykonać wyłącznie jeden prosty, lokalnie zwalidowany krok w stronę celu. Nie szuka wtedy własnej drogi i zatrzymuje się na przeszkodzie.

## Dlaczego zostaje lokalna walidacja powierzchni

`PathfindingService` wyznacza trasę, ale nie przesuwa zakotwiczonego modelu i nie utrzymuje jego dokładnego offsetu nad low-poly Terrain/proxy. `NpcGroundSurface.ValidateStep()` pozostaje wyłącznie warstwą wykonawczą:

- przykleja root NPC do właściwej warstwy wysokości,
- sprawdza footprint i korytarz korpusu dla następnego krótkiego kroku,
- blokuje wodę, lawę, zbyt strome powierzchnie i nagłe przejście między warstwami,
- chroni przed przejściem pod mostem na jego górną warstwę i odwrotnie.

Nie wyznacza już dalekiej trasy ani obejścia przeszkody.

## Profile ruchu

Profile są zdefiniowane w `ServerScriptService.ModuleScript.NpcNavigationConfig`:

- `GroundSmall` — agent o promieniu `1.75`, wysokości `6`, z natywnym skokiem i waypoint spacing `6`.
- `GroundLarge` — agent o promieniu `5.5`, wysokości `18`, bez skoku i z waypoint spacing `8`. Używany przez większe moby, między innymi Golema, Knighta i Enta.
- `Flying` — osobna nawigacja 3D; Robloxowy ground navmesh nie obsługuje swobodnego lotu.
- `SurfaceCrawler` — osobna nawigacja po ścianach/sufitach; standardowy ground navmesh nie opisuje takiego ruchu.

`NpcNavigationConfig.ActiveSystem` nadal wybiera zestaw zachowań/tagów dla nowych spawnów, ale nie wybiera już starego lub nowego backendu naziemnego. Każdy `GroundSmall` i `GroundLarge` przechodzi przez ten sam natywny adapter `PathfindingService`.

## Natywne waypointy i skoki

Zwykłe waypointy są realizowane jako zwalidowane kroki naziemne. Waypoint z `Enum.PathWaypointAction.Jump` uruchamia krótki kinematyczny łuk do pozycji wskazanej przez natywną trasę. Sam punkt skoku i lądowania pochodzi z `PathfindingService`; kod nie próbuje sam wykryć skrzyni, kamienia albo ściany i nie tworzy własnego przejścia.

`PauseState` i freeze zatrzymują zegar aktywnego skoku. Po wznowieniu NPC kontynuuje łuk bez przeskoku czasowego. `GroundLarge` odrzuca trasę zawierającą niedozwolony skok i zamawia inną.

## Cache i limity PathfindingService

Obliczenia są współdzielone i ograniczone globalnie:

- maksymalnie `2` aktywne `ComputeAsync`,
- maksymalnie `15` startów ścieżek na sekundę,
- maksymalnie `160` oczekujących rekordów,
- krótki cache według profilu, sektora startowego, sektora celu i warstwy Y,
- trasa jest odświeżana po przesunięciu celu, wygaśnięciu, zablokowanym kroku albo wykryciu braku postępu.

Cache przechowuje tylko natywne waypointy. Jeżeli współdzielona trasa nie pasuje do lokalnej geometrii konkretnego NPC, pierwszy zablokowany krok natychmiast usuwa ten wpis i wymusza osobne obliczenie.

Nie podpinamy trwałego `Path.Blocked` dla każdego żywego NPC. Przy setkach mobów oznaczałoby to setki dodatkowych połączeń. Zamiast tego istniejący centralny tick wykrywa blokadę bieżącego kroku, brak postępu i wygaśnięcie trasy.

## Powierzchnie i proxy mapy

Walkable ground może być:

- Roblox `Terrain`,
- `BasePart` lub model oznaczony starym tagiem `Terrain`,
- `BasePart` lub model oznaczony tagiem `NpcWalkable`.

Złożony model low-poly powinien mieć proste, niewidoczne i zakotwiczone proxy kolizji. Proxy powinno mieć `CanCollide=true`, należeć do modelu albo folderu mapy i posiadać tag `NpcWalkable`. Nie oznaczaj części czysto wizualnych jako walkable, jeżeli geometria ma szczeliny albo strome dekoracyjne powierzchnie.

W Studio włącz `Navigation mesh` oraz `Pathfinding modifiers`. Jeżeli obszar nie pojawia się na natywnym navmeshu dla rozmiaru danego profilu, NPC nie otrzyma przez niego poprawnej trasy niezależnie od tagu `NpcWalkable` używanego przez końcową walidację kroku.

## PathfindingModifier i koszty

Dodaj `PathfindingModifier` jako dziecko proxy i ustaw `Label`. Profile rozpoznają między innymi:

- `Bridge`,
- `NarrowBridge`,
- `Water`,
- `Mud`,
- `Lava`,
- `Jump`, `Climb` i `Drop`.

`Water` i `Lava` mają dla zwykłych profili koszt blokujący. `Mud` jest dozwolone, ale droższe. Klucze w tabeli `Costs` są przekazywane bezpośrednio do `PathfindingService:CreatePath()`.

## PathfindingLink

Ręcznie umieszczony `PathfindingLink` może prowadzić przez przejście specjalne, ale musi zostać przetestowany z faktycznym profilem agenta. Link `Jump` jest dozwolony tylko dla profilu z `AgentCanJump=true`, a `Climb` tylko dla `AgentCanClimb=true`. Nie generuj losowych linków w runtime.

Oba attachmenty linku muszą leżeć na prawidłowym navmeshu i warstwie wysokości. Sam `PathfindingLink` opisuje trasę; wykonanie nietypowej interakcji, takiej jak drzwi, łódź albo teleport, nadal wymaga osobnego jawnego zachowania.

## Nawigacja lotnicza i surface crawler

`NpcFlightNavigation` pozostaje osobnym systemem 3D z testem korytarza i opcjonalnym grafem `NpcAirNode`. `NpcSurfaceNavigation` pozostaje osobnym systemem adhezji do powierzchni oznaczonych `NpcCrawlable`/`NpcWalkable`.

Te dwa tryby nie są błędem ani obejściem. Natywny `PathfindingService` tworzy trasy dla agentów poruszających się po navmeshu powierzchni chodzonych; nie zastępuje swobodnego lotu ani chodzenia po pionowych ścianach i sufitach.

## Scheduler, debug i metryki

Jeden `Heartbeat` w `NpcService` nadal obsługuje:

- movement: `12 Hz`,
- odświeżanie targetów: `3 Hz`,
- formacje i opcjonalny debug: `2 Hz`,
- batch klientowy: `10 Hz`,
- kolejkę i token bucket natywnego pathfindingu.

W Studio można wywołać:

```lua
local NpcService = require(game.ServerScriptService.ModuleScript.NpcService)
NpcService.SetNavigationDebugEnabled(true) -- opcjonalnie drugi argument: NpcId
print(NpcService.GetNavigationDebug(modelOrId))
print(NpcService.GetNavigationMetrics())
```

Debug ground navigation zwraca `backend = "PathfindingService"`, bieżący status, waypointy, indeks waypointa, powód ostatniego repathu, lokalny ground probe i stan skoku. Najważniejsze metryki to `pathRequests`, `pathStarts`, `pathSuccesses`, `pathFailures`, `pathCacheHits`, `pathQueueFull`, `nativePathTicks`, `nativeFallbackTicks`, `blockedStepTicks`, `stuckRepaths`, `pendingPaths` i `activePaths`.

## Obowiązkowy playtest po synchronizacji do Studio

1. Włącz podgląd navmesha i sprawdź mapę dla `GroundSmall` oraz `GroundLarge`.
2. Przetestuj co najmniej zwykłego moba, Goblina, dużego moba, Bossa/MiniBossa, Bata i SurfaceCrawlera.
3. Sprawdź ścianę, wąskie przejście, most z drogą pod nim, slope, schody, wodę/lawę, niedostępny cel i zmianę celu w ruchu.
4. Potwierdź natywny waypoint `Jump`, pause/freeze podczas skoku, knockback i zewnętrzne `NpcService.SetPosition`.
5. Uruchom próbę `100+` NPC i porównaj MicroProfiler oraz `NpcService.GetNavigationMetrics()`.
6. Potwierdź brak błędów, brak rosnącej kolejki po despawnie i prawidłowy cleanup po śmierci/end runie.
