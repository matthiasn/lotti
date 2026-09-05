import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Maps an entry-type key (as stored in `selectedEntryTypes`) to the glyph the
/// matching list card leads with, so the filter and the feed share one icon
/// vocabulary. Keep this in sync with the per-type glyphs in
/// `ModernJournalCard` / `ModernJournalImageCard`.
IconData entryTypeIcon(String type) {
  return switch (type) {
    'Task' => LottiIcons.confirmCircled,
    'JournalEntry' => LottiIcons.note,
    'JournalEvent' => LottiIcons.calendar,
    'JournalAudio' => LottiIcons.mic,
    'JournalImage' => LottiIcons.image,
    'MeasurementEntry' => LottiIcons.measure,
    'SurveyEntry' => LottiIcons.clipboardText,
    'WorkoutEntry' => LottiIcons.fitness,
    'HabitCompletionEntry' => LottiIcons.confirmCircled,
    'QuantitativeEntry' => LottiIcons.heartRate,
    'Checklist' => LottiIcons.checkAll,
    'ChecklistItem' => LottiIcons.checkboxChecked,
    'AiResponse' => LottiIcons.aiSpark,
    _ => LottiIcons.radioUnselected,
  };
}
