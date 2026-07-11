"""
OmnitGram til Windows.

Grammarly-style tekstbehandling på markeret tekst i en hvilken som helst app:
  1. Ret grammatik  (default Ctrl+Alt+G)  - kun fejl, aldrig omskrivning
  2. Optimér sprog  (default Ctrl+Alt+O)  - fejl + flow, samme sprog og tone

Flow: gem clipboard -> simuler Ctrl+C -> send til LLM -> sæt resultat på
clipboard -> simuler Ctrl+V -> gendan clipboard.

Kører som system tray-app. Indstillinger (udbyder, API-nøgle, model, genveje)
i et lille vindue - genveje optages ved at trykke kombinationen.

Config: %APPDATA%/OmnitGram/config.json (API-nøgle i Windows Credential
Manager via keyring; falder tilbage til config-filen hvis keyring fejler).
"""

import json
import os
import sys
import threading
import time
import tkinter as tk
from tkinter import ttk

import keyboard   # globale hotkeys + simulerede tastetryk
import pyperclip  # clipboard
import requests

try:
    import keyring
    KEYRING_OK = True
except Exception:
    KEYRING_OK = False

try:
    import winsound
    def beep_ok():
        winsound.MessageBeep(winsound.MB_OK)
    def beep_err():
        winsound.MessageBeep(winsound.MB_ICONHAND)
except Exception:
    def beep_ok():
        pass
    def beep_err():
        pass

APP_NAME = "OmnitGram"
CONFIG_DIR = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), APP_NAME)
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.json")

PROVIDERS = {
    "anthropic": {
        "display": "Anthropic (Claude)",
        "default_model": "claude-opus-4-7",
        "key_hint": "sk-ant-...  (console.anthropic.com)",
    },
    "openai": {
        "display": "OpenAI (GPT)",
        "default_model": "gpt-4o",
        "key_hint": "sk-...  (platform.openai.com/api-keys)",
    },
}

DEFAULT_CONFIG = {
    "provider": "anthropic",
    "model": "",  # tom = brug udbyderens default
    "hotkey_grammar": "ctrl+alt+g",
    "hotkey_improve": "ctrl+alt+o",
    "show_preview": True,  # vis diff og kræv accept før indsættelse
    "api_key_fallback": "",  # kun brugt hvis keyring ikke virker
}

GRAMMAR_PROMPT = """You are a strict grammar and spelling checker.
The text may be Danish or English - detect the language and NEVER translate;
Danish stays Danish, English stays English.

Correct ONLY: spelling mistakes, grammar errors, punctuation, obvious typos.

ABSOLUTE RULES:
1. DO NOT rephrase, restructure, or rewrite sentences.
2. DO NOT change tone, style, register, or word choice.
3. DO NOT add, remove, or summarize content.
4. If the text is already correct, return it EXACTLY as-is.
5. Preserve all line breaks and whitespace exactly.

Output ONLY the corrected text - no preamble, no explanation, no markdown, no quotes."""

IMPROVE_PROMPT = """You are a language improvement assistant.
The text may be Danish or English - detect the language and NEVER translate;
Danish stays Danish, English stays English.

Improve the text so it reads clearly and naturally:
- Fix all spelling, grammar, and punctuation errors
- Smooth out awkward phrasing and improve flow
- Tighten wordy sentences

RULES:
1. Keep the writer's tone and register - formal stays formal, casual stays casual.
2. Keep ALL meaning and content. Do not add or drop points.
3. Do not make it sound AI-generated - no filler phrases, keep it human.
4. Preserve paragraph structure.

Output ONLY the improved text - no preamble, no explanation, no markdown, no quotes."""


# ---------------------------------------------------------------- config

def load_config() -> dict:
    cfg = dict(DEFAULT_CONFIG)
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            cfg.update(json.load(f))
    except Exception:
        pass
    return cfg


def save_config(cfg: dict) -> None:
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)


def get_api_key(cfg: dict) -> str:
    if KEYRING_OK:
        try:
            key = keyring.get_password(APP_NAME, cfg["provider"])
            if key:
                return key
        except Exception:
            pass
    return cfg.get("api_key_fallback", "")


