---
name: the-dungeon-2-workflow
description: Profesjonalny workflow analizy, implementacji, debugowania, optymalizacji, synchronizacji i testowania kodu Roblox/Luau w projekcie The Dungeon 2.
---

# The Dungeon 2 — workflow programistyczny

## Cel

Pracuj jak developer utrzymujący długoterminowy projekt produkcyjny, a nie jak generator jednorazowych fragmentów kodu. Każda zmiana ma być zgodna z aktywną architekturą, bezpieczna po stronie klient–serwer, odporna na cykl życia Roblox, możliwa do rozwijania i sprawdzona w zakresie adekwatnym do ryzyka.

Kod nie jest ukończony tylko dlatego, że się kompiluje. Musi mieć poprawnego właściciela stanu, jawne zależności, kontrolowany koszt runtime, cleanup, testy regresji i uczciwie opisany zakres weryfikacji.

## 1. Start każdego zadania

1. Uruchom `mcp__roblox_mcp__list_roblox_studios`.
2. Jeżeli właściwa instancja jest dostępna, ustaw ją przez `mcp__roblox_mcp__set_active_studio`:
   - `Poziom` dla `Level/`,
   - `Cztery szczyty` dla `Four Peaks/`,
   - `Gildia` dla `Guild/`.
3. Jeżeli Studio lub MCP nie działa, napisz to krótko i kontynuuj na podstawie repo.
4. Sprawdź `git status` i nie nadpisuj niezwiązanych zmian użytkownika.
5. Przeczytaj `AGENTS.md` oraz ostatnie wpisy w `CHANGELOG_AI.md` i bieżącym pliku `docs/changelog/`.
6. Dobierz dokumentację do ryzyka zadania zamiast automatycznie czytać wszystko:
   - `docs/PROJECT_CODE_GUIDE.md` dla nieznanych systemów, danych, remotes i teleportu,
   - `docs/ROBLOX_REPO_SYNC.md` dla synchronizacji i rozbieżności Studio–repo,
   - `docs/ARCHITECTURE_PERFORMANCE.md` dla nowych systemów i kodu częstego,
   - `docs/AUDYT_OPTYMALIZACJI_PROJEKTU.md` dla wydajności,
   - `docs/REVIEW_CHECKLIST.md` przed zakończeniem większej zmiany.

## 2. Najpierw ustal właściwy kontekst

Przed napisaniem kodu ustal:

- czy zmiana dotyczy `Four Peaks`, `Level` czy `Guild`,
- czy kod ma działać na serwerze, kliencie czy w module współdzielonym,
- jaka jest dokładna aktywna ścieżka w Roblox Studio,
- który system jest właścicielem zmienianego stanu,
- jakie moduły, remotes, atrybuty, tagi, DataStore i UI zależą od tej funkcji,
- czy podobna funkcja już istnieje.

Nie zakładaj, że plik o podobnej nazwie w repo jest aktywny. Przy rozbieżności Studio jest źródłem prawdy, chyba że użytkownik wyraźnie postanowi inaczej.

Nie traktuj `src/` ani `default.project.json` jako pełnego źródła gry. Główne snapshoty znajdują się w `Four Peaks/`, `Level/` i ewentualnie `Guild/`.

## 3. Prześledź cały przepływ przed zmianą

Nie analizuj tylko jednego pliku. Ustal pełny przepływ:

1. Co uruchamia system.
2. Który skrypt odbiera żądanie lub event.
3. Jakie moduły są wywoływane.
4. Gdzie wykonywana jest walidacja.
5. Gdzie znajduje się właściciel stanu.
6. Gdzie stan jest zmieniany.
7. Jak wynik trafia do klienta lub kolejnego systemu.
8. Jak i kiedy dane są zapisywane.
9. Jak system kończy działanie i sprząta zasoby.

Wyszukaj wszystkie użycia:

- nazw funkcji i modułów,
- `RemoteEvent` i `RemoteFunction`,
- `BindableEvent` i `BindableFunction`,
- atrybutów,
- tagów `CollectionService`,
- pól konfiguracji,
- nazw DataStore i kluczy,
- pól `TeleportData`,
- publicznych callbacków,
- użyć `_G`.

