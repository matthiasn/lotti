"""Minimal client for the Melious.ai OpenAI-compatible API.

Deliberately thin: the point of this package is to characterise what the
provider does with a *known-good* request, so the client adds nothing to the
payload beyond what the caller asks for. Anything clever here would undermine
the diagnosis.
"""

from __future__ import annotations

import dataclasses
import enum
import hashlib
import os
import pathlib
import time
from typing import Any

import requests

DEFAULT_BASE_URL = "https://api.melious.ai/v1"

# Keys the probe understands, most specific first. MELIOUS_API_KEY is the app's
# own name; UP_UPSTREAM_API_KEY is what the prototype repos use.
API_KEY_NAMES = ("MELIOUS_API_KEY", "UP_UPSTREAM_API_KEY")
BASE_URL_NAMES = ("MELIOUS_BASE_URL", "UP_UPSTREAM_BASE_URL")


class Outcome(enum.StrEnum):
    """Classification of a single chat-completion attempt."""

    OK = "ok"
    MALFORMED = "malformed"          # HTTP 400 invalid_request_error
    UPSTREAM_ERROR = "upstream"      # HTTP 5xx from the model provider
    NOT_FOUND = "not_found"          # HTTP 404, model absent at the backend
    UNAUTHORIZED = "unauthorized"    # HTTP 401/403
    OTHER = "other"

    @classmethod
    def from_status(cls, status: int) -> "Outcome":
        if 200 <= status < 300:
            return cls.OK
        if status == 400:
            return cls.MALFORMED
        if status in (401, 403):
            return cls.UNAUTHORIZED
        if status == 404:
            return cls.NOT_FOUND
        if status >= 500:
            return cls.UPSTREAM_ERROR
        return cls.OTHER


@dataclasses.dataclass(frozen=True, slots=True)
class Probe:
    """The result of one chat-completion attempt against one model."""

    model: str
    status: int
    outcome: Outcome
    message: str
    request_id: str | None
    attempts: int
    elapsed_s: float

    @property
    def ok(self) -> bool:
        return self.outcome is Outcome.OK

    def as_dict(self) -> dict[str, Any]:
        data = dataclasses.asdict(self)
        data["outcome"] = str(self.outcome)
        return data


def describe_secret(secret: str) -> str:
    """Describe a credential without disclosing any of it.

    Deliberately returns no characters of the secret — not even a prefix.
    A partial reveal is still a leak into CI logs, and the length plus a
    non-reversible fingerprint is enough to tell two keys apart.
    """
    digest = hashlib.sha256(secret.encode()).hexdigest()[:8]
    return f"{len(secret)} chars, sha256:{digest}"


def load_dotenv(path: pathlib.Path) -> dict[str, str]:
    """Parse a dotenv file. Ignores comments, blanks and malformed lines.

    Not a full dotenv implementation on purpose — no interpolation, no export
    handling — because the probe should read exactly the literal the app reads.
    """
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        name, _, value = stripped.partition("=")
        values[name.strip()] = value.strip().strip("'\"")
    return values


def resolve_credentials(
    dotenv_paths: tuple[pathlib.Path, ...],
) -> tuple[str | None, str]:
    """Return (api_key, base_url), preferring the process environment.

    Falls back through `dotenv_paths` in order so a working key in a sibling
    repo can be picked up without editing the app's own .env.
    """
    sources: list[dict[str, str]] = [dict(os.environ)]
    sources.extend(load_dotenv(path) for path in dotenv_paths)

    def first(names: tuple[str, ...]) -> str | None:
        for source in sources:
            for name in names:
                value = source.get(name)
                if value:
                    return value
        return None

    return first(API_KEY_NAMES), first(BASE_URL_NAMES) or DEFAULT_BASE_URL


class MeliousClient:
    """Synchronous client scoped to one credential."""

    def __init__(
        self,
        api_key: str,
        base_url: str = DEFAULT_BASE_URL,
        *,
        timeout_s: float = 90.0,
        session: requests.Session | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._timeout_s = timeout_s
        self._session = session or requests.Session()
        self._session.headers.update(
            {
                "Authorization": f"Bearer {api_key.strip()}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            }
        )

    def close(self) -> None:
        self._session.close()

    def list_models(self, *, include_meta: bool = True) -> list[dict[str, Any]]:
        """Fetch the catalog. Raises for a non-2xx, which is never expected."""
        response = self._session.get(
            f"{self._base_url}/models",
            params={"include_meta": "true"} if include_meta else None,
            timeout=self._timeout_s,
        )
        response.raise_for_status()
        payload = response.json()
        return payload["data"] if isinstance(payload, dict) else payload

    def probe_chat(
        self,
        model: str,
        *,
        body: dict[str, Any] | None = None,
        retries: int = 2,
        backoff_s: float = 2.0,
    ) -> Probe:
        """Send one chat completion and classify the result.

        5xx responses are retried, so a transient capacity blip is not
        mistaken for a model that is persistently unusable. 4xx is never
        retried — the server has made a decision about the request.
        """
        payload = body if body is not None else minimal_chat_body(model)
        started = time.monotonic()
        status, message, request_id = 0, "", None

        for attempt in range(1, retries + 2):
            response = self._session.post(
                f"{self._base_url}/chat/completions",
                json=payload,
                timeout=self._timeout_s,
            )
            status = response.status_code
            request_id = response.headers.get("x-request-id")
            message = _extract_message(response)
            if status < 500:
                break
            if attempt <= retries:
                time.sleep(backoff_s * attempt)
        else:  # pragma: no cover - loop always breaks or exhausts
            attempt = retries + 1

        return Probe(
            model=model,
            status=status,
            outcome=Outcome.from_status(status),
            message=message,
            request_id=request_id,
            attempts=attempt,
            elapsed_s=round(time.monotonic() - started, 2),
        )


def minimal_chat_body(model: str) -> dict[str, Any]:
    """The smallest request the OpenAI chat schema permits.

    No temperature, no max tokens, no tools, no response_format — so a
    "malformed request" reply cannot be blamed on an optional parameter.
    """
    return {
        "model": model,
        "messages": [{"role": "user", "content": "Say OK"}],
    }


def _extract_message(response: requests.Response) -> str:
    try:
        payload = response.json()
    except ValueError:
        return response.text[:200]
    if isinstance(payload, dict) and isinstance(payload.get("error"), dict):
        return str(payload["error"].get("message", ""))[:200]
    choices = payload.get("choices") if isinstance(payload, dict) else None
    if choices:
        content = choices[0].get("message", {}).get("content", "")
        return repr(content)[:200]
    return ""
