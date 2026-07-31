"""Tests for the code-hygiene history analyzer."""

from __future__ import annotations

import csv
import gzip
import io
import json
import tarfile
import tempfile
import threading
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

    def test_archive_extraction_drains_stderr_while_reading_stdout(self) -> None:
        ready = threading.Event()
        archive_bytes = io.BytesIO()
        payload = b"void main() {}\n"
        with tarfile.open(fileobj=archive_bytes, mode="w") as archive:
            member = tarfile.TarInfo("lib/main.dart")
            member.size = len(payload)
            archive.addfile(member, io.BytesIO(payload))

        class BlockingStdout(io.BytesIO):
            def read(self, size: int = -1) -> bytes:
                if not ready.wait(timeout=1):
                    raise AssertionError("stderr was not drained concurrently")
                return super().read(size)

        class SignalingStderr(io.BytesIO):
            def read(self, size: int = -1) -> bytes:
                ready.set()
                return super().read(size)

        process = mock.Mock()
        process.stdout = BlockingStdout(archive_bytes.getvalue())
        process.stderr = SignalingStderr(b"archive diagnostic")
        process.wait.return_value = 0

        with tempfile.TemporaryDirectory() as temp:
            destination = Path(temp)
            with mock.patch.object(analyze.subprocess, "Popen", return_value=process):
                analyze._extract_archive(
                    Path("/repo"),
                    "a" * 40,
                    ("lib",),
                    destination,
                    "git",
                )

            self.assertEqual(
                (destination / "lib" / "main.dart").read_bytes(),
                payload,
            )

    def test_archive_read_errors_are_reported_as_hygiene_errors(self) -> None:
        process = mock.Mock()
        process.stdout = io.BytesIO(b"not a tar archive")
        process.stderr = io.BytesIO(b"truncated archive")
        process.poll.return_value = None
        process.wait.return_value = 1

        with (
            tempfile.TemporaryDirectory() as temp,
            mock.patch.object(analyze.subprocess, "Popen", return_value=process),
            self.assertRaisesRegex(
                analyze.HygieneError,
                "Could not read Git archive",
            ),
        ):
            analyze._extract_archive(
                Path("/repo"),
                "a" * 40,
                ("lib",),
                Path(temp),
                "git",
            )

        process.kill.assert_called_once()
        process.wait.assert_called_once()


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

    def test_chart_is_standalone_and_escapes_all_subject_less_than_signs(self) -> None:
        rows = [
            {
                "date": "2025-03-01",
                "commit": "a" * 40,
                "is_merge": False,
                "subject": "avoid <!--<script>alert(1)</script>",
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
        self.assertNotIn("<!--<script>alert(1)</script>", content)
        self.assertIn(
            r"avoid \u003c!--\u003cscript>alert(1)\u003c/script>",
            content,
        )

    def test_csv_neutralizes_formula_leading_commit_subjects(self) -> None:
        rows = []
        for subject in ("=WEBSERVICE(\"https://example.com\")", "+1", "-1", "@SUM(1)"):
            row = dict.fromkeys(analyze.CSV_FIELDS, 0)
            row["subject"] = subject
            rows.append(row)

        with tempfile.TemporaryDirectory() as temp:
            report = Path(temp) / "report.csv"
            analyze._write_csv(report, rows)
            with report.open(encoding="utf-8", newline="") as source:
                subjects = [row["subject"] for row in csv.DictReader(source)]

        self.assertEqual(
            subjects,
            [
                "'=WEBSERVICE(\"https://example.com\")",
                "'+1",
                "'-1",
                "'@SUM(1)",
            ],
        )

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

    def test_recounts_only_cache_entries_from_a_different_cloc_version(self) -> None:
        commit = _commit("a" * 40, "2025-03-01")
        cached_record = {
            "commit": commit.hash,
            "date": commit.date.isoformat(),
            "is_merge": False,
            "subject": commit.subject,
            "cloc_version": "1.96",
            "lib": {"files": 1, "blank": 0, "comment": 0, "code": 10},
            "test": {"files": 1, "blank": 0, "comment": 0, "code": 5},
        }
        refreshed_record = {**cached_record, "cloc_version": "1.98"}

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            cache_path = root / "cache.json"
            cache = analyze._empty_cache()
            cache["commits"][commit.hash] = cached_record
            analyze._write_cache(cache_path, cache)

            with (
                mock.patch.object(analyze, "_repository_root", return_value=root),
                mock.patch.object(
                    analyze,
                    "_commits_on_first_parent",
                    return_value=[commit],
                ),
                mock.patch.object(analyze, "_restore_cache", return_value=None),
                mock.patch.object(
                    analyze,
                    "_run",
                    return_value=mock.Mock(stdout="1.98\n"),
                ) as run,
                mock.patch.object(
                    analyze,
                    "_count_commit",
                    return_value=refreshed_record,
                ) as count_commit,
                mock.patch.object(analyze, "_write_csv"),
                mock.patch.object(analyze, "_write_chart"),
            ):
                _, _, _, measured, reused = analyze.analyze(
                    root,
                    ref="HEAD",
                    days=1,
                    output_dir=root,
                    cache_path=cache_path,
                    git="git",
                    cloc="cloc",
                    refresh=False,
                    cache_url=None,
                    seed_cache=None,
                )

        run.assert_called_once_with(["cloc", "--version"])
        count_commit.assert_called_once()
        self.assertEqual((measured, reused), (1, 0))

    def test_cache_record_requires_the_current_cloc_version(self) -> None:
        self.assertTrue(
            analyze._cache_record_uses_cloc(
                {"cloc_version": "1.98"},
                "1.98",
            )
        )
        self.assertFalse(
            analyze._cache_record_uses_cloc(
                {"cloc_version": "1.96"},
                "1.98",
            )
        )
        self.assertFalse(analyze._cache_record_uses_cloc("invalid", "1.98"))


if __name__ == "__main__":
    unittest.main()