Nie usuwaj ani nie zmieniaj legacy API bez potwierdzenia wszystkich użyć oraz aktywnej struktury Studio.

## 4. Plan przed większą implementacją

Przedstaw plan, gdy zadanie dotyczy co najmniej jednego z poniższych:

- nowego systemu gameplayowego,
- persistent data, remotes, teleportu lub wspólnego API,
- więcej niż dwóch istniejących systemów,
- dużego lub silnie sprzężonego pliku,
- nowej pętli `Heartbeat`, `Stepped`, `RenderStepped` lub cyklicznego taska,
- masowej obsługi NPC, pocisków, dropów, VFX lub graczy,
- zmiany mogącej przekroczyć około 300 linii.

Plan ma wskazywać:

1. odpowiedzialności i właściciela stanu,
2. pliki tworzone i zmieniane,
3. przepływ danych,
4. publiczne API, remotes i zależności,
5. wszystkie pętle runtime i ich częstotliwość,
6. koszt przy skali docelowej,
7. testy, ryzyka i rollback.

## 5. Najmniejsza poprawna zmiana

- Jedno zadanie powinno rozwiązywać jeden problem albo jedną wąską funkcję.
- Preferuj najmniejszy diff, który jest kompletny architektonicznie.
- Nie wykonuj pobocznych refaktorów.
- Nie zmieniaj balansu, nazw publicznych ani formatu danych bez potrzeby.
- Nie przepisuj całego systemu, jeżeli można bezpiecznie naprawić lub wydzielić odpowiedzialność etapami.
- Duży refaktor i zmiana zachowania powinny być osobnymi etapami.
- Najpierw zachowaj zachowanie 1:1, później optymalizuj albo zmieniaj gameplay.

## 6. Jeden właściciel stanu i odpowiedzialności

Nie twórz równoległego źródła prawdy.

Wykorzystuj istniejących właścicieli, między innymi:

- `PlayerData` i `PlayerStateStore` dla danych gracza,
- `CurrencyService` dla walut,
- `CraftingService` dla craftingu,
- `WeaponCatalog` i `WeaponConfigs` dla broni,
- `NpcService` dla stanu, obrażeń i lifecycle NPC,
- odpowiedni progress/reward service dla progresu runu i nagród.

Każdy system powinien mieć jednego właściciela dla damage, NPC simulation, projectiles, drops, rewards, inventory i save state.

Nie dodawaj nowych zależności przez `_G`. Używaj jawnych `ModuleScript` i `require()`. Nie nadpisuj globalnej funkcji, którą może definiować inny skrypt.

Każdy moduł powinien mieć jedną główną odpowiedzialność. Unikaj zarówno God Scriptów, jak i nadmiernej liczby mikromodułów.

## 7. Server authority i granica klient–serwer

Serwer jest ostatecznym źródłem prawdy dla:

- walut,
- damage,
- rewardów,
- inventory i ekwipunku,
- craftingu,
- progresu,
- wyników losowania,
- dostępu do systemów,
- stanu NPC i runu.

Klient może przekazać zamiar lub input, ale nie gotowy wynik.

Każde dane klienta waliduj warstwowo:

1. typ i kształt,
2. wartości skończone i dozwolony zakres,
3. istnienie identyfikatora w konfiguracji,
4. ownership i uprawnienia,
5. stan gracza i systemu,
6. dystans od obiektu, jeśli dotyczy,
7. cooldown i serwerowy rate limit,
8. ochronę przed duplikacją żądania.

Uwzględniaj `nil`, błędne typy, puste stringi, liczby ujemne, `math.huge`, `NaN`, nieistniejące ID, spam i gracza opuszczającego serwer w trakcie operacji.

Cooldown klienta jest tylko elementem UX. Prawdziwy cooldown i limit częstotliwości muszą działać na serwerze.

Waliduj również interakcje uruchamiane przez `ProximityPrompt`, `ClickDetector` i podobne obiekty. Nie zakładaj, że ich wywołanie automatycznie potwierdza dystans, stan albo uprawnienie.

