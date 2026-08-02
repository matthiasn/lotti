#!/usr/bin/env python3
"""Assert the Flathub manifest's Flutter SDK tag matches ``.fvmrc``.

``.fvmrc`` is the single source of truth for the Flutter version: FVM reads it
locally, ``kuhnroyal/flutter-fvm-config-action`` reads it in CI, and Codemagic
reads it for release builds. The Flathub manifest is the one remaining pin that
is not derived from it — ``flatpak/com.matthiasn.lotti.flatpak-flutter.yml``
carries a literal ``tag:`` on the Flutter SDK source, because Flathub builds
from the committed file and reviewers read it.

A hand-maintained duplicate drifts. It already has: 3.41.1 reached the manifest
in its own follow-up commit (c9b4d7ab8) after the version bump missed it, and
3.44.0 sat in the manifest while ``.fvmrc`` said 3.44.7. That one stayed
invisible because pubspec's floor was exactly ``flutter >=3.44.0``, so the
manifest resolved to a version that happened to still satisfy it.

Deriving the tag at build time would have hidden that rather than surfaced it,
so the pin stays literal and this check guards it at PR time instead.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


FLUTTER_SDK_URL = "https://github.com/flutter/flutter.git"

# A YAML sequence item, e.g. "      - type: git". Captures the indentation so a
# block ends at the next item introduced at the same depth or shallower.
LIST_ITEM_RE = re.compile(r"^(\s*)-\s")


def read_fvmrc_version(fvmrc: Path) -> str:
    """Return the Flutter version pinned in ``.fvmrc``.

    Raises ValueError when the file has no usable ``flutter`` entry, so a
    malformed pin fails the check instead of comparing against ``None``.
    """
    config = json.loads(fvmrc.read_text())
    version = config.get("flutter")
    if not isinstance(version, str) or not version.strip():
        raise ValueError(f"{fvmrc} has no usable 'flutter' version: {config!r}")
    return version.strip()


def read_manifest_flutter_tag(manifest: Path) -> str:
    """Return the ``tag:`` of the manifest's Flutter SDK git source.

    Parsed by hand rather than with PyYAML so the check needs no dependency
    beyond the standard library, matching ``check_foreign_deps.py``.

    Raises ValueError unless exactly one Flutter SDK source carrying a tag is
    found. Both extremes matter: zero matches would make the check pass
    vacuously if the manifest were restructured, and more than one would mean
    the answer is ambiguous.
    """
    tags: list[str] = []
    lines = manifest.read_text().splitlines()

    for index, line in enumerate(lines):
        if line.split("#", 1)[0].strip() != f"url: {FLUTTER_SDK_URL}":
            continue

        # Walk the rest of this sequence item looking for its tag. The item
        # started at the most recent "- " line, so anything up to the next one
        # at that depth or shallower still belongs to this source.
        block_indent = _enclosing_item_indent(lines, index)
        for candidate in lines[index + 1 :]:
            item = LIST_ITEM_RE.match(candidate)
            if item is not None and len(item.group(1)) <= block_indent:
                break
            stripped = candidate.split("#", 1)[0].strip()
            if stripped.startswith("tag:"):
                tags.append(stripped[len("tag:") :].strip())
                break

    if len(tags) != 1:
        raise ValueError(
            f"expected exactly one tagged {FLUTTER_SDK_URL} source in "
            f"{manifest}, found {len(tags)}"
        )
    return tags[0]


def _enclosing_item_indent(lines: list[str], index: int) -> int:
    """Indentation of the sequence item that contains ``lines[index]``."""
    for candidate in reversed(lines[: index + 1]):
        item = LIST_ITEM_RE.match(candidate)
        if item is not None:
            return len(item.group(1))
    return 0


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    fvmrc = repo_root / ".fvmrc"
    manifest = repo_root / "flatpak" / "com.matthiasn.lotti.flatpak-flutter.yml"

    try:
        pinned = read_fvmrc_version(fvmrc)
        tagged = read_manifest_flutter_tag(manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Flutter pin check could not run: {error}", file=sys.stderr)
        return 1

    if pinned != tagged:
        print(
            f"Flutter version pins disagree:\n"
            f"  .fvmrc pins {pinned}\n"
            f"  {manifest.relative_to(repo_root)} tags {tagged}\n\n"
            f".fvmrc is the source of truth — set the manifest's Flutter SDK "
            f"tag to {pinned}.",
            file=sys.stderr,
        )
        return 1

    print(f"Flutter pin consistent: {pinned}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
