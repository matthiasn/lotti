"""Tests for bundle creation orchestration.

The behaviour that matters here is what happens when provisioning half-succeeds:
an account that exists on Synapse but is absent from our records is an untracked
live credential, which is the worst possible outcome.
"""

from __future__ import annotations

import httpx
import pytest

from shared.matrix import SynapseAdminClient, SynapseProvisioner
from src.core.exceptions import (
    SynapseUnavailableException,
    UsernameAlreadyProvisionedException,
)
from src.core.models import BundleStatus, CreateBundleRequest
from src.services.bundle_service import BundleService, fingerprint_bundle
from tests.conftest import (
    ROOM_ID,
    SERVER_NAME,
    register_synapse_account,
    synapse_handler,
)

pytestmark = pytest.mark.anyio


def _service(repository, credentials, transport) -> BundleService:
    return BundleService(
        SynapseProvisioner(credentials, transport=transport),
        repository,
        SynapseAdminClient(credentials, transport=transport),
    )


async def test_create_bundle_persists_a_record_and_returns_the_bundle(
    repository, credentials, mock_transport
):
    service = _service(repository, credentials, mock_transport)

    response = await service.create_bundle(CreateBundleRequest(username="lotti_user"))

    assert response.user.user_mxid == f"@lotti_user:{SERVER_NAME}"
    assert response.user.room_id == ROOM_ID
    assert response.user.status is BundleStatus.UNUSED
    assert await repository.get(response.user.bundle_id) is not None


async def test_created_bundle_decodes_to_a_usable_client_payload(
    repository, credentials, mock_transport
):
    from shared.matrix.bundle import BundleKind, SyncBundle

    service = _service(repository, credentials, mock_transport)

    response = await service.create_bundle(CreateBundleRequest(username="lotti_user"))
    decoded = SyncBundle.decode(response.bundle)

    assert decoded.kind is BundleKind.PROVISIONED
    assert decoded.user == f"@lotti_user:{SERVER_NAME}"
    assert decoded.room_id == ROOM_ID
    assert decoded.password


async def test_password_is_never_persisted(repository, credentials, mock_transport):
    """A database compromise must not yield live credentials."""
    from shared.matrix.bundle import SyncBundle

    service = _service(repository, credentials, mock_transport)

    response = await service.create_bundle(CreateBundleRequest(username="lotti_user"))
    password = SyncBundle.decode(response.bundle).password

    stored = await repository.get(response.user.bundle_id)
    assert password not in stored.model_dump_json()
    assert stored.bundle_fingerprint == fingerprint_bundle(response.bundle)


async def test_fingerprint_identifies_a_bundle_without_storing_it(
    repository, credentials, mock_transport
):
    """An admin can confirm a bundle a user quotes matches this record."""
    service = _service(repository, credentials, mock_transport)

    response = await service.create_bundle(CreateBundleRequest(username="lotti_user"))

    assert fingerprint_bundle(response.bundle) == response.user.bundle_fingerprint
    assert fingerprint_bundle(response.bundle + "x") != response.user.bundle_fingerprint


async def test_duplicate_username_fails_before_touching_synapse(
    repository, credentials, tracking_transport
):
    """The cheap failure must not create an account that then needs rollback."""
    transport, requests = tracking_transport
    service = _service(repository, credentials, transport)
    await service.create_bundle(CreateBundleRequest(username="lotti_user"))
    requests.clear()

    with pytest.raises(UsernameAlreadyProvisionedException):
        await service.create_bundle(CreateBundleRequest(username="lotti_user"))

    assert requests == []


async def test_synapse_http_failure_surfaces_as_unavailable(repository, credentials):
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.startswith("/_synapse/admin/v2/users/"):
            return httpx.Response(403, json={"errcode": "M_FORBIDDEN"})
        return synapse_handler(request)

    service = _service(repository, credentials, httpx.MockTransport(handler))

    with pytest.raises(SynapseUnavailableException, match="403"):
        await service.create_bundle(CreateBundleRequest(username="lotti_user"))


async def test_nothing_is_recorded_when_provisioning_fails(repository, credentials):
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/_matrix/client/v3/createRoom":
            return httpx.Response(500, json={"errcode": "M_UNKNOWN"})
        return synapse_handler(request)

    service = _service(repository, credentials, httpx.MockTransport(handler))

    with pytest.raises(SynapseUnavailableException):
        await service.create_bundle(CreateBundleRequest(username="lotti_user"))

    users, total = await repository.list_users()
    assert total == 0 and users == []


async def test_persistence_failure_deactivates_the_orphan_account(
    repository, credentials, tracking_transport, monkeypatch
):
    """An account we cannot track must not be left live on the homeserver."""
    transport, requests = tracking_transport
    service = _service(repository, credentials, transport)

    async def exploding_create(**_kwargs):
        raise RuntimeError("disk full")

    monkeypatch.setattr(repository, "create", exploding_create)

    with pytest.raises(RuntimeError, match="disk full"):
        await service.create_bundle(CreateBundleRequest(username="lotti_user"))

    deactivations = [
        r
        for r in requests
        if r.method == "PUT" and "/_synapse/admin/v2/users/" in str(r.url)
    ]
    assert deactivations, "expected a rollback deactivation call"


