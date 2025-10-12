#!/usr/bin/env bash
# Local quality check mirroring CI for manifest_tool
# - Formats code with Black (writes changes)
# - Lints with flake8 (fails on violations)
# - Runs tests (optional via --no-tests)

set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workdir="$here"

python_bin="python3"
run_tests=1
create_venv_if_missing=1

usage() {
  echo "Usage: ${0##*/} [--no-tests] [--no-venv] [--python PYTHON]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-tests)
      run_tests=0; shift ;;
    --no-venv)
      create_venv_if_missing=0; shift ;;
    --python=*)
      python_bin="${1#*=}"; shift ;;
    --python)
      # Accept space-separated form: --python PY
      if [[ $# -ge 2 && "${2:0:1}" != '-' && -n "$2" ]]; then
        python_bin="$2"; shift 2
      else
        echo "Error: --python requires a value (use --python=PY or --python PY)" >&2
        usage
      fi
      ;;
    -h|--help)
      usage ;;
    *)
      echo "Unknown arg: $1" >&2; usage ;;
  esac
done

echo "[quality] Working directory: $workdir"
cd "$workdir"

# Create venv if not active and allowed
if [[ -z "${VIRTUAL_ENV:-}" && $create_venv_if_missing -eq 1 ]]; then
  venv_dir="$workdir/.venv"
  if [[ ! -d "$venv_dir" ]]; then
    echo "[quality] Creating virtualenv at $venv_dir"
    "$python_bin" -m venv "$venv_dir"
  fi
  # shellcheck disable=SC1090
  source "$venv_dir/bin/activate"
fi

echo "[quality] Python: $(python -V 2>&1)"

echo "[quality] Installing tooling (black, flake8, pytest, pyyaml)"
pip install -q --upgrade pip >/dev/null
pip install -q black flake8 flake8-bugbear flake8-comprehensions pytest pyyaml >/dev/null

echo "[quality] Formatting with Black (writes changes)"
black --line-length=120 .

echo "[quality] Linting with flake8 (fails on violations)"
flake8 . \
  --count \
  --max-line-length=120 \
  --extend-ignore=E203,W503 \
  --statistics \
  --show-source \
  --exclude=.git,__pycache__,.pytest_cache,venv,.venv,build,dist,*.egg-info

if [[ $run_tests -eq 1 ]]; then
  echo "[quality] Running tests"
  PYTHONPATH="$here/.." pytest tests/ -v --tb=short --color=yes
else
  echo "[quality] Skipping tests (--no-tests)"
fi

echo "[quality] Done"
