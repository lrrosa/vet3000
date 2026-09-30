"""Content constraints independent of the 6809 decoder tests in MAME."""
from collections import deque
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/"cartridge/demo"))
from levels import COURTS


class ArcadeLevelsTests(unittest.TestCase):
    def test_32_distinct_courts(self):
        self.assertEqual(len(COURTS),32)
        self.assertEqual(len({tuple(rows) for _,rows in COURTS}),32)
        for name,rows in COURTS:
            with self.subTest(name=name):
                self.assertEqual(len(rows),10)
                self.assertTrue(all(len(row)==15 and set(row)<=set(".#SG") for row in rows))
                self.assertGreater(sum(c in "#S" for row in rows for c in row),0)

    def test_no_bricks_sealed_behind_gold(self):
        # Treat destructible bricks as removable and flood upward from the paddle.
        for name,rows in COURTS:
            with self.subTest(name=name):
                reached={(x,10) for x in range(15)}
                queue=deque(reached)
                while queue:
                    x,y=queue.popleft()
                    for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                        if not (0<=nx<15 and 0<=ny<=10) or (nx,ny) in reached:
                            continue
                        if ny<10 and rows[ny][nx]=="G":
                            continue
                        reached.add((nx,ny)); queue.append((nx,ny))
                for y,row in enumerate(rows):
                    for x,cell in enumerate(row):
                        if cell in "#S":
                            self.assertIn((x,y),reached)
