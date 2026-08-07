"""Tests for the shared Synapse admin client.

The figures this client reports drive an irreversible decision — how much a
purge reclaimed, and therefore whether retention is working at all — so the
tests here are mostly about *completeness*: Synapse paginates the per-user media
endpoints at 100 rows, and a client that reads one page reports a number that
looks plausible and is wrong.
"""

from __future__ import annotations

import httpx
import pytest

from shared.matrix import SynapseAdminClient
from shared.matrix.admin_client import MEDIA_PAGE_SIZE
from tests.conftest import register_synapse_account, synapse_handler

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
    from shared.matrix import AdminCredentials

    transport, requests = tracking_transport
    client = SynapseAdminClient(
        AdminCredentials(homeserver="https://matrix.example.com", admin_token="tok"),
        transport=transport,
    )
    register_synapse_account("@lotti_user:example.com")

    await client.get_user_activity("@lotti_user:example.com")

    assert [r for r in requests if r.url.path.endswith("/login")] == []
    assert requests[0].headers["Authorization"] == "Bearer tok"
    await client.aclose()
