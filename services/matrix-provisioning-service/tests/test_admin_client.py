"""Tests for the shared Synapse admin client.

The figures this client reports drive an irreversible decision — how much a
purge reclaimed, and therefore whether retention is working at all — so the
tests here are mostly about *completeness*: Synapse paginates the per-user media
endpoints at 100 rows, and a client that reads one page reports a number that
looks plausible and is wrong.
"""

from __future__ import annotations

import json

import httpx
import pytest
from tests.conftest import register_synapse_account, synapse_handler

from shared.matrix import AdminCredentials, ProvisioningError, SynapseAdminClient
from shared.matrix.admin_client import MEDIA_PAGE_SIZE

pytestmark = pytest.mark.anyio

USER = "@heavy_user:example.com"


def _paged_media_handler(pages: list[dict]):
    """Serve ``pages`` in order from the media listing endpoint.

    Each entry is the raw JSON body for one page, so a test can express exactly
    what Synapse would return including its ``next_token`` chain.
    """
    served: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/media") and request.method == "GET":
            served.append(request)
            return httpx.Response(200, json=pages[min(len(served) - 1, len(pages) - 1)])
        return synapse_handler(request)

    return httpx.MockTransport(handler), served


async def test_media_usage_sums_every_page_not_just_the_first(credentials):
    """A single page would under-report a real account by orders of magnitude."""
    transport, served = _paged_media_handler(
        [
            {
                "total": 250,
                "next_token": 100,
                "media": [{"media_length": 1000}] * MEDIA_PAGE_SIZE,
            },
            {
                "total": 250,
                "next_token": 200,
                "media": [{"media_length": 1000}] * MEDIA_PAGE_SIZE,
            },
            {"total": 250, "media": [{"media_length": 1000}] * 50},
        ]
    )
    client = SynapseAdminClient(credentials, transport=transport)

    usage = await client.get_media_usage(USER)

    assert usage.media_length_bytes == 250_000
    assert usage.media_count == 250
    assert len(served) == 3


async def test_media_usage_follows_the_cursor_synapse_returned(credentials):
    """The second request must resume from ``next_token``, not restart at zero."""
    transport, served = _paged_media_handler(
        [
            {"total": 101, "next_token": 100, "media": [{"media_length": 5}] * 100},
            {"total": 101, "media": [{"media_length": 5}]},
        ]
    )
    client = SynapseAdminClient(credentials, transport=transport)

    await client.get_media_usage(USER)

    assert "from" not in served[0].url.params
    assert served[1].url.params["from"] == "100"


async def test_media_usage_stops_when_synapse_reports_no_more_pages(credentials):
    transport, served = _paged_media_handler(
        [{"total": 2, "media": [{"media_length": 7}, {"media_length": 3}]}]
    )
    client = SynapseAdminClient(credentials, transport=transport)

    usage = await client.get_media_usage(USER)

    assert usage.media_length_bytes == 10
    assert len(served) == 1


async def test_media_usage_falls_back_to_the_row_count_without_a_total(credentials):
    transport, _ = _paged_media_handler([{"media": [{"media_length": 4}] * 3}])
    client = SynapseAdminClient(credentials, transport=transport)

    usage = await client.get_media_usage(USER)

    assert usage.media_count == 3


async def test_media_deletion_keeps_going_until_a_batch_comes_back_empty(credentials):
    """Synapse deletes at most one page per call, so one call caps the reclaim."""
    batches = [
        {"deleted_media": ["mxc://a"] * MEDIA_PAGE_SIZE, "total": MEDIA_PAGE_SIZE},
        {"deleted_media": ["mxc://b"] * 40, "total": 40},
        {"deleted_media": [], "total": 0},
    ]
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/media") and request.method == "DELETE":
            calls.append(request)
            return httpx.Response(200, json=batches[len(calls) - 1])
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    deletion = await client.delete_user_media(USER, before_ts_ms=1_700_000_000_000)

    assert deletion.deleted_count == 140
    assert len(calls) == 3
    assert calls[0].url.params["before_ts"] == "1700000000000"


