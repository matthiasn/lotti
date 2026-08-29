"""Dependency injection container"""

from __future__ import annotations

import base64
import binascii
import json
import os
from datetime import timedelta
from typing import Any, Callable, Dict, cast

from shared.matrix import AdminCredentials, SynapseAdminClient, SynapseProvisioner

from .core.constants import (
    BUNDLE_CLAIM_REAPER_STARTUP_DELAY_SECONDS,
    DEFAULT_DB_PATH,
    DEFAULT_ENTITLEMENT_ISSUANCE_LIMIT,
    DEFAULT_ENTITLEMENT_ISSUANCE_WINDOW_SECONDS,
    DEFAULT_PAID_PROVISIONING_POLL_SECONDS,
    DEFAULT_PAID_PROVISIONING_WAIT_SECONDS,
    DEFAULT_PLAY_BASE_PLAN_IDS,
    DEFAULT_POLL_BATCH_SIZE,
    DEFAULT_POLL_INTERVAL_SECONDS,
    DEFAULT_PURCHASE_INTENT_ATTEMPT_LIMIT,
    DEFAULT_PURCHASE_INTENT_ATTEMPT_WINDOW_SECONDS,
    DEFAULT_PURCHASE_INTENT_ISSUANCE_LIMIT,
    DEFAULT_PURCHASE_INTENT_ISSUANCE_WINDOW_SECONDS,
    DEFAULT_RETENTION_DAYS,
    DEFAULT_RETENTION_SWEEP_HOURS,
    PAID_PROVISIONING_OPERATION_TIMEOUT_SECONDS,
    PLAY_PACKAGE_NAME,
    PLAY_SUBSCRIPTION_PRODUCT_ID,
    SERVICE_ADMIN_CLIENT,
    SERVICE_BUNDLE_CLAIM_REAPER,
    SERVICE_BUNDLE_ROTATION_SERVICE,
    SERVICE_BUNDLE_SERVICE,
    SERVICE_GOOGLE_PLAY_CLIENT,
    SERVICE_GOOGLE_PLAY_NOTIFICATIONS,
    SERVICE_PAID_BUNDLE_SERVICE,
    SERVICE_PROVISIONER,
    SERVICE_PROVISIONING_REPOSITORY,
    SERVICE_REDEMPTION_POLLER,
    SERVICE_RETENTION_SCHEDULER,
    SERVICE_RETENTION_SERVICE,
    SERVICE_SECRET_CIPHER,
    SERVICE_SUBSCRIPTION_ACCESS_SERVICE,
    SERVICE_SUBSCRIPTION_IDENTITY,
    SERVICE_SUBSCRIPTION_RECONCILER,
    SERVICE_SUBSCRIPTION_REPOSITORY,
    SERVICE_SUBSCRIPTION_SERVICE,
)
from .services.bundle_claim_reaper import BundleClaimReaper
from .services.bundle_rotation_service import BundleRotationService
from .services.bundle_service import BundleService
from .services.google_play_client import GoogleAccessTokenProvider, GooglePlayClient
from .services.google_play_notifications import (
    GooglePlayNotificationService,
    PubSubAuthenticator,
)
from .services.paid_bundle_service import PaidBundleService
from .services.provisioning_repository import ProvisioningRepository
from .services.redemption_poller import RedemptionPoller
from .services.retention_scheduler import RetentionScheduler
from .services.retention_service import RetentionService
from .services.secret_cipher import SecretCipher
from .services.subscription_access_service import SubscriptionAccessService
from .services.subscription_identity_service import SubscriptionIdentityService
from .services.subscription_reconciler import SubscriptionReconciler
from .services.subscription_repository import SubscriptionRepository
from .services.subscription_service import SubscriptionService


def build_admin_credentials() -> AdminCredentials:
    """Read admin credentials from the environment.

    A long-lived ``MATRIX_ADMIN_TOKEN`` is preferred. Password login is
    supported as a fallback so an operator can run the service with the same
    credentials the CLI uses.

    Raises:
        ValueError: If neither a token nor a user/password pair is configured.
    """
    return AdminCredentials(
        homeserver=os.getenv("MATRIX_HOMESERVER", ""),
        admin_token=os.getenv("MATRIX_ADMIN_TOKEN") or None,
        admin_user=os.getenv("MATRIX_ADMIN_USER") or None,
        admin_password=os.getenv("MATRIX_ADMIN_PASSWORD") or None,
    )


