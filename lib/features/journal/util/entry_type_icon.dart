import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

/// Maps an entry-type key (as stored in `selectedEntryTypes`) to the glyph the
/// matching list card leads with, so the filter and the feed share one icon
/// vocabulary. Keep this in sync with the per-type glyphs in
/// `ModernJournalCard` / `ModernJournalImageCard` / `ModernTaskCard`.
IconData entryTypeIcon(String type) {
  return switch (type) {
    'Task' => Icons.check_circle_outline_rounded,
    'JournalEntry' => Icons.notes_rounded,
    'JournalEvent' => Icons.event_rounded,
    'JournalAudio' => Icons.mic_rounded,
    'JournalImage' => Icons.image_rounded,
    'MeasurementEntry' => MdiIcons.ruler,
    'SurveyEntry' => MdiIcons.clipboardTextOutline,
    'WorkoutEntry' => Icons.fitness_center_rounded,
    'HabitCompletionEntry' => Icons.check_circle_rounded,
    'QuantitativeEntry' => MdiIcons.heartPulse,
    'Checklist' => MdiIcons.checkAll,
    'ChecklistItem' => MdiIcons.checkboxMarkedOutline,
    'AiResponse' => Icons.auto_awesome_rounded,
    _ => Icons.circle_outlined,
  };
}