async def test_confirm_rotation_marks_the_record_rotated(
    repository, credentials, mock_transport
):
    service = _service(repository, credentials, mock_transport)
    response = await service.create_bundle(CreateBundleRequest(username="lotti_user"))

    updated = await service.confirm_rotation(response.user.bundle_id)

    assert updated.status is BundleStatus.ROTATED
    assert updated.rotated_at is not None


async def test_revoke_without_deactivation_leaves_the_account_alone(
    repository, credentials, tracking_transport
):
    transport, requests = tracking_transport
    service = _service(repository, credentials, transport)
    response = await service.create_bundle(CreateBundleRequest(username="lotti_user"))
    requests.clear()

    updated = await service.revoke(response.user.bundle_id, reason="no longer needed")

    assert updated.status is BundleStatus.REVOKED
    assert requests == []


async def test_revoke_with_deactivation_calls_synapse(
    repository, credentials, tracking_transport
):
    transport, requests = tracking_transport
    service = _service(repository, credentials, transport)
    response = await service.create_bundle(CreateBundleRequest(username="lotti_user"))
    requests.clear()

    updated = await service.revoke(
        response.user.bundle_id, reason="leaked", deactivate_account=True
    )

    assert updated.status is BundleStatus.REVOKED
    assert "account deactivated" in (await repository.get_events(response.user.bundle_id))[
        -1
    ].detail
    assert any(r.method == "PUT" for r in requests)


async def test_revoking_an_unknown_bundle_raises_not_found(
    repository, credentials, mock_transport
):
    from src.core.exceptions import BundleNotFoundException

    service = _service(repository, credentials, mock_transport)

    with pytest.raises(BundleNotFoundException):
        await service.revoke("no-such-bundle")


@pytest.mark.parametrize(
    "username",
    [
        "ab",  # too short
        "has space",
        "-leading",  # must start alphanumeric
        "x" * 65,  # too long
        "",
        "user@host",  # ':' and '@' would corrupt the MXID
        "user:host",
    ],
)
async def test_invalid_usernames_are_rejected_by_the_request_model(username):
    with pytest.raises(ValueError):
        CreateBundleRequest(username=username)


async def test_usernames_are_normalised_to_lowercase_and_trimmed():
    """Synapse localparts are case-sensitive, so normalising avoids near-duplicates."""
    assert CreateBundleRequest(username="  LottiUser  ").username == "lottiuser"


async def test_refuses_to_provision_over_an_account_that_already_exists(
    repository, credentials, mock_transport
):
    """`PUT /users/{mxid}` is an upsert: pushing through resets a live password.

    The record-level pre-check cannot see this — an account created by the CLI,
    or any ordinary Synapse user, has no row in our database at all.
    """
    register_synapse_account(f"@squatter:{SERVER_NAME}")
    service = _service(repository, credentials, mock_transport)

    with pytest.raises(UsernameAlreadyProvisionedException, match="already exists"):
        await service.create_bundle(CreateBundleRequest(username="squatter"))


async def test_an_existing_account_is_never_written_to(
    repository, credentials, tracking_transport
):
    """The point of the guard is that no write reaches the occupied account."""
    transport, requests = tracking_transport
    register_synapse_account(f"@squatter:{SERVER_NAME}")
    service = _service(repository, credentials, transport)

    with pytest.raises(UsernameAlreadyProvisionedException):
        await service.create_bundle(CreateBundleRequest(username="squatter"))

    assert [r for r in requests if r.method == "PUT"] == []
    assert await repository.find_by_username("squatter") is None


async def test_an_inconclusive_existence_check_does_not_provision(
    repository, credentials
):
    """A 500 on the lookup must not be read as "the localpart is free"."""

    def handler(request: httpx.Request) -> httpx.Response:
        if request.method == "GET" and "/_synapse/admin/v2/users/" in str(request.url):
            return httpx.Response(500, json={"errcode": "M_UNKNOWN"})
        return synapse_handler(request)

    service = _service(repository, credentials, httpx.MockTransport(handler))

    with pytest.raises(SynapseUnavailableException):
        await service.create_bundle(CreateBundleRequest(username="lotti_user"))

    assert await repository.find_by_username("lotti_user") is None


async def test_an_unreachable_homeserver_surfaces_as_a_gateway_error(
    repository, credentials
):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused")

    service = _service(repository, credentials, httpx.MockTransport(handler))

    with pytest.raises(SynapseUnavailableException, match="Could not reach"):
        await service.create_bundle(CreateBundleRequest(username="lotti_user"))

    assert await repository.find_by_username("lotti_user") is None
