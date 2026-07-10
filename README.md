# OmnitGram

Grammarly til **Mac og Windows** - men med din egen LLM-nøgle og uden abonnement.

**Sådan virker den:** Markér tekst i en hvilken som helst app. Tryk en genvej. Den behandlede tekst erstatter automatisk det markerede.

| Genvej (kan ændres i Indstillinger) | Handling |
|---|---|
| Mac **⌃⌥G** / Windows **Ctrl+Alt+G** | **Ret grammatik** - retter KUN stave- og grammatikfejl. Ændrer aldrig tone, ordvalg eller sprog. |
| Mac **⌃⌥O** / Windows **Ctrl+Alt+O** | **Optimér sproget** - retter fejl OG forbedrer flow og klarhed. Bevarer sprog, tone og alt indhold. |

Virker på **dansk og engelsk** (sproget detekteres automatisk - dansk forbliver dansk, engelsk forbliver engelsk). Du vælger selv LLM-udbyder: **Anthropic (Claude)** eller **OpenAI (GPT)** med din egen API-nøgle.

---

## Installér på Mac (2 minutter)

1. Gå til **[Actions-fanen](https://github.com/omnitjm/JM-voicing/actions)** → åbn det nyeste grønne ✅ "Build apps"-run
2. Scroll ned til **Artifacts** → klik **OmnitGram-mac** → en zip downloades
3. Unzip → træk `OmnitGram.app` til **Applications**
4. **Højre-klik → Open** første gang (ad-hoc signeret app)
5. Find ✓-ikonet i menubaren

## Installér på Windows (2 minutter)

1. Samme Actions-run → **Artifacts** → klik **OmnitGram-windows**
2. Unzip → læg `OmnitGram.exe` hvor du vil (fx i Dokumenter)
3. Dobbeltklik. Windows SmartScreen advarer første gang → klik **More info → Run anyway**
4. Find det grønne G-ikon i system tray (nederst til højre)
5. Vil du have den til at starte med Windows: læg en genvej i `shell:startup`-mappen (Win+R → skriv `shell:startup`)

## Sæt op (3 minutter, begge platforme)

1. **API-nøgle**: Klik tray/menubar-ikonet → **Indstillinger…** → vælg udbyder → indsæt nøgle
   - Anthropic: [console.anthropic.com](https://console.anthropic.com) → Billing (læg fx $5 ind) → API keys → Create Key
   - OpenAI: [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. **Kun Mac - Accessibility-tilladelse**: macOS spørger første gang du bruger en genvej. Ellers: System Settings → Privacy & Security → Accessibility → tilføj OmnitGram.
3. **Genveje**: Kan omprogrammeres frit i Indstillinger på begge platforme - klik/Optag og tryk den nye kombination.

## Brug

1. Skriv noget i Mail, Slack, Notion, browseren - hvor som helst
2. **Markér teksten**
3. Tryk **⌃⌥G** (ret grammatik) eller **⌃⌥O** (optimér sproget)
4. Vent 1-2 sekunder → det markerede erstattes af den behandlede version
5. Hører du bare et "Tink" var teksten allerede korrekt - intet blev ændret

Begge handlinger kan også køres fra menubar-menuen, og genvejene kan ændres frit i Indstillinger (klik på genvejs-chippen og tryk en ny kombination).

---

## Byg selv fra source

```bash
brew install xcodegen
git clone https://github.com/omnitjm/JM-voicing.git
cd JM-voicing
git checkout claude/voice-dictation-mac-pcebx
xcodegen generate
open OmnitGram.xcodeproj   # vælg dit Apple ID under Signing, tryk ⌘R
```

## Arkitektur

**Mac** (Swift/AppKit, `OmnitGram/`):

```
OmnitGramApp.swift               # SwiftUI entry point
AppDelegate.swift                # Menubar, hotkey-registrering, settings-observation
SelectionActionCoordinator.swift # Flow: læs markering → LLM → erstat

Managers/
  GlobalHotkey.swift             # Carbon RegisterEventHotKey (globale genveje)
  SelectionService.swift         # Læs markeret tekst (gem/⌘C/gendan pasteboard)
  TextInserter.swift             # Indsæt resultat (pasteboard + simuleret ⌘V)

Services/
  LLMService.swift               # Provider-abstraktion: Anthropic + OpenAI, 2 modes

Settings/
  SettingsStore.swift            # Nøgler i Keychain (én pr. udbyder), prefs i UserDefaults
  SettingsView.swift             # Udbyder, nøgle, model, genveje
  ShortcutSpec.swift             # Genvejs-model (Codable)
  ShortcutRecorderView.swift     # "Tryk taster…"-recorder
```

**Windows** (Python, `windows/omnitgram.py` - bygges til standalone `OmnitGram.exe` med PyInstaller):

- System tray-ikon (pystray) med de samme to handlinger + Indstillinger
- Globale genveje via `keyboard`-biblioteket, omprogrammerbare i Indstillinger (Optag-knap)
- Samme clipboard-flow: gem → Ctrl+C → LLM → Ctrl+V → gendan
- API-nøgle i Windows Credential Manager (keyring), config i `%APPDATA%/OmnitGram/`

## Omkostninger

Du betaler kun for det du bruger via din egen API-nøgle. En typisk rettelse af et afsnit koster under 1 øre med Claude Opus / GPT-4o - og endnu mindre med billigere modeller (skift model i Indstillinger, fx `claude-haiku-4-5` eller `gpt-4o-mini`).

## Fejlfinding

| Problem | Løsning |
|---|---|
| Genvejen gør ingenting | Accessibility-tilladelse mangler. System Settings → Privacy & Security → Accessibility → OmnitGram. |
| "Marker først den tekst…" | Nogle felter tillader ikke programmatisk kopiering. Prøv et almindeligt tekstfelt. |
| "Manglende API-nøgle" | Indstillinger → indsæt nøgle for den valgte udbyder. |
| Fejl 401 | Nøglen er forkert eller udløbet - lav en ny. |
| Fejl 402/403 | Læg penge på kontoen hos udbyderen. |
| macOS: "kan ikke åbnes…" | Højre-klik → Open. Eller: `xattr -dr com.apple.quarantine /Applications/OmnitGram.app` |
