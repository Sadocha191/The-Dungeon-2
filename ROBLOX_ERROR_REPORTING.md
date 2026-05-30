# ROBLOX_ERROR_REPORTING

## Cel

Ten projekt raportuje bledy Roblox dwoma kanalami:

- Discord webhook
- GitHub Issues przez zewnetrzny backend bridge endpoint

GitHub token nie moze byc trzymany w Robloxie. Roblox wysyla tylko payload HTTP do backendu. Backend trzyma token i robi create/update issue po `errorCode`.

## Gdzie ustawic URL-e

Edytuj oba pliki:

- `Level/ServerScriptService/Services/ErrorReporter.lua`
- `Four Peaks/ServerScriptService/Services/ErrorReporter.lua`

Podmien stale:

- `DISCORD_WEBHOOK_URL`
- `GITHUB_BRIDGE_URL`
- `GITHUB_BRIDGE_SECRET`

Domyslne placeholdery:

- `PASTE_YOUR_WEBHOOK_HERE`
- `PASTE_YOUR_GITHUB_BRIDGE_URL_HERE`
- `PASTE_YOUR_ROBLOX_ERROR_SECRET_HERE`

`GITHUB_BRIDGE_URL` nie jest sekretem. Sekretem pozostaje GitHub token i musi zostac po stronie backendu.
`GITHUB_BRIDGE_SECRET` jest wspolnym sekretem miedzy Roblox a backendem i musi byc taki sam jak backendowe `ROBLOX_ERROR_SECRET`.
Jesli URL nie konczy sie na `/roblox-error`, reporter dopnie ten suffix automatycznie i wypisze warning diagnostyczny.

## Jak dziala errorCode

`errorCode` ma format:

- `TD2-ERR-XXXXXXXX`

Kod jest budowany stabilnie z:

- `placeId`
- `scriptName`
- `lineNumber`
- oczyszczony `message`

Sanityzacja usuwa dynamiczne wartosci typu:

- `userId`
- `jobId`
- GUID-y
- timestampy
- liczby pozycji i inne stale zmieniajace sie liczby

To zmniejsza ryzyko, ze ten sam blad bedzie tworzyc wiele roznych issue.

## Antyspam

- cooldown per `errorCode`: `60s`
- serwer liczy lokalne `occurrenceCount`
- gdy blad powroci po cooldownie, nastepny raport dostaje zaktualizowany `occurrenceCount`

To ogranicza spam do Discorda i backendu, ale dalej zachowuje informacje ile razy blad pojawil sie w jednej sesji serwera.

## Payload do backendu

Przykladowy payload:

```json
{
  "source": "roblox",
  "game": "The Dungeon 2",
  "errorCode": "TD2-ERR-XXXXXXXX",
  "errorType": "ServerError",
  "placeId": 123456,
  "placeName": "Level",
  "jobId": "job-id",
  "serverTime": "2026-05-20T12:34:56Z",
  "firstSeen": "2026-05-20T12:34:56Z",
  "lastSeen": "2026-05-20T12:35:40Z",
  "scriptName": "SpellService",
  "scriptFullName": "ServerScriptService.Script.SpellService",
  "lineNumber": 316,
  "message": "attempt to index nil with 'Character'",
  "sanitizedMessage": "attempt to index nil with 'character'",
  "stackTrace": "ServerScriptService.Script.SpellService:316 ...",
  "occurrenceCount": 5,
  "player": {
    "userId": 123,
    "name": "PlayerName"
  },
  "context": {
    "system": "SpellService",
    "phase": "combat",
    "runMode": "Single",
    "level": "Level",
    "wave": "12",
    "extra": {
      "Environment": "Studio",
      "Location": "Run"
    }
  }
}
```

## Backend contract

Backend powinien:

1. Przyjac payload z Roblox.
2. Wyszukac issue po `errorCode`.
3. Jesli issue nie istnieje:
   - stworzyc nowe issue
4. Jesli issue istnieje:
   - zaktualizowac body albo dodac komentarz

Backend odrzuca request bez poprawnego naglowka:

- `X-Roblox-Error-Secret`

Sugerowany format issue:

Title:

```text
[TD2-ERR-XXXXXXXX] SpellService error in Level
```

Labels:

- `roblox-error`
- `auto-report`
- `place:level` albo `place:lobby`
- `system:SpellService`

Body powinno zawierac:

- Error code
- Place
- Script
- Line
- Message
- Stack trace
- First seen
- Last seen
- Occurrences
- Example player / userId
- JobId
- Context

## Gdzie sa hooki w Robloxie

### Wspolny reporter

- `Level/ServerScriptService/Services/ErrorReporter.lua`
- `Four Peaks/ServerScriptService/Services/ErrorReporter.lua`

### Kompatybilny wrapper

- `Level/ServerScriptService/Services/ErrorReportService.lua`
- `Four Peaks/ServerScriptService/Services/ErrorReportService.lua`

### Bootstrap serwera

- `Level/ServerScriptService/ErrorBootstrap.server.lua`
- `Four Peaks/ServerScriptService/ErrorBootstrap.server.lua`

### Reporter klienta

