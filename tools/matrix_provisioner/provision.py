#!/usr/bin/env python3
"""Matrix account and room provisioning tool for Lotti sync.

Creates a Matrix user account and sync room on a Synapse homeserver, then
outputs a Base64url-encoded provisioning bundle that can be imported by the
Lotti desktop client.

The provisioning flow itself lives in ``services/shared/matrix`` so that this
CLI and the matrix-provisioning-service web API cannot drift apart. This module
is the command-line front end: argument parsing, credential resolution, stderr
progress and file output.
"""

import argparse
import asyncio
import getpass
import json
import os
import sys
from pathlib import Path

import httpx

# The shared provisioning core lives under services/. Add it to the path so the
# CLI can run standalone from its own virtualenv without a packaging step.
_SERVICES_DIR = Path(__file__).resolve().parents[2] / "services"
if str(_SERVICES_DIR) not in sys.path:
    sys.path.insert(0, str(_SERVICES_DIR))

# These follow the sys.path bootstrap above, hence the E402 suppressions.
from shared.matrix import (  # noqa: E402
    AdminCredentials,
    ProvisioningError,
    SynapseProvisioner,
    UserAlreadyExistsError,
    encode_mxid_for_path,
    encode_room_id_for_path,
)

# Kept under their original private names for backwards compatibility.
_encode_mxid_for_path = encode_mxid_for_path
_encode_room_id_for_path = encode_room_id_for_path

__all__ = [
    "AdminCredentials",
    "ProvisioningError",
    "SynapseProvisioner",
    "UserAlreadyExistsError",
    "_encode_mxid_for_path",
    "_encode_room_id_for_path",
    "main",
    "provision",
]


async def provision(
    args: argparse.Namespace,
    *,
    transport: httpx.AsyncBaseTransport | None = None,
) -> str:
    """Run the full provisioning flow.

    Args:
        args: CLI arguments (homeserver, admin_user, admin_password, username,
              display_name, output_file, verbose).
        transport: Optional HTTP transport for testing. When ``None``, httpx
                   uses its default transport.

    Returns:
        The Base64url-encoded provisioning bundle (no padding).

    Raises:
        httpx.HTTPStatusError: If any Synapse call returns an error status.
        UserAlreadyExistsError: If the localpart already has an account on the
            homeserver. Provisioning over it would reset that account's
            password, so the flow refuses rather than upserting.
        ValueError: If Synapse returns a malformed response.
        OSError: If the bundle cannot be written to ``--output-file``.
    """
    verbose = getattr(args, "verbose", False)

    def log(msg: str) -> None:
        print(msg, file=sys.stderr)

    credentials = AdminCredentials(
        homeserver=args.homeserver,
        admin_user=args.admin_user,
        admin_password=args.admin_password,
    )
    provisioner = SynapseProvisioner(credentials, transport=transport, log=log)

    result = await provisioner.provision(
        username=args.username,
        display_name=args.display_name or None,
    )
    bundle_b64 = result.encoded_bundle

    # Write the bundle to a file instead of stdout to avoid leaking credentials
    # into terminal scrollback, CI logs, or shell history. The bundle
    # intentionally contains the generated password — the Lotti desktop client
    # rotates it immediately upon import.
    output_file = getattr(args, "output_file", None)
    if output_file:
        try:
            with open(output_file, "w", encoding="utf-8") as fh:
                # codeql[py/clear-text-storage-sensitive-data]
                fh.write(bundle_b64)
        except OSError as exc:
            raise OSError(f"Failed to write bundle to {output_file}: {exc}") from exc
        log(f"Bundle written to {output_file}")

    if verbose:
        log("\n--- Decoded (for verification) ---")
        log(json.dumps(result.bundle.redacted_dict(), indent=2))

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
        default="",
        help='Display name for the new user (default: "Lotti Sync (<username>)")',
    )
    parser.add_argument(
        "--output-file",
        required=True,
        help="File path to write the provisioning bundle to",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        default=False,
        help="Print decoded bundle JSON (with password redacted) to stderr",
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
    except OSError as exc:
        print(f"\nFile error: {exc}", file=sys.stderr)
        sys.exit(1)
    except UserAlreadyExistsError as exc:
        # Ahead of the ValueError branch it inherits from, so this reads as the
        # deliberate refusal it is rather than a malformed-response error.
        print(f"\nRefusing to provision: {exc}", file=sys.stderr)
        sys.exit(1)
    except ValueError as exc:
        print(f"\nValidation error: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
