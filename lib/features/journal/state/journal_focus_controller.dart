import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

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

final NotifierProviderFamily<
  JournalFocusController,
  JournalFocusIntent?,
  String
>
journalFocusControllerProvider = NotifierProvider.autoDispose
    .family<JournalFocusController, JournalFocusIntent?, String>(
      JournalFocusController.new,
      name: 'journalFocusControllerProvider',
    );

class JournalFocusController extends Notifier<JournalFocusIntent?> {
  JournalFocusController(this.id);

  final String id;

  @override
  JournalFocusIntent? build() {
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
