"""Normalize existing Lotti eval artifacts without confusing execution and quality."""

import html
import json
import math
import statistics
from collections import Counter
from pathlib import Path


class InvalidArtifact(ValueError):
    """The artifact cannot establish what the manifest asked to measure."""


def _sum_known(values):
    known = []
    for value in values:
        if value is None:
            continue
        if (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not math.isfinite(value)
            or value < 0
        ):
            raise InvalidArtifact("Invalid cost observation")
        known.append(value)
    return sum(known) if known else None


def _object(value):
    if not isinstance(value, dict):
        raise InvalidArtifact("Expected a JSON object")
    return value


def _objects(value):
    if not isinstance(value, list):
        raise InvalidArtifact("Expected a JSON array of objects")
    return [_object(row) for row in value]


def normalize(suite, artifact, expected, model, *, test_passed):
    """Require exact case/model identity; retain infrastructure and review outcomes.

    Wake/workflow harnesses assert quality after writing their raw artifacts, so
    their machine-reporter outcome is part of the result, never a console grep.
    """
    artifact = _object(artifact)
    adapter = suite["adapter"]
    if adapter == "preparation":
        reports = _objects(artifact.get("reports", []))
        if (
            artifact.get("model") != model
            or not artifact.get("sourceHash")
            or not reports
            or not test_passed
        ):
            raise InvalidArtifact("Summary preparation did not complete")
        owners = [r.get("ownerId") for r in reports]
        if (
            None in owners
            or len(set(owners)) != len(owners)
            or any(
                not isinstance(r.get(k), str) or not r[k].strip()
                for r in reports
                for k in ("oneLiner", "tldr", "content")
            )
        ):
            raise InvalidArtifact("Summary preparation contains invalid reports")
        return [
            {
                "case": "reports",
                "status": "prepared",
                "latencyMs": None,
                "credits": None,
            }
        ]

    key = {"planning": "judgeBundle", "journey": "runs", "compaction": "cases"}.get(
        adapter, "results"
    )
    rows = [artifact] if adapter in ("wake", "workflow") else artifact.get(key)
    if not isinstance(rows, list) or not rows:
        raise InvalidArtifact(f"Missing non-empty {key}")
    results = []
    for row in _objects(rows):
        error = row.get("errorMessage") or row.get("error")
        passed = row.get("passed")
        review = False
        credits = row.get("credits")
        latency = row.get("latencyMs", row.get("totalMs"))
        detail = row.get("failureCategory") or ""
        actual_model = row.get(
            "providerModelId", row.get("modelId", artifact.get("model"))
        )
        case = row.get("scenarioId", row.get("case"))
        if adapter == "task":
            if not isinstance(row.get("failureCategory"), str):
                raise InvalidArtifact("Missing task failure category")
            passed = row["failureCategory"] == "none"
        elif adapter == "wake":
            case, actual_model = row.get("scenario"), row.get("model")
            passed = row.get("success") is True and test_passed
        elif adapter == "workflow":
            case = "workflow"
            actual_model = _object(row.get("model", {})).get("providerModelId")
            passed = (
                _object(row.get("wakeResult", {})).get("success") is True
                and test_passed
            )
            error = _object(row.get("wakeResult", {})).get("error")
            credits = _sum_known(
                e.get("credits") for e in _objects(row.get("consumptionEvents", []))
            )
        elif adapter == "planning":
            case = _object(row.get("scenario", {})).get("id")
            if row.get("cell") != f"{case}/{model}/baseline#1":
                raise InvalidArtifact("Unexpected planning model, variant or sample")
            actual_model = model
            constraints = _object(row.get("constraints", {}))
            for constraint in constraints.values():
                _object(constraint)
            objective = [
                c.get("passed")
                for c in constraints.values()
                if c.get("kind") == "objective" and c.get("passed") is not None
            ]
            passed = bool(objective) and all(v is True for v in objective)
            review = not objective
            error = _object(row.get("job", {})).get("error")
            latency = _object(row.get("job", {})).get("latencyMs")
            credits = _object(row.get("cost", {})).get("credits")
            detail = ", ".join(
                k
                for k, c in constraints.items()
                if c.get("kind") == "objective" and c.get("passed") is False
            )
        elif adapter == "journey":
            # This driver collects metrics, but does not implement a complete
            # quality grader. A successful journey must not become a free pass.
            error = error or row.get("metricsError")
            latency = row.get("userVisibleLatencyMs")
            passed = False
            review = True
            detail = "Journey metrics require review; no complete quality grader."
        elif adapter == "compaction":
            case = f"{row.get('fixtureId')}/{row.get('strategyId')}"
            passed = _object(row.get("wake", {})).get("statusCorrect") is True
            review = passed
            detail = "Fact recall and recommendation consistency require judging."
        elif adapter in ("query", "actions"):
            actual_model = artifact.get("model")
            if row.get("status") in ("error", "blocked"):
                error = row.get("errorType") or "inference error"
            if adapter == "actions":
                latency = row.get("timeToReviewMs")
                if row.get("status") != "complete":
                    error = "Action inference or harness error"
            credits = _sum_known(
                e.get("credits") for e in _objects(row.get("providerUsage", []))
            )
            if adapter == "query" and artifact.get("revisionUnchanged") is not True:
                raise InvalidArtifact("Query revision was not verified unchanged")
        if actual_model != model or not isinstance(case, str):
            raise InvalidArtifact("Missing or mismatched model/case identity")
        if error or detail in ("inferenceError", "inferenceFailed"):
            status = "error"
            # Do not copy raw provider errors into the consolidated report.
            detail = "Inference or harness error; inspect the local artifact."
        elif review:
            status = "review_required"
        elif passed is True:
            status = "passed"
        elif passed is False:
            status = "failed"
        else:
            raise InvalidArtifact("Missing boolean quality outcome")
        for value in (latency, credits):
            if value is not None and (
                isinstance(value, bool)
                or not isinstance(value, (int, float))
                or not math.isfinite(value)
                or value < 0
            ):
                raise InvalidArtifact("Invalid latency or cost telemetry")
        results.append(
            {
                "case": case,
                "status": status,
                "latencyMs": latency,
                "credits": credits,
                "detail": detail,
            }
        )
    actual = [r["case"] for r in results]
    if len(set(actual)) != len(actual) or set(actual) - set(expected):
        raise InvalidArtifact("Duplicate or unexpected case identity")
    if Counter(actual) != Counter(expected):
        if adapter == "query" and any(r["status"] == "error" for r in results):
            # The grouped query driver stops after authorization failures.
            # Preserve measured rows and account for the unattempted tail.
            results.extend(
                {
                    "case": case,
                    "status": "not_assessed",
                    "latencyMs": None,
                    "credits": None,
                    "detail": "Not attempted after an inference or dependency failure.",
                }
                for case in expected if case not in actual
            )
        else:
            raise InvalidArtifact(
                f"Case inventory mismatch: expected {expected}, received {actual}"
            )
    if not test_passed and all(
        r["status"] in ("passed", "review_required") for r in results
    ):
        raise InvalidArtifact("Worker failed despite successful artifact rows")
    return results


