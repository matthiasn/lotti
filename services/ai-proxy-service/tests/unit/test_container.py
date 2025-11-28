"""Unit tests for dependency injection container"""

import os
import pytest
from unittest.mock import patch
from src.container import Container
from src.services.gemini_client import GeminiClient
from src.services.billing_service import BillingService


class TestContainer:
    """Test cases for Container"""

    def test_container_initialization(self):
        """Test container initialization"""
        container = Container()
        assert container._services == {}
        assert len(container._factories) == 2

    @patch("google.generativeai.configure")
    @patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"})
    def test_get_gemini_client(self, mock_configure):
        """Test getting Gemini client from container"""
        container = Container()
        client = container.get_gemini_client()

        assert isinstance(client, GeminiClient)
        assert client is container.get_gemini_client()  # Should be singleton

    def test_get_billing_service(self):
        """Test getting billing service from container"""
        container = Container()
        service = container.get_billing_service()

        assert isinstance(service, BillingService)
        assert service is container.get_billing_service()  # Should be singleton

    @patch.dict(os.environ, {}, clear=True)
    def test_container_missing_api_key(self):
        """Test container error when API key is missing"""
        container = Container()

        with pytest.raises(ValueError, match="GEMINI_API_KEY"):
            container.get_gemini_client()

    def test_get_unknown_service(self):
        """Test getting unknown service from container"""
        container = Container()

        with pytest.raises(ValueError, match="not found"):
            container.get("unknown_service")

    @patch("google.generativeai.configure")
    @patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"})
    def test_container_singleton_pattern(self, mock_configure):
        """Test that container returns the same instance for each service"""
        container = Container()

        # Get services multiple times
        client1 = container.get_gemini_client()
        client2 = container.get_gemini_client()
        service1 = container.get_billing_service()
        service2 = container.get_billing_service()

        # Verify singletons
        assert client1 is client2
        assert service1 is service2

    @patch("google.generativeai.configure")
    @patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"})
    def test_container_generic_get_method(self, mock_configure):
        """Test generic get method for services"""
        container = Container()

        gemini_client = container.get("gemini_client")
        billing_service = container.get("billing_service")

        assert isinstance(gemini_client, GeminiClient)
        assert isinstance(billing_service, BillingService)
