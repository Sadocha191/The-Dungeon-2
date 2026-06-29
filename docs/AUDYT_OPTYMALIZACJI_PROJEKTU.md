# Audyt optymalizacji i struktury kodu — The Dungeon 2

Zakres: statyczny skan archiwum `The-Dungeon-2-main.zip` z 29 czerwca 2026 r.  
Przeskanowano 487 plików `.lua/.luau`, łącznie około 141 700 linii. Po odjęciu identycznych kopii pozostaje 308 unikalnych treści i około 101 800 unikalnych linii.

To nie jest wynik MicroProfilera ani pełnego playtestu. Wnioski dotyczą struktury, oczywistych kosztów wykonywanych w pętlach oraz ryzyka błędów wynikających z kolejności uruchamiania skryptów.

## Krytyczne problemy

### 1. DebugStressTools może działać poza Studio

Plik: `Level/ServerScriptService/Script/DebugStressTools.lua`

Skrypt nie ma zabezpieczenia `RunService:IsStudio()`, a domyślnie ustawia:

- `GodModeEnabled = true`
- `SpawnStressMode = true`
- `SpawnBurstSize = 3`
- `SpawnIntervalScale = 0.55`
- `MaxAliveScale = 2.6`
- `PerfHudEnabled = true`

Dodatkowo na każdym `Heartbeat` sprawdza wszystkich graczy i próbuje utrzymywać ich pełne HP. Jeżeli skrypt jest aktywny w opublikowanej grze, zmienia balans, spawn i koszt serwera.

Naprawa: natychmiast dodać na początku:

```lua
if not RunService:IsStudio() then
    return
end
```

lub całkowicie przenieść narzędzia debugowe do oddzielnego miejsca testowego.

### 2. Kilka systemów nadpisuje `_G.ApplyDamageToPlayer`

Definicje występują m.in. w:

- `Level/ServerScriptService/ModuleScript/Stats/RunStatsService.lua:569`
- `Level/ServerScriptService/Script/ShrineService.server.lua:503`
- `Level/ServerScriptService/Script/DebugStressTools.lua:47`

`RunStatsService` obsługuje właściwe statystyki runu. `ShrineService` zastępuje tę funkcję własną implementacją tarczy i trudności. Debug następnie może opakować dowolną wersję, która akurat była dostępna w momencie startu.

Efekt zależy od kolejności uruchamiania skryptów, której nie należy traktować jako stabilnego API. Możliwe skutki:

- pominięcie armor/dodge/statystyk z `RunStatsService`,
- pominięcie tarczy ze shrine,
- różne obrażenia pomiędzy serwerami,
- niedziałający god mode albo permanentny god mode.

Naprawa: jedna publiczna funkcja w `DamageService`. Shrine powinien dodawać modyfikator obrażeń lub hook do tego serwisu, a nie zastępować całą funkcję.

### 3. Repo zawiera wiele równoległych kopii runtime'owych skryptów

Znaleziono 88 grup identycznych plików obejmujących 267 plików. Około 39 900 linii to dokładne kopie.

Przykłady:

- `InventoryController.lua` — dwie identyczne kopie po 2216 linii,
- `BannerUI.lua` — dwie kopie po 1484 linie,
- `MineUI.lua` — dwie kopie po 1416 linii,
- `GuildClient.lua` — dwie kopie po 1143 linie,
- `SpellDefinitions.lua` w `Level/ReplicatedStorage/ModuleScript` i `ModuleScripts`,
- wiele skryptów broni powielonych między `Level`, `Four Peaks` i `roblox`.

Są również kopie, które już się rozjechały:

- dwa `WaveController` — około 457 zmienionych linii,
- dwa `MissionsUI` — około 98 zmienionych linii,
- dwa `BlacksmithUI` — około 44 zmienione linie,
- dwa `EventsClient` — około 37 zmienionych linii.

Jeżeli równoległe LocalScripty znajdują się jednocześnie w aktywnym drzewie gracza, mogą dwukrotnie budować UI i podpinać eventy. Nawet jeśli część jest tylko starym eksportem, łatwo edytować niewłaściwy plik.

