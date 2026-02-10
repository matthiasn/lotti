#!/usr/bin/env python3
"""Matrix account and room provisioning tool for Lotti sync.

Creates a Matrix user account and sync room on a Synapse homeserver,
then outputs a Base64-encoded provisioning bundle that can be imported
by the Lotti desktop client.
"""

import argparse
import asyncio
import base64
import getpass
import json
import os
import secrets
import sys
import time
from urllib.parse import quote

import httpx


def _encode_mxid_for_path(mxid: str) -> str:
    """URL-encode a Matrix user ID for use in a URL path segment.

    MXIDs can contain characters like ``/`` that are significant in URL
    paths, so the entire MXID must be percent-encoded (with ``safe=""``)
    before interpolation into a path.
    """
    return quote(mxid, safe="")


async def _deactivate_user(
    client: httpx.AsyncClient,
    admin_headers: dict,
    user_mxid: str,
) -> None:
    """Best-effort deactivation of an orphan user after a partial failure."""
    encoded = _encode_mxid_for_path(user_mxid)
    try:
        resp = await client.put(
            f"/_synapse/admin/v2/users/{encoded}",
            headers=admin_headers,
            json={"deactivated": True},
        )
        if resp.is_success:
            print(f"Rolled back: deactivated orphan user {user_mxid}", file=sys.stderr)
        else:
            print(
                f"Warning: failed to deactivate orphan user {user_mxid} "
                f"(HTTP {resp.status_code})",
                file=sys.stderr,
            )
    except httpx.RequestError as exc:
        print(
            f"Warning: could not deactivate orphan user {user_mxid}: {exc}",
            file=sys.stderr,
        )


async def provision(
    args: argparse.Namespace,
    *,
    transport: httpx.AsyncBaseTransport | None = None,
) -> str:
    """Run the full provisioning flow.

    Args:
        args: CLI arguments (homeserver, admin_user, admin_password, username,
              display_name, verbose).
        transport: Optional HTTP transport for testing. When ``None``, httpx
                   uses its default transport.

    Returns:
        The Base64url-encoded provisioning bundle (no padding).
    """
    homeserver = args.homeserver.rstrip("/")
    verbose = getattr(args, "verbose", False)

    client_kwargs: dict = {"base_url": homeserver, "timeout": 30}
    if transport is not None:
        client_kwargs["transport"] = transport

    async with httpx.AsyncClient(**client_kwargs) as client:
        # Step 1: Login as admin
        print(f"Logging in as admin '{args.admin_user}'...")
        resp = await client.post(
            "/_matrix/client/v3/login",
            json={
                "type": "m.login.password",
                "user": args.admin_user,
                "password": args.admin_password,
            },
        )
        resp.raise_for_status()
        login_data = resp.json()
        admin_token = login_data["access_token"]
        admin_mxid = login_data["user_id"]

        # Extract server name from admin MXID (@admin:server_name)
        server_name = admin_mxid.split(":", 1)[1]
        print(f"Server name: {server_name}")

        admin_headers = {"Authorization": f"Bearer {admin_token}"}

        # Step 2: Generate random password (44 chars, cryptographically random)
        password = secrets.token_urlsafe(32)

        # Step 3: Create user
        user_mxid = f"@{args.username}:{server_name}"
        encoded_mxid = _encode_mxid_for_path(user_mxid)
        display_name = args.display_name

        print(f"Creating user {user_mxid}...")
        resp = await client.put(
            f"/_synapse/admin/v2/users/{encoded_mxid}",
            headers=admin_headers,
            json={
                "password": password,
                "admin": False,
                "displayname": display_name,
            },
        )
        resp.raise_for_status()
        print(f"User created: {user_mxid}")

        # From here on, if anything fails we try to deactivate the orphan user.
        try:
            # Step 4: Login as user via admin endpoint (short-lived token)
            valid_until_ms = int(time.time() * 1000) + 10 * 60 * 1000  # 10 min

            print("Obtaining user token...")
            resp = await client.post(
                f"/_synapse/admin/v1/users/{encoded_mxid}/login",
                headers=admin_headers,
                json={"valid_until_ms": valid_until_ms},
            )
            resp.raise_for_status()
            user_token = resp.json()["access_token"]

            user_headers = {"Authorization": f"Bearer {user_token}"}

            # Step 5: Create room as user
            print("Creating sync room...")
            resp = await client.post(
                "/_matrix/client/v3/createRoom",
                headers=user_headers,
                json={
                    "visibility": "private",
                    "name": "Lotti Sync",
                    "preset": "trusted_private_chat",
                    "creation_content": {"m.federate": False},
                    "initial_state": [
                        {
                            "type": "m.room.encryption",
                            "state_key": "",
                            "content": {
                                "algorithm": "m.megolm.v1.aes-sha2",
                            },
                        },
                        {
                            "type": "m.lotti.sync_room",
                            "state_key": "",
                            "content": {"version": 1},
                        },
                    ],
                },
            )
            resp.raise_for_status()
            room_id = resp.json()["room_id"]
            print(f"Room created: {room_id}")
        except Exception:
            await _deactivate_user(client, admin_headers, user_mxid)
            raise

        # Step 6: Build provisioning bundle
        bundle = {
            "v": 1,
            "homeServer": homeserver,
            "user": user_mxid,
            "password": password,
            "roomId": room_id,
        }

        bundle_json = json.dumps(bundle, separators=(",", ":"))
        bundle_b64 = base64.urlsafe_b64encode(bundle_json.encode()).rstrip(b"=").decode()

        print("\n--- Provisioning Bundle (Base64) ---")
        print(bundle_b64)

        if verbose:
            print("\n--- Decoded (for verification) ---")
            print(json.dumps(bundle, indent=2))

        return bundle_b64


def _resolve_admin_password(args: argparse.Namespace) -> str:
    """Resolve the admin password from flag, env var, or interactive prompt."""
    if args.admin_password:
        return args.admin_password

    env_pw = os.environ.get("MATRIX_ADMIN_PASSWORD")
    if env_pw:
        return env_pw

    return getpass.getpass("Admin password: ")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Provision a Matrix account and sync room for Lotti.",
    )
    parser.add_argument(
        "--homeserver",
        required=True,
        help="Matrix homeserver URL (e.g. https://matrix.example.com)",
    )
    parser.add_argument(
        "--admin-user",
        required=True,
        help="Admin username for the homeserver",
    )
    parser.add_argument(
        "--admin-password",
        default="",
        help=(
            "Admin password (default: reads MATRIX_ADMIN_PASSWORD env var, "
            "or prompts interactively)"
        ),
    )
    parser.add_argument(
        "--username",
        required=True,
        help="Username for the new Lotti sync user (localpart only)",
    )
    parser.add_argument(
        "--display-name",
        default="Lotti Sync",
        help='Display name for the new user (default: "Lotti Sync")',
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        default=False,
        help="Print decoded bundle JSON (contains plaintext password)",
    )

    args = parser.parse_args()

    try:
        args.admin_password = _resolve_admin_password(args)
    except (EOFError, KeyboardInterrupt):
        print("\nAborted: no password provided.", file=sys.stderr)
        sys.exit(1)

    try:
        asyncio.run(provision(args))
    except httpx.HTTPStatusError as exc:
        print(
            f"\nHTTP error: {exc.response.status_code} {exc.response.text}",
            file=sys.stderr,
        )
        sys.exit(1)
    except httpx.RequestError as exc:
        print(f"\nRequest error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
