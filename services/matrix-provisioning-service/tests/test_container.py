"""Tests for dependency wiring and credential resolution.

The credential precedence is security-relevant: a stale password in the
environment must never silently win over a configured admin token.
"""

from __future__ import annotations

import pytest

from shared.matrix import SynapseAdminClient, SynapseProvisioner
from src.container import Container, build_admin_credentials
from src.services.bundle_service import BundleService
from src.services.provisioning_repository import ProvisioningRepository
from src.services.redemption_poller import RedemptionPoller
from src.services.retention_service import RetentionService


@pytest.fixture
def env(monkeypatch, tmp_path):
    """Baseline service configuration pointing at a throwaway database."""
    monkeypatch.setenv("MATRIX_HOMESERVER", "https://matrix.example.com")
    monkeypatch.setenv("MATRIX_ADMIN_USER", "admin")
    monkeypatch.setenv("MATRIX_ADMIN_PASSWORD", "secret")
    monkeypatch.setenv("DB_PATH", str(tmp_path / "container.db"))
    monkeypatch.delenv("MATRIX_ADMIN_TOKEN", raising=False)
    return monkeypatch


def test_token_takes_precedence_over_password(env):
    """A configured token must win, so rotating it actually takes effect."""
    env.setenv("MATRIX_ADMIN_TOKEN", "syt_admin_token")

    credentials = build_admin_credentials()

    assert credentials.admin_token == "syt_admin_token"


def test_password_login_is_the_fallback(env):
    credentials = build_admin_credentials()

    assert credentials.admin_token is None
    assert credentials.admin_user == "admin"


def test_blank_token_falls_back_rather_than_authenticating_with_empty_string(env):
    """An unset-but-present env var must not become a literal empty token."""
    env.setenv("MATRIX_ADMIN_TOKEN", "")

    credentials = build_admin_credentials()

    assert credentials.admin_token is None
    assert credentials.admin_password == "secret"


def test_missing_credentials_fail_fast(env):
    env.delenv("MATRIX_ADMIN_USER")
    env.delenv("MATRIX_ADMIN_PASSWORD")

    with pytest.raises(ValueError, match="admin_token"):
        build_admin_credentials()


def test_missing_homeserver_fails_fast(env):
    env.setenv("MATRIX_HOMESERVER", "")

    with pytest.raises(ValueError, match="homeserver"):
        build_admin_credentials()


def test_trailing_slash_is_normalised_away(env):
    """Otherwise every request path would contain a double slash."""
    env.setenv("MATRIX_HOMESERVER", "https://matrix.example.com/")

    assert build_admin_credentials().base_url == "https://matrix.example.com"


def test_container_builds_every_service(env):
    container = Container()

    assert isinstance(container.get_repository(), ProvisioningRepository)
    assert isinstance(container.get_provisioner(), SynapseProvisioner)
    assert isinstance(container.get_admin_client(), SynapseAdminClient)
    assert isinstance(container.get_bundle_service(), BundleService)
    assert isinstance(container.get_redemption_poller(), RedemptionPoller)
    assert isinstance(container.get_retention_service(), RetentionService)


def test_services_are_singletons(env):
    container = Container()

    assert container.get_repository() is container.get_repository()


def test_unknown_service_is_rejected(env):
    with pytest.raises(ValueError, match="not found"):
        Container().get("no_such_service")


def test_override_replaces_an_instance(env, tmp_path):
    container = Container()
    replacement = ProvisioningRepository(str(tmp_path / "other.db"))

    container.override("provisioning_repository", replacement)

    assert container.get_repository() is replacement


def test_reset_drops_instances(env):
    container = Container()
    first = container.get_repository()

    container.reset()

    assert container.get_repository() is not first


def test_poller_reads_its_schedule_from_the_environment(env):
    env.setenv("POLL_INTERVAL_SECONDS", "42")
    env.setenv("POLL_BATCH_SIZE", "7")

    poller = Container().get_redemption_poller()

    assert poller._interval_seconds == 42
    assert poller._batch_size == 7


def test_retention_window_is_configurable(env):
    env.setenv("RETENTION_DAYS", "45")

    assert Container().get_retention_service()._default_retention_days == 45
