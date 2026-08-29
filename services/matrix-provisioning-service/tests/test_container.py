"""Tests for dependency wiring and credential resolution.

The credential precedence is security-relevant: a stale password in the
environment must never silently win over a configured admin token.
"""

from __future__ import annotations

import base64
import json
from datetime import timedelta

import pytest
from src.container import Container, GoogleAccessTokenProvider, build_admin_credentials
from src.services.bundle_claim_reaper import BundleClaimReaper
from src.services.bundle_rotation_service import BundleRotationService
from src.services.bundle_service import BundleService
from src.services.google_play_client import GooglePlayClient
from src.services.google_play_notifications import GooglePlayNotificationService
from src.services.paid_bundle_service import PaidBundleService
from src.services.provisioning_repository import ProvisioningRepository
from src.services.redemption_poller import RedemptionPoller
from src.services.retention_service import RetentionService
from src.services.secret_cipher import SecretCipher
from src.services.subscription_access_service import SubscriptionAccessService
from src.services.subscription_identity_service import SubscriptionIdentityService
from src.services.subscription_reconciler import SubscriptionReconciler
from src.services.subscription_repository import SubscriptionRepository
from src.services.subscription_service import SubscriptionService

from shared.matrix import SynapseAdminClient, SynapseProvisioner


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

    assert credentials.admin_token == "syt_admin_token"  # noqa: S105 - test fixture


def test_password_login_is_the_fallback(env):
    credentials = build_admin_credentials()

    assert credentials.admin_token is None
    assert credentials.admin_user == "admin"


def test_blank_token_falls_back_rather_than_authenticating_with_empty_string(env):
    """An unset-but-present env var must not become a literal empty token."""
    env.setenv("MATRIX_ADMIN_TOKEN", "")

    credentials = build_admin_credentials()

    assert credentials.admin_token is None
    assert credentials.admin_password == "secret"  # noqa: S105 - test fixture


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


def configure_play(env):
    env.setenv(
        "SUBSCRIPTION_ENCRYPTION_KEY_BASE64",
        base64.b64encode(bytes(range(32))).decode(),
    )
    env.setenv("SUBSCRIPTION_ENCRYPTION_KEY_ID", "key-v1")
    env.setenv(
        "PLAY_ACCOUNT_BINDING_KEY_BASE64",
        base64.b64encode(bytes(reversed(range(32)))).decode(),
    )
    env.setenv("PLAY_SIGNING_CERTIFICATE_SHA256", "release-certificate")
    env.setenv("PLAY_RTDN_AUDIENCE", "https://provisioner.example/rtdn")
    env.setenv(
        "PLAY_RTDN_SERVICE_ACCOUNT_EMAIL",
        "play-rtdn@example.iam.gserviceaccount.com",
    )


def test_container_builds_complete_play_subscription_graph(env, monkeypatch):
    configure_play(env)
    env.setenv("PURCHASE_VERIFICATION_ATTEMPT_LIMIT", "8")
    env.setenv("PURCHASE_VERIFICATION_ATTEMPT_WINDOW_SECONDS", "420")

    class TokenProvider:
        async def get_token(self):
            return "token"

    monkeypatch.setattr(
        GoogleAccessTokenProvider,
        "from_application_default_credentials",
        lambda: TokenProvider(),
    )
    container = Container()

    assert isinstance(container.get_subscription_repository(), SubscriptionRepository)
    assert container.get_subscription_repository() is container.get_repository()
    assert isinstance(container.get_secret_cipher(), SecretCipher)
    assert isinstance(container.get_google_play_client(), GooglePlayClient)
    assert isinstance(container.get_subscription_identity_service(), SubscriptionIdentityService)
    assert isinstance(container.get_subscription_service(), SubscriptionService)
    assert container.get_subscription_service()._purchase_verification_attempt_limit == 8
    assert container.get_subscription_service()._purchase_verification_attempt_window == timedelta(
        minutes=7
    )
    assert isinstance(container.get_paid_bundle_service(), PaidBundleService)
    assert isinstance(container.get_bundle_rotation_service(), BundleRotationService)
    assert isinstance(container.get_subscription_access_service(), SubscriptionAccessService)
    assert isinstance(container.get_google_play_notifications(), GooglePlayNotificationService)
    assert isinstance(container.get_subscription_reconciler(), SubscriptionReconciler)
    assert isinstance(container.get_bundle_claim_reaper(), BundleClaimReaper)
    assert container.existing("google_play_client") is container.get_google_play_client()


