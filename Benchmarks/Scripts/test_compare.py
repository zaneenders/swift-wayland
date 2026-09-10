import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name("compare.py")
spec = importlib.util.spec_from_file_location("compare", SCRIPT)
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class ComparisonTests(unittest.TestCase):
    def test_gate_and_metadata(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            for name in ("baseline", "candidate"):
                for trial in range(3):
                    directory = root / name / f"trial-{trial}"
                    directory.mkdir(parents=True)
                    for metadata in compare.METADATA:
                        (directory / metadata).write_text("same")
                    report = {key: 1 for key in compare.CONFIG}
                    report.update(profilingEnabled=False,
                                  timings={"encode": {"p50MS": 1.0, "p95MS": 2.0}})
                    (directory / "text-wire.json").write_text(json.dumps(report))

            def run():
                return subprocess.run([sys.executable, str(SCRIPT), str(root / "baseline"),
                                       str(root / "candidate")], capture_output=True).returncode

            self.assertEqual(run(), 0)
            for trial in range(3):
                path = root / "candidate" / f"trial-{trial}" / "text-wire.json"
                data = json.loads(path.read_text())
                data["timings"]["encode"]["p95MS"] = 3.0
                path.write_text(json.dumps(data))
            self.assertEqual(run(), 1)
            (root / "candidate" / "trial-0" / "hardware.txt").write_text("different")
            self.assertEqual(run(), 1)


if __name__ == "__main__":
    unittest.main()
