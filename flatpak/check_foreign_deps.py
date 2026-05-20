#!/usr/bin/env python3
"""Validate Flatpak foreign dependency patches against the locked Pub cache."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PACKAGE_PATH_RE = re.compile(
    r"\.pub-cache/hosted/pub\.dev/([A-Za-z0-9_]+)-([^/]+)"
)


@dataclass(frozen=True)
class LockedPackage:
    source: str | None
    version: str


@dataclass(frozen=True)
class PatchCheck:
    name: str
    patch_file: Path
    destination: Path
    strip_components: int
    options: list[str]


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    flatpak_dir = repo_root / "flatpak"
    pub_cache = Path(os.environ.get("PUB_CACHE", "~/.pub-cache")).expanduser()
    locked_packages = _read_pubspec_lock(repo_root / "pubspec.lock")

    failures: list[str] = []
    checks: list[PatchCheck] = []

    overlay_path = flatpak_dir / "flatpak_flutter_extra" / "foreign_deps.json"
    if overlay_path.exists():
        checks.extend(
            _checks_from_versioned_foreign_deps(
                overlay_path=overlay_path,
                patch_root=flatpak_dir / "flatpak_flutter_extra",
                pub_cache=pub_cache,
                locked_packages=locked_packages,
                failures=failures,
            )
        )

    foreign_path = flatpak_dir / "foreign.json"
    if foreign_path.exists():
        checks.extend(
            _checks_from_foreign_json(
                foreign_path=foreign_path,
                patch_root=flatpak_dir,
                pub_cache=pub_cache,
                locked_packages=locked_packages,
                failures=failures,
            )
        )

    for check in checks:
        failures.extend(_run_patch_check(check))

    if failures:
        print("Flatpak foreign dependency validation failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print(f"Validated {len(checks)} Flatpak foreign dependency patch(es).")
    return 0


def _read_pubspec_lock(path: Path) -> dict[str, LockedPackage]:
    packages: dict[str, dict[str, str | None]] = {}
    current: str | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        package_match = re.match(r"^  ([A-Za-z0-9_]+):$", raw_line)
        if package_match:
            current = package_match.group(1)
            packages[current] = {"source": None, "version": None}
            continue

        if current is None:
            continue

        source_match = re.match(r"^    source:\s+(.+)$", raw_line)
        if source_match:
            packages[current]["source"] = _unquote(source_match.group(1))
            continue

        version_match = re.match(r"^    version:\s+(.+)$", raw_line)
        if version_match:
            packages[current]["version"] = _unquote(version_match.group(1))

    return {
        name: LockedPackage(
            source=values["source"],
            version=str(values["version"]),
        )
        for name, values in packages.items()
        if values["version"] is not None
    }


def _checks_from_versioned_foreign_deps(
    *,
    overlay_path: Path,
    patch_root: Path,
    pub_cache: Path,
    locked_packages: dict[str, LockedPackage],
    failures: list[str],
) -> list[PatchCheck]:
    data = _read_json_object(overlay_path)
    checks: list[PatchCheck] = []

    for dep_name, versions in data.items():
        if dep_name.startswith("_"):
            continue
        if not isinstance(versions, dict):
            failures.append(f"{overlay_path}: {dep_name} must map versions to entries")
            continue

        locked = locked_packages.get(dep_name)
        if locked is None:
            continue

        if locked.source != "hosted":
            failures.append(
                f"{dep_name} is locked from source {locked.source!r}; "
                "Flatpak foreign_deps overlays only support hosted Pub packages"
            )
            continue

        if locked.version not in versions:
            latest = _latest_compatible_version(versions.keys(), locked.version)
            if latest is None:
                hint = "no compatible overlay entry exists"
            else:
                hint = f"flatpak-flutter would reuse {latest}"
            failures.append(
                f"{dep_name} is locked at {locked.version}, but "
                f"{overlay_path} has no exact entry for that version ({hint})"
            )
            continue

        entry = versions[locked.version]
        pub_dev = pub_cache / "hosted" / "pub.dev" / f"{dep_name}-{locked.version}"
        checks.extend(
            _checks_from_entry(
                name=f"{dep_name} {locked.version}",
                entry=entry,
                patch_root=patch_root,
                pub_dev=pub_dev,
                pub_cache=pub_cache,
                locked_packages=locked_packages,
                failures=failures,
            )
        )

    return checks


def _checks_from_foreign_json(
    *,
    foreign_path: Path,
    patch_root: Path,
    pub_cache: Path,
    locked_packages: dict[str, LockedPackage],
    failures: list[str],
) -> list[PatchCheck]:
    data = _read_json_object(foreign_path)
    checks: list[PatchCheck] = []

    for name, entry in data.items():
        _validate_embedded_pub_versions(
            name=name,
            value=entry,
            locked_packages=locked_packages,
            failures=failures,
        )
        checks.extend(
            _checks_from_entry(
                name=name,
                entry=entry,
                patch_root=patch_root,
                pub_dev=None,
                pub_cache=pub_cache,
                locked_packages=locked_packages,
                failures=failures,
            )
        )

    return checks


def _checks_from_entry(
    *,
    name: str,
    entry: Any,
    patch_root: Path,
    pub_dev: Path | None,
    pub_cache: Path,
    locked_packages: dict[str, LockedPackage],
    failures: list[str],
) -> list[PatchCheck]:
    if not isinstance(entry, dict):
        failures.append(f"{name}: foreign dependency entry must be an object")
        return []

    checks: list[PatchCheck] = []
    manifest = entry.get("manifest")
    if not isinstance(manifest, dict):
        return checks

    sources = manifest.get("sources", [])
    if not isinstance(sources, list):
        failures.append(f"{name}: manifest.sources must be a list")
        return checks

    for index, source in enumerate(sources):
        if not isinstance(source, dict) or source.get("type") != "patch":
            continue

        patch_path = source.get("path")
        if not isinstance(patch_path, str):
            failures.append(f"{name}: patch source #{index} is missing path")
            continue

        patch_file = patch_root / patch_path
        if not patch_file.is_file():
            failures.append(f"{name}: patch file does not exist: {patch_file}")
            continue

        destination = _resolve_destination(
            name=name,
            source=source,
            pub_dev=pub_dev,
            pub_cache=pub_cache,
            locked_packages=locked_packages,
            failures=failures,
        )
        if destination is None:
            continue

        options = source.get("options", [])
        if not isinstance(options, list) or not all(
            isinstance(option, str) for option in options
        ):
            failures.append(f"{name}: patch options must be a list of strings")
            continue

        strip_components = source.get("strip-components", 1)
        if not isinstance(strip_components, int):
            failures.append(f"{name}: strip-components must be an integer")
            continue

        checks.append(
            PatchCheck(
                name=name,
                patch_file=patch_file,
                destination=destination,
                strip_components=strip_components,
                options=options,
            )
        )

    return checks


def _resolve_destination(
    *,
    name: str,
    source: dict[str, Any],
    pub_dev: Path | None,
    pub_cache: Path,
    locked_packages: dict[str, LockedPackage],
    failures: list[str],
) -> Path | None:
    dest = source.get("dest")
    if not isinstance(dest, str):
        failures.append(f"{name}: patch source is missing dest")
        return None

    resolved = dest
    if pub_dev is not None:
        resolved = resolved.replace("$PUB_DEV", str(pub_dev))
    if resolved.startswith(".pub-cache/hosted/pub.dev"):
        resolved = resolved.replace(
            ".pub-cache/hosted/pub.dev",
            str(pub_cache / "hosted" / "pub.dev"),
            1,
        )

    unresolved = re.findall(r"\$[A-Za-z_][A-Za-z0-9_]*", resolved)
    if unresolved:
        failures.append(
            f"{name}: unresolved variable(s) in patch dest {dest!r}: "
            f"{', '.join(unresolved)}"
        )
        return None

    _validate_embedded_pub_versions(
        name=name,
        value=dest,
        locked_packages=locked_packages,
        failures=failures,
    )

    destination = Path(resolved).expanduser()
    if not destination.is_absolute():
        failures.append(f"{name}: patch dest must resolve to an absolute path: {dest}")
        return None

    return destination


def _run_patch_check(check: PatchCheck) -> list[str]:
    if not check.destination.is_dir():
        return [
            f"{check.name}: patch destination does not exist: {check.destination}. "
            "Run `flutter pub get` first."
        ]

    command = [
        "patch",
        "--dry-run",
        f"-p{check.strip_components}",
        *check.options,
        "-i",
        str(check.patch_file),
    ]
    result = subprocess.run(
        command,
        cwd=check.destination,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        print(f"OK: {check.name} -> {check.patch_file.relative_to(Path.cwd())}")
        return []

    output = "\n".join(
        line
        for line in [result.stdout.strip(), result.stderr.strip()]
        if line
    )
    return [
        f"{check.name}: patch dry-run failed in {check.destination} "
        f"for {check.patch_file}:\n{output}"
    ]


def _validate_embedded_pub_versions(
    *,
    name: str,
    value: Any,
    locked_packages: dict[str, LockedPackage],
    failures: list[str],
) -> None:
    for text in _walk_strings(value):
        for dep_name, version in PACKAGE_PATH_RE.findall(text):
            locked = locked_packages.get(dep_name)
            if locked is not None and locked.version != version:
                failures.append(
                    f"{name}: {dep_name} path references {version}, "
                    f"but pubspec.lock has {locked.version}"
                )


def _walk_strings(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [text for item in value for text in _walk_strings(item)]
    if isinstance(value, dict):
        return [text for item in value.values() for text in _walk_strings(item)]
    return []


def _read_json_object(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def _latest_compatible_version(
    versions: Any,
    locked_version: str,
) -> str | None:
    compatible = [
        version
        for version in versions
        if _version_key(str(version)) <= _version_key(locked_version)
    ]
    if not compatible:
        return None
    return max(compatible, key=_version_key)


def _version_key(version: str) -> tuple[tuple[int, ...], int, tuple[tuple[int, Any], ...]]:
    version = version.split("+", 1)[0]
    release, separator, prerelease = version.partition("-")
    release_key = tuple(int(part) for part in release.split(".") if part.isdigit())
    prerelease_key = tuple(_prerelease_part(part) for part in re.split(r"[.-]", prerelease))
    stable_rank = 1 if not separator else 0
    return release_key, stable_rank, prerelease_key


def _prerelease_part(part: str) -> tuple[int, Any]:
    if part.isdigit():
        return 0, int(part)
    return 1, part


def _unquote(value: str) -> str:
    return value.strip().strip('"').strip("'")


if __name__ == "__main__":
    raise SystemExit(main())
