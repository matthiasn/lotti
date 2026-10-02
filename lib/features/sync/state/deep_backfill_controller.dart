import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/deep_backfill/deep_backfill_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/get_it.dart';

/// Records of each synced type on this device, deletions included, or null
/// where no sync stack runs (a demo world). Kept current while something
/// listens — the page, while it is shown — and the app is visible: a
/// backgrounded app keeps a retained route (and so this provider) alive, and
/// must not keep counting. On return to the foreground it counts at once. A
/// count that fails surfaces as an error without ending the polling, so the
/// next successful count replaces it.
final StreamProvider<Map<SyncSequencePayloadType, int>?>
deepBackfillRecordCountsProvider =
    StreamProvider.autoDispose<Map<SyncSequencePayloadType, int>?>(
      (ref) {
        if (!getIt.isRegistered<DeepBackfillService>()) {
          return Stream.value(null);
        }
        final poller = _RecordCountsPoller(getIt<DeepBackfillService>());
        ref.onDispose(poller.dispose);
        return poller.counts;
      },
      name: 'deepBackfillRecordCountsProvider',
    );

/// Counts every type at once, then every
/// [SyncTuning.recordCountsRefreshInterval] re-counts only the types whose
/// table the database reported written to, and every
/// [SyncTuning.recordCountsFullRecountInterval] all of them, for the writes
/// it does not report. A full `COUNT(*)` of a large table each second was
/// the top source of slow queries while the page stayed open. Nothing is
/// counted while the app is hidden; a tick that finds the previous count
/// still running is skipped, so slow counts never pile up.
class _RecordCountsPoller {
  _RecordCountsPoller(this._service) {
    _lifecycle = AppLifecycleListener(
      onShow: () {
        unawaited(_countAll());
        _start();
      },
      onHide: _stop,
    );
    _changes = _service.recordChanges.listen(_changed.add);
    unawaited(_countAll());
    _start();
  }

  /// Ticks between two full counts.
  static final int _ticksPerFullCount =
      SyncTuning.recordCountsFullRecountInterval.inMicroseconds ~/
      SyncTuning.recordCountsRefreshInterval.inMicroseconds;

  final DeepBackfillService _service;
  final _controller = StreamController<Map<SyncSequencePayloadType, int>>();
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<SyncSequencePayloadType> _changes;
  final _changed = <SyncSequencePayloadType>{};
  Map<SyncSequencePayloadType, int> _last = const {};
  Timer? _timer;
  bool _inFlight = false;

  /// Every type needs counting: none has been yet, the last full count
  /// failed, or a full interval has passed since.
  bool _fullDue = true;
  int _ticksSinceFull = 0;

  Stream<Map<SyncSequencePayloadType, int>> get counts => _controller.stream;

  void _start() => _timer ??= Timer.periodic(
    SyncTuning.recordCountsRefreshInterval,
    (_) => unawaited(_tick()),
  );

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (++_ticksSinceFull >= _ticksPerFullCount) _fullDue = true;
    if (_fullDue) return _countAll();
    if (_changed.isEmpty) return;
    await _count(only: {..._changed});
  }

  Future<void> _countAll() async {
    _fullDue = true;
    await _count();
  }

  /// Counts [only] those types (every type when null), publishes them over
  /// the last counts, and clears what it counted from the pending work. A
  /// change that lands while the count runs stays pending; what a failed
  /// count covered stays pending too, so the next tick retries it.
  Future<void> _count({Set<SyncSequencePayloadType>? only}) async {
    if (_inFlight) return;
    _inFlight = true;
    if (only == null) {
      _fullDue = false;
      _ticksSinceFull = 0;
      _changed.clear();
    } else {
      _changed.removeAll(only);
    }
    try {
      final counts = await _service.recordCounts(only: only);
      _last = only == null ? counts : {..._last, ...counts};
      if (!_controller.isClosed) _controller.add(_last);
    } catch (error, stackTrace) {
      if (only == null) {
        _fullDue = true;
      } else {
        _changed.addAll(only);
      }
      if (!_controller.isClosed) _controller.addError(error, stackTrace);
    } finally {
      _inFlight = false;
    }
  }

  void dispose() {
    _stop();
    _lifecycle.dispose();
    unawaited(_changes.cancel());
    unawaited(_controller.close());
  }
}

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
