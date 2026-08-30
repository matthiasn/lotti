"""Tests for application startup and shutdown orchestration."""

from __future__ import annotations

from types import SimpleNamespace

import pytest
from src import main
from src.core.constants import SERVICE_GOOGLE_PLAY_CLIENT

pytestmark = pytest.mark.anyio


class FakePeriodicTask:
    def __init__(self):
        self.started = False
        self.stopped = False

    def start(self):
        self.started = True

    async def stop(self):
        self.stopped = True


class FakeCloseable:
    def __init__(self, *, suspension_error=None):
        self.closed = False
        self.suspension_checks = 0
        self.suspension_error = suspension_error

    async def require_account_suspension_support(self):
        self.suspension_checks += 1
        if self.suspension_error is not None:
            raise self.suspension_error

    async def aclose(self):
        self.closed = True


async def test_lifespan_starts_and_stops_every_enabled_worker(monkeypatch):
    poller = FakePeriodicTask()
    retention = FakePeriodicTask()
    reconciler = FakePeriodicTask()
    reaper = FakePeriodicTask()
    admin = FakeCloseable()
    google = FakeCloseable()
    resolved = []
    fake_container = SimpleNamespace(
        get_repository=lambda: resolved.append("repository"),
        get_redemption_poller=lambda: poller,
        get_retention_scheduler=lambda: retention,
        get_subscription_identity_service=lambda: resolved.append("identity"),
        get_subscription_service=lambda: resolved.append("subscription"),
        get_paid_bundle_service=lambda: resolved.append("paid_bundle"),
        get_google_play_notifications=lambda: resolved.append("notifications"),
        get_subscription_reconciler=lambda: reconciler,
        get_bundle_claim_reaper=lambda: reaper,
        get_admin_client=lambda: admin,
        existing=lambda name: google if name == SERVICE_GOOGLE_PLAY_CLIENT else None,
    )
    monkeypatch.setattr(main, "container", fake_container)
    monkeypatch.setenv("ENABLE_REDEMPTION_POLLING", "true")
    monkeypatch.setenv("ENABLE_RETENTION_SWEEP", "true")
    monkeypatch.setenv("ENABLE_PLAY_SUBSCRIPTIONS", "true")

    async with main.lifespan(main.app):
        assert resolved == [
            "repository",
            "identity",
            "subscription",
            "paid_bundle",
            "notifications",
        ]
        assert admin.suspension_checks == 1
        assert all(task.started for task in (poller, retention, reconciler, reaper))
        assert not admin.closed
        assert not google.closed

    assert all(task.stopped for task in (poller, retention, reconciler, reaper))
    assert admin.closed
    assert google.closed


async def test_lifespan_rejects_subscriptions_without_suspension_support(monkeypatch):
    reconciler = FakePeriodicTask()
    reaper = FakePeriodicTask()
    admin = FakeCloseable(suspension_error=RuntimeError("unsupported Synapse"))
    google = FakeCloseable()
    fake_container = SimpleNamespace(
        get_repository=lambda: None,
        get_subscription_identity_service=lambda: None,
        get_subscription_service=lambda: None,
        get_paid_bundle_service=lambda: None,
        get_google_play_notifications=lambda: None,
        get_subscription_reconciler=lambda: reconciler,
        get_bundle_claim_reaper=lambda: reaper,
        get_admin_client=lambda: admin,
        existing=lambda name: google if name == SERVICE_GOOGLE_PLAY_CLIENT else None,
    )
    monkeypatch.setattr(main, "container", fake_container)
    monkeypatch.setenv("ENABLE_REDEMPTION_POLLING", "false")
    monkeypatch.setenv("ENABLE_RETENTION_SWEEP", "false")
    monkeypatch.setenv("ENABLE_PLAY_SUBSCRIPTIONS", "true")

    with pytest.raises(RuntimeError, match="unsupported Synapse"):
        async with main.lifespan(main.app):
            pytest.fail("Startup must fail before accepting subscription traffic")

    assert admin.suspension_checks == 1
    assert reconciler.started is False
    assert reaper.started is False
    assert admin.closed is True
    assert google.closed is True


async def test_lifespan_rejects_invalid_paid_delivery_configuration(monkeypatch):
    admin = FakeCloseable()
    google = FakeCloseable()

    def invalid_paid_bundle_service():
        raise ValueError("Paid provisioning poll interval must be positive")

    fake_container = SimpleNamespace(
        get_repository=lambda: None,
        get_subscription_identity_service=lambda: None,
        get_subscription_service=lambda: None,
        get_paid_bundle_service=invalid_paid_bundle_service,
        get_google_play_notifications=lambda: None,
        get_admin_client=lambda: admin,
        existing=lambda name: google if name == SERVICE_GOOGLE_PLAY_CLIENT else None,
    )
    monkeypatch.setattr(main, "container", fake_container)
    monkeypatch.setenv("ENABLE_REDEMPTION_POLLING", "false")
    monkeypatch.setenv("ENABLE_RETENTION_SWEEP", "false")
    monkeypatch.setenv("ENABLE_PLAY_SUBSCRIPTIONS", "true")

    with pytest.raises(ValueError, match="poll interval"):
        async with main.lifespan(main.app):
            pytest.fail("Invalid paid delivery settings must fail during startup")

    assert admin.suspension_checks == 0
    assert admin.closed is True
    assert google.closed is True