- `Level/StarterPlayer/StarterPlayerScripts/ClientErrorReporter.client.lua`
- `Four Peaks/StarterPlayer/StarterPlayerScripts/ClientErrorReporter.client.lua`

### Krytyczne callbacki z dodatkowymi oslonami

- `Level/ServerScriptService/Script/Model.model/WaveController.lua`
- `Level/ServerScriptService/Script/SpellService.lua`
- `Level/ServerScriptService/Script/WeaponCombat.server.lua`
- `Level/ServerScriptService/Script/ProgressService.lua`
- `Four Peaks/ServerScriptService/Script/BlacksmithService.lua`
- `Four Peaks/ServerScriptService/Script/MissionRemotes.lua`
- `Four Peaks/ServerScriptService/Script/PortalToDungeon.lua`

## Jak wlaczyc HttpService

W Roblox Studio:

1. `Home`
2. `Game Settings`
3. `Security`
4. wlacz `Allow HTTP Requests`

Jesli HTTP jest wylaczone, `ErrorReporter` wypisze czytelny warning w output.

## Gdzie wkleic secret po stronie Roblox

W obu plikach:

- `Level/ServerScriptService/Services/ErrorReporter.lua`
- `Four Peaks/ServerScriptService/Services/ErrorReporter.lua`

ustaw:

- `GITHUB_BRIDGE_SECRET = "twoj-shared-secret"`

Ten sam sekret ustaw w backend ENV:

- `ROBLOX_ERROR_SECRET`

## Jak testowac sztuczny blad

Uruchom serwer lub Play w odpowiednim place.

Po starcie serwera bootstrap powinien automatycznie wypisac:

```text
[ErrorBootstrap] _G.ErrorReporterTest exists: true
[ErrorBootstrap] PrintConfig result: githubEnabled=... urlConfigured=... secretConfigured=... discordEnabled=... githubReason=... discordReason=...
```

Nie polegaj na client Command Bar dla `_G.ErrorReporterTest`, bo client `_G` nie ma dostepu do serwerowego hooka.

Test serwera przez server-side hook:

```lua
_G.ErrorReporterTest.PrintConfig()
_G.ErrorReporterTest.TriggerServer("Test GitHub bridge error")
```

Test serwera przez chat command w Studio:

```text
;debug errorconfig
;debug errorreport Test GitHub bridge error
```

W `Level` dziala tez alias:

```text
;td errorconfig
;td errorreport Test GitHub bridge error
```

Test klienta z Server Command Bar:

```lua
_G.ErrorReporterTest.TriggerClient("PlayerName", "manual-client-test")
```

Legacy alias nadal dziala:

```lua
_G.ErrorWebhookTest.TriggerServer("legacy-test")
```

Jesli chcesz przetestowac stary tor nieobsluzonego runtime error przez `ScriptContext.Error`, uzyj:

```lua
_G.ErrorReporterTest.TriggerUnhandledServerError("runtime-test")
```

## Jakie logi powinny sie pojawic

Przy poprawnej konfiguracji i probie wysylki bridge powinienes zobaczyc w Output m.in.:

```text
[ErrorReporter] ReportServerError called
[ErrorReporter] ReportError called
[ErrorReporter] channel discord enabled true|false
[ErrorReporter] channel github enabled true|false
[ErrorReporter] GitHub bridge enabled: true
[ErrorReporter] GitHub bridge URL configured: true
[ErrorReporter] GitHub bridge secret configured: true
[ErrorReporter] Sending to GitHub bridge from ReportError
[ErrorReporter] Sending to GitHub bridge: https://.../roblox-error
[ErrorReporter] GitHub bridge response: success=true status=201 body={"ok":true,...}
[ErrorReporter] SendToGithubBridge completed: ok=true reason=Delivered status=201
[ManualServerTest] ReportServerError called
```

Przy request failure pojawi sie tez:

```text
[ErrorReporter] GitHub bridge failed: <blad z RequestAsync>
```

## Jak sprawdzic, czy raport dotarl do GitHub

1. Sprawdz Roblox Studio Output.
   - Brak warningu o `HttpService`
   - Brak warningu o `GITHUB_BRIDGE_URL`
   - Brak warningu o `GITHUB_BRIDGE_SECRET`
   - Jest log `Sending to GitHub bridge: .../roblox-error`
   - Jest log `GitHub bridge response: success=... status=... body=...`
2. Sprawdz logi backendu.
   - Roblox powinien trafic w endpoint HTTP `POST`
   - Backend powinien zwrocic `2xx`
3. Sprawdz GitHub Issues.
   - Nowy issue powinien miec tytul zaczynajacy sie od `[TD2-ERR-...]`
   - Jesli issue juz istnialo, powinno dostac update zamiast duplikatu
4. Powtorz ten sam blad po ponad `60s`.
   - issue powinno zostac zaktualizowane
   - `occurrenceCount` powinien wzrosnac

## Uwaga o dwoch place'ach

- `Four Peaks` = lobby / meta systems
- `Level` = dungeon / combat / run systems

Oba place maja wlasna kopie `ErrorReporter.lua`, wiec przy zmianie endpointu trzeba podmienic URL w obu lokalizacjach.
To samo dotyczy `GITHUB_BRIDGE_SECRET`.
