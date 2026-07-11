"""
Logik-tests for OmnitGram (Windows).

Kører på alle platforme: alle eksterne afhængigheder (keyboard, pyperclip,
pystray, tkinter, requests, keyring, winsound) stubbes ud, så vi tester ren
logik: config-persistens, API-nøgle-fallback, LLM-kald inkl. fejlveje og
truncation-guard, samt clipboard-flowet i read_selection/paste_text.

Kør:  python windows/test_omnitgram.py
"""

import json
import os
import sys
import tempfile
import time
import types
import unittest


def make_stub(name, **attrs):
    mod = types.ModuleType(name)
    for k, v in attrs.items():
        setattr(mod, k, v)
    sys.modules[name] = mod
    return mod


# --- Stub alle eksterne afhængigheder FØR import af omnitgram -------------

make_stub("keyboard",
          send=lambda *a, **k: None,
          release=lambda *a, **k: None,
          add_hotkey=lambda *a, **k: object(),
          remove_hotkey=lambda *a, **k: None,
          read_hotkey=lambda **k: "ctrl+alt+g")
make_stub("pyperclip", paste=lambda: "", copy=lambda t: None)
make_stub("requests", post=None)
make_stub("keyring")  # mangler get/set_password -> AttributeError -> fallback-vej
make_stub("pystray")
make_stub("PIL")
make_stub("winsound", MessageBeep=lambda *a: None, MB_OK=0, MB_ICONHAND=16)

tk_stub = make_stub("tkinter", Tk=object, Toplevel=object, StringVar=object)
make_stub("tkinter.ttk")
tk_stub.ttk = sys.modules["tkinter.ttk"]

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import omnitgram as og  # noqa: E402


class FakeResp:
    def __init__(self, status=200, body=None, text=""):
        self.status_code = status
        self._body = body if body is not None else {}
        self.text = text

    def json(self):
        return self._body


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        og.CONFIG_DIR = self.tmp.name
        og.CONFIG_PATH = os.path.join(self.tmp.name, "config.json")

    def tearDown(self):
        self.tmp.cleanup()

    def test_defaults_when_no_file(self):
        cfg = og.load_config()
        self.assertEqual(cfg["provider"], "anthropic")
        self.assertEqual(cfg["hotkey_grammar"], "ctrl+alt+g")
        self.assertEqual(cfg["hotkey_improve"], "ctrl+alt+o")

    def test_roundtrip(self):
        cfg = og.load_config()
        cfg["provider"] = "openai"
        cfg["hotkey_grammar"] = "f6"
        cfg["model"] = "gpt-4o-mini"
        og.save_config(cfg)
        cfg2 = og.load_config()
        self.assertEqual(cfg2["provider"], "openai")
        self.assertEqual(cfg2["hotkey_grammar"], "f6")
        self.assertEqual(cfg2["model"], "gpt-4o-mini")

    def test_corrupt_file_falls_back_to_defaults(self):
        os.makedirs(og.CONFIG_DIR, exist_ok=True)
        with open(og.CONFIG_PATH, "w") as f:
            f.write("{not valid json")
        cfg = og.load_config()
        self.assertEqual(cfg["provider"], "anthropic")

    def test_api_key_fallback_without_keyring(self):
        og.KEYRING_OK = False
        cfg = og.load_config()
        og.set_api_key(cfg, "  sk-test-123  ")
        self.assertEqual(og.get_api_key(cfg), "sk-test-123")
        # og at den overlever en save/load-runde
        og.save_config(cfg)
        cfg2 = og.load_config()
        self.assertEqual(og.get_api_key(cfg2), "sk-test-123")

    def test_broken_keyring_falls_back(self):
        og.KEYRING_OK = True  # keyring-stub mangler metoderne -> exceptions
        cfg = og.load_config()
        og.set_api_key(cfg, "sk-fallback")
        self.assertEqual(og.get_api_key(cfg), "sk-fallback")