Serwer nie może bez walidacji przekazywać danych jednego klienta do innych klientów.

## 8. Dobór remotes

- Preferuj `RemoteEvent` dla asynchronicznych żądań i powiadomień.
- Używaj `RemoteFunction` tylko wtedy, gdy nadawca naprawdę musi czekać na odpowiedź.
- Unikaj `InvokeClient()` w logice krytycznej, ponieważ klient może nie odpowiedzieć, rozłączyć się albo celowo blokować wywołanie.
- Używaj `UnreliableRemoteEvent` wyłącznie dla częstych danych wizualnych lub ciągłych, których utrata i zmiana kolejności nie psuje stanu gry.

`UnreliableRemoteEvent` może pasować do niekrytycznych pozycji VFX lub szybko zastępowanych danych prezentacyjnych. Nie używaj go dla damage, inventory, zakupów, rewardów, zapisów, wyników losowania ani trwałego stanu.

Nie wysyłaj pełnych snapshotów co klatkę. Preferuj:

- event po zmianie stanu,
- delta updates,
- batching,
- ograniczoną częstotliwość,
- lokalne tworzenie VFX po serwerowym ustaleniu wyniku.

## 9. Persistent data

Trzymaj aktywny stan gracza w pamięci serwera. DataStore służy do trwałego zapisu, a nie do obsługi każdej bieżącej zmiany XP, waluty lub materiału.

Każde wywołanie DataStore:

- wykonuj wyłącznie po stronie serwera,
- opakuj w `pcall`,
- obsłuż błąd bez udawania sukcesu,
- respektuj request budget i throttling,
- nie wykonuj w pętli klatkowej.

Przy konfliktach wielu serwerów preferuj `UpdateAsync()` zamiast prostego `SetAsync()`.

Callback `UpdateAsync()`:

- nie może yieldować,
- nie może wykonywać `task.wait()`,
- może zostać uruchomiony więcej niż raz,
- powinien być deterministyczny,
- nie powinien wywoływać innych operacji sieciowych ani efektów ubocznych.

Nie traktuj błędu zapisu jako gwarancji, że backend niczego nie zapisał. Operacje nagród i zakupów projektuj idempotentnie.

Dla inventory, walut, broni, zakupów i handlu stosuj session locking albo istniejący system profilowy zapewniający blokadę sesji.

Po nieudanym ładowaniu profilu nie zapisuj bezwarunkowo danych domyślnych. Mogłoby to nadpisać prawidłowy profil pustymi danymi.

Nie zmieniaj nazw DataStore, kluczy ani kształtu zapisanych danych bez:

- migracji,
- bezpiecznych wartości domyślnych,
- kompatybilności starych profili,
- planu rollbacku.

## 10. Idempotentne rewardy i transakcje

Każda operacja, która może zostać ponowiona, musi być bezpieczna przy wielokrotnym wykonaniu.

Dotyczy to szczególnie:

- developer products,
- daily rewards,
- event rewards,
- claimów misji,
- chestów,
- kończenia runu,
- teleportów i ich potwierdzeń.

Używaj unikalnego receipt ID, tokenu, transaction ID albo zapisanego statusu odebrania. Ponowione wywołanie nie może przyznać nagrody drugi raz.

## 11. Luau, typy i styl

Dla nowych modułów i kontrolowanych refaktorów preferuj:

```lua
--!strict
```

Wprowadzaj strict stopniowo. Nie przełączaj całego legacy projektu jedną zmianą bez planu.

Definiuj typy dla:

- publicznych argumentów i wyników,
- snapshotów,
- configów,
- danych zapisanych,
- payloadów remote,
- `TeleportData`.

Unikaj nadużywania `any`, ponieważ wyłącza ochronę typowania. Preferuj doprecyzowanie typu, walidację runtime albo `unknown` z późniejszym zawężeniem.

Zachowuj spójny styl i optymalizuj kod pod czytanie. Preferowana kolejność pliku:

