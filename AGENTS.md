# AGENTS.md — The Dungeon 2

## Cel

Pracuj jak developer utrzymujący długoterminowy projekt, a nie jak generator jednorazowych poprawek. Kod ma działać, być możliwy do rozwijania i mieć rozsądny koszt przy docelowej liczbie NPC, pocisków, dropów i graczy.

## Start każdego zadania

1. Uruchom `mcp__roblox_mcp__list_roblox_studios`.
2. Jeżeli właściwa instancja Studio jest dostępna, ustaw ją przez `mcp__roblox_mcp__set_active_studio`:
   - `Poziom` dla `Level/`,
   - `Cztery szczyty` dla `Four Peaks/`,
   - `Gildia` dla `Guild/`.
3. Jeżeli Studio lub MCP nie działa, napisz to krótko i kontynuuj na podstawie repo.
4. Używaj MCP do konkretnych inspekcji, synchronizacji i testów. Nie skanuj całej gry bez potrzeby.
5. Sprawdź `git status` i nie nadpisuj niezwiązanych zmian użytkownika.
6. Przeczytaj `docs/AI_WORK_QUEUE.md` oraz `docs/CODEX_TASK_STATE.md` przed rozpoczęciem większej implementacji lub wznowieniem przerwanego zadania.

## Koordynacja ChatGPT ↔ Codex

GitHub jest trwałą warstwą przekazywania stanu między ChatGPT i Codexem. Roblox Studio pozostaje źródłem prawdy dla aktywnego runtime i aktualnych instancji, gdy repo jest rozjechane ze Studio.

- `docs/AI_WORK_QUEUE.md` — krótka wspólna kolejka: co jest aktywne, zablokowane, gotowe do review i do zrobienia.
- `docs/CODEX_TASK_STATE.md` — pełny checkpoint jednego bieżącego większego zadania Codexa.
- PR i jego diff — źródło prawdy dla zmian już zsynchronizowanych z GitHubem.
- Live Studio — źródło prawdy dla faktycznie aktywnych obiektów, ścieżek, Output i testów.

Dla większego zadania Codex musi:

1. przed implementacją sprawdzić, czy w `AI_WORK_QUEUE.md` nie istnieje kolidujące `IN_PROGRESS` albo `PAUSED`,
2. ustawić lub zaktualizować `CODEX_TASK_STATE.md`,
3. po każdym istotnym etapie zapisać krótki checkpoint,
4. przed końcem sesji, wyczerpaniem limitu albo świadomym przerwaniem pracy koniecznie zapisać:
   - co zostało wykonane,
   - co jest w toku,
   - co pozostało,
   - zmienione pliki i obiekty Studio,
   - wykonane testy,
   - znane problemy i blokery,
   - dokładny następny krok,
   - branch / PR / ostatni commit, jeżeli istnieją,
5. nie oznaczać zadania jako `DONE`, dopóki nie przeszło wymaganej walidacji.

Jeżeli sesja Codexa ma lokalne zmiany, których nie ma jeszcze na GitHubie, nie odtwarzaj ich z pamięci ani z opisu PR. Najpierw porównaj `git status`, lokalny HEAD i branch z PR, a potem zaktualizuj checkpoint.

ChatGPT może wykonywać live audyt Studio, analizę, review PR/diff i dopisywać nowe pozycje do kolejki. Nie powinien jednak równolegle implementować zmian w zakresie aktywnego zadania Codexa bez wyraźnej decyzji użytkownika.

## Dokumenty do czytania

Nie czytaj automatycznie całej dokumentacji i pełnego changelogu przed każdym drobnym zadaniem.

Zawsze:

- przeczytaj ten `AGENTS.md`,
- sprawdź ostatnie wpisy w `CHANGELOG_AI.md` oraz odpowiedni fragment bieżącego pliku w `docs/changelog/`.

Czytaj zależnie od zadania:

- `docs/PROJECT_CODE_GUIDE.md` — gdy system jest nieznany, zmiana obejmuje kilka systemów albo dotyczy danych/remotes/teleportu,
- `docs/ROBLOX_REPO_SYNC.md` — gdy synchronizujesz Studio z repo, zmieniasz ścieżki lub trafiasz na duplikaty,
- `docs/ARCHITECTURE_PERFORMANCE.md` — przy nowym systemie, refaktorze albo kodzie działającym często,
- `docs/AUDYT_OPTYMALIZACJI_PROJEKTU.md` — przy pracy nad wydajnością lub dużymi skryptami,
- `docs/ROBLOX_ERROR_REPORTING.md` — tylko przy reporterze błędów i backendzie,
- `docs/REVIEW_CHECKLIST.md` — przed zakończeniem większego zadania.