def _base64_secret(name: str, *, exact_bytes: int | None = None) -> bytes:
    value = os.getenv(name, "")
    return _decode_base64_secret(value, name=name, exact_bytes=exact_bytes)


def _decode_base64_secret(
    value: str,
    *,
    name: str,
    exact_bytes: int | None = None,
) -> bytes:
    try:
        decoded = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise ValueError(f"{name} must be valid Base64") from exc
    if exact_bytes is not None and len(decoded) != exact_bytes:
        raise ValueError(f"{name} must decode to exactly {exact_bytes} bytes")
    if len(decoded) < 32:
        raise ValueError(f"{name} must decode to at least 32 bytes")
    return decoded


def _subscription_decryption_keys() -> dict[str, bytes]:
    value = os.getenv("SUBSCRIPTION_DECRYPTION_KEYS_JSON", "{}")
    try:
        configured = json.loads(value)
    except json.JSONDecodeError as exc:
        raise ValueError("SUBSCRIPTION_DECRYPTION_KEYS_JSON must be valid JSON") from exc
    if not isinstance(configured, dict) or not all(
        isinstance(key_id, str) and isinstance(encoded_key, str)
        for key_id, encoded_key in configured.items()
    ):
        raise ValueError("SUBSCRIPTION_DECRYPTION_KEYS_JSON must be a JSON string map")
    return {
        key_id: _decode_base64_secret(
            encoded_key,
            name=f"SUBSCRIPTION_DECRYPTION_KEYS_JSON[{key_id!r}]",
            exact_bytes=32,
        )
        for key_id, encoded_key in configured.items()
    }


def _allowed_products() -> dict[str, frozenset[str]]:
    configured = os.getenv("PLAY_BASE_PLAN_IDS", "")
    plans = (
        frozenset(plan.strip() for plan in configured.split(",") if plan.strip())
        if configured
        else DEFAULT_PLAY_BASE_PLAN_IDS
    )
    if not plans:
        raise ValueError("PLAY_BASE_PLAN_IDS must contain at least one base plan")
    return {PLAY_SUBSCRIPTION_PRODUCT_ID: plans}


