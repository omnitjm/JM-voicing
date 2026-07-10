# OmnitGram

Grammarly for din Mac - men med din egen LLM-nøgle og uden abonnement.

**Sådan virker den:** Markér tekst i en hvilken som helst app. Tryk en genvej. Den behandlede tekst erstatter automatisk det markerede.

| Genvej (kan ændres) | Handling |
|---|---|
| **⌃⌥G** | **Ret grammatik** - retter KUN stave- og grammatikfejl. Ændrer aldrig tone, ordvalg eller sprog. |
| **⌃⌥O** | **Optimér sproget** - retter fejl OG forbedrer flow og klarhed. Bevarer sprog, tone og alt indhold. |

Virker på **dansk og engelsk** (sproget detekteres automatisk - dansk forbliver dansk, engelsk forbliver engelsk). Du vælger selv LLM-udbyder: **Anthropic (Claude)** eller **OpenAI (GPT)** med din egen API-nøgle.

---

## Installér (2 minutter)

1. Gå til **[Actions-fanen](https://github.com/omnitjm/JM-voicing/actions)** → åbn det nyeste grønne ✅ "Build .app"-run
2. Scroll ned til **Artifacts** → klik **OmnitGram-app** → en zip downloades
3. Unzip → træk `OmnitGram.app` til **Applications**
4. **Højre-klik → Open** første gang (ad-hoc signeret app)
5. Find ✓-ikonet i menubaren

## Sæt op (3 minutter)

1. **API-nøgle**: Klik menubar-ikonet → **Indstillinger…** → vælg udbyder → indsæt nøgle
   - Anthropic: [console.anthropic.com](https://console.anthropic.com) → Billing (læg fx $5 ind) → API keys → Create Key
   - OpenAI: [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. **Accessibility-tilladelse**: macOS spørger første gang du bruger en genvej. Ellers: System Settings → Privacy & Security → Accessibility → tilføj OmnitGram.

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