Naprawa: najpierw ustalić live ścieżkę Studio, potem oznaczyć lub usunąć stare kopie. Nie wykonywać automatycznego kasowania bez porównania ze Studio.

## Największe problemy wydajnościowe

### 4. NpcService wykonuje globalne sortowanie NPC na każdym Heartbeat

Plik: `Level/ServerScriptService/ModuleScript/NpcService.lua` — 1666 linii.

Na każdej klatce serwera:

1. pobiera wszystkich żywych graczy,
2. przechodzi przez wszystkie NPC i przypisuje je do najbliższego gracza,
3. dla każdej grupy oblicza centroid,
4. sortuje wszystkie NPC według odległości,
5. aktualizuje każdy NPC,
6. wykonuje raycasty ziemi i przeszkód,
7. zapisuje atrybuty stanu.

`buildEngagementSlots()` jest wywoływane co Heartbeat i sortuje grupy NPC. Przy dużej liczbie przeciwników jest to koszt `O(N log N)` wykonywany około 60 razy na sekundę.

Dodatkowo co `0.1 s` tworzony jest pełny snapshot wszystkich NPC i wysyłany przez `FireAllClients`. Dla 500 NPC oznacza budowanie i wysłanie około 5000 rekordów stanu na sekundę przed uwzględnieniem liczby klientów.

Naprawa:

- AI tick 10–20 Hz zamiast 60 Hz,
- formation slots przebudowywać 2–5 razy na sekundę albo tylko po zmianie liczby NPC,
- osobne częstotliwości dla ruchu, targetowania, raycastów i sieci,
- delta replication zamiast pełnego snapshotu,
- kwantyzacja pozycji i LOD zależny od odległości,
- cache list graczy i filtrów raycastu.

### 5. DropService skanuje każdy drop na każdej klatce

Plik: `Level/ServerScriptService/Script/DropService.lua` — 448 linii.

Na każdym `Heartbeat`, dla każdego dropu:

- szuka globalnego magnet targetu,
- w przeciwnym razie przechodzi po wszystkich graczach,
- sprawdza character/humanoid/root,
- gdy drop nie jest przyciągany, może wykonać raycast do ziemi,
- funkcja raycastu za każdym razem buduje nową tablicę ignorowanych obiektów i ponownie pobiera graczy.

Przy wielu orbach koszt rośnie jako `dropy × gracze × 60` plus raycasty.

Naprawa:

- cache żywych graczy raz na tick,
- aktualizacja dropów 15–20 Hz,
- raycast ziemi tylko przy spawnie i po istotnej zmianie pozycji,
- łączenie pobliskich dropów tego samego typu,
- spatial hash/grid dla wyszukiwania gracza,
- buforowanie `RaycastParams` i listy ignorowanych instancji.

### 6. SpellService tworzy osobny Heartbeat dla każdego pocisku

Plik: `Level/ServerScriptService/Script/SpellService.lua` — 1280 linii.

Każdy pocisk uruchamia własne `RunService.Heartbeat:Connect`. Na każdej klatce pocisk wywołuje `NpcService.GetNearestEnemy`, które liniowo skanuje wszystkie NPC. Wiele pocisków daje koszt zbliżony do `pociski × NPC × 60`.

W pliku jest też duży, prawdopodobnie martwy blok serwerowych VFX. Funkcje takie jak `createProjectileVisual`, `spawnBeamVisual`, `spawnNovaVisual`, `spawnRingVisual` i `spawnImpactVisual` nie mają wywołań, podczas gdy właściwe VFX są wysyłane do klienta.

Naprawa:

- jeden centralny `ProjectileService` aktualizujący wszystkie pociski,
- tick kolizji 20–30 Hz,
- spatial partitioning w `NpcService`,
- usunięcie potwierdzonego martwego kodu VFX,
- podział combat logic i visual payload builder.

### 7. RunStatsService zapisuje atrybuty co klatkę

