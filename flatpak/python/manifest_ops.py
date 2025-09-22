"""Pure manifest mutation helpers."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable, Sequence

try:  # pragma: no cover
    from . import utils
except ImportError:  # pragma: no cover
    import utils  # type: ignore

_DEFAULT_REPO_URLS: tuple[str, ...] = (
    "https://github.com/matthiasn/lotti",
    "git@github.com:matthiasn/lotti",
)


def ensure_flutter_setup_helper(manifest_path: str | Path, helper_name: str) -> bool:
    """Ensure the flutter-sdk module ships ``helper_name`` and PATH includes /app/flutter/bin."""

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

    changed = False
    for module in modules:
        if not isinstance(module, dict):
            continue
        name = module.get("name")
        if name == "flutter-sdk":
            sources = module.setdefault("sources", [])
            if not any(
                isinstance(source, dict)
                and source.get("dest-filename") == "setup-flutter.sh"
                for source in sources
            ):
                sources.append(
                    {
                        "type": "file",
                        "path": helper_name,
                        "dest": "flutter/bin",
                        "dest-filename": "setup-flutter.sh",
                    }
                )
                changed = True
        elif name == "lotti":
            build_options = module.setdefault("build-options", {})
            env = build_options.setdefault("env", {})
            current_path = env.get("PATH", "")
            entries = [entry for entry in current_path.split(":") if entry]
            if "/app/flutter/bin" not in entries:
                env["PATH"] = (
                    f"/app/flutter/bin:{current_path}" if current_path else "/app/flutter/bin"
                )
                changed = True

    if changed:
        utils.dump_manifest(manifest_path, data)
    return changed


def pin_commit(
    manifest_path: str | Path,
    *,
    commit: str,
    repo_urls: Sequence[str] | None = None,
) -> bool:
    """Replace lotti git source commit with ``commit`` and drop branch keys."""

    targets: Iterable[str]
    if repo_urls is None:
        targets = _DEFAULT_REPO_URLS
    else:
        targets = repo_urls

    data = utils.load_manifest(manifest_path)
    modules = data.get("modules")
    if not isinstance(modules, list):
        return False

    changed = False
    for module in modules:
        if not isinstance(module, dict) or module.get("name") != "lotti":
            continue
        for source in module.get("sources", []):
            if not isinstance(source, dict):
                continue
            url = source.get("url") or ""
            if url not in targets:
                continue
            if source.get("commit") == commit and "branch" not in source:
                continue
            source["commit"] = commit
            source.pop("branch", None)
            changed = True
    if changed:
        utils.dump_manifest(manifest_path, data)
    return changed
