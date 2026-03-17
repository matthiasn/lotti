#!/usr/bin/env bash
#
# Dashboard Demo Tool
# Usage:
#   ./demo.sh create <user_id> [display_name]     Create account + top up $10
#   ./demo.sh topup  <user_id> [amount]            Top up credits (default $10, max $10)
#   ./demo.sh bill   <user_id> [amount]            Bill/charge credits (default $1.50)
#   ./demo.sh balance <user_id>                    Check balance
#   ./demo.sh chat   <user_id> [message]           Send an AI chat request
#   ./demo.sh status                               Health + system overview
#   ./demo.sh seed                                 Create 3 demo users with activity
#
# Examples:
#   ./demo.sh create alice "Alice Wonder"
#   ./demo.sh create bob                           # display name defaults to "bob"
#   ./demo.sh topup alice 5.00
#   ./demo.sh bill alice 0.75
#   ./demo.sh chat alice "What is the meaning of life?"
#   ./demo.sh seed                                 # quick demo setup

set -euo pipefail

CREDITS_URL="${CREDITS_URL:-http://localhost:8001}"
PROXY_URL="${PROXY_URL:-http://localhost:8002}"
API_KEY="${API_KEY:-dev-key}"
ADMIN_KEY="${ADMIN_KEY:-dev-admin-key}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

log()  { echo -e "${CYAN}>>>${RESET} $*"; }
ok()   { echo -e "${GREEN} OK${RESET} $*"; }
warn() { echo -e "${YELLOW} !!${RESET} $*"; }
fail() { echo -e "${RED}ERR${RESET} $*" >&2; }

api() {
  local method="$1" url="$2" key="${3:-$API_KEY}"
  shift 3 || shift 2
  local body="${1:-}"

  local args=(-s -w "\n%{http_code}" -X "$method" -H "Authorization: Bearer $key" -H "Content-Type: application/json")
  [[ -n "$body" ]] && args+=(-d "$body")

  local response
  response=$(curl "${args[@]}" "$url" 2>&1) || { fail "curl failed"; return 1; }

  local http_code="${response##*$'\n'}"
  local body="${response%$'\n'*}"

  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo "$body"
    return 0
  elif [[ "$http_code" == "409" ]]; then
    warn "Already exists (409)"
    echo "$body"
    return 0
  else
    fail "HTTP $http_code"
    echo "$body"
    return 1
  fi
}

dollars_to_cents() {
  # Convert a dollar amount like "5.00" or "5" to integer cents
  local amount="$1"
  # Remove dollar sign if present
  amount="${amount#\$}"
  # Use awk for float math
  awk "BEGIN { printf \"%d\", $amount * 100 }"
}

cmd_create() {
  local user_id="${1:?Usage: demo.sh create <user_id> [display_name]}"
  local display_name="${2:-$user_id}"

  log "Creating account ${BOLD}$user_id${RESET} (\"$display_name\")"
  api POST "$CREDITS_URL/api/v1/accounts" "$API_KEY" \
    "{\"user_id\": \"$user_id\", \"display_name\": \"$display_name\"}" \
    && ok "Account created"

  log "Topping up \$10.00"
  api POST "$CREDITS_URL/api/v1/topup" "$API_KEY" \
    "{\"user_id\": \"$user_id\", \"amount\": 1000}" \
    && ok "Topped up"

  echo ""
  cmd_balance "$user_id"
}

cmd_topup() {
  local user_id="${1:?Usage: demo.sh topup <user_id> [amount]}"
  local amount="${2:-10.00}"

  # Cap at $10
  local capped
  capped=$(awk "BEGIN { v=$amount; print (v > 10) ? 10 : v }")
  if [[ "$capped" != "$amount" ]]; then
    warn "Capped to \$10.00 (max)"
    amount="$capped"
  fi

  local cents
  cents=$(dollars_to_cents "$amount")

  log "Topping up ${BOLD}$user_id${RESET} with \$$amount ($cents cents)"
  api POST "$CREDITS_URL/api/v1/topup" "$API_KEY" \
    "{\"user_id\": \"$user_id\", \"amount\": $cents}" \
    && ok "Done"
}

cmd_bill() {
  local user_id="${1:?Usage: demo.sh bill <user_id> [amount]}"
  local amount="${2:-1.50}"

  local cents
  cents=$(dollars_to_cents "$amount")

  log "Billing ${BOLD}$user_id${RESET} \$$amount ($cents cents)"
  api POST "$CREDITS_URL/api/v1/bill" "$API_KEY" \
    "{\"user_id\": \"$user_id\", \"amount\": $cents}" \
    && ok "Billed"
}

