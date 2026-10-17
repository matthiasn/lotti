"""Tests for the Paddle API boundary."""

# ruff: noqa: S106 - explicit non-production credential fixtures

from __future__ import annotations

import json

import httpx
import pytest
from src.core.exceptions import PaddleUnavailableException
from src.core.paddle import PaddleSubscriptionStatus
from src.services.paddle_client import PADDLE_SANDBOX_BASE_URL, PaddleClient
from tests.paddle_fixtures import subscription_payload

pytestmark = pytest.mark.anyio


def client_for(handler) -> PaddleClient:
    return PaddleClient(
        "pdl_sdbx_apikey_test",
        base_url=PADDLE_SANDBOX_BASE_URL,
        http_client=httpx.AsyncClient(transport=httpx.MockTransport(handler)),
    )


def test_client_requires_an_api_key():
    with pytest.raises(ValueError, match="PADDLE_API_KEY"):
        PaddleClient("")


async def test_get_subscription_authenticates_and_parses():
    requests = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(200, json={"data": subscription_payload(status="past_due")})

    subscription = await client_for(handler).get_subscription("sub/01")

    assert subscription.status is PaddleSubscriptionStatus.PAST_DUE
    assert requests[0].method == "GET"
    assert str(requests[0].url) == f"{PADDLE_SANDBOX_BASE_URL}/subscriptions/sub%2F01"
    assert requests[0].headers["authorization"] == "Bearer pdl_sdbx_apikey_test"


async def test_portal_url_scopes_the_session_to_one_subscription():
    requests = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return httpx.Response(
            201,
            json={
                "data": {
                    "urls": {
                        "general": {"overview": "https://customer-portal.paddle.com/cpl_01"},
                        "subscriptions": [{"id": "sub_01"}],
                    }
                }
            },
        )

    url = await client_for(handler).create_portal_url("ctm_01", "sub_01")

    assert url == "https://customer-portal.paddle.com/cpl_01"
    assert str(requests[0].url).endswith("/customers/ctm_01/portal-sessions")
    assert json.loads(requests[0].content) == {"subscription_ids": ["sub_01"]}


async def test_portal_without_an_overview_link_is_an_outage():
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(201, json={"data": {"urls": {}}})

    with pytest.raises(PaddleUnavailableException, match="no URL"):
        await client_for(handler).create_portal_url("ctm_01", "sub_01")


@pytest.mark.parametrize(
    ("response", "message"),
    [
        (httpx.Response(500, json={}), "HTTP 500"),
        (httpx.Response(200, content=b"not json"), "invalid JSON"),
        (httpx.Response(200, json={"data": []}), "no data object"),
    ],
)
async def test_bad_responses_surface_as_unavailable(response, message):
    with pytest.raises(PaddleUnavailableException, match=message):
        await client_for(lambda request: response).get_subscription("sub_01")


async def test_transport_failures_surface_as_unavailable():
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("down", request=request)

    with pytest.raises(PaddleUnavailableException, match="unreachable"):
        await client_for(handler).get_subscription("sub_01")


async def test_aclose_closes_the_pool():
    http = httpx.AsyncClient(transport=httpx.MockTransport(lambda r: httpx.Response(200)))
    client = PaddleClient("key", http_client=http)

    await client.aclose()

    assert http.is_closed
