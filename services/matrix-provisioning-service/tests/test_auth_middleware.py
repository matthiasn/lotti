"""Tests for the shared API-key auth middleware.

Lives here because this service is the one that runs it in admin-by-default
mode, where the prefix list decides what is *not* privileged — so a matching bug
downgrades an endpoint rather than merely rejecting a request.
"""

from __future__ import annotations

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from shared.auth import APIKeyAuthMiddleware

CLIENT_AUTH = {"Authorization": "Bearer test-key"}
ADMIN_AUTH = {"Authorization": "Bearer test-admin-key"}


def _app(**middleware_kwargs) -> FastAPI:
    """An app exposing a handful of paths behind the middleware under test."""
    app = FastAPI()

    for path in (
        "/api/v1/client",
        "/api/v1/client/bundles/x/rotated",
        "/api/v1/client-admin",
        "/api/v1/clientele",
        "/api/v1/bundles",
        "/api/v1/anything-else",
    ):
        app.add_api_route(path, lambda: {"ok": True}, methods=["GET"])

    app.add_middleware(APIKeyAuthMiddleware, **middleware_kwargs)
    return app


@pytest.fixture
def client_default_deny() -> TestClient:
    return TestClient(_app(client_path_prefixes=["/api/v1/client"]))


@pytest.mark.parametrize(
    "path",
    ["/api/v1/client", "/api/v1/client/bundles/x/rotated"],
)
def test_the_client_namespace_accepts_a_regular_key(client_default_deny, path):
    assert client_default_deny.get(path, headers=CLIENT_AUTH).status_code == 200


@pytest.mark.parametrize(
    "path",
    [
        # The bug this guards: `startswith` alone treats both of these as
        # sitting under /api/v1/client, so an admin route whose name merely
        # begins with a client prefix would take a plain key.
        "/api/v1/client-admin",
        "/api/v1/clientele",
        "/api/v1/bundles",
        "/api/v1/anything-else",
    ],
)
def test_a_neighbouring_path_is_not_inside_the_client_namespace(client_default_deny, path):
    assert client_default_deny.get(path, headers=CLIENT_AUTH).status_code == 403
    assert client_default_deny.get(path, headers=ADMIN_AUTH).status_code == 200


def test_a_trailing_slash_on_the_prefix_does_not_change_the_boundary():
    """Config should not silently change meaning over a cosmetic slash."""
    client = TestClient(_app(client_path_prefixes=["/api/v1/client/"]))

    assert client.get("/api/v1/client", headers=CLIENT_AUTH).status_code == 200
    assert client.get("/api/v1/client-admin", headers=CLIENT_AUTH).status_code == 403


def test_admin_prefix_mode_also_respects_the_segment_boundary():
    """The other two services use this mode; the same collision applies."""
    client = TestClient(_app(admin_path_prefixes=["/api/v1/client"]))

    # Under the admin list, /api/v1/client is privileged...
    assert client.get("/api/v1/client", headers=CLIENT_AUTH).status_code == 403
    assert client.get("/api/v1/client", headers=ADMIN_AUTH).status_code == 200
    # ...while a merely similar name is an ordinary client path.
    assert client.get("/api/v1/client-admin", headers=CLIENT_AUTH).status_code == 200


def test_exempt_paths_need_no_credentials(client_default_deny):
    assert client_default_deny.get("/health").status_code in (200, 404)


def test_a_missing_header_is_challenged(client_default_deny):
    response = client_default_deny.get("/api/v1/bundles")

    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"


def test_a_malformed_header_is_rejected(client_default_deny):
    response = client_default_deny.get(
        "/api/v1/bundles", headers={"Authorization": "test-admin-key"}
    )

    assert response.status_code == 401


def test_an_admin_key_is_not_accepted_on_a_client_path(client_default_deny):
    """Admin keys are deliberately not a superset; a leak stays contained."""
    response = client_default_deny.get("/api/v1/client", headers=ADMIN_AUTH)

    assert response.status_code == 403
