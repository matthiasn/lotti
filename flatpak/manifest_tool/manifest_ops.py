"""Pure manifest mutation helpers."""

from __future__ import annotations

from typing import Iterable, Sequence, Optional

try:  # pragma: no cover
    from . import utils
    from .manifest import ManifestDocument, OperationResult
except ImportError:  # pragma: no cover
    import utils  # type: ignore
    from manifest import ManifestDocument, OperationResult  # type: ignore

_DEFAULT_REPO_URLS: tuple[str, ...] = (
    "https://github.com/matthiasn/lotti",
    "git@github.com:matthiasn/lotti",
)

_LOGGER = utils.get_logger("manifest_ops")


def ensure_flutter_setup_helper(
    document: ManifestDocument,
    *,
    helper_name: str,
) -> OperationResult:
    """Ensure flutter-sdk ships ``helper_name`` and lotti PATH includes /app/flutter/bin."""

    modules = document.ensure_modules()
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
                    f"/app/flutter/bin:{current_path}"
                    if current_path
                    else "/app/flutter/bin"
                )
                changed = True

    if changed:
        document.mark_changed()
        _LOGGER.debug("Ensured setup helper %s is present", helper_name)
        return OperationResult.changed_result(f"Ensured setup helper {helper_name}")
    return OperationResult.unchanged()


def pin_commit(
    document: ManifestDocument,
    *,
    commit: str,
    repo_urls: Sequence[str] | None = None,
) -> OperationResult:
    """Replace lotti git source commit with ``commit`` and drop branch keys."""

    targets: Iterable[str]
    if repo_urls is None:
        targets = _DEFAULT_REPO_URLS
    else:
        targets = repo_urls

    modules = document.ensure_modules()

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
        document.mark_changed()
        _LOGGER.debug("Pinned lotti module to commit %s", commit)
        return OperationResult.changed_result(f"Pinned lotti module to {commit}")
    return OperationResult.unchanged()


def ensure_module_include(
    document: ManifestDocument,
    *,
    module_name: str,
    before_name: Optional[str] = None,
) -> OperationResult:
    """Ensure a string module include (e.g., rustup-1.83.0.json) is present.

    If ``before_name`` is provided and a module with that name exists, the
    include is inserted just before it to influence build order; otherwise it is
    appended to the end of the modules list.
    """

    modules = document.ensure_modules()
    # Already present?
    for module in modules:
        if isinstance(module, str) and module == module_name:
            return OperationResult.unchanged()

    insert_index = None
    if before_name is not None:
        for idx, module in enumerate(modules):
            if isinstance(module, dict) and module.get("name") == before_name:
                insert_index = idx
                break
    if insert_index is None:
        modules.append(module_name)
    else:
        modules.insert(insert_index, module_name)

    document.mark_changed()
    _LOGGER.debug("Ensured module include %s", module_name)
    return OperationResult.changed_result(f"Ensured module include {module_name}")
