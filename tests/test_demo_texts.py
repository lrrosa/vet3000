"""Portuguese texts of the demo keep their accents (ESPAÇO, LANÇA, ...)."""
from pathlib import Path
import re
import sys
import unittest

DEMO = Path(__file__).resolve().parents[1] / "cartridge/demo"
sys.path.insert(0, str(DEMO))
import gen_assets

# Words that must not appear without their accents in anything shown on screen.
UNACCENTED = ["ESPACO", "LANCA", "DEMONSTRACAO", "GUARDIAO", "CAPSULA", "TITULOS", "ESTAGIO"]


class DemoTextTests(unittest.TestCase):
    def texts(self):
        yield "SCROLL_TEXT", gen_assets.SCROLL_TEXT
        for label, text in gen_assets.MESSAGES:
            yield label, text
        # strings written directly in the assembly bypass the accent table
        for path in sorted(DEMO.glob("*.inc")) + [DEMO / "demo.asm"]:
            if path.name == "assets.inc":
                continue
            for m in re.finditer(r'fcc\s+"([^"]*)"', path.read_text(encoding="utf-8")):
                yield path.name, m.group(1)

    def test_accents(self):
        for where, text in self.texts():
            for word in UNACCENTED:
                with self.subTest(where=where, word=word):
                    self.assertNotIn(word, text.upper())

    def test_glyphs_exist(self):
        # every character must map to one of the 64 font glyphs
        for where, text in self.texts():
            if where.endswith(".asm") or where.endswith(".inc"):
                continue
            with self.subTest(where=where):
                for ch in text.upper():
                    code = ord(gen_assets.ACCENTS.get(ch, ch))
                    self.assertTrue(0x20 <= code < 0x60, ch)


if __name__ == "__main__":
    unittest.main()