async def test_media_deletion_reports_nothing_when_there_is_nothing_to_delete(
    credentials,
):
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/media") and request.method == "DELETE":
            return httpx.Response(200, json={"deleted_media": [], "total": 0})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    deletion = await client.delete_user_media(USER, before_ts_ms=1)

    assert deletion.deleted_count == 0


async def test_the_shared_connection_is_reused_across_calls(credentials, mock_transport):
    """The poller and sweep call this per user; a client per call would reconnect."""
    register_synapse_account("@lotti_user:example.com")
    client = SynapseAdminClient(credentials, transport=mock_transport)

    await client.get_user_activity("@lotti_user:example.com")
    first = client._client()
    await client.get_user_activity("@lotti_user:example.com")

    assert client._client() is first
    await client.aclose()


async def test_closing_lets_a_later_call_reopen(credentials, mock_transport):
    """Shutdown must not leave the object permanently broken."""
    register_synapse_account("@lotti_user:example.com")
    client = SynapseAdminClient(credentials, transport=mock_transport)
    await client.get_user_activity("@lotti_user:example.com")
    await client.aclose()

    activity = await client.get_user_activity("@lotti_user:example.com")

    assert activity.has_signed_in
    await client.aclose()


async def test_closing_twice_is_harmless(credentials, mock_transport):
    register_synapse_account("@lotti_user:example.com")
    client = SynapseAdminClient(credentials, transport=mock_transport)
    await client.get_user_activity("@lotti_user:example.com")

    await client.aclose()
    await client.aclose()


async def test_user_activity_reports_suspension(credentials):
    register_synapse_account(USER)

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/@heavy_user:example.com"):
            return httpx.Response(200, json={"deactivated": False, "suspended": True})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    activity = await client.get_user_activity(USER)

    assert activity.suspended is True
    assert activity.deactivated is False


@pytest.mark.parametrize("suspended", [True, False])
async def test_subscription_enforcement_uses_reversible_suspension(
    credentials,
    suspended,
):
    requests = []

    def handler(request: httpx.Request) -> httpx.Response:
        if "/_synapse/admin/v1/suspend/" in request.url.path:
            requests.append(request)
            return httpx.Response(200, json={})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    await client.set_user_suspended(USER, suspended=suspended)

    assert requests[0].url.path.endswith("/@heavy_user:example.com")
    assert requests[0].read().decode() == ('{"suspend":true}' if suspended else '{"suspend":false}')


async def test_suspension_failure_is_not_silently_accepted(credentials):
    def handler(request: httpx.Request) -> httpx.Response:
        if "/_synapse/admin/v1/suspend/" in request.url.path:
            return httpx.Response(503, json={})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    with pytest.raises(ProvisioningError, match="Failed to suspend"):
        await client.set_user_suspended(USER, suspended=True)


@pytest.mark.parametrize(("status_code", "expected"), [(200, True), (403, False)])
async def test_bootstrap_password_check_distinguishes_rejection_from_success(
    credentials,
    status_code,
    expected,
):
    requests = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/_matrix/client/v3/login":
            requests.append(request)
            payload = (
                {"access_token": "token"}
                if status_code == 200
                else {"errcode": "M_FORBIDDEN", "error": "Invalid username or password"}
            )
            return httpx.Response(status_code, json=payload)
        if request.url.path == "/_matrix/client/v3/logout":
            requests.append(request)
            return httpx.Response(200, json={})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    result = await client.password_authenticates(USER, "bootstrap-password")

    assert result is expected
    assert b"bootstrap-password" in requests[0].read()


async def test_bootstrap_password_check_reuses_device_and_logs_out(credentials):
    requests = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if request.url.path == "/_matrix/client/v3/login":
            return httpx.Response(200, json={"access_token": f"token-{len(requests)}"})
        if request.url.path == "/_matrix/client/v3/logout":
            return httpx.Response(200, json={})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    assert await client.password_authenticates(USER, "bootstrap-password") is True
    assert await client.password_authenticates(USER, "bootstrap-password") is True

    logins = [request for request in requests if request.url.path.endswith("/login")]
    logouts = [request for request in requests if request.url.path.endswith("/logout")]
    assert len(logins) == len(logouts) == 2
    assert {json.loads(request.content)["device_id"] for request in logins} == {
        "LOTTI_PROVISIONING_PASSWORD_CHECK"
    }
    assert [request.headers["Authorization"] for request in logouts] == [
        "Bearer token-1",
        "Bearer token-3",
    ]


