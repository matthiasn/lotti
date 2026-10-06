import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/backfill/inference_backfill.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_detector.dart';
import 'package:lotti/features/ai/backfill/inference_backfill_queue.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// The candidates stored data yields for a task, rescanned whenever the task,
/// one of its media entries, a category or the AI configuration changes.
///
/// A category change matters because its automatic-inference switch is the
/// gate: turning it on offers the backlog, turning it off withdraws it. The
/// AI configuration matters because the other half of the gate — whether a
/// profile automates the skill and has its model — is read from profiles,
/// skills, models and providers, which change through their own stream
/// rather than journal notifications.
final AsyncNotifierProviderFamily<
  InferenceBackfillScanController,
  InferenceBackfillScan,
  String
>
inferenceBackfillScanProvider = AsyncNotifierProvider.autoDispose
    .family<InferenceBackfillScanController, InferenceBackfillScan, String>(
      InferenceBackfillScanController.new,
      name: 'inferenceBackfillScanProvider',
    );

/// The AI configuration the automation gate reads.
const List<AiConfigType> _gateConfigTypes = [
  AiConfigType.inferenceProfile,
  AiConfigType.skill,
  AiConfigType.model,
  AiConfigType.inferenceProvider,
];

class InferenceBackfillScanController
    extends AsyncNotifier<InferenceBackfillScan> {
  InferenceBackfillScanController(this.taskId);

  final String taskId;

  /// Bumped by every scan. Scans overlap — each notification starts one — and
  /// a slow scan that read the database before an analysis landed must not
  /// overwrite a faster, later one that read it after: only the latest
  /// generation may publish.
  int _generation = 0;

  @override
  Future<InferenceBackfillScan> build() async {
    final subscriptions = [
      ref.watch(updateNotificationsProvider).updateStream.listen(_onUpdate),
      for (final type in _gateConfigTypes)
        ref
            .read(aiConfigRepositoryProvider)
            .watchConfigsByType(type)
            // The first event replays the snapshot the initial scan reads.
            .skip(1)
            .listen((_) => _rescan()),
    ];
    ref.onDispose(
      () => Future.wait([
        for (final subscription in subscriptions) subscription.cancel(),
      ]),
    );
    final generation = ++_generation;
    final scan = await ref.read(inferenceBackfillDetectorProvider).scan(taskId);
    // A rescan that started after this one has published, or will: keep its
    // newer answer rather than this older one.
    if (generation != _generation && state.hasValue) return state.requireValue;
    return scan;
  }

  Future<void> _onUpdate(Set<String> affectedIds) async {
    final watched = state.value?.watchedIds ?? {taskId};
    if (!affectedIds.contains(categoriesNotification) &&
        affectedIds.intersection(watched).isEmpty) {
      return;
    }
    await _rescan();
  }

  /// Scans again and publishes the result if no later scan has started.
  /// Never throws: a failure is logged and the last list stays.
  Future<void> _rescan() async {
    final generation = ++_generation;
    try {
      final scan = await ref
          .read(inferenceBackfillDetectorProvider)
          .scan(taskId);
      if (ref.mounted && generation == _generation) state = AsyncData(scan);
    } catch (exception, stackTrace) {
      // A background rescan keeps the last list rather than flashing an
      // error over suggestions that were fine a moment ago.
      ref
          .read(domainLoggerProvider)
          .error(
            LogDomain.ai,
            exception,
            stackTrace: stackTrace,
            subDomain: 'inferenceBackfillScan',
          );
    }
  }
}

/// Settings key holding the dismissed suggestion keys, as a JSON list.
const inferenceBackfillDismissedKey = 'INFERENCE_BACKFILL_DISMISSED';

/// Backfill suggestions the user dismissed on this device.
///
/// Device-local, like the rest of `SettingsDb`: a dismissal is a reading
/// preference for the list, not a change to the entry, so it rides on no
/// synced entity. Without it a dismissed suggestion would come straight
/// back on the next scan.
class InferenceBackfillDismissals extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final raw = await ref
        .read(settingsDbProvider)
        .itemByKey(inferenceBackfillDismissedKey);
    if (raw == null) return const {};
    try {
      return (jsonDecode(raw) as List<dynamic>).whereType<String>().toSet();
    } on FormatException {
      return const {};
    }
  }

  /// Hides [candidate] from the list on this device for good.
  Future<void> dismiss(InferenceBackfillCandidate candidate) async {
    final current = state.value ?? await future;
    if (current.contains(candidate.key)) return;
    final next = {...current, candidate.key};
    state = AsyncData(next);
    await ref
        .read(settingsDbProvider)
        .saveSettingsItem(
          inferenceBackfillDismissedKey,
          jsonEncode(next.toList()..sort()),
        );
  }
}

final inferenceBackfillDismissalsProvider =
    AsyncNotifierProvider<InferenceBackfillDismissals, Set<String>>(
      InferenceBackfillDismissals.new,
      name: 'inferenceBackfillDismissalsProvider',
    );

/// The backfill suggestions to show for a task, newest entry first.
///
/// Re-evaluated whenever a scan, the queue, a dismissal or one of the
/// candidates' inference statuses changes, so an entry drops out the moment
/// its inference starts — from any trigger — and comes back if that run
/// fails. Empty until both the scan and the dismissals have loaded, so a
/// dismissed suggestion never flashes in first.
final ProviderFamily<List<InferenceBackfillCandidate>, String>
inferenceBackfillSuggestionsProvider = Provider.autoDispose
    .family<List<InferenceBackfillCandidate>, String>(
      (ref, taskId) {
        final scan = ref.watch(inferenceBackfillScanProvider(taskId)).value;
        final dismissed = ref.watch(inferenceBackfillDismissalsProvider).value;
        if (scan == null || dismissed == null) return const [];
        final queued = ref.watch(inferenceBackfillQueueProvider);

        bool isRunning(InferenceBackfillCandidate candidate) =>
            candidate.kind.busyResponseTypes.any(
              (type) =>
                  ref.watch(
                    inferenceStatusControllerProvider((
                      id: candidate.entryId,
                      aiResponseType: type,
                    )),
                  ) ==
                  InferenceStatus.running,
            );

        return [
          for (final candidate in scan.candidates)
            if (!dismissed.contains(candidate.key) &&
                !queued.contains(candidate.key) &&
                !isRunning(candidate))
              candidate,
        ];
      },
      name: 'inferenceBackfillSuggestionsProvider',
    );
