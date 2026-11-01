import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion.dart';
import 'package:lotti/features/ai/link_suggestions/task_link_suggestion_detector.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/ai/state/device_local_key_set.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/domain_logging.dart';

final taskLinkSuggestionDetectorProvider = Provider<TaskLinkSuggestionDetector>(
  (ref) => TaskLinkSuggestionDetector(
    db: ref.watch(journalDbProvider),
    search: ref.watch(vectorSearchRepositoryProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'taskLinkSuggestionDetectorProvider',
);

/// The link suggestions a task's text yields, rescanned whenever the task,
/// one of its text entries or a suggested task changes.
///
/// A new or edited log entry changes the task's links or the entry itself, so
/// it is seen here as it happens — while the task is on screen; nothing scans
/// a task nobody is looking at. Searches run on the embedding model's own
/// thread and are reused across rescans for every sentence that did not
/// change, so a rescan after an unrelated edit embeds nothing.
final AsyncNotifierProviderFamily<
  TaskLinkSuggestionScanController,
  TaskLinkSuggestionScan,
  String
>
taskLinkSuggestionScanProvider = AsyncNotifierProvider.autoDispose
    .family<TaskLinkSuggestionScanController, TaskLinkSuggestionScan, String>(
      TaskLinkSuggestionScanController.new,
      name: 'taskLinkSuggestionScanProvider',
    );

class TaskLinkSuggestionScanController
    extends AsyncNotifier<TaskLinkSuggestionScan> {
  TaskLinkSuggestionScanController(this.taskId);

  final String taskId;

  /// Bumped by every scan. Scans overlap — each notification starts one —
  /// and a slow scan that read the task before an edit must not overwrite a
  /// later one that read it after: only the latest generation publishes.
  int _generation = 0;

  @override
  Future<TaskLinkSuggestionScan> build() async {
    final subscription = ref
        .watch(updateNotificationsProvider)
        .updateStream
        .listen(_onUpdate);
    ref.onDispose(subscription.cancel);
    final generation = ++_generation;
    final scan = await ref
        .read(taskLinkSuggestionDetectorProvider)
        .scan(taskId);
    if (generation != _generation && state.hasValue) return state.requireValue;
    return scan;
  }

  Future<void> _onUpdate(Set<String> affectedIds) async {
    final watched = state.value?.watchedIds ?? {taskId};
    if (affectedIds.intersection(watched).isEmpty) return;
    await _rescan();
  }

  /// Scans again, reusing the last scan's searches, and publishes the result
  /// if no later scan has started. Never throws: a failure is logged and the
  /// last list stays, rather than an error replacing suggestions that were
  /// fine a moment ago.
  Future<void> _rescan() async {
    final generation = ++_generation;
    try {
      final scan = await ref
          .read(taskLinkSuggestionDetectorProvider)
          .scan(taskId, previous: state.value);
      if (ref.mounted && generation == _generation) state = AsyncData(scan);
    } catch (exception, stackTrace) {
      ref
          .read(domainLoggerProvider)
          .error(
            LogDomain.ai,
            exception,
            stackTrace: stackTrace,
            subDomain: 'taskLinkSuggestionScan',
          );
    }
  }
}

/// Settings key holding the dismissed suggestion keys, as a JSON list.
const taskLinkSuggestionsDismissedKey = 'TASK_LINK_SUGGESTIONS_DISMISSED';

/// The pairs of tasks whose link suggestion the user dismissed on this
/// device. Without it a dismissed suggestion would come straight back on the
/// next scan.
class TaskLinkSuggestionDismissals extends DeviceLocalKeySet {
  @override
  String get settingsKey => taskLinkSuggestionsDismissedKey;

  /// Hides [suggestion]'s pair of tasks from the list on this device.
  Future<void> dismiss(TaskLinkSuggestion suggestion) => addKey(suggestion.key);
}

final taskLinkSuggestionDismissalsProvider =
    AsyncNotifierProvider<TaskLinkSuggestionDismissals, Set<String>>(
      TaskLinkSuggestionDismissals.new,
      name: 'taskLinkSuggestionDismissalsProvider',
    );

/// The pairs whose suggestion the user accepted in this session.
///
/// The link the acceptance wrote is what keeps the suggestion away for good:
/// the next scan finds the pair linked. This only covers the moment between
/// the write and that scan, so an accepted row cannot reappear before it.
class TaskLinkSuggestionAccepted extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void accept(TaskLinkSuggestion suggestion) {
    if (state.contains(suggestion.key)) return;
    state = {...state, suggestion.key};
  }
}

final taskLinkSuggestionAcceptedProvider =
    NotifierProvider<TaskLinkSuggestionAccepted, Set<String>>(
      TaskLinkSuggestionAccepted.new,
      name: 'taskLinkSuggestionAcceptedProvider',
    );

/// The link suggestions to show for a task, nearest first.
///
/// Empty until both the scan and the dismissals have loaded, so a dismissed
/// suggestion never flashes in first.
final ProviderFamily<List<TaskLinkSuggestion>, String>
taskLinkSuggestionsProvider = Provider.autoDispose
    .family<List<TaskLinkSuggestion>, String>(
      (ref, taskId) {
        final scan = ref.watch(taskLinkSuggestionScanProvider(taskId)).value;
        final dismissed = ref.watch(taskLinkSuggestionDismissalsProvider).value;
        if (scan == null || dismissed == null) return const [];
        final accepted = ref.watch(taskLinkSuggestionAcceptedProvider);
        return [
          for (final suggestion in scan.suggestions)
            if (!dismissed.contains(suggestion.key) &&
                !accepted.contains(suggestion.key))
              suggestion,
        ];
      },
      name: 'taskLinkSuggestionsProvider',
    );
