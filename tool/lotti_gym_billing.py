"""Capture provider billing independently of exercise success and artifact writes.

The loopback relay forwards the original request body to the configured provider.
Only request identity, status, usage and billing metadata enter its append-only
ledger. It never records authorization headers, prompts or generated content.
"""

import gzip
import http.client
import json
import threading
import uuid
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


def decimal_amount(value):
    """Accept an exact non-negative amount; missing or malformed is unknown."""
    if value is None or isinstance(value, bool):
        return None
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None
    return amount if amount.is_finite() and amount >= 0 else None


def response_billing(body, content_type, content_encoding=""):
    """Read the final billing record once, including SSE completion chunks."""
    try:
        if content_encoding == "gzip":
            body = gzip.decompress(body)
        text = body.decode("utf-8")
        if "text/event-stream" in content_type:
            packets = []
            for event in text.replace("\r\n", "\n").split("\n\n"):
                data = "\n".join(
                    line[5:].lstrip() for line in event.splitlines()
                    if line.startswith("data:")
                )
                if data and data != "[DONE]":
                    packets.append(json.loads(data, parse_float=Decimal))
        else:
            packets = [json.loads(text, parse_float=Decimal)]
        billing = None
        for packet in packets:
            if not isinstance(packet, dict):
                continue
            candidate = packet.get("billing_cost")
            if isinstance(candidate, dict):
                credits = decimal_amount(candidate.get("credits"))
                if credits is None:
                    continue
                billing = {"credits": str(credits)}
                energy = decimal_amount(candidate.get("energy"))
                if energy is not None:
                    billing["energy"] = str(energy)
                if candidate.get("paid_with") in ("credits", "energy"):
                    billing["paid_with"] = candidate["paid_with"]
        return {"billingCost": billing}
    except (ValueError, OSError, UnicodeError):
        return {"billingCost": None}


def safe_response_headers(headers):
    """Keep SDK-relevant upstream headers without permitting response splitting."""
    allowed = {
        "content-encoding": "Content-Encoding",
        "content-length": "Content-Length",
        "content-type": "Content-Type",
        "retry-after": "Retry-After",
        "x-request-id": "X-Request-ID",
        "x-ratelimit-limit-requests": "X-RateLimit-Limit-Requests",
        "x-ratelimit-remaining-requests": "X-RateLimit-Remaining-Requests",
        "x-ratelimit-reset-requests": "X-RateLimit-Reset-Requests",
    }
    return [
        (allowed[key.lower()], value)
        for key, value in headers
        if key.lower() in allowed and "\r" not in value and "\n" not in value
    ]


