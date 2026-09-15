#!/usr/bin/env python3
"""LottiGym: assess one model across Lotti's registered live workloads.

Uses only Python's standard library and the repository's pinned Flutter SDK.
Examples: python3 tool/lotti_gym.py assess --model MODEL [--dry-run]
          python3 tool/lotti_gym.py resume /path/to/run
"""

import argparse
import hashlib
import json
import os
import platform
import shlex
import subprocess
import sys
import threading
import time
import uuid
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, as_completed, wait
from contextlib import ExitStack, contextmanager
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin, urlparse

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tool.lotti_gym_results import (
    InvalidArtifact,
    compare_baseline,
    normalize,
    summarize,
    write_report,
)
from tool.lotti_gym_billing import BillingRelay, summarize_billing
from tool.lotti_gym_history import aggregate_history, duration_summary, history_record, record_history
from tool.penguin_query_eval import RUN_HISTORY_PATH, repository_revision, stop_process_tree
from tool.task_agent_model_eval_judge import DEFAULT_JUDGE_MODEL, _valid_judgment

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = Path.home() / ".local/share/lotti-gym/runs"
TERMINAL = {"complete", "failed", "review_required", "prepared"}


def atomic_json(path, value):
    """Replace a checkpoint atomically; a killed writer leaves the old one intact."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    # lgtm[py/clear-text-storage-sensitive-data] Connection credentials are
    # excluded before manifests, checkpoints and aggregate summaries reach here.
    temporary.write_text(
        json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    temporary.replace(path)


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def file_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def connection(environment, env_file):
    """Read only connection keys; exported settings precede inert dotenv values."""
    allowed = (
        "MELIOUS_API_KEY",
        "MELIOUS_BASE_URL",
        "UP_UPSTREAM_API_KEY",
        "UP_UPSTREAM_BASE_URL",
    )
    values = {}
    if env_file and env_file.exists():
        for line in env_file.read_text().splitlines():
            key, sep, value = line.removeprefix("export ").partition("=")
            if sep and key.strip() in allowed:
                tokens = shlex.split(value, comments=True)
                if len(tokens) > 1:
                    raise ValueError(f"Invalid dotenv value for {key.strip()}")
                values[key.strip()] = tokens[0] if tokens else ""
    return {
        canonical: environment.get(canonical)
        or environment.get(alias)
        or values.get(canonical)
        or values.get(alias)
        for canonical, alias in zip(allowed[:2], allowed[2:])
    }


def clean_environment(environment):
    """Ambient eval flags must never alter the manifest or enable another suite."""
    return {
        k: v
        for k, v in environment.items()
        if not (
            "_EVAL_" in k
            or k.startswith(("LOTTI_GYM_", "LOTTI_DAY_PLANNING_", "TASK_AGENT_EVAL_"))
            or k
            in (
                "MELIOUS_API_KEY",
                "MELIOUS_BASE_URL",
                "UP_UPSTREAM_API_KEY",
                "UP_UPSTREAM_BASE_URL",
            )
        )
    }


def validate_catalog(catalog, root=ROOT):
    """Reject empty/duplicate inventory and invalid dependencies before spending."""
    if catalog.get("schemaVersion") != 1:
        raise ValueError("Unsupported catalog version")
    suites = catalog.get("suites", [])
    ids = [s["id"] for s in suites]
    if not ids or len(set(ids)) != len(ids):
        raise ValueError("Catalog requires unique suites")
    for suite in suites:
        cases = suite["cases"]
        if (
            not cases
            or len(set(cases)) != len(cases)
            or any(not isinstance(c, str) or not c for c in cases)
        ):
            raise ValueError(f"Invalid cases in {suite['id']}")
        path = (root / suite["entryPoint"]).resolve()
        if not path.is_relative_to(root) or not path.is_file():
            raise ValueError("Catalog entry point must exist inside the repository")
        for dependency in suite["dependencies"]:
            if dependency not in ids[: ids.index(suite["id"])]:
                raise ValueError("Dependencies must precede their consumers")


def make_jobs(suites, samples, batch_size=8):
    """Checkpoint bounded batches; amortize Flutter startup and preserve queries."""
    if samples < 1:
        raise ValueError("Samples must be positive")
    jobs = []
    for suite in suites:
        size = (
            1
            if suite["adapter"] in ("wake", "workflow", "compaction", "preparation")
            else batch_size
        )
        groups = (
            [suite["cases"]]
            if suite["grouped"]
            else [
                suite["cases"][i : i + size]
                for i in range(0, len(suite["cases"]), size)
            ]
        )
        if suite["id"] == "task-conversation" and not suite["grouped"]:
            # The first existing contract case doubles as provider preflight;
            # do not send a full matrix to a missing model or invalid key.
            groups = [suite["cases"][:1]] + [
                suite["cases"][i : i + size]
                for i in range(1, len(suite["cases"]), size)
            ]
        for cases in groups:
            for sample in range(
                1, (1 if suite["adapter"] == "preparation" else samples) + 1
            ):
                key = f"{suite['id']}/{','.join(cases)}/{sample}"
                expected = (
                    [f"{c}/{arm}" for c in cases for arm in ("full", "hierarchical")]
                    if suite["adapter"] == "compaction"
                    else cases
                )
                jobs.append(
                    {
                        "id": key,
                        "directory": f"{suite['id']}-{fingerprint(key)[:16]}",
                        "suite": suite["id"],
                        "cases": cases,
                        "expected": expected,
                        "sample": sample,
                        "state": "pending",
                        "attempts": [],
                    }
                )
    return jobs


def job_environment(suite, job, manifest, directory, api_key, summary_path=None):
    """Translate the common model config into existing harness entry contracts."""
    env = clean_environment(os.environ)
    model, base_url = manifest["model"], manifest["baseUrl"]
    env.update(MELIOUS_API_KEY=api_key, MELIOUS_BASE_URL=base_url)
    prefix = suite["prefix"]
    env.update(
        {
            suite["gate"]: "1",
            f"{prefix}_MODEL": model,
            f"{prefix}_MODELS": model,
            f"{prefix}_PROVIDER_TYPE": "melious",
            f"{prefix}_BASE_URL": base_url,
            f"{prefix}_API_KEY": api_key,
            f"{prefix}_SCENARIOS": ",".join(job["cases"]),
            f"{prefix}_JSON": str(directory / "artifact.json"),
            f"{prefix}_MARKDOWN": str(directory / "artifact.md"),
            f"{prefix}_TEMPERATURE": "0",
            f"{prefix}_SAMPLES": "1",
            f"{prefix}_REPEATS": "1",
        }
    )
    env.update(suite["environment"])
    adapter = suite["adapter"]
    if adapter == "task":
        env[f"{prefix}_PROFILES"] = f"candidate={model}"
    elif adapter == "outcome":
        env.update(
            GOAL_AGENT_EVAL_PROVIDER_TYPE="melious",
            GOAL_AGENT_EVAL_BASE_URL=base_url,
            GOAL_AGENT_EVAL_API_KEY=api_key,
        )
    elif adapter == "wake":
        env.update(
            PENGUIN_WAKE_EVAL_SCENARIO=job["cases"][0],
            PENGUIN_WAKE_EVAL_OUTPUT=str(directory / "artifact.json"),
        )
    elif adapter in ("query", "actions", "preparation"):
        env.update(
            QUERY_EVAL_OUTPUT=str(directory / "artifact.json"),
            QUERY_EVAL_VARIANT="lotti-gym-production",
            QUERY_EVAL_PYTHON=sys.executable,
            QUERY_EVAL_CASES=",".join(job["cases"]),
            QUERY_ACTION_EVAL_CASES=",".join(job["cases"]),
            QUERY_EVAL_PREPARE_REPORTS="1" if adapter == "preparation" else "0",
        )
        if summary_path:
            env["QUERY_EVAL_SUMMARY_REPORTS"] = str(summary_path)
    elif adapter == "journey":
        env.update(
            DAY_PLANNING_EVAL_DIR=str(directory), DAY_PLANNING_EVAL_DATE="2030-01-15"
        )
    elif adapter == "compaction":
        env.update(
            GOAL_COMPACTION_EVAL_FIXTURES=",".join(job["cases"]),
            GOAL_COMPACTION_EVAL_STRATEGIES="full,hierarchical",
            GOAL_COMPACTION_EVAL_PACKET=str(directory / "artifact.json"),
            # Separate cache per fixture: concurrent samples must not race
            # on a shared partially written digest. Reuse on resume.
            GOAL_COMPACTION_EVAL_DIGEST_CACHE=str(directory.parent / "digests"),
        )
    return env


class Processes:
    """Own child process groups, including Flutter compiler descendants."""

    def __init__(self):
        self.lock = threading.Lock()
        self.active = set()
        self.cancelled = False

    def run(self, command, env, log, timeout, *, cwd=None):
        """Run an owned process, optionally in a private Flutter project."""
        with log.open("x", encoding="utf-8") as output:
            with self.lock:
                if self.cancelled:
                    return 130
                process = subprocess.Popen(
                    command,
                    cwd=cwd or ROOT,
                    env=env,
                    stdout=output,
                    stderr=subprocess.STDOUT,
                    start_new_session=os.name == "posix",
                )
                self.active.add(process)
            try:
                code = process.wait(timeout=timeout)
                with self.lock:
                    return 130 if self.cancelled else code
            except subprocess.TimeoutExpired:
                stop_process_tree(process)
                return 124
            except BaseException:
                # Warmup and preflight run on the main thread. An interrupt
                # must stop the child before finally removes it from active.
                stop_process_tree(process)
                raise
            finally:
                with self.lock:
                    self.active.discard(process)

    def cancel(self):
        with self.lock:
            self.cancelled = True
            active = list(self.active)
        for process in active:
            stop_process_tree(process)


def machine_outcome(log):
    """Require a completed, non-skipped test; ignore Flutter's display strings."""
    events = []
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict):
            events.append(event)
    done = [e for e in events if e.get("type") == "done"]
    executed = [
        e
        for e in events
        if e.get("type") == "testDone" and not e.get("skipped") and not e.get("hidden")
    ]
    return bool(
        done
        and done[-1].get("success") is True
        and executed
        and all(e.get("result") == "success" for e in executed)
    )