@pytest.mark.parametrize("payload", [{}, []])
async def test_bootstrap_password_check_requires_login_token(credentials, payload):
    transport = httpx.MockTransport(lambda _: httpx.Response(200, json=payload))
    client = SynapseAdminClient(credentials, transport=transport)

    with pytest.raises(ProvisioningError, match="did not return a login token"):
        await client.password_authenticates(USER, "bootstrap-password")


async def test_bootstrap_password_check_requires_successful_logout(credentials):
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/login"):
            return httpx.Response(200, json={"access_token": "password-check-token"})
        return httpx.Response(503, json={})

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    with pytest.raises(ProvisioningError, match="Could not clean up password check"):
        await client.password_authenticates(USER, "bootstrap-password")


async def test_bootstrap_password_check_does_not_treat_outage_as_rotation(credentials):
    transport = httpx.MockTransport(lambda _: httpx.Response(503, json={}))
    client = SynapseAdminClient(credentials, transport=transport)

    with pytest.raises(ProvisioningError, match="Could not verify"):
        await client.password_authenticates(USER, "bootstrap-password")


@pytest.mark.parametrize(
    "payload",
    [
        {"errcode": "M_FORBIDDEN", "error": "User account is suspended"},
        {"errcode": "M_USER_DEACTIVATED", "error": "This account has been deactivated"},
        {"errcode": "M_FORBIDDEN"},
    ],
)
async def test_bootstrap_password_check_treats_account_state_as_inconclusive(
    credentials,
    payload,
):
    transport = httpx.MockTransport(lambda _: httpx.Response(403, json=payload))
    client = SynapseAdminClient(credentials, transport=transport)

    with pytest.raises(ProvisioningError, match="Could not verify password rotation"):
        await client.password_authenticates(USER, "bootstrap-password")


async def test_bootstrap_password_check_rejects_malformed_auth_failure(credentials):
    transport = httpx.MockTransport(
        lambda _: httpx.Response(403, content=b"not-json", headers={"content-type": "text/plain"})
    )
    client = SynapseAdminClient(credentials, transport=transport)

    with pytest.raises(ProvisioningError, match="Could not verify password rotation"):
        await client.password_authenticates(USER, "bootstrap-password")


async def test_rotation_state_is_read_with_short_lived_user_token(credentials, monkeypatch):
    requests = []
    monkeypatch.setattr("shared.matrix.admin_client.time_ns", lambda: 1_700_000_000_000_000_000)

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if request.url.path == "/_matrix/client/v3/login":
            return httpx.Response(
                200,
                json={"access_token": "admin-token", "user_id": "@admin:example.com"},
            )
        if request.url.path.endswith("/login"):
            return httpx.Response(200, json={"access_token": "user-token"})
        if "/state/" in request.url.path:
            return httpx.Response(200, json={"challenge": "proof"})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    state = await client.get_room_state_as_user(
        USER,
        "!paid:example.com",
        "com.lotti.sync.provisioning.rotation",
        state_key="bundle-id",
    )

    assert state == {"challenge": "proof"}
    login_as_user_request = requests[-2]
    assert login_as_user_request.read().decode() == '{"valid_until_ms":1700000060000}'
    state_request = requests[-1]
    assert state_request.headers["Authorization"] == "Bearer user-token"
    assert state_request.url.path.endswith("/state/com.lotti.sync.provisioning.rotation/bundle-id")


