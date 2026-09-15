"""Check concurrent public history, resume identity and honest aggregate totals."""

import json
import os
import subprocess
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from tool.lotti_gym_history import aggregate_history, duration_summary, history_record, record_history
from tool.penguin_query_eval import RUN_HISTORY_PATH, repository_revision


class HistoryTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)

    def record(self, run_id="run-one"):
        return {
            "runId": run_id, "model": "candidate",
            "exercises": {"planned": 3, "passed": 2, "failed": 1},
            "cost": {"complete": True, "knownCostEur": "0.10000001", "totalCostEur": "0.10000001"},
            "duration": {"complete": True, "knownActiveWallSeconds": 20, "activeWallSeconds": 20},
        }

    def test_parallel_runs_and_resume_upsert_without_lost_or_duplicate_rows(self):
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(lambda i: record_history(self.root, self.record(str(i))), range(12)))
        updated = self.record("4")
        updated["exercises"] = {"planned": 3, "passed": 3, "failed": 0}
        record_history(self.root, updated)
        rows = [json.loads(line) for line in (self.root / RUN_HISTORY_PATH).read_text().splitlines()]
        self.assertEqual(len(rows), 12)
        self.assertEqual(next(row for row in rows if row["runId"] == "4"), updated)

    def test_totals_include_failed_runs_and_keep_unknown_history_explicit(self):
        old = self.record("old")
        old["cost"].update(complete=False, totalCostEur=None)
        old["duration"].update(complete=False, activeWallSeconds=None, knownActiveWallSeconds=0)
        total = aggregate_history([self.record(), old])[0]
        self.assertEqual(total["exercises"]["failed"], 2)
        self.assertEqual(total["knownCostEur"], "0.20000002")
        self.assertIsNone(total["totalCostEur"])
        self.assertEqual(total["knownActiveWallSeconds"], 20)
        self.assertIsNone(total["totalActiveWallSeconds"])
        self.assertEqual(total["runsWithIncompleteCost"], 1)

    def test_resume_duration_excludes_idle_gap_and_sums_parallel_exercise_time_separately(self):
        sessions = self.root / "sessions"
        sessions.mkdir()
        for name, start, end, seconds in [
            ("z", "2030-01-15T10:00:00Z", "2030-01-15T10:01:00Z", 60),
            ("a", "2030-01-15T15:00:00Z", "2030-01-15T15:00:30Z", 30),
        ]:
            (sessions / f"{name}.json").write_text(json.dumps({
                "startedAt": start, "finishedAt": end, "durationSeconds": seconds,
            }))
        jobs = [{"attempts": [{"results": [{"latencyMs": 80000}, {"latencyMs": 80000}]}]}]
        timing = duration_summary(self.root, jobs)
        self.assertEqual(timing["activeWallSeconds"], 90)
        self.assertEqual(timing["summedExerciseSeconds"], 160)
        self.assertEqual(timing["startedAt"], "2030-01-15T10:00:00Z")
        self.assertEqual(timing["finishedAt"], "2030-01-15T15:00:30Z")

    def test_public_projection_excludes_preparation_from_exercises_and_private_fields(self):
        manifest = {
            "model": "candidate", "provider": "melious", "revision": {"commit": "abc"},
            "scope": "partial", "samples": 3, "workers": 4,
            "suites": [{"id": "reports", "adapter": "preparation", "cases": ["reports"]},
                       {"id": "query", "adapter": "query", "cases": ["one"]}],
            "apiKey": "SECRET", "host": "PRIVATE HOST",
        }
        jobs = [
            {"suite": "reports", "state": "prepared", "expected": ["reports"], "attempts": []},
            {"suite": "query", "state": "failed", "expected": ["one"],
             "attempts": [{"artifact": "/PRIVATE PATH", "results": [{"status": "failed"}]}]},
        ]
        summary = {"verdict": "failed", "suites": [{"credits": 0.2}]}
        result = history_record(self.root, manifest, summary, jobs)
        self.assertEqual(result["exercises"]["planned"], 1)
        self.assertEqual(result["exercises"]["failed"], 1)
        self.assertFalse(result["cost"]["complete"])
        self.assertIsNone(result["duration"]["activeWallSeconds"])
        self.assertNotIn("SECRET", json.dumps(result))
        self.assertNotIn("PRIVATE", json.dumps(result))

    def test_history_changes_do_not_invalidate_source_but_source_changes_do(self):
        def git(*args):
            return subprocess.check_output(["git", *args], cwd=self.root, stderr=subprocess.DEVNULL,
                                           env={**os.environ, "GIT_AUTHOR_DATE": "2030-01-15T00:00:00Z",
                                                "GIT_COMMITTER_DATE": "2030-01-15T00:00:00Z"})
        git("init", "-q")
        (self.root / ".gitignore").write_text("build/\n")
        (self.root / "source.dart").write_text("original")
        git("add", ".")
        git("-c", "user.name=Test", "-c", "user.email=test@example.invalid",
            "-c", "commit.gpgsign=false", "commit", "-qm", "fixture")
        original = repository_revision(self.root)
        record_history(self.root, self.record())
        self.assertEqual(repository_revision(self.root), original)
        git("add", RUN_HISTORY_PATH)
        self.assertEqual(repository_revision(self.root), original)
        (self.root / "source.dart").write_text("changed")
        self.assertNotEqual(repository_revision(self.root), original)


if __name__ == "__main__":
    unittest.main()
