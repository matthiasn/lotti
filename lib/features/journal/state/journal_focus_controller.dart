import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journal_focus_controller.g.dart';

/// Intent to focus on a specific entry within a journal entry
class JournalFocusIntent {
  JournalFocusIntent({
    required this.journalId,
    required this.entryId,
    this.alignment = 0.0,
  });

  /// The journal ID containing the entry
  final String journalId;

  /// The entry ID to scroll to
  final String entryId;

  /// The alignment of the target (0.0 = top, 0.5 = center, 1.0 = bottom)
  final double alignment;

  @override
  String toString() =>
      'JournalFocusIntent(journalId: $journalId, entryId: $entryId, alignment: $alignment)';
}

@riverpod
class JournalFocusController extends _$JournalFocusController {
  JournalFocusController();

  @override
  JournalFocusIntent? build({required String id}) {
    ref.keepAlive();
    return null;
  }

  /// Publish a focus intent for a specific entry
  void publishJournalFocus({
    required String entryId,
    double alignment = 0.0,
  }) {
    state = JournalFocusIntent(
      journalId: id,
      entryId: entryId,
      alignment: alignment,
    );
  }

  /// Clear the current intent (called after consumption to enable re-triggering)
  void clearIntent() {
    state = null;
  }
}

/// Helper function to publish a journal focus intent
void publishJournalFocus({
  required String journalId,
  required String entryId,
  required WidgetRef ref,
  double alignment = 0.0,
}) {
  ref
      .read(journalFocusControllerProvider(id: journalId).notifier)
      .publishJournalFocus(
        entryId: entryId,
        alignment: alignment,
      );
}