def summarize(manifest, jobs):
    """Summarize every scheduled cell, including work that never produced data."""
    suites = []
    for suite in manifest["suites"]:
        selected = [j for j in jobs if j["suite"] == suite["id"]]
        rows = []
        for job in selected:
            latest = job.get("attempts", [])[-1:]
            result = latest[0] if latest else {}
            rows.extend(
                result.get("results")
                or [{"case": c, "status": "not_assessed"} for c in job["expected"]]
            )
        counts = Counter(r["status"] for r in rows)
        if suite["adapter"] == "preparation":
            verdict = (
                "prepared"
                if counts.get("prepared") == len(rows) and rows
                else "incomplete"
            )
        elif counts["not_assessed"] or counts["error"] or not rows:
            verdict = "incomplete"
        elif counts["failed"]:
            verdict = "failed"
        else:
            # These are automated checks, not an unrestricted fitness certificate.
            verdict = (
                "review_required" if counts["review_required"] else "checks_passed"
            )
        latencies = [
            r["latencyMs"]
            for r in rows
            if isinstance(r.get("latencyMs"), (int, float))
            and math.isfinite(r["latencyMs"])
        ]
        attempt_rows = [
            row
            for job in selected
            for attempt in job.get("attempts", [])
            for row in (
                attempt.get("results") or [{"credits": None} for _ in job["expected"]]
            )
        ]
        credits = [r.get("credits") for r in attempt_rows]
        suites.append(
            {
                "suite": suite["id"],
                "verdict": verdict,
                "expected": len(rows),
                "counts": dict(counts),
                "meanLatencyMs": statistics.mean(latencies) if latencies else None,
                "p95LatencyMs": sorted(latencies)[math.ceil(0.95 * len(latencies)) - 1]
                if len(latencies) >= 20
                else None,
                "latencySamples": len(latencies),
                "credits": _sum_known(credits),
                "creditSamples": sum(c is not None for c in credits),
                "attemptedResults": len(attempt_rows),
                "creditsPerPassedCase": _sum_known(credits) / counts["passed"]
                if counts["passed"] and credits and all(c is not None for c in credits)
                else None,
                "taskJudging": dict(
                    Counter(
                        j.get("attempts", [])[-1]
                        .get("judge", {})
                        .get("state", "not_assessed")
                        if j.get("attempts")
                        else "not_assessed"
                        for j in selected
                    )
                )
                if suite["adapter"] == "task"
                else None,
            }
        )
    verdicts = {s["verdict"] for s in suites}
    overall = (
        "incomplete"
        if "incomplete" in verdicts
        else "failed"
        if "failed" in verdicts
        else "review_required"
    )
    return {
        "schemaVersion": 1,
        "model": manifest["model"],
        "provider": manifest["provider"],
        "verdict": overall,
        "suites": suites,
        "coverageGaps": manifest["coverageGaps"],
        "excludedEntryPoints": manifest["excludedEntryPoints"],
        "scope": manifest["scope"],
        "omittedSuites": manifest.get("omittedSuites", []),
        "judgeModel": manifest.get("judgeModel"),
        "revision": manifest["revision"],
    }


