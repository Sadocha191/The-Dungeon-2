# AI Work Queue

Wspólna kolejka pracy dla ChatGPT i Codexa. Ma ograniczać równoległe, kolidujące zmiany oraz dawać jedną krótką listę tego, co jest aktywne, zablokowane i gotowe do review.

## Statusy

- `IN_PROGRESS` — aktywnie realizowane; nie rozpoczynać drugiej implementacji w tym samym zakresie.
- `PAUSED` — zadanie rozpoczęte, ale chwilowo zatrzymane; zachować właściciela i checkpoint.
- `BLOCKED` — nie zaczynać implementacji do usunięcia blokera.
- `READY_FOR_REVIEW` — implementacja ukończona, oczekuje review/walidacji.
- `TODO` — gotowe do podjęcia, gdy nie koliduje z aktywną pracą.
- `DONE` — zakończone i zweryfikowane.

## Kolejka

| Priorytet | Status | Właściciel | Zadanie | Źródło / warunek |
|---|---|---|---|---|
| P0 | `PAUSED` | Codex | Dokończyć PR #164: lobby spells + NPC animation sanitizer + terrain-following Tornado | Wyczerpany limit Codexa. Checkpoint: `docs/CODEX_TASK_STATE.md`. |
| P1 | `BLOCKED` | Codex / ChatGPT review | Naprawić rozjazd `BlacksmithUI` z aktualnym drzewem `StarterGui.BlacksmithGui` | Nie ruszać do zakończenia bieżącego zadania Codexa; live audit wykazał m.in. `PassiveDesc` i `Stats` pod innymi parentami. |
| P1 | `BLOCKED` | Codex / ChatGPT review | Ujednolicić `Knight's Oath` vs `Knights Oath` | Najpierw pełny search referencji i ustalenie kanonicznego ID; nie usuwać wpisów w ciemno. |
| P2 | `BLOCKED` | Codex | Usunąć podwójny blok kodu w `ChatReSetup`, jeśli po wznowieniu audyt nadal to potwierdza | Przed zmianą ponownie odczytać aktywny skrypt ze Studio i repo. |
| P2 | `BLOCKED` | ChatGPT audit → Codex | Zweryfikować pusty `ServerScriptService.SpellService` i ewentualnie usunąć | Najpierw wyszukać wszystkie `FindFirstChild` / `WaitForChild` / direct references do `SpellService`. |
| P2 | `READY_FOR_REVIEW` | Codex / Studio validation | PR #162: preserve player momentum across modal UI pauses | Wymaga Studio checks opisanych w PR; nie mieszać z #164. |

## Reguły kolejkowania

1. Jednocześnie może istnieć kilka niezależnych PR, ale w jednym systemie nie powinny powstawać dwie równoległe implementacje tego samego problemu.
2. Przed rozpoczęciem nowego zadania Codex sprawdza ten plik i `docs/CODEX_TASK_STATE.md`.
3. Jeżeli istnieje `IN_PROGRESS` lub `PAUSED` w tym samym obszarze, Codex nie zaczyna nowej implementacji bez wyraźnej decyzji użytkownika.
4. ChatGPT może dodawać wyniki audytów jako `TODO`/`BLOCKED`, ale nie powinien zmieniać statusu aktywnego zadania Codexa na `DONE` bez potwierdzonych testów.
5. Po rozpoczęciu większego zadania jego pełny checkpoint trafia do `docs/CODEX_TASK_STATE.md`; ta kolejka pozostaje krótka.
6. Po merge/odrzuceniu PR zaktualizuj status odpowiedniej pozycji.

## Podział ról

**ChatGPT:** live audyt Roblox Studio, analiza architektury, planowanie, cross-check Studio ↔ repo, review PR/diff, przygotowanie precyzyjnego handoffu.

**Codex:** implementacja, refaktory, edycja repo/Studio zgodnie z zadaniem, testy, commity i PR, utrzymywanie checkpointu podczas dużego zadania.

**GitHub:** trwała warstwa komunikacji, historia decyzji, diffy, PR i checkpointy.

**Roblox Studio:** źródło prawdy dla aktywnych instancji i runtime, gdy jest rozjazd z repo, zgodnie z `AGENTS.md` i `docs/ROBLOX_REPO_SYNC.md`.
