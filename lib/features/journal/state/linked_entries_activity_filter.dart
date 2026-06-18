import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';

/// Activity kinds surfaced as toggle pills above the linked entries list.
///
/// Each kind maps a slice of [JournalEntity] subtypes to a single filter
/// pill (Timer / Audio / Images / Code). Entity types not covered by any
/// kind are always visible — the pills only filter "task activities".
///
/// Checklists are intentionally absent: they have a dedicated section at
/// the top of the task details page, so a Todo pill in the linked
/// entries section would be misleading.
enum LinkedEntryActivityFilter {
  timer,
  audio,
  images,
  code;

  /// Returns the pill kind a [entity] belongs to, or `null` when the entity
  /// is not part of the activity-filter taxonomy and should always render.
  ///
  /// Only coding prompts ([AiResponseType.promptGeneration]) map to [code];
  /// other [AiResponseEntry] kinds (transcripts, image analysis, image-prompt
  /// generation) are not part of the taxonomy and always render.
  static LinkedEntryActivityFilter? fromEntity(JournalEntity entity) {
    return switch (entity) {
      JournalEntry() => LinkedEntryActivityFilter.timer,
      JournalAudio() => LinkedEntryActivityFilter.audio,
      JournalImage() => LinkedEntryActivityFilter.images,
      AiResponseEntry() =>
        entity.data.type == AiResponseType.promptGeneration
            ? LinkedEntryActivityFilter.code
            : null,
      _ => null,
    };
  }
}