cmd_balance() {
  local user_id="${1:?Usage: demo.sh balance <user_id>}"

  log "Balance for ${BOLD}$user_id${RESET}"
  local result
  result=$(api POST "$CREDITS_URL/api/v1/balance" "$API_KEY" \
    "{\"user_id\": \"$user_id\"}")

  local balance
  balance=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'\${d[\"balance\"]/100:.2f}')" 2>/dev/null || echo "$result")
  echo -e "  ${BOLD}$balance${RESET}"
}

cmd_chat() {
  local user_id="${1:?Usage: demo.sh chat <user_id> [message]}"
  local message="${2:-Hello, tell me a short joke}"

  log "Sending chat as ${BOLD}$user_id${RESET}: \"$message\""
  local result
  result=$(api POST "$PROXY_URL/v1/chat/completions" "$API_KEY" \
    "{\"model\": \"gpt-4\", \"messages\": [{\"role\": \"user\", \"content\": \"$message\"}], \"user_id\": \"$user_id\"}")

  # Try to extract the reply
  local reply
  reply=$(echo "$result" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['choices'][0]['message']['content'])
" 2>/dev/null || echo "$result")

  echo -e "  ${CYAN}AI:${RESET} $reply"
}

cmd_status() {
  echo -e "${BOLD}Service Health${RESET}"
  echo -n "  Credits Service:  "
  api GET "$CREDITS_URL/api/v1/health" "$API_KEY" > /dev/null 2>&1 && ok "UP" || fail "DOWN"
  echo -n "  AI Proxy:         "
  api GET "$PROXY_URL/health" "$API_KEY" > /dev/null 2>&1 && ok "UP" || fail "DOWN"

  echo ""
  echo -e "${BOLD}Users${RESET}"
  api GET "$CREDITS_URL/api/v1/users" "$ADMIN_KEY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    users = d.get('users', [])
    if not users:
        print('  (none)')
    for u in users:
        bal = f'\${u[\"balance\"]/100:.2f}' if u.get('balance') is not None else '?'
        print(f'  {u[\"user_id\"]:<20} {u.get(\"display_name\",\"-\"):<20} {bal}')
except:
    print('  (could not fetch)')
" 2>/dev/null

  echo ""
  echo -e "${BOLD}System Usage${RESET}"
  api GET "$PROXY_URL/v1/usage/summary" "$ADMIN_KEY" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(f'  Requests:  {d.get(\"total_requests\", 0)}')
    print(f'  Tokens:    {d.get(\"total_tokens\", 0):,}')
    print(f'  Cost:      \${d.get(\"total_cost\", 0):.4f}')
except:
    print('  (no usage data yet)')
" 2>/dev/null
}

cmd_seed() {
  log "Seeding demo data..."
  echo ""

  cmd_create "alice" "Alice Johnson"
  echo ""
  cmd_create "bob" "Bob Smith"
  echo ""
  cmd_create "carol" "Carol Chen"
  echo ""

  log "Generating some activity..."
  cmd_bill "alice" 2.50
  cmd_bill "bob" 1.00
  cmd_bill "alice" 0.75
  cmd_bill "carol" 3.00

  echo ""
  log "Sending AI requests (generates usage charts)..."
  cmd_chat "alice" "What is the capital of France?" || true
  cmd_chat "bob" "Write a haiku about coding" || true
  cmd_chat "carol" "Explain quantum computing in one sentence" || true

  echo ""
  echo -e "${GREEN}${BOLD}Seed complete!${RESET} Open ${CYAN}http://localhost:5173${RESET} to see the dashboard."
  echo ""
  cmd_status
}

show_help() {
  sed -n '3,16p' "$0" | sed 's/^#  \?//'
}

# --- Main ---
command="${1:-help}"
shift || true

case "$command" in
  create)  cmd_create "$@" ;;
  topup)   cmd_topup "$@" ;;
  bill)    cmd_bill "$@" ;;
  balance) cmd_balance "$@" ;;
  chat)    cmd_chat "$@" ;;
  status)  cmd_status ;;
  seed)    cmd_seed ;;
  help|-h|--help) show_help ;;
  *)
    fail "Unknown command: $command"
    show_help
    exit 1
    ;;
esac