Dokumenty w `docs/archive/` są historyczne. Nie traktuj ich jako aktualnych instrukcji, chyba że zadanie dotyczy historii parity.

## Zakres pracy

- Jedno zadanie powinno rozwiązywać jeden problem albo jedną wąską funkcję.
- Preferuj najmniejszy diff, który jest poprawny architektonicznie.
- Nie wykonuj pobocznych refaktorów bez związku z zadaniem.
- Nie zmieniaj balansu, nazw publicznych ani formatu danych, jeżeli zadanie tego nie wymaga.
- Nie usuwaj kodu oznaczonego jako legacy tylko dlatego, że wygląda na nieużywany. Najpierw sprawdź wszystkie użycia oraz aktywną strukturę Studio.

## Planowanie przed implementacją

Najpierw przedstaw plan, jeżeli zachodzi co najmniej jeden warunek:

- nowy system gameplayowy,
- zmiana może przekroczyć około 300 linii,
- zmiana obejmuje więcej niż dwa istniejące systemy,
- zmiana dotyczy persistent data, teleportu, remotes albo wspólnego API,
- powstaje nowa pętla `Heartbeat`, `Stepped`, `RenderStepped` lub cykliczny task,
- system obsługuje masowo NPC, pociski, dropy, VFX lub graczy,
- refaktoryzowany jest duży albo silnie sprzężony plik.

Plan powinien wskazać:

1. odpowiedzialności systemu,
2. pliki tworzone i zmieniane,
3. przepływ danych i właścicieli stanu,
4. publiczne API, remotes i zależności,
5. wszystkie pętle runtime i ich częstotliwość,
6. koszt przy skali docelowej,
7. testy, ryzyka i rollback.

## Architektura

- Każdy skrypt lub moduł powinien mieć jedną główną odpowiedzialność.
- Nie dopisuj nowego niezależnego systemu do największego istniejącego pliku tylko dlatego, że jest wygodnym punktem wejścia.
- Plik powyżej około 800 linii wymaga oceny architektury przed dalszym rozbudowywaniem.
- Plik powyżej około 1200 linii nie powinien przyjmować kolejnej niezależnej odpowiedzialności bez wyraźnego uzasadnienia.
- Limity linii są sygnałem do przeglądu, nie powodem do sztucznego dzielenia każdej funkcji na osobny moduł.
- Unikaj zarówno God Scriptów, jak i nadmiernej liczby mikromodułów.
- Dane contentowe i tuning trzymaj w konfiguracjach. Kontroler runtime ma wykonywać konfigurację, a nie przechowywać setki linii definicji.
- Jeden system powinien mieć jednego właściciela, np. damage, NPC simulation, projectiles, drops, rewards, save state.
- Nie dodawaj nowych zależności przez `_G`. Używaj jawnych `ModuleScript` i `require()`.
- Nie nadpisuj globalnej funkcji, którą może definiować inny skrypt.
- Nie zmieniaj nazw `RemoteEvent`, `RemoteFunction`, `ModuleScript`, folderów, modeli, `Attribute` ani tagów bez audytu wszystkich użyć.

## Wydajność Roblox

- Nie twórz osobnego `Heartbeat`, `Stepped` lub `RenderStepped` dla każdego NPC, pocisku, dropu albo efektu.
- Używaj centralnego schedulera/service dla obiektów tego samego typu.
- Nie wykonuj bez uzasadnienia co klatkę:
  - `Players:GetPlayers()`,
  - `GetChildren()` lub `GetDescendants()`,
  - tworzenia `RaycastParams`, tablic filtrów i dużych tabel tymczasowych,
  - sortowania wszystkich NPC,
  - pełnego wyszukiwania najbliższego celu,
  - formatowania logów/debug UI,
  - zapisów DataStore,
  - wysyłania pełnych snapshotów wszystkich obiektów.
- Cache'uj dane, które nie muszą być odświeżane co klatkę.
- Rozdziel częstotliwości pracy. Typowe wartości orientacyjne:
  - krytyczna fizyka: `Heartbeat`, tylko gdy konieczne,
  - AI i steering: około 5–15 Hz,
  - wyszukiwanie celu: okresowo lub po zmianie stanu,
  - HUD i niekrytyczna synchronizacja: około 4–10 Hz,
  - persistent rewards/save: buforowane i wykonywane zbiorczo.