@contextmanager
def compiler_slot_pool(workers, directory=None):
    """Lease reusable kernel caches exclusively across concurrent assessments."""
    if os.name != "posix":
        raise ValueError("LottiGym currently requires Linux or macOS")
    import fcntl

    directory = directory or ROOT / "build/test_cache/lotti_gym_leases"
    directory.mkdir(parents=True, exist_ok=True)
    with ExitStack() as leases:
        slots = []
        index = 0
        while len(slots) < workers:
            lock = (directory / f"{index}.lock").open("a")
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                lock.close()
            else:
                leases.enter_context(lock)
                slots.append(str(index))
            index += 1
        yield slots


def worker_project(compiler_slot):
    """Reuse private Flutter build state while reading this checkout's source.

    Flutter hardcodes native and test asset output paths beneath its project
    directory, independently of kernel cache defines. Source links plus a
    private package config give each leased worker separate mutable outputs.
    No repository checkout or source copy is created.
    """
    if not compiler_slot.isdecimal():
        raise ValueError("Compiler slot must be a numeric lease identifier")
    directory = ROOT / "build/lotti_gym_workers" / compiler_slot
    directory.mkdir(parents=True, exist_ok=True)
    excluded = {"build", ".dart_tool", ".git", "coverage"}
    sources = {
        entry.name: entry for entry in ROOT.iterdir()
        if entry.name not in excluded and not entry.name.startswith(".env")
    }
    for link in directory.iterdir():
        if link.is_symlink() and link.name not in sources:
            link.unlink()
    for name, source in sources.items():
        link = directory / name
        if not link.is_symlink():
            link.symlink_to(source, target_is_directory=source.is_dir())
    config_path = ROOT / ".dart_tool/package_config.json"
    if not config_path.is_file():
        raise ValueError("Install repository dependencies before running LottiGym")
    config = read_json(config_path)
    for package in config["packages"]:
        resolved = urljoin(config_path.as_uri(), package["rootUri"])
        package["rootUri"] = (
            "../" if resolved.rstrip("/") == ROOT.as_uri() else resolved
        )
    atomic_json(directory / ".dart_tool/package_config.json", config)
    graph = ROOT / ".dart_tool/package_graph.json"
    if graph.is_file():
        atomic_json(directory / ".dart_tool/package_graph.json", read_json(graph))
    return directory


