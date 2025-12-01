"""Dependency injection container"""

import os
from typing import Any, Callable, Dict, TypeVar, cast

from .core.constants import (
    SERVICE_ACCOUNT_SERVICE,
    SERVICE_BALANCE_SERVICE,
    SERVICE_BILLING_SERVICE,
    SERVICE_TIGERBEETLE_CLIENT,
)
from .core.interfaces import (
    IAccountService,
    IBalanceService,
    IBillingService,
    ITigerBeetleClient,
)

T = TypeVar("T")


class Container:
    """Simple dependency injection container"""

    def __init__(self) -> None:
        self._services: Dict[str, Any] = {}
        self._factories: Dict[str, Callable[[], Any]] = {}
        self._configure_factories()

    def _configure_factories(self) -> None:
        """Configure service factory functions for lazy initialization"""
        self._factories[SERVICE_TIGERBEETLE_CLIENT] = lambda: self._create_tigerbeetle_client()
        self._factories[SERVICE_ACCOUNT_SERVICE] = lambda: self._create_account_service()
        self._factories[SERVICE_BALANCE_SERVICE] = lambda: self._create_balance_service()
        self._factories[SERVICE_BILLING_SERVICE] = lambda: self._create_billing_service()

    def _create_tigerbeetle_client(self) -> Any:
        """Create TigerBeetle client"""
        from .services.tigerbeetle_client import TigerBeetleClient

        cluster_id = int(os.getenv("TIGERBEETLE_CLUSTER_ID", "0"))
        host = os.getenv("TIGERBEETLE_HOST", "localhost")
        port = os.getenv("TIGERBEETLE_PORT", "3000")

        addresses = f"{host}:{port}"

        return TigerBeetleClient(cluster_id=cluster_id, addresses=addresses)

    def _create_account_service(self) -> Any:
        """Create account service"""
        from .services.account_service import AccountService

        return AccountService(self.get_tigerbeetle_client())

    def _create_balance_service(self) -> Any:
        """Create balance service"""
        from .services.balance_service import BalanceService

        return BalanceService(self.get_tigerbeetle_client())

    def _create_billing_service(self) -> Any:
        """Create billing service"""
        from .services.billing_service import BillingService

        return BillingService(self.get_tigerbeetle_client())

    def get(self, service_name: str) -> Any:
        """Get a service by name (lazy initialization)"""
        if service_name not in self._services:
            if service_name not in self._factories:
                raise ValueError(f"Service '{service_name}' not found")
            # Lazy initialization - create service when first requested
            self._services[service_name] = self._factories[service_name]()
        return self._services[service_name]

    def get_tigerbeetle_client(self) -> ITigerBeetleClient:
        """Get TigerBeetle client"""
        return cast(ITigerBeetleClient, self.get(SERVICE_TIGERBEETLE_CLIENT))

    def get_account_service(self) -> IAccountService:
        """Get account service"""
        return cast(IAccountService, self.get(SERVICE_ACCOUNT_SERVICE))

    def get_balance_service(self) -> IBalanceService:
        """Get balance service"""
        return cast(IBalanceService, self.get(SERVICE_BALANCE_SERVICE))

    def get_billing_service(self) -> IBillingService:
        """Get billing service"""
        return cast(IBillingService, self.get(SERVICE_BILLING_SERVICE))


# Global container instance
container = Container()