Plik: `Level/ServerScriptService/ModuleScript/Stats/RunStatsService.lua`.

Na każdym Heartbeat dla każdego żywego gracza wywoływane jest pięć `SetAttribute`, nawet gdy wartości się nie zmieniły. Regeneracja HP również nie wymaga 60 Hz.

Naprawa: cache ostatnich wartości i zapis tylko po zmianie; regen oraz synchronizacja 5–10 Hz.

### 8. MovementController wykonuje pracę debugową mimo wyłączonego debugowania

Plik: `Level/StarterPlayer/StarterPlayerScripts/LocalScript/MovementController.client.lua` — 1827 linii.

Skrypt jest duży, ale większość jest spójną maszyną ruchu. Realne problemy:

- na każdej klatce tworzony jest nowy `RaycastParams`,
- wykonywany jest raycast podłoża,
- wiele wywołań tworzy `string.format(...)` przed wejściem do `debugLog`; nawet gdy `DebugMovement = false`, tekst już został zbudowany,
- jedna funkcja `updateMovement` obsługuje sprint, dash, slide, slope, air control, low gravity, momentum i landing transition.

Naprawa:

- jeden cache'owany `RaycastParams`,
- debug callback lub warunek przed `string.format`,
- wydzielić `SlideController`, `AirMomentumController`, `JumpController` i `DashController`,
- zachować jeden centralny update loop.

### 9. PlayerHubLobby skanuje wszystkie ScreenGui co RenderStepped

Plik: `Four Peaks/StarterPlayer/StarterPlayerScripts/PlayerHubLobby.lua:86`.

`anyModalOpen()` przechodzi po wszystkich dzieciach `PlayerGui` około 60 razy na sekundę. Stan modalny powinien być event-driven przez wspólny `ModalUiState` albo atrybut/licznik.

## God Scripty wymagające podziału

### Priorytet 1

#### WaveController — 2611 linii

Łączy spawn, pozycje, skalowanie, rewardy, elity, bossy, umiejętności, portal, zakończenie runu, HUD i debug. Szczegółowy audyt wykonano osobno.

#### ProgressService — 1645 linii

Obsługuje:

- stan runu,
- party XP i level-up,
- pause sources,
- misje,
- spell offers i rarity,
- synergie,
- stat gains,
- monety/souls,
- kill tracking,
- boss tracking,
- zakończenie runu,
- zapis persistent data,
- podsumowanie.

Proponowany podział: `RunStateService`, `RunProgressionService`, `UpgradeOfferService`, `PartyProgressService`, `RunMissionTracker`, `RunEndService`.

#### NpcService — 1666 linii

Jest częściowo spójny, ale nadal łączy: rejestr NPC, ruch, ground snapping, obstacle avoidance, targetowanie, combat, crowd formation, status effects, damage, death callbacks i network replication.

Proponowany podział: `NpcRegistry`, `NpcSimulation`, `NpcTargeting`, `NpcCombat`, `NpcReplication`.

#### GuildService — 1503 linie

Łączy persistent storage, katalog gildii, członkostwo, role, invite'y, requesty, treasury, upgrade'y, taski, teleport i snapshoty UI.

Dodatkowy problem: `GuildService.Search` może wykonywać `GetAsync` dla każdego pasującego wpisu przed ograniczeniem wyników do 20. Przy rosnącej liczbie gildii będzie to bardzo drogie i podatne na throttling. Katalog jest zapisywany przez `SetAsync` jako jeden duży rekord, co grozi utratą zmian między serwerami.

Proponowany podział: `GuildRepository`, `GuildDirectoryService`, `GuildMembershipService`, `GuildTreasuryService`, `GuildProgressionService`, `GuildTeleportService`.

#### GuildPlace.server.lua — 1422 linie

Łączy setup remotes, wczytywanie profilu, DataStore gildii, treasury transactions, budowanie świata/promptów, autoryzację i teleport powrotny.

Proponowany podział: `GuildCastleBootstrap`, `GuildCastleWorldService`, `GuildTreasuryRemoteService`, `GuildCastleRepository`.