class Container:
    """Simple dependency injection container"""

    def __init__(self) -> None:
        self._services: Dict[str, Any] = {}
        self._factories: Dict[str, Callable[[], Any]] = {}
        self._configure_factories()

    def _configure_factories(self) -> None:
        self._factories[SERVICE_PROVISIONING_REPOSITORY] = self._create_repository
        self._factories[SERVICE_PROVISIONER] = self._create_provisioner
        self._factories[SERVICE_ADMIN_CLIENT] = self._create_admin_client
        self._factories[SERVICE_BUNDLE_SERVICE] = self._create_bundle_service
        self._factories[SERVICE_REDEMPTION_POLLER] = self._create_redemption_poller
        self._factories[SERVICE_RETENTION_SERVICE] = self._create_retention_service
        self._factories[SERVICE_RETENTION_SCHEDULER] = self._create_retention_scheduler
        self._factories[SERVICE_SUBSCRIPTION_REPOSITORY] = self.get_repository
        self._factories[SERVICE_SECRET_CIPHER] = self._create_secret_cipher
        self._factories[SERVICE_GOOGLE_PLAY_CLIENT] = self._create_google_play_client
        self._factories[SERVICE_SUBSCRIPTION_IDENTITY] = self._create_subscription_identity
        self._factories[SERVICE_SUBSCRIPTION_SERVICE] = self._create_subscription_service
        self._factories[SERVICE_PAID_BUNDLE_SERVICE] = self._create_paid_bundle_service
        self._factories[SERVICE_BUNDLE_ROTATION_SERVICE] = self._create_bundle_rotation_service
        self._factories[SERVICE_SUBSCRIPTION_ACCESS_SERVICE] = (
            self._create_subscription_access_service
        )
        self._factories[SERVICE_GOOGLE_PLAY_NOTIFICATIONS] = self._create_google_play_notifications
        self._factories[SERVICE_SUBSCRIPTION_RECONCILER] = self._create_subscription_reconciler
        self._factories[SERVICE_BUNDLE_CLAIM_REAPER] = self._create_bundle_claim_reaper

    def _create_repository(self) -> SubscriptionRepository:
        return SubscriptionRepository(os.getenv("DB_PATH", DEFAULT_DB_PATH))

    def _create_provisioner(self) -> SynapseProvisioner:
        return SynapseProvisioner(build_admin_credentials())

    def _create_admin_client(self) -> SynapseAdminClient:
        return SynapseAdminClient(build_admin_credentials())

    def _create_bundle_service(self) -> BundleService:
        return BundleService(self.get_provisioner(), self.get_repository(), self.get_admin_client())

    def _create_redemption_poller(self) -> RedemptionPoller:
        return RedemptionPoller(
            self.get_repository(),
            self.get_admin_client(),
            interval_seconds=int(
                os.getenv("POLL_INTERVAL_SECONDS", str(DEFAULT_POLL_INTERVAL_SECONDS))
            ),
            batch_size=int(os.getenv("POLL_BATCH_SIZE", str(DEFAULT_POLL_BATCH_SIZE))),
        )

    def _create_retention_service(self) -> RetentionService:
        return RetentionService(
            self.get_repository(),
            self.get_admin_client(),
            default_retention_days=int(os.getenv("RETENTION_DAYS", str(DEFAULT_RETENTION_DAYS))),
        )

    def _create_retention_scheduler(self) -> RetentionScheduler:
        return RetentionScheduler(
            self.get_retention_service(),
            interval_hours=float(
                os.getenv("RETENTION_SWEEP_HOURS", str(DEFAULT_RETENTION_SWEEP_HOURS))
            ),
            include_media=os.getenv("RETENTION_SWEEP_MEDIA", "true").lower()
            in ("1", "true", "yes"),
        )

    def _create_secret_cipher(self) -> SecretCipher:
        return SecretCipher(
            key_id=os.getenv("SUBSCRIPTION_ENCRYPTION_KEY_ID", ""),
            key=_base64_secret("SUBSCRIPTION_ENCRYPTION_KEY_BASE64", exact_bytes=32),
            decryption_keys=_subscription_decryption_keys(),
        )

    def _create_google_play_client(self) -> GooglePlayClient:
        return GooglePlayClient(GoogleAccessTokenProvider.from_application_default_credentials())

    def _create_subscription_identity(self) -> SubscriptionIdentityService:
        return SubscriptionIdentityService(
            self.get_subscription_repository(),
            account_binding_key=_base64_secret("PLAY_ACCOUNT_BINDING_KEY_BASE64"),
            allowed_products=_allowed_products(),
            entitlement_issuance_limit=int(
                os.getenv(
                    "ENTITLEMENT_ISSUANCE_LIMIT",
                    str(DEFAULT_ENTITLEMENT_ISSUANCE_LIMIT),
                )
            ),
            entitlement_issuance_window=timedelta(
                seconds=float(
                    os.getenv(
                        "ENTITLEMENT_ISSUANCE_WINDOW_SECONDS",
                        str(DEFAULT_ENTITLEMENT_ISSUANCE_WINDOW_SECONDS),
                    )
                )
            ),
            purchase_intent_attempt_limit=int(
                os.getenv(
                    "PURCHASE_INTENT_ATTEMPT_LIMIT",
                    str(DEFAULT_PURCHASE_INTENT_ATTEMPT_LIMIT),
                )
            ),
            purchase_intent_attempt_window=timedelta(
                seconds=float(
                    os.getenv(
                        "PURCHASE_INTENT_ATTEMPT_WINDOW_SECONDS",
                        str(DEFAULT_PURCHASE_INTENT_ATTEMPT_WINDOW_SECONDS),
                    )
                )
            ),
            purchase_intent_issuance_limit=int(
                os.getenv(
                    "PURCHASE_INTENT_ISSUANCE_LIMIT",
                    str(DEFAULT_PURCHASE_INTENT_ISSUANCE_LIMIT),
                )
            ),
            purchase_intent_issuance_window=timedelta(
                seconds=float(
                    os.getenv(
                        "PURCHASE_INTENT_ISSUANCE_WINDOW_SECONDS",
                        str(DEFAULT_PURCHASE_INTENT_ISSUANCE_WINDOW_SECONDS),
                    )
                )
            ),
        )

    def _create_subscription_service(self) -> SubscriptionService:
        certificates = frozenset(
            value.strip()
            for value in os.getenv("PLAY_SIGNING_CERTIFICATE_SHA256", "").split(",")
            if value.strip()
        )
        return SubscriptionService(
            self.get_subscription_repository(),
            self.get_subscription_identity_service(),
            self.get_google_play_client(),
            self.get_secret_cipher(),
            package_name=PLAY_PACKAGE_NAME,
            allowed_products=_allowed_products(),
            certificate_sha256_digests=certificates,
            allow_test_purchases=os.getenv("PLAY_ALLOW_TEST_PURCHASES", "false").lower()
            in ("1", "true", "yes"),
        )

    def _create_paid_bundle_service(self) -> PaidBundleService:
        return PaidBundleService(
            self.get_bundle_service(),
            self.get_subscription_repository(),
            self.get_google_play_client(),
            self.get_secret_cipher(),
            provisioning_wait_seconds=float(
                os.getenv(
                    "PAID_PROVISIONING_WAIT_SECONDS",
                    str(DEFAULT_PAID_PROVISIONING_WAIT_SECONDS),
                )
            ),
            provisioning_poll_seconds=float(
                os.getenv(
                    "PAID_PROVISIONING_POLL_SECONDS",
                    str(DEFAULT_PAID_PROVISIONING_POLL_SECONDS),
                )
            ),
            provisioning_operation_timeout=timedelta(
                seconds=float(
                    os.getenv(
                        "PAID_PROVISIONING_OPERATION_TIMEOUT_SECONDS",
                        str(PAID_PROVISIONING_OPERATION_TIMEOUT_SECONDS),
                    )
                )
            ),
        )

    def _create_bundle_rotation_service(self) -> BundleRotationService:
        return BundleRotationService(
            self.get_subscription_repository(),
            self.get_subscription_identity_service(),
            self.get_admin_client(),
            self.get_secret_cipher(),
        )

    def _create_subscription_access_service(self) -> SubscriptionAccessService:
        return SubscriptionAccessService(
            self.get_subscription_repository(),
            self.get_admin_client(),
        )

    def _create_google_play_notifications(self) -> GooglePlayNotificationService:
        audience = os.getenv("PLAY_RTDN_AUDIENCE", "")
        email = os.getenv("PLAY_RTDN_SERVICE_ACCOUNT_EMAIL", "")
        if not audience or not email:
            raise ValueError("PLAY_RTDN_AUDIENCE and PLAY_RTDN_SERVICE_ACCOUNT_EMAIL are required")
        return GooglePlayNotificationService(
            PubSubAuthenticator(audience=audience, service_account_email=email),
            self.get_subscription_service(),
            self.get_subscription_access_service(),
            self.get_subscription_repository(),
            package_name=PLAY_PACKAGE_NAME,
        )

    def _create_subscription_reconciler(self) -> SubscriptionReconciler:
        return SubscriptionReconciler(
            self.get_subscription_repository(),
            self.get_subscription_service(),
            self.get_subscription_access_service(),
            self.get_secret_cipher(),
            interval_seconds=float(os.getenv("SUBSCRIPTION_RECONCILE_INTERVAL_SECONDS", "60")),
            batch_size=int(os.getenv("SUBSCRIPTION_RECONCILE_BATCH_SIZE", "50")),
        )

    def _create_bundle_claim_reaper(self) -> BundleClaimReaper:
        return BundleClaimReaper(
            self.get_subscription_repository(),
            self.get_admin_client(),
            interval_seconds=float(os.getenv("BUNDLE_CLAIM_REAPER_INTERVAL_SECONDS", "300")),
            startup_delay_seconds=float(
                os.getenv(
                    "BUNDLE_CLAIM_REAPER_STARTUP_DELAY_SECONDS",
                    str(BUNDLE_CLAIM_REAPER_STARTUP_DELAY_SECONDS),
                )
            ),
            batch_size=int(os.getenv("BUNDLE_CLAIM_REAPER_BATCH_SIZE", "50")),
        )

    def get(self, service_name: str) -> Any:
        """Get a service by name (lazy initialization)"""
        if service_name not in self._services:
            if service_name not in self._factories:
                raise ValueError(f"Service '{service_name}' not found")
            self._services[service_name] = self._factories[service_name]()
        return self._services[service_name]

    def override(self, service_name: str, instance: Any) -> None:
        """Replace a service instance. Intended for tests."""
        self._services[service_name] = instance

    def reset(self) -> None:
        """Drop all instantiated services. Intended for tests."""
        self._services.clear()

    def existing(self, service_name: str) -> Any | None:
        """Return an instantiated service without triggering lazy creation."""
        return self._services.get(service_name)

    def get_repository(self) -> ProvisioningRepository:
        """Get the provisioning repository"""
        return cast(ProvisioningRepository, self.get(SERVICE_PROVISIONING_REPOSITORY))

    def get_subscription_repository(self) -> SubscriptionRepository:
        """Get the repository that adds paid state to the provisioning database."""
        return cast(SubscriptionRepository, self.get(SERVICE_SUBSCRIPTION_REPOSITORY))

    def get_provisioner(self) -> SynapseProvisioner:
        """Get the Synapse provisioner"""
        return cast(SynapseProvisioner, self.get(SERVICE_PROVISIONER))

    def get_admin_client(self) -> SynapseAdminClient:
        """Get the Synapse admin client"""
        return cast(SynapseAdminClient, self.get(SERVICE_ADMIN_CLIENT))

    def get_bundle_service(self) -> BundleService:
        """Get the bundle service"""
        return cast(BundleService, self.get(SERVICE_BUNDLE_SERVICE))

    def get_redemption_poller(self) -> RedemptionPoller:
        """Get the redemption poller"""
        return cast(RedemptionPoller, self.get(SERVICE_REDEMPTION_POLLER))

    def get_retention_service(self) -> RetentionService:
        """Get the retention service"""
        return cast(RetentionService, self.get(SERVICE_RETENTION_SERVICE))

    def get_retention_scheduler(self) -> RetentionScheduler:
        """Get the retention sweep scheduler"""
        return cast(RetentionScheduler, self.get(SERVICE_RETENTION_SCHEDULER))

    def get_secret_cipher(self) -> SecretCipher:
        return cast(SecretCipher, self.get(SERVICE_SECRET_CIPHER))

    def get_google_play_client(self) -> GooglePlayClient:
        return cast(GooglePlayClient, self.get(SERVICE_GOOGLE_PLAY_CLIENT))

    def get_subscription_identity_service(self) -> SubscriptionIdentityService:
        return cast(
            SubscriptionIdentityService,
            self.get(SERVICE_SUBSCRIPTION_IDENTITY),
        )

    def get_subscription_service(self) -> SubscriptionService:
        return cast(SubscriptionService, self.get(SERVICE_SUBSCRIPTION_SERVICE))

    def get_paid_bundle_service(self) -> PaidBundleService:
        return cast(PaidBundleService, self.get(SERVICE_PAID_BUNDLE_SERVICE))

    def get_bundle_rotation_service(self) -> BundleRotationService:
        return cast(BundleRotationService, self.get(SERVICE_BUNDLE_ROTATION_SERVICE))

    def get_subscription_access_service(self) -> SubscriptionAccessService:
        return cast(
            SubscriptionAccessService,
            self.get(SERVICE_SUBSCRIPTION_ACCESS_SERVICE),
        )

    def get_google_play_notifications(self) -> GooglePlayNotificationService:
        return cast(
            GooglePlayNotificationService,
            self.get(SERVICE_GOOGLE_PLAY_NOTIFICATIONS),
        )

    def get_subscription_reconciler(self) -> SubscriptionReconciler:
        return cast(
            SubscriptionReconciler,
            self.get(SERVICE_SUBSCRIPTION_RECONCILER),
        )

    def get_bundle_claim_reaper(self) -> BundleClaimReaper:
        return cast(BundleClaimReaper, self.get(SERVICE_BUNDLE_CLAIM_REAPER))


# Global container instance
container = Container()
