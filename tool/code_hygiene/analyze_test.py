"""Tests for the code-hygiene history analyzer."""

from __future__ import annotations

import gzip
import json
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest import mock

from tool.code_hygiene import analyze


def _commit(
    commit_hash: str,
    committed_on: str,
    *,
    parent_count: int = 1,
    subject: str = "change",
) -> analyze.Commit:
    return analyze.Commit(
        hash=commit_hash,
        parents=tuple(f"parent-{index}" for index in range(parent_count)),
        date=date.fromisoformat(committed_on),
        subject=subject,
    )


class DailySelectionTest(unittest.TestCase):
    def test_prefers_latest_merge_and_falls_back_to_latest_commit(self) -> None:
        commits = [
            _commit("newest-nonmerge", "2025-03-02"),
            _commit("newest-merge", "2025-03-02", parent_count=2),
            _commit("older-merge", "2025-03-02", parent_count=2),
            _commit("fallback", "2025-03-01"),
            _commit("older-fallback", "2025-03-01"),
            _commit("outside", "2025-02-28", parent_count=2),
        ]

        selected = analyze.select_daily_commits(
            commits,
            start=date(2025, 3, 1),
            end=date(2025, 3, 2),
        )

        self.assertEqual(
            [commit.hash for commit in selected],
            ["fallback", "newest-merge"],
        )


class ClocAggregationTest(unittest.TestCase):
    def test_aggregates_each_directory_and_ignores_summary_entries(self) -> None:
        report = {
            "header": {"cloc_version": "1.98"},
            "lib/a.dart": {"blank": 2, "comment": 3, "code": 5},
            "./lib/nested/b.dart": {"blank": 7, "comment": 11, "code": 13},
            "test/a_test.dart": {"blank": 17, "comment": 19, "code": 23},
            "other/file.dart": {"blank": 100, "comment": 100, "code": 100},
            "SUM": {"blank": 126, "comment": 133, "code": 141},
        }

        totals = analyze.aggregate_cloc_report(report)

        self.assertEqual(
            totals["lib"],
            analyze.LineCounts(files=2, blank=9, comment=14, code=18),
        )
        self.assertEqual(
            totals["test"],
            analyze.LineCounts(files=1, blank=17, comment=19, code=23),
        )

    def test_missing_historical_directory_is_recorded_as_zero(self) -> None:
        commit = _commit("a" * 40, "2025-03-01")
        report = {
            "header": {"cloc_version": "1.98"},
            "lib/a.dart": {"blank": 2, "comment": 3, "code": 5},
            "SUM": {"blank": 2, "comment": 3, "code": 5},
        }
        completed = mock.Mock(stdout=json.dumps(report))

        with (
            mock.patch.object(analyze, "_existing_roots", return_value=("lib",)),
            mock.patch.object(analyze, "_extract_archive") as extract,
            mock.patch.object(analyze, "_run", return_value=completed) as run,
        ):
            record = analyze._count_commit(
                Path("/repo"),
                commit,
                git="git",
                cloc="cloc",
                cloc_version="1.98",
            )

        extract.assert_called_once()
        self.assertEqual(run.call_args.args[0][-1], "lib")
        self.assertEqual(record["lib"]["code"], 5)
        self.assertEqual(
            record["test"],
            {"files": 0, "blank": 0, "comment": 0, "code": 0},
        )


class OutputTest(unittest.TestCase):
    def test_rows_expose_growth_and_shrinkage_deltas(self) -> None:
        records = [
            {
                "date": "2025-03-01",
                "commit": "a" * 40,
                "is_merge": False,
                "subject": "baseline",
                "lib": {"files": 1, "blank": 1, "comment": 1, "code": 100},
                "test": {"files": 1, "blank": 1, "comment": 1, "code": 50},
            },
            {
                "date": "2025-03-02",
                "commit": "b" * 40,
                "is_merge": True,
                "subject": "remove dead code",
                "lib": {"files": 1, "blank": 1, "comment": 1, "code": 80},
                "test": {"files": 2, "blank": 2, "comment": 2, "code": 55},
            },
        ]

        rows = analyze._rows(records)

        self.assertEqual(rows[0]["total_code"], 150)
        self.assertEqual(rows[0]["total_delta"], 0)
        self.assertEqual(rows[1]["lib_delta"], -20)
        self.assertEqual(rows[1]["test_delta"], 5)
        self.assertEqual(rows[1]["total_delta"], -15)

    def test_chart_is_standalone_and_escapes_script_closing_subjects(self) -> None:
        rows = [
            {
                "date": "2025-03-01",
                "commit": "a" * 40,
                "is_merge": False,
                "subject": "avoid </script><script>alert(1)</script>",
                "lib_code": 100,
                "test_code": 50,
                "total_code": 150,
                "lib_delta": 0,
                "test_delta": 0,
                "total_delta": 0,
            }
        ]
        with tempfile.TemporaryDirectory() as temp:
            chart = Path(temp) / "chart.html"

            analyze._write_chart(chart, rows, "Lotti <history>")
            content = chart.read_text(encoding="utf-8")

        self.assertIn("Lotti &lt;history&gt;", content)
        self.assertIn("Daily shrinkage", content)
        self.assertIn("Math.max(0, -d.total_delta)", content)
        self.assertIn("plotTop", content)
        self.assertNotIn("right = 28, top = 35", content)
        self.assertNotIn("</script><script>alert(1)</script>", content)
        self.assertIn("<\\/script><script>alert(1)<\\/script>", content)

    def test_cache_round_trip_preserves_completed_commit(self) -> None:
        cache = analyze._empty_cache()
        cache["commits"]["abc"] = {"lib": {"code": 12}, "test": {"code": 8}}
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "nested" / "cache.json"

            analyze._write_cache(path, cache)
            loaded = analyze._load_cache(path)

        self.assertEqual(loaded, cache)

    def test_restores_missing_cache_from_remote_url(self) -> None:
        cache = analyze._empty_cache()
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps(cache).encode()
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "cache.json"

            with mock.patch.object(analyze.urllib.request, "urlopen", return_value=response):
                restored_from = analyze._restore_cache(
                    path,
                    cache_url="https://example.com/cache.json",
                    seed_cache=None,
                )

            loaded = analyze._load_cache(path)

        self.assertEqual(restored_from, "remote cache https://example.com/cache.json")
        self.assertEqual(loaded, cache)

    def test_falls_back_to_compressed_seed_cache(self) -> None:
        cache = analyze._empty_cache()
        cache["commits"]["abc"] = {"lib": {"code": 12}, "test": {"code": 8}}
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path = root / "cache.json"
            seed = root / "seed_cache.json.gz"
            with gzip.open(seed, "wt", encoding="utf-8") as output:
                json.dump(cache, output)

            restored_from = analyze._restore_cache(
                path,
                cache_url=None,
                seed_cache=seed,
            )
            loaded = analyze._load_cache(path)

        self.assertEqual(restored_from, f"seed cache {seed}")
        self.assertEqual(loaded, cache)

    def test_rejects_cache_with_unknown_schema(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "cache.json"
            path.write_text(
                json.dumps({"schema_version": 999, "commits": {}}),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(analyze.HygieneError, "unsupported format"):
                analyze._load_cache(path)


if __name__ == "__main__":
    unittest.main()
