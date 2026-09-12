#!/usr/bin/env python3
"""Run the real query pipeline against the unmodified synthetic penguin world.

Only Melious connection keys are read from .env; dotenv content is never
executed as shell code. Existing environment values take precedence. No keys,
request bodies or raw provider errors are printed by this wrapper.
"""

import argparse
import os
from pathlib import Path
import shlex
import signal
import subprocess


def stop_process_tree(process):
    """Stop the owned Flutter process group, including compiler descendants."""
    def send(*, force=False):
        try:
            if os.name == "posix":
                os.killpg(process.pid, signal.SIGKILL if force else signal.SIGTERM)
            elif force:
                process.kill()
            else:
                process.terminate()
        except ProcessLookupError:
            pass

    send()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        send(force=True)
        process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True, help="Explicit Melious model ID")
    parser.add_argument("--output", required=True, type=Path, help="JSON artifact outside the repository")
    parser.add_argument("--cases", default="local,follow_up,wider_category,absent,category_boundary")
    parser.add_argument("--home-only", action="store_true")
    parser.add_argument("--legacy-flow", action="store_true", help="Force the original preview/window path for a matched control")
    parser.add_argument("--variant", required=True, help="Explicit code/comparison variant")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = args.output.expanduser().resolve()
    if output.exists():
        parser.error("Output already exists; use a distinct filename for every sample")
    if output.is_relative_to(root):
        parser.error("Generated artifacts must be outside the repository")
    env = os.environ.copy()
    dotenv = root / ".env"
    if dotenv.exists():
        for line in dotenv.read_text().splitlines():
            key, sep, value = line.partition("=")
            key = key.removeprefix("export ").strip()
            if sep and key in {"MELIOUS_API_KEY", "MELIOUS_BASE_URL"} and key not in env:
                tokens = shlex.split(value, comments=True)
                if len(tokens) != 1:
                    parser.error(f"Cannot parse {key} from .env")
                env[key] = tokens[0]
    if not (env.get("QUERY_EVAL_API_KEY") or env.get("MELIOUS_API_KEY")):
        parser.error("Set QUERY_EVAL_API_KEY or MELIOUS_API_KEY")
    if not (env.get("QUERY_EVAL_BASE_URL") or env.get("MELIOUS_BASE_URL")):
        parser.error("Set QUERY_EVAL_BASE_URL or MELIOUS_BASE_URL")
    env.update({
        "LOTTI_QUERY_EVAL_LIVE": "1",
        "QUERY_EVAL_MODEL": args.model,
        "QUERY_EVAL_OUTPUT": str(output),
        "QUERY_EVAL_CASES": args.cases,
        "QUERY_EVAL_HOME_ONLY": "1" if args.home_only else "0",
        "QUERY_EVAL_VARIANT": args.variant,
        "QUERY_EVAL_LEGACY_FLOW": "1" if args.legacy_flow else "0",
    })
    output.parent.mkdir(parents=True, exist_ok=True)
    # Keep compiler/provider output beside the synthetic artifact; credentials
    # are not command arguments and never become part of a checked-in report.
    log = output.with_suffix(".log")
    with log.open("w") as stream:
        process = subprocess.Popen(
            ["fvm", "flutter", "test", "test/features/ai/eval/penguin_query_eval_live_test.dart"],
            cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT,
            start_new_session=os.name == "posix",
        )
        try:
            returncode = process.wait(timeout=900)
        except subprocess.TimeoutExpired:
            stop_process_tree(process)
            print(f"Eval exceeded 15 minutes; partial artifact: {output}")
            return 124
        except KeyboardInterrupt:
            stop_process_tree(process)
            raise
    print(f"Eval exit {returncode}; artifact: {output}; log: {log}")
    return returncode


if __name__ == "__main__":
    raise SystemExit(main())
