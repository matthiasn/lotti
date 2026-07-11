"""Tests for the independent task-agent evaluation judge."""

from __future__ import annotations

import json
import math
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tool import task_agent_model_eval_judge as judge


def _valid_judgment() -> dict:
    return {
        "factualGrounding": 4,
        "requiredCoverage": 3,
        "checklistQuality": 3.5,
        "summaryQuality": 4,
        "formatCompliance": 4,
        "overall": 3.8,
        "verdict": "good",
        "findings": ["Concise and grounded."],
    }


def _report() -> dict:
    return {
        "scenarios": [
            {
                "id": "scenario",
                "promptVariant": "production",
                "userMessage": "Synthetic task context",
                "expectedToolCalls": [],
                "requiresReport": True,
                "isFirstWake": True,
                "forbiddenToolNames": [],
                "requiredReportTermGroups": [],
                "forbiddenReportTerms": [],
                "forbiddenToolArgumentTerms": {},
            }
        ],
        "results": [
            {
                "profileName": "candidate",
                "providerModelId": "candidate-model",
                "scenarioId": "scenario",
                "failureCategory": "none",
                "qualityScore": 1,
                "toolCalls": [],
                "finalContent": None,
            }
        ],
    }


class JudgmentValidationTest(unittest.TestCase):
    def test_accepts_only_complete_bounded_judgments(self) -> None:
        self.assertTrue(judge._valid_judgment(_valid_judgment()))

        invalid_cases = []
        for value in (True, math.nan, math.inf, -0.1, 4.1, "4"):
            invalid = _valid_judgment()
            invalid["overall"] = value
            invalid_cases.append(invalid)
        invalid_cases.extend(
            [
                {**_valid_judgment(), "verdict": "unknown"},
                {**_valid_judgment(), "findings": ["finding"] * 6},
                {**_valid_judgment(), "findings": [1]},
            ]
        )

        for invalid in invalid_cases:
            with self.subTest(invalid=invalid):
                self.assertFalse(judge._valid_judgment(invalid))

    def test_selects_the_last_valid_product_report(self) -> None:
        draft = {
            "oneLiner": "Draft",
            "tldr": "Draft summary",
            "content": "Draft report",
        }
        product = {
            "oneLiner": "Product",
            "tldr": "Product summary",
            "content": "Product report",
        }
        result = {
            "toolCalls": [
                {"name": "set_task_title", "argumentsJson": "{}"},
                {
                    "name": "update_report",
                    "argumentsJson": json.dumps(draft),
                },
                {"name": "update_report", "argumentsJson": "not-json"},
                {
                    "name": "update_report",
                    "argumentsJson": json.dumps({"content": "incomplete"}),
                },
                {
                    "name": "update_report",
                    "argumentsJson": json.dumps(product),
                },
            ]
        }

        self.assertEqual(judge._product_report(result), product)
        self.assertIsNone(
            judge._product_report(
                {"toolCalls": [{"name": "update_report", "argumentsJson": "[]"}]}
            )
        )

    def test_judge_payload_identifies_the_product_report(self) -> None:
        scenario = _report()["scenarios"][0]
        result = _report()["results"][0]
        result["toolCalls"] = [
            {
                "name": "update_report",
                "argumentsJson": json.dumps(
                    {
                        "oneLiner": "Final",
                        "tldr": "Final summary",
                        "content": "Final report",
                    }
                ),
            }
        ]
        response = {
            "choices": [
                {"message": {"content": json.dumps(_valid_judgment())}}
            ]
        }

        with mock.patch.object(judge, "_post", return_value=response) as post:
            judgment, accounting = judge._judge_case(
                "https://example.com/v1", "key", "judge", scenario, result
            )

        request_body = post.call_args.args[2]
        payload = json.loads(request_body["messages"][1]["content"])
        self.assertEqual(
            payload["productReport"],
            {
                "oneLiner": "Final",
                "tldr": "Final summary",
                "content": "Final report",
            },
        )
        self.assertEqual(judgment, _valid_judgment())
        self.assertEqual(
            accounting,
            {"usage": {}, "environmentImpact": {}, "billingCost": {}},
        )

    def test_case_fingerprint_changes_with_the_judge_rubric(self) -> None:
        report = _report()
        scenario = report["scenarios"][0]
        result = report["results"][0]
        original = judge._case_fingerprint(scenario, result)

        with mock.patch.object(judge, "SYSTEM_PROMPT", "revised rubric"):
            revised = judge._case_fingerprint(scenario, result)

        self.assertNotEqual(original, revised)


class JudgeCliTest(unittest.TestCase):
    def test_writes_diagnostics_and_fails_unless_errors_are_allowed(self) -> None:
        for allow_errors in (False, True):
            with self.subTest(allow_errors=allow_errors), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                input_path = root / "input.json"
                json_path = root / "judged.json"
                markdown_path = root / "judged.md"
                input_path.write_text(json.dumps(_report()), encoding="utf-8")
                argv = [
                    "task_agent_model_eval_judge.py",
                    str(input_path),
                    "--json",
                    str(json_path),
                    "--markdown",
                    str(markdown_path),
                ]
                if allow_errors:
                    argv.append("--allow-errors")

                with (
                    mock.patch.object(sys, "argv", argv),
                    mock.patch.dict(os.environ, {"MELIOUS_API_KEY": "key"}),
                    mock.patch.object(
                        judge,
                        "_judge_case",
                        side_effect=RuntimeError("judge unavailable"),
                    ),
                ):
                    if allow_errors:
                        judge.main()
                    else:
                        with self.assertRaisesRegex(SystemExit, "1 judge case"):
                            judge.main()

                written = json.loads(json_path.read_text(encoding="utf-8"))
                self.assertEqual(
                    written["results"][0]["judge"]["verdict"], "parse_error"
                )
                self.assertTrue(markdown_path.is_file())


if __name__ == "__main__":
    unittest.main()
