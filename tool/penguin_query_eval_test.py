"""Offline safety checks for the opt-in live query evaluator."""

import contextlib
import io
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, call, patch

from tool import penguin_query_eval as runner


class PenguinQueryEvalTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.output = Path(directory.name) / "sample.json"
        self.args = [
            "penguin_query_eval.py", "--model", "deepseek-v4.1-flash",
            "--variant", "synthetic-test", "--output", str(self.output),
        ]

    def run_main(self, process):
        with (
            patch.object(sys, "argv", self.args),
            patch.dict(os.environ, {}, clear=True),
            patch.object(Path, "read_text", return_value=(
                'MELIOUS_API_KEY="synthetic key"\n'
                'MELIOUS_BASE_URL="https://synthetic.invalid/v1"\n'
            )),
            patch.object(Path, "exists", lambda path: path.name == ".env"),
            patch.object(runner.subprocess, "Popen", return_value=process) as start,
            contextlib.redirect_stdout(io.StringIO()),
        ):
            result = runner.main()
        return result, start

    def test_model_variant_and_credentials_reach_only_the_child_environment(self):
        process = Mock(pid=12345)
        process.wait.return_value = 0
        result, start = self.run_main(process)
        self.assertEqual(result, 0)
        args, kwargs = start.call_args
        self.assertNotIn("synthetic key", repr(args))
        self.assertEqual(kwargs["env"]["MELIOUS_API_KEY"], "synthetic key")
        self.assertEqual(kwargs["env"]["QUERY_EVAL_MODEL"], "deepseek-v4.1-flash")
        self.assertEqual(kwargs["env"]["QUERY_EVAL_VARIANT"], "synthetic-test")
        self.assertEqual(kwargs["env"]["QUERY_EVAL_LEGACY_FLOW"], "0")
        self.assertEqual(kwargs["env"]["QUERY_EVAL_OUTPUT"], str(self.output))
        process.wait.assert_called_once_with(timeout=900)

    def test_legacy_control_is_explicit(self):
        self.args.append("--legacy-flow")
        process = Mock(pid=12345)
        process.wait.return_value = 0
        result, start = self.run_main(process)
        self.assertEqual(result, 0)
        self.assertEqual(start.call_args.kwargs["env"]["QUERY_EVAL_LEGACY_FLOW"], "1")

    @unittest.skipUnless(os.name == "posix", "POSIX process group contract")
    def test_deadline_terminates_the_owned_flutter_tree(self):
        process = Mock(pid=12345)
        process.wait.side_effect = [subprocess.TimeoutExpired("synthetic", 900), 0]
        with patch.object(runner.os, "killpg") as kill:
            result, _ = self.run_main(process)
        self.assertEqual(result, 124)
        kill.assert_called_once_with(12345, signal.SIGTERM)
        self.assertEqual(process.wait.call_args_list, [call(timeout=900), call(timeout=5)])

    @unittest.skipUnless(os.name == "posix", "POSIX process group contract")
    def test_unresponsive_descendants_are_killed_after_graceful_stop(self):
        process = Mock(pid=12345)
        process.wait.side_effect = [subprocess.TimeoutExpired("synthetic", 5), 0]
        with patch.object(runner.os, "killpg") as kill:
            runner.stop_process_tree(process)
        self.assertEqual(kill.call_args_list, [
            call(12345, signal.SIGTERM), call(12345, signal.SIGKILL),
        ])
        self.assertEqual(process.wait.call_args_list, [call(timeout=5), call()])

    def test_existing_sample_is_never_overwritten(self):
        self.output.write_text("preserved synthetic sample")
        with (
            patch.object(sys, "argv", self.args),
            patch.object(runner.subprocess, "Popen") as start,
            contextlib.redirect_stderr(io.StringIO()),
            self.assertRaises(SystemExit),
        ):
            runner.main()
        start.assert_not_called()
        self.assertEqual(self.output.read_text(), "preserved synthetic sample")


if __name__ == "__main__":
    unittest.main()