def test_claim_reaper_schedule_and_entitlement_quota_are_configurable(env):
    configure_play(env)
    env.setenv("BUNDLE_CLAIM_REAPER_STARTUP_DELAY_SECONDS", "42")
    env.setenv("ENTITLEMENT_ISSUANCE_LIMIT", "7")
    env.setenv("ENTITLEMENT_ISSUANCE_WINDOW_SECONDS", "1800")
    env.setenv("PURCHASE_INTENT_ISSUANCE_LIMIT", "4")
    env.setenv("PURCHASE_INTENT_ISSUANCE_WINDOW_SECONDS", "600")
    env.setenv("PURCHASE_INTENT_ATTEMPT_LIMIT", "6")
    env.setenv("PURCHASE_INTENT_ATTEMPT_WINDOW_SECONDS", "300")
    container = Container()

    assert container.get_bundle_claim_reaper()._startup_delay_seconds == 42
    identity = container.get_subscription_identity_service()
    assert identity._entitlement_issuance_limit == 7
    assert identity._entitlement_issuance_window == timedelta(minutes=30)
    assert identity._purchase_intent_issuance_limit == 4
    assert identity._purchase_intent_issuance_window == timedelta(minutes=10)
    assert identity._purchase_intent_attempt_limit == 6
    assert identity._purchase_intent_attempt_window == timedelta(minutes=5)


@pytest.mark.parametrize(
    ("name", "value", "message"),
    [
        ("SUBSCRIPTION_ENCRYPTION_KEY_BASE64", "not base64", "valid Base64"),
        (
            "SUBSCRIPTION_ENCRYPTION_KEY_BASE64",
            base64.b64encode(b"short").decode(),
            "exactly 32 bytes",
        ),
        (
            "PLAY_ACCOUNT_BINDING_KEY_BASE64",
            base64.b64encode(b"short").decode(),
            "at least 32 bytes",
        ),
    ],
)
def test_play_secret_configuration_fails_fast(env, name, value, message):
    configure_play(env)
    env.setenv(name, value)
    container = Container()

    with pytest.raises(ValueError, match=message):
        if name.startswith("SUBSCRIPTION_ENCRYPTION"):
            container.get_secret_cipher()
        else:
            container.get_subscription_identity_service()


def test_rtdn_identity_configuration_is_mandatory(env):
    configure_play(env)
    env.delenv("PLAY_RTDN_AUDIENCE")

    with pytest.raises(ValueError, match="PLAY_RTDN_AUDIENCE"):
        Container().get_google_play_notifications()


def test_base_plan_configuration_is_trimmed_and_applied(env):
    configure_play(env)
    env.setenv("PLAY_BASE_PLAN_IDS", " monthly, annual ")

    identity = Container().get_subscription_identity_service()

    assert identity._allowed_products == {"lotti_sync": frozenset({"monthly", "annual"})}


def test_empty_base_plan_configuration_is_rejected(env):
    configure_play(env)
    env.setenv("PLAY_BASE_PLAN_IDS", ", ,")

    with pytest.raises(ValueError, match="at least one base plan"):
        Container().get_subscription_identity_service()


def test_container_loads_decrypt_only_legacy_subscription_key(env):
    configure_play(env)
    legacy_key = bytes(range(31, -1, -1))
    env.setenv(
        "SUBSCRIPTION_DECRYPTION_KEYS_JSON",
        json.dumps({"key-v0": base64.b64encode(legacy_key).decode()}),
    )
    cipher = Container().get_secret_cipher()
    legacy_cipher = SecretCipher(key_id="key-v0", key=legacy_key)
    encrypted = legacy_cipher.encrypt(b"old", purpose="bundle", record_id="claim")

    assert (
        cipher.decrypt(
            encrypted,
            purpose="bundle",
            record_id="claim",
            key_id="key-v0",
        )
        == b"old"
    )


@pytest.mark.parametrize(
    ("value", "message"),
    [
        ("not-json", "valid JSON"),
        ("[]", "JSON string map"),
        ('{"legacy": 123}', "JSON string map"),
        ('{"legacy": "c2hvcnQ="}', "exactly 32 bytes"),
    ],
)
def test_legacy_subscription_key_configuration_fails_fast(env, value, message):
    configure_play(env)
    env.setenv("SUBSCRIPTION_DECRYPTION_KEYS_JSON", value)

    with pytest.raises(ValueError, match=message):
        Container().get_secret_cipher()
