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
