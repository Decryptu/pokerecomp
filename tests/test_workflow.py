"""Protect CI selection from silently dropping coverage. Run with unittest discover."""
import contextlib
import importlib.util
import io
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("workflow", Path(__file__).parents[1] / "tools/test.py")
workflow = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(workflow)


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        sources = {
            "game/model.gd": "class_name Model\n",
            "game/page.gd": 'class_name Page\nvar model: Model\n',
            "game/screen.tscn": '[ext_resource path="res://game/page.gd"]',
            "tests/unit/test_screen.gd": 'extends GutTest\nconst SCENE = preload("res://game/screen.tscn")',
            "tests/unit/test_other.gd": "extends GutTest\n",
            "tests/unit/test_smoke.gd": "extends GutTest\n",
        }
        for name, source in sources.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(source)
        self.context = patch.object(workflow, "ROOT", self.root)
        self.context.start()
        self.addCleanup(self.context.stop)
        original = Path.cwd()
        self.addCleanup(os.chdir, original)

    def test_class_and_scene_consumers_are_transitive(self):
        selected, _ = workflow.select(["game/model.gd"])
        self.assertEqual(selected, ["tests/unit/test_screen.gd", "tests/unit/test_smoke.gd"])

    def test_test_only_change_runs_its_subject(self):
        self.assertEqual(workflow.select(["tests/unit/test_other.gd"])[0], ["tests/unit/test_other.gd"])

    def test_documentation_runs_only_explicit_consumers(self):
        self.assertEqual(workflow.select(["README.md"])[0], [])
        path = self.root / "tests/unit/test_other.gd"
        path.write_text('extends GutTest\nvar text = FileAccess.get_file_as_string("res://README.md")')
        self.assertEqual(workflow.select(["README.md"])[0], ["tests/unit/test_other.gd"])

    def test_unknown_shared_inputs_and_deletions_fall_back_to_full(self):
        for path in ("project.godot", "game/deleted.gd", "assets/icon.png", "addons/gut/test.gd"):
            with self.subTest(path=path):
                self.assertEqual(len(workflow.select([path])[0]), 3)

    def test_new_source_is_selected_without_a_git_index_entry(self):
        path = self.root / "game/new.gd"
        path.write_text('class_name NewModel\n')
        test = self.root / "tests/unit/test_other.gd"
        test.write_text('extends GutTest\nvar model: NewModel\n')
        self.assertEqual(workflow.select(["game/new.gd"])[0],
                         ["tests/unit/test_other.gd", "tests/unit/test_smoke.gd"])

    def test_shards_cover_every_script_exactly_once(self):
        parts = []
        for index in range(1, 5):
            output = io.StringIO()
            with patch.object(sys, "argv", ["test.py", "--full", "--list", "--shard", f"{index}/4"]):
                with contextlib.redirect_stdout(output):
                    workflow.main()
            parts.extend(output.getvalue().splitlines()[1:])
        self.assertEqual(len(parts), 3)
        self.assertEqual(len(set(parts)), 3)


class WatchdogTests(unittest.TestCase):
    def test_failure_timeout_and_successful_teardown_have_distinct_statuses(self):
        wrapper = Path(__file__).resolve().parents[1] / "tools/ci_godot.sh"
        cases = [("raise SystemExit(7)", "", 7),
                 ("import time; time.sleep(5)", "", 124),
                 ("import time; print('VERDICT', flush=True); time.sleep(5)", "VERDICT", 0)]
        for code, verdict, expected in cases:
            with self.subTest(expected=expected):
                env = dict(os.environ, GODOT_CAP="2", GODOT_GRACE="1", GODOT_DONE=verdict)
                result = subprocess.run([str(wrapper), sys.executable, "-c", code],
                                        env=env, capture_output=True, timeout=8)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
