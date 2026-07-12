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

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tool import task_agent_model_eval_judge as judge


def _valid_judgment() -> dict:
    return {
        "factualGrounding": 4,
        "requiredCoverage": 3,
        "checklistQuality": 3,
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
        rubric_keys = (
            "factualGrounding",
            "requiredCoverage",
            "checklistQuality",
            "summaryQuality",
            "formatCompliance",
        )
        score_keys = (*rubric_keys, "overall")
        for key in score_keys:
            for value in (True, math.nan, math.inf, -0.1, 4.1, "4"):
                invalid = _valid_judgment()
                invalid[key] = value
                invalid_cases.append(invalid)
        for key in rubric_keys:
            invalid = _valid_judgment()
            invalid[key] = 2.5
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
            {
                "attemptCount": 1,
                "attempts": [
                    {"usage": {}, "environmentImpact": {}, "billingCost": {}}
                ],
                "usage": {},
                "environmentImpact": {},
                "billingCost": {},
            },
        )

    def test_retries_a_malformed_judgment_with_a_repair_turn(self) -> None:
        scenario = _report()["scenarios"][0]
        result = _report()["results"][0]
        malformed = {
            "choices": [{"message": {"content": "not json"}}],
            "usage": {"prompt_tokens": 10, "completion_tokens": 4},
            "environment_impact": {"energy_kwh": 0.1},
            "billing_cost": {"credits": "0.2", "paid_with": "credits"},
        }
        valid = {
            "choices": [
                {"message": {"content": json.dumps(_valid_judgment())}}
            ],
            "usage": {"prompt_tokens": 12, "completion_tokens": 5},
            "environment_impact": {"energy_kwh": 0.3},
            "billing_cost": {"credits": "0.4", "paid_with": "credits"},
        }

        with mock.patch.object(
            judge,
            "_post",
            side_effect=[malformed, valid],
        ) as post:
            judgment, accounting = judge._judge_case(
                "https://example.com/v1", "key", "judge", scenario, result
            )

        self.assertEqual(judgment, _valid_judgment())
        self.assertEqual(post.call_count, 2)
        retry_messages = post.call_args.args[2]["messages"]
        self.assertEqual(retry_messages[-2]["content"], "not json")
        self.assertEqual(retry_messages[-1]["content"], judge.REPAIR_PROMPT)
        self.assertEqual(accounting["attemptCount"], 2)
        self.assertEqual(accounting["usage"]["prompt_tokens"], 22)
        self.assertEqual(accounting["usage"]["completion_tokens"], 9)
        self.assertEqual(accounting["environmentImpact"]["energy_kwh"], 0.4)
        self.assertEqual(accounting["billingCost"]["credits"], "0.6")
        self.assertEqual(accounting["billingCost"]["paid_with"], "credits")

    def test_case_fingerprint_changes_with_the_judge_rubric(self) -> None:
        report = _report()
        scenario = report["scenarios"][0]
        result = report["results"][0]
        original = judge._case_fingerprint(scenario, result)

        with mock.patch.object(judge, "SYSTEM_PROMPT", "revised rubric"):
            revised = judge._case_fingerprint(scenario, result)

        self.assertNotEqual(original, revised)


class JudgeUrlValidationTest(unittest.TestCase):
    def test_post_accepts_an_explicitly_allowed_https_host(self) -> None:
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = "{}"

        with (
            mock.patch.dict(
                os.environ,
                {judge.ALLOWED_JUDGE_HOSTS_ENV: "example.com"},
                clear=True,
            ),
            mock.patch.object(
                judge.urllib.request,
                "urlopen",
                return_value=response,
            ) as urlopen,
        ):
            result = judge._post(
                "https://example.com/v1/chat/completions",
                "key",
                {"model": "judge"},
            )

        self.assertEqual(result, {})
        request = urlopen.call_args.args[0]
        self.assertEqual(
            request.full_url,
            "https://example.com/v1/chat/completions",
        )

    def test_post_rejects_invalid_or_disallowed_urls_before_urlopen(self) -> None:
        invalid_urls = (
            "file:///etc/passwd",
            "https:///missing-host",
            "https://user:secret@example.com/v1",
            "https://disallowed.example/v1",
        )

        with (
            mock.patch.dict(
                os.environ,
                {judge.ALLOWED_JUDGE_HOSTS_ENV: "example.com"},
                clear=True,
            ),
            mock.patch.object(judge.urllib.request, "urlopen") as urlopen,
        ):
            for url in invalid_urls:
                with self.subTest(url=url), self.assertRaises(ValueError):
                    judge._post(url, "key", {"model": "judge"})

        urlopen.assert_not_called()


class JudgeCliTest(unittest.TestCase):
    def test_rejects_a_disallowed_configured_base_url(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            input_path = root / "input.json"
            input_path.write_text(json.dumps(_report()), encoding="utf-8")
            argv = [
                "task_agent_model_eval_judge.py",
                str(input_path),
                "--json",
                str(root / "judged.json"),
                "--markdown",
                str(root / "judged.md"),
            ]

            with (
                mock.patch.object(sys, "argv", argv),
                mock.patch.dict(
                    os.environ,
                    {
                        "MELIOUS_API_KEY": "key",
                        "MELIOUS_BASE_URL": "https://disallowed.example/v1",
                    },
                    clear=True,
                ),
                mock.patch.object(judge, "_judge_case") as judge_case,
                self.assertRaisesRegex(SystemExit, "host is not allowed"),
            ):
                judge.main()

            judge_case.assert_not_called()

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
                    mock.patch.dict(
                        os.environ,
                        {"MELIOUS_API_KEY": "key"},
                        clear=True,
                    ),
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
