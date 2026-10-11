import importlib.util
import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("card_state", ROOT / "card-state.py")
card_state = importlib.util.module_from_spec(spec)
spec.loader.exec_module(card_state)
CARD = "# probe\n\n## Goal\nKeep the approved scope.\n\n## Done when\nA real check passes.\n\n## State\nUnverified; investigation in progress.\n\n## Neighbours\nNone.\n"


class CardStateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="card-state-test-")
        self.cwd = self.temp.name
        self.repo = Path(self.cwd)
        subprocess.run(["git", "init", "-q", "--initial-branch=wt/probe", self.cwd], check=True)
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("commit", "-q", "--allow-empty", "-m", "test: seed")
        self.card = self.repo / ".cards" / "probe.md"
        self.card.parent.mkdir()
        self.card.write_text(CARD)
        (self.repo / "CLAUDE.md").write_text("Read ~/nerdtools/claude/playbooks/worktree.md before card work.\n")

    def tearDown(self):
        self.temp.cleanup()

    def git(self, *args):
        return card_state.git(self.cwd, *args)

    def snapshot(self):
        return card_state.snapshot(self.cwd, str(self.card))

    def test_unicode_character_budget_not_lines_or_bytes(self):
        self.card.write_text(CARD.replace("Unverified; investigation in progress.", "界" * 4000))
        self.snapshot()
        self.card.write_text(CARD.replace("Unverified; investigation in progress.", "界" * 4001))
        with self.assertRaisesRegex(ValueError, "State has 4001 characters"):
            self.snapshot()
        self.card.write_text(CARD + "x" * 8000)
        with self.assertRaisesRegex(ValueError, "card has"):
            self.snapshot()

    def test_rejects_missing_and_duplicate_sections(self):
        for text in (CARD.replace("## Goal", "## Other"), CARD + "\n## State\nDuplicate\n"):
            self.card.write_text(text)
            with self.assertRaises(ValueError):
                self.snapshot()

    def test_stale_compares_card_with_commit_and_changed_files(self):
        future = time.time() + 60
        os.utime(self.card, (future, future))
        self.assertIsNone(card_state.stale(self.snapshot()))
        code = self.repo / "src" / "code.txt"
        code.parent.mkdir()
        code.write_text("edit")
        os.utime(code, (future + 10, future + 10))
        self.assertIn("predates src/code.txt", card_state.stale(self.snapshot()))
        self.git("add", "src/code.txt")
        self.git("mv", "src/code.txt", "src/renamed.txt")
        self.assertIn("predates src/renamed.txt", card_state.stale(self.snapshot()))
        os.utime(self.card, (future + 20, future + 20))
        self.assertIsNone(card_state.stale(self.snapshot()))

    def test_untracked_contents_require_consumer_reverification(self):
        artifact = self.repo / "probe-output.txt"
        artifact.write_text("first output")
        data = self.snapshot()
        artifact.write_text("changed output")
        self.assertEqual(card_state.identity(self.cwd), {key: data[key] for key in ("head", "tree", "status", "tracked_diff")})
        self.assertIn("do not fingerprint untracked contents or external artifacts", card_state.render(data))

    def test_snapshot_lookup_reuses_worktree_adapter_and_opt_in(self):
        def lookup():
            output = subprocess.check_output(["bash", str(ROOT / "wt.sh"), "snapshot"], cwd=self.cwd, text=True)
            return json.loads(output)
        self.assertEqual(lookup()["path"], str(self.card.resolve()))
        (self.repo / "CLAUDE.md").unlink()
        self.assertIsNone(lookup())
        (self.repo / "CLAUDE.md").write_text("~/nerdtools/claude/playbooks/worktree.md\n")
        self.card.unlink()
        with self.assertRaises(subprocess.CalledProcessError):
            lookup()

    def test_symlink_card_is_rejected(self):
        self.card.unlink()
        target = self.repo / "other.md"
        target.write_text(CARD)
        self.card.symlink_to(target)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.snapshot()


if __name__ == "__main__":
    unittest.main()
