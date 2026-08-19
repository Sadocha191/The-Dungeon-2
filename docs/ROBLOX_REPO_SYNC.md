# ROBLOX_REPO_SYNC

Ten dokument określa aktualne zasady synchronizacji Roblox Studio z repo.

## Aktualny status

- Ostatni zweryfikowany snapshot osiągnął script parity na poziomie pokrycia repo.
- Full object parity nadal jest częściowe: nie wszystkie modele, UI, Tool, remotes, atrybuty i inne obiekty nieskryptowe są odwzorowane 1:1.
- Parity nie jest stanem wiecznym. Każda dotykana ścieżka powinna zostać sprawdzona ponownie, jeżeli Studio mogło się zmienić.

## Źródło prawdy

Przy rozbieżności między repo i aktywnym Studio:

1. sprawdź aktywny obiekt w Studio,
2. ustal, czy plik repo jest aktywnym mirrorem, kopią compatibility, stale snapshotem albo historycznym eksportem,
3. traktuj Studio jako źródło prawdy, chyba że użytkownik wyraźnie poleci przywrócić wersję z repo.

## Główne mapowania

- `Poziom` ↔ `Level/`
- `level2` ↔ `Level2/`
- `Cztery szczyty` ↔ `Four Peaks/`
- `Gildia` ↔ `Guild/`
- `roblox/` zawiera dodatkowe mirrory i manifesty parity; nie zakładaj automatycznie, że zastępuje aktywne drzewa powyżej.

## Snapshoty dungeon Packages

- Shared runtime jest przechowywany pod `Level*/ServerScriptService/DungeonPackages/<Package>/Templates/<Service>/...`.
- Te same źródła mogą fizycznie występować w `Level/` i `Level2/`; jest to świadomy mirror dwóch drzew Studio, a nie dwa niezależne forki do utrzymywania.
- `PackageManifest.lua` opisuje ownership i dependency graph, a `DungeonPackages/MANIFEST.md` przechowuje asset ID, status `PackageLink` i nieskryptowe atrybuty kontenerów.
- `ServerStorage/DungeonLevel/LevelConfig.lua` jest per Place i nie może zostać zastąpiony configiem z drugiego snapshotu.
- `Workspace/MANIFEST.md` dokumentuje map contract tam, gdzie terrain/geometria nie jest serializowana do repo.
- Zmiany shared kodu najpierw wykonuje się w Studio, publikuje do Roblox Package, aktualizuje linked copies i testuje; kopiowanie między folderami repo nie jest deploymentem.
- Przy porównaniu package parity pomijaj dozwolone różnice `LevelConfig`, place manifestu i mapy. Źródła wewnątrz pięciu shared roots powinny pozostać identyczne.

## Procedura przed zmianą

1. Wylistuj dostępne instancje Studio.
2. Ustaw właściwy place jako aktywny.
3. Potwierdź dokładny Roblox path dotykanego skryptu lub obiektu.
4. Wyszukaj odpowiadające mu pliki i duplikaty w repo.
5. Sprawdź lokalny `MANIFEST.md`, jeżeli istnieje.
6. Zdecyduj, który plik jest kanoniczny dla tego zadania.
7. Dopiero wtedy edytuj kod.

## Zasady mirrorowania skryptów

- Każdy aktywny `Script`, `LocalScript` i `ModuleScript` powinien mieć odpowiadający plik źródłowy.
- Ścieżka repo powinna odwzorowywać realnego rodzica w Studio, o ile nie jest to świadomie utrzymywany historyczny mirror.
- Nie twórz sztucznych folderów tylko po to, aby dopasować typ skryptu.
- Jeżeli nie da się potwierdzić zgodności, nie oznaczaj pliku jako kanoniczny.
- Po synchronizacji porównaj źródło lub przynajmniej długość/checksum, gdy workflow to umożliwia.

## Obiekty nieskryptowe

Użyj `MANIFEST.md`, gdy kod zależy od struktury, której sam plik Lua nie opisuje, np.:

- `RemoteEvent` i `RemoteFunction`,
- `Folder`, `Model` i `Tool`,
- hierarchia `ScreenGui`,
- `ProximityPrompt`, `Attachment`, sound, particle i values,
- krytyczne atrybuty i tagi,
- duplicate-instance edge cases.

Manifest powinien podać:

- dokładny Roblox path,
- odpowiadający repo path,
- klasy i ważne children,
- krytyczne atrybuty/tagi,
- status `COMPLETE`, `PARTIAL` lub `UNKNOWN`,
- informację o ewentualnym canonical mirrorze duplikatu.

## Duplikaty

- Nie aktualizuj wszystkich podobnych plików w ciemno.
- Jeżeli Studio ma jedną aktywną ścieżkę, a repo kilka kopii, najpierw oznacz role kopii.
- Jeżeli duplicate siblings mają identyczne źródło, filesystem może przechowywać jeden canonical mirror z notatką w manifeście.
- Jeżeli źródła różnią się, zatrzymaj automatyczną migrację i przygotuj osobny plan.

## Status plików repo-only

Stosuj jawne oznaczenia:

- `active` — potwierdzony aktywny mirror,
- `stale_snapshot` — brak aktywnego odpowiednika w obecnym Studio,
- `unknown` — za mało danych,
- `candidate_to_restore_to_studio` — możliwa wersja do przywrócenia,
- `candidate_for_removal_later` — prawdopodobnie zbędny, ale nie do automatycznego usunięcia.

## Refaktor a parity

Częściowe full object parity nie blokuje każdej poprawki i każdego refaktoru.

Przy refaktorze:

- potwierdź parity konkretnych dotykanych ścieżek,
- nie przenoś obiektów Studio bez planu,
- zachowaj path-sensitive kontrakty,
- rozdziel refaktor zachowujący działanie od zmian gameplayowych,
- zsynchronizuj i przetestuj każdy etap.

Nie wymagaj pełnego globalnego audytu całego projektu, jeżeli zadanie dotyczy jednego dobrze zweryfikowanego systemu.

## Nazwy wymagające szczególnej ostrożności

Bez audytu użyć nie zmieniaj:

- `Remotes`, `RemoteEvents`, `RemoteFunctions`,
- `ModuleScript`, `ModuleScripts`,
- `WeaponTemplates`, `NPCs`,
- `Portal`, `PortalModel`, `PortalTeleport`,
- nazw remote'ów,
- nazw atrybutów i tagów,
- DataStore names i kluczy,
- pól `TeleportData`.

## Po zmianie

1. Wykonaj compile check.
2. Zsynchronizuj właściwy obiekt Studio, jeżeli jest to część zadania.
3. Odczytaj ponownie live source albo zweryfikuj checksum.
4. Uruchom odpowiedni playtest.
5. Zapisz zmienione ścieżki, testy, ryzyka i rollback w miesięcznym changelogu.
