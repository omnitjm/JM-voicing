# JM Voicing

En minimal Mac voice-dictation menu bar app inspireret af [VoiceInk](https://github.com/Beingpax/VoiceInk).

**Hvad gør den?**
1. Du holder **Fn / Globus**-tasten nede.
2. App'en optager mens du taler.
3. Du slipper tasten.
4. macOS' indbyggede Speech Recognition omdanner tale til tekst (auto-detekterer dansk eller engelsk).
5. Claude (Opus 4.7) retter grammatik og tilpasser teksten til **din tone**.
6. Den polerede tekst indsættes præcis der hvor markøren står - i Slack, Mail, Notes, Cursor, hvor som helst.

Ingen UI-vinduer i vejen, kun et menubar-ikon (`mic`) der ændrer sig under brug. **Kun én API key** (Anthropic) - resten kører gratis on-device.

---

## Krav

- macOS 13.0 eller nyere
- Xcode 15+
- En **Anthropic API key** fra https://console.anthropic.com (kræver et betalingsmiddel - er **ikke** inkluderet i Claude Pro eller Team subscription)

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

Første gang du holder Fn vil macOS bede om tilladelser. Du skal acceptere alle tre:

- **Microphone**: System Settings → Privacy & Security → Microphone → JM Voicing ✅
- **Speech Recognition**: System Settings → Privacy & Security → Speech Recognition → JM Voicing ✅
- **Accessibility**: System Settings → Privacy & Security → Accessibility → JM Voicing ✅
  (kræves for at lytte efter Fn og simulere ⌘V)

### 4. Slå macOS' indbyggede Fn-dictation FRA

Ellers stjæler systemet Fn-tasten:

- System Settings → **Keyboard** → **Dictation**: Off
- System Settings → **Keyboard** → **Press 🌐 key to**: **Do Nothing**

### 5. Tilføj din Anthropic API key

Klik på menubar-ikonet → **Indstillinger…** → indsæt din API key (`sk-ant-...`).
Den gemmes sikkert i macOS Keychain.

---

## Sådan bruger du den

1. Klik et tekstfelt et sted (Mail, Slack, browseren, et terminalvindue, hvor som helst).
2. **Hold Fn nede** mens du taler. Ikonet bliver fyldt mens du optager.
3. **Slip Fn**. Et lille `Pop` lyder når teksten er indsat.

Du behøver ikke skifte sprog. App'en kører dansk og engelsk recognition parallelt og vælger det resultat med højest confidence.

---

## Tilpas tonen

Det polerede output bruger en hardcoded prompt der beskriver din skrivestil. Den ligger i:

`JMVoicing/Tone/TonePrompt.swift`

Default-beskrivelsen er "uformel, direkte, korte sætninger, ingen pompøse ord". Rediger `voiceDescription`-strengen frit. Et godt trick: tilføj 2-3 eksempler på tekst du selv har skrevet. Claude kopierer stilen overraskende godt.

Du kan også slå grammatik-passet helt fra under **Indstillinger** → "Polér grammatik". Så bliver den rå transcription indsat direkte (ingen Claude-omkostning, ingen risiko for at modellen omformulerer).

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
  NativeSpeechService.swift # macOS SFSpeechRecognizer (da-DK + en-US, on-device)
  ClaudeService.swift       # POST /v1/messages (claude-opus-4-7)

Settings/
  SettingsStore.swift       # API key i Keychain, prefs i UserDefaults
  SettingsView.swift        # SwiftUI Settings-vindue

Tone/
  TonePrompt.swift          # Beskrivelse af din skrivestil (rediger her)
```

---

## Omkostninger

- **Transcription**: gratis (on-device via macOS Speech Recognition).
- **Claude polish (Opus 4.7)**: $5/M input tokens, $25/M output tokens. Med prompt-caching på system-prompten bliver gentagne dictations meget billige - typisk under $0.01 per dictation.

For en typisk bruger (10-20 dictations om dagen) bliver det få dollars om måneden.

Vil du spare endnu mere? Skift `model` i `ClaudeService.swift` fra `"claude-opus-4-7"` til `"claude-haiku-4-5"` (5x billigere, lidt mindre præcis) eller `"claude-sonnet-4-6"` (mellem).

---

## Fejlfinding

| Problem | Løsning |
|---|---|
| Fn-tasten gør ingenting | Slå macOS dictation fra (se step 4). Tjek Accessibility tilladelse. |
| "Manglende Anthropic API key" | Åbn Indstillinger og indsæt din key. |
| Tekst kommer ikke ind i feltet | Tjek Accessibility tilladelse. Klik først i tekstfeltet før du dikterer. |
| "Speech Recognition er ikke tilladt" | System Settings → Privacy & Security → Speech Recognition → JM Voicing |
| Forkert sprog detekteret | Sig sætningen lidt længere - korte sætninger kan tippe forkert. |
| Tonen er forkert | Rediger `voiceDescription` i `TonePrompt.swift`. |

---

## Hvad er IKKE inkluderet (men kan tilføjes senere)

- OpenAI Whisper-transcription (mere præcis end macOS' indbyggede, men koster og kræver ekstra API key)
- Lokal whisper.cpp (fuldt offline med Whisper-kvalitet)
- Historik over tidligere dictations
- Custom hotkey i Settings UI
- Auto-update via Sparkle

---

## Licens

Personligt projekt - brug det som du vil.
