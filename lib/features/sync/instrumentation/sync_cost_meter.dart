import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart' show SyncStatus, SyncStatusUpdate;

/// The sync work [SyncCostMeter] times — ADR 0142's step 2, measuring before
/// anything moves off the UI isolate.
///
/// Every section but [apply] runs whatever the user is doing; [apply] is the
/// activity-gated inbound worker, timed as the comparison.
enum SyncCostSection {
  /// The Matrix SDK handling one `/sync` response: from its `processing`
  /// status to `finished` — room and state handling, decryption, the
  /// database transaction, device-key updates and the to-device queue. The
  /// response's JSON decode happens before `processing` and is not in it.
  sdkSync('sdk'),

  /// The deep copy each live response's events get before admission, run
  /// synchronously on the UI isolate.
  admissionCopy('copy'),

  /// Admitting one live response: decrypting its payloads and writing them
  /// to the inbound queue.
  admission('admit'),

  /// One live timeline event: descriptor indexing, ciphertext floors.
  liveEvent('live'),

  /// One catch-up walk of the room's history.
  bridgeWalk('bridge'),

  /// Applying one inbound queue entry — the gated work, for comparison.
  apply('apply'),

  /// One automatic backfill-request pass.
  backfillPass('backfill'),

  /// One sync recovery pass.
  recoveryPass('recovery');

  const SyncCostSection(this.label);

  /// Short name for the summary line.
  final String label;

  /// The span's name in a DevTools timeline.
  String get timelineName => 'sync.$name';
}

/// One timed run of a [SyncCostSection]; [end] it exactly once.
abstract interface class SyncCostSpan {
  void end();
}

/// Measures what sync costs the UI isolate, so moving it into an isolate
/// (ADR 0142) is decided on numbers.
///
/// Two outputs:
///
/// * **Timeline spans, always.** Every section is a `dart:developer`
///   timeline span, so a profile-mode DevTools capture on a phone shows the
///   sync work labelled beside the frames it overlapped. In release builds
///   these calls do nothing.
/// * **A summary in the sync log, while the `sync` log domain is on** (off by
///   default): per section the runs, total time and longest run, plus a
///   probe of the UI isolate's event loop — how long it was stalled, and how
///   much of that came while sync work was running. One line per report
///   interval (a minute), none when nothing ran.
///
/// Times are wall clock. For [SyncCostSection.admissionCopy], a synchronous
/// section, that is UI-isolate time; for the others, which await the
/// database and the network, it bounds it from above. The stall probe is
/// what measures blocking itself.
class SyncCostMeter {
  SyncCostMeter({
    required this._logger,
    this._reportEvery = const Duration(minutes: 1),
    this._probeEvery = const Duration(milliseconds: 100),
  });

  /// Timeline spans only — for the code paths a test builds without a
  /// meter of its own.
  SyncCostMeter.inert()
    : _logger = null,
      _reportEvery = Duration.zero,
      _probeEvery = Duration.zero;

  static const _subDomain = 'cost';

  /// A stall the probe counts on its own: long enough to drop several frames
  /// at 60 Hz.
  static const Duration noticeableStall = Duration(milliseconds: 50);

  final DomainLogger? _logger;
  final Duration _reportEvery;
  final Duration _probeEvery;

  final Map<SyncCostSection, _SectionTotal> _totals = {
    for (final section in SyncCostSection.values) section: _SectionTotal(),
  };
  int _active = 0;
  bool _syncSinceTick = false;
  final _StallTotal _stalls = _StallTotal();
  Timer? _reportTimer;
  Timer? _probeTimer;
  StreamSubscription<SyncStatusUpdate>? _sdkStatuses;
  SyncCostSpan? _sdkSync;
  DateTime? _lastTick;

  /// Whether this run's time is counted: the sync log domain is on.
  bool get _counting =>
      _logger?.enabledDomains.contains(LogDomain.sync) ?? false;

  /// Starts the minute report, which also starts and stops the stall probe
  /// as the sync log domain is switched.
  void start() {
    if (_logger == null || _reportTimer != null) return;
    _reportTimer = Timer.periodic(_reportEvery, (_) => _report());
    _syncProbe();
  }

  Future<void> dispose() async {
    _reportTimer?.cancel();
    _reportTimer = null;
    _probeTimer?.cancel();
    _probeTimer = null;
    await _sdkStatuses?.cancel();
    _sdkStatuses = null;
    _sdkSync?.end();
    _sdkSync = null;
  }

  /// Times [SyncCostSection.sdkSync] from the Matrix client's own status
  /// stream: a span opens at `processing` and closes at `finished` or
  /// `error`. A `processing` that arrives while one is open — a sync the
  /// SDK abandoned for a newer one — closes the old span first.
  void observeSdkSync(Stream<SyncStatusUpdate> statuses) {
    _sdkStatuses ??= statuses.listen((update) {
      switch (update.status) {
        case SyncStatus.processing:
          _sdkSync?.end();
          _sdkSync = begin(SyncCostSection.sdkSync);
        case SyncStatus.finished || SyncStatus.error:
          _sdkSync?.end();
          _sdkSync = null;
        case SyncStatus.waitingForResponse || SyncStatus.cleaningUp:
          break;
      }
    });
  }

