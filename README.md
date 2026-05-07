# JM Voicing

En minimal Mac voice-dictation menu bar app inspireret af [VoiceInk](https://github.com/Beingpax/VoiceInk).

**Hvad gør den?**
1. Du holder **Fn / Globus**-tasten nede.
2. App'en optager mens du taler.
3. Du slipper tasten.
4. Den sender lyd til OpenAI Whisper (auto-detekterer dansk eller engelsk).
5. GPT-4o-mini retter grammatik og tilpasser teksten til **din tone**.
6. Den polerede tekst indsættes præcis der hvor markøren står - i Slack, Mail, Notes, Cursor, hvor som helst.

Ingen UI-vinduer i vejen, kun et menubar-ikon (`mic`) der ændrer sig under brug.

---

## Krav

- macOS 13.0 eller nyere
- Xcode 15+
- En **OpenAI API key** (du laver én på https://platform.openai.com/api-keys - kræver et betalingsmiddel på din OpenAI konto, **ikke** ChatGPT Plus eller Claude Team)

---

## Setup (første gang)

### 1. Generér Xcode-projektet

App'en bruger [XcodeGen](https://github.com/yonaskolb/XcodeGen) til at undgå at vedligeholde `.xcodeproj` i git.

```bash
brew install xcodegen
cd path/to/JM-voicing
xcodegen generate
open JMVoicing.xcodeproj
```

### 2. Byg og kør

I Xcode: tryk `⌘R`. App'en lukker ikke et vindue op - kig i menu baren for et lille mikrofon-ikon.

### 3. Giv tilladelser

Første gang du holder Fn vil macOS bede om tilladelser. Du skal acceptere:

- **Microphone**: System Settings → Privacy & Security → Microphone → JM Voicing ✅
- **Accessibility**: System Settings → Privacy & Security → Accessibility → JM Voicing ✅
  (kræves for at lytte efter Fn og simulere ⌘V)

### 4. Slå macOS' indbyggede Fn-dictation FRA

Ellers stjæler systemet Fn-tasten:

- System Settings → **Keyboard** → **Dictation**: Off
- System Settings → **Keyboard** → **Press 🌐 key to**: **Do Nothing**

### 5. Tilføj din OpenAI API key

Klik på menubar-ikonet → **Indstillinger…** → indsæt din API key (`sk-...`).
Den gemmes sikkert i macOS Keychain.

---

## Sådan bruger du den

1. Klik et tekstfelt et sted (Mail, Slack, browseren, et terminalvindue, hvor som helst).
2. **Hold Fn nede** mens du taler. Ikonet bliver fyldt mens du optager.
3. **Slip Fn**. Et lille `Pop` lyder når teksten er indsat.

Du behøver ikke skifte sprog. Whisper auto-detekterer dansk/engelsk pr. session.

---

## Tilpas tonen

Det polerede output bruger en hardcoded prompt der beskriver din skrivestil. Den ligger i:

`JMVoicing/Tone/TonePrompt.swift`

Default-beskrivelsen er "uformel, direkte, korte sætninger, ingen pompøse ord". Rediger `voiceDescription`-strengen frit. Et godt trick: tilføj 2-3 eksempler på tekst du selv har skrevet. GPT-4o-mini kopierer stilen overraskende godt.

Du kan også slå grammatik-passet helt fra under **Indstillinger** → "Polér grammatik". Så bliver Whisper-output indsat direkte (ingen GPT-omkostning, ingen risiko for at modellen omformulerer).

---

## Arkitektur

```
JMVoicingApp.swift          # SwiftUI entry point
AppDelegate.swift           # Menu bar + status ikon
DictationCoordinator.swift  # State machine: idle → record → transcribe → polish → insert

Managers/
  HotkeyManager.swift       # CGEventTap der lytter på Fn-modifier
  AudioRecorder.swift       # AVAudioRecorder → m4a fil i tmp
  TextInserter.swift        # Pasteboard + simuleret ⌘V

Services/
  WhisperService.swift      # POST /v1/audio/transcriptions (auto-language)
  GrammarService.swift      # POST /v1/chat/completions (gpt-4o-mini)

Settings/
  SettingsStore.swift       # API key i Keychain, prefs i UserDefaults
  SettingsView.swift        # SwiftUI Settings-vindue

Tone/
  TonePrompt.swift          # Beskrivelse af din skrivestil (rediger her)
```

---

## Omkostninger (cirka, dec 2025)

- Whisper: $0.006 per minut lyd
- GPT-4o-mini polish: $0.15 per million input tokens, $0.60 per million output tokens
  → typisk under $0.001 per dictation

For en typisk bruger (10-20 dictations om dagen, ~30 sek hver) bliver det få dollars om måneden.

---

## Fejlfinding

| Problem | Løsning |
|---|---|
| Fn-tasten gør ingenting | Slå macOS dictation fra (se step 4). Tjek Accessibility tilladelse. |
| "Manglende OpenAI API key" | Åbn Indstillinger og indsæt din key. |
| Tekst kommer ikke ind i feltet | Tjek Accessibility tilladelse. Klik først i tekstfeltet før du dikterer. |
| Forkert sprog detekteret | Whisper-prompten i `WhisperService.swift` kan tunes - tilføj fx flere danske ord som hint. |
| Tonen er forkert | Rediger `voiceDescription` i `TonePrompt.swift`. |

---

## Hvad er IKKE inkluderet (men kan tilføjes senere)

- Lokal whisper.cpp (fuldt offline) - VoiceInk har det, vi sprang det over for MVP
- Historik over tidligere dictations
- Custom hotkey i Settings UI
- Auto-update via Sparkle
- Lyde / hapticer for start/slut feedback
- Brugerdefinerede AI-prompts ud over tone-passet

---

## Licens

Personligt projekt - brug det som du vil.
