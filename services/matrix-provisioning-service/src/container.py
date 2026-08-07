"""Dependency injection container"""

from __future__ import annotations

import os
from typing import Any, Callable, Dict, cast

from shared.matrix import AdminCredentials, SynapseAdminClient, SynapseProvisioner

from .core.constants import (
    DEFAULT_DB_PATH,
    DEFAULT_POLL_BATCH_SIZE,
    DEFAULT_POLL_INTERVAL_SECONDS,
    DEFAULT_RETENTION_DAYS,
    DEFAULT_RETENTION_SWEEP_HOURS,
    SERVICE_ADMIN_CLIENT,
    SERVICE_BUNDLE_SERVICE,
    SERVICE_PROVISIONING_REPOSITORY,
    SERVICE_REDEMPTION_POLLER,
    SERVICE_RETENTION_SCHEDULER,
)
from .services.bundle_service import BundleService
from .services.provisioning_repository import ProvisioningRepository
from .services.redemption_poller import RedemptionPoller
from .services.retention_scheduler import RetentionScheduler
from .services.retention_service import RetentionService

SERVICE_PROVISIONER = "provisioner"
SERVICE_RETENTION_SERVICE = "retention_service"


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

    def _create_repository(self) -> ProvisioningRepository:
        return ProvisioningRepository(os.getenv("DB_PATH", DEFAULT_DB_PATH))

    def _create_provisioner(self) -> SynapseProvisioner:
        return SynapseProvisioner(build_admin_credentials())

    def _create_admin_client(self) -> SynapseAdminClient:
        return SynapseAdminClient(build_admin_credentials())

    def _create_bundle_service(self) -> BundleService:
        return BundleService(
            self.get_provisioner(), self.get_repository(), self.get_admin_client()
        )

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
            default_retention_days=int(
                os.getenv("RETENTION_DAYS", str(DEFAULT_RETENTION_DAYS))
            ),
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

    def get_repository(self) -> ProvisioningRepository:
        """Get the provisioning repository"""
        return cast(ProvisioningRepository, self.get(SERVICE_PROVISIONING_REPOSITORY))

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


# Global container instance
container = Container()