def compare_baseline(manifest, summary, baseline_directory):
    """Compare matched execution contracts; refuse stale or unpaired fixtures."""
    baseline = json.loads((baseline_directory / "manifest.json").read_text())
    old = json.loads((baseline_directory / "summary.json").read_text())
    keys = (
        "schemaVersion",
        "revision",
        "provider",
        "baseUrl",
        "samples",
        "workers",
        "batchSize",
        "suites",
        "host",
    )
    if (
        old.get("revisionValid") is False
        or summary.get("revisionValid") is False
        or any(manifest.get(k) != baseline.get(k) for k in keys)
    ):
        return {
            "status": "incompatible",
            "reason": "Source, suite, endpoint or execution settings differ.",
        }
    previous = {s["suite"]: s for s in old["suites"]}
    rows = []
    for current in summary["suites"]:
        before = previous.get(current["suite"])
        if (
            not before
            or before["verdict"] == "incomplete"
            or current["verdict"] == "incomplete"
        ):
            continue
        if current["suite"] == "day-planning" and manifest.get(
            "evaluationDate"
        ) != baseline.get("evaluationDate"):
            rows.append(
                {
                    "suite": current["suite"],
                    "status": "not_comparable",
                    "reason": "Day-dependent planning fixtures were evaluated on different dates.",
                }
            )
            continue
        if current["suite"] in ("query-reports", "query", "query-actions") and (
            not manifest.get("summaryFixtureHash")
            or manifest.get("summaryFixtureHash") != baseline.get("summaryFixtureHash")
        ):
            rows.append(
                {
                    "suite": current["suite"],
                    "status": "not_comparable",
                    "reason": "Reports are generated by each candidate; frozen common fixtures are required.",
                }
            )
            continue
        if current["suite"] == "query-reports":
            continue
        before_n, after_n = before["expected"], current["expected"]
        rows.append(
            {
                "suite": current["suite"],
                "status": "compared",
                "passRateDelta": current["counts"].get("passed", 0) / after_n
                - before["counts"].get("passed", 0) / before_n,
                "meanLatencyDeltaMs": current["meanLatencyMs"] - before["meanLatencyMs"]
                if current["meanLatencyMs"] is not None
                and before["meanLatencyMs"] is not None
                else None,
            }
        )
    return {"status": "compared", "model": old["model"], "suites": rows}


