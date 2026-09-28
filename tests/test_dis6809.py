"""Regressions for malformed hints and external self-relative targets."""
import io
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from dis6809 import Disassembler


class HintsTests(unittest.TestCase):
    def test_unterminated_inline_string(self):
        d = Disassembler(b"\xbd\x12\x34ABC", 0xC000,
                         SimpleNamespace(INLINE={0x1234: "asciz"}))
        with self.assertRaisesRegex(ValueError, r"asciz.*\$C003.*\$C006"):
            d.trace([0xC000])

    def test_terminator_at_last_byte(self):
        d = Disassembler(b"ABC\0", 0xC000)
        self.assertEqual(d.inline_len(0xC000, "asciz"), 4)

    def test_invalid_data_ranges(self):
        for addr, length in [(0xBFFF, 2), (0xC001, 2), (0xC000, 0), (0xC000, -1)]:
            with self.subTest(addr=addr, length=length):
                d = Disassembler(b"\0\0", 0xC000)
                with self.assertRaisesRegex(ValueError, "hint at"):
                    d.mark_data(addr, length, "fcb")
                self.assertFalse(d.data)

    def test_word_hints_require_pairs(self):
        for kind in ("fdb", "ptr", "jmptab", "selfrel"):
            with self.subTest(kind=kind):
                with self.assertRaisesRegex(ValueError, "even length"):
                    Disassembler(b"\0", 0xC000).mark_data(0xC000, 1, kind)

    def test_truncated_fixed_inline_data(self):
        for spec in ("ptr", 3):
            with self.subTest(spec=spec):
                with self.assertRaisesRegex(ValueError, "inline.*hint at"):
                    Disassembler(b"A", 0xC000).inline_len(0xC000, spec)

    def test_external_selfrel(self):
        for labels, expected in [({}, "$1234-*"), ({0x1234: "EXTERNAL"}, "EXTERNAL-*")]:
            hints = SimpleNamespace(DATA=[(0xC000, 2, "selfrel")], LABELS=labels)
            d = Disassembler(b"\x52\x34", 0xC000, hints)
            d.trace([])
            out = io.StringIO()
            d.emit(out)
            self.assertIn(expected, out.getvalue())
            self.assertNotIn("None", out.getvalue())
            self.assertNotIn(0x1234, d.code_refs)


if __name__ == "__main__":
    unittest.main()
