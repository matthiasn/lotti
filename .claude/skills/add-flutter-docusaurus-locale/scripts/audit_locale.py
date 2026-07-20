#!/usr/bin/env python3
"""Audit one Flutter ARB and Docusaurus locale against canonical sources."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

FORMATTED_ARGUMENT = re.compile(
    r"\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*"
    r"(?:plural|select|selectordinal|number|date|time)\b"
)
SIMPLE_PLACEHOLDER = re.compile(r"\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}")


def message_keys(catalog: dict[str, object]) -> set[str]:
    return {key for key in catalog if not key.startswith("@")}


def placeholders(
    catalog: dict[str, object], key: str, expected: set[str] | None = None
) -> set[str]:
    metadata = catalog.get(f"@{key}")
    if isinstance(metadata, dict) and isinstance(metadata.get("placeholders"), dict):
        return set(metadata["placeholders"])

    value = catalog.get(key)
    if not isinstance(value, str):
        return set()

    found = set(FORMATTED_ARGUMENT.findall(value))
    if not found:
        # Without ICU formatted arguments every {word} is a placeholder.
        # Inside ICU messages, branch bodies such as one{eins} defeat that
        # scan, so there we only search for the expected names below.
        return set(SIMPLE_PLACEHOLDER.findall(value))
    for name in expected or ():
        if re.search(rf"\{{\s*{re.escape(name)}\s*(?:\}}|,)", value):
            found.add(name)
    return found


def pages(root: Path) -> set[Path]:
    return {
        path.relative_to(root)
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in {".md", ".mdx"}
    }


def body(path: Path) -> str:
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n").strip()
    if text.startswith("---\n"):
        _, separator, remainder = text[4:].partition("\n---\n")
        if separator:
            return remainder.strip()
    return text


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template-arb", type=Path, required=True)
    parser.add_argument("--target-arb", type=Path, required=True)
    parser.add_argument("--source-docs", type=Path, required=True)
    parser.add_argument("--target-docs", type=Path, required=True)
    parser.add_argument("--fail-identical", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    template = json.loads(args.template_arb.read_text(encoding="utf-8"))
    target = json.loads(args.target_arb.read_text(encoding="utf-8"))
    template_keys = message_keys(template)
    target_keys = message_keys(target)
    missing_keys = sorted(template_keys - target_keys)
    extra_keys = sorted(target_keys - template_keys)
    placeholder_drift = []
    for key in sorted(template_keys & target_keys):
        expected = placeholders(template, key)
        if expected != placeholders(target, key, expected):
            placeholder_drift.append(key)

    source_pages = pages(args.source_docs)
    target_pages = pages(args.target_docs)
    missing_pages = sorted(source_pages - target_pages)
    extra_pages = sorted(target_pages - source_pages)
    identical_pages = sorted(
        relative
        for relative in source_pages & target_pages
        if body(args.source_docs / relative) == body(args.target_docs / relative)
    )

    groups = (
        ("missing ARB key", missing_keys),
        ("extra ARB key", extra_keys),
        ("placeholder drift", placeholder_drift),
        ("missing manual page", missing_pages),
        ("extra manual page", extra_pages),
    )
    for label, values in groups:
        for value in values:
            rendered = value.as_posix() if isinstance(value, Path) else value
            print(f"{label}: {rendered}")
    for relative in identical_pages:
        print(f"review identical manual body: {relative.as_posix()}")

    print(
        f"ARB {len(target_keys)}/{len(template_keys)} keys; "
        f"manual {len(target_pages)}/{len(source_pages)} pages; "
        f"{len(placeholder_drift)} placeholder mismatches; "
        f"{len(identical_pages)} identical manual bodies"
    )

    failed = any(values for _, values in groups)
    if args.fail_identical and identical_pages:
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