1. `--!strict`,
2. services,
3. dependencies,
4. constants,
5. types,
6. module state,
7. private functions,
8. public functions,
9. initialization,
10. return.

Jawne `require()` trzymaj przy początku pliku. Komentarze mają wyjaśniać przyczynę, kontrakt lub ograniczenie, a nie powtarzać oczywistą linię kodu.

Używaj `task.wait`, `task.spawn`, `task.defer`, `task.delay` i `task.cancel` zamiast legacy `wait`, `spawn` i `delay`.

Nie używaj `task.spawn()` jako sposobu na ukrywanie błędów ani do tworzenia nieograniczonej liczby wątków.

## 12. Cykl życia Roblox i defensywność

Kod musi uwzględniać:

- `PlayerAdded`,
- `PlayerRemoving`,
- `BindToClose`,
- respawn postaci,
- brak `Character`, `Humanoid` lub `HumanoidRootPart`,
- usunięcie obiektu podczas callbacku,
- opóźnioną replikację i ładowanie assetów,
- klienta dołączającego później,
- ponowne otwarcie UI,
- koniec runu,
- teleport i rozłączenie.

Nie zakładaj, że obiekt zawsze istnieje. Na granicy replikacji stosuj `WaitForChild`, a tam, gdzie brak obiektu jest możliwy, używaj timeoutu i jawnej obsługi błędu.

Nie używaj nieskończonego `WaitForChild()` w miejscu, które może zablokować kluczowy system na zawsze.

## 13. StreamingEnabled

Przy `Workspace.StreamingEnabled` klient nie musi posiadać wszystkich obiektów `Workspace` w danym momencie. Obiekty mogą pojawić się później albo zostać odstreamowane.

Kod klienta powinien:

- reagować na pojawienie i usunięcie obiektu,
- nie przechowywać bezterminowo niezweryfikowanych referencji,
- nie zakładać kompletnego `Workspace`,
- stosować trwałe modele tylko tam, gdzie jest to naprawdę konieczne,
- rozróżniać brak obiektu od błędu systemu.

## 14. Connections, taski i cleanup

Każde dynamiczne połączenie, task i obiekt musi mieć właściciela oraz ścieżkę cleanupu.

Sprzątaj:

- `RBXScriptConnection`,
- bindy `RunService`,
- aktywne tweens,
- tymczasowe instancje,
- wpisy cooldownów,
- registry NPC, dropów i pocisków,
- cache referencji,
- tabele graczy,
- taski i pętle,
- callbacki tymczasowej sesji.

Sprawdź respawn, usuwanie obiektu, koniec runu i ponowne otwieranie UI pod kątem duplikowania connections.

Długowieczne registry muszą usuwać martwe rekordy. Rosnące `LuaHeap`, `InstanceCount` albo pamięć konkretnego skryptu traktuj jako sygnał wycieku.

## 15. Wydajność: najpierw pomiar

Nie optymalizuj na podstawie domysłów. Najpierw ustal rzeczywiste wąskie gardło za pomocą:

- MicroProfilera,
- Script Profilera,
- Developer Console,
- pamięci i Luau heap snapshots,
- statystyk sieciowych,
- Performance Dashboard dla opublikowanej gry.

Rozdziel diagnozę na:

- CPU klienta,
- CPU serwera,
- GPU,
- fizykę,
- pamięć,
- sieć,
- czas ładowania.

Przy zmianie wydajnościowej porównaj scenariusz przed i po. Liczy się nie tylko średni FPS, ale także stabilność frame time i piki.

## 16. Pętle i skala

Nie twórz osobnego `Heartbeat`, `Stepped` lub `RenderStepped` dla każdego NPC, pocisku, dropu ani efektu.

Używaj centralnego schedulera lub service dla obiektów tego samego typu.

Nie wykonuj bez uzasadnienia co klatkę:

- `Players:GetPlayers()`,
- `GetChildren()` i `GetDescendants()`,
- pełnego wyszukiwania najbliższego celu,
- sortowania wszystkich NPC,
- tworzenia `RaycastParams` i dużych tabel tymczasowych,
- głębokiego kopiowania i serializacji,
- formatowania logów,
- wysyłania pełnych snapshotów,
- zapisu DataStore.

