"""Offline regressions for honest LottiGym verdicts and artifact validation."""

import json
import tempfile
import unittest
from pathlib import Path

from tool.lotti_gym_results import (
    InvalidArtifact,
    compare_baseline,
    normalize,
    summarize,
    write_report,
)


class ResultsTest(unittest.TestCase):
    def test_invalid_telemetry_cannot_become_free_or_negative_cost(self):
        for credits in (True, -1, float("nan"), "0.25"):
            with self.subTest(credits=credits), self.assertRaises(InvalidArtifact):
                self.agent(
                    [
                        {
                            "modelId": "candidate",
                            "scenarioId": "quiet",
                            "passed": True,
                            "credits": credits,
                        }
                    ]
                )

    def test_task_artifact_uses_failure_category_not_a_nonexistent_passed_field(self):
        for category, expected in [("none", "passed"), ("forbiddenToolCall", "failed")]:
            result = normalize(
                {"adapter": "task"},
                {
                    "results": [
                        {
                            "providerModelId": "candidate",
                            "scenarioId": "quiet",
                            "failureCategory": category,
                        }
                    ]
                },
                ["quiet"],
                "candidate",
                test_passed=True,
            )
            self.assertEqual(result[0]["status"], expected)

    def agent(self, rows, passed=True):
        return normalize(
            {"adapter": "agent"},
            {"results": rows},
            ["quiet"],
            "candidate",
            test_passed=passed,
        )

    def test_flutter_success_does_not_override_model_failure(self):
        rows = self.agent(
            [
                {
                    "modelId": "candidate",
                    "scenarioId": "quiet",
                    "passed": False,
                    "failureCategory": "noOpViolated",
                }
            ]
        )
        self.assertEqual(rows[0]["status"], "failed")

    def test_empty_missing_duplicate_extra_and_wrong_model_results_fail_closed(self):
        valid = {"modelId": "candidate", "scenarioId": "quiet", "passed": True}
        for rows in (
            [],
            [valid, valid],
            [{**valid, "scenarioId": "other"}],
            [{**valid, "modelId": "baseline"}],
            [{k: v for k, v in valid.items() if k != "passed"}],
        ):
            with self.subTest(rows=rows), self.assertRaises(InvalidArtifact):
                self.agent(rows)

    def test_nonzero_worker_cannot_hide_behind_green_artifact(self):
        with self.assertRaises(InvalidArtifact):
            self.agent(
                [{"modelId": "candidate", "scenarioId": "quiet", "passed": True}],
                passed=False,
            )

    def test_inference_errors_are_not_behavioral_failures(self):
        result = self.agent(
            [
                {
                    "modelId": "candidate",
                    "scenarioId": "quiet",
                    "passed": False,
                    "failureCategory": "inferenceError",
                    "errorMessage": "secret provider details",
                }
            ]
        )
        self.assertEqual(result[0]["status"], "error")
        self.assertNotIn("secret", repr(result))

    def test_wake_assertions_matter_even_when_workflow_succeeds(self):
        result = normalize(
            {"adapter": "wake"},
            {"model": "candidate", "scenario": "quiet", "success": True},
            ["quiet"],
            "candidate",
            test_passed=False,
        )
        self.assertEqual(result[0]["status"], "failed")

    def test_heuristics_and_ungraded_journeys_do_not_earn_free_passes(self):
        result = normalize(
            {"adapter": "planning"},
            {
                "judgeBundle": [
                    {
                        "cell": "quiet/candidate/baseline#1",
                        "scenario": {"id": "quiet"},
                        "constraints": {"prose": {"kind": "heuristic", "passed": True}},
                    }
                ]
            },
            ["quiet"],
            "candidate",
            test_passed=True,
        )
        self.assertEqual(result[0]["status"], "review_required")
        result = normalize(
            {"adapter": "journey"},
            {
                "runs": [
                    {
                        "modelId": "candidate",
                        "scenarioId": "quiet",
                        "parsedItemCount": 4,
                    }
                ]
            },
            ["quiet"],
            "candidate",
            test_passed=True,
        )
        self.assertEqual(result[0]["status"], "review_required")

    def test_compaction_requires_all_arms_and_keeps_judgment_pending(self):
        rows = [
            {
                "modelId": "candidate",
                "fixtureId": "old",
                "strategyId": a,
                "wake": {"statusCorrect": True},
            }
            for a in ("full", "hierarchical")
        ]
        result = normalize(
            {"adapter": "compaction"},
            {"cases": rows},
            ["old/full", "old/hierarchical"],
            "candidate",
            test_passed=True,
        )
        self.assertEqual([r["status"] for r in result], ["review_required"] * 2)
        with self.assertRaises(InvalidArtifact):
            normalize(
                {"adapter": "compaction"},
                {"cases": rows[:1]},
                ["old/full", "old/hierarchical"],
                "candidate",
                test_passed=True,
            )

    def test_report_counts_missing_jobs_and_escapes_model_output(self):
        manifest = {
            "model": "<script>alert(1)</script>",
            "provider": "melious",
            "revision": {},
            "scope": "full",
            "coverageGaps": {"speech": "not assessed"},
            "excludedEntryPoints": {},
            "suites": [{"id": "goals", "adapter": "agent"}],
        }
        jobs = [
            {
                "id": "goals/quiet/1",
                "suite": "goals",
                "state": "pending",
                "expected": ["quiet"],
                "attempts": [],
            }
        ]
        summary = summarize(manifest, jobs)
        self.assertEqual(summary["verdict"], "incomplete")
        self.assertEqual(summary["suites"][0]["counts"], {"not_assessed": 1})
        self.assertIsNone(summary["suites"][0]["credits"])
        with tempfile.TemporaryDirectory() as tmp:
            write_report(Path(tmp), summary, jobs)
            text = (Path(tmp) / "report.html").read_text()
        self.assertNotIn("<script>", text)
        self.assertIn("&lt;script&gt;", text)

    def test_query_uses_provider_usage_and_requires_stable_revision(self):
        artifact = {
            "model": "candidate",
            "revisionUnchanged": True,
            "results": [
                {
                    "case": "quiet",
                    "status": "complete",
                    "passed": True,
                    "totalMs": 120,
                    "providerUsage": [{"credits": 0.5}, {"credits": 0.25}],
                }
            ],
        }
        result = normalize(
            {"adapter": "query"}, artifact, ["quiet"], "candidate", test_passed=True
        )
        self.assertEqual(result[0]["credits"], 0.75)
        self.assertEqual(result[0]["latencyMs"], 120)
        artifact["revisionUnchanged"] = False
        with self.assertRaises(InvalidArtifact):
            normalize(
                {"adapter": "query"}, artifact, ["quiet"], "candidate", test_passed=True
            )

    def test_action_transport_error_is_not_a_quality_failure(self):
        result = normalize(
            {"adapter": "actions"},
            {
                "model": "candidate",
                "results": [
                    {
                        "case": "quiet",
                        "status": "TimeoutException",
                        "passed": False,
                        "timeToReviewMs": 120,
                    }
                ],
            },
            ["quiet"],
            "candidate",
            test_passed=False,
        )
        self.assertEqual(result[0]["status"], "error")
        self.assertEqual(result[0]["latencyMs"], 120)

    def test_planning_objective_failure_cannot_be_hidden_by_heuristic_pass(self):
        row = {
            "cell": "quiet/candidate/baseline#1",
            "scenario": {"id": "quiet"},
            "constraints": {
                "prose": {"kind": "heuristic", "passed": True},
                "overlap": {"kind": "objective", "passed": False},
            },
        }
        result = normalize(
            {"adapter": "planning"},
            {"judgeBundle": [row]},
            ["quiet"],
            "candidate",
            test_passed=True,
        )
        self.assertEqual(result[0]["status"], "failed")
        self.assertEqual(result[0]["detail"], "overlap")

    def test_baseline_requires_same_source_and_reports_unpaired_query_fixtures(self):
        manifest = {
            "schemaVersion": 1,
            "revision": {"commit": "same"},
            "provider": "melious",
            "baseUrl": "endpoint",
            "samples": 3,
            "workers": 2,
            "batchSize": 8,
            "suites": [],
        }
        old_row = {
            "suite": "goals",
            "verdict": "checks_passed",
            "expected": 10,
            "counts": {"passed": 8},
            "meanLatencyMs": 100,
        }
        new_row = {**old_row, "counts": {"passed": 9}, "meanLatencyMs": 80}
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            (directory / "manifest.json").write_text(json.dumps(manifest))
            (directory / "summary.json").write_text(
                json.dumps({"model": "baseline", "suites": [old_row]})
            )
            result = compare_baseline(manifest, {"suites": [new_row]}, directory)
            self.assertAlmostEqual(result["suites"][0]["passRateDelta"], 0.1)
            self.assertEqual(result["suites"][0]["meanLatencyDeltaMs"], -20)
            self.assertEqual(
                compare_baseline(
                    {**manifest, "revision": {}}, {"suites": [new_row]}, directory
                )["status"],
                "incompatible",
            )
            old_row["suite"] = new_row["suite"] = "query"
            (directory / "summary.json").write_text(
                json.dumps({"model": "baseline", "suites": [old_row]})
            )
            self.assertEqual(
                compare_baseline(manifest, {"suites": [new_row]}, directory)["suites"][
                    0
                ]["status"],
                "not_comparable",
            )


if __name__ == "__main__":
    unittest.main()
