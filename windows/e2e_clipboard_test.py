"""
End-to-end-test af OS-integrationslaget på en RIGTIG Windows-session.

Modsat test_omnitgram.py (som stubber alt) bruger denne test det ægte
keyboard-bibliotek og det ægte Windows-clipboard mod et rigtigt tekstfelt:

  1. Åbner et vindue med et tekstfelt der indeholder "hello wrold" (med fejl)
  2. Markerer teksten og kalder read_selection() - der sender ÆGTE Ctrl+C
     gennem OS'et og læser det ægte clipboard
  3. Kalder paste_text("hello world") - der sender ÆGTE Ctrl+V
  4. Verificerer at tekstfeltet nu indeholder den rettede tekst
  5. Verificerer at det oprindelige clipboard-indhold er gendannet

Består denne, ved vi at hele kæden UDEN LLM'en (hotkey-laget ind til
tekstfeltet og ud igen) virker på en rigtig Windows-maskine.

Kør: python windows/e2e_clipboard_test.py   (kræver Windows + display)
"""

import os
import sys
import threading
import time
import tkinter as tk

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import omnitgram as og  # noqa: E402

import pyperclip  # noqa: E402

ORIGINAL_CLIPBOARD = "forudgaaende clipboard-indhold"
WRONG_TEXT = "hello wrold"
FIXED_TEXT = "hello world"

result = {"ok": False, "err": "ukendt"}


def main() -> int:
    root = tk.Tk()
    root.title("OmnitGram e2e target")
    root.geometry("420x160+200+200")

    text = tk.Text(root, width=48, height=5, font=("Consolas", 12))
    text.pack(padx=10, pady=10)
    text.insert("1.0", WRONG_TEXT)

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
            time.sleep(1.5)  # lad vinduet få fokus og selection blive sat

            # 1) Læs markering via ægte Ctrl+C
            selected = og.read_selection()
            if selected != WRONG_TEXT:
                raise AssertionError(f"read_selection gav {selected!r}, forventede {WRONG_TEXT!r}")

            # 2) Selection skal stadig være aktiv; indsæt rettet tekst via ægte Ctrl+V
            og.paste_text(FIXED_TEXT)
            time.sleep(1.5)  # lad paste lande og clipboard-gendannelse køre

            # 3) Verificér indholdet af tekstfeltet (på main-tråden)
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

            # 4) Verificér at det oprindelige clipboard er gendannet
            clip = pyperclip.paste()
            if clip != ORIGINAL_CLIPBOARD:
                raise AssertionError(
                    f"Clipboard er {clip!r}, forventede gendannet {ORIGINAL_CLIPBOARD!r}")

            result["ok"] = True
            result["err"] = None
        except Exception as e:  # noqa: BLE001
            result["err"] = str(e)
        finally:
            root.after(0, root.destroy)

    threading.Thread(target=flow, daemon=True).start()
    root.mainloop()

    if result["ok"]:
        print("E2E OK: markering laest, tekst erstattet, clipboard gendannet")
        return 0
    print(f"E2E FAILED: {result['err']}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