Cache'uj dane, które nie muszą być odświeżane co klatkę. Rozdziel częstotliwości pracy. Orientacyjnie:

- krytyczna fizyka: `Heartbeat`, tylko gdy konieczne,
- AI i steering: około 5–15 Hz,
- target search: okresowo, po zmianie stanu albo przez shared target service,
- HUD i niekrytyczna synchronizacja: około 4–10 Hz,
- save i persistent rewards: buforowane i wykonywane zbiorczo.

Każda nowa częsta pętla musi mieć:

- uzasadnienie,
- częstotliwość,
- maksymalną liczbę obsługiwanych obiektów,
- koszt przy docelowej skali,
- warunek zatrzymania,
- cleanup.

Projektuj systemy masowe co najmniej pod orientacyjną skalę projektu: 100–500 NPC, około 100 pocisków, około 300 dropów i kilku graczy, jeśli dany system może osiągnąć takie wartości.

Przy wyszukiwaniu celów rozważ spatial partitioning, grid, query cache albo wspólny target service.

Pooling rozważ dla często tworzonych i niszczonych NPC, pocisków, pickupów, damage indicators i VFX, ale wdrażaj go dopiero, gdy pomiar pokazuje koszt tworzenia, niszczenia albo garbage collectora.

## 17. Replikacja i prezentacja

Serwer ustala wynik gameplayowy. Klient może prezentować wynik lokalnie.

Przykładowy podział:

- serwer: cel, trafienie, damage, reward, stan NPC,
- klient: VFX, dźwięk, camera shake, część animacji i UI.

Nie replikuj dużej liczby instancji tylko po to, aby pokazać krótkotrwały efekt. Gdy jest to bezpieczne, wyślij mały payload i utwórz efekt lokalnie.

Batchuj częste aktualizacje i wysyłaj tylko zmiany wymagane przez klienta.

## 18. Bezpieczeństwo zewnętrznych assetów

Każdy model, plugin i skrypt pochodzący spoza projektu sprawdź przed użyciem.

Szukaj:

- ukrytych `Script` i `LocalScript`,
- `require(assetId)`,
- obfuskowanego kodu,
- `loadstring`,
- nieuzasadnionego dostępu do sieci, DataStore lub asset require,
- warunków aktywowanych przez konkretnego gracza,
- backdoorów administracyjnych.

Nie ufaj assetowi wyłącznie dlatego, że jest popularny. Gdy dostępne i właściwe, stosuj sandboxing oraz minimalne capabilities.

Nie umieszczaj sekretów ani logiki wymagającej poufności w `ReplicatedStorage`, `LocalScript` ani replikowanym `ModuleScript`. Klient może odczytać i zdekompilować replikowany kod i dane.

## 19. Sprawdzenie kodu przed oddaniem

Przed zakończeniem sprawdź:

- składnię Luau,
- type errors w dotkniętych plikach,
- poprawność nazw usług i API,
- poprawność ścieżek instancji,
- właściwą stronę klient–serwer,
- brakujące i cykliczne `require`,
- możliwe `nil`,
- `WaitForChild` i streaming,
- race conditions,
- server authority i exploity remote,
- kompatybilność danych,
- cleanup connections, tasków i registry,
- koszt runtime i sieci,
- regresje systemów zależnych.

Nie zgaduj zachowania API Roblox. Przy niepewności sprawdź aktualną oficjalną dokumentację Roblox Creator Hub albo Luau. DevForum i cudze implementacje traktuj jako materiał pomocniczy, nie jako nadrzędne źródło prawdy.

## 20. Minimalny zakres testów

Test poprawnego przypadku nie wystarcza. Dobierz testy do systemu i sprawdź między innymi:

- prawidłową akcję,
- błędne argumenty remote,
- spamowanie i duplikaty,
- brak wymaganych zasobów,
- respawn,
- wyjście gracza podczas operacji,
- dwóch graczy działających jednocześnie,
- późne dołączenie klienta,
- ponowne otwarcie UI,
- koniec runu,
- zapis i ponowne wejście.

