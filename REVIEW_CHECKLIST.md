# REVIEW_CHECKLIST

Use this checklist before asking for a commit or marking work as done.

## Scope

- [ ] Zmiana rozwiazuje tylko uzgodniony problem.
- [ ] Nie ma nieplanowanego refactoru.
- [ ] Diff jest minimalny.

## Studio / repo parity

- [ ] Zmiana nie pogarsza parity Studio vs repo.
- [ ] Jesli dotykany path nie byl 1:1, zostalo to jawnie opisane.
- [ ] Studio pozostaje zrodlem prawdy.

## Path and naming safety

- [ ] Nie zmieniono nazw `RemoteEvent`, `RemoteFunction`, `ModuleScript`, folderow ani modeli bez planu.
- [ ] Nie zmieniono nazw krytycznych `Attribute`.
- [ ] Nie zmieniono `CollectionService` tags bez sprawdzenia wszystkich uzyc.
- [ ] Nie przeniesiono skryptow w Studio bez osobnego planu.

## Sensitive systems

- [ ] Sprawdzono wplyw na `Remotes`, `RemoteEvents`, `RemoteFunctions`, `ModuleScript`, `ModuleScripts`.
- [ ] Sprawdzono wplyw na `ServerStorage.WeaponTemplates`.
- [ ] Sprawdzono wplyw na `Workspace.NPCs`, `Portal`, `PortalModel`, `PortalTeleport`, `StarterCharacter.Animate`.
- [ ] Jesli dotyczy: sprawdzono `WaveController`, `ProgressService`, `NpcService`, `WeaponCombat`, `PortalUIController`, `InventoryController`, `TutorialService`, `PortalToDungeon`.

## Verification

- [ ] Podano sposob testu w Roblox Studio.
- [ ] Wypisano ryzyka.
- [ ] Wypisano rollback.
- [ ] Zaktualizowano `CHANGELOG_AI.md`.

## Communication

- [ ] W odpowiedzi wymieniono zmienione pliki.
- [ ] W odpowiedzi opisano, czego nie udalo sie sprawdzic, jesli cos zostalo niezweryfikowane.