@pytest.mark.parametrize(
    ("login_payload", "state_payload", "message"),
    [
        ({}, {"challenge": "proof"}, "did not return a login token"),
        ([], {"challenge": "proof"}, "did not return a login token"),
        ({"access_token": "user-token"}, ["not", "state"], "invalid room state"),
    ],
)
async def test_rotation_state_rejects_inconclusive_synapse_responses(
    credentials,
    login_payload,
    state_payload,
    message,
):
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/_matrix/client/v3/login":
            return httpx.Response(
                200,
                json={"access_token": "admin-token", "user_id": "@admin:example.com"},
            )
        if request.url.path.endswith("/login"):
            return httpx.Response(200, json=login_payload)
        if "/state/" in request.url.path:
            return httpx.Response(200, json=state_payload)
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    with pytest.raises(ProvisioningError, match=message):
        await client.get_room_state_as_user(
            USER,
            "!paid:example.com",
            "com.lotti.sync.provisioning.rotation",
        )


async def test_paging_gives_up_on_a_homeserver_that_never_advances(
    credentials, monkeypatch, caplog
):
    """A cursor that always points back at itself must not loop forever.

    The sweep calls this per user, so one pathological account would hang
    retention for everyone behind it.
    """
    monkeypatch.setattr("shared.matrix.admin_client.MAX_MEDIA_PAGES", 3)
    served: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/media") and request.method == "GET":
            served.append(request)
            # Always another page, always the same cursor.
            return httpx.Response(
                200, json={"total": 9, "next_token": 0, "media": [{"media_length": 1}]}
            )
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    usage = await client.get_media_usage(USER)

    assert len(served) == 3
    assert usage.media_length_bytes == 3
    assert "Stopped paging media" in caplog.text


async def test_deletion_gives_up_on_a_homeserver_that_never_drains(
    credentials, monkeypatch, caplog
):
    monkeypatch.setattr("shared.matrix.admin_client.MAX_MEDIA_PAGES", 2)
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/media") and request.method == "DELETE":
            calls.append(request)
            return httpx.Response(200, json={"deleted_media": ["mxc://a"], "total": 1})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    deletion = await client.delete_user_media(USER, before_ts_ms=1)

    assert len(calls) == 2
    assert deletion.deleted_count == 2
    assert "Stopped deleting media" in caplog.text


@pytest.mark.parametrize(
    ("status", "complete", "failed", "running"),
    [
        ("complete", True, False, False),
        ("failed", False, True, False),
        ("active", False, False, True),
        ("unknown", False, False, False),
    ],
)
async def test_purge_status_classifies_what_synapse_reported(
    credentials, status, complete, failed, running
):
    """The sweep reports these to an operator; a misread state misreports a purge."""

    def handler(request: httpx.Request) -> httpx.Response:
        if "purge_history_status" in request.url.path:
            return httpx.Response(200, json={"status": status})
        return synapse_handler(request)

    client = SynapseAdminClient(credentials, transport=httpx.MockTransport(handler))

    result = await client.get_purge_status("purge_abc")

    assert (result.is_complete, result.is_failed, result.is_running) == (
        complete,
        failed,
        running,
    )


async def test_a_configured_admin_token_is_used_without_a_login_round_trip(
    tracking_transport,
):
    """Password login on every call would hammer the homeserver during a sweep."""
    transport, requests = tracking_transport
    client = SynapseAdminClient(
        AdminCredentials(
            homeserver="https://matrix.example.com",
            admin_token="tok",  # noqa: S106 - fixture credential for the mock homeserver
        ),
        transport=transport,
    )
    register_synapse_account("@lotti_user:example.com")

    await client.get_user_activity("@lotti_user:example.com")

    assert [r for r in requests if r.url.path.endswith("/login")] == []
    assert requests[0].headers["Authorization"] == "Bearer tok"
    await client.aclose()


@pytest.mark.parametrize(
    "homeserver",
    ["", "http://matrix.example.com", "ftp://matrix.example.com", "matrix.example.com"],
)
def test_admin_credentials_reject_non_https_homeservers(homeserver):
    with pytest.raises(ValueError, match="HTTPS"):
        AdminCredentials(
            homeserver=homeserver,
            admin_token="token",  # noqa: S106 - fixture credential
        )


def test_synapse_client_disables_redirects(credentials):
    client = SynapseAdminClient(credentials)

    assert client._client().follow_redirects is False


def test_admin_credentials_require_an_authentication_method():
    with pytest.raises(ValueError, match="either admin_token"):
        AdminCredentials(homeserver="https://matrix.example.com")
