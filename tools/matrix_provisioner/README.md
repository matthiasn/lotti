# Matrix Provisioner

Admin CLI tool that creates a Matrix user account and sync room on a Synapse
homeserver, then outputs a Base64url-encoded (no padding) provisioning bundle
for import into the Lotti desktop client.

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
  --username lotti_sync_user42 \
  --output-file bundle.txt

# Alternative: interactive prompt (no shell history exposure)
python provision.py \
  --homeserver https://matrix.example.com \
  --admin-user admin \
  --username lotti_sync_user42 \
  --output-file bundle.txt
# → prompts: "Admin password: "

# Least secure: password via CLI flag (visible in shell history/ps)
python provision.py \
  --homeserver https://matrix.example.com \
  --admin-user admin \
  --admin-password <secret> \
  --username lotti_sync_user42 \
  --output-file bundle.txt
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--homeserver` | Yes | Matrix homeserver URL |
| `--admin-user` | Yes | Admin username |
| `--admin-password` | No | Admin password (default: reads `MATRIX_ADMIN_PASSWORD` env var, or prompts interactively) |
| `--username` | Yes | Localpart for the new user (e.g. `lotti_sync_user42`) |
| `--output-file` | Yes | File path to write the provisioning bundle to |
| `--display-name` | No | Display name (default: `Lotti Sync (<username>)`) |
| `--verbose` | No | Print decoded JSON (password redacted) to stderr for debugging |

### Output

The provisioning bundle is written to the file specified by `--output-file`.
Nothing sensitive is printed to stdout or stderr. Progress messages go to stderr.
Use `--verbose` to also see a decoded JSON summary (with password redacted) on
stderr for debugging.

The bundle file contains a Base64url-encoded string (no padding) that decodes to:

```json
{
  "v": 1,
  "homeServer": "https://matrix.example.com",
  "user": "@lotti_sync_user42:example.com",
  "password": "<generated>",
  "roomId": "!abcdef:example.com"
}
```

Paste the contents of the output file into the Lotti desktop client's
"Provisioned Sync" import field.

## What It Does

1. **Logs in as admin** to obtain an access token
2. **Generates a random password** (43 chars, cryptographically random)
3. **Creates the user** via the Synapse Admin API
4. **Obtains a short-lived user token** (10 min) via admin login-as-user
5. **Creates a private sync room** as the user, with:
   - End-to-end encryption enabled
   - `m.lotti.sync_room` state marker for room discovery
   - Federation disabled
6. **Writes the provisioning bundle** to the specified output file

If room creation or user login fails after the user was already created, the
tool automatically deactivates the orphan account and reports the failure.

## Security

- **Admin password input:** Prefer the `MATRIX_ADMIN_PASSWORD` env var or the
  interactive prompt over the `--admin-password` CLI flag, which is visible in
  shell history and process listings.
- **Output:** The bundle is written to a file (never to stdout/stderr). The
  `--verbose` flag prints a decoded JSON summary to stderr with the password
  redacted — use only for debugging.
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
