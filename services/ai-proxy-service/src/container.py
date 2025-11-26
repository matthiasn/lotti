"""Dependency injection container"""

import os
from typing import Any, Callable, Dict, TypeVar, cast

from .core.constants import SERVICE_GEMINI_CLIENT, SERVICE_BILLING_SERVICE
from .core.interfaces import IGeminiClient, IBillingService

T = TypeVar("T")


class Container:
    """Simple dependency injection container"""

    def __init__(self) -> None:
        self._services: Dict[str, Any] = {}
        self._factories: Dict[str, Callable[[], Any]] = {}
        self._configure_factories()

    def _configure_factories(self) -> None:
        """Configure service factory functions for lazy initialization"""
        self._factories[SERVICE_GEMINI_CLIENT] = lambda: self._create_gemini_client()
        self._factories[SERVICE_BILLING_SERVICE] = lambda: self._create_billing_service()

    def _create_gemini_client(self) -> Any:
        """Create Gemini client"""
        from .services.gemini_client import GeminiClient

        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY environment variable is required")

        return GeminiClient(api_key=api_key)

    def _create_billing_service(self) -> Any:
        """Create billing service"""
        from .services.billing_service import BillingService

        return BillingService()

    def get(self, service_name: str) -> Any:
        """Get a service by name (lazy initialization)"""
        if service_name not in self._services:
            if service_name not in self._factories:
                raise ValueError(f"Service '{service_name}' not found")
            # Lazy initialization - create service when first requested
            self._services[service_name] = self._factories[service_name]()
        return self._services[service_name]

    def get_gemini_client(self) -> IGeminiClient:
        """Get Gemini client"""
        return cast(IGeminiClient, self.get(SERVICE_GEMINI_CLIENT))

    def get_billing_service(self) -> IBillingService:
        """Get billing service"""
        return cast(IBillingService, self.get(SERVICE_BILLING_SERVICE))


# Global container instance
container = Container()
