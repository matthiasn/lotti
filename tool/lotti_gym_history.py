"""A public, aggregate-only run ledger; raw eval evidence stays outside Git."""

import json
import math
from collections import Counter
from contextlib import contextmanager
from decimal import Decimal
from pathlib import Path

from tool.penguin_query_eval import RUN_HISTORY_PATH


def duration_summary(directory, jobs):
    """Sum active invocations, excluding time spent idle between resumes."""
    sessions = sorted((json.loads(p.read_text()) for p in (directory / "sessions").glob("*.json")),
                      key=lambda session: session["startedAt"])
    durations = [s.get("durationSeconds") for s in sessions]
    known = [v for v in durations if isinstance(v, (int, float)) and math.isfinite(v) and v >= 0]
    rows = [r for job in jobs for attempt in job.get("attempts", [])
            for r in (attempt.get("results") or
                      [{"latencyMs": None} for _ in job.get("expected", [None])])
            if r.get("status") != "prepared"]
    latencies = [r["latencyMs"] for r in rows
                 if isinstance(r.get("latencyMs"), (int, float))
                 and math.isfinite(r["latencyMs"]) and r["latencyMs"] >= 0]
    complete = bool(sessions) and len(known) == len(sessions)
    return {
        "startedAt": sessions[0]["startedAt"] if sessions else None,
        "finishedAt": sessions[-1].get("finishedAt") if complete else None,
        "activeWallSeconds": round(sum(known), 6) if complete else None,
        "knownActiveWallSeconds": round(sum(known), 6),
        "invocations": len(sessions), "complete": complete,
        "summedExerciseSeconds": round(sum(latencies) / 1000, 6),
        "exerciseLatencyObservations": len(latencies),
        "exerciseLatencyComplete": bool(rows) and len(latencies) == len(rows),
    }


def history_record(directory, manifest, summary, jobs):
    """Project a run into bounded public metadata, never copy raw artifacts."""
    preparations = {s["id"] for s in manifest["suites"] if s["adapter"] == "preparation"}
    counts = Counter()
    expected = 0
    for job in jobs:
        if job["suite"] in preparations:
            continue
        expected += len(job["expected"])
        attempts = job.get("attempts", [])
        rows = attempts[-1].get("results", []) if attempts else []
        if rows:
            counts.update(row["status"] for row in rows)
        else:
            counts["error" if job["state"] == "error" else "not_assessed"] += len(job["expected"])
    timing = summary.get("duration") or duration_summary(directory, jobs)
    cost = summary.get("cost")
    if cost is None:
        # Old artifacts cannot establish a complete bill. Retain their known
        # subtotal for history without manufacturing missing helper/retry fees.
        known = sum((Decimal(str(s["credits"])) for s in summary["suites"]
                     if s.get("credits") is not None), Decimal(0))
        cost = {"currency": "EUR", "knownCostEur": str(known),
                "totalCostEur": None, "complete": False,
                "accounting": "legacy-artifact-subtotal"}
    return {
        "schemaVersion": 1, "runId": directory.name,
        "model": manifest["model"], "provider": manifest["provider"],
        "sourceCommit": manifest["revision"].get("commit"),
        "sourceDirty": manifest["revision"].get("dirty", False),
        "revisionValid": summary.get("revisionValid", True),
        "scope": manifest["scope"],
        "selection": {s["id"]: s["cases"] for s in manifest["suites"]},
        "samples": manifest["samples"], "workers": manifest["workers"],
        "batchSize": manifest.get("batchSize", 8),
        "judgeModel": manifest.get("judgeModel"),
        "verdict": summary["verdict"],
        "exercises": {"planned": expected, "passed": counts["passed"],
                      "failed": counts["failed"], "errors": counts["error"],
                      "reviewRequired": counts["review_required"],
                      "notAssessed": counts["not_assessed"],
                      "completed": counts["passed"] + counts["failed"] + counts["review_required"]},
        "duration": timing, "cost": cost,
    }


@contextmanager
def _history_lock(root):
    import fcntl
    path = root / "build/lotti_gym_history.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def record_history(root, record):
    """Atomically upsert one run; resume updates a row instead of double-counting."""
    path = root / RUN_HISTORY_PATH
    with _history_lock(root):
        rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()] if path.exists() else []
        rows = [row for row in rows if row["runId"] != record["runId"]]
        rows.append(record)
        rows.sort(key=lambda row: row["runId"])
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = root / "build/lotti_gym_history.jsonl.tmp"
        # lgtm[py/clear-text-storage-sensitive-data] history_record projects
        # only public aggregate fields; its tests reject private source fields.
        temporary.write_text("".join(json.dumps(row, sort_keys=True, ensure_ascii=False) + "\n" for row in rows))
        temporary.replace(path)


def aggregate_history(records):
    """Keep per-model sums honest when historical price or duration is missing."""
    grouped = {}
    for row in records:
        grouped.setdefault(row["model"], []).append(row)
    result = []
    for model, rows in sorted(grouped.items()):
        complete_cost = all(row["cost"]["complete"] for row in rows)
        complete_time = all(row["duration"]["complete"] for row in rows)
        known_cost = sum((Decimal(row["cost"]["knownCostEur"]) for row in rows), Decimal(0))
        known_seconds = sum(row["duration"]["knownActiveWallSeconds"] for row in rows)
        result.append({
            "model": model, "runs": len(rows),
            "exercises": {key: sum(row["exercises"][key] for row in rows)
                          for key in rows[0]["exercises"]},
            "knownCostEur": str(known_cost),
            "totalCostEur": str(known_cost) if complete_cost else None,
            "runsWithIncompleteCost": sum(not row["cost"]["complete"] for row in rows),
            "knownActiveWallSeconds": round(known_seconds, 6),
            "totalActiveWallSeconds": round(known_seconds, 6) if complete_time else None,
            "runsWithIncompleteDuration": sum(not row["duration"]["complete"] for row in rows),
        })
    return result
