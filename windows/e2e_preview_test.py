"""
End-to-end-test af PREVIEW-flowet på en RIGTIG Windows-session.

Bruger produktionskoden OmnitGramApp._show_preview (via duck-typing) og
verificerer hele accept-kæden med ægte OS-input:

  1. Åbner et målvindue med et tekstfelt der indeholder "hello wrold", markeret
  2. Kalder _show_preview(original, rettet, mål-hwnd) - previewet åbner
     med farvemarkeret diff og tager fokus
  3. Sender et ÆGTE Enter-tastetryk gennem OS'et -> previewets accept-flow:
     luk vindue -> gendan fokus til målvinduet -> ægte Ctrl+V
  4. Verificerer at tekstfeltet nu indeholder den rettede tekst,
     at clipboard er gendannet, og at busy-flaget er frigivet

Kør: python windows/e2e_preview_test.py   (kræver Windows + display)
"""

import os
import sys
import threading
import time
import tkinter as tk

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import omnitgram as og  # noqa: E402

import keyboard   # noqa: E402
import pyperclip  # noqa: E402

ORIGINAL_CLIPBOARD = "forudgaaende clipboard-indhold"
WRONG_TEXT = "hello wrold"
FIXED_TEXT = "hello world"

result = {"ok": False, "err": "ukendt"}


class HostStub:
    """Duck-type-erstatning for OmnitGramApp: kun det _show_preview bruger."""
    def __init__(self, root):
        self.root = root
        self.busy = True
        self.cfg = dict(og.DEFAULT_CONFIG)


def main() -> int:
    root = tk.Tk()
    root.title("OmnitGram preview-e2e target")
    root.geometry("420x160+200+200")

    # exportselection=0: previewets eget Text-widget må ikke stjæle
    # selection-taggen fra målfeltet (kun relevant når begge er tk i
    # samme proces - i produktion er målet en helt anden app).
    text = tk.Text(root, width=48, height=5, font=("Consolas", 12),
                   exportselection=0)
    text.pack(padx=10, pady=10)
    text.insert("1.0", WRONG_TEXT)

    host = HostStub(root)

    def prepare_focus():
        root.lift()
        root.attributes("-topmost", True)
        root.focus_force()
        text.focus_set()
        text.tag_add("sel", "1.0", "end-1c")
        text.mark_set("insert", "end-1c")

    root.after(200, prepare_focus)

    def flow():
        try:
            pyperclip.copy(ORIGINAL_CLIPBOARD)
            time.sleep(1.5)  # målvinduet skal have fokus først

            target_hwnd = og.get_foreground_window()
            if not target_hwnd:
                raise AssertionError("Kunne ikke aflæse foreground-vinduet")

            # 2) Åbn previewet fra produktionskoden (på tk-tråden)
            root.after(0, lambda: og.OmnitGramApp._show_preview(
                host, WRONG_TEXT, FIXED_TEXT, target_hwnd))

            # Vent på at preview-vinduet er åbent og har fokus
            time.sleep(1.5)

            # 3) Ægte Enter gennem OS'et -> accept
            keyboard.send("enter")

            # Accept-flowet: luk -> gendan fokus -> 0.3s -> Ctrl+V -> gendan clipboard
            time.sleep(2.5)

            # 4) Verificér målfeltets indhold (på main-tråden)
            got = {}
            done = threading.Event()

            def grab():
                got["content"] = text.get("1.0", "end-1c")
                done.set()

            root.after(0, grab)
            if not done.wait(5):
                raise AssertionError("Kunne ikke læse tekstfeltet")
            if got["content"] != FIXED_TEXT:
                raise AssertionError(
                    f"Tekstfeltet indeholder {got['content']!r}, forventede {FIXED_TEXT!r}")

            clip = pyperclip.paste()
            if clip != ORIGINAL_CLIPBOARD:
                raise AssertionError(
                    f"Clipboard er {clip!r}, forventede gendannet {ORIGINAL_CLIPBOARD!r}")

            if host.busy:
                raise AssertionError("busy-flaget blev ikke frigivet efter accept")

            result["ok"] = True
            result["err"] = None
        except Exception as e:  # noqa: BLE001
            result["err"] = str(e)
        finally:
            root.after(0, root.destroy)

    threading.Thread(target=flow, daemon=True).start()
    root.mainloop()

    if result["ok"]:
        print("PREVIEW E2E OK: diff vist, aegte Enter accepteret, tekst erstattet, clipboard gendannet")
        return 0
    print(f"PREVIEW E2E FAILED: {result['err']}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