class BillingRelay:
    """One attempt's transparent loopback endpoint and durable billing journal."""

    def __init__(self, upstream, ledger, *, stage="candidate", timeout=600):
        self.upstream = urlsplit(upstream)
        if self.upstream.scheme not in ("http", "https") or not self.upstream.hostname:
            raise ValueError("Billing relay requires an HTTP(S) provider endpoint")
        self.ledger = ledger
        self.stage = stage
        self.timeout = timeout
        self.lock = threading.Lock()
        self.session_id = uuid.uuid4().hex

    def record(self, event, **fields):
        record = {
            "event": event, "sessionId": self.session_id, "stage": self.stage,
            "timestamp": datetime.now(timezone.utc).isoformat(), **fields,
        }
        with self.lock, self.ledger.open("a", encoding="utf-8") as output:
            # lgtm[py/clear-text-storage-sensitive-data] Provider payloads are
            # reduced to validated numeric billing fields and a fixed enum.
            output.write(json.dumps(record, ensure_ascii=False) + "\n")
            output.flush()

    def __enter__(self):
        self.ledger.parent.mkdir(parents=True, exist_ok=True)
        self.ledger.touch(exist_ok=False)
        relay = self

        class Handler(BaseHTTPRequestHandler):
            # Close-delimited responses retain streaming without inventing a
            # Content-Length or forwarding upstream chunk framing as content.
            protocol_version = "HTTP/1.0"

            def log_message(self, *_args):
                pass

            def do_POST(self):
                self.forward()

            def do_GET(self):
                self.forward()

            def read_body(self):
                if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
                    chunks = []
                    while True:
                        size = int(self.rfile.readline().split(b";", 1)[0], 16)
                        if not size:
                            while self.rfile.readline().strip():
                                pass
                            return b"".join(chunks)
                        chunks.append(self.rfile.read(size))
                        if self.rfile.read(2) != b"\r\n":
                            raise ValueError("Malformed request chunk")
                return self.rfile.read(int(self.headers.get("Content-Length", "0")))

            def forward(self):
                request_id = uuid.uuid4().hex
                connection = None
                sent_headers = False
                billing = {"billingCost": None}
                status = None
                error = None
                body = self.read_body()
                try:
                    model = json.loads(body).get("model") if body else None
                except (ValueError, AttributeError):
                    model = None
                relay.record("request_started", requestId=request_id,
                             model=model, method=self.command,
                             operation=urlsplit(self.path).path)
                try:
                    # The upstream authority is fixed; client-controlled URLs
                    # and Host headers cannot turn this into a forward proxy.
                    if not self.path.startswith("/") or self.path.startswith("//"):
                        raise ValueError("Expected an origin-relative request path")
                    kind = (http.client.HTTPSConnection if relay.upstream.scheme == "https"
                            else http.client.HTTPConnection)
                    connection = kind(relay.upstream.hostname, relay.upstream.port,
                                      timeout=relay.timeout)
                    hop_headers = {"host", "connection", "transfer-encoding",
                                   "content-length", "keep-alive", "proxy-authorization",
                                   "te", "trailer", "upgrade", "accept-encoding"}
                    headers = {k: v for k, v in self.headers.items()
                               if k.lower() not in hop_headers}
                    headers["Accept-Encoding"] = "identity"
                    connection.request(self.command, self.path, body=body, headers=headers)
                    response = connection.getresponse()
                    status = response.status
                    self.send_response_only(status, response.reason)
                    for key, value in safe_response_headers(response.getheaders()):
                        self.send_header(key, value)
                    self.end_headers()
                    sent_headers = True
                    chunks = []
                    client_connected = True
                    while chunk := response.read1(65536):
                        chunks.append(chunk)
                        if client_connected:
                            try:
                                self.wfile.write(chunk)
                                self.wfile.flush()
                            except (BrokenPipeError, ConnectionResetError):
                                # A caller timeout must not discard a bill the
                                # provider subsequently returns for its request.
                                client_connected = False
                    billing = response_billing(
                        b"".join(chunks), response.getheader("Content-Type", ""),
                        response.getheader("Content-Encoding", ""),
                    )
                except (OSError, ValueError, http.client.HTTPException) as failure:
                    error = type(failure).__name__
                    if not sent_headers:
                        try:
                            self.send_error(502, "Provider transport failed")
                        except OSError:
                            pass
                finally:
                    if connection is not None:
                        connection.close()
                    relay.record("request_finished", requestId=request_id,
                                 httpStatus=status, error=error, **billing)

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        # Wait for active responses at shutdown so their billing is retained.
        self.server.daemon_threads = False
        self.thread = threading.Thread(target=self.server.serve_forever,
                                       kwargs={"poll_interval": 0.05}, daemon=True)
        self.base_url = (f"http://127.0.0.1:{self.server.server_port}"
                         f"{self.upstream.path.rstrip('/')}")
        self.record("session_started")
        self.thread.start()
        return self

    def __exit__(self, *_args):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.record("session_finished")


def summarize_billing(paths, *, untracked_attempts=0):
    """Sum every HTTP attempt exactly once; never upgrade unknown cost to zero."""
    calls = {}
    sessions = {}
    invalid = 0
    for path in paths:
        for line in path.read_text(encoding="utf-8").splitlines():
            try:
                record = json.loads(line)
                session = record["sessionId"]
                event = record["event"]
                if event.startswith("session_"):
                    sessions.setdefault(session, set()).add(event)
                elif event.startswith("request_"):
                    key = (session, record["requestId"])
                    entry = calls.setdefault(key, {})
                    if event in entry:
                        invalid += 1
                    entry[event] = record
            except (ValueError, KeyError, TypeError):
                invalid += 1
    total = Decimal(0)
    charged_credits = Decimal(0)
    charged_energy = Decimal(0)
    missing = 0
    payment_unknown = 0
    by_model = {}
    by_stage = {}
    for entry in calls.values():
        started = entry.get("request_started", {})
        finished = entry.get("request_finished", {})
        billing = finished.get("billingCost") or {}
        cost = decimal_amount(billing.get("credits")) if isinstance(billing, dict) else None
        if not started or not finished or cost is None:
            missing += 1
        if cost is None:
            continue
        total += cost
        model = started.get("model") or "unknown"
        stage = started.get("stage") or "unknown"
        by_model[model] = by_model.get(model, Decimal(0)) + cost
        by_stage[stage] = by_stage.get(stage, Decimal(0)) + cost
        if billing.get("paid_with") == "credits":
            charged_credits += cost
        elif billing.get("paid_with") == "energy" and decimal_amount(billing.get("energy")) is not None:
            charged_energy += decimal_amount(billing["energy"])
        else:
            payment_unknown += 1
    open_sessions = sum("session_finished" not in events for events in sessions.values())
    complete = not (missing or invalid or untracked_attempts or open_sessions)
    return {
        "currency": "EUR", "knownCostEur": str(total),
        "totalCostEur": str(total) if complete else None,
        "complete": complete, "requests": len(calls),
        "requestsWithUnknownCost": missing, "untrackedAttempts": untracked_attempts,
        "openSessions": open_sessions, "invalidRecords": invalid,
        "chargedCredits": str(charged_credits), "chargedEnergy": str(charged_energy),
        "requestsWithUnknownPaymentSource": payment_unknown,
        "costEurByModel": {k: str(v) for k, v in sorted(by_model.items())},
        "costEurByStage": {k: str(v) for k, v in sorted(by_stage.items())},
    }
