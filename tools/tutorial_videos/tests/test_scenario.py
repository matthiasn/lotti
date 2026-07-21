"""Tests for scenario loading and locale validation."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from tutorial_videos.scenario import ScenarioError, load_scenario  # noqa: E402

VALID = """\
scenario: sample
title: {en: Title, de: Titel}
dictionary:
  en: [Project Waddle]
  de: [Projekt Waddle]
steps:
  - id: intro
    min_duration: 3.0
    narration: {en: Hello, de: Hallo}
  - id: dictate
    min_duration: 4.0
    dictation: true
    narration: {en: Speak now, de: Sprich jetzt}
    dictation_text: {en: A task, de: Eine Aufgabe}
"""


class ScenarioTest(unittest.TestCase):
    def _load(self, text: str, name: str = "sample"):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / f"{name}.yaml"
            path.write_text(text)
            return load_scenario(path)

    def test_valid_scenario_loads_and_validates(self):
        scenario = self._load(VALID)
        self.assertEqual(scenario.name, "sample")
        self.assertEqual([s.id for s in scenario.steps], ["intro", "dictate"])
        self.assertEqual(scenario.dictation_step.id, "dictate")
        self.assertEqual(
            scenario.dictation_step.dictation_text["de"], "Eine Aufgabe"
        )
        scenario.validate_locale("en")
        scenario.validate_locale("de")

    def test_missing_locale_lists_every_gap(self):
        scenario = self._load(VALID)
        with self.assertRaises(ScenarioError) as ctx:
            scenario.validate_locale("fr")
        message = str(ctx.exception)
        for gap in (
            "title",
            "dictionary",
            "steps[intro].narration",
            "steps[dictate].dictation_text",
        ):
            self.assertIn(gap, message)

    def test_scenario_name_must_match_filename(self):
        with self.assertRaises(ScenarioError):
            self._load(VALID, name="other")

    def test_dictation_step_is_optional(self):
        no_dictation = VALID.replace("dictation: true", "dictation: false").replace(
            "    dictation_text: {en: A task, de: Eine Aufgabe}\n", ""
        )
        scenario = self._load(no_dictation)
        self.assertIsNone(scenario.dictation_step)

    def test_multiple_dictation_steps_rejected(self):
        doubled = VALID.replace(
            """  - id: intro
    min_duration: 3.0
    narration: {en: Hello, de: Hallo}""",
            """  - id: intro
    min_duration: 3.0
    dictation: true
    narration: {en: Hello, de: Hallo}
    dictation_text: {en: Hi, de: Hallo}""",
        )
        with self.assertRaises(ScenarioError):
            self._load(doubled)

    def test_dictation_text_without_flag_rejected(self):
        stray = VALID.replace("dictation: true", "dictation: false")
        with self.assertRaises(ScenarioError):
            self._load(stray)

    def test_duplicate_step_ids_rejected(self):
        dupe = VALID.replace("id: dictate", "id: intro")
        with self.assertRaises(ScenarioError):
            self._load(dupe)

    def test_nonpositive_min_duration_rejected(self):
        bad = VALID.replace("min_duration: 3.0", "min_duration: 0")
        with self.assertRaises(ScenarioError):
            self._load(bad)

    def test_real_scenario_buildable_for_en_and_de(self):
        path = TOOL_ROOT / "config" / "scenarios" / "create_task_from_audio.yaml"
        scenario = load_scenario(path)
        scenario.validate_locale("en")
        scenario.validate_locale("de")
        self.assertTrue(scenario.dictation_step.dictation_text["de"])
        self.assertGreaterEqual(len(scenario.steps), 5)


if __name__ == "__main__":
    unittest.main()
