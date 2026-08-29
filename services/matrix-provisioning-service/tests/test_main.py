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
    def __init__(self):
        self.closed = False

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
        assert resolved == ["repository", "identity", "subscription", "notifications"]
        assert all(task.started for task in (poller, retention, reconciler, reaper))
        assert not admin.closed
        assert not google.closed

    assert all(task.stopped for task in (poller, retention, reconciler, reaper))
    assert admin.closed
    assert google.closed