def set_api_key(cfg: dict, value: str) -> None:
    value = value.strip()
    if KEYRING_OK:
        try:
            keyring.set_password(APP_NAME, cfg["provider"], value)
            cfg["api_key_fallback"] = ""
            return
        except Exception:
            pass
    cfg["api_key_fallback"] = value


# ---------------------------------------------------------------- LLM

def call_llm(cfg: dict, system_prompt: str, text: str) -> str:
    provider = cfg["provider"]
    api_key = get_api_key(cfg)
    if not api_key:
        raise RuntimeError("Manglende API-nøgle. Åbn Indstillinger fra tray-ikonet.")

    model = cfg.get("model", "").strip() or PROVIDERS[provider]["default_model"]

    if provider == "anthropic":
        resp = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": model,
                "max_tokens": 8192,
                "system": [{"type": "text", "text": system_prompt,
                            "cache_control": {"type": "ephemeral"}}],
                "messages": [{"role": "user", "content": text}],
            },
            timeout=90,
        )
        if resp.status_code != 200:
            raise RuntimeError(f"Anthropic-fejl ({resp.status_code}): {resp.text[:300]}")
        body = resp.json()
        if body.get("stop_reason") == "max_tokens":
            raise RuntimeError("Teksten er for lang - markér en mindre del ad gangen. Intet blev ændret.")
        blocks = body.get("content", [])
        out = next((b.get("text", "") for b in blocks if b.get("type") == "text"), "")
    else:
        resp = requests.post(
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "content-type": "application/json",
            },
            json={
                "model": model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": text},
                ],
            },
            timeout=90,
        )
        if resp.status_code != 200:
            raise RuntimeError(f"OpenAI-fejl ({resp.status_code}): {resp.text[:300]}")
        choices = resp.json().get("choices", [])
        if choices and choices[0].get("finish_reason") == "length":
            raise RuntimeError("Teksten er for lang - markér en mindre del ad gangen. Intet blev ændret.")
        out = choices[0]["message"]["content"] if choices else ""

    out = out.strip()
    return out if out else text


# ---------------------------------------------------------------- selection

def tokenize_words(text: str) -> list[str]:
    """Split i ord-tokens; whitespace kollapses, linjeskift bevares som '\\n'."""
    tokens: list[str] = []
    current = ""
    for ch in text:
        if ch == "\n":
            if current:
                tokens.append(current)
                current = ""
            tokens.append("\n")
        elif ch.isspace():
            if current:
                tokens.append(current)
                current = ""
        else:
            current += ch
    if current:
        tokens.append(current)
    return tokens


def diff_words(original: str, corrected: str) -> list[tuple[str, str]]:
    """Ord-niveau diff. Returnerer [(op, tekst), ...] hvor op er
    'equal', 'delete' eller 'insert'. Ren funktion - unit-testes."""
    import difflib

    a = tokenize_words(original)
    b = tokenize_words(corrected)
    out: list[tuple[str, str]] = []
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(a=a, b=b, autojunk=False).get_opcodes():
        if op == "equal":
            out.append(("equal", " ".join(b[j1:j2])))
        elif op == "delete":
            out.append(("delete", " ".join(a[i1:i2])))
        elif op == "insert":
            out.append(("insert", " ".join(b[j1:j2])))
        else:  # replace
            out.append(("delete", " ".join(a[i1:i2])))
            out.append(("insert", " ".join(b[j1:j2])))
    return out


def get_foreground_window() -> int | None:
    """HWND for det aktive vindue (målappen) - bruges til at gendanne fokus
    efter preview-vinduet, så Ctrl+V lander det rigtige sted."""
    try:
        import ctypes
        return ctypes.windll.user32.GetForegroundWindow()
    except Exception:
        return None


def restore_foreground(hwnd: int | None) -> None:
    if not hwnd:
        return
    try:
        import ctypes
        ctypes.windll.user32.SetForegroundWindow(hwnd)
    except Exception:
        pass


def release_modifiers() -> None:
    """Send key-up for evt. fysisk holdte modifiers, så vores simulerede
    Ctrl+C ikke bliver til fx Ctrl+Alt+C mens brugeren stadig holder genvejen."""
    for mod in ("ctrl", "alt", "shift", "windows"):
        try:
            keyboard.release(mod)
        except Exception:
            pass


