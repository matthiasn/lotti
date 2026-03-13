"""Dependency injection container"""

import logging
import os
from typing import Any, Callable, Dict, TypeVar, cast

logger = logging.getLogger(__name__)

from .core.constants import (
    SERVICE_GEMINI_CLIENT,
    SERVICE_BILLING_SERVICE,
    SERVICE_USAGE_LOG,
    SERVICE_PRICING_SERVICE,
)
from .core.interfaces import IGeminiClient, IBillingService, IUsageLogService, IPricingService

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
        self._factories[SERVICE_USAGE_LOG] = lambda: self._create_usage_log_service()
        self._factories[SERVICE_PRICING_SERVICE] = lambda: self._create_pricing_service()

    def _create_gemini_client(self) -> Any:
        """Create Gemini client"""
        from .services.gemini_client import GeminiClient

        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY environment variable is required")

        return GeminiClient(api_key=api_key)

    def _create_pricing_service(self) -> Any:
        """Create pricing service"""
        from .services.pricing_service import PricingService

        return PricingService()

    def _create_billing_service(self) -> Any:
        """Create billing service, wired with pricing service"""
        from .services.billing_service import BillingService

        try:
            pricing_service = self.get_pricing_service()
        except Exception:
            logger.exception("Pricing service unavailable; falling back to static pricing")
            pricing_service = None
        return BillingService(pricing_service=pricing_service)

    def _create_usage_log_service(self) -> Any:
        """Create usage log service"""
        from .services.usage_log_service import UsageLogService

        return UsageLogService()

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

    def get_usage_log(self) -> IUsageLogService:
        """Get usage log service"""
        return cast(IUsageLogService, self.get(SERVICE_USAGE_LOG))

    def get_pricing_service(self) -> IPricingService:
        """Get pricing service"""
        return cast(IPricingService, self.get(SERVICE_PRICING_SERVICE))


# Global container instance
container = Container()
