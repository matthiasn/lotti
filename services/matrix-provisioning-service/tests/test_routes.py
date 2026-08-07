"""Tests for the HTTP API.

Covers the auth boundary, status codes and the request/response contract the
admin SPA and the Lotti client depend on.
"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from shared.matrix import SynapseAdminClient, SynapseProvisioner
from src.container import (
    SERVICE_RETENTION_SERVICE,
    container,
)
from src.core.constants import (
    SERVICE_ADMIN_CLIENT,
    SERVICE_BUNDLE_SERVICE,
    SERVICE_PROVISIONING_REPOSITORY,
)
from src.main import app
from src.services.bundle_service import BundleService
from src.services.retention_service import RetentionService

ADMIN_AUTH = {"Authorization": "Bearer test-admin-key"}
CLIENT_AUTH = {"Authorization": "Bearer test-key"}


@pytest.fixture
def client(repository, credentials, mock_transport):
    """A TestClient whose container is wired to the mock homeserver and temp DB."""
    admin_client = SynapseAdminClient(credentials, transport=mock_transport)
    provisioner = SynapseProvisioner(credentials, transport=mock_transport)

    container.reset()
    container.override(SERVICE_PROVISIONING_REPOSITORY, repository)
    container.override(SERVICE_ADMIN_CLIENT, admin_client)
    container.override(
        SERVICE_BUNDLE_SERVICE, BundleService(provisioner, repository, admin_client)
    )
    container.override(
        SERVICE_RETENTION_SERVICE, RetentionService(repository, admin_client)
    )
    with TestClient(app) as test_client:
        yield test_client
    container.reset()


def _rotated_url(bundle_id: str) -> str:
    return f"/api/v1/client/bundles/{bundle_id}/rotated"


def _create(client, username="lotti_user") -> dict:
    response = client.post("/api/v1/bundles", json={"username": username}, headers=ADMIN_AUTH)
    assert response.status_code == 201, response.text
    return response.json()


# -- auth -------------------------------------------------------------------


def test_health_needs_no_credentials(client):
    assert client.get("/health").status_code == 200


def test_admin_endpoints_reject_a_missing_key(client):
    assert client.get("/api/v1/bundles").status_code == 401


def test_admin_endpoints_reject_a_non_admin_key(client):
    """The client key must not be able to provision accounts or read the roster."""
    assert client.get("/api/v1/bundles", headers=CLIENT_AUTH).status_code == 403
    assert (
        client.post(
            "/api/v1/bundles", json={"username": "sneaky_user"}, headers=CLIENT_AUTH
        ).status_code
        == 403
    )


def test_stats_and_purges_require_an_admin_key(client):
    assert client.get("/api/v1/stats", headers=CLIENT_AUTH).status_code == 403
    assert client.post("/api/v1/purges", headers=CLIENT_AUTH).status_code == 403


# -- bundle creation --------------------------------------------------------


def test_create_returns_the_bundle_and_record(client):
    body = _create(client)

    assert body["bundle"]
    assert body["user"]["status"] == "unused"
    assert body["user"]["payment_status"] == "unknown"


def test_created_bundle_is_a_decodable_v2_payload(client):
    from shared.matrix.bundle import SyncBundle

    decoded = SyncBundle.decode(_create(client)["bundle"])

    assert decoded.version == 2
    assert decoded.kind.value == "provisioned"


def test_duplicate_username_conflicts(client):
    _create(client)

    response = client.post(
        "/api/v1/bundles", json={"username": "lotti_user"}, headers=ADMIN_AUTH
    )

    assert response.status_code == 409


def test_invalid_username_is_a_validation_error(client):
    response = client.post(
        "/api/v1/bundles", json={"username": "no"}, headers=ADMIN_AUTH
    )

    assert response.status_code == 422


# -- reads ------------------------------------------------------------------


def test_list_returns_pagination_metadata(client):
    _create(client, "user_one")
    _create(client, "user_two")

    body = client.get("/api/v1/bundles?page=1&page_size=1", headers=ADMIN_AUTH).json()

    assert body["total"] == 2
    assert len(body["users"]) == 1
    assert body["page_size"] == 1


def test_list_filters_by_status(client):
    _create(client, "user_one")

    body = client.get("/api/v1/bundles?status=rotated", headers=ADMIN_AUTH).json()

    assert body["total"] == 0


def test_get_unknown_bundle_is_404(client):
    assert client.get("/api/v1/bundles/nope", headers=ADMIN_AUTH).status_code == 404


def test_events_endpoint_returns_the_audit_trail(client):
    bundle_id = _create(client)["user"]["bundle_id"]

    events = client.get(f"/api/v1/bundles/{bundle_id}/events", headers=ADMIN_AUTH).json()

    assert [e["event_type"] for e in events] == ["created"]


def test_events_for_an_unknown_bundle_is_404(client):
    assert (
        client.get("/api/v1/bundles/nope/events", headers=ADMIN_AUTH).status_code == 404
    )


# -- updates ----------------------------------------------------------------


def test_patch_updates_payment_status_and_notes(client):
    bundle_id = _create(client)["user"]["bundle_id"]

    body = client.patch(
        f"/api/v1/bundles/{bundle_id}",
        json={"payment_status": "paying", "notes": "paid via bank transfer"},
        headers=ADMIN_AUTH,
    ).json()

    assert body["payment_status"] == "paying"
    assert body["notes"] == "paid via bank transfer"


def test_patch_unknown_bundle_is_404(client):
    response = client.patch(
        "/api/v1/bundles/nope", json={"payment_status": "paying"}, headers=ADMIN_AUTH
    )

    assert response.status_code == 404


def test_patch_rejects_an_unknown_payment_status(client):
    bundle_id = _create(client)["user"]["bundle_id"]

    response = client.patch(
        f"/api/v1/bundles/{bundle_id}",
        json={"payment_status": "freeloader"},
        headers=ADMIN_AUTH,
    )

    assert response.status_code == 422


# -- rotation callback ------------------------------------------------------


def test_rotation_callback_accepts_the_client_key(client):
    """The Lotti client confirms rotation without holding admin credentials."""
    bundle_id = _create(client)["user"]["bundle_id"]

    response = client.post(_rotated_url(bundle_id), headers=CLIENT_AUTH)

    assert response.status_code == 200
    assert response.json()["status"] == "rotated"


def test_rotation_callback_is_idempotent(client):
    bundle_id = _create(client)["user"]["bundle_id"]
    first = client.post(_rotated_url(bundle_id), headers=CLIENT_AUTH)

    second = client.post(_rotated_url(bundle_id), headers=CLIENT_AUTH)

    assert second.status_code == 200
    assert second.json()["rotated_at"] == first.json()["rotated_at"]


def test_rotation_callback_on_a_revoked_bundle_conflicts(client):
    bundle_id = _create(client)["user"]["bundle_id"]
    client.post(f"/api/v1/bundles/{bundle_id}/revoke", headers=ADMIN_AUTH)

    response = client.post(_rotated_url(bundle_id), headers=CLIENT_AUTH)

    assert response.status_code == 409


def test_rotation_callback_for_an_unknown_bundle_is_404(client):
    assert (
        client.post(_rotated_url("nope"), headers=CLIENT_AUTH).status_code
        == 404
    )


# -- revocation -------------------------------------------------------------


def test_revoke_marks_the_record_revoked(client):
    bundle_id = _create(client)["user"]["bundle_id"]

    body = client.post(
        f"/api/v1/bundles/{bundle_id}/revoke?reason=leaked", headers=ADMIN_AUTH
    ).json()

    assert body["status"] == "revoked"
    assert body["revoked_at"] is not None


# -- stats and usage --------------------------------------------------------


def test_stats_reflects_created_records(client):
    _create(client, "user_one")
    _create(client, "user_two")

    body = client.get("/api/v1/stats", headers=ADMIN_AUTH).json()

    assert body["total_provisioned"] == 2
    assert body["unused"] == 2
    assert sum(body["signups_by_day"].values()) == 2


def test_usage_reports_live_synapse_figures(client):
    bundle_id = _create(client)["user"]["bundle_id"]

    body = client.get(f"/api/v1/bundles/{bundle_id}/usage", headers=ADMIN_AUTH).json()

    assert body["device_count"] == 1
    assert body["media_count"] == 2
    assert body["media_length_bytes"] == 3500


def test_usage_for_an_unknown_bundle_is_404(client):
    assert (
        client.get("/api/v1/bundles/nope/usage", headers=ADMIN_AUTH).status_code == 404
    )


# -- retention --------------------------------------------------------------


def test_purge_starts_a_run(client):
    bundle_id = _create(client)["user"]["bundle_id"]
    client.post(_rotated_url(bundle_id), headers=CLIENT_AUTH)

    body = client.post(
        f"/api/v1/bundles/{bundle_id}/purge", headers=ADMIN_AUTH
    ).json()

    assert body["purge_id"] == "purge_abc"
    assert body["retention_days"] == 30


def test_purge_below_the_floor_is_a_bad_request(client):
    bundle_id = _create(client)["user"]["bundle_id"]

    response = client.post(
        f"/api/v1/bundles/{bundle_id}/purge?retention_days=1", headers=ADMIN_AUTH
    )

    assert response.status_code == 400


def test_purge_for_an_unknown_bundle_is_404(client):
    assert (
        client.post("/api/v1/bundles/nope/purge", headers=ADMIN_AUTH).status_code == 404
    )


def test_purge_status_endpoint_reports_completion(client):
    bundle_id = _create(client)["user"]["bundle_id"]
    client.post(_rotated_url(bundle_id), headers=CLIENT_AUTH)
    client.post(f"/api/v1/bundles/{bundle_id}/purge", headers=ADMIN_AUTH)

    body = client.get("/api/v1/purges/purge_abc", headers=ADMIN_AUTH).json()

    assert body["status"] == "complete"


def test_purge_all_skips_unredeemed_rooms(client):
    _create(client, "never_used")

    body = client.post("/api/v1/purges", headers=ADMIN_AUTH).json()

    assert body["started"] == 0


def test_list_purges_is_empty_before_any_run(client):
    assert client.get("/api/v1/purges", headers=ADMIN_AUTH).json()["purges"] == []


# -- homeserver failures ----------------------------------------------------


@pytest.fixture
def broken_synapse_client(repository, credentials):
    """A client whose homeserver rejects everything after admin login."""
    import httpx

    from tests.conftest import synapse_handler

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/_matrix/client/v3/login":
            return synapse_handler(request)
        return httpx.Response(503, json={"errcode": "M_UNKNOWN"})

    transport = httpx.MockTransport(handler)
    admin_client = SynapseAdminClient(credentials, transport=transport)
    provisioner = SynapseProvisioner(credentials, transport=transport)

    container.reset()
    container.override(SERVICE_PROVISIONING_REPOSITORY, repository)
    container.override(SERVICE_ADMIN_CLIENT, admin_client)
    container.override(
        SERVICE_BUNDLE_SERVICE, BundleService(provisioner, repository, admin_client)
    )
    container.override(
        SERVICE_RETENTION_SERVICE, RetentionService(repository, admin_client)
    )
    with TestClient(app) as test_client:
        yield test_client
    container.reset()


def test_create_returns_502_when_synapse_is_down(broken_synapse_client):
    response = broken_synapse_client.post(
        "/api/v1/bundles", json={"username": "lotti_user"}, headers=ADMIN_AUTH
    )

    assert response.status_code == 502


def _seed_directly(repository):
    """Insert a record without going through the API, which needs a live Synapse."""
    import asyncio

    from tests.conftest import seed_user

    return asyncio.run(seed_user(repository))


def test_usage_returns_502_when_synapse_is_down(broken_synapse_client, repository):
    user = _seed_directly(repository)

    response = broken_synapse_client.get(
        f"/api/v1/bundles/{user.bundle_id}/usage", headers=ADMIN_AUTH
    )

    assert response.status_code == 502


def test_purge_returns_502_when_synapse_is_down(broken_synapse_client, repository):
    user = _seed_directly(repository)

    response = broken_synapse_client.post(
        f"/api/v1/bundles/{user.bundle_id}/purge", headers=ADMIN_AUTH
    )

    assert response.status_code == 502


def test_purge_status_returns_502_when_synapse_is_down(broken_synapse_client):
    response = broken_synapse_client.get("/api/v1/purges/purge_abc", headers=ADMIN_AUTH)

    assert response.status_code == 502


def test_revoke_with_deactivation_returns_502_when_synapse_is_down(
    broken_synapse_client, repository
):
    user = _seed_directly(repository)

    response = broken_synapse_client.post(
        f"/api/v1/bundles/{user.bundle_id}/revoke?deactivate_account=true",
        headers=ADMIN_AUTH,
    )

    assert response.status_code == 502


def test_get_bundle_returns_the_record(client):
    """The detail endpoint's success path, used by the SPA's drawer."""
    bundle_id = _create(client)["user"]["bundle_id"]

    body = client.get(f"/api/v1/bundles/{bundle_id}", headers=ADMIN_AUTH).json()

    assert body["bundle_id"] == bundle_id
    assert body["username"] == "lotti_user"


def test_purge_all_rejects_a_retention_below_the_floor(client):
    response = client.post("/api/v1/purges?retention_days=3", headers=ADMIN_AUTH)

    assert response.status_code == 400
