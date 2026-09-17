"""Exercise LottiGym orchestration offline with deterministic worker artifacts."""

import contextlib
import io
import json
import os
import shutil
import tempfile
import threading
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import Mock, patch

from tool import lotti_gym as gym
from tool import task_agent_model_eval_judge as judge_cli


def suite(id="goals", adapter="agent", cases=None, dependencies=None, grouped=False):
    return {
        "id": id,
        "adapter": adapter,
        "cases": cases or ["quiet", "change"],
        "entryPoint": "test/features/agents/eval/goal/goal_agent_eval_live_test.dart",
        "prefix": "GOAL_AGENT_EVAL",
        "gate": "LOTTI_GOAL_AGENT_EVAL_LIVE",
        "dependencies": dependencies or [],
        "grouped": grouped,
        "environment": {},
    }


class WorkerProjectTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name) / "repo"
        self.root.mkdir()
        root_patch = patch.object(gym, "ROOT", self.root)
        root_patch.start()
        self.addCleanup(root_patch.stop)
        (self.root / "lib").mkdir()
        (self.root / "lib/source.dart").write_text("same production source")
        (self.root / "pubspec.yaml").write_text("name: lotti\n")
        (self.root / ".env").write_text("PRIVATE_PLACEHOLDER=unused")
        (self.root / ".dart_tool").mkdir()
        self.config = self.root / ".dart_tool/package_config.json"
        self.config.write_text(json.dumps({"configVersion": 2, "packages": [
            {"name": "lotti", "rootUri": "../", "packageUri": "lib/"},
            {"name": "dependency", "rootUri": "../../dependency/", "packageUri": "lib/"},
        ]}))

    def test_workers_share_source_but_isolate_native_assets_and_package_state(self):
        first, second = gym.worker_project("0"), gym.worker_project("1")
        self.assertNotEqual(first, second)
        self.assertTrue((first / "lib").is_symlink())
        (self.root / "lib/source.dart").write_text("updated production source")
        for worker in [first, second]:
            self.assertEqual((worker / "lib/source.dart").read_text(), "updated production source")
            self.assertFalse((worker / ".env").exists())
            self.assertFalse((worker / ".dart_tool").is_symlink())
            native = worker / "build/native_assets/linux"
            native.mkdir(parents=True, exist_ok=True)
            (native / "native_assets.json").write_text(worker.name)
        shutil.rmtree(first / "build/native_assets")
        self.assertEqual((second / "build/native_assets/linux/native_assets.json").read_text(), "1")
        self.assertFalse((self.root / "build/native_assets").exists())
        config = gym.read_json(first / ".dart_tool/package_config.json")
        self.assertEqual(config["packages"][0]["rootUri"], "../")
        self.assertEqual(config["packages"][1]["rootUri"], (self.root.parent / "dependency").as_uri() + "/")
        self.assertEqual(gym.read_json(self.config)["packages"][1]["rootUri"], "../../dependency/")

    def test_reuse_preserves_build_cache_and_refreshes_package_resolution(self):
        worker = gym.worker_project("0")
        cache = worker / "build/cached-kernel"
        cache.parent.mkdir()
        cache.write_text("compiled")
        config = gym.read_json(self.config)
        config["packages"][1]["rootUri"] = "../../new-dependency/"
        self.config.write_text(json.dumps(config))
        self.assertEqual(gym.worker_project("0"), worker)
        self.assertEqual(cache.read_text(), "compiled")
        self.assertEqual(gym.read_json(worker / ".dart_tool/package_config.json")["packages"][1]["rootUri"], (self.root.parent / "new-dependency").as_uri() + "/")

    def test_slot_cannot_escape_build_directory(self):
        for slot in ["../lib", "", "/tmp", "name"]:
            with self.subTest(slot=slot), self.assertRaises(ValueError):
                gym.worker_project(slot)