def read_selection() -> str | None:
    """Gem clipboard, simuler Ctrl+C, læs, gendan. None hvis intet markeret."""
    try:
        saved = pyperclip.paste()
    except Exception:
        saved = ""

    sentinel = "\x00__omnitgram__\x00"
    try:
        pyperclip.copy(sentinel)
    except Exception:
        pass

    time.sleep(0.15)  # lad brugeren nå at slippe hotkey'en
    release_modifiers()
    keyboard.send("ctrl+c")

    text = None
    for _ in range(20):  # op til ~1 sekund
        time.sleep(0.05)
        try:
            current = pyperclip.paste()
        except Exception:
            continue
        if current != sentinel:
            text = current
            break

    try:
        pyperclip.copy(saved)
    except Exception:
        pass

    if text is None:
        return None
    text = text.strip()
    return text or None


def paste_text(text: str) -> None:
    """Sæt tekst på clipboard, simuler Ctrl+V, gendan gammelt clipboard."""
    try:
        saved = pyperclip.paste()
    except Exception:
        saved = ""

    pyperclip.copy(text)
    time.sleep(0.1)
    release_modifiers()
    keyboard.send("ctrl+v")

    def restore():
        time.sleep(0.5)
        try:
            pyperclip.copy(saved)
        except Exception:
            pass
    threading.Thread(target=restore, daemon=True).start()


# ---------------------------------------------------------------- app

