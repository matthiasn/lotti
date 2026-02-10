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
python provision.py \
  --homeserver https://matrix.example.com \
  --admin-user admin \
  --admin-password <secret> \
  --username lotti_sync_user42 \
  --display-name "Lotti Sync"
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--homeserver` | Yes | Matrix homeserver URL |
| `--admin-user` | Yes | Admin username |
| `--admin-password` | Yes | Admin password |
| `--username` | Yes | Localpart for the new user (e.g. `lotti_sync_user42`) |
| `--display-name` | No | Display name (default: "Lotti Sync") |

### Output

The tool prints a Base64url-encoded string (no padding) containing:

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

## Security

- The admin password is used only to obtain a token; it is never stored or
  included in the output.
- The generated user password is included in the bundle. This is intentional:
  the Lotti desktop client rotates the password immediately upon import, before
  displaying the QR code for mobile setup.
- The short-lived user token (10 min) is used only for room creation and is not
  included in the output.

## Development

```bash
make test          # Run all tests
make test-cov      # Run tests with coverage report
make lint          # Check linting (flake8 + isort + black)
make format        # Auto-format code (isort + black)
make clean         # Remove caches and build artifacts
```
