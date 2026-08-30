from pathlib import Path

_COMPOSE_FILE = Path(__file__).resolve().parents[2] / "docker-compose.matrix-admin.yml"
_CONTAINER_CREDENTIAL_PATH = "/run/secrets/google-application-credentials.json"


def test_compose_mounts_google_credentials_read_only_at_container_path():
    compose = _COMPOSE_FILE.read_text(encoding="utf-8")

    assert f"GOOGLE_APPLICATION_CREDENTIALS={_CONTAINER_CREDENTIAL_PATH}" in compose
    assert (
        "${GOOGLE_APPLICATION_CREDENTIALS:-/dev/null}:"
        f"{_CONTAINER_CREDENTIAL_PATH}:ro" in compose
    )


def test_compose_forwards_bundle_claim_reaper_startup_delay():
    compose = _COMPOSE_FILE.read_text(encoding="utf-8")

    assert (
        "BUNDLE_CLAIM_REAPER_STARTUP_DELAY_SECONDS="
        "${BUNDLE_CLAIM_REAPER_STARTUP_DELAY_SECONDS:-60}" in compose
    )


def test_compose_forwards_documented_subscription_tunables():
    compose = _COMPOSE_FILE.read_text(encoding="utf-8")
    expected_defaults = {
        "ENTITLEMENT_ISSUANCE_LIMIT": "5",
        "ENTITLEMENT_ISSUANCE_WINDOW_SECONDS": "3600",
        "PAID_PROVISIONING_WAIT_SECONDS": "30",
        "PAID_PROVISIONING_POLL_SECONDS": "0.1",
        "PAID_PROVISIONING_OPERATION_TIMEOUT_SECONDS": "300",
    }

    for variable, default in expected_defaults.items():
        assert f"{variable}=${{{variable}:-{default}}}" in compose
