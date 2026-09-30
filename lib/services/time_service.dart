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

  /// Persists the outgoing entry's end time when a running session is
  /// implicitly stopped by [start]. Null when the service is constructed
  /// without persistence (bare unit tests) — finalization is then skipped.
  final PersistRunningTimer? _persistTimerStop;

  /// Persists the running entry every [_autosaveInterval] while it runs.
  /// Null when the service is constructed without persistence — no autosave
  /// cadence is scheduled then.
  final PersistRunningTimer? _autosave;
  final Duration _autosaveInterval;

  late final StreamController<JournalEntity?> _controller;
  JournalEntity? _current;
  JournalEntity? linkedFrom;
  StreamSubscription<int>? _periodicSubscription;
  Timer? _autosaveTimer;

  Future<void> start(JournalEntity journalEntity, JournalEntity? linked) async {
    final outgoing = _current;
    if (outgoing != null) {
      // A new session is replacing one that is still running. Persist the
      // outgoing entry's real stop time before discarding it; otherwise it
      // keeps the stale `dateTo` it was created with (≈ its start time) and
      // the whole elapsed span is lost. The write is built on the stored
      // entry, so its text is kept — or, when the user typed a draft, that
      // draft is stored with it. A failure here must never block the new
      // timer from starting.
      await _persistSafely(
        _persistTimerStop,
        outgoing,
        subDomain: 'finalizeRunningTimer',
      );
      await stop();
    }

    _current = journalEntity;
    linkedFrom = linked;
    const interval = Duration(seconds: 1);

    int callback(int value) {
      return value;
    }

    _periodicSubscription = Stream<int>.periodic(interval, callback).listen((
      i,
    ) {
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

  Future<void> stop() async {
    if (_current != null) {
      _current = null;
      linkedFrom = null;
      _autosaveTimer?.cancel();
      _autosaveTimer = null;
      _controller.add(null);
      await _periodicSubscription?.cancel();
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
