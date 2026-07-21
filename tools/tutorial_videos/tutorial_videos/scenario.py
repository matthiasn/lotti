"""Scenario configuration: loading and validation.

A scenario YAML (see ``config/scenarios/``) is the single source of truth for
one tutorial video: ordered steps, per-locale narration, the dictation step's
user-voice text, and the speech-dictionary terms seeded into the app. This
module loads a scenario and validates that a requested locale is fully
buildable — missing text for a locale fails loudly here, before any API call
or app launch.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import yaml


class ScenarioError(ValueError):
    """A scenario file is malformed or incomplete for a requested locale."""


@dataclass(frozen=True)
class Step:
    id: str
    min_duration: float
    narration: dict[str, str]
    dictation: bool = False
    dictation_text: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class Scenario:
    name: str
    title: dict[str, str]
    dictionary: dict[str, list[str]]
    steps: list[Step]

    @property
    def dictation_step(self) -> Step | None:
        return next((step for step in self.steps if step.dictation), None)

    def validate_locale(self, locale: str) -> None:
        """Raise ScenarioError unless ``locale`` is fully buildable."""
        missing: list[str] = []
        if locale not in self.title:
            missing.append("title")
        if not self.dictionary.get(locale):
            missing.append("dictionary")
        for step in self.steps:
            if locale not in step.narration:
                missing.append(f"steps[{step.id}].narration")
            if step.dictation and locale not in step.dictation_text:
                missing.append(f"steps[{step.id}].dictation_text")
        if missing:
            raise ScenarioError(
                f"scenario '{self.name}' is not buildable for locale "
                f"'{locale}'; missing: {', '.join(missing)}"
            )


def load_scenario(path: Path) -> Scenario:
    raw = yaml.safe_load(path.read_text())
    if not isinstance(raw, dict):
        raise ScenarioError(f"{path}: not a mapping")

    name = raw.get("scenario")
    if name != path.stem:
        raise ScenarioError(
            f"{path}: 'scenario' ({name!r}) must match the file name "
            f"({path.stem!r})"
        )

    steps_raw = raw.get("steps")
    if not steps_raw:
        raise ScenarioError(f"{path}: 'steps' is missing or empty")

    steps: list[Step] = []
    for i, entry in enumerate(steps_raw):
        step_id = entry.get("id")
        if not step_id:
            raise ScenarioError(f"{path}: steps[{i}] has no id")
        narration = entry.get("narration")
        if not isinstance(narration, dict) or not narration:
            raise ScenarioError(f"{path}: steps[{step_id}] has no narration")
        min_duration = entry.get("min_duration")
        if not isinstance(min_duration, (int, float)) or min_duration <= 0:
            raise ScenarioError(
                f"{path}: steps[{step_id}] needs a positive min_duration"
            )
        dictation = bool(entry.get("dictation", False))
        dictation_text = entry.get("dictation_text", {})
        if dictation and not dictation_text:
            raise ScenarioError(
                f"{path}: steps[{step_id}] is a dictation step but has no "
                "dictation_text"
            )
        if dictation_text and not dictation:
            raise ScenarioError(
                f"{path}: steps[{step_id}] has dictation_text but is not "
                "marked dictation: true"
            )
        steps.append(
            Step(
                id=step_id,
                min_duration=float(min_duration),
                narration=dict(narration),
                dictation=dictation,
                dictation_text=dict(dictation_text),
            )
        )

    ids = [step.id for step in steps]
    if len(set(ids)) != len(ids):
        raise ScenarioError(f"{path}: duplicate step ids")
    if sum(step.dictation for step in steps) > 1:
        raise ScenarioError(f"{path}: at most one dictation step is allowed")

    return Scenario(
        name=name,
        title=dict(raw.get("title") or {}),
        dictionary={k: list(v) for k, v in (raw.get("dictionary") or {}).items()},
        steps=steps,
    )
