import 'package:lotti/classes/journal_entities.dart';

/// Activity kinds surfaced as toggle pills above the linked entries list.
///
/// Each kind maps a slice of [JournalEntity] subtypes to a single filter
/// pill (Timer / Audio / Images). Entity types not covered by any kind
/// are always visible — the pills only filter "task activities".
///
/// Checklists are intentionally absent: they have a dedicated section at
/// the top of the task details page, so a Todo pill in the linked
/// entries section would be misleading.
enum LinkedEntryActivityFilter {
  timer,
  audio,
  images
  ;

  /// Returns the pill kind a [entity] belongs to, or `null` when the entity
  /// is not part of the activity-filter taxonomy and should always render.
  static LinkedEntryActivityFilter? fromEntity(JournalEntity entity) {
    return switch (entity) {
      JournalEntry() => LinkedEntryActivityFilter.timer,
      JournalAudio() => LinkedEntryActivityFilter.audio,
      JournalImage() => LinkedEntryActivityFilter.images,
      _ => null,
    };
  }
}
