# Architektura i wydajność — The Dungeon 2

Ten dokument rozwija zasady z `AGENTS.md`. Czytaj go przed tworzeniem nowego systemu, refaktorem albo zmianą kodu działającego często.

## 1. Najpierw określ właściciela

Każdy stan i operacja powinny mieć jednego właściciela.

Przykładowe granice:

| Obszar | Właściciel |
|---|---|
| symulacja i stan NPC | `NpcService` |
| harmonogram encounterów | `WaveController` / wydzielony encounter service |
| obrażenia gracza | jeden `DamageService` |
| aktywne pociski | jeden `ProjectileService` |
| dropy na mapie | `DropService` |
| persistent rewards | reward/data service |
| UI konkretnego ekranu | kontroler tego ekranu |

Nie twórz dwóch niezależnych writerów tego samego stanu. Nie opieraj ownership na kolejności uruchamiania skryptów.

## 2. Jak rozpoznać God Script

Sam rozmiar nie jest błędem. Refaktor jest wskazany, gdy plik jednocześnie:

- ma wiele niezależnych odpowiedzialności,
- zawiera kilka osobnych pętli runtime,
- łączy konfigurację, gameplay, networking, persistent data i UI,
- udostępnia wiele globalnych hooków,
- jest zmieniany przy niemal każdym nowym feature,
- nie daje się testować bez uruchomienia całego runu.

Przed dopisaniem kodu do pliku powyżej 800 linii odpowiedz:

1. Czy ta funkcja należy do głównej odpowiedzialności pliku?
2. Czy ma własny stan i lifecycle?
3. Czy może być testowana lub wymieniana niezależnie?
4. Czy tworzy nową pętlę albo nowy typ obiektów runtime?

Jeżeli odpowiedzi wskazują na niezależny system, wydziel moduł/service zamiast rozbudowywać kontroler.

## 3. Rozsądny podział

Dziel po odpowiedzialności, a nie po liczbie linii.

Dobry podział:

- config: wyłącznie dane i tuning,
- service: stan i operacje domenowe,
- controller/bootstrap: podłączenie eventów i uruchomienie systemu,
- presentation: VFX/UI bez authority,
- adapter: integracja z istniejącym API/remotes.

Zły podział:

- jeden moduł na każdą funkcję,
- moduły, które tylko przekazują wywołanie dalej bez ownership,
- cykliczne zależności,
- serwis wymagający wielu ukrytych `_G`.

## 4. Pętle runtime

Przed dodaniem pętli zapisz:

| Pole | Pytanie |
|---|---|
| właściciel | Który service uruchamia i zatrzymuje pętlę? |
| częstotliwość | Dlaczego potrzebuje tylu aktualizacji na sekundę? |
| skala | Ile obiektów maksymalnie przetwarza? |
| koszt | Czy robi raycast, sortowanie, alokacje albo networking? |
| cleanup | Co zatrzymuje ją po końcu runu/usunięciu obiektu? |

Preferowane wzorce:

- jedna pętla dla wszystkich pocisków,
- jedna pętla dla wszystkich dropów,
- batch update NPC,
- accumulator pozwalający aktualizować różne podsystemy z różną częstotliwością,
- event-driven update, gdy stan zmienia się rzadko.

Unikaj:

- connection per pocisk/drop/NPC,
- pętli `while task.wait()` bez właściciela,
- pełnego `GetDescendants()` w częstej pętli,
- sortowania całej kolekcji w każdej klatce.

## 5. Alokacje i raycasty

W częstych ścieżkach:

- reużywaj `RaycastParams`, gdy filtr się nie zmienia,
- buduj listę ignorowanych instancji raz na batch, nie raz na próbę,
- nie twórz dużych tabel tymczasowych dla każdego obiektu,
- cache'uj graczy, root party i aktywne foldery,
- używaj limitów prób i budżetu raycastów,
- rozłóż ciężką pracę na kilka klatek, jeśli nie musi być natychmiastowa.

## 6. Wyszukiwanie celów

Koszt naiwny `pociski × NPC` szybko rośnie.

Przy dużej liczbie obiektów preferuj:

- spatial hash/grid,
- buckety przestrzenne,
- cache najbliższych celów,
- okresowe odświeżanie targetu,
- query z ograniczonym promieniem,
- wspólny `TargetService` zamiast skanowania w każdym spellu.

Zawsze oszacuj najgorszy przypadek. Przykład: 100 pocisków skanujących 500 NPC przy 60 Hz oznacza 3 000 000 porównań na sekundę przed dodatkowymi kosztami.

## 7. Networking

- Nie wysyłaj pełnego snapshotu całego świata częściej, niż jest to potrzebne.
- Rozważ delty, batching, priorytety odległości i niższą częstotliwość dla odległych obiektów.
- Nie wysyłaj klientowi danych, których nie używa do prezentacji.
- Serwer pozostaje właścicielem gameplay state; klient może interpolować presentation.
- Waliduj częstotliwość RemoteEventów z klienta.

## 8. Persistent data

- Nie zapisuj DataStore przy każdym killu, ticku lub pickupie.
- Aktualizuj stan pamięci, oznacz profil jako dirty i zapisuj zgodnie z kontrolowanym schedulerem.
- Grupuj rewardy i materiały, gdy ich liczba jest duża.
- Zachowaj idempotencję claimów i zabezpieczenie przed duplikacją.

## 9. UI

Duży kontroler UI też może być God Scriptem.

Rozdzielaj, gdy ekran zawiera niezależne domeny, np. inventory, spells, materials i codex. Wspólny shell może zarządzać otwieraniem i nawigacją, a osobne komponenty renderowaniem zakładek.

Nie twórz pętli renderowej do rzeczy, które mogą reagować na event lub zmianę atrybutu. Czyść connections po zamknięciu/odtworzeniu ekranu.

## 10. Bezpieczny refaktor dużego pliku

1. Zidentyfikuj publiczne API i ukryte zależności (`_G`, remotes, attributes, folder paths).
2. Dodaj testy/proby albo zapisz zachowanie do porównania.
3. Wydziel konfigurację bez zmiany działania.
4. Wydziel jeden system z własnym stanem i lifecycle.
5. Zostaw adapter w starym pliku, jeśli inne systemy oczekują starego API.
6. Wykonaj compile check i playtest.
7. Dopiero w kolejnym zadaniu zmieniaj algorytm lub częstotliwość.

## 11. Szablon planu dla Codexa

```text
Cel:

Obecne odpowiedzialności dotykanych plików:

Proponowany właściciel nowej logiki:

Pliki tworzone/zmieniane:

Publiczne API i zależności:

Pętle runtime:
- nazwa
- częstotliwość
- maksymalna liczba obiektów
- koszt jednej iteracji
- cleanup

Skala docelowa:

Plan implementacji etapami:

Walidacja:

Ryzyka i rollback:
```

## 12. Definition of Done

Zmiana jest gotowa, gdy:

- zachowanie wymagane przez zadanie działa,
- ownership jest jawny,
- nie powstał per-object update loop,
- koszt przy skali docelowej jest uzasadniony,
- connections i stan runtime są czyszczone,
- publiczne kontrakty zostały zachowane albo świadomie zmigrowane,
- wykonano test w odpowiednim place,
- opisano ryzyka i rollback.
