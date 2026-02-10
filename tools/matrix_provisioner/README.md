# Matrix Provisioner

Admin CLI tool that creates a Matrix user account and sync room on a Synapse
homeserver, then outputs a Base64-encoded provisioning bundle for import into
the Lotti desktop client.

## Prerequisites

- Python 3.10+
- A Synapse homeserver with admin API access
- An admin account on the homeserver

## Setup

```bash
cd tools/matrix_provisioner
make setup-env
source .venv/bin/activate
make install-dev
```

## Usage

```bash
# Recommended: password via env var (avoids shell history exposure)
export MATRIX_ADMIN_PASSWORD='<secret>'
python provision.py \
  --homeserver https://matrix.example.com \
  --admin-user admin \
  --username lotti_sync_user42

# Alternative: interactive prompt (no shell history exposure)
python provision.py \
  --homeserver https://matrix.example.com \
  --admin-user admin \
  --username lotti_sync_user42
# → prompts: "Admin password: "

# Least secure: password via CLI flag (visible in shell history/ps)
python provision.py \
  --homeserver https://matrix.example.com \
  --admin-user admin \
  --admin-password <secret> \
  --username lotti_sync_user42
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--homeserver` | Yes | Matrix homeserver URL |
| `--admin-user` | Yes | Admin username |
| `--admin-password` | No | Admin password (default: reads `MATRIX_ADMIN_PASSWORD` env var, or prompts interactively) |
| `--username` | Yes | Localpart for the new user (e.g. `lotti_sync_user42`) |
| `--display-name` | No | Display name (default: "Lotti Sync") |
| `--verbose` | No | Print decoded JSON bundle (contains plaintext password — use only for debugging) |

### Output

The tool prints only the Base64url-encoded string (no padding). Use `--verbose`
to also see the decoded JSON for debugging.

The encoded bundle contains:

```json
{
  "v": 1,
  "homeServer": "https://matrix.example.com",
  "user": "@lotti_sync_user42:example.com",
  "password": "<generated>",
  "roomId": "!abcdef:example.com"
}
```

Paste this string into the Lotti desktop client's "Provisioned Sync" import
field.

## What It Does

1. **Logs in as admin** to obtain an access token
2. **Generates a random password** (44 chars, cryptographically random)
3. **Creates the user** via the Synapse Admin API
4. **Obtains a short-lived user token** (10 min) via admin login-as-user
5. **Creates a private sync room** as the user, with:
   - End-to-end encryption enabled
   - `m.lotti.sync_room` state marker for room discovery
   - Federation disabled
6. **Outputs the provisioning bundle** as Base64

If room creation or user login fails after the user was already created, the
tool automatically deactivates the orphan account and reports the failure.

## Security

- **Admin password input:** Prefer the `MATRIX_ADMIN_PASSWORD` env var or the
  interactive prompt over the `--admin-password` CLI flag, which is visible in
  shell history and process listings.
- **Output:** Only the Base64 bundle is printed by default. The `--verbose` flag
  reveals the decoded JSON (including the plaintext password) — use only for
  debugging.
- The admin password is used only to obtain a token; it is never stored or
  included in the output.
- The generated user password is included in the bundle. This is intentional:
  the Lotti desktop client rotates the password immediately upon import, before
  displaying the QR code for mobile setup.
- The short-lived user token (10 min) is used only for room creation and is not
  included in the output.
- MXIDs are URL-encoded in all API paths to prevent path traversal with
  localparts containing special characters (e.g. `/`).

## Development

```bash
make test          # Run all tests
make test-cov      # Run tests with coverage report
make lint          # Check linting (flake8 + isort + black)
make format        # Auto-format code (isort + black)
make clean         # Remove caches and build artifacts
```