def flutter_test_command(entry_point, compiler_slot):
    """Select the leased cache used by both warmup and live inference.

    Flutter hashes Dart defines into its cache path. The unused define isolates
    concurrent compilers while permitting subsequent assessments to reuse it.
    """
    return [
        "fvm",
        "flutter",
        "test",
        "--no-pub",
        "--reporter",
        "json",
        f"--dart-define=LOTTI_GYM_COMPILER_SLOT={compiler_slot}",
        entry_point,
    ]


def run_job(suite, job, manifest, output, api_key, processes, summary_path, compiler_slot):
    number = len(job["attempts"]) + 1
    directory = output / "jobs" / job["directory"] / f"attempt-{number}"
    while directory.exists():
        number += 1
        directory = directory.with_name(f"attempt-{number}")
    directory.mkdir(parents=True)
    log = directory / "worker.jsonl"
    result = {
        "number": number,
        "directory": str(directory),
        "results": [],
        "jobId": job["id"],
        "manifestHash": fingerprint(manifest),
    }
    try:
        with BillingRelay(manifest["baseUrl"], directory / "billing.jsonl",
                          stage="preparation" if suite["adapter"] == "preparation" else "candidate") as billing:
            env = job_environment(suite, job, {**manifest, "baseUrl": billing.base_url},
                                  directory, api_key, summary_path)
            exit_code = processes.run(
                flutter_test_command(suite["entryPoint"], compiler_slot),
                env,
                log,
                5400 if suite["adapter"] == "compaction" else 1200,
                cwd=worker_project(compiler_slot),
            )
        result["exitCode"] = exit_code
        artifact_path = directory / "artifact.json"
        if suite["adapter"] == "journey":
            files = list(directory.glob("full-journey-*.json"))
            if len(files) == 1:
                artifact_path = files[0]
        result["artifact"] = str(artifact_path)
        if exit_code < 0 or exit_code in (124, 130) or not artifact_path.is_file():
            raise InvalidArtifact(
                "Worker timed out, was cancelled, or produced no artifact"
            )
        result["results"] = normalize(
            suite,
            read_json(artifact_path),
            job["expected"],
            manifest["model"],
            test_passed=exit_code == 0 and machine_outcome(log),
        )
        result["artifactHash"] = file_hash(artifact_path)
        statuses = {r["status"] for r in result["results"]}
        state = (
            "error"
            if "error" in statuses
            else "failed"
            if "failed" in statuses
            else "review_required"
            if "review_required" in statuses
            else "prepared"
            if statuses == {"prepared"}
            else "complete"
        )
    except (ValueError, KeyError, TypeError, OSError) as error:
        state = "error"
        result["error"] = (
            f"{type(error).__name__}: artifact or worker contract failed; inspect worker.jsonl"
        )
    result["state"] = state
    atomic_json(directory / "result.json", result)
    return result


