# The Dungeon 2

The Dungeon 2 to Roblox survivors action RPG złożony z połączonych place'ów: trwałego lobby, właściwego dungeonu/runu oraz osobnego miejsca gildii.

Gracz przygotowuje postać i ekwipunek w lobby, wchodzi do dungeonu, walczy automatycznymi atakami, zbiera materiały i nagrody, a następnie przenosi progres z powrotem do warstwy meta.

## Główne części projektu

- `Four Peaks/` — lobby, profile, inventory, crafting, misje, party, eventy i teleport do runu.
- `Level/` — combat, NPC, spelle, fale, bossy, dropy, chesty i zakończenie runu.
- `Guild/` — guild castle i systemy związane z gildią.
- `roblox/` — dodatkowy mirror/parity snapshot wybranych struktur Studio; nie zakładaj, że jest jedynym aktywnym źródłem kodu.
- `src/` i `default.project.json` — minimalny bootstrap Rojo, niepełny mirror gry.

Przy rozbieżności między repo a aktywnym Roblox Studio traktuj Studio jako źródło prawdy, dopóki konkretna ścieżka nie zostanie zweryfikowana.

## Dobre punkty wejścia

### Lobby

- `Four Peaks/ServerScriptService/Script/PortalToDungeon.lua`
- `Four Peaks/ServerScriptService/Script/InventoryService.lua`
- `Four Peaks/ServerScriptService/Script/BlacksmithService.lua`
- `Four Peaks/ServerScriptService/ModuleScript/CraftingService.lua`
- `Four Peaks/ServerScriptService/ModuleScript/PlayerData.lua`
- `Four Peaks/ServerScriptService/ModuleScript/PlayerStateStore.lua`

### Dungeon

- `Level/ServerScriptService/Script/RunReadyGate.server.lua`
- `Level/ServerScriptService/Script/ProgressService.lua`
- `Level/ServerScriptService/Script/Model/WaveController.lua`
- `Level/ServerScriptService/ModuleScript/NpcService.lua`
- `Level/ServerScriptService/Script/WeaponCombat.server.lua`
- `Level/ServerScriptService/Script/SpellService.lua`
- `Level/ServerScriptService/Script/DropService.lua`

### Guild

- `Guild/ServerScriptService/Script/GuildPlace.server.lua`
- `Guild/StarterPlayer/StarterPlayerScripts/LocalScript/GuildCastleClient.lua`

## Dokumentacja

- `AGENTS.md` — obowiązujące zasady pracy Codexa/AI.
- `docs/PROJECT_CODE_GUIDE.md` — mapa systemów, danych, remotes i przepływów.
- `docs/ARCHITECTURE_PERFORMANCE.md` — zasady projektowania i wydajności.
- `docs/ROBLOX_REPO_SYNC.md` — synchronizacja Roblox Studio z repo.
- `docs/REVIEW_CHECKLIST.md` — kontrola przed zakończeniem zadania.
- `docs/AUDYT_OPTYMALIZACJI_PROJEKTU.md` — audyt dużych skryptów i bottlenecków.
- `CHANGELOG_AI.md` — indeks historii zmian AI.

Dokumenty w `docs/archive/` są historyczne i nie stanowią aktualnych instrukcji operacyjnych.

## Workflow

1. Sprawdź właściwy place i aktywną instancję Roblox Studio.
2. Zweryfikuj aktywną ścieżkę skryptu oraz możliwe duplikaty.
3. Zrób wąski plan dla większych zmian.
4. Wprowadź najmniejszą bezpieczną zmianę.
5. Wykonaj compile check i test w Studio.
6. Zapisz zmianę w miesięcznym changelogu.

Szczegółowe zasady znajdują się w `AGENTS.md`.
