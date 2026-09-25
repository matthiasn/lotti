// ignore_for_file: sort_constructors_first

import 'dart:async';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_collapse.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';

/// Transport seam for the outbox: turns a queued [SyncMessage] into an actual
/// send (over Matrix in production). Returns `true` on confirmed delivery and
/// `false` on a recoverable failure, which the [OutboxProcessor] treats as a
/// retry signal. Implementations must not throw for ordinary send failures.
abstract class OutboxMessageSender {
  Future<bool> send(SyncMessage message);
}

/// Outcome of a single [OutboxProcessor.processQueue] pass: either [none]
/// (nothing left to do) or a [OutboxProcessingResult.schedule] carrying the
/// delay before the next pass should run.
class OutboxProcessingResult {
  const OutboxProcessingResult._({this.nextDelay});

  final Duration? nextDelay;

  static const OutboxProcessingResult none = OutboxProcessingResult._();

  factory OutboxProcessingResult.schedule(Duration delay) =>
      OutboxProcessingResult._(nextDelay: delay);

  bool get shouldSchedule => nextDelay != null;
}

/// Drains one claimed batch of outbox rows per [processQueue] call and reports
/// back, via [OutboxProcessingResult], whether another pass should be scheduled
/// and after how long.
///
/// This is the per-pass engine behind the outbox runner: it claims rows
/// atomically, collapses each entity's rows into one send of its newest
/// version (ADR 0086, see `outbox_collapse.dart`), sends through the injected
/// [OutboxMessageSender] under a [sendTimeout], and translates the outcome
/// into row state via [OutboxRepository] — every collapsed row marked sent on
/// success, `markRetry` (which flips to `error` once `retries` crosses the
/// repository's `maxRetries`) on failure. A single send goes out verbatim;
/// several are packed into a `SyncMessage.outboxBundle` so consecutive text
/// rows ride one Matrix event (media attachments always travel alone). [maxRetriesForDiagnostics] only controls log verbosity and the
/// fast-path "cap reached" scheduling, not the actual retry ceiling.
class OutboxProcessor {
  OutboxProcessor({
    required this._repository,
    required this._messageSender,
    required this._loggingService,
    Duration? retryDelayOverride,
    Duration? errorDelayOverride,
    int? maxRetriesOverride,
    Duration? sendTimeoutOverride,
    Duration? claimLeaseOverride,
    this._domainLogger,
    int? bundleMaxSizeOverride,
  }) : bundleMaxSize = bundleMaxSizeOverride ?? SyncTuning.outboxBundleMaxSize,
       retryDelay = retryDelayOverride ?? SyncTuning.outboxRetryDelay,
       errorDelay = errorDelayOverride ?? SyncTuning.outboxErrorDelay,
       maxRetriesForDiagnostics =
           maxRetriesOverride ?? SyncTuning.outboxMaxRetriesDiagnostics,
       sendTimeout = sendTimeoutOverride ?? SyncTuning.outboxSendTimeout,
       claimLease = claimLeaseOverride ?? SyncTuning.outboxClaimLease;

  final OutboxRepository _repository;
  final OutboxMessageSender _messageSender;
  final DomainLogger _loggingService;
  final DomainLogger? _domainLogger;
  final int bundleMaxSize;

  /// The ids of the rows this pass claimed from the queue, as opposed to the
  /// rows a collapse folded in. Retry scheduling and diagnostics follow the
  /// claimed rows: a folded-in `error` row is already past the retry cap.
  Set<int> _claimedIds = const {};
  final Duration retryDelay;
  final Duration errorDelay;
  final int maxRetriesForDiagnostics;
  final Duration sendTimeout;
  final Duration claimLease;

  void _syncLog(String message, {String? subDomain}) {
    _domainLogger?.log(LogDomain.sync, message, subDomain: subDomain);
  }

  // Diagnostics for repeated failures on the same head-of-queue subject.
  String? _lastFailedSubject;
  int _lastFailedRepeats = 0;

