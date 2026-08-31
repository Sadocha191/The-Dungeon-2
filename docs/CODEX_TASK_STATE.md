# Codex Task State

Ten plik jest trwałym checkpointem bieżącego dużego zadania Codexa. Ma umożliwić wznowienie pracy po końcu limitu, zmianie sesji albo przekazaniu kontekstu między Codexem i ChatGPT.

## Zasady

- Codex aktualizuje ten plik po każdym istotnym etapie większego zadania.
- Przed zakończeniem sesji, końcem limitu albo świadomym przerwaniem pracy Codex musi zapisać checkpoint tutaj.
- Nie oznaczaj zadania jako `DONE`, jeżeli nie przeszło wymaganej walidacji.
- Jeżeli lokalna sesja Codexa zawiera zmiany niezsynchronizowane z GitHubem, zaznacz to jawnie. Nie zgaduj ich zawartości na podstawie PR.
- ChatGPT może używać tego pliku razem z GitHubem i live Roblox Studio do review, planowania i przygotowania następnego kroku, ale nie powinien nadpisywać aktywnej pracy Codexa bez wyraźnej potrzeby.
- Po zakończeniu zadania przenieś istotny rezultat do changelogu/PR, a ten plik przygotuj pod kolejne zadanie.

## Statusy

`PLANNED` → `IN_PROGRESS` → `PAUSED` / `BLOCKED` → `READY_FOR_REVIEW` → `DONE`

## Bieżące zadanie

**Status:** `PAUSED`

**Powód pauzy:** wyczerpany limit Codexa. Nie rozpoczynać równoległych zmian w tym samym zakresie do czasu wznowienia lub świadomego zamknięcia zadania.

**Ostatni stan zsynchronizowany z GitHubem:**
- PR: `#164` — `Fix lobby spells, NPC animation assets and terrain-following Tornado`
- Branch: `fix/lobby-documented-spells`
- Ostatni znany head PR: `5753cc192b9aec7307c0246b10712247f8335540`
- PR pozostaje otwarty.
- Mergeability trzeba ponownie sprawdzić przy wznowieniu, ponieważ `main` może zmienić się niezależnie od brancha Codexa.

**Ważne:** aktywna sesja Codexa może zawierać dodatkową pracę, której nie ma jeszcze na GitHubie. Przy wznowieniu Codex ma najpierw porównać `git status`, lokalny HEAD i PR, a dopiero potem zaktualizować ten checkpoint.

### Cel zsynchronizowany z PR

1. Ujednolicić lobby i dungeon pod aktualne `SpellDefinitions` oraz usunąć stary pre-run spell loadout.
2. Przenieść sanitizer assetów animacji NPC do aktywnych package templates dla `Level` i `Level2`.
3. Sprawić, aby authored Tornado VFX podążał po wysokości terenu i pozostawał zgodny z serwerowym hit zone.

### Stan według ostatniego PR

- Zmiany są zapisane na branchu i PR pozostaje otwarty.
- W PR opisano implementację lobby spells, NPC sanitizer oraz terrain-following Tornado.
- Nadal wymagane są testy w Roblox Studio wymienione niżej.
- Nie zakładać, że opis PR zawiera całą pracę z ostatniej sesji Codexa.

### Walidacja wymagana przed `DONE`

- `Four Peaks`: otworzyć Witch i Inventory; potwierdzić nowy roster spelli i brak starego loadout UI.
- `Level` i `Level2`: potwierdzić, że Bat/Cauldron/Stump/Ent_Fat nadal poprawnie animują się po sanitizerze.
- Sprawdzić logi `[NpcAssetSanitizer]` i brak usuwania runtime-required elementów rigów.
- Przetestować Tornado na zboczach, pagórkach, krawędziach i nierównym terenie; VFX ma pozostać zgrany z damage area.
- Przejrzeć finalny diff i sprawdzić, czy nie weszły niezwiązane zmiany.

### Dokładny następny krok po odzyskaniu limitu

1. Otworzyć istniejącą sesję/task Codexa.
2. Sprawdzić `git status`, aktualny branch i lokalny HEAD.
3. Porównać lokalny stan z PR `#164` oraz aktualnym `main`.
4. Uzupełnić sekcje `Completed`, `In progress`, `Still to do`, `Files changed`, `Studio changes`, `Tests` poniżej na podstawie faktycznej sesji, nie na podstawie domysłu.
5. Jeżeli branch wymaga aktualizacji względem `main`, wykonać ją bez utraty lokalnych zmian i ponownie sprawdzić diff.
6. Dokończyć zadanie i wykonać Studio checks.
7. Ustawić `READY_FOR_REVIEW`, dopiero gdy implementacja jest kompletna i testy są wykonane.

## Checkpoint roboczy Codexa

### Completed

- Do uzupełnienia przez aktywną sesję Codexa przy wznowieniu.

### In progress

- Do uzupełnienia przez aktywną sesję Codexa przy wznowieniu.

### Still to do

- Zweryfikować stan lokalnej sesji względem PR `#164` i aktualnego `main`.
- Wykonać wymagane testy Studio.
- Wykonać finalny review i synchronizację repo/Studio zgodnie z zakresem zadania.

### Files changed

- Źródłem prawdy do czasu wznowienia jest diff PR `#164`; lokalne niezapisane/niepushnięte zmiany są nieznane.

### Studio changes

- Niepotwierdzone w tym checkpointcie. Uzupełnić na podstawie aktywnej sesji i live Studio.

### Tests

- Wymagane testy Studio nie są jeszcze oznaczone jako zakończone.

### Known problems / blockers

- Limit Codexa.
- Możliwa różnica między stanem sesji lokalnej a ostatnim pushem do PR.
- `main` może być nowszy niż base brancha; sprawdzić mergeability/rebase przy wznowieniu.

### Exact next step

- Reconcile local Codex task state with PR `#164` and current `main`, then update this file before further implementation.
