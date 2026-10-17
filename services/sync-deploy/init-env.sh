#!/usr/bin/env bash
# Write a fresh sync.env with every generated secret filled in as a literal.
#
# Usage: sudo services/sync-deploy/init-env.sh /etc/lotti-sync/sync.env example.com
#
# Docker Compose reads the env file as plain KEY=value lines and never runs
# shell in it, so secrets must be written out, not left as $(openssl …).
# Refuses to overwrite an existing file: regenerating would orphan the
# database password and every escrowed bundle.
set -euo pipefail

target="${1:?usage: init-env.sh <env-file> <server-name>}"
server_name="${2:?usage: init-env.sh <env-file> <server-name>}"

if [[ -e "$target" ]]; then
  echo "$target exists; not overwriting it" >&2
  exit 1
fi

install -d -m 0700 "$(dirname "$target")"
umask 077
cat > "$target" <<EOF
SYNAPSE_SERVER_NAME=${server_name}
MATRIX_PUBLIC_BASEURL=https://matrix.${server_name}
SYNAPSE_DB_PASSWORD=$(openssl rand -hex 24)
SYNAPSE_MACAROON_SECRET=$(openssl rand -hex 32)
SYNAPSE_FORM_SECRET=$(openssl rand -hex 32)
SYNAPSE_REGISTRATION_SECRET=$(openssl rand -hex 32)
API_KEY=$(openssl rand -hex 32)
ADMIN_API_KEY=$(openssl rand -hex 32)
SUBSCRIPTION_ENCRYPTION_KEY_ID=escrow-$(date +%Y-%m)
SUBSCRIPTION_ENCRYPTION_KEY_BASE64=$(openssl rand -base64 32)
ACCOUNT_BINDING_KEY_BASE64=$(openssl rand -base64 32)
WEB_CHECKOUT_PAGE_URL=https://sync.${server_name}/checkout
WEB_CHECKOUT_ORIGIN=https://sync.${server_name}
PADDLE_ENVIRONMENT=sandbox
# Fill in from Paddle (step 5) and Synapse (step 3):
PADDLE_API_KEY=
PADDLE_WEBHOOK_SECRET=
PADDLE_MONTHLY_PRICE_ID=
PADDLE_ANNUAL_PRICE_ID=
MATRIX_ADMIN_TOKEN=
# Step 7, once the app release that verifies signatures is out:
BUNDLE_SIGNING_KEY_BASE64=
BUNDLE_SIGNING_KEY_ID=
EOF
chmod 0600 "$target"
echo "Wrote $target — fill in the Paddle values and MATRIX_ADMIN_TOKEN, and keep an offline copy."
