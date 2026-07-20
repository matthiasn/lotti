#!/usr/bin/env python3
"""Audit page parity across standard Docusaurus documentation locale trees."""

from __future__ import annotations

import argparse
from pathlib import Path


def page_paths(root: Path) -> set[Path]:
    return {
        path.relative_to(root)
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in {".md", ".mdx"}
    }


def normalized_body(path: Path) -> str:
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n").strip()
    if text.startswith("---\n"):
        _, separator, body = text[4:].partition("\n---\n")
        if separator:
            return body.strip()
    return text


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--site-root", type=Path, required=True)
    parser.add_argument("--docs-dir", default="docs")
    parser.add_argument("--i18n-dir", default="i18n")
    parser.add_argument(
        "--plugin-path", default="docusaurus-plugin-content-docs/current"
    )
    parser.add_argument("--locales", help="Comma-separated locale allowlist")
    parser.add_argument("--fail-identical", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    site_root = args.site_root.resolve()
    source_root = site_root / args.docs_dir
    i18n_root = site_root / args.i18n_dir
    if not source_root.is_dir() or not i18n_root.is_dir():
        raise SystemExit("Expected source docs and i18n directories were not found.")

    source_pages = page_paths(source_root)
    requested = set(args.locales.split(",")) if args.locales else None
    locale_dirs = sorted(path for path in i18n_root.iterdir() if path.is_dir())
    failures = 0

    for locale_dir in locale_dirs:
        locale = locale_dir.name
        if requested is not None and locale not in requested:
            continue
        translated_root = locale_dir / args.plugin_path
        if not translated_root.is_dir():
            print(f"{locale}: missing docs tree {translated_root}")
            failures += 1
            continue

        translated_pages = page_paths(translated_root)
        missing = sorted(source_pages - translated_pages)
        extra = sorted(translated_pages - source_pages)
        identical = sorted(
            relative
            for relative in source_pages & translated_pages
            if normalized_body(source_root / relative)
            == normalized_body(translated_root / relative)
        )

        print(
            f"{locale}: {len(translated_pages)} pages, "
            f"{len(missing)} missing, {len(extra)} extra, "
            f"{len(identical)} identical bodies"
        )
        for label, paths in (("missing", missing), ("extra", extra)):
            for path in paths:
                print(f"  {label}: {path.as_posix()}")
        for path in identical:
            print(f"  review identical: {path.as_posix()}")

        failures += bool(missing or extra)
        if args.fail_identical:
            failures += bool(identical)

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