- Projektuj pod co najmniej: 100–500 NPC, 100 pocisków, 300 dropów i kilku graczy, jeżeli system może osiągnąć taką skalę.
- Przy wyszukiwaniu celów rozważ spatial partitioning, siatkę przestrzenną, query cache albo wspólny target service.
- Nowa częsta pętla musi mieć jasno określoną częstotliwość, maksymalną liczbę obiektów i sposób zatrzymania/cleanup.

## Połączenia i cleanup

- Każde dynamiczne połączenie eventu musi mieć właściciela i ścieżkę rozłączenia.
- Sprawdź respawn, usuwanie obiektu, koniec runu i ponowne otwarcie UI pod kątem duplikowania connections.
- Nie twórz nieograniczonych `task.spawn()` lub `task.delay()` bez anulowania albo kontroli stanu.
- Długowieczne tabele aktywnych obiektów muszą usuwać martwe rekordy.

## Refaktory

- Refaktor wykonuj tylko na wyraźne polecenie albo gdy jest niezbędny do bezpiecznej realizacji zadania.
- Duży refaktor i zmiana zachowania powinny być osobnymi etapami.
- Najpierw zachowaj działanie 1:1, potem optymalizuj lub zmieniaj gameplay.
- Podczas wydzielania modułów zachowaj, o ile zadanie nie mówi inaczej:
  - publiczne API,
  - nazwy remotes,
  - format `TeleportData`,
  - format persistent data,
  - kolejność istotnych eventów,
  - zachowanie gameplayowe.
- Nie przepisuj dużego systemu od zera, gdy można wydzielać odpowiedzialności etapami.
- Przed refaktorem potwierdź aktywną ścieżkę w Studio i sprawdź repo pod kątem duplikatów.

## Studio i repo

- Przy rozbieżności Studio jest źródłem prawdy, chyba że użytkownik wyraźnie postanowi inaczej.
- Ostatni znany snapshot ma script parity, ale full object parity pozostaje częściowe. Weryfikuj konkretną dotykaną ścieżkę zamiast zakładać pełną zgodność całego projektu.
- Nie przenoś ani nie usuwaj obiektów w Studio bez osobnego planu.
- Nie poprawiaj jednocześnie wszystkich historycznych kopii. Najpierw ustal, która ścieżka jest aktywna, a które są mirrorami lub stale snapshotami.
- Po zmianie kodu zsynchronizuj właściwy aktywny obiekt Studio, jeżeli MCP jest dostępne i zadanie tego wymaga.

## Server authority i dane

- Klient nie może być źródłem prawdy dla walut, damage, rewardów, ekwipunku ani progresu.
- Waliduj typ, zakres, ownership, cooldown i stan gracza dla danych z klienta.
- Nie zmieniaj DataStore name, kluczy ani kształtu zapisanych danych bez migracji i rollbacku.
- Nowe pola danych muszą mieć bezpieczne wartości domyślne dla starych profili.

## Walidacja przed zakończeniem

1. Przejrzyj cały diff.
2. Sprawdź, czy nie powstał nowy God Script albo nowa ukryta odpowiedzialność w dużym pliku.
3. Wypisz wszystkie dodane lub zmienione pętle runtime i ich częstotliwości.
4. Sprawdź brak per-object Heartbeat oraz nowych zależności `_G`.
5. Sprawdź cleanup eventów i tabel runtime.
6. Uruchom dostępne compile checks i odpowiedni test w Roblox Studio.
7. Przy zmianie wydajnościowej porównaj zachowanie i koszt przed/po, gdy jest to możliwe.
8. Zaktualizuj bieżący miesięczny changelog w `docs/changelog/CHANGELOG_AI_YYYY-MM.md`.
9. Na końcu podaj:
   - zmienione pliki,
   - wykonane testy,
   - czego nie udało się zweryfikować,
   - ryzyka,
   - rollback.

Kod nie jest ukończony tylko dlatego, że się kompiluje. Musi mieć poprawnego właściciela, kontrolowany koszt runtime i możliwą ścieżkę utrzymania.

## Skills

- `the-dungeon-2-workflow`: workflow dla kodu, debugowania, synchronizacji i testów. Plik: `C:\Users\Sadocha\.codex\skills\the-dungeon-2-workflow\SKILL.md`