  /// Starts a span the caller ends — for work whose start and end arrive as
  /// separate events.
  SyncCostSpan begin(SyncCostSection section) {
    final task = developer.TimelineTask()..start(section.timelineName);
    if (!_counting) return _TimelineSpan(task);
    _active++;
    _syncSinceTick = true;
    return _CountedSpan(this, section, task, clock.now());
  }

  /// Times [body], a section that runs synchronously.
  T measureSync<T>(SyncCostSection section, T Function() body) {
    final span = begin(section);
    try {
      return body();
    } finally {
      span.end();
    }
  }

  /// Times [body] from its start until its future completes.
  Future<T> measure<T>(SyncCostSection section, Future<T> Function() body) {
    final span = begin(section);
    return Future<T>.sync(body).whenComplete(span.end);
  }

  void _record(SyncCostSection section, Duration took) {
    _active = math.max(0, _active - 1);
    _totals[section]!.add(took);
  }

  /// Runs the stall probe exactly while time is being counted.
  void _syncProbe() {
    if (_counting && _probeTimer == null) {
      _lastTick = clock.now();
      _probeTimer = Timer.periodic(_probeEvery, (_) => _tick());
    } else if (!_counting && _probeTimer != null) {
      _probeTimer!.cancel();
      _probeTimer = null;
      _lastTick = null;
    }
  }

  /// A probe tick that comes late was held up by whatever ran on the UI
  /// isolate in between; the lateness is the stall.
  void _tick() {
    final now = clock.now();
    final last = _lastTick;
    _lastTick = now;
    if (last == null) return;
    final stall = now.difference(last) - _probeEvery;
    _stalls.add(stall, duringSync: _syncSinceTick || _active > 0);
    _syncSinceTick = _active > 0;
  }

  void _report() {
    final line = summary();
    if (line != null) {
      _logger!.log(LogDomain.sync, line, subDomain: _subDomain);
    }
    for (final total in _totals.values) {
      total.reset();
    }
    _stalls.reset();
    _syncProbe();
  }

  /// The line the next report writes, or null when nothing was counted.
  String? summary() {
    final ran = [
      for (final section in SyncCostSection.values)
        if (_totals[section]!.runs > 0) '${section.label} ${_totals[section]}',
    ];
    if (ran.isEmpty && _stalls.isEmpty) return null;
    return 'sync cost ${_reportEvery.inSeconds}s: '
        '${ran.isEmpty ? 'no sync work' : ran.join(' · ')} | $_stalls';
  }
}

class _TimelineSpan implements SyncCostSpan {
  _TimelineSpan(this._task);

  final developer.TimelineTask _task;

  @override
  void end() => _task.finish();
}

class _CountedSpan implements SyncCostSpan {
  _CountedSpan(this._meter, this._section, this._task, this._startedAt);

  final SyncCostMeter _meter;
  final SyncCostSection _section;
  final developer.TimelineTask _task;
  final DateTime _startedAt;
  bool _ended = false;

  @override
  void end() {
    if (_ended) return;
    _ended = true;
    _task.finish();
    _meter._record(_section, clock.now().difference(_startedAt));
  }
}

class _SectionTotal {
  int runs = 0;
  Duration total = Duration.zero;
  Duration longest = Duration.zero;

  void add(Duration took) {
    runs++;
    total += took;
    if (took > longest) longest = took;
  }

  void reset() {
    runs = 0;
    total = Duration.zero;
    longest = Duration.zero;
  }

  @override
  String toString() =>
      '${total.inMilliseconds}ms/$runs (max ${longest.inMilliseconds})';
}

class _StallTotal {
  Duration total = Duration.zero;
  Duration duringSync = Duration.zero;
  Duration worst = Duration.zero;
  int noticeable = 0;

  bool get isEmpty => total == Duration.zero;

  void add(Duration stall, {required bool duringSync}) {
    if (stall <= Duration.zero) return;
    total += stall;
    if (duringSync) this.duringSync += stall;
    if (stall > worst) worst = stall;
    if (stall >= SyncCostMeter.noticeableStall) noticeable++;
  }

  void reset() {
    total = Duration.zero;
    duringSync = Duration.zero;
    worst = Duration.zero;
    noticeable = 0;
  }

  @override
  String toString() =>
      'ui stall ${total.inMilliseconds}ms '
      '(${duringSync.inMilliseconds}ms with sync running), '
      'worst ${worst.inMilliseconds}ms, '
      '$noticeable over ${SyncCostMeter.noticeableStall.inMilliseconds}ms';
}