def recover_jobs(output, manifest):
    """Rebuild checkpoints from the plan and immutable completed attempts.

    A killed coordinator may not have updated jobs.json. Never trust that file
    to decide which cases exist or which results are safe to reuse.
    """
    jobs = make_jobs(
        manifest["suites"], manifest["samples"], manifest.get("batchSize", 8)
    )
    for job in jobs:
        parent = output / "jobs" / job["directory"]
        records = list(parent.glob("attempt-*/result.json"))
        for path in sorted(
            records, key=lambda p: int(p.parent.name.removeprefix("attempt-"))
        ):
            result = read_json(path)
            if (
                result.get("jobId") != job["id"]
                or result.get("manifestHash") != fingerprint(manifest)
                or Path(result["directory"]) != path.parent
            ):
                raise ValueError("Checkpoint provenance does not match the manifest")
            if result.get("artifactHash"):
                artifact = Path(result["artifact"])
                if (
                    artifact.parent != path.parent
                    or not artifact.is_file()
                    or file_hash(artifact) != result["artifactHash"]
                ):
                    raise ValueError(
                        "Completed artifact changed or disappeared; start a new assessment"
                    )
            job["attempts"].append(result)
            job["state"] = result["state"]
    return jobs


@contextmanager
def run_lock(directory):
    """A kernel lock survives crashes without leaving a stale lock to delete."""
    if os.name != "posix":
        raise ValueError("LottiGym currently requires Linux or macOS")
    import fcntl

    with (directory / ".lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ValueError("Another process owns this run") from error
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def checkpoint(output, manifest, jobs):
    atomic_json(output / "jobs.json", jobs)
    summary = summarize(manifest, jobs)
    attempts = list((output / "jobs").glob("*/attempt-*"))
    prepared = {
        Path(attempt["directory"]).resolve()
        for job in jobs
        for attempt in job.get("attempts", [])
        if attempt.get("state") == "prepared"
    }
    untracked = sum(
        path.resolve() not in prepared and not (path / "billing.jsonl").exists()
        for path in attempts
    )
    untracked += sum(
        bool(attempt.get("judge")) and not list(Path(attempt["directory"]).glob("billing-judge-*.jsonl"))
        for job in jobs for attempt in job.get("attempts", [])
    )
    summary["cost"] = summarize_billing(
        sorted((output / "jobs").glob("*/attempt-*/billing*.jsonl")),
        untracked_attempts=untracked,
    )
    summary["duration"] = duration_summary(output, jobs)
    summary["revisionValid"] = not (output / "invalidated.json").exists()
    if not summary["revisionValid"]:
        summary["verdict"] = "incomplete"
    if manifest.get("baseline"):
        summary["baseline"] = compare_baseline(
            manifest, summary, Path(manifest["baseline"])
        )
    atomic_json(output / "summary.json", summary)
    write_report(output, summary, jobs)
    return summary


@contextmanager
def assessment_session(output, manifest, jobs, started_at, started_clock):
    """Finalize elapsed time and the public ledger even after interruption."""
    path = output / "sessions" / f"{uuid.uuid4().hex}.json"
    session = {"startedAt": started_at, "finishedAt": None, "durationSeconds": None}
    atomic_json(path, session)
    completed = False
    try:
        yield
        completed = True
    finally:
        source_changed = manifest["revision"] != repository_revision(ROOT)
        if source_changed:
            atomic_json(
                output / "invalidated.json",
                {"reason": "Checkout changed during assessment"},
            )
        session.update(finishedAt=datetime.now(timezone.utc).isoformat(),
                       durationSeconds=round(time.monotonic() - started_clock, 6))
        atomic_json(path, session)
        summary = checkpoint(output, manifest, jobs)
        record_history(ROOT, history_record(output, manifest, summary, jobs))
        if source_changed and completed:
            raise ValueError(
                "Checkout changed during assessment; results are not comparable"
            )


def judge_jobs(output, manifest, jobs, api_key, workers, processes):
    """Run the existing task rubric without repeating candidate inference.

    Judgments remain diagnostic. Other suite graders retain their documented
    review requirements; they must not borrow the task-specific rubric.
    """
    if not manifest.get("judgeModel"):
        return
    task_suites = {s["id"] for s in manifest["suites"] if s["adapter"] == "task"}
    eligible = [
        j
        for j in jobs
        if j["suite"] in task_suites
        and j["state"] in TERMINAL
        and j["attempts"][-1].get("judge", {}).get("state") != "complete"
    ]

    def judge(job):
        result = job["attempts"][-1]
        directory = Path(result["directory"])
        env = clean_environment(os.environ)
        env.update(
            MELIOUS_API_KEY=api_key,
            MELIOUS_BASE_URL=manifest["baseUrl"],
            # Authorize only the endpoint explicitly recorded for this run.
            TASK_AGENT_EVAL_ALLOWED_JUDGE_HOSTS=urlparse(manifest["baseUrl"]).hostname,
        )
        command = [
            sys.executable,
            "tool/task_agent_model_eval_judge.py",
            result["artifact"],
            "--json",
            str(directory / "judgments.json"),
            "--markdown",
            str(directory / "judgments.md"),
            "--judge-model",
            manifest["judgeModel"],
        ]
        with BillingRelay(manifest["baseUrl"],
                          directory / f"billing-judge-{uuid.uuid4().hex}.jsonl",
                          stage="judge") as billing:
            env.update(MELIOUS_BASE_URL=billing.base_url,
                       TASK_AGENT_EVAL_ALLOWED_JUDGE_HOSTS="127.0.0.1")
            code = processes.run(
                command, env, directory / f"judge-{uuid.uuid4().hex}.log", 3600
            )
        valid = False
        try:
            packet = read_json(directory / "judgments.json")
            rows = packet["results"]
            valid = (
                packet["judgeModel"] == manifest["judgeModel"]
                and sorted(r["scenarioId"] for r in rows) == sorted(job["cases"])
                and all(
                    r["providerModelId"] == manifest["model"]
                    and _valid_judgment(r["judge"])
                    for r in rows
                )
            )
        except (ValueError, OSError, KeyError, TypeError):
            pass
        record = {
            "model": manifest["judgeModel"],
            "state": "complete" if code == 0 and valid else "error",
            "exitCode": code,
        }
        atomic_json(directory / "result.json", {**result, "judge": record})
        return record

    pool = ThreadPoolExecutor(max_workers=workers)
    futures = []
    try:
        futures = [(job, pool.submit(judge, job)) for job in eligible]
        for job, future in futures:
            job["attempts"][-1]["judge"] = future.result()
            checkpoint(output, manifest, jobs)
    except BaseException:
        processes.cancel()
        raise
    finally:
        pool.shutdown(wait=True, cancel_futures=True)
        checkpoint(output, manifest, jobs)


def use_frozen_reports(output, manifest, jobs, bundle):
    """Materialize a validated, query-neutral fixture as a completed dependency."""
    job = next((j for j in jobs if j["suite"] == "query-reports"), None)
    if job is None:
        raise ValueError("--summary-reports requires a query suite")
    rows = bundle.get("reports", [])
    if bundle.get("sourceHash") != manifest["summarySourceHash"] or {
        r.get("ownerId") for r in rows
    } != set(manifest["summaryOwnerIds"]):
        raise ValueError("Frozen reports do not match the synthetic penguin corpus")
    results = normalize(
        {"adapter": "preparation"},
        bundle,
        ["reports"],
        bundle.get("model"),
        test_passed=True,
    )
    directory = output / "jobs" / job["directory"] / "attempt-1"
    directory.mkdir(parents=True)
    path = directory / "artifact.json"
    atomic_json(path, bundle)
    (directory / "worker.jsonl").write_text("Frozen fixture; no inference request.\n")
    result = {
        "number": 1,
        "directory": str(directory),
        "results": results,
        "jobId": job["id"],
        "manifestHash": fingerprint(manifest),
        "artifact": str(path),
        "artifactHash": file_hash(path),
        "state": "prepared",
        "exitCode": 0,
    }
    atomic_json(directory / "result.json", result)
    job["attempts"].append(result)
    job["state"] = "prepared"


def execute(output, manifest, jobs, api_key, workers, processes, compiler_slots):
    """Run independent exercises; preserve failures and dependency diagnostics."""
    suites = {s["id"]: s for s in manifest["suites"]}
    pending = [j for j in jobs if j["state"] not in TERMINAL]
    for job in pending:
        job["state"] = "pending"
    # Compile at most two private projects at once per assessment. Inference
    # concurrency is independent of this local CPU/memory warmup limit.
    entries = sorted({suites[j["suite"]]["entryPoint"] for j in pending})

    def warm_slot(slot):
        directory = worker_project(slot)
        for entry in entries:
            warm = output / f"warm-{uuid.uuid4().hex}.jsonl"
            if processes.run(
                flutter_test_command(entry, slot),
                clean_environment(os.environ),
                warm,
                600,
                cwd=directory,
            ) != 0:
                raise ValueError(f"Could not compile {entry}; see {warm.name}")

    with ThreadPoolExecutor(max_workers=min(workers, 2)) as warmers:
        try:
            futures = [warmers.submit(warm_slot, slot) for slot in compiler_slots]
            for future in as_completed(futures):
                future.result()
        except BaseException:
            # Stop children before the executor waits for active warmups.
            processes.cancel()
            raise
    idle_slots = list(compiler_slots)
    active = {}
    if pending and not any(
        j["state"] in TERMINAL and j["state"] != "prepared" for j in jobs
    ):
        probe = next(
            (j for j in pending if not suites[j["suite"]]["dependencies"]), None
        )
        if probe is not None:
            result = run_job(
                suites[probe["suite"]],
                probe,
                manifest,
                output,
                api_key,
                processes,
                None,
                compiler_slots[0],
            )
            probe["attempts"].append(result)
            probe["state"] = result["state"]
            pending.remove(probe)
            if probe["state"] == "error":
                for job in pending:
                    if probe["suite"] in suites[job["suite"]]["dependencies"]:
                        job["state"] = "blocked"
                checkpoint(output, manifest, jobs)
                print(
                    "Provider preflight failed; remaining exercises are not assessed.",
                    flush=True,
                )
                return
            checkpoint(output, manifest, jobs)
    pool = ThreadPoolExecutor(max_workers=workers)
    try:
        while pending or active:
            for job in list(pending):
                if len(active) >= workers:
                    break
                dependencies = [
                    j
                    for j in jobs
                    if j["suite"] in suites[job["suite"]]["dependencies"]
                ]
                if any(j["state"] in ("pending", "running") for j in dependencies):
                    continue
                pending.remove(job)
                if any(j["state"] != "prepared" for j in dependencies):
                    job["state"] = "blocked"
                    checkpoint(output, manifest, jobs)
                    continue
                summary_path = (
                    Path(dependencies[0]["attempts"][-1]["artifact"])
                    if dependencies
                    else None
                )
                job["state"] = "running"
                checkpoint(output, manifest, jobs)
                slot = idle_slots.pop()
                future = pool.submit(
                    run_job,
                    suites[job["suite"]],
                    job,
                    manifest,
                    output,
                    api_key,
                    processes,
                    summary_path,
                    slot,
                )
                active[future] = (job, slot)
            if active:
                finished, _ = wait(active, return_when=FIRST_COMPLETED)
                for future in finished:
                    job, slot = active.pop(future)
                    idle_slots.append(slot)
                    result = future.result()
                    job["attempts"].append(result)
                    job["state"] = result["state"]
                    checkpoint(output, manifest, jobs)
                    print(f"{job['state']}: {job['id']}", flush=True)
            elif pending:
                raise ValueError("No runnable jobs; invalid dependency graph")
    except BaseException:
        processes.cancel()
        raise
    finally:
        pool.shutdown(wait=True, cancel_futures=True)
        # A completed future is durable even if cancellation arrived before
        # the scheduler consumed it. Recover it on this or the next resume.
        for future, (job, _) in active.items():
            if future.done() and not future.cancelled() and future.exception() is None:
                result = future.result()
                job["attempts"].append(result)
                job["state"] = result["state"]
        checkpoint(output, manifest, jobs)


def discover(directory, processes, compiler_slot):
    """Discover using the same private Flutter project as live workers."""
    path = directory / "catalog.json"
    env = clean_environment(os.environ)
    env["LOTTI_GYM_CATALOG"] = str(path)
    status = processes.run(
        flutter_test_command("tool/lotti_gym_catalog.dart", compiler_slot),
        env,
        directory / "catalog.log",
        600,
        cwd=worker_project(compiler_slot),
    )
    if status != 0 or not path.is_file():
        raise ValueError(
            f"Catalog compilation failed; inspect {directory / 'catalog.log'}"
        )
    catalog = read_json(path)
    validate_catalog(catalog)
    return catalog


def positive(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("Must be positive")
    return number


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    assess = commands.add_parser(
        "assess", help="Assess all registered suites by default"
    )
    assess.add_argument("--model", required=True)
    assess.add_argument("--provider", choices=["melious"], default="melious")
    assess.add_argument("--base-url")
    assess.add_argument("--samples", type=positive, default=3)
    assess.add_argument(
        "--batch-size",
        type=positive,
        default=8,
        help="Cases per Flutter worker; smaller batches resume more precisely",
    )
    assess.add_argument(
        "--suites", help="Comma-separated subset; report explicitly marks partial scope"
    )
    assess.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT)
    assess.add_argument(
        "--dry-run",
        action="store_true",
        help="Compile inventory and write manifest without inference",
    )
    assess.add_argument(
        "--baseline",
        type=Path,
        help="Compare against a compatible previous run directory",
    )
    assess.add_argument(
        "--summary-reports",
        type=Path,
        help="Reuse a frozen synthetic query-report fixture",
    )
    assess.add_argument(
        "--judge-model",
        default=DEFAULT_JUDGE_MODEL,
        help="Diagnostic task-report judge",
    )
    assess.add_argument(
        "--no-judge",
        action="store_true",
        help="Skip optional task rubric; reported as not assessed",
    )
    resume = commands.add_parser(
        "resume",
        help="Resume missing/error jobs; preserve measured behavioral failures",
    )
    resume.add_argument("directory", type=Path)
    history = commands.add_parser("history", help="Summarize the checked-in run ledger")
    history.add_argument("--import-run", type=Path, action="append", default=[],
                         help="Record an existing run; missing historical prices stay unknown")
    history.add_argument("--model", help="Show totals for one model")
    for command in (assess, resume):
        command.add_argument("--workers", type=positive, default=2)
        command.add_argument("--env-file", type=Path, default=ROOT / ".env")
    args = parser.parse_args(argv)
    if args.command == "history":
        for directory in args.import_run:
            directory = directory.expanduser().resolve()
            manifest = read_json(directory / "manifest.json")
            summary = read_json(directory / "summary.json")
            record_history(ROOT, history_record(directory, manifest, summary, recover_jobs(directory, manifest)))
        path = ROOT / RUN_HISTORY_PATH
        rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()] if path.exists() else []
        if args.model:
            rows = [row for row in rows if row["model"] == args.model]
        print(json.dumps(aggregate_history(rows), indent=2))
        return 0
    started_at, started_clock = datetime.now(timezone.utc).isoformat(), time.monotonic()
    processes = Processes()
    output = None
    with ExitStack() as resources:
        try:
            compiler_slots = resources.enter_context(compiler_slot_pool(args.workers))
            conn = connection(os.environ, args.env_file)
            if args.command == "assess":
                if not args.model.strip() or any(
                    c.isspace() or c == "," for c in args.model
                ):
                    raise ValueError("Model must be one explicit provider model ID")
                base_url = (
                    args.base_url or conn["MELIOUS_BASE_URL"] or "https://api.melious.ai/v1"
                )
                parsed = urlparse(base_url)
                if (
                    parsed.scheme not in ("http", "https")
                    or not parsed.hostname
                    or parsed.username
                    or parsed.password
                    or parsed.query
                    or parsed.fragment
                    or (
                        parsed.scheme == "http"
                        and parsed.hostname not in ("localhost", "127.0.0.1", "::1")
                    )
                ):
                    raise ValueError(
                        "Base URL must be an HTTP endpoint without credentials, query or fragment"
                    )
                if not args.dry_run and not conn["MELIOUS_API_KEY"]:
                    raise ValueError("Set MELIOUS_API_KEY or use --env-file")
                root = args.output_root.expanduser().resolve()
                if root.is_relative_to(ROOT):
                    raise ValueError(
                        "Generated model output must remain outside the repository"
                    )
                output = root / (
                    datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ-")
                    + uuid.uuid4().hex[:12]
                )
                output.mkdir(parents=True)
                catalog = discover(output, processes, compiler_slots[0])
                bundle = (
                    read_json(args.summary_reports.expanduser().resolve())
                    if args.summary_reports
                    else None
                )
                requested = (
                    set(args.suites.split(","))
                    if args.suites
                    else {s["id"] for s in catalog["suites"]}
                )
                if not requested or requested - {s["id"] for s in catalog["suites"]}:
                    raise ValueError("Unknown or empty suite selection")
                for suite in reversed(catalog["suites"]):
                    if suite["id"] in requested:
                        requested.update(suite["dependencies"])
                suites = [s for s in catalog["suites"] if s["id"] in requested]
                manifest = {
                    "schemaVersion": 1,
                    "model": args.model,
                    "provider": args.provider,
                    "baseUrl": base_url,
                    "samples": args.samples,
                    "workers": args.workers,
                    "batchSize": args.batch_size,
                    "revision": repository_revision(ROOT),
                    "evaluationDate": datetime.now().astimezone().date().isoformat(),
                    "host": platform.node(),
                    "suites": suites,
                    "coverageGaps": catalog["coverageGaps"],
                    "excludedEntryPoints": catalog["excludedEntryPoints"],
                    "scope": "full" if len(suites) == len(catalog["suites"]) else "partial",
                    "baseline": str(args.baseline.expanduser().resolve())
                    if args.baseline
                    else None,
                    "judgeModel": None if args.no_judge else args.judge_model,
                    "billing": "provider-response-ledger-v1",
                    "summaryFixtureHash": fingerprint(bundle) if bundle else None,
                    "summarySourceHash": catalog["summarySourceHash"],
                    "summaryOwnerIds": catalog["summaryOwnerIds"],
                    "omittedSuites": [
                        s["id"] for s in catalog["suites"] if s["id"] not in requested
                    ],
                }
                atomic_json(output / "manifest.json", manifest)
                jobs = make_jobs(suites, args.samples, args.batch_size)
                if bundle is not None:
                    use_frozen_reports(output, manifest, jobs, bundle)
                checkpoint(output, manifest, jobs)
                print(
                    f"LottiGym: {len(suites)} suites, {len(jobs)} jobs, {sum(len(j['expected']) for j in jobs)} expected results.\nRun: {output}",
                    flush=True,
                )
                if args.dry_run:
                    return 0
            else:
                output = args.directory.expanduser().resolve()
                if output.is_relative_to(ROOT):
                    raise ValueError("Run must be outside the repository")
                manifest = read_json(output / "manifest.json")
                jobs = []  # Reconstructed from the immutable plan after acquiring the lock.
                if manifest.get("schemaVersion") != 1 or manifest[
                    "revision"
                ] != repository_revision(ROOT):
                    raise ValueError(
                        "Source revision changed; start a new assessment instead of mixing results"
                    )
                if manifest["workers"] != args.workers:
                    raise ValueError(
                        "Resume must use the original --workers for comparable latency"
                    )
                if (
                    manifest.get("evaluationDate")
                    != datetime.now().astimezone().date().isoformat()
                    or manifest.get("host") != platform.node()
                ):
                    raise ValueError(
                        "Resume must use the original host and calendar day; start a new run"
                    )
                if not conn["MELIOUS_API_KEY"]:
                    raise ValueError("Set MELIOUS_API_KEY or use --env-file")
            with run_lock(output):
                if (output / "invalidated.json").exists():
                    raise ValueError(
                        "Run was invalidated by a source change; start a new assessment"
                    )
                if args.command == "resume":
                    jobs = recover_jobs(output, manifest)
                with assessment_session(output, manifest, jobs, started_at, started_clock):
                    execute(
                        output, manifest, jobs, conn["MELIOUS_API_KEY"],
                        args.workers, processes, compiler_slots,
                    )
                    judge_jobs(
                        output, manifest, jobs, conn["MELIOUS_API_KEY"], args.workers, processes
                    )
                summary = checkpoint(output, manifest, jobs)
            print(
                f"Verdict: {summary['verdict']}. Report: {output / 'report.html'}",
                flush=True,
            )
            cost = summary["cost"]
            cost_label = "Run spend so far" if summary["verdict"] == "incomplete" else "Run price"
            # lgtm[py/clear-text-logging-sensitive-data] These fields are
            # validated numeric billing aggregates and public request counts.
            print(
                f"{cost_label} (EUR equivalent): {cost['totalCostEur']}"
                if cost["complete"] else
                f"Run price incomplete; known EUR {cost['knownCostEur']}, "
                f"{cost['requestsWithUnknownCost']} unpriced requests and "
                f"{cost['untrackedAttempts']} untracked attempts.",
                flush=True,
            )
            return {"incomplete": 2, "failed": 1, "review_required": 3}.get(
                summary["verdict"], 0
            )
        except KeyboardInterrupt:
            processes.cancel()
            print(
                f"Interrupted; resume with: python3 tool/lotti_gym.py resume {output}",
                file=sys.stderr,
            )
            return 130
        except (ValueError, OSError, KeyError) as error:
            processes.cancel()
            print(f"LottiGym: {error}", file=sys.stderr)
            return 2


if __name__ == "__main__":
    raise SystemExit(main())
