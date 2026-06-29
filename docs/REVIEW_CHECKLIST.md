# REVIEW_CHECKLIST

Użyj przed oznaczeniem większego zadania jako ukończone.

## Zakres

- [ ] Zmiana rozwiązuje tylko uzgodniony problem.
- [ ] Nie wykonano nieplanowanego refaktoru.
- [ ] Diff nie zawiera przypadkowych zmian formatowania ani unrelated files.

## Architektura

- [ ] Nowa logika ma jawnego właściciela.
- [ ] Nie dodano niezależnego systemu do God Scriptu bez oceny wydzielenia.
- [ ] Jeżeli dotknięty plik ma ponad 800 linii, sprawdzono jego odpowiedzialności.
- [ ] Konfiguracja/content nie zostały niepotrzebnie umieszczone w kontrolerze runtime.
- [ ] Nie dodano nowego `_G` ani zależności zależnej od kolejności startu skryptów.
- [ ] Nie powstała cykliczna zależność modułów.

## Pętle i wydajność

- [ ] Wypisano wszystkie nowe lub zmienione pętle runtime.
- [ ] Nie ma `Heartbeat`/`RenderStepped` per NPC, pocisk, drop lub efekt.
- [ ] Częstotliwość pętli odpowiada wymaganej dokładności.
- [ ] W częstej pętli nie dodano bez uzasadnienia `GetDescendants`, sortowania całości, dużych alokacji albo nowych `RaycastParams`.
- [ ] Oszacowano koszt przy docelowej liczbie obiektów.
- [ ] Snapshoty sieciowe nie są pełne i zbyt częste bez potrzeby.
- [ ] Operacje persistent są buforowane i nie wykonują się na każdy tick/kill.

## Lifecycle

- [ ] Dynamiczne connections mają cleanup.
- [ ] Respawn, koniec runu i ponowne otwarcie UI nie duplikują eventów.
- [ ] Aktywne tabele usuwają martwe obiekty.
- [ ] `task.spawn`/`task.delay` mają kontrolę stanu lub możliwość anulowania tam, gdzie jest potrzebna.

## Studio / repo parity

- [ ] Potwierdzono właściwy place i aktywny Roblox path.
- [ ] Sprawdzono duplikaty i compatibility copies.
- [ ] Zmiana nie pogarsza parity dotykanej ścieżki.
- [ ] Studio pozostaje źródłem prawdy, jeśli użytkownik nie zarządził inaczej.
- [ ] Nie przeniesiono ani nie usunięto obiektów Studio bez osobnego planu.

## Publiczne kontrakty

- [ ] Nie zmieniono nazw `RemoteEvent`, `RemoteFunction`, modułów, folderów, modeli, atrybutów ani tagów bez audytu.
- [ ] Nie zmieniono DataStore name, key schema lub `TeleportData` bez migracji.
- [ ] Dane z klienta są walidowane po stronie serwera.
- [ ] Stare profile mają wartości domyślne dla nowych pól.

## Systemy wrażliwe

- [ ] Sprawdzono wpływ na remotes i shared modules.
- [ ] Sprawdzono wpływ na `ServerStorage.WeaponTemplates` i asset internals, jeśli dotyczy.
- [ ] Sprawdzono wpływ na NPC, portal, character animation i modal UI, jeśli dotyczy.
- [ ] Dla dungeonu sprawdzono powiązania z `WaveController`, `NpcService`, `ProgressService`, `WeaponCombat`, `SpellService` i `DropService`.
- [ ] Dla lobby sprawdzono `PortalToDungeon`, `Inventory`, `Crafting`, `Tutorial`, `Party`, `Missions` i persistent data.

## Walidacja

- [ ] Uruchomiono compile check zmienionych źródeł.
- [ ] Wykonano właściwy Play/Play Solo albo test multiplayer, jeśli jest potrzebny.
- [ ] Przy zmianie wydajnościowej porównano koszt lub przynajmniej sprawdzono MicroProfiler/Stats w scenariuszu obciążenia.
- [ ] Opisano testy, rzeczy niezweryfikowane, ryzyka i rollback.
- [ ] Zaktualizowano `docs/changelog/CHANGELOG_AI_YYYY-MM.md`.

## Raport końcowy

- [ ] Wymieniono wszystkie zmienione pliki.
- [ ] Opisano wpływ na architekturę i wydajność.
- [ ] Nie przedstawiono nieprzetestowanego zachowania jako potwierdzonego.
