import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CARD = "# probe\n\n## Goal\nDiscussion only; no implementation approved.\n\n## Done when\nOwner chooses scope.\n\n## State\nWaiting on owner.\n\n## Neighbours\nNone.\n"


class CheckpointHookTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="claude-checkpoint-test-")
        self.cwd = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", "--initial-branch=wt/probe", str(self.cwd)], check=True)
        subprocess.run(["git", "-C", str(self.cwd), "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-q", "--allow-empty", "-m", "test: seed"], check=True)
        (self.cwd / "CLAUDE.md").write_text("Read ~/nerdtools/claude/playbooks/worktree.md.\n")
        self.card = self.cwd / ".cards/probe.md"
        self.card.parent.mkdir()
        self.card.write_text(CARD)
        self.age(self.card, 10)

    def tearDown(self):
        self.temp.cleanup()

    def age(self, path, seconds):
        os.utime(path, (time.time() + seconds, time.time() + seconds))

    def run_hook(self, event):
        return subprocess.run(["python3", str(ROOT / "worktree-checkpoint.py")], input=json.dumps({"cwd": str(self.cwd), **event}), capture_output=True, text=True, cwd=self.cwd)

    def edit_code(self):
        code = self.cwd / "code.txt"
        code.write_text("changed")
        self.age(code, 20)

    def test_manual_compact_passes_when_state_is_newer_than_changes(self):
        result = self.run_hook({"hook_event_name": "PreCompact", "trigger": "manual"})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_manual_compact_blocks_on_stale_state_and_names_the_change(self):
        self.edit_code()
        result = self.run_hook({"hook_event_name": "PreCompact", "trigger": "manual"})
        self.assertEqual(result.returncode, 2)
        self.assertIn("predates code.txt", result.stderr)
        self.age(self.card, 30)
        result = self.run_hook({"hook_event_name": "PreCompact", "trigger": "manual"})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_auto_compact_proceeds_and_session_start_asks_for_state(self):
        self.edit_code()
        result = self.run_hook({"hook_event_name": "PreCompact", "trigger": "auto"})
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_hook({"hook_event_name": "SessionStart", "source": "compact"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("overwrite that State from the summary", result.stdout)
        self.assertEqual(self.run_hook({"hook_event_name": "SessionStart", "source": "startup"}).stdout, "")

    def test_card_edit_alone_is_not_a_change(self):
        self.card.write_text(CARD + "More.\n")
        self.age(self.card, 40)
        result = self.run_hook({"hook_event_name": "PreCompact", "trigger": "manual"})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_over_budget_card_blocks_manual_compact(self):
        self.card.write_text(CARD + "x" * 8000)
        result = self.run_hook({"hook_event_name": "PreCompact", "trigger": "manual"})
        self.assertEqual(result.returncode, 2)
        self.assertIn("owner must shorten it", result.stderr)

    def test_non_applicable_repository_passes(self):
        (self.cwd / "CLAUDE.md").unlink()
        self.edit_code()
        result = self.run_hook({"hook_event_name": "PreCompact", "trigger": "manual"})
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
