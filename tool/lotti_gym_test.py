"""Exercise LottiGym orchestration offline with deterministic worker artifacts."""

import contextlib
import io
import json
import os
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import Mock, patch

from tool import lotti_gym as gym


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

    def test_workers_reuse_private_compiler_caches_without_cross_run_collisions(self):
        cases = suite(cases=["one", "two", "three", "four"])
        jobs = gym.make_jobs([cases], 1, batch_size=1)
        processes = Mock()
        processes.run.side_effect = self.fake_worker
        other_run = self.output / "another-run"
        other_run.mkdir()
        configurations = [
            ("worker-0", self.output),
            ("worker-0", self.output),
            ("worker-1", self.output),
            ("worker-0", other_run),
        ]
        flags = []
        for job, (worker, output) in zip(jobs, configurations):
            thread = Mock()
            thread.name = worker
            with patch.object(gym.threading, "current_thread", return_value=thread):
                gym.run_job(
                    cases, job, self.manifest, output, "synthetic-key", processes, None
                )
            command = processes.run.call_args.args[0]
            slot = [
                arg
                for arg in command
                if arg.startswith("--dart-define=LOTTI_GYM_COMPILER_SLOT=")
            ]
            self.assertEqual(len(slot), 1)
            flags.append(slot[0])
        self.assertEqual(flags[0], flags[1])
        self.assertNotEqual(flags[0], flags[2])
        self.assertNotEqual(flags[0], flags[3])

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

    def fake_worker(self, command, env, log, timeout):
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
            gym.execute(self.output, self.manifest, jobs, "key", 1, processes)
        self.assertEqual([j["state"] for j in jobs], ["failed", "failed"])
        self.assertEqual(
            gym.read_json(self.output / "summary.json")["verdict"], "failed"
        )
        self.assertTrue((self.output / "report.html").is_file())
        calls = processes.run.call_count
        gym.execute(self.output, self.manifest, jobs, "key", 1, processes)
        self.assertEqual(processes.run.call_count, calls)

    def test_missing_artifact_is_error_and_retry_keeps_prior_attempt(self):
        job = gym.make_jobs([self.suite], 1)[0]
        processes = Mock()
        processes.run.side_effect = lambda command, env, log, timeout: (
            log.write_text("") and 0
        )
        result = gym.run_job(
            self.suite, job, self.manifest, self.output, "key", processes, None
        )
        self.assertEqual(result["state"], "error")
        job["attempts"].append(result)
        processes.run.side_effect = self.fake_worker
        second = gym.run_job(
            self.suite, job, self.manifest, self.output, "key", processes, None
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
        processes.run.side_effect = lambda command, env, log, timeout: (
            log.write_text(""),
            0,
        )[1]
        with contextlib.redirect_stdout(io.StringIO()):
            gym.execute(self.output, self.manifest, jobs, "key", 1, processes)
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
            self.suite, job, self.manifest, self.output, "key", processes, None
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
            self.suite, job, self.manifest, self.output, "key", processes, None
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
        processes.run.return_value = 0
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

    def test_invalidated_run_cannot_look_like_a_successful_baseline(self):
        gym.atomic_json(self.output / "invalidated.json", {"reason": "source changed"})
        summary = gym.checkpoint(self.output, self.manifest, [])
        self.assertFalse(summary["revisionValid"])
        self.assertEqual(summary["verdict"], "incomplete")

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


if __name__ == "__main__":
    unittest.main()
