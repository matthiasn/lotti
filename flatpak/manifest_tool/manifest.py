"""Manifest helpers and operation result types."""

from __future__ import annotations

import copy
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

try:  # pragma: no cover
    from . import utils
except ImportError:  # pragma: no cover
    import utils  # type: ignore


@dataclass
class OperationResult:
    """Represents the outcome of a manifest operation."""

    changed: bool = False
    messages: list[str] = field(default_factory=list)

    @classmethod
    def unchanged(cls) -> "OperationResult":
        return cls(changed=False)

    @classmethod
    def changed_result(cls, *messages: str) -> "OperationResult":
        return cls(changed=True, messages=list(messages))

    def add_message(self, message: str) -> None:
        self.messages.append(message)

    def merge(self, other: "OperationResult") -> "OperationResult":
        return OperationResult(
            changed=self.changed or other.changed,
            messages=[*self.messages, *other.messages],
        )


@dataclass
class ManifestDocument:
    """In-memory representation of a Flatpak manifest."""

    path: Path
    data: dict[str, Any] = field(default_factory=dict)
    _changed: bool = False

    @classmethod
    def load(
        cls, path: str | Path, *, allow_missing: bool = False
    ) -> "ManifestDocument":
        manifest_path = Path(path)
        if allow_missing and not manifest_path.exists():
            return cls(manifest_path, {})
        data = utils.load_manifest(manifest_path)
        return cls(manifest_path, data)

    def copy(self) -> "ManifestDocument":
        return ManifestDocument(self.path, copy.deepcopy(self.data))

    def mark_changed(self) -> None:
        self._changed = True

    @property
    def changed(self) -> bool:
        return self._changed

    def ensure_modules(self) -> list[Any]:
        if "modules" not in self.data:
            raise TypeError("manifest.modules must be a list")

        modules = self.data["modules"]
        if not isinstance(modules, list):
            raise TypeError("manifest.modules must be a list")
        return modules

    def save(self) -> None:
        utils.dump_manifest(self.path, self.data)
        self._changed = False


def merge_results(results: Iterable[OperationResult]) -> OperationResult:
    merged = OperationResult.unchanged()
    for result in results:
        merged = merged.merge(result)
    return merged
