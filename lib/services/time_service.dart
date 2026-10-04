import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Persists the progress of a running timer's entry. Implemented by the
/// persistence layer and injected so this low-level service stays free of a
/// direct database dependency (and so unit tests can observe the call
/// without a real DB).
typedef PersistRunningTimer = Future<void> Function(JournalEntity entry);

/// How often a running timer's entry is written to the database while it
/// runs, so the calendar — on this device and, through sync, on every other
/// one — shows the session growing instead of a gap until it is stopped.
const runningTimerAutosaveInterval = Duration(minutes: 5);

class TimeService {
  TimeService({
    this._persistTimerStop,
    this._autosave,
    this._autosaveInterval = runningTimerAutosaveInterval,
  }) {
    _controller = StreamController<JournalEntity?>.broadcast();
  }

  /// Persists a running session's end time when it stops — by [stop], or
  /// by [start] replacing it. Null when the service is constructed without
  /// persistence (bare unit tests) — finalization is then skipped.
  final PersistRunningTimer? _persistTimerStop;

  /// Persists the running entry every [_autosaveInterval] while it runs.
  /// Null when the service is constructed without persistence — no autosave
  /// cadence is scheduled then.
  final PersistRunningTimer? _autosave;
  final Duration _autosaveInterval;

  late final StreamController<JournalEntity?> _controller;
  JournalEntity? _current;
  JournalEntity? linkedFrom;

  /// Emits the running entry, ending now, once a second.
  Timer? _ticker;
  Timer? _autosaveTimer;

  /// Starts a timer on [journalEntity], for the entry [linked] it was
  /// started from. A session still running is stopped first, its end written
  /// ([stop]).
  Future<void> start(JournalEntity journalEntity, JournalEntity? linked) async {
    if (_current != null) {
      // A new session is replacing one that is still running. Its real stop
      // time is persisted before it is discarded; otherwise it keeps the
      // stale `dateTo` of its last save and the elapsed span is lost. A
      // failure here must never block the new timer from starting.
      await stop();
    }

    _current = journalEntity;
    linkedFrom = linked;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_current != null) {
        _controller.add(
          _current!.copyWith(
            meta: _current!.meta.copyWith(dateTo: clock.now()),
          ),
        );
      }
    });

    if (_autosave != null) {
      _autosaveTimer = Timer.periodic(
        _autosaveInterval,
        (_) => _persistSafely(
          _autosave,
          journalEntity,
          subDomain: 'autosaveRunningTimer',
        ),
      );
    }
  }

  /// Runs [persist] for [entry] when one was injected, swallowing (but
  /// logging) any failure: neither a replacing timer nor the running one may
  /// be disturbed by a write that did not land.
  Future<void> _persistSafely(
    PersistRunningTimer? persist,
    JournalEntity entry, {
    required String subDomain,
  }) async {
    if (persist == null) {
      return;
    }
    try {
      await persist(entry);
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }

  JournalEntity? getCurrent() {
    return _current;
  }

  /// Starts a timer on [journalEntity] only while none runs, and answers
  /// whether it did. The check and the start happen in one step — nothing
  /// is awaited between them — so a timer the user starts while a caller
  /// prepares its own is never replaced by it
  /// (`specs/tla/RunningTimer.tla`, AgentStartAtomic).
  Future<bool> startIfIdle(
    JournalEntity journalEntity,
    JournalEntity? linked,
  ) async {
    if (_current != null) return false;
    await start(journalEntity, linked);
    return true;
  }

  /// Stops the running timer, if any, and writes its entry's end time as now
  /// ([persistEnd]): every way of stopping it — the entry's stop button, the
  /// sidebar's, a profile switch, quitting the app, a new timer — keeps the
  /// time tracked since the last autosave (`specs/tla/RunningTimer.tla`,
  /// StopPersists). A caller that has just written the end itself, or whose
  /// entry is deleted, passes `persistEnd: false`. A failed write is logged
  /// and the timer stops all the same.
  Future<void> stop({bool persistEnd = true}) async {
    final outgoing = _current;
    if (outgoing == null) return;
    _current = null;
    linkedFrom = null;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _ticker?.cancel();
    _ticker = null;
    _controller.add(null);
    if (persistEnd) {
      await _persistSafely(
        _persistTimerStop,
        outgoing,
        subDomain: 'finalizeRunningTimer',
      );
    }
  }

  Stream<JournalEntity?> getStream() {
    return _controller.stream;
  }

  void updateCurrent(JournalEntity? current) {
    if (_current?.id == current?.id) {
      _current = current;
    }
  }
}