  /// Claims and processes the next batch (single send or bundle), returning
  /// [OutboxProcessingResult.none] when the queue is empty or fully drained, or
  /// [OutboxProcessingResult.schedule] with the delay before the next pass
  /// (`Duration.zero` to drain immediately, [retryDelay]/[errorDelay] to back
  /// off after a failure). Never throws: send failures and post-send exceptions
  /// are caught and converted into retry scheduling.
  Future<OutboxProcessingResult> processQueue() async {
    // Atomic claim (pending → sending) of the next contiguous batch. Media
    // attachments always travel alone; text rows pack up to [bundleMaxSize]
    // consecutive rows stopping before the next attachment.
    final batch = await _repository.claimNextBatch(
      maxSize: bundleMaxSize,
      leaseDuration: claimLease,
    );
    if (batch.isEmpty) {
      return OutboxProcessingResult.none;
    }
    _claimedIds = {for (final row in batch) row.id};

    final List<_OutboxSend> sends;
    try {
      sends = await _collapse(batch);
    } catch (error, stackTrace) {
      // An undecodable row: the claimed batch goes back to the queue with its
      // retry count raised, exactly as a failed send does.
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendNext.collapse',
      );
      await _markRetry(batch);
      return _retryResult(
        batch,
        delay: errorDelay,
        subject: batch.first.subject,
      );
    }
    if (sends.length == 1) {
      return _processSingle(sends.single);
    }
    return _processBundle(sends);
  }

  /// Turns the claimed [batch] into sends, collapsing each entity's rows.
  ///
  /// For every entity with a claimed row, the entity's other pending and
  /// failed rows are read and the newest version chosen, by clock or, for a
  /// clockless payload, by enqueue order. Every row that version supersedes is
  /// claimed and rides the send: the newest payload, covering their counters,
  /// with the attachment if any of them owed one. A bundle carries JSON only,
  /// so a bundled send does not fold in rows that owe an attachment; those
  /// go out alone later.
  Future<List<_OutboxSend>> _collapse(List<OutboxItem> batch) async {
    final allowMedia = batch.length == 1;
    final claimedIds = {for (final row in batch) row.id};
    final groups = <String, List<CollapseCandidate>>{};
    final slots = <Object>[];
    for (final row in batch) {
      final candidate = CollapseCandidate.decode(row);
      final key = collapseKeyOf(candidate);
      if (key == null) {
        slots.add(_OutboxSend(candidate.message, [row]));
        continue;
      }
      final group = groups[key];
      if (group == null) {
        groups[key] = [candidate];
        slots.add(key);
      } else {
        group.add(candidate);
      }
    }

    final sends = <_OutboxSend>[];
    for (final slot in slots) {
      if (slot is _OutboxSend) {
        sends.add(slot);
      } else {
        final key = slot as String;
        sends.addAll(
          await _collapseEntity(
            key,
            groups[key]!,
            claimedIds: claimedIds,
            allowMedia: allowMedia,
          ),
        );
      }
    }
    return sends;
  }

  Future<List<_OutboxSend>> _collapseEntity(
    String key,
    List<CollapseCandidate> claimed, {
    required Set<int> claimedIds,
    required bool allowMedia,
  }) async {
    // Rows are stored under the bare entry id, which other payload families
    // may share: only rows of the same family (the same collapse key) fold.
    final others = <CollapseCandidate>[];
    for (final row in await _repository.collapsibleRows(
      claimed.first.row.outboxEntryId!,
      excludeIds: claimedIds,
    )) {
      // A row outside the batch is only a fold-in candidate. One that cannot
      // be decoded is left alone: it fails on its own when it is claimed, and
      // must not block the sends of the rows that were.
      final CollapseCandidate candidate;
      try {
        candidate = CollapseCandidate.decode(row);
      } catch (error, stackTrace) {
        _loggingService.error(
          LogDomain.sync,
          error,
          stackTrace: stackTrace,
          subDomain: 'sendNext.collapse.skip',
        );
        continue;
      }
      if (collapseKeyOf(candidate) == key &&
          (allowMedia || !candidate.needsMedia)) {
        others.add(candidate);
      }
    }
    final readNewest = newestOf([...claimed, ...others]);
    final wanted = [
      for (final c in others)
        if (supersededBy(c, readNewest)) c.row,
    ];
    final taken = wanted.isEmpty
        ? const <int>{}
        : {for (final row in await _repository.claimRows(wanted)) row.id};

    final members = [
      ...claimed,
      ...others.where((c) => taken.contains(c.row.id)),
    ];
    final newest = newestOf(members);
    final collapsed = members.where((c) => supersededBy(c, newest)).toList()
      ..sort((a, b) => a.row.id.compareTo(b.row.id));
    return [
      _OutboxSend(
        collapsedMessage(newest, collapsed),
        [for (final c in collapsed) c.row],
      ),
      for (final c in members)
        if (!supersededBy(c, newest)) _OutboxSend(c.message, [c.row]),
    ];
  }

  Future<void> _markSent(List<OutboxItem> rows) => rows.length == 1
      ? _repository.markSent(rows.single)
      : _repository.markSentBatch(rows);

  Future<void> _markRetry(List<OutboxItem> rows) => rows.length == 1
      ? _repository.markRetry(rows.single)
      : _repository.markRetryBatch(rows);

  /// The rows of [rows] this pass claimed, or all of them when none was
  /// (a collapse only ever adds to claimed rows).
  List<OutboxItem> _claimedOf(List<OutboxItem> rows) {
    final claimed = rows.where((row) => _claimedIds.contains(row.id)).toList();
    return claimed.isEmpty ? rows : claimed;
  }

  /// Scheduling after a failed attempt over [rows]: straight on when a
  /// claimed row just reached the retry cap (the repository flipped it to
  /// error), else after [delay]. Folded-in `error` rows are past the cap
  /// already and do not count, or one of them would turn every retry of the
  /// newer rows into a zero-delay loop. [bundleSize] is set for a bundle,
  /// whose log line names its head subject and size.
  OutboxProcessingResult _retryResult(
    List<OutboxItem> rows, {
    required Duration delay,
    required String? subject,
    int? bundleSize,
  }) {
    final claimed = _claimedOf(rows);
    final capReached = claimed.any(
      (row) => row.retries + 1 >= maxRetriesForDiagnostics,
    );
    if (capReached) {
      try {
        _loggingService.log(
          LogDomain.sync,
          bundleSize == null
              ? 'retryCapReached subject=$subject '
                    'attempts=${claimed.first.retries + 1} '
                    'status=error → skip/head-advance'
              : 'retryCapReached headSubject=$subject size=$bundleSize '
                    'attempts=${claimed.first.retries + 1} '
                    'status=error → skip/head-advance',
          subDomain: 'retry.cap',
        );
      } catch (_) {}
      return OutboxProcessingResult.schedule(Duration.zero);
    }
    return OutboxProcessingResult.schedule(delay);
  }

  void _trackFailure(String? subject) {
    if (_lastFailedSubject == subject) {
      _lastFailedRepeats++;
    } else {
      _lastFailedSubject = subject;
      _lastFailedRepeats = 1;
    }
  }

  Future<OutboxProcessingResult> _processSingle(_OutboxSend send) async {
    final rows = send.rows;
    final head = _claimedOf(rows).first;
    // Tracks whether the rows have already been committed as sent so the
    // exception handler below does not revive them. Without this, a throw
    // from the post-send observability path (hasMorePending, logging) would
    // run `markRetry` on rows just acknowledged — re-sending the same Matrix
    // event on the next pass.
    var markedSent = false;

    try {
      final sendStart = DateTime.now();
      var timedOut = false;
      final success = await _messageSender
          .send(send.message)
          .timeout(
            sendTimeout,
            onTimeout: () {
              timedOut = true;
              return false;
            },
          );

      if (!success) {
        final nextAttempts = head.retries + 1;
        await _markRetry(rows);
        _syncLog(
          'sendFail subject=${head.subject} attempts=$nextAttempts timedOut=$timedOut',
          subDomain: 'outbox.retry',
        );
        _trackFailure(head.subject);
        try {
          _loggingService.log(
            LogDomain.sync,
            'sendFailed subject=${head.subject} attempts=$nextAttempts repeats=$_lastFailedRepeats backoffMs=${retryDelay.inMilliseconds} timedOut=$timedOut',
            subDomain: 'retry',
          );
        } catch (_) {}
        return _retryResult(rows, delay: retryDelay, subject: head.subject);
      }

      await _markSent(rows);
      markedSent = true;
      final elapsedMs = DateTime.now().difference(sendStart).inMilliseconds;
      final hasMore = await _repository.hasMorePending();
      _loggingService.log(
        LogDomain.sync,
        'sent type=${send.message.runtimeType} subject=${head.subject} '
        'retries=${head.retries} ms=$elapsedMs '
        'rows=${rows.length} pending=${hasMore ? 2 : 1}',
        subDomain: 'outbox.send',
      );
      // Reset repeat tracker on success for this subject.
      if (_lastFailedSubject == head.subject) {
        _lastFailedSubject = null;
        _lastFailedRepeats = 0;
      }

      return hasMore
          ? OutboxProcessingResult.schedule(Duration.zero)
          : OutboxProcessingResult.none;
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendNext',
      );
      // If the rows are already sent, the exception happened in the post-send
      // observability path. Swallow it: markRetry would revive sent rows and
      // cause duplicate delivery.
      if (markedSent) {
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      final nextAttempts = head.retries + 1;
      await _markRetry(rows);
      _trackFailure(head.subject);
      try {
        _loggingService.log(
          LogDomain.sync,
          'sendException subject=${head.subject} attempts=$nextAttempts repeats=$_lastFailedRepeats backoffMs=${errorDelay.inMilliseconds}',
          subDomain: 'retry',
        );
      } catch (_) {}
      return _retryResult(rows, delay: errorDelay, subject: head.subject);
    }
  }

  Future<OutboxProcessingResult> _processBundle(
    List<_OutboxSend> sends,
  ) async {
    // Head subject anchors all head-of-queue diagnostics. The bundle is one
    // logical send attempt; per-row retries++/error-cap accounting still
    // happens row-by-row inside [OutboxRepository.markRetryBatch], so a
    // rotten head row eventually flips to error and the next drain claims a
    // smaller bundle without it.
    final rows = [for (final send in sends) ...send.rows];
    final head = _claimedOf(rows).first;
    final headSubject = head.subject;
    final bundleSize = sends.length;

    var markedSent = false;
    try {
      final bundle = SyncMessage.outboxBundle(
        children: [for (final send in sends) send.message],
      );

      final sendStart = DateTime.now();
      var timedOut = false;
      final success = await _messageSender
          .send(bundle)
          .timeout(
            sendTimeout,
            onTimeout: () {
              timedOut = true;
              return false;
            },
          );

      if (!success) {
        final nextAttempts = head.retries + 1;
        await _repository.markRetryBatch(rows);
        _syncLog(
          'bundleSendFail size=$bundleSize headSubject=$headSubject '
          'attempts=$nextAttempts timedOut=$timedOut',
          subDomain: 'outbox.retry',
        );
        _trackFailure(headSubject);
        try {
          _loggingService.log(
            LogDomain.sync,
            'bundleSendFailed size=$bundleSize headSubject=$headSubject '
            'attempts=$nextAttempts repeats=$_lastFailedRepeats '
            'backoffMs=${retryDelay.inMilliseconds} timedOut=$timedOut',
            subDomain: 'retry',
          );
        } catch (_) {}
        return _retryResult(
          rows,
          delay: retryDelay,
          subject: headSubject,
          bundleSize: bundleSize,
        );
      }

      await _repository.markSentBatch(rows);
      markedSent = true;
      final elapsedMs = DateTime.now().difference(sendStart).inMilliseconds;
      final hasMore = await _repository.hasMorePending();
      _loggingService.log(
        LogDomain.sync,
        'bundleSent size=$bundleSize rows=${rows.length} '
        'headSubject=$headSubject ms=$elapsedMs pending=${hasMore ? 2 : 1}',
        subDomain: 'outbox.send',
      );
      if (_lastFailedSubject == headSubject) {
        _lastFailedSubject = null;
        _lastFailedRepeats = 0;
      }

      return hasMore
          ? OutboxProcessingResult.schedule(Duration.zero)
          : OutboxProcessingResult.none;
    } catch (error, stackTrace) {
      _loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'sendNext.bundle',
      );
      if (markedSent) {
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      final nextAttempts = head.retries + 1;
      await _repository.markRetryBatch(rows);
      _trackFailure(headSubject);
      try {
        _loggingService.log(
          LogDomain.sync,
          'bundleSendException size=$bundleSize headSubject=$headSubject '
          'attempts=$nextAttempts repeats=$_lastFailedRepeats '
          'backoffMs=${errorDelay.inMilliseconds}',
          subDomain: 'retry',
        );
      } catch (_) {}
      return _retryResult(
        rows,
        delay: errorDelay,
        subject: headSubject,
        bundleSize: bundleSize,
      );
    }
  }
}

/// One Matrix send: the message, and every row it settles.
class _OutboxSend {
  _OutboxSend(this.message, this.rows);

  final SyncMessage message;
  final List<OutboxItem> rows;
}
