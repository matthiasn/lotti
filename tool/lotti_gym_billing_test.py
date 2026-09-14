"""Verify complete billing across response formats, retries and worker failure."""

import contextlib
import gzip
import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from unittest.mock import Mock, patch

from tool import lotti_gym as gym
from tool.lotti_gym_billing import BillingRelay, response_billing, summarize_billing


@contextlib.contextmanager
def provider(responses, received):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_POST(self):
            received.append((self.path, dict(self.headers),
                             self.rfile.read(int(self.headers["Content-Length"]))))
            status, content_type, body = responses[len(received) - 1]
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever,
                              kwargs={"poll_interval": 0.05}, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}/v1"
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


class BillingTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)

    def test_http_attempts_and_helper_models_are_billed_even_when_worker_fails(self):
        responses = [
            (500, "application/json", b'{"billing_cost":{"credits":"0.00000001","paid_with":"credits"}}'),
            (200, "application/json", b'{"billing_cost":{"credits":"0.20000002","energy":"2000.0002","paid_with":"energy"},"choices":[{"message":{"content":"PRIVATE OUTPUT"}}]}'),
        ]
        received = []
        ledger = self.directory / "billing.jsonl"
        with provider(responses, received) as upstream:
            with self.assertRaisesRegex(RuntimeError, "artifact failed"):
                with BillingRelay(upstream, ledger) as relay:
                    for model in ["candidate", "report-editor"]:
                        body = json.dumps({"model": model, "messages": ["PRIVATE PROMPT"]}).encode()
                        request = urllib.request.Request(
                            relay.base_url + "/chat/completions", data=body,
                            headers={"Authorization": "Bearer PRIVATE KEY", "Content-Type": "application/json"},
                        )
                        try:
                            with urllib.request.urlopen(request) as response:
                                self.assertEqual(response.read(), responses[1][2])
                        except urllib.error.HTTPError as error:
                            self.assertEqual(error.code, 500)
                            self.assertEqual(error.read(), responses[0][2])
                    raise RuntimeError("artifact failed")
        result = summarize_billing([ledger])
        self.assertTrue(result["complete"])
        self.assertEqual(result["requests"], 2)
        self.assertEqual(result["totalCostEur"], "0.20000003")
        self.assertEqual(result["chargedCredits"], "1E-8")
        self.assertEqual(result["chargedEnergy"], "2000.0002")
        self.assertEqual(result["costEurByModel"], {"candidate": "1E-8", "report-editor": "0.20000002"})
        self.assertEqual(received[0][0], "/v1/chat/completions")
        self.assertEqual(received[0][1]["Authorization"], "Bearer PRIVATE KEY")
        self.assertEqual(json.loads(received[1][2])["messages"], ["PRIVATE PROMPT"])
        self.assertNotIn("PRIVATE", ledger.read_text())

    def test_stream_is_forwarded_unchanged_and_final_billing_counted_once(self):
        body = (
            b'data: {"id":"completion-1","choices":[{"delta":{"content":"hello"}}]}\n\n'
            b'data: {"id":"completion-1","billing_cost":{"credits":"0.001","paid_with":"credits"}}\n\n'
            b'data: {"id":"completion-1","billing_cost":{"credits":"0.001","paid_with":"credits"}}\n\n'
            b'data: [DONE]\n\n'
        )
        ledger = self.directory / "billing.jsonl"
        with provider([(200, "text/event-stream", body)], []) as upstream:
            with BillingRelay(upstream, ledger, stage="judge") as relay:
                request = urllib.request.Request(relay.base_url + "/chat/completions",
                                                 data=b'{"model":"judge","stream":true}')
                with urllib.request.urlopen(request) as response:
                    self.assertEqual(response.read(), body)
        result = summarize_billing([ledger])
        self.assertEqual(result["totalCostEur"], "0.001")
        self.assertEqual(result["costEurByStage"], {"judge": "0.001"})

    def test_failed_worker_and_resumed_attempt_contribute_to_the_same_run_bill(self):
        suite = {"id": "goals", "adapter": "agent", "cases": ["one"],
                 "entryPoint": "synthetic.dart", "prefix": "GOAL_AGENT_EVAL",
                 "gate": "LOTTI_GOAL_AGENT_EVAL_LIVE", "environment": {},
                 "grouped": False, "dependencies": []}
        response = (200, "application/json", b'{"billing_cost":{"credits":"0.05","paid_with":"credits"}}')
        jobs = gym.make_jobs([suite], 1, 1)
        processes = Mock()
        with provider([response, response], []) as upstream:
            manifest = {"model": "candidate", "provider": "melious", "baseUrl": upstream,
                        "suites": [suite], "scope": "partial", "revision": {},
                        "coverageGaps": {}, "excludedEntryPoints": {}}

            def worker(command, env, log, timeout, **kwargs):
                request = urllib.request.Request(env["MELIOUS_BASE_URL"] + "/chat/completions",
                                                 data=b'{"model":"candidate"}')
                with urllib.request.urlopen(request) as response:
                    response.read()
                if not jobs[0]["attempts"]:
                    return 1  # A billed inference whose artifact writer failed.
                Path(env["GOAL_AGENT_EVAL_JSON"]).write_text(json.dumps({
                    "results": [{"scenarioId": "one", "providerModelId": "candidate",
                                 "passed": True, "credits": 0.05}],
                }))
                log.write_text('{"type":"done","success":true}\n')
                return 0

            processes.run.side_effect = worker
            with patch.object(gym, "worker_project", return_value=self.directory):
                for _ in range(2):
                    attempt = gym.run_job(suite, jobs[0], manifest, self.directory,
                                          "synthetic", processes, None, "0")
                    jobs[0]["attempts"].append(attempt)
                    jobs[0]["state"] = attempt["state"]
        summary = gym.checkpoint(self.directory, manifest, jobs)
        self.assertEqual(jobs[0]["attempts"][0]["state"], "error")
        self.assertEqual(summary["cost"]["totalCostEur"], "0.10")
        self.assertEqual(summary["cost"]["requests"], 2)
        self.assertIn("EUR 0.10", (self.directory / "report.html").read_text())

    def test_gzip_and_numeric_decimal_preserve_exact_price(self):
        body = b'{"billing_cost":{"credits":0.1234567890123456789012345678,"paid_with":"credits"}}'
        result = response_billing(gzip.compress(body), "application/json", "gzip")
        self.assertEqual(result["billingCost"]["credits"], "0.1234567890123456789012345678")

    def test_unknown_and_cancelled_calls_never_become_a_full_price(self):
        path = self.directory / "billing.jsonl"
        records = [
            {"event": "session_started", "sessionId": "s"},
            {"event": "request_started", "sessionId": "s", "requestId": "priced", "model": "candidate"},
            {"event": "request_finished", "sessionId": "s", "requestId": "priced", "billingCost": {"credits": "0.2", "paid_with": "credits"}},
            {"event": "request_started", "sessionId": "s", "requestId": "cancelled"},
            {"event": "request_started", "sessionId": "s", "requestId": "unpriced"},
            {"event": "request_finished", "sessionId": "s", "requestId": "unpriced", "billingCost": None},
        ]
        path.write_text("\n".join(json.dumps(r) for r in records) + '\n{"partial":')
        result = summarize_billing([path], untracked_attempts=1)
        self.assertEqual(result["knownCostEur"], "0.2")
        self.assertIsNone(result["totalCostEur"])
        self.assertEqual(result["requestsWithUnknownCost"], 2)
        self.assertEqual(result["openSessions"], 1)
        self.assertEqual(result["invalidRecords"], 1)
        self.assertFalse(result["complete"])

    def test_zero_price_is_known_but_invalid_amounts_are_not(self):
        for amount, complete in [("0", True), (None, False), (True, False),
                                 ("NaN", False), ("-1", False), ("Infinity", False)]:
            with self.subTest(amount=amount):
                path = self.directory / "billing.jsonl"
                records = [
                    {"event": "session_started", "sessionId": "s"},
                    {"event": "request_started", "sessionId": "s", "requestId": "r"},
                    {"event": "request_finished", "sessionId": "s", "requestId": "r", "billingCost": {"credits": amount}},
                    {"event": "session_finished", "sessionId": "s"},
                ]
                path.write_text("\n".join(json.dumps(r) for r in records))
                result = summarize_billing([path])
                self.assertEqual(result["complete"], complete)
                self.assertEqual(result["totalCostEur"], "0" if complete else None)


if __name__ == "__main__":
    unittest.main()