class OmnitGramApp:
    def __init__(self):
        self.cfg = load_config()
        self.busy = False
        self.registered = []

        # Skjult tk-root: bruges til settings-vindue og tråd-sikre callbacks.
        self.root = tk.Tk()
        self.root.withdraw()
        self.root.title(APP_NAME)

        self.register_hotkeys()
        self.start_tray()

        # Første-gangs-hjælp: vis hvordan appen bruges, og guide til API-nøgle.
        def first_run_hint():
            time.sleep(2)
            if not get_api_key(self.cfg):
                self.notify("Velkommen! Højreklik ikonet → Indstillinger og indsæt din API-nøgle.")
            else:
                self.notify(f"Klar. Markér tekst og tryk {self.cfg['hotkey_grammar']} (ret grammatik) "
                            f"eller {self.cfg['hotkey_improve']} (optimér sprog).")
        threading.Thread(target=first_run_hint, daemon=True).start()

    # ------------------------------------------------------------ hotkeys

    def register_hotkeys(self):
        for h in self.registered:
            try:
                keyboard.remove_hotkey(h)
            except Exception:
                pass
        self.registered = []

        for combo, prompt in [
            (self.cfg["hotkey_grammar"], GRAMMAR_PROMPT),
            (self.cfg["hotkey_improve"], IMPROVE_PROMPT),
        ]:
            combo = (combo or "").strip()
            if not combo:
                continue
            try:
                handle = keyboard.add_hotkey(
                    combo,
                    lambda p=prompt: threading.Thread(
                        target=self.run_action, args=(p,), daemon=True).start(),
                    suppress=False,
                )
                self.registered.append(handle)
            except Exception as e:
                print(f"Kunne ikke registrere '{combo}': {e}")

    def run_action(self, system_prompt: str):
        if self.busy:
            return
        self.busy = True
        release_busy = True
        try:
            target_hwnd = get_foreground_window()
            text = read_selection()
            if not text:
                self.notify("Marker først den tekst du vil have behandlet.")
                beep_err()
                return

            result = call_llm(self.cfg, system_prompt, text)
            if result == text:
                beep_ok()  # allerede korrekt - rør ikke teksten
                return

            if self.cfg.get("show_preview", True):
                # Preview-vinduet overtager ansvaret for busy-flaget.
                release_busy = False
                self.root.after(0, lambda: self._show_preview(text, result, target_hwnd))
            else:
                paste_text(result)
                beep_ok()
        except Exception as e:
            self.notify(str(e))
            beep_err()
        finally:
            if release_busy:
                self.busy = False

    # ------------------------------------------------------------ preview

    def _show_preview(self, original: str, result: str, target_hwnd: int | None):
        """Vis diff og kræv accept (Enter) før indsættelse. Kører på tk-tråden."""
        win = tk.Toplevel(self.root)
        win.title(f"{APP_NAME} - forhåndsvisning")
        win.attributes("-topmost", True)
        win.geometry("620x380")

        header = ttk.Frame(win)
        header.pack(fill="x", padx=12, pady=(10, 4))
        ttk.Label(header, text="Ændringer:", font=("Segoe UI", 10, "bold")).pack(side="left")
        ttk.Label(header, text="rød = fjernes · grøn = tilføjes",
                  foreground="gray").pack(side="right")

        body = tk.Text(win, wrap="word", font=("Segoe UI", 11),
                       padx=10, pady=8, relief="flat")
        body.pack(fill="both", expand=True, padx=12, pady=4)
        body.tag_configure("delete", foreground="#c0392b",
                           font=("Segoe UI", 11, "overstrike"))
        body.tag_configure("insert", foreground="#1e8449",
                           font=("Segoe UI", 11, "bold"))

        first = True
        for op, chunk in diff_words(original, result):
            if not chunk:
                continue
            if not first and chunk != "\n":
                body.insert("end", " ")
            if op == "equal":
                body.insert("end", chunk)
            elif op == "delete":
                body.insert("end", chunk, "delete")
            else:
                body.insert("end", chunk, "insert")
            first = False
        body.configure(state="disabled")

        def finish(accepted: bool):
            try:
                win.destroy()
            except Exception:
                pass
            if accepted:
                def do_paste():
                    restore_foreground(target_hwnd)
                    time.sleep(0.3)
                    paste_text(result)
                    beep_ok()
                    self.busy = False
                threading.Thread(target=do_paste, daemon=True).start()
            else:
                self.busy = False

        btns = ttk.Frame(win)
        btns.pack(fill="x", padx=12, pady=(4, 10))
        ttk.Label(btns, text="Enter = indsæt · Esc = annullér",
                  foreground="gray").pack(side="left")
        ttk.Button(btns, text="Indsæt", command=lambda: finish(True)).pack(side="right", padx=(8, 0))
        ttk.Button(btns, text="Annullér", command=lambda: finish(False)).pack(side="right")

        win.bind("<Return>", lambda e: finish(True))
        win.bind("<Escape>", lambda e: finish(False))
        win.protocol("WM_DELETE_WINDOW", lambda: finish(False))
        win.focus_force()

    # ------------------------------------------------------------ tray

    def start_tray(self):
        import pystray
        from PIL import Image, ImageDraw

        # Simpelt genereret ikon: grønt "G" på transparent baggrund.
        img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.ellipse([4, 4, 60, 60], fill=(46, 160, 67, 255))
        d.text((22, 14), "G", fill=(255, 255, 255, 255))

        menu = pystray.Menu(
            pystray.MenuItem(
                "Ret grammatik på markeret tekst",
                lambda: threading.Thread(target=self.run_action,
                                         args=(GRAMMAR_PROMPT,), daemon=True).start()),
            pystray.MenuItem(
                "Optimér sproget på markeret tekst",
                lambda: threading.Thread(target=self.run_action,
                                         args=(IMPROVE_PROMPT,), daemon=True).start()),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Indstillinger…", self.open_settings),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Afslut", self.quit),
        )
        self.tray = pystray.Icon(APP_NAME, img, APP_NAME, menu)
        threading.Thread(target=self.tray.run, daemon=True).start()

    def notify(self, message: str):
        try:
            self.tray.notify(message, APP_NAME)
        except Exception:
            print(message)

    def quit(self):
        try:
            self.tray.stop()
        except Exception:
            pass
        self.root.after(0, self.root.destroy)

    # ------------------------------------------------------------ settings UI

    def open_settings(self):
        self.root.after(0, self._open_settings_window)

    def _open_settings_window(self):
        win = tk.Toplevel(self.root)
        win.title(f"{APP_NAME} - Indstillinger")
        win.geometry("480x470")
        win.resizable(False, False)
        win.attributes("-topmost", True)

        pad = {"padx": 12, "pady": 4}

        # --- Udbyder ---
        ttk.Label(win, text="AI-udbyder", font=("Segoe UI", 10, "bold")).pack(anchor="w", **pad)
        provider_var = tk.StringVar(value=self.cfg["provider"])
        prov_frame = ttk.Frame(win)
        prov_frame.pack(anchor="w", **pad)
        for key, meta in PROVIDERS.items():
            ttk.Radiobutton(prov_frame, text=meta["display"], value=key,
                            variable=provider_var).pack(side="left", padx=(0, 16))

        # --- API-nøgle ---
        ttk.Label(win, text="API-nøgle", font=("Segoe UI", 10, "bold")).pack(anchor="w", **pad)
        key_var = tk.StringVar(value=get_api_key(self.cfg))
        key_entry = ttk.Entry(win, textvariable=key_var, show="•", width=52)
        key_entry.pack(anchor="w", **pad)
        key_hint = ttk.Label(win, text=PROVIDERS[self.cfg["provider"]]["key_hint"],
                             foreground="gray")
        key_hint.pack(anchor="w", padx=12)

        def on_provider_change(*_):
            key_hint.config(text=PROVIDERS[provider_var.get()]["key_hint"])
            # Vis den gemte nøgle for den nye udbyder
            tmp = dict(self.cfg)
            tmp["provider"] = provider_var.get()
            key_var.set(get_api_key(tmp))
            model_var.set(self.cfg.get("model", "") if provider_var.get() == self.cfg["provider"] else "")
        provider_var.trace_add("write", on_provider_change)

        # --- Model ---
        ttk.Label(win, text="Model (tom = standard)", font=("Segoe UI", 10, "bold")).pack(anchor="w", **pad)
        model_var = tk.StringVar(value=self.cfg.get("model", ""))
        ttk.Entry(win, textvariable=model_var, width=32).pack(anchor="w", **pad)

        # --- Genveje ---
        ttk.Label(win, text="Genveje (klik Optag og tryk kombinationen)",
                  font=("Segoe UI", 10, "bold")).pack(anchor="w", **pad)

        def hotkey_row(label_text, initial):
            frame = ttk.Frame(win)
            frame.pack(anchor="w", fill="x", **pad)
            ttk.Label(frame, text=label_text, width=16).pack(side="left")
            var = tk.StringVar(value=initial)
            entry = ttk.Entry(frame, textvariable=var, width=20)
            entry.pack(side="left", padx=(0, 8))

            def record():
                var.set("tryk taster…")
                def worker():
                    try:
                        combo = keyboard.read_hotkey(suppress=False)
                        self.root.after(0, lambda: var.set(combo))
                    except Exception:
                        self.root.after(0, lambda: var.set(initial))
                threading.Thread(target=worker, daemon=True).start()

            ttk.Button(frame, text="Optag", command=record).pack(side="left")
            return var

        grammar_var = hotkey_row("Ret grammatik", self.cfg["hotkey_grammar"])
        improve_var = hotkey_row("Optimér sprog", self.cfg["hotkey_improve"])

        # --- Preview ---
        preview_var = tk.BooleanVar(value=self.cfg.get("show_preview", True))
        ttk.Checkbutton(win, text="Vis ændringer før de indsættes (Enter = indsæt, Esc = annullér)",
                        variable=preview_var).pack(anchor="w", **pad)

        # --- Gem ---
        def save():
            self.cfg["provider"] = provider_var.get()
            self.cfg["model"] = model_var.get().strip()
            self.cfg["hotkey_grammar"] = grammar_var.get().strip()
            self.cfg["hotkey_improve"] = improve_var.get().strip()
            self.cfg["show_preview"] = bool(preview_var.get())
            set_api_key(self.cfg, key_var.get())
            save_config(self.cfg)
            self.register_hotkeys()
            win.destroy()

        btn_frame = ttk.Frame(win)
        btn_frame.pack(pady=16)
        ttk.Button(btn_frame, text="Gem", command=save).pack(side="left", padx=8)
        ttk.Button(btn_frame, text="Annullér", command=win.destroy).pack(side="left")

        note = ("Sådan bruges appen: markér tekst hvor som helst, tryk genvejen,\n"
                "den behandlede tekst erstatter det markerede.")
        ttk.Label(win, text=note, foreground="gray", justify="left").pack(anchor="w", padx=12, pady=(4, 8))

    # ------------------------------------------------------------ run

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    app = OmnitGramApp()
    app.run()