Dla systemów sieciowych użyj rzeczywistego modelu klient–serwer:

- Test z przełączaniem Client/Server,
- `Server & Clients`,
- co najmniej dwóch klientów dla multiplayera,
- Network Simulation dla opóźnień i gorszych warunków.

Dla UI i sterowania sprawdź Device Emulator oraz realne proporcje mobilne. Emulator nie zastępuje testu pamięci na prawdziwym słabszym urządzeniu.

Dla tego projektu szczególnie sprawdzaj pełny cykl:

`Four Peaks → teleport → Level → run → zapis/reward → powrót do Four Peaks`.

Zmiany broni sprawdzaj przez inventory, equip, blacksmith, zapis, `TeleportData`, loadout w Level, combat i powrót.

Zmiany misji sprawdzaj przez update w runie, zapis, powrót, snapshot w lobby i claim.

Zmiany wydajnościowe testuj w najcięższym realistycznym momencie runu, a nie wyłącznie zaraz po starcie.

## 21. Synchronizacja Studio–repo

Przed zmianą potwierdź aktywną ścieżkę w Studio i sprawdź repo pod kątem duplikatów.

Nie przenoś ani nie usuwaj obiektów bez osobnego planu. Nie poprawiaj automatycznie wszystkich historycznych kopii. Najpierw ustal, która ścieżka jest aktywna, a które są mirrorami albo stale snapshotami.

Po zmianie zsynchronizuj właściwy aktywny obiekt Studio, jeżeli MCP jest dostępne i zadanie tego wymaga.

## 22. Format przekazywania kodu użytkownikowi

Gdy użytkownik prosi o cały skrypt, przekaż kompletny plik gotowy do wklejenia, a nie urwany fragment.

Podaj:

- dokładną ścieżkę,
- typ: `Script`, `LocalScript` albo `ModuleScript`,
- czy kod zastępuje cały plik,
- wymagane remotes, foldery, atrybuty i assety.

Na końcu podaj:

- zmienione pliki,
- co dokładnie zmieniono,
- wykonane testy,
- czego nie udało się zweryfikować,
- oczekiwane logi lub zachowanie w Studio,
- ryzyka,
- rollback.

Nie twierdź, że kod na pewno działa, jeżeli nie został uruchomiony w odpowiednim playteście. Rozróżniaj analizę statyczną, testy automatyczne i potwierdzony test w Roblox Studio.

## 23. Definicja ukończenia

Zadanie jest ukończone dopiero, gdy:

- dotyczy właściwego place'a i aktywnej ścieżki,
- jest zgodne z istniejącą architekturą,
- ma jednego właściciela stanu,
- nie tworzy drugiego systemu ani nowej zależności `_G`,
- zachowuje kontrakty remotes, `TeleportData` i persistent data albo posiada migrację,
- waliduje dane klienta i posiada rate limit, gdy jest potrzebny,
- obsługuje błędy i cykl życia,
- posiada cleanup,
- ma kontrolowany koszt runtime i replikacji,
- przeszło dostępne sprawdzenie składni i typów,
- przeszło testy adekwatne do ryzyka,
- zostało sprawdzone pod kątem regresji,
- zaktualizowano bieżący changelog,
- raport końcowy uczciwie oddziela rzeczy potwierdzone od niezweryfikowanych.

## Oficjalne źródła praktyk

Przy aktualizacji tego workflow preferuj aktualne źródła pierwotne:

- Roblox Creator Hub: client–server runtime i securing the client–server boundary,
- Roblox Creator Hub: RemoteEvents, RemoteFunctions i UnreliableRemoteEvents,
- Roblox Creator Hub: Data stores, limity i best practices,
- Roblox Creator Hub: Performance optimization, MicroProfiler, Script Profiler i memory usage,
- Roblox Creator Hub: Instance streaming i Studio testing modes,
- Roblox Creator Hub: task scheduler i third-party asset vulnerabilities,
- Luau documentation: types i strict mode,
- Roblox Lua Style Guide.
