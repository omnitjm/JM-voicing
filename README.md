# Gramchek

En personlig macOS menubar-app (Gramchek) der gør tre ting via globale genveje:

| Genvej | Funktion |
|---|---|
| **Hold Fn / 🌐** | **Diktér** - optager mens du holder tasten. Slip → polerede tekst indsættes ved markøren. Auto-detekterer dansk / engelsk. |
| **⌃1** | **Correct grammar** - marker tekst hvor som helst, tryk genvejen, rettet version erstatter den markerede. Ændrer KUN stavefejl og grammatik - ikke tone eller sprog. Virker på dansk og engelsk. |
| **⌃2** | **Improve** - marker tekst, tryk genvejen. Claude strammer formuleringen op uden at ændre mening, stil eller sprog. |
| **⌃3** | **AI-kommando** - marker tekst (eller intet), tryk genvejen. Vælg en preset-knap (Correct grammar / Improve clarity) eller skriv en kommando: *"svar høfligt nej…"*, *"oversæt til engelsk"*. |

Alt sker via samme Anthropic API key. Dictation kører transcription on-device gratis via macOS' indbyggede Speech Recognition.

---

## Installer (nem version)

1. Gå til **[Actions-fanen på GitHub](https://github.com/omnitjm/JM-voicing/actions)** og åbn det seneste grønne "Build .app"-run.
2. Scroll til "Artifacts" → klik **JMVoicing-app** → en `.zip` downloades.
3. Unzip → træk `JMVoicing.app` ind i `/Applications`.
4. Første gang du åbner den: **højre-klik på app'en → Open** (ikke dobbeltklik). macOS spørger om du er sikker - klik Open. Du skal kun gøre det denne ene gang.
5. App'en lever i menu baren - kig efter et lille mikrofon-ikon 🎤 øverst på skærmen.

---

## Installer (fra source - hvis du vil rette i koden)

```bash
brew install xcodegen
git clone https://github.com/omnitjm/JM-voicing.git
cd JM-voicing
git checkout claude/voice-dictation-mac-pcebx
xcodegen generate
open JMVoicing.xcodeproj
```

I Xcode: vælg dit Apple ID som signing team under **Signing & Capabilities**, tryk **⌘R**.

---

## Setup (5 minutter, første gang)

### 1. Anthropic API key

1. Gå til **https://console.anthropic.com**, log ind (eller opret konto - den er separat fra Claude.ai)
2. Billing → Add payment method → læg fx $5-10 ind
3. Settings → API keys → Create Key
4. Kopier nøglen (`sk-ant-...`)

### 2. Indsæt nøglen i Gramchek

Klik på mikrofon-ikonet i menu baren → **Indstillinger…** → indsæt nøglen. Den gemmes i Keychain.

### 3. Giv tilladelser

Når macOS spørger første gang, accepter:
- **Microphone** - til at høre dig diktere
- **Speech Recognition** - til on-device tale → tekst
- **Accessibility** - til at lytte efter Fn og indsætte tekst i andre apps

Hvis du ikke får prompts: åbn **System Settings → Privacy & Security** og tilføj Gramchek manuelt under hver kategori.

### 4. Slå macOS' indbyggede Fn-dictation FRA

Ellers stjæler systemet Fn-tasten:

- **System Settings → Keyboard → Dictation: Off**
- **System Settings → Keyboard → Press 🌐 key to: Do Nothing**

---

## Sådan bruger du de tre features

### 🎤 Diktér (Hold Fn)
1. Klik et tekstfelt i hvilken som helst app
2. **Hold Fn** mens du taler
3. Slip Fn - efter et par sekunder indsættes den polerede tekst

### ✓ Correct grammar (⌃1)
1. Marker et stykke tekst i fx Mail, Slack, Notes
2. Tryk **⌃1**
3. Den rettede version erstatter dit udvalg. Stavefejl og grammatik er rettet, men din tone, dit ordvalg og dit sprog er bevaret 1:1. Virker på både dansk og engelsk.

### ✨ Improve (⌃2)
1. Marker tekst hvor som helst
2. Tryk **⌃2**
3. Claude strammer formuleringen op (kortere, klarere) uden at ændre mening, stil eller sprog. Virker på dansk og engelsk.

### 🪄 AI-kommando (⌃3)
1. (Valgfrit) Marker tekst først - fx en mail du vil svare på
2. Tryk **⌃3** - en lille popup vises midt på skærmen
3. Vælg en preset-knap (**Correct grammar** / **Improve clarity**) **eller** skriv en kommando, fx:
   - *"svar høfligt nej med disse punkter: jeg er i ferie til 1. juni og kan først tage møder derefter"*
   - *"oversæt til engelsk"*
   - *"gør halvt så langt"*
   - *"skriv en kort takke-besked"*
4. Tryk **Enter** - resultatet indsættes ved markøren (eller erstatter dit udvalg)

---

## Tilpas din tone (kun dictation-polering)

Filen `JMVoicing/Tone/TonePrompt.swift` indeholder beskrivelsen af din skrivestil. Default er dansk uformel, men du kan redigere `voiceDescription` til hvad som helst - tilføj fx 2-3 eksempler på tekst du selv har skrevet, så kopierer Claude stilen.

Correct grammar (⌃1) bruger IKKE tone-prompten - den ændrer bevidst ikke din stil.

---

## Arkitektur

```
JMVoicingApp.swift                  # SwiftUI entry point
AppDelegate.swift                   # Menu bar + alle hotkeys
DictationCoordinator.swift          # Fn flow: optag → transcriber → polér → indsæt
SelectionActionCoordinator.swift    # ⌃⌥G & ⌃⌥A flows

Managers/
  HotkeyManager.swift               # Fn-listener via CGEventTap
  GlobalHotkey.swift                # ⌃⌥G og ⌃⌥A via Carbon RegisterEventHotKey
  AudioRecorder.swift               # AVAudioRecorder → m4a
  SelectionService.swift            # Læs markeret tekst via simuleret ⌘C
  TextInserter.swift                # Indsæt via pasteboard + simuleret ⌘V

Services/
  NativeSpeechService.swift         # SFSpeechRecognizer (da-DK + en-US parallelt)
  ClaudeService.swift               # Dictation polering (tone-tilpasset)
  GrammarCheckService.swift         # Streng grammatik-tjek (bevarer tone)
  InlineCommandService.swift        # AI-kommando med markeret tekst som kontekst

UI/
  CommandPaletteView.swift          # SwiftUI popup-UI
  CommandPaletteController.swift    # NSPanel-wrapper (floating, non-activating)

Settings/
  SettingsStore.swift               # API key i Keychain, prefs i UserDefaults
  SettingsView.swift                # SwiftUI Settings-vindue

Tone/
  TonePrompt.swift                  # Din skrivestil (kun til dictation)
```

Alle Claude-kald bruger `claude-opus-4-7` med `effort: "max"` for bedste kvalitet, prompt-caching på system-prompten for at minimere omkostninger ved gentagne kald.

---

## Omkostninger

- **Transcription**: gratis (on-device, kører på din Mac)
- **Claude Opus 4.7**: $5/M input, $25/M output. Med caching og max effort er typisk dictation ~$0.02-0.05, grammar-check ~$0.01, AI-kommando ~$0.05-0.20 afhængigt af længde.

Skift `model` i de tre service-filer fra `"claude-opus-4-7"` til `"claude-sonnet-4-6"` hvis du vil halvere prisen mod let lavere kvalitet, eller `"claude-haiku-4-5"` for 5x billigere.

---

## Fejlfinding

| Problem | Løsning |
|---|---|
| Fn gør ingenting | Step 4 ovenfor - slå macOS-dictation fra. Tjek Accessibility. |
| ⌃1 / ⌃2 / ⌃3 gør ingenting | Tjek Accessibility-tilladelse. Genvejen virker IKKE før app'en er startet. |
| "Marker først tekst" når jeg har markeret | Nogle apps tillader ikke ⌘C-via-script. Prøv et almindeligt tekstfelt. |
| "Manglende Anthropic API key" | Indstillinger → indsæt key |
| Forkert sprog detekteret i dictation | Tal længere ad gangen - korte sætninger er svære for sprog-detection. |
| macOS siger "kan ikke åbne fordi udvikler ikke kan verificeres" | Højre-klik → Open. Eller terminal: `xattr -dr com.apple.quarantine /Applications/JMVoicing.app` |

---

## Licens

Personligt projekt - brug det som du vil.
