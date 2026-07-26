# Nawigacja NPC

System zachowuje kinematyczną symulację serwera i interpolację klientową. `NpcService` jest właścicielem rekordów, targetowania, walki, statusów i replikacji. `NpcGroundNavigation` oraz `NpcFlightNavigation` wyznaczają bezpieczny następny krok, ale nie używają `Humanoid:MoveTo`.

## Profile ruchu

Profile są zdefiniowane w `ServerScriptService.ModuleScript.NpcNavigationConfig`:

- `GroundSmall` — domyślny profil istniejących mobów; agent o promieniu 1,75 i wysokości 6 studów. Może wykonać niski, kinematyczny hop przez waypoint `Jump` albo nad zwalidowaną niską przeszkodą.
- `GroundLarge` — większy korytarz, krok do 4,5 studa i zwalidowany `Stride` do 6 studów w górę / 8 w dół. Nie używa klasycznego skoku. Obecnie używany przez Grzyba, Golema, Knighta i Enta.
- `Flying` — ruch 3D, promień kolizyjny 2,5, preferowana wysokość 14 i minimalny prześwit 7 studów.

Profil można wskazać w konfiguracji moba przez `movementProfile`, przez `movementMode`, `canFly` albo atrybut modelu `CanFly`. Brak konfiguracji zawsze daje profil naziemny. Nie ustawiaj `CanFly` tylko dlatego, że nazwa lub wygląd moba sugeruje latanie.

## Przechodzenie nad przeszkodami

Próba hopu albo dużego kroku uruchamia się tylko po zablokowanym lokalnym kroku lub na przejściu `Jump`. System najpierw sprawdza wysokość przeszkody, dystans, dozwolony wznios/opad, pełny footprint lądowania oraz podniesiony korytarz korpusu. Skrzynie, niskie pnie i małe kamienie mogą zostać przekroczone, ale wysoka ściana, stromy klif, woda/lawa albo brak bezpiecznej powierzchni nadal wymuszają zatrzymanie i repath.

Przejście jest stanem w istniejącym schedulerze ruchu 12 Hz. Nie powstaje osobny `Heartbeat`, task ani fizyczny `Humanoid` dla NPC. Podczas aktywnego przejścia `ConstrainPosition` zwraca wyliczoną pozycję łuku zamiast ponownie przyklejać Y do ziemi; po lądowaniu wykonuje normalny snap do zwalidowanej powierzchni. `PauseState` i freeze zatrzymują także zegar aktywnego przejścia; przy wznowieniu oba znaczniki czasu są przesuwane o czas zatrzymania, więc NPC kontynuuje od bieżącej pozycji łuku bez skoku do lądowania.

## Powierzchnie i proxy mapy

Walkable ground może być:

- Roblox `Terrain`,
- `BasePart` lub model oznaczony starym tagiem `Terrain`,
- `BasePart` lub model oznaczony tagiem `NpcWalkable`.

Złożony model low-poly powinien mieć proste, niewidoczne i zakotwiczone proxy kolizji. Proxy powinno być `CanCollide=true`, należeć do modelu albo folderu mapy i mieć tag `NpcWalkable`. Nie oznaczaj części czysto wizualnych jako walkable, jeżeli ich geometria ma szczeliny albo strome dekoracyjne powierzchnie.

Ground probe jest lokalny względem bieżącej lub oczekiwanej warstwy wysokości. Dzięki temu podłoże pod mostem i nawierzchnia mostu nie są zamieniane automatycznie.

## PathfindingModifier i koszty

Dodaj `PathfindingModifier` jako dziecko proxy i ustaw `Label`. Wbudowane profile rozpoznają:

- `Bridge`,
- `NarrowBridge`,
- `Water`,
- `Mud`,
- `Lava`,
- `Jump`, `Climb` i `Drop`.

`Water` i `Lava` mają dla zwykłych profili koszt blokujący. `Mud` jest dozwolone, ale droższe. Dalsze etykiety można dodać wyłącznie w tabeli `Costs` profilu, bez zmiany runtime kontrolera.

## PathfindingLink

Ręcznie umieszczony `PathfindingLink` może prowadzić przez przejście specjalne. Używaj etykiet:

- `Jump` — tylko profil z `CanJump=true`,
- `Climb` — tylko profil z `CanClimb=true`,
- `Drop` — tylko profil z `CanDrop=true`.

Nie generuj losowych linków w runtime. Oba attachmenty linku muszą leżeć na poprawnych warstwach nawigacyjnych, a odcinek przejścia nie może prowadzić przez wizualną ścianę. Serwer wykonuje przejście kinematycznie między waypointami.

## Nawigacja lotnicza

`NpcFlightNavigation` najpierw sprawdza bezpośredni korytarz przez `Spherecast`. Gdy jest zablokowany, korzysta ze wspólnego grafu:

- tag `NpcAirNode` można nadać `Attachment`, `BasePart` albo modelowi,
- tag `NpcNoFlyZone` nadaje się prostemu `BasePart` albo modelowi opisującemu zakazaną objętość,
- graf łączy tylko widoczne węzły w limicie odległości,
- cache A* jest wspólny dla wszystkich NPC,
- bez węzłów system próbuje bezpiecznej zmiany wysokości i zatrzymuje NPC, jeżeli nie ma wolnego korytarza.

Węzły warto umieszczać po obu stronach zakrętu kanionu, nad i pod mostem, przy wejściu do jaskini oraz na kilku jawnych warstwach wysokości. Nie twórz gęstej regularnej siatki w całej mapie.

## Dodawanie latającego moba

1. Dodaj model do istniejącego folderu template'ów bez zmiany nazw remotes lub folderów.
2. W `MobConfig` ustaw `movementProfile = "Flying"` albo `canFly = true`.
3. Dopasuj `attackRange` do preferowanej wysokości lotu; statystyki walki nadal należą do konfiguracji moba.
4. Zweryfikuj rozmiar modelu względem `CollisionRadius`. Dla większej klasy dodaj osobny jawny profil zamiast zmieniać globalny profil wszystkich latających mobów.
5. Przetestuj spawn, bezpośredni lot, przeszkodę, air nodes, no-fly zone, LOS ataku i cleanup po śmierci.

Latający profil automatycznie pomija emergence spod ziemi i ground snap. Pole `movementMode` jest dodawane kompatybilnie do batcha klientowego, aby `NpcPresentation` nie spłaszczał kierunku lotu.

## Scheduler, debug i metryki

Jeden `Heartbeat` w `NpcService` obsługuje:

- movement/steering: 12 Hz,
- odświeżanie targetów: 3 Hz,
- formacje i opcjonalny debug: 2 Hz,
- istniejący batch klientowy: 10 Hz,
- pathfinding: maksymalnie 2 aktywne obliczenia, 15 startów/s i 160 oczekujących rekordów.

W Studio można wywołać:

```lua
local NpcService = require(game.ServerScriptService.ModuleScript.NpcService)
NpcService.SetNavigationDebugEnabled(true) -- opcjonalnie drugi argument: NpcId
print(NpcService.GetNavigationDebug(modelOrId))
print(NpcService.GetNavigationMetrics())
```

Debug jest wyłączony domyślnie i poza Studio nie może zostać włączony. Wizualizuje profil, target, linię bezpośrednią, waypointy, bieżący waypoint, ground probe, status/reason oraz stan kolejki. Wyłącz go przez `SetNavigationDebugEnabled(false)`.
