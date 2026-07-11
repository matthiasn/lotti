#!/usr/bin/env python3
"""Judge task-agent eval artifacts with an independent Melious model."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

DEFAULT_JUDGE_MODEL = "qwen3.5-122b-a10b"
SYSTEM_PROMPT = """
You are an independent evaluator of a personal task-management agent. Judge
only the supplied synthetic task context and captured model output. Do not
reward verbosity. Tool calls are proposed changes, not proof that work outside
the app was completed.

Return one JSON object with integer scores from 0 to 4 for:
- factualGrounding: no invented facts or falsely completed work
- requiredCoverage: material people, blockers, dates, and requested changes
- checklistQuality: concrete, distinct, verb-first actions with owners retained
- summaryQuality: concise, useful current-state synthesis rather than a tool log
- formatCompliance: user-facing language, no internal IDs, no empty sections,
  no redundant H1 title, and a useful oneLiner/tldr/content shape

Also return `overall` as a number from 0 to 4, `verdict` as excellent/good/weak/
failed, and `findings` as at most five concise strings. A missing update_report
is failed only when the scenario has `requiresReport: true`. When it is false,
reward a brief plain-text completion and penalize unnecessary report churn.
""".strip()


def _post(url: str, key: str, body: dict) -> dict:
    for attempt in range(3):
        request = urllib.request.Request(
            url,
            data=json.dumps(body).encode(),
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code < 500 or attempt == 2:
                raise
        except urllib.error.URLError:
            if attempt == 2:
                raise
        time.sleep(2**attempt)
    raise AssertionError("unreachable")


def _json_object(text: str) -> dict:
    cleaned = re.sub(r"^```(?:json)?|```$", "", text.strip(), flags=re.MULTILINE)
    start = cleaned.find("{")
    if start < 0:
        raise ValueError("judge response contained no JSON object")
    result, _ = json.JSONDecoder().raw_decode(cleaned[start:])
    if not isinstance(result, dict):
        raise ValueError("judge response was not a JSON object")
    return result


def _valid_judgment(judgment: dict) -> bool:
    score_keys = (
        "factualGrounding",
        "requiredCoverage",
        "checklistQuality",
        "summaryQuality",
        "formatCompliance",
        "overall",
    )
    return (
        all(isinstance(judgment.get(key), (int, float)) for key in score_keys)
        and judgment.get("verdict") in {"excellent", "good", "weak", "failed"}
        and isinstance(judgment.get("findings"), list)
    )


def _scenario_by_id(report: dict) -> dict[str, dict]:
    return {scenario["id"]: scenario for scenario in report["scenarios"]}


def _case_fingerprint(scenario: dict, result: dict) -> str:
    relevant = {
        "scenario": scenario,
        "toolCalls": result["toolCalls"],
        "failureCategory": result["failureCategory"],
        "finalContent": result.get("finalContent"),
    }
    encoded = json.dumps(relevant, ensure_ascii=False, sort_keys=True).encode()
    return hashlib.sha256(encoded).hexdigest()


def _display_path(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(Path.cwd().resolve()))
    except ValueError:
        return str(path)


def _judge_case(base_url: str, key: str, model: str, scenario: dict, result: dict) -> tuple[dict, dict]:
    payload = {
        "scenarioId": scenario["id"],
        "promptVariant": scenario["promptVariant"],
        "taskContext": scenario["userMessage"],
        "expectedToolCalls": scenario["expectedToolCalls"],
        "requiresReport": scenario["requiresReport"],
        "isFirstWake": scenario["isFirstWake"],
        "forbiddenToolNames": scenario["forbiddenToolNames"],
        "requiredReportTermGroups": scenario["requiredReportTermGroups"],
        "forbiddenReportTerms": scenario["forbiddenReportTerms"],
        "forbiddenToolArgumentTerms": scenario["forbiddenToolArgumentTerms"],
        "capturedToolCalls": result["toolCalls"],
        "finalAssistantContent": result.get("finalContent"),
        "deterministicFailure": result["failureCategory"],
    }
    response = _post(
        f"{base_url.rstrip('/')}/chat/completions",
        key,
        {
            "model": model,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": json.dumps(payload, ensure_ascii=False)},
            ],
            "temperature": 0,
            "max_tokens": 4000,
            "response_format": {"type": "json_object"},
            "stream": False,
        },
    )
    content = response["choices"][0]["message"]["content"]
    judgment = _json_object(content)
    if not _valid_judgment(judgment):
        raise ValueError("judge response omitted required rubric fields")
    return judgment, {
        "usage": response.get("usage", {}),
        "environmentImpact": response.get("environment_impact", {}),
        "billingCost": response.get("billing_cost", {}),
    }


def _write_markdown(path: Path, judged: dict) -> None:
    accounting = [case.get("judgeAccounting", {}) for case in judged["results"]]
    credits = sum(
        float(item.get("billingCost", {}).get("credits", 0) or 0)
        for item in accounting
    )
    energy = sum(
        float(item.get("environmentImpact", {}).get("energy_kwh", 0) or 0)
        for item in accounting
    )
    carbon = sum(
        float(item.get("environmentImpact", {}).get("carbon_g_co2", 0) or 0)
        for item in accounting
    )
    tokens = sum(
        int(item.get("usage", {}).get("total_tokens", 0) or 0)
        for item in accounting
    )
    lines = [
        "# Task-Agent Model Eval with Independent Judge",
        "",
        f"Judge: `{judged['judgeModel']}`",
        f"Judge accounting: {tokens} tokens, {credits:.7f} credits, "
        f"{energy:.6f} kWh, {carbon:.3f} g CO2.",
        "",
        "| Model | Scenario | Prompt | Deterministic | Judge | Verdict |",
        "| --- | --- | --- | ---: | ---: | --- |",
    ]
    for case in judged["results"]:
        score = case["judge"].get("overall", 0)
        lines.append(
            f"| {case['profileName']} | {case['scenarioId']} | {case['promptVariant']} | "
            f"{case['deterministicScore'] * 100:.0f}% | {score:.1f}/4 | "
            f"{case['judge'].get('verdict', 'parse_error')} |"
        )
    lines += ["", "## Findings"]
    for case in judged["results"]:
        lines += ["", f"### {case['profileName']} / {case['scenarioId']}"]
        findings = case["judge"].get("findings", [])
        lines.extend(f"- {finding}" for finding in findings)
        if not findings:
            lines.append("- No judge findings.")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--markdown", type=Path, required=True)
    parser.add_argument("--judge-model", default=os.getenv("TASK_AGENT_EVAL_JUDGE_MODEL", DEFAULT_JUDGE_MODEL))
    args = parser.parse_args()

    key = os.getenv("MELIOUS_API_KEY") or os.getenv("UP_UPSTREAM_API_KEY")
    if not key:
        raise SystemExit("Missing MELIOUS_API_KEY or UP_UPSTREAM_API_KEY")
    base_url = os.getenv("MELIOUS_BASE_URL") or os.getenv(
        "UP_UPSTREAM_BASE_URL", "https://api.melious.ai/v1"
    )
    report = json.loads(args.input.read_text(encoding="utf-8"))
    scenarios = _scenario_by_id(report)
    previous_by_case = {}
    if args.json.is_file():
        previous = json.loads(args.json.read_text(encoding="utf-8"))
        if previous.get("judgeModel") == args.judge_model:
            previous_by_case = {
                (case["profileName"], case["scenarioId"]): case
                for case in previous.get("results", [])
                if _valid_judgment(case.get("judge", {}))
            }
    judged_results = []
    for result in report["results"]:
        scenario = scenarios[result["scenarioId"]]
        case_key = (result["profileName"], result["scenarioId"])
        fingerprint = _case_fingerprint(scenario, result)
        previous_case = previous_by_case.get(case_key)
        if (
            previous_case is not None
            and previous_case.get("caseFingerprint") == fingerprint
        ):
            print(f"Reusing {case_key[0]} / {case_key[1]}", flush=True)
            judged_results.append(
                {**previous_case, "caseFingerprint": fingerprint}
            )
            continue
        print(f"Judging {result['profileName']} / {result['scenarioId']}...", flush=True)
        try:
            judgment, accounting = _judge_case(
                base_url, key, args.judge_model, scenario, result
            )
        except Exception as error:  # Preserve the rest of a comparison matrix.
            judgment = {"verdict": "parse_error", "overall": 0, "findings": [str(error)]}
            accounting = {}
        judged_results.append(
            {
                "profileName": result["profileName"],
                "providerModelId": result["providerModelId"],
                "scenarioId": result["scenarioId"],
                "promptVariant": scenario["promptVariant"],
                "caseFingerprint": fingerprint,
                "deterministicFailure": result["failureCategory"],
                "deterministicScore": result["qualityScore"],
                "judge": judgment,
                "judgeAccounting": accounting,
            }
        )
    judged = {
        "schemaVersion": 1,
        "kind": "lotti.taskAgentModelEvalJudgments",
        "judgeModel": args.judge_model,
        "source": _display_path(args.input),
        "results": judged_results,
    }
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.markdown.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(judged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _write_markdown(args.markdown, judged)


if __name__ == "__main__":
    main()