### Priorytet 2

#### InventoryController — 2216 linii

To największy klient lobby. Łączy pełne tworzenie UI, styling, wszystkie zakładki, wallet/resources, statystyki, weapon details, spell details, codex, context menu, akcje i snapshoty.

Nie jest głównym bottleneckiem serwera, ale jest bardzo trudny do utrzymania. Proponowany podział:

- `InventoryView`,
- `InventoryTabs`,
- `InventoryDetailsPresenter`,
- `InventoryDataAdapter`,
- `InventoryActions`,
- `InventoryTheme`.

#### BlacksmithUI — około 1630 linii

Łączy UI, kamerę, ukrywanie postaci, prompty, movement lock, icon resolution, listę craftów, tooltipy, szczegóły i akcje serwera.

Proponowany podział: `BlacksmithCameraController`, `BlacksmithVisibilityController`, `BlacksmithCatalogView`, `BlacksmithDetailsView`, `BlacksmithActionController`.

#### SpellService — 1280 linii

Poza problemem pocisków łączy scheduler, targeting, damage/effects, orbit, nova, zone, beam, projectile i część starego VFX.

#### CraftingService — 1287 linii

Łączy materiały, recipe discovery, mining, yield rolling, crafting, upgrade broni, sprzedaż i tworzenie snapshotów UI.

Proponowany podział: `MaterialInventoryService`, `MiningService`, `RecipeService`, `WeaponCraftService`, `WeaponUpgradeService`, `CraftingSnapshotBuilder`.

### Priorytet 3 — duże UI, ale mniejsze ryzyko runtime

- `BannerUI.lua` — 1484 linie,
- `MineUI.lua` — 1416 linii,
- `SpellVFXClient.lua` — 1268 linii,
- `MissionsUI.lua` — 1254 linie,
- `GuildClient.lua` — 1143 linie,
- `ChestRewardClient.client.lua` — 898 linii,
- `PortalUIController.lua` — 847 linii.

W tych plikach głównym problemem jest utrzymanie i testowanie, nie sama liczba linii. Najpierw należy naprawić serwerowe hot loopy i ukryte zależności.

## Duże pliki, które nie są automatycznie problemem

- `SpellDefinitions.lua` — głównie definicje contentu; warto dzielić według elementów/spelli, ale nie jest to bezpośredni bottleneck.
- `ErrorReporter.lua` — duża biblioteka, lecz odpowiedzialność jest względnie spójna.
- `Hybrid Terrain Hex Generator.lua` i pluginy Mesh Collision Browser — narzędzia edytorowe, nie runtime gry.
- skrypty `Animate.lua` i assety broni — wiele z nich jest dużych lub zduplikowanych, ale nie należy mieszać ich z centralnymi systemami gry bez osobnego audytu assetów.

## Zalecana kolejność prac

1. Zabezpieczyć lub usunąć `DebugStressTools` z produkcji.
2. Zastąpić `_G.ApplyDamageToPlayer` jednym `DamageService`.
3. Ustalić live ścieżki Studio i zamknąć problem duplikatów/driftu.
4. Zoptymalizować `NpcService` replication i formation tick.
5. Zoptymalizować `DropService` oraz centralizować pociski w `SpellService`.
6. Rozdzielić `WaveController` i `ProgressService` bez zmiany działania.
7. Dopiero potem dzielić duże UI i serwisy lobby.
8. Po każdej zmianie wykonać test pełnego flow: lobby → teleport → run → boss/end → powrót → zapis danych.

## Najważniejszy wniosek

Problem projektu nie polega na tym, że istnieją pliki powyżej 1000 linii. Największym ryzykiem są:

- logika wykonywana dla każdego NPC/dropu/pocisku na każdej klatce,
- pełne snapshoty sieciowe,
- ukryte API w `_G`,
- kilka systemów nadpisujących te same funkcje,
- równoległe kopie plików i drift między nimi,
- debugowe ustawienia wpływające na produkcyjny gameplay.