class LLMTests(unittest.TestCase):
    def setUp(self):
        og.KEYRING_OK = False
        self.cfg = dict(og.DEFAULT_CONFIG)
        self.cfg["api_key_fallback"] = "sk-x"

    def test_missing_key_raises(self):
        cfg = dict(og.DEFAULT_CONFIG)
        cfg["api_key_fallback"] = ""
        with self.assertRaises(RuntimeError):
            og.call_llm(cfg, "sys", "hello")

    def test_anthropic_success_strips_whitespace(self):
        og.requests.post = lambda *a, **k: FakeResp(200, {
            "content": [{"type": "text", "text": "  rettet tekst  "}],
            "stop_reason": "end_turn",
        })
        self.assertEqual(og.call_llm(self.cfg, "sys", "tekst"), "rettet tekst")

    def test_anthropic_truncation_raises(self):
        og.requests.post = lambda *a, **k: FakeResp(200, {
            "content": [{"type": "text", "text": "halv tek"}],
            "stop_reason": "max_tokens",
        })
        with self.assertRaises(RuntimeError):
            og.call_llm(self.cfg, "sys", "meget lang tekst")

    def test_anthropic_http_error_raises(self):
        og.requests.post = lambda *a, **k: FakeResp(401, {}, text="unauthorized")
        with self.assertRaises(RuntimeError):
            og.call_llm(self.cfg, "sys", "tekst")

    def test_anthropic_empty_output_returns_input(self):
        og.requests.post = lambda *a, **k: FakeResp(200, {
            "content": [], "stop_reason": "end_turn",
        })
        self.assertEqual(og.call_llm(self.cfg, "sys", "original"), "original")

    def test_openai_success(self):
        self.cfg["provider"] = "openai"
        og.requests.post = lambda *a, **k: FakeResp(200, {
            "choices": [{"message": {"content": "fixed"}, "finish_reason": "stop"}],
        })
        self.assertEqual(og.call_llm(self.cfg, "sys", "tekst"), "fixed")

    def test_openai_truncation_raises(self):
        self.cfg["provider"] = "openai"
        og.requests.post = lambda *a, **k: FakeResp(200, {
            "choices": [{"message": {"content": "halv"}, "finish_reason": "length"}],
        })
        with self.assertRaises(RuntimeError):
            og.call_llm(self.cfg, "sys", "lang tekst")

    def test_default_model_used_when_blank(self):
        captured = {}
        def fake_post(url, headers=None, json=None, timeout=None):
            captured["model"] = json["model"]
            return FakeResp(200, {"content": [{"type": "text", "text": "ok"}],
                                  "stop_reason": "end_turn"})
        og.requests.post = fake_post
        self.cfg["model"] = "   "
        og.call_llm(self.cfg, "sys", "t")
        self.assertEqual(captured["model"], "claude-opus-4-7")


class ClipboardFlowTests(unittest.TestCase):
    def test_read_selection_success_and_restore(self):
        state = {"clip": "original clipboard"}
        og.pyperclip.paste = lambda: state["clip"]
        og.pyperclip.copy = lambda t: state.__setitem__("clip", t)

        def fake_send(combo):
            if combo == "ctrl+c":
                state["clip"] = "  MARKERET TEKST  "
        og.keyboard.send = fake_send

        out = og.read_selection()
        self.assertEqual(out, "MARKERET TEKST")
        self.assertEqual(state["clip"], "original clipboard")  # gendannet

    def test_read_selection_nothing_selected(self):
        state = {"clip": "original"}
        og.pyperclip.paste = lambda: state["clip"]
        og.pyperclip.copy = lambda t: state.__setitem__("clip", t)
        og.keyboard.send = lambda combo: None  # ctrl+c ændrer intet

        out = og.read_selection()
        self.assertIsNone(out)
        self.assertEqual(state["clip"], "original")  # gendannet

    def test_paste_text_sends_ctrl_v_and_restores(self):
        state = {"clip": "gammelt indhold"}
        sent = []
        og.pyperclip.paste = lambda: state["clip"]
        og.pyperclip.copy = lambda t: state.__setitem__("clip", t)
        og.keyboard.send = lambda combo: sent.append(combo)

        og.paste_text("nyt resultat")
        self.assertIn("ctrl+v", sent)
        self.assertEqual(state["clip"], "nyt resultat")  # lå klar ved paste
        time.sleep(0.8)
        self.assertEqual(state["clip"], "gammelt indhold")  # gendannet bagefter


class DiffTests(unittest.TestCase):
    def test_identical_text_is_all_equal(self):
        out = og.diff_words("hej med dig", "hej med dig")
        self.assertEqual(out, [("equal", "hej med dig")])

    def test_single_word_replacement(self):
        out = og.diff_words("jeg have en hund", "jeg har en hund")
        self.assertIn(("delete", "have"), out)
        self.assertIn(("insert", "har"), out)
        ops = [op for op, _ in out]
        self.assertEqual(ops.count("delete"), 1)
        self.assertEqual(ops.count("insert"), 1)

    def test_insertion_only(self):
        out = og.diff_words("hund er sjov", "min hund er sjov")
        self.assertIn(("insert", "min"), out)
        self.assertNotIn("delete", [op for op, _ in out])

    def test_deletion_only(self):
        out = og.diff_words("det er meget helt fint", "det er helt fint")
        self.assertIn(("delete", "meget"), out)
        self.assertNotIn("insert", [op for op, _ in out])

    def test_newlines_preserved_as_tokens(self):
        out = og.diff_words("linje et\nlinje to", "linje et\nlinje to")
        joined = " ".join(chunk for _, chunk in out)
        self.assertIn("\n", joined)

    def test_reconstruction_of_corrected_text(self):
        # equal + insert-dele skal tilsammen udgøre den rettede tekst (ordvis).
        original = "jeg have en hund og den er sjove"
        corrected = "jeg har en hund og den er sjov"
        out = og.diff_words(original, corrected)
        rebuilt = " ".join(chunk for op, chunk in out if op in ("equal", "insert") and chunk)
        self.assertEqual(rebuilt.split(), corrected.split())


if __name__ == "__main__":
    unittest.main(verbosity=2)
