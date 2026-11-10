# Sefirah – vlastní mody (fork sgrolik-base/Sefirah)

Tento fork je moje vlastní aplikace postavená na [shrimqy/Sefirah](https://github.com/shrimqy/Sefirah).
Každá vlastní funkce je **mod** = jeden commit na `master` od `mods/BASE`. Záložní kopie každého
modu je patch v `mods/patches/`. Po vydání nového Sefirah se mody znovu nasadí jedním kliknutím
(skript je přehraje na novou verzi přes `git rebase`).

- **Základ (upstream commit):** viz `mods/BASE` (nyní `6db524a`, Sefirah 3.2.0).
- **Změny dělat vždy jako PR** do tohoto forku (větev `feat/...` → `master`), nikdy rovnou na master.

## Jedním kliknutím

| Soubor | Co udělá |
|---|---|
| `mods/Update-From-Upstream.cmd` | Stáhne nejnovější oficiální Sefirah, vypíše co se tam změnilo a které soubory kolidují s mody, vytvoří větev `update/upstream-<sha>` a nasadí na ni všechny mody. Master nemění. Při konfliktu zastaví a řekne, který mod. |
| `mods/Build-Install.cmd` | Sestaví aktuální větev (Release x64) a nainstaluje ji místo běžícího Sefirah (sideload, zachová párování a data, sám zvedne číslo verze). |
| `mods/export-mods.ps1` | Po merge nového modu obnoví záložní patche v `mods/patches/`. |

### Postup, když vyjde nový Sefirah

1. Dvojklik `mods/Update-From-Upstream.cmd`. Vypíše mody, novinky v upstreamu a soubory, které mění obojí (tam hrozí konflikt).
2. Konflikt? Skript zastaví u konkrétního modu. Otevři ho v tabulce níže, oprav soubory, `git add …`, `git rebase --continue`.
3. Na konci skript sám zapíše nový `mods/BASE`.
4. Dvojklik `mods/Build-Install.cmd` a projdi **Test** u každého modu.
5. Pushni větev `update/upstream-<sha>` a otevři PR na `master`. Po merge spusť `mods/export-mods.ps1` (nové záložní patche) a dej to jako PR.

Mody se nasazují **v pořadí 0001 → 0006** (pořadí commitů). Pozdější mody stavějí na dřívějších (hlavně `CallsPage.xaml(.cs)` a `CallsPageViewModel.cs`), takže je nevynechávej jednotlivě. Chování se vypíná v **Nastavení → General**, ne odebráním patche.

## Seznam modů

### 0001 – Pole pro číslo v dialeru + čištění formátu
- **Co:** editovatelné pole nad avatarem v dialeru. Vložení `+420 (739) 017 476`, `+420   739017 476` a podobných zápisů se vyčistí na `+420739017476` (číslice, `*`, `#`, `+` jen na začátku, zahodí `(0)`). Čistí se i před vytočením a u čísla z vyhledávání kontaktů.
- **Soubory:** `Utils/PhoneNumberUtils.cs` (`CleanDialInput`), `Views/CallsPage.xaml(.cs)`, `ViewModels/CallsPageViewModel.cs`.
- **Upstream místa, kde hledat při konfliktu:** blok dialeru ve `CallsPage.xaml` (TextBlocky s `ViewModel.PhoneNumber`), `Window_KeyDown` v `CallsPage.xaml.cs`, `DialAsync` ve VM.
- **Test:** vlož `+420 (739) 017 476` → v poli `+420739017476`.

### 0002 – Odkazy tel: a sms:
- **Co:** Sefirah se registruje jako obsluha `tel:` a `sms:`. Odkaz předvyplní dialer nebo nový SMS koncept (příjemci + `body=`), přepne obrazovku i v úzkém okně, funguje i při studeném startu. `sefirah://` (scrcpy) zůstává beze změny.
- **Soubory:** `Utils/ExternalLinkParser.cs` (nový), `App.xaml.cs` (`HandleProtocolActivationArgs`, `TryApplyPendingExternalLink`), `Package.appxmanifest` (protokoly `tel`, `sms`), `Views/MainPage.xaml.cs`, `Views/CallsPage.xaml.cs`, `Views/MessagesPage.xaml.cs`, `ViewModels/CallsPageViewModel.cs`, `ViewModels/MessagesViewModel.cs`. Navíc oprava pádu `OnPhoneNumberChanged` bez aktivního zařízení.
- **Po instalaci jednou ručně:** Nastavení Windows → Výchozí aplikace → Sefirah → TEL a SMS.
- **Test:** Win+R `sms:+420…?body=Ahoj%20%C5%A0t%C4%9Bp%C3%A1ne` → Zprávy, příjemce + „Ahoj Štěpáne“.

### 0003 – Úvodní obrazovka, okamžité vytočení tel:, nápověda pole
- **Co:** Nastavení → General → **Start screen** (Last used / Calls – dialer / Calls – history / Messages / Apps) a přepínač **Dial phone links immediately** (výchozí ON; při studeném startu čeká až 60 s na Bluetooth linku a vytočí jen nezměněné číslo).
- **Soubory:** `Data/Enums/Preferences.cs` (`StartScreen`), `Data/Contracts/IGeneralSettingsService.cs`, `Services/Settings/GeneralSettingsService.cs`, `ViewModels/Settings/GeneralViewModel.cs`, `Views/Settings/GeneralPage.xaml`, `Views/MainPage.xaml.cs` (`MainNavigationView_Loaded`), `ViewModels/CallsPageViewModel.cs` (`PrepareExternalDial`, `TryRunPendingAutoDial`), `App.xaml.cs`.
- **Test:** Start screen = Calls – dialer → zavřít a otevřít Sefirah → dialer.

### 0004 – Kontakty v dialeru
- **Co:** klik na avatar otevře prohledávatelný seznam všech kontaktů z telefonu. Pole čísla je AutoSuggestBox: jméno nebo část čísla v libovolném formátu nabídne kontakty.
- **Soubory:** `Data/AppDatabase/Repository/ContactRepository.cs` (`GetAllContacts`, hledání podle číslic), `ViewModels/CallsPageViewModel.cs`, `Views/CallsPage.xaml(.cs)`.
- **Test:** klik na avatar → seznam; napiš jméno → návrhy.

### 0005 – Barevné stavy hovorů, export historie, rychlý výběr kontaktu
- **Co:** v historii ikona telefonu + šipka (↗ odchozí, ↙ příchozí) a barva podle výsledku: zelená = spojeno (délka > 0), červená = nespojeno / zmeškáno / odmítnuto, jantarová = hlasová schránka, šedá = blokováno. Export do `Documents\Sefirah\call-log.json` a `.csv` (outcome, connected, délka, číslo, kontakt) 2 s po změně. Pole: nápověda „Num or search“, Enter/Tab vezme zvýrazněný nebo první kontakt, šipky vyberou kontakt.
- **Soubory:** `Data/Models/CallLog.cs` (`Outcome`, `IsConnected`, `CallOutcome`), `Helpers/CallStatusHelper.cs` (nový), `Utils/CallLogExporter.cs` (nový), `ViewModels/CallsPageViewModel.cs` (`ScheduleCallLogExport`), `Views/CallsPage.xaml(.cs)`.
- **Test:** historie barevně; `Documents\Sefirah\call-log.json` obsahuje `connected_calls`.

### 0006 – Vypínač exportu, vycentrovaná nápověda
- **Co:** Nastavení → General → **Export call history** (výchozí ON). Nápověda „Num or search“ je vlastní vycentrovaný popisek (vestavěný placeholder AutoSuggestBoxu ignoruje centrování).
- **Soubory:** settings (jako 0003), `ViewModels/CallsPageViewModel.cs`, `Views/CallsPage.xaml(.cs)`.
- **Test:** vypnout export → soubory se přestanou aktualizovat.

## Připravené, zatím neimplementované

- **Auto-ukládání volaných lidí do Google Contacts** (HubSpot / Lusha / Apollo přes nové Chrome rozšíření, skupina „base.com klienti“). Specifikace: `Claude Done Work\Automatizace a Nastroje\2026-11-10 Sefirah Dialer Paste\SPEC-Sefirah-auto-contacts.md`. Dělat jako samostatný PR `feat/auto-contacts`, po merge přidat jako mod 0007.

## Build a instalace (co dělá Build-Install.cmd)

- .NET 10 SDK per-user v `%LOCALAPPDATA%\Microsoft\dotnet` (bez admina).
- `mrmsupport.dll` z NuGet balíčku `microsoft.windows.sdk.buildtools` (Windows SDK není potřeba).
- Výstup se kopíruje do `C:\Users\s.grolik\Apps\Sefirah` a registruje přes `Add-AppxPackage -Register` (Developer Mode musí být zapnutý). Identita zůstává `shrimqy.Seki-PhoneLink`, takže párování a data zůstanou. Windows nepřeinstaluje stejnou verzi, proto skript zvedá poslední číslo verze v kopii manifestu.
- Návrat na oficiální verzi: `Get-AppxPackage shrimqy.Seki-PhoneLink | Remove-AppxPackage`, pak Sefirah z Microsoft Store (párování se ztratí).