def write_report(directory, summary, jobs):
    """Write a portable, escaped HTML report with links to retained evidence."""
    esc = lambda value: html.escape(str(value))
    parts = [
        '<!doctype html><html lang="en"><meta charset="utf-8"><title>LottiGym</title>',
        f"<h1>LottiGym: {esc(summary['model'])}</h1><p>Verdict: <strong>{esc(summary['verdict'])}</strong>. Scope: {esc(summary['scope'])}.</p>",
        "<p>Automated checks do not certify unrestricted fitness. Missing cost is unknown. P95 requires at least 20 measurements. Latency includes production retries.</p>",
        "<table><thead><tr><th>Suite</th><th>Verdict</th><th>Passed / expected</th><th>Failures</th><th>Errors / missing</th><th>Mean ms</th><th>Reported credits / observations</th></tr></thead><tbody>",
    ]
    for suite in summary["suites"]:
        c = suite["counts"]
        values = [
            suite["suite"],
            suite["verdict"],
            f"{c.get('passed', 0)} / {suite['expected']}",
            c.get("failed", 0),
            c.get("error", 0) + c.get("not_assessed", 0),
            suite["meanLatencyMs"],
            f"{suite['credits']} / {suite['creditSamples']}",
        ]
        parts.append(
            "<tr>"
            + "".join(
                f"<td>{esc(v if v is not None else 'unknown')}</td>" for v in values
            )
            + "</tr>"
        )
    parts.append("</tbody></table><h2>Coverage limits</h2><ul>")
    for key, value in {
        **summary["coverageGaps"],
        **summary["excludedEntryPoints"],
    }.items():
        parts.append(f"<li>{esc(key)}: {esc(value)}</li>")
    for suite in summary.get("omittedSuites", []):
        parts.append(f"<li>{esc(suite)}: omitted by explicit suite selection</li>")
    if summary.get("baseline"):
        parts.append(
            "</ul><h2>Baseline comparison</h2><pre>"
            + esc(json.dumps(summary["baseline"], indent=2))
            + "</pre><ul>"
        )
    parts.append("</ul><h2>Exercise evidence</h2><ul>")
    for job in jobs:
        parts.append(f"<li>{esc(job['id'])}: {esc(job['state'])}<ul>")
        for attempt in job.get("attempts", []):
            path = Path(attempt["directory"]).relative_to(directory).as_posix()
            parts.append(
                f'<li><a href="{esc(path)}/result.json">Attempt {attempt["number"]}</a> · <a href="{esc(path)}/worker.jsonl">worker log</a></li>'
            )
        parts.append("</ul></li>")
        for attempt in job.get("attempts", []):
            if attempt.get("judge"):
                path = Path(attempt["directory"]).relative_to(directory).as_posix()
                parts.append(
                    f'<li>Task rubric ({esc(attempt["judge"]["model"])}): {esc(attempt["judge"]["state"])} · <a href="{esc(path)}/judgments.md">diagnostic judgments and accounting</a></li>'
                )
    parts.append("</ul></html>")
    (directory / "report.html").write_text("\n".join(parts), encoding="utf-8")
