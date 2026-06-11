import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Persists the end time of a timer that is being stopped because a new
/// one is starting. Implemented by the persistence layer and injected so
/// this low-level service stays free of a direct database dependency (and
/// so unit tests can observe the call without a real DB).
typedef PersistTimerStop = Future<void> Function(JournalEntity entry);

class TimeService {
  TimeService([this._persistTimerStop]) {
    _controller = StreamController<JournalEntity?>.broadcast();
  }

  /// Persists the outgoing entry's end time when a running session is
  /// implicitly stopped by [start]. Null when the service is constructed
  /// without persistence (bare unit tests) — finalization is then skipped.
  final PersistTimerStop? _persistTimerStop;

  late final StreamController<JournalEntity?> _controller;
  JournalEntity? _current;
  JournalEntity? linkedFrom;
  StreamSubscription<int>? _periodicSubscription;

  Future<void> start(JournalEntity journalEntity, JournalEntity? linked) async {
    final outgoing = _current;
    if (outgoing != null) {
      // A new session is replacing one that is still running. Persist the
      // outgoing entry's real stop time before discarding it; otherwise it
      // keeps the stale `dateTo` it was created with (≈ its start time) and
      // the whole elapsed span is lost. Only the end time is written, so
      // the entry's existing text is preserved. A failure here must never
      // block the new timer from starting.
      await _finalizeOutgoing(outgoing);
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
            meta: _current!.meta.copyWith(dateTo: DateTime.now()),
          ),
        );
      }
    });
  }

  /// Writes the outgoing timer's stop time via the injected persistence
  /// callback, swallowing (but logging) any failure so the replacing timer
  /// always starts.
  Future<void> _finalizeOutgoing(JournalEntity entry) async {
    final persist = _persistTimerStop;
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
        subDomain: 'finalizeRunningTimer',
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
