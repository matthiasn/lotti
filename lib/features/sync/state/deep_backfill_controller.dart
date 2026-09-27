import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/get_it.dart';

/// Records of each synced type on this device, deletions included, or null
/// where no sync stack runs (a demo world). Read on demand: counting a large
/// journal is not free, so the page refreshes it explicitly.
final FutureProvider<Map<SyncSequencePayloadType, int>?>
deepBackfillRecordCountsProvider =
    FutureProvider.autoDispose<Map<SyncSequencePayloadType, int>?>(
      (ref) async => getIt.isRegistered<DeepBackfillService>()
          ? getIt<DeepBackfillService>().recordCounts()
          : null,
      name: 'deepBackfillRecordCountsProvider',
    );

final deepBackfillControllerProvider =
    NotifierProvider<DeepBackfillController, DeepBackfillState>(
      DeepBackfillController.new,
    );

/// UI state of a manual deep-backfill round: how many records have been
/// advertised out of the round's [total], whether it is still running, and
/// the error that stopped it.
class DeepBackfillState {
  const DeepBackfillState({
    this.isRunning = false,
    this.isDone = false,
    this.advertised = 0,
    this.total = 0,
    this.error,
  });

  final bool isRunning;

  /// The round finished: every batch is in the outbox.
  final bool isDone;
  final int advertised;
  final int total;
  final String? error;

  /// Share of the round advertised so far, 0 to 1; 1 for an empty round.
  double get progress => total == 0 ? (isDone ? 1 : 0) : advertised / total;
}

/// Runs one deep-backfill round from the sync maintenance page. The round
/// only advertises this device's records; the requests and pushes it sets
/// off arrive while sync runs, long after the modal has closed.
class DeepBackfillController extends Notifier<DeepBackfillState> {
  @override
  DeepBackfillState build() => const DeepBackfillState();

  /// Starts a round, unless one is already running: the modal can be
  /// dismissed and reopened while a round is still enqueueing its batches.
  Future<void> runRound() async {
    if (state.isRunning) return;
    state = const DeepBackfillState(isRunning: true);
    try {
      final summary = await getIt<DeepBackfillService>().runRound(
        onProgress: (progress) {
          state = DeepBackfillState(
            isRunning: true,
            advertised: progress.records,
            total: progress.total,
          );
        },
      );
      state = DeepBackfillState(
        isDone: true,
        advertised: summary.records,
        total: summary.records,
      );
    } catch (error) {
      state = DeepBackfillState(error: error.toString());
    }
  }
}
