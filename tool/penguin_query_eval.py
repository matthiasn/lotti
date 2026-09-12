#!/usr/bin/env python3
"""Run the real query pipeline against the unmodified synthetic penguin world.

Only Melious connection keys are read from .env; dotenv content is never
executed as shell code. Existing environment values take precedence. No keys,
request bodies or raw provider errors are printed by this wrapper.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys


def repository_revision(root):
    """Identify committed and dirty inputs without recording file contents."""
    def git(*args):
        return subprocess.check_output(
            ["git", *args], cwd=root, stderr=subprocess.DEVNULL,
        )

    commit, tree = git("rev-parse", "HEAD", "HEAD^{tree}").decode().splitlines()
    diff = git("diff", "--no-ext-diff", "--binary", "HEAD")
    untracked = git("ls-files", "--others", "--exclude-standard", "-z")
    untracked_hashes = {
        name: hashlib.sha256((root / name).read_bytes()).hexdigest()
        for name in sorted(filter(None, untracked.decode().split("\0")))
        if (root / name).is_file()
    }
    return {
        "commit": commit,
        "committedTree": tree,
        "dirty": bool(diff or untracked),
        "trackedDiffSha256": hashlib.sha256(diff).hexdigest(),
        "untrackedFileHashes": untracked_hashes,
    }


def stop_process_tree(process):
    """Stop the owned Flutter process group, including compiler descendants."""
    def send(*, force=False):
        try:
            if os.name == "posix":
                os.killpg(process.pid, signal.SIGKILL if force else signal.SIGTERM)
            elif os.name == "nt":
                subprocess.run(
                    ["taskkill", "/PID", str(process.pid), "/T", *(["/F"] if force else [])],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    check=False,
                )
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
    # Also used by the Dart/MCP entry point, which may bypass this launcher.
    if sys.argv[1:] == ["--print-revision"]:
        print(json.dumps(repository_revision(Path(__file__).resolve().parent.parent)))
        return 0
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True, help="Explicit Melious model ID")
    parser.add_argument("--output", required=True, type=Path, help="JSON artifact outside the repository")
    parser.add_argument("--cases", default="local,follow_up,wider_category,absent,category_boundary")
    parser.add_argument("--home-only", action="store_true")
    parser.add_argument("--stream-synthesis", action="store_true")
    parser.add_argument("--legacy-flow", action="store_true", help="Force the original preview/window path for a matched control")
    parser.add_argument("--variant", required=True, help="Explicit code/comparison variant")
    parser.add_argument("--summary-reports", type=Path, help="Frozen generated report bundle; enables production summary-first retrieval")
    parser.add_argument("--prepare-summary-reports", action="store_true", help="Generate a query-neutral report fixture instead of measuring chat")
    parser.add_argument("--env-file", type=Path, help="Read only Melious connection keys from this local file (default: repository .env)")
    args = parser.parse_args()
    if args.prepare_summary_reports and args.summary_reports:
        parser.error("Prepare reports first, then use the frozen bundle in a separate run")
    if args.summary_reports and args.legacy_flow:
        parser.error("--legacy-flow is an entry control, not a summary-first option")
    root = Path(__file__).resolve().parent.parent
    output = args.output.expanduser().resolve()
    log = output.with_suffix(".log")
    if output.exists() or log.exists():
        parser.error("Output or log already exists; use a distinct filename for every sample")
    if output.is_relative_to(root):
        parser.error("Generated artifacts must be outside the repository")
    env = os.environ.copy()
    dotenv = args.env_file.expanduser().resolve() if args.env_file else root / ".env"
    connection = {}
    if dotenv.exists():
        for line in dotenv.read_text().splitlines():
            key, sep, value = line.partition("=")
            key = key.removeprefix("export ").strip()
            if sep and key in {"MELIOUS_API_KEY", "MELIOUS_BASE_URL", "UP_UPSTREAM_API_KEY", "UP_UPSTREAM_BASE_URL"}:
                tokens = shlex.split(value, comments=True)
                if len(tokens) != 1:
                    parser.error(f"Cannot parse {key} from .env")
                connection[key] = tokens[0]
    for canonical, alias in (("MELIOUS_API_KEY", "UP_UPSTREAM_API_KEY"), ("MELIOUS_BASE_URL", "UP_UPSTREAM_BASE_URL")):
        if canonical not in env:
            value = env.get(alias) or connection.get(canonical) or connection.get(alias)
            if value:
                env[canonical] = value
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
        "QUERY_EVAL_PYTHON": sys.executable,
        "QUERY_EVAL_STREAM_SYNTHESIS": "1" if args.stream_synthesis else "0",
        "QUERY_EVAL_PREPARE_REPORTS": "1" if args.prepare_summary_reports else "0",
        "QUERY_EVAL_SUMMARY_REPORTS": str(args.summary_reports.expanduser().resolve()) if args.summary_reports else "",
    })
    output.parent.mkdir(parents=True, exist_ok=True)
    # Keep compiler/provider output beside the synthetic artifact; credentials
    # are not command arguments and never become part of a checked-in report.
    with log.open("x") as stream:
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