class GymTest(unittest.TestCase):
    def setUp(self):
        fixed_datetime = Mock(wraps=datetime)
        fixed_datetime.now.return_value = datetime(2030, 1, 15, 12, tzinfo=UTC)
        datetime_patch = patch.object(gym, "datetime", fixed_datetime)
        datetime_patch.start()
        self.addCleanup(datetime_patch.stop)
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.output = Path(temp.name)
        history_patch = patch.object(gym, "record_history")
        self.record_history = history_patch.start()
        self.addCleanup(history_patch.stop)
        project_patch = patch.object(gym, "worker_project", side_effect=lambda slot: self.output / f"worker-{slot}")
        project_patch.start()
        self.addCleanup(project_patch.stop)
        self.suite = suite()
        self.manifest = {
            "schemaVersion": 1,
            "model": "vendor/candidate",
            "provider": "melious",
            "baseUrl": "https://example.invalid/v1",
            "revision": {},
            "suites": [self.suite],
            "samples": 1,
            "workers": 1,
            "scope": "full",
            "coverageGaps": {},
            "excludedEntryPoints": {},
        }

    def test_every_case_and_sample_has_unique_stable_job_identity(self):
        jobs = gym.make_jobs([self.suite], 3, batch_size=1)
        self.assertEqual(len(jobs), 6)
        self.assertEqual(len({j["directory"] for j in jobs}), 6)
        self.assertEqual(jobs, gym.make_jobs([self.suite], 3, batch_size=1))
        self.assertEqual([j["sample"] for j in jobs[:3]], [1, 2, 3])
        with self.assertRaises(ValueError):
            gym.make_jobs([self.suite], 0)

    def test_every_live_worker_uses_a_cache_prepared_during_warmup(self):
        self.suite = suite(cases=["one", "two", "three", "four"])
        self.manifest["suites"] = [self.suite]
        jobs = gym.make_jobs([self.suite], 1, batch_size=1)
        processes = Mock()
        processes.run.side_effect = self.fake_worker
        gym.execute(self.output, self.manifest, jobs, "key", 2, processes, ["0", "1"])
        warmed = set()
        live = set()
        for call in processes.run.call_args_list:
            command, env = call.args[:2]
            flag = next(
                arg for arg in command
                if arg.startswith("--dart-define=LOTTI_GYM_COMPILER_SLOT=")
            )
            (live if self.suite["gate"] in env else warmed).add(flag)
            self.assertEqual(call.kwargs["cwd"], self.output / f"worker-{flag.split('=')[-1]}")
        self.assertTrue(live)
        self.assertTrue(live.issubset(warmed), (live, warmed))

    def test_warmup_interrupt_cancels_owned_processes_before_waiting(self):
        jobs = gym.make_jobs([self.suite], 1, batch_size=1)
        processes = Mock()
        processes.run.side_effect = KeyboardInterrupt
        with self.assertRaises(KeyboardInterrupt):
            gym.execute(self.output, self.manifest, jobs, "key", 2, processes, ["0", "1"])
        processes.cancel.assert_called_once_with()

    def test_later_warmup_failure_cancels_a_blocked_earlier_slot(self):
        jobs = gym.make_jobs([self.suite], 1, batch_size=1)
        first_started = threading.Event()
        cancelled = threading.Event()
        processes = Mock()
        processes.cancel.side_effect = cancelled.set

        def warmup(command, env, log, timeout, **kwargs):
            self.assertNotIn(self.suite["gate"], env)
            if kwargs["cwd"] == self.output / "worker-0":
                first_started.set()
                self.assertTrue(cancelled.wait(5), "Earlier slot waited instead of being cancelled")
                return 130
            self.assertTrue(first_started.wait(5))
            return 1

        processes.run.side_effect = warmup
        with self.assertRaisesRegex(ValueError, "Could not compile"):
            gym.execute(self.output, self.manifest, jobs, "key", 2, processes, ["0", "1"])
        processes.cancel.assert_called_once_with()

    def test_samples_of_one_exercise_run_in_sequence_and_exercises_in_parallel(self):
        self.suite = suite(cases=["a", "b", "c"])
        self.manifest.update(suites=[self.suite], workers=3, samples=3)
        jobs = gym.make_jobs([self.suite], 3, batch_size=1)
        job_of = {job["directory"]: job for job in jobs}
        lock = threading.Lock()
        running = []
        overlaps = []
        finished = []
        workers_used = {}
        # Exercises a, b and c must be in flight together at least once.
        together = threading.Barrier(3, timeout=5)
        processes = Mock()

        def worker(command, env, log, timeout, **kwargs):
            if self.suite["gate"] not in env:
                return self.fake_worker(command, env, log, timeout, **kwargs)
            job = job_of[next(d for d in job_of if d in str(log))]
            with lock:
                overlaps.extend(
                    (job["id"], other["id"]) for other in running
                    if other["cases"] == job["cases"]
                )
                earlier = [
                    j["id"] for j in jobs
                    if j["cases"] == job["cases"] and j["sample"] < job["sample"]
                ]
                self.assertTrue(set(earlier) <= set(finished), (job["id"], finished))
                running.append(job)
                workers_used.setdefault(tuple(job["cases"]), set()).add(str(kwargs.get("cwd")))
            if job["sample"] == 2:
                together.wait()
            try:
                return self.fake_worker(command, env, log, timeout, **kwargs)
            finally:
                with lock:
                    running.remove(job)
                    finished.append(job["id"])

        processes.run.side_effect = worker
        gym.execute(self.output, self.manifest, jobs, "key", 3, processes, ["0", "1", "2"])
        self.assertEqual(sum(len(job["attempts"]) for job in jobs), 9)
        self.assertEqual(overlaps, [])
        self.assertFalse(together.broken)
        # Each exercise is one lane: all its samples ran on the same worker.
        self.assertEqual({cases: len(used) for cases, used in workers_used.items()},
                         {("a",): 1, ("b",): 1, ("c",): 1})

    def test_an_errored_sample_does_not_stall_its_exercise(self):
        self.suite = suite(cases=["a", "b"])
        self.manifest.update(suites=[self.suite], samples=2)
        jobs = gym.make_jobs([self.suite], 2, batch_size=1)
        errored = next(j for j in jobs if j["cases"] == ["b"] and j["sample"] == 1)
        later = next(j for j in jobs if j["cases"] == ["b"] and j["sample"] == 2)
        processes = Mock()

        def worker(command, env, log, timeout, **kwargs):
            if errored["directory"] in str(log):
                return 1  # No artifact: an infrastructure error, not a verdict.
            return self.fake_worker(command, env, log, timeout, **kwargs)

        processes.run.side_effect = worker
        gym.execute(self.output, self.manifest, jobs, "key", 1, processes, ["0"])
        self.assertEqual(errored["state"], "error")
        self.assertEqual(later["state"], "failed")
        self.assertTrue(all(job["attempts"] for job in jobs), jobs)

    def test_eight_paid_workers_run_concurrently_after_preflight(self):
        self.suite = suite(cases=[str(i) for i in range(9)])
        self.manifest.update(suites=[self.suite], workers=8)
        jobs = gym.make_jobs([self.suite], 1, batch_size=1)
        barrier = threading.Barrier(8, timeout=5)
        preflight_done = threading.Event()
        processes = Mock()

        def worker(command, env, log, timeout, **kwargs):
            if self.suite["gate"] in env:
                if preflight_done.is_set():
                    barrier.wait()
                else:
                    preflight_done.set()
            return self.fake_worker(command, env, log, timeout, **kwargs)

        processes.run.side_effect = worker
        gym.execute(self.output, self.manifest, jobs, "key", 8, processes, [str(i) for i in range(8)])
        self.assertTrue(preflight_done.is_set())
        self.assertFalse(barrier.broken)
        self.assertTrue(all(job["state"] == "failed" for job in jobs), jobs)
        self.assertEqual(sum(len(job["attempts"]) for job in jobs), 9)

    def _failing_probe_worker(self, message, fail_times):
        """A worker that writes `message` as an inference error `fail_times`."""
        state = {"calls": 0}

        def worker(command, env, log, timeout, **kwargs):
            if self.suite["gate"] not in env:
                return self.fake_worker(command, env, log, timeout, **kwargs)
            state["calls"] += 1
            if state["calls"] > fail_times:
                return self.fake_worker(command, env, log, timeout, **kwargs)
            log.write_text(
                "\n".join(
                    json.dumps(e)
                    for e in [
                        {"type": "testDone", "result": "error", "error": message},
                        {"type": "done", "success": False},
                    ]
                )
            )
            gym.atomic_json(
                Path(env["GOAL_AGENT_EVAL_JSON"]),
                {
                    "results": [
                        {
                            "modelId": self.manifest["model"],
                            "scenarioId": case,
                            "passed": False,
                            "failureCategory": "inferenceError",
                            "errorMessage": message,
                        }
                        for case in env["GOAL_AGENT_EVAL_SCENARIOS"].split(",")
                    ]
                },
            )
            return 1

        return worker, state

    def test_a_transient_preflight_failure_is_retried_and_the_matrix_runs(self):
        # One 503 on the single probe used to abandon the whole matrix.
        patcher = patch.object(gym, "PREFLIGHT_RETRY_DELAY_S", 0)
        patcher.start()
        self.addCleanup(patcher.stop)
        jobs = gym.make_jobs([self.suite], 1, batch_size=1)
        processes = Mock()
        worker, state = self._failing_probe_worker(
            "MeliousInferenceException (HTTP 503): provider encountered an error",
            fail_times=2,
        )
        processes.run.side_effect = worker

        gym.execute(self.output, self.manifest, jobs, "key", 1, processes, ["0"])

        probe = next(j for j in jobs if len(j["attempts"]) > 1)
        self.assertEqual(
            [a["state"] for a in probe["attempts"]],
            ["error", "error", "failed"],
            "two transient errors, then the probe lands",
        )
        self.assertGreaterEqual(state["calls"], 3)
        self.assertTrue(all(job["state"] != "blocked" for job in jobs), jobs)

    def test_a_transient_failure_that_never_clears_stops_after_the_retries(self):
        patcher = patch.object(gym, "PREFLIGHT_RETRY_DELAY_S", 0)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.manifest.update(suites=[self.suite, suite(id="dependent", dependencies=["goals"])])
        jobs = gym.make_jobs(self.manifest["suites"], 1, batch_size=1)
        processes = Mock()
        worker, state = self._failing_probe_worker("HTTP 503 Service Unavailable", fail_times=99)
        processes.run.side_effect = worker

        gym.execute(self.output, self.manifest, jobs, "key", 1, processes, ["0"])

        self.assertEqual(state["calls"], gym.PREFLIGHT_RETRIES + 1)
        self.assertTrue(any(job["state"] == "blocked" for job in jobs), jobs)

    def test_a_rejected_key_is_not_retried(self):
        patcher = patch.object(gym, "PREFLIGHT_RETRY_DELAY_S", 0)
        patcher.start()
        self.addCleanup(patcher.stop)
        jobs = gym.make_jobs([self.suite], 1, batch_size=1)
        processes = Mock()
        worker, state = self._failing_probe_worker(
            "MeliousInferenceException (HTTP 401): Invalid API key",
            fail_times=99,
        )
        processes.run.side_effect = worker

        gym.execute(self.output, self.manifest, jobs, "key", 1, processes, ["0"])

        self.assertEqual(state["calls"], 1, "a rejected key repeats forever")

    def test_a_resumed_run_does_not_reset_the_preflight_retry_budget(self):
        # An interrupted run that already spent a paid probe attempt resumes
        # with the rest of the budget, never a fresh one.
        patcher = patch.object(gym, "PREFLIGHT_RETRY_DELAY_S", 0)
        patcher.start()
        self.addCleanup(patcher.stop)
        jobs = gym.make_jobs([self.suite], 1, batch_size=1)
        jobs[0].update(
            state="error",
            attempts=[
                {
                    "state": "error",
                    "number": number,
                    "exitCode": code,
                    "results": [],
                    "directory": str(
                        self.output / "jobs" / jobs[0]["directory"] / f"attempt-{number}"
                    ),
                }
                for number, code in enumerate([1, gym.CANCELLED_EXIT_CODE], start=1)
            ],
        )
        processes = Mock()
        worker, state = self._failing_probe_worker("HTTP 503 Service Unavailable", fail_times=99)
        processes.run.side_effect = worker

        gym.execute(self.output, self.manifest, jobs, "key", 1, processes, ["0"])

        self.assertEqual(
            state["calls"],
            gym.PREFLIGHT_RETRIES,
            "one spent attempt leaves three; the cancelled one costs nothing",
        )

    def test_compiler_leases_isolate_active_runs_and_reuse_released_caches(self):
        leases = self.output / "leases"
        with gym.compiler_slot_pool(2, leases) as first:
            with gym.compiler_slot_pool(2, leases) as second:
                self.assertTrue(set(first).isdisjoint(second))
            with gym.compiler_slot_pool(2, leases) as reused:
                self.assertEqual(reused, second)
        with gym.compiler_slot_pool(2, leases) as released:
            self.assertEqual(released, first)

    def test_query_dependency_runs_once_and_followups_share_a_worker(self):
        prep = suite("query-reports", "preparation", ["reports"])
        query = suite("query", "query", ["local", "follow_up"], ["query-reports"], True)
        jobs = gym.make_jobs([prep, query], 3)
        self.assertEqual(len(jobs), 4)
        self.assertEqual(jobs[1]["expected"], ["local", "follow_up"])

    def test_compaction_preserves_paired_full_and_hierarchical_arms(self):
        jobs = gym.make_jobs([suite("compaction", "compaction", ["old"])], 1)
        self.assertEqual(jobs[0]["expected"], ["old/full", "old/hierarchical"])

    def test_environment_is_explicit_and_secret_never_enters_manifest(self):
        job = gym.make_jobs([self.suite], 1, batch_size=1)[0]
        with patch.dict(
            os.environ,
            {
                "GOAL_AGENT_EVAL_SCENARIOS": "unrelated",
                "GOAL_AGENT_EVAL_STRICT": "1",
                "LOTTI_QUERY_EVAL_LIVE": "1",
            },
            clear=True,
        ):
            env = gym.job_environment(
                self.suite, job, self.manifest, self.output, "synthetic-key"
            )
        self.assertEqual(env["GOAL_AGENT_EVAL_MODELS"], "vendor/candidate")
        self.assertEqual(env["GOAL_AGENT_EVAL_SCENARIOS"], "quiet")
        self.assertNotIn("GOAL_AGENT_EVAL_STRICT", env)
        self.assertNotIn("LOTTI_QUERY_EVAL_LIVE", env)
        self.assertEqual(env["GOAL_AGENT_EVAL_API_KEY"], "synthetic-key")
        self.assertNotIn("synthetic-key", json.dumps(self.manifest))

    def test_connection_file_is_inert_and_exported_alias_precedes_file(self):
        dotenv = self.output / ".env"
        dotenv.write_text(
            'MELIOUS_API_KEY="file key"\nMELIOUS_BASE_URL="https://example.invalid"\nUNRELATED_SECRET="not loaded"\n'
        )
        conn = gym.connection({"UP_UPSTREAM_API_KEY": "exported key"}, dotenv)
        self.assertEqual(conn["MELIOUS_API_KEY"], "exported key")
        self.assertEqual(set(conn), {"MELIOUS_API_KEY", "MELIOUS_BASE_URL"})

    def test_empty_connection_placeholders_do_not_override_exported_values(self):
        dotenv = self.output / ".env"
        dotenv.write_text('MELIOUS_API_KEY=\nMELIOUS_BASE_URL= # optional\n')
        self.assertEqual(
            gym.connection({"MELIOUS_API_KEY": "exported"}, dotenv),
            {"MELIOUS_API_KEY": "exported", "MELIOUS_BASE_URL": None},
        )
        self.assertIsNone(gym.connection({}, dotenv)["MELIOUS_API_KEY"])

    def test_signal_exit_after_artifact_is_resumable_not_a_model_failure(self):
        wake = suite("task-wake", "wake", ["quiet"])
        self.manifest["suites"] = [wake]
        job = gym.make_jobs([wake], 1)[0]
        processes = Mock()

        def interrupted(command, env, log, timeout, **kwargs):
            gym.atomic_json(log.parent / "artifact.json", {
                "model": self.manifest["model"], "scenario": "quiet", "success": True,
            })
            log.write_text('{"type":"testStart"}\n')
            return -15

        processes.run.side_effect = interrupted
        result = gym.run_job(wake, job, self.manifest, self.output, "key", processes, None, "0")
        self.assertEqual(result["state"], "error")
        self.assertEqual(result["results"], [])
        self.assertEqual(gym.recover_jobs(self.output, self.manifest)[0]["state"], "error")

    def test_cancellation_normalizes_child_signal_status(self):
        processes = gym.Processes()
        child = Mock()

        def finish(timeout):
            processes.cancel()
            return -15

        child.wait.side_effect = finish
        with (
            patch.object(gym.subprocess, "Popen", return_value=child),
            patch.object(gym, "stop_process_tree"),
        ):
            status = processes.run(["worker"], {}, self.output / "cancel.log", 10)
        self.assertEqual(status, 130)
        self.assertFalse(processes.active)

    def test_invalid_catalog_rejects_empty_cases_and_unknown_dependencies(self):
        for bad in (
            {**self.suite, "cases": []},
            {**self.suite, "cases": ["a", "a"]},
            {**self.suite, "dependencies": ["absent"]},
        ):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                gym.validate_catalog({"schemaVersion": 1, "suites": [bad]})

    def test_machine_result_requires_real_non_skipped_test(self):
        log = self.output / "worker.jsonl"
        for events in (
            [{"type": "done", "success": True}],
            [
                {"type": "testDone", "result": "success", "skipped": True},
                {"type": "done", "success": True},
            ],
            [],
        ):
            log.write_text(
                "All tests passed\n" + "\n".join(json.dumps(e) for e in events)
            )
            self.assertFalse(gym.machine_outcome(log))
        log.write_text(
            "\n".join(
                json.dumps(e)
                for e in [
                    {
                        "type": "testDone",
                        "result": "success",
                        "skipped": False,
                        "hidden": False,
                    },
                    {"type": "done", "success": True},
                ]
            )
        )
        self.assertTrue(gym.machine_outcome(log))

    def fake_worker(self, command, env, log, timeout, **kwargs):
        log.write_text(
            "\n".join(
                json.dumps(e)
                for e in [
                    {
                        "type": "testDone",
                        "result": "success",
                        "skipped": False,
                        "hidden": False,
                    },
                    {"type": "done", "success": True},
                ]
            )
        )
        if "GOAL_AGENT_EVAL_JSON" in env:
            gym.atomic_json(
                Path(env["GOAL_AGENT_EVAL_JSON"]),
                {
                    "results": [
                        {
                            "modelId": self.manifest["model"],
                            "scenarioId": case,
                            "passed": False,
                            "failureCategory": "noOpViolated",
                        }
                        for case in env["GOAL_AGENT_EVAL_SCENARIOS"].split(",")
                    ]
                },
            )
        return 0

    def test_single_call_finishes_all_cases_retains_failures_and_resumes_without_spend(
        self,
    ):
        jobs = gym.make_jobs([self.suite], 1, batch_size=1)
        processes = Mock()
        processes.run.side_effect = self.fake_worker
        with contextlib.redirect_stdout(io.StringIO()):
            gym.execute(self.output, self.manifest, jobs, "key", 1, processes, ["0"])
        self.assertEqual([j["state"] for j in jobs], ["failed", "failed"])
        self.assertEqual(
            gym.read_json(self.output / "summary.json")["verdict"], "failed"
        )
        self.assertTrue((self.output / "report.html").is_file())
        calls = processes.run.call_count
        gym.execute(self.output, self.manifest, jobs, "key", 1, processes, ["0"])
        self.assertEqual(processes.run.call_count, calls)

    def test_missing_artifact_is_error_and_retry_keeps_prior_attempt(self):
        job = gym.make_jobs([self.suite], 1)[0]
        processes = Mock()
        processes.run.side_effect = lambda command, env, log, timeout, **kwargs: (
            log.write_text("") and 0
        )
        result = gym.run_job(
            self.suite, job, self.manifest, self.output, "key", processes, None, "0"
        )
        self.assertEqual(result["state"], "error")
        job["attempts"].append(result)
        processes.run.side_effect = self.fake_worker
        second = gym.run_job(
            self.suite, job, self.manifest, self.output, "key", processes, None, "0"
        )
        self.assertEqual(second["number"], 2)
        self.assertTrue(Path(result["directory"]).is_dir())
        self.assertEqual(second["state"], "failed")

    def test_batched_workers_preserve_the_complete_case_inventory(self):
        cases = [f"case{i}" for i in range(19)]
        jobs = gym.make_jobs([suite(cases=cases)], 1)
        self.assertEqual([len(j["cases"]) for j in jobs], [8, 8, 3])
        self.assertEqual([c for j in jobs for c in j["expected"]], cases)

    def test_dependency_failure_blocks_consumer_without_calling_model(self):
        prep = suite("query-reports", "preparation", ["reports"])
        query = suite("query", "query", ["local"], ["query-reports"])
        self.manifest["suites"] = [prep, query]
        jobs = gym.make_jobs([prep, query], 1)
        processes = Mock()
        processes.run.side_effect = lambda command, env, log, timeout, **kwargs: (
            log.write_text(""),
            0,
        )[1]
        with contextlib.redirect_stdout(io.StringIO()):
            gym.execute(self.output, self.manifest, jobs, "key", 1, processes, ["0"])
        self.assertEqual([j["state"] for j in jobs], ["error", "blocked"])
        self.assertEqual(processes.run.call_count, 2)  # one build + preparation

    def test_kernel_lock_prevents_two_writers_and_releases_after_exception(self):
        with (
            gym.run_lock(self.output),
            self.assertRaises(ValueError),
            gym.run_lock(self.output),
        ):
            self.fail("Acquired twice")
        with gym.run_lock(self.output):
            self.assertTrue((self.output / ".lock").exists())

    def test_changed_revision_refuses_resume_before_any_process_starts(self):
        gym.atomic_json(self.output / "manifest.json", self.manifest)
        gym.atomic_json(self.output / "jobs.json", [])
        with (
            patch.object(
                gym, "repository_revision", return_value={"commit": "different"}
            ),
            patch.object(gym.Processes, "run") as run,
            contextlib.redirect_stderr(io.StringIO()),
        ):
            status = gym.main(["resume", str(self.output), "--workers", "1"])
        self.assertEqual(status, 2)
        run.assert_not_called()

    def test_recovery_uses_completed_attempts_even_without_scheduler_checkpoint(self):
        job = gym.make_jobs([self.suite], 1)[0]
        processes = Mock()
        processes.run.side_effect = self.fake_worker
        result = gym.run_job(
            self.suite, job, self.manifest, self.output, "key", processes, None, "0"
        )
        recovered = gym.recover_jobs(self.output, self.manifest)
        self.assertEqual(recovered[0]["state"], "failed")
        self.assertEqual(recovered[0]["attempts"], [result])
        Path(result["artifact"]).write_text("{}")
        with self.assertRaisesRegex(ValueError, "changed or disappeared"):
            gym.recover_jobs(self.output, self.manifest)

    def test_interrupted_attempt_directory_is_retained_and_never_overwritten(self):
        job = gym.make_jobs([self.suite], 1)[0]
        interrupted = self.output / "jobs" / job["directory"] / "attempt-1"
        interrupted.mkdir(parents=True)
        (interrupted / "worker.jsonl").write_text("partial evidence")
        processes = Mock()
        processes.run.side_effect = self.fake_worker
        result = gym.run_job(
            self.suite, job, self.manifest, self.output, "key", processes, None, "0"
        )
        self.assertEqual(result["number"], 2)
        self.assertEqual((interrupted / "worker.jsonl").read_text(), "partial evidence")

    def test_frozen_reports_skip_preparation_and_reject_wrong_world(self):
        prep = suite("query-reports", "preparation", ["reports"])
        self.manifest.update(
            suites=[prep], summarySourceHash="world", summaryOwnerIds=["owner"]
        )
        jobs = gym.make_jobs([prep], 1)
        bundle = {
            "sourceHash": "wrong",
            "model": "fixture-model",
            "reports": [
                {"ownerId": "owner", "oneLiner": "A", "tldr": "B", "content": "C"}
            ],
        }
        with self.assertRaises(ValueError):
            gym.use_frozen_reports(self.output, self.manifest, jobs, bundle)
        bundle["sourceHash"] = "world"
        gym.use_frozen_reports(self.output, self.manifest, jobs, bundle)
        self.assertEqual(jobs[0]["state"], "prepared")
        self.assertEqual(
            gym.recover_jobs(self.output, self.manifest)[0]["state"], "prepared"
        )
        summary = gym.checkpoint(self.output, self.manifest, jobs)
        self.assertTrue(summary["cost"]["complete"])
        self.assertEqual(summary["cost"]["untrackedAttempts"], 0)
        self.assertEqual(summary["cost"]["totalCostEur"], "0")

    def test_dry_run_and_resume_use_the_same_manifest_without_live_credentials(self):
        catalog = {
            "schemaVersion": 1,
            "suites": [self.suite],
            "coverageGaps": {},
            "excludedEntryPoints": {},
            "summarySourceHash": "world",
            "summaryOwnerIds": ["owner"],
        }
        with (
            patch.object(gym, "discover", return_value=catalog),
            patch.object(gym, "repository_revision", return_value={}),
            patch.dict(os.environ, {}, clear=True),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            status = gym.main(
                [
                    "assess",
                    "--model",
                    "candidate",
                    "--dry-run",
                    "--output-root",
                    str(self.output),
                    "--env-file",
                    str(self.output / "absent"),
                ]
            )
        self.assertEqual(status, 0)
        run = next(self.output.iterdir())
        manifest = gym.read_json(run / "manifest.json")
        self.assertEqual(manifest["model"], "candidate")
        self.assertEqual(gym.read_json(run / "summary.json")["verdict"], "incomplete")
        self.assertEqual(len(gym.recover_jobs(run, manifest)), 3)

    def test_model_and_unknown_suite_validation_precede_worker_execution(self):
        with (
            patch.object(gym.Processes, "run") as run,
            contextlib.redirect_stderr(io.StringIO()),
        ):
            status = gym.main(["assess", "--model", "candidate,other", "--dry-run"])
        self.assertEqual(status, 2)
        run.assert_not_called()

    def test_process_timeout_kills_owned_descendants_and_removes_active_handle(self):
        process = Mock()
        process.wait.side_effect = gym.subprocess.TimeoutExpired("worker", 10)
        processes = gym.Processes()
        with (
            patch.object(gym.subprocess, "Popen", return_value=process),
            patch.object(gym, "stop_process_tree") as stop,
        ):
            code = processes.run(["worker"], {}, self.output / "worker.log", 10)
        self.assertEqual(code, 124)
        stop.assert_called_once_with(process)
        self.assertEqual(processes.active, set())

    def test_interrupt_during_preflight_stops_child_before_unregistering_it(self):
        process = Mock()
        process.wait.side_effect = KeyboardInterrupt
        processes = gym.Processes()
        with (
            patch.object(gym.subprocess, "Popen", return_value=process),
            patch.object(gym, "stop_process_tree") as stop,
            self.assertRaises(KeyboardInterrupt),
        ):
            processes.run(["worker"], {}, self.output / "worker.log", 10)
        stop.assert_called_once_with(process)
        self.assertEqual(processes.active, set())

    def test_judge_workers_publish_copies_before_coordinator_updates_jobs(self):
        task = suite("tasks", "task", ["quiet", "change"])
        self.manifest.update(suites=[task], judgeModel="independent-judge")
        jobs = gym.make_jobs([task], 1, batch_size=1)
        attempts = {}
        for job in jobs:
            directory = self.output / "jobs" / job["directory"] / "attempt-1"
            directory.mkdir(parents=True)
            attempt = {
                "directory": str(directory),
                "artifact": str(directory / "artifact.json"),
                "number": 1,
                "results": [{"case": job["cases"][0], "status": "passed"}],
            }
            job.update(state="complete", attempts=[attempt])
            attempts[directory] = attempt
        original_write = gym.atomic_json
        published = []

        def check_ownership(path, value):
            if path.name == "result.json":
                # Judge subprocesses complete on worker threads. Until their
                # durable record is written, the coordinator-owned attempt
                # must remain unchanged so checkpoint can safely iterate it.
                self.assertNotIn("judge", attempts[path.parent])
                self.assertIsNot(value, attempts[path.parent])
                published.append(path)
            original_write(path, value)

        processes = Mock()
        processes.run.return_value = 1
        with patch.object(gym, "atomic_json", side_effect=check_ownership):
            gym.judge_jobs(self.output, self.manifest, jobs, "key", 2, processes)
        self.assertEqual(len(published), 2)
        for job in jobs:
            attempt = job["attempts"][0]
            self.assertEqual(attempt["judge"]["state"], "error")
            self.assertEqual(job["state"], "complete")
            self.assertEqual(
                gym.read_json(Path(attempt["directory"]) / "result.json"), attempt,
            )

    def test_judge_failure_resumes_without_repeating_candidate_or_changing_verdict(
        self,
    ):
        task = suite("tasks", "task", ["quiet"])
        self.manifest.update(suites=[task], judgeModel="independent-judge")
        jobs = gym.make_jobs([task], 1)
        directory = self.output / "jobs" / jobs[0]["directory"] / "attempt-1"
        directory.mkdir(parents=True)
        jobs[0].update(
            state="failed",
            attempts=[
                {
                    "directory": str(directory),
                    "artifact": str(directory / "artifact.json"),
                    "number": 1,
                    "results": [{"case": "quiet", "status": "failed"}],
                }
            ],
        )
        processes = Mock()
        def run_judge(command, env, log, timeout):
            with patch.dict(os.environ, env, clear=True):
                self.assertEqual(
                    judge_cli._validate_judge_url(env["MELIOUS_BASE_URL"]),
                    env["MELIOUS_BASE_URL"],
                )
            self.assertRegex(env["MELIOUS_BASE_URL"], r"^http://127\.0\.0\.1:\d+/v1$")
            self.assertEqual(env["TASK_AGENT_EVAL_ALLOWED_JUDGE_HOSTS"], "127.0.0.1")
            return 0

        processes.run.side_effect = run_judge
        gym.judge_jobs(self.output, self.manifest, jobs, "key", 1, processes)
        self.assertEqual(jobs[0]["attempts"][0]["judge"]["state"], "error")
        judgment = {
            key: 3
            for key in (
                "factualGrounding",
                "requiredCoverage",
                "checklistQuality",
                "summaryQuality",
                "formatCompliance",
            )
        }
        judgment.update(overall=3, verdict="good", findings=[])
        gym.atomic_json(
            directory / "judgments.json",
            {
                "judgeModel": "independent-judge",
                "results": [
                    {
                        "scenarioId": "quiet",
                        "providerModelId": self.manifest["model"],
                        "judge": judgment,
                    }
                ],
            },
        )
        gym.judge_jobs(self.output, self.manifest, jobs, "key", 1, processes)
        self.assertEqual(jobs[0]["attempts"][0]["judge"]["state"], "complete")
        self.assertEqual(jobs[0]["state"], "failed")
        gym.judge_jobs(self.output, self.manifest, jobs, "key", 1, processes)
        self.assertEqual(processes.run.call_count, 2)

    def test_full_cli_saves_failed_model_result_and_resume_does_not_reroll(self):
        catalog = {
            "schemaVersion": 1,
            "suites": [self.suite],
            "coverageGaps": {},
            "excludedEntryPoints": {},
            "summarySourceHash": "world",
            "summaryOwnerIds": ["owner"],
        }
        with (
            patch.object(gym, "discover", return_value=catalog),
            patch.object(gym, "repository_revision", return_value={}),
            patch.object(gym.Processes, "run", side_effect=self.fake_worker) as run,
            patch.dict(os.environ, {"MELIOUS_API_KEY": "synthetic"}, clear=True),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            status = gym.main(
                [
                    "assess",
                    "--model",
                    self.manifest["model"],
                    "--samples",
                    "1",
                    "--workers",
                    "1",
                    "--no-judge",
                    "--output-root",
                    str(self.output),
                ]
            )
            self.assertEqual(status, 1)
            directory = next(self.output.iterdir())
            calls = run.call_count
            status = gym.main(["resume", str(directory), "--workers", "1"])
            self.assertEqual(status, 1)
            self.assertEqual(run.call_count, calls)
            self.assertEqual(self.record_history.call_count, 2)
            recorded = self.record_history.call_args.args[1]
            self.assertEqual(recorded["runId"], directory.name)
            self.assertEqual(recorded["duration"]["invocations"], 2)
            self.assertIsNotNone(recorded["duration"]["activeWallSeconds"])

    def test_invalidated_run_cannot_look_like_a_successful_baseline(self):
        gym.atomic_json(self.output / "invalidated.json", {"reason": "source changed"})
        summary = gym.checkpoint(self.output, self.manifest, [])
        self.assertFalse(summary["revisionValid"])
        self.assertEqual(summary["verdict"], "incomplete")

    def test_session_finalization_invalidates_changed_source_and_preserves_interrupt(self):
        with (
            patch.object(gym, "repository_revision", return_value={"commit": "changed"}),
            patch.object(gym.time, "monotonic", return_value=10),
            self.assertRaises(KeyboardInterrupt),
        ):
            with gym.assessment_session(
                self.output,
                self.manifest,
                [],
                "2030-01-15T12:00:00Z",
                5,
            ):
                raise KeyboardInterrupt
        self.assertTrue((self.output / "invalidated.json").exists())
        recorded = self.record_history.call_args.args[1]
        self.assertFalse(recorded["revisionValid"])
        self.assertEqual(recorded["verdict"], "incomplete")

    def test_session_finalization_reports_changed_source_after_success(self):
        with (
            patch.object(gym, "repository_revision", return_value={"commit": "changed"}),
            patch.object(gym.time, "monotonic", return_value=10),
            self.assertRaisesRegex(ValueError, "Checkout changed"),
        ):
            with gym.assessment_session(
                self.output,
                self.manifest,
                [],
                "2030-01-15T12:00:00Z",
                5,
            ):
                pass
        self.assertTrue((self.output / "invalidated.json").exists())
        self.assertFalse(self.record_history.call_args.args[1]["revisionValid"])

    def test_all_adapter_environments_bind_model_and_expected_output(self):
        for adapter in (
            "task",
            "workflow",
            "wake",
            "outcome",
            "query",
            "actions",
            "preparation",
            "planning",
            "journey",
            "compaction",
        ):
            with self.subTest(adapter=adapter):
                target = suite(adapter, adapter, ["quiet"])
                job = gym.make_jobs([target], 1)[0]
                env = gym.job_environment(
                    target,
                    job,
                    self.manifest,
                    self.output,
                    "synthetic",
                    self.output / "reports.json",
                )
                self.assertEqual(env["MELIOUS_API_KEY"], "synthetic")
                self.assertEqual(env["GOAL_AGENT_EVAL_MODEL"], self.manifest["model"])
                if adapter == "task":
                    self.assertEqual(
                        env["GOAL_AGENT_EVAL_PROFILES"], "candidate=vendor/candidate"
                    )
                elif adapter == "compaction":
                    self.assertEqual(
                        env["GOAL_COMPACTION_EVAL_STRATEGIES"], "full,hierarchical"
                    )
                elif adapter in ("query", "actions", "preparation"):
                    self.assertEqual(
                        env["QUERY_EVAL_OUTPUT"], str(self.output / "artifact.json")
                    )


class TransientFailureTest(unittest.TestCase):
    """Classify a failed attempt from the evidence it actually wrote."""

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.directory = Path(temp.name)

    def attempt(self, log="", exit_code=1):
        (self.directory / "worker.jsonl").write_text(log)
        return {"directory": str(self.directory), "exitCode": exit_code}

    def test_a_rejected_request_is_not_retried_for_mentioning_a_connection(self):
        self.assertFalse(
            gym.transient_failure(
                self.attempt("HTTP 400: connection parameter is invalid")
            )
        )

    def test_overload_and_server_statuses_are_retried(self):
        for status in ["HTTP 429: slow down", "HTTP 503 Service Unavailable", "status code 500"]:
            self.assertTrue(gym.transient_failure(self.attempt(status)), status)

    def test_a_permanent_status_beats_a_transient_one(self):
        self.assertFalse(
            gym.transient_failure(
                self.attempt("HTTP 503 once, then HTTP 401: Invalid API key")
            )
        )

    def test_a_coordinator_timeout_is_retried_without_any_marker(self):
        # Killing the worker at the timeout can leave the log empty; the call
        # it was waiting on still never answered.
        self.assertTrue(
            gym.transient_failure(self.attempt(exit_code=gym.TIMEOUT_EXIT_CODE))
        )

    def test_a_cancelled_attempt_is_not_retried(self):
        self.assertFalse(
            gym.transient_failure(self.attempt(exit_code=gym.CANCELLED_EXIT_CODE))
        )

    def test_a_contract_breach_without_evidence_is_not_retried(self):
        self.assertFalse(gym.transient_failure(self.attempt("expected 3 reports, saw 1")))


if __name__ == "__main__":
    unittest.main()
