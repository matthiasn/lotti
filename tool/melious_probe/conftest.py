"""Shared fixtures and CLI options for the Melious provider probe.

These tests hit the live API and cost real money, so they are opt-in: without
`--live` the whole suite skips.
"""

from __future__ import annotations

import json
import pathlib
from typing import Any

import pytest

from melious import MeliousClient, Probe, describe_secret, resolve_credentials

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

# Searched in order. The app's own .env first, then the sibling prototype repos
# that carry the eval credential.
DOTENV_PATHS = (
    REPO_ROOT / ".env",
    REPO_ROOT.parent / "lotti3" / ".env",
    REPO_ROOT.parent / "lotti4" / ".env",
)


def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("melious")
    group.addoption(
        "--live",
        action="store_true",
        default=False,
        help="Run probes against the live Melious API (costs money).",
    )
    group.addoption(
        "--models",
        default=None,
        help="Comma-separated model ids to probe instead of the full catalog.",
    )
    group.addoption(
        "--report",
        default=None,
        help="Write a JSON probe report to this path.",
    )


def pytest_configure(config: pytest.Config) -> None:
    config.addinivalue_line("markers", "live: hits the live Melious API")


def pytest_collection_modifyitems(
    config: pytest.Config, items: list[pytest.Item]
) -> None:
    if config.getoption("--live"):
        return
    skip = pytest.mark.skip(reason="needs --live (hits the paid API)")
    for item in items:
        if "live" in item.keywords:
            item.add_marker(skip)


@pytest.fixture(scope="session")
def credentials() -> tuple[str, str]:
    api_key, base_url = resolve_credentials(DOTENV_PATHS)
    if not api_key:
        pytest.skip(
            "No Melious credential found. Set MELIOUS_API_KEY, or place one in "
            + " / ".join(str(p) for p in DOTENV_PATHS)
        )
    return api_key, base_url


@pytest.fixture(scope="session")
def client(credentials: tuple[str, str]) -> Any:
    api_key, base_url = credentials
    print(f"\nMelious probe: {base_url} key=({describe_secret(api_key)})")
    instance = MeliousClient(api_key, base_url)
    yield instance
    instance.close()


@pytest.fixture(scope="session")
def catalog(client: MeliousClient) -> list[dict[str, Any]]:
    """The live model catalog, fetched once per session."""
    return client.list_models()


@pytest.fixture(scope="session")
def chat_models(
    catalog: list[dict[str, Any]], pytestconfig: pytest.Config
) -> list[str]:
    """Chat-capable model ids, honouring an explicit --models override."""
    override = pytestconfig.getoption("--models")
    if override:
        return [m.strip() for m in override.split(",") if m.strip()]
    return sorted(
        entry["id"]
        for entry in catalog
        if entry.get("_meta", {}).get("type") == "chat"
    )


@pytest.fixture(scope="session")
def model_allowlist(pytestconfig: pytest.Config) -> frozenset[str] | None:
    """The --models allowlist, or None when the caller did not restrict it.

    Every live probe must consult this. `--models` is documented as "probe
    just these", and a probe outside the list both spends money the caller
    did not authorise and can fail for reasons unrelated to their query.
    """
    override = pytestconfig.getoption("--models")
    if not override:
        return None
    return frozenset(m.strip() for m in override.split(",") if m.strip())


@pytest.fixture
def require_model(model_allowlist: frozenset[str] | None) -> Any:
    """Skips the calling test when a model is outside the --models allowlist."""

    def check(*models: str) -> None:
        if model_allowlist is None:
            return
        outside = [m for m in models if m not in model_allowlist]
        if outside:
            pytest.skip(f"outside --models allowlist: {', '.join(outside)}")

    return check


@pytest.fixture(scope="session")
def recorder(pytestconfig: pytest.Config) -> Any:
    """Collects every probe so the session can emit one JSON report."""
    probes: list[Probe] = []
    yield probes
    path = pytestconfig.getoption("--report")
    if path and probes:
        pathlib.Path(path).write_text(
            json.dumps([p.as_dict() for p in probes], indent=2),
            encoding="utf-8",
        )
        print(f"\nWrote {len(probes)} probe results to {path}")


_COLLECTED_MODELS: list[str] | None = None


def _collect_chat_models(config: pytest.Config) -> list[str]:
    """Model ids for parametrisation, fetched once at collection time.

    Parametrising per model gives one test id per model, so a failure names the
    model directly instead of hiding inside a loop.
    """
    global _COLLECTED_MODELS
    if _COLLECTED_MODELS is not None:
        return _COLLECTED_MODELS

    override = config.getoption("--models")
    if override:
        _COLLECTED_MODELS = [m.strip() for m in override.split(",") if m.strip()]
        return _COLLECTED_MODELS

    if not config.getoption("--live"):
        _COLLECTED_MODELS = []
        return _COLLECTED_MODELS

    api_key, base_url = resolve_credentials(DOTENV_PATHS)
    if not api_key:
        _COLLECTED_MODELS = []
        return _COLLECTED_MODELS

    probe_client = MeliousClient(api_key, base_url)
    try:
        _COLLECTED_MODELS = sorted(
            entry["id"]
            for entry in probe_client.list_models()
            if entry.get("_meta", {}).get("type") == "chat"
        )
    finally:
        probe_client.close()
    return _COLLECTED_MODELS


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    if "chat_model" in metafunc.fixturenames:
        models = _collect_chat_models(metafunc.config)
        metafunc.parametrize("chat_model", models, ids=models or None)
