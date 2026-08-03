import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:uuid/uuid.dart';

const onboardingSyncProtocolVersion = 1;
const onboardingSyncLease = Duration(hours: 1);
const onboardingSyncAcceptanceTimeout = Duration(minutes: 1);
const onboardingTerminalCounterChunkSize = 250;

const _inbound = 'inbound';
const _outbound = 'outbound';
const _awaitingBegin = 'awaitingBegin';
const _awaitingAcceptance = 'awaitingAcceptance';
const _active = 'active';
const _ending = 'ending';
const _completed = 'completed';
const _aborted = 'aborted';
const _cancelled = 'cancelled';

typedef OnboardingAcceptanceWaiter =
    Future<void> Function(Future<void> acceptance, Duration timeout);

class OnboardingSyncTarget {
  const OnboardingSyncTarget({required this.userId, required this.deviceId});

  final String userId;
  final String deviceId;
}

class OutboundOnboardingRound {
  const OutboundOnboardingRound({
    required this.roundId,
    required this.senderHostId,
    required this.target,
    required this.coverageUpperBounds,
  });

  final String roundId;
  final String senderHostId;
  final OnboardingSyncTarget target;
  final Map<String, int> coverageUpperBounds;
}

/// Coordinates the target-specific suppression lease used only by initial
/// device onboarding. Wire messages remain broadcast Matrix events, while
/// target checks ensure that only the named device mutates local state.
class OnboardingSyncService {
  OnboardingSyncService({
    required this._syncDatabase,
    required this._enqueueMessage,
    required this._getHostId,
    required this._getSnapshotCoverage,
    required this._getLocalUserId,
    required this._getLocalDeviceId,
    this._logging,
    Clock? serviceClock,
    String Function()? roundIdFactory,
    this._acceptanceTimeout = onboardingSyncAcceptanceTimeout,
    this._lease = onboardingSyncLease,
    this._terminalCounterChunkSize = onboardingTerminalCounterChunkSize,
    OnboardingAcceptanceWaiter? acceptanceWaiter,
  }) : _clock = serviceClock ?? const Clock(),
       _roundIdFactory = roundIdFactory ?? const Uuid().v4,
       _acceptanceWaiter =
           acceptanceWaiter ??
           ((acceptance, timeout) => acceptance.timeout(timeout)),
       assert(
         _terminalCounterChunkSize > 0,
         'terminalCounterChunkSize must be positive',
       );

  final SyncDatabase _syncDatabase;
  final Future<void> Function(SyncMessage message) _enqueueMessage;
  final Future<String?> Function() _getHostId;
  final Future<Map<String, int>> Function() _getSnapshotCoverage;
  final String? Function() _getLocalUserId;
  final String? Function() _getLocalDeviceId;
  final DomainLogger? _logging;
  final Clock _clock;
  final String Function() _roundIdFactory;
  final Duration _acceptanceTimeout;
  final Duration _lease;
  final int _terminalCounterChunkSize;
  final OnboardingAcceptanceWaiter _acceptanceWaiter;
  final Map<String, Completer<void>> _acceptances = {};

  /// Assigned by the composition root after the backfill requester exists.
  /// A successful end should immediately re-check any residual gaps; aborted
  /// rounds retain their original cooldown until lease expiry.
  void Function()? onInboundSuppressionEnded;

  /// Durably blocks automatic backfill before a newly provisioned receiver
  /// logs in and starts consuming timeline events. The sender's targeted Begin
  /// replaces this blanket gate with bounded per-host coverage. If no Begin
  /// arrives, the gate expires after [_lease]; manual repair remains available.
  Future<String> beginInboundPreflight({
    required String recipientUserId,
  }) async {
    if (recipientUserId.isEmpty) {
      throw ArgumentError.value(recipientUserId, 'recipientUserId');
    }
    final now = _clock.now();
    final roundId = _roundIdFactory();
    await _syncDatabase.upsertOnboardingSyncRound(
      OnboardingSyncRoundsCompanion.insert(
        roundId: roundId,
        direction: _inbound,
        state: _awaitingBegin,
        senderHostId: '',
        recipientUserId: recipientUserId,
        recipientDeviceId: '',
        coverageUpperBoundsJson: _encodeCoverage(const {}),
        startedAt: now,
        updatedAt: now,
        expiresAt: now.add(_lease),
      ),
    );
    _trace('preflight installed round=$roundId');
    return roundId;
  }

  /// Cancels a provisioning preflight when login or room setup fails. Errors
  /// from this method are intentionally surfaced so the caller can log them
  /// without hiding the original provisioning failure.
  Future<void> cancelInboundPreflight(String roundId) async {
    final row = await _syncDatabase.onboardingSyncRound(roundId);
    if (row == null ||
        row.direction != _inbound ||
        row.state != _awaitingBegin) {
      return;
    }
    await _syncDatabase.updateOnboardingSyncRound(
      roundId,
      OnboardingSyncRoundsCompanion(
        state: const Value(_cancelled),
        updatedAt: Value(_clock.now()),
      ),
    );
    _trace('preflight cancelled round=$roundId');
  }

  Future<bool> hasActiveInboundPreflight() {
    return _syncDatabase.hasActiveInboundOnboardingSyncPreflight(
      now: _clock.now(),
    );
  }

  Future<OutboundOnboardingRound> beginOutbound(
    OnboardingSyncTarget target,
  ) async {
    final senderHostId = await _getHostId();
    final senderUserId = _getLocalUserId();
    final senderDeviceId = _getLocalDeviceId();
    if (senderHostId == null ||
        senderUserId == null ||
        senderDeviceId == null) {
      throw StateError('Local sync identity is unavailable');
    }

    final now = _clock.now();
    final roundId = _roundIdFactory();
    final coverageUpperBounds = _normalizedCoverage(
      await _getSnapshotCoverage(),
    );
    final round = OutboundOnboardingRound(
      roundId: roundId,
      senderHostId: senderHostId,
      target: target,
      coverageUpperBounds: coverageUpperBounds,
    );
    final acceptance = Completer<void>();
    _acceptances[roundId] = acceptance;

    await _syncDatabase.upsertOnboardingSyncRound(
      OnboardingSyncRoundsCompanion.insert(
        roundId: roundId,
        direction: _outbound,
        state: _awaitingAcceptance,
        senderHostId: senderHostId,
        senderUserId: Value(senderUserId),
        senderDeviceId: Value(senderDeviceId),
        recipientUserId: target.userId,
        recipientDeviceId: target.deviceId,
        coverageUpperBoundsJson: _encodeCoverage(coverageUpperBounds),
        startedAt: now,
        updatedAt: now,
        expiresAt: now.add(_lease),
      ),
    );

    try {
      await _enqueueMessage(
        SyncMessage.onboardingSnapshotBegin(
          protocolVersion: onboardingSyncProtocolVersion,
          roundId: roundId,
          senderHostId: senderHostId,
          senderUserId: senderUserId,
          senderDeviceId: senderDeviceId,
          recipientUserId: target.userId,
          recipientDeviceId: target.deviceId,
          coverageUpperBounds: coverageUpperBounds,
          leaseSeconds: _lease.inSeconds,
        ),
      );
      await _acceptanceWaiter(acceptance.future, _acceptanceTimeout);
      await _enqueueTerminalCounters(round);
      _trace('accepted round=$roundId hosts=${coverageUpperBounds.length}');
      return round;
    } on Object catch (error, stackTrace) {
      try {
        await abortOutbound(round);
      } on Object catch (abortError, abortStackTrace) {
        _logging?.error(
          LogDomain.sync,
          abortError,
          stackTrace: abortStackTrace,
          subDomain: 'onboardingSync.abort',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      _acceptances.remove(roundId);
    }
  }

  Future<void> completeOutbound(OutboundOnboardingRound round) async {
    await _finishOutbound(round, OnboardingSyncEndReason.complete);
  }

  Future<void> abortOutbound(OutboundOnboardingRound round) async {
    await _finishOutbound(round, OnboardingSyncEndReason.aborted);
  }

  Future<void> _finishOutbound(
    OutboundOnboardingRound round,
    OnboardingSyncEndReason reason,
  ) async {
    final now = _clock.now();
    await _syncDatabase.updateOnboardingSyncRound(
      round.roundId,
      OnboardingSyncRoundsCompanion(
        state: const Value(_ending),
        updatedAt: Value(now),
      ),
    );
    await _enqueueMessage(
      SyncMessage.onboardingSnapshotEnd(
        protocolVersion: onboardingSyncProtocolVersion,
        roundId: round.roundId,
        senderHostId: round.senderHostId,
        recipientUserId: round.target.userId,
        recipientDeviceId: round.target.deviceId,
        reason: reason,
      ),
    );
  }

  Future<void> _enqueueTerminalCounters(OutboundOnboardingRound round) async {
    final upperBound = round.coverageUpperBounds[round.senderHostId];
    if (upperBound == null) return;
    final counters = await _syncDatabase.burnedSequenceCountersForHost(
      hostId: round.senderHostId,
      upperBound: upperBound,
    );
    for (final ranges in chunkCounterRanges(
      counters,
      maxCountersPerChunk: _terminalCounterChunkSize,
    )) {
      await _enqueueMessage(
        SyncMessage.onboardingTerminalCounters(
          protocolVersion: onboardingSyncProtocolVersion,
          roundId: round.roundId,
          senderHostId: round.senderHostId,
          recipientUserId: round.target.userId,
          recipientDeviceId: round.target.deviceId,
          ranges: ranges,
        ),
      );
    }
  }

  Future<void> handleMessage(SyncMessage message) async {
    switch (message) {
      case final SyncOnboardingSnapshotBegin begin:
        await _handleBegin(begin);
      case final SyncOnboardingSnapshotAccepted accepted:
        await _handleAccepted(accepted);
      case final SyncOnboardingTerminalCounters terminal:
        await _handleTerminalCounters(terminal);
      case final SyncOnboardingSnapshotEnd end:
        await _handleEnd(end);
      default:
        return;
    }
  }

  /// Finalizes an outbound round only after Matrix confirms the End event was
  /// sent. Sender echoes are filtered by the sent-event registry, so the
  /// durable sender lifecycle cannot depend on receiving its own event.
  Future<void> handleMessageSent(SyncMessage message) async {
    switch (message) {
      case final SyncOnboardingSnapshotEnd end:
        await _handleOutboundEndSent(end);
      case SyncOutboxBundle(:final children):
        for (final child in children) {
          await handleMessageSent(child);
        }
      default:
        return;
    }
  }

  Future<void> _handleBegin(SyncOnboardingSnapshotBegin message) async {
    if (!_isCurrentProtocol(message.protocolVersion) ||
        !_isLocalTarget(message.recipientUserId, message.recipientDeviceId)) {
      return;
    }
    final recipientHostId = await _getHostId();
    if (recipientHostId == null) return;

    final now = _clock.now();
    final existing = await _syncDatabase.onboardingSyncRound(message.roundId);
    if (existing != null) {
      final isMatchingActiveRound =
          existing.direction == _inbound &&
          existing.state == _active &&
          existing.senderHostId == message.senderHostId &&
          existing.recipientUserId == message.recipientUserId &&
          existing.recipientDeviceId == message.recipientDeviceId &&
          existing.expiresAt.isAfter(now);
      if (isMatchingActiveRound) {
        await _syncDatabase.adoptInboundOnboardingSyncPreflights(
          recipientUserId: message.recipientUserId,
          now: now,
        );
        await _enqueueAccepted(message, recipientHostId);
      }
      // A duplicate begin never renews, reopens, or changes a durable round.
      // A genuinely new onboarding attempt carries a new round id.
      return;
    }
    final lease = _boundedWireDuration(message.leaseSeconds, _lease);
    await _syncDatabase.installInboundOnboardingSyncRound(
      round: OnboardingSyncRoundsCompanion.insert(
        roundId: message.roundId,
        direction: _inbound,
        state: _active,
        senderHostId: message.senderHostId,
        senderUserId: Value(message.senderUserId),
        senderDeviceId: Value(message.senderDeviceId),
        recipientHostId: Value(recipientHostId),
        recipientUserId: message.recipientUserId,
        recipientDeviceId: message.recipientDeviceId,
        coverageUpperBoundsJson: _encodeCoverage(
          _normalizedCoverage(message.coverageUpperBounds),
        ),
        startedAt: now,
        updatedAt: now,
        expiresAt: now.add(lease),
      ),
      recipientUserId: message.recipientUserId,
      now: now,
    );
    await _enqueueAccepted(message, recipientHostId);
    _trace(
      'installed round=${message.roundId} '
      'hosts=${message.coverageUpperBounds.length}',
    );
  }

  Future<void> _enqueueAccepted(
    SyncOnboardingSnapshotBegin message,
    String recipientHostId,
  ) {
    return _enqueueMessage(
      SyncMessage.onboardingSnapshotAccepted(
        protocolVersion: onboardingSyncProtocolVersion,
        roundId: message.roundId,
        senderHostId: message.senderHostId,
        senderUserId: message.senderUserId,
        senderDeviceId: message.senderDeviceId,
        recipientHostId: recipientHostId,
        recipientDeviceId: message.recipientDeviceId,
      ),
    );
  }

  Future<void> _handleAccepted(
    SyncOnboardingSnapshotAccepted message,
  ) async {
    if (!_isCurrentProtocol(message.protocolVersion) ||
        !_isLocalTarget(message.senderUserId, message.senderDeviceId)) {
      return;
    }
    final row = await _syncDatabase.onboardingSyncRound(message.roundId);
    if (row == null ||
        row.direction != _outbound ||
        row.senderHostId != message.senderHostId ||
        row.recipientDeviceId != message.recipientDeviceId ||
        row.state != _awaitingAcceptance) {
      return;
    }
    final now = _clock.now();
    await _syncDatabase.updateOnboardingSyncRound(
      message.roundId,
      OnboardingSyncRoundsCompanion(
        state: const Value(_active),
        recipientHostId: Value(message.recipientHostId),
        updatedAt: Value(now),
      ),
    );
    final acceptance = _acceptances[message.roundId];
    if (acceptance != null && !acceptance.isCompleted) acceptance.complete();
  }

  Future<void> _handleTerminalCounters(
    SyncOnboardingTerminalCounters message,
  ) async {
    if (!_isCurrentProtocol(message.protocolVersion) ||
        !_isLocalTarget(message.recipientUserId, message.recipientDeviceId)) {
      return;
    }
    final row = await _activeInboundRound(
      message.roundId,
      message.senderHostId,
    );
    if (row == null) return;
    final upperBound = _decodeCoverage(
      row.coverageUpperBoundsJson,
    )[message.senderHostId];
    if (upperBound == null) return;
    final counters = expandCounterRanges(
      message.ranges,
      upperBound: upperBound,
    );
    await _syncDatabase.applyAuthoritativeBurnedCounters(
      hostId: message.senderHostId,
      counters: counters,
      now: _clock.now(),
    );
  }

  Future<void> _handleEnd(SyncOnboardingSnapshotEnd message) async {
    if (!_isCurrentProtocol(message.protocolVersion)) {
      return;
    }
    if (!_isLocalTarget(message.recipientUserId, message.recipientDeviceId)) {
      return;
    }
    final row = await _syncDatabase.onboardingSyncRound(message.roundId);
    if (row == null ||
        row.direction != _inbound ||
        row.senderHostId != message.senderHostId ||
        row.state != _active) {
      return;
    }
    final now = _clock.now();
    await _syncDatabase.updateOnboardingSyncRound(
      message.roundId,
      OnboardingSyncRoundsCompanion(
        state: Value(
          message.reason == OnboardingSyncEndReason.complete
              ? _completed
              : _aborted,
        ),
        updatedAt: Value(now),
      ),
    );
    if (message.reason == OnboardingSyncEndReason.complete) {
      onInboundSuppressionEnded?.call();
    }
  }

  Future<void> _handleOutboundEndSent(
    SyncOnboardingSnapshotEnd message,
  ) async {
    final localHostId = await _getHostId();
    if (localHostId == null || localHostId != message.senderHostId) return;
    final row = await _syncDatabase.onboardingSyncRound(message.roundId);
    if (row == null ||
        row.direction != _outbound ||
        row.state != _ending ||
        row.senderHostId != message.senderHostId ||
        row.recipientUserId != message.recipientUserId ||
        row.recipientDeviceId != message.recipientDeviceId) {
      return;
    }
    final now = _clock.now();
    await _syncDatabase.updateOnboardingSyncRound(
      message.roundId,
      OnboardingSyncRoundsCompanion(
        state: Value(
          message.reason == OnboardingSyncEndReason.complete
              ? _completed
              : _aborted,
        ),
        updatedAt: Value(now),
      ),
    );
  }

  Future<OnboardingSyncRoundItem?> _activeInboundRound(
    String roundId,
    String senderHostId,
  ) async {
    final row = await _syncDatabase.onboardingSyncRound(roundId);
    final now = _clock.now();
    if (row == null ||
        row.direction != _inbound ||
        row.state != _active ||
        row.senderHostId != senderHostId ||
        !row.expiresAt.isAfter(now)) {
      return null;
    }
    return row;
  }

  Future<Map<String, int>> activeInboundCoverage() async {
    final rounds = await _syncDatabase.activeInboundOnboardingSyncRounds(
      now: _clock.now(),
    );
    return _mergedCoverage(rounds);
  }

  Future<Map<String, int>> activeOutboundCoverageForRequester(
    String requesterHostId,
  ) async {
    final rounds = await _syncDatabase.activeOutboundOnboardingSyncRounds(
      recipientHostId: requesterHostId,
      now: _clock.now(),
    );
    return _mergedCoverage(rounds);
  }

  Map<String, int> _mergedCoverage(Iterable<OnboardingSyncRoundItem> rounds) {
    final coverage = <String, int>{};
    for (final round in rounds) {
      for (final entry in _decodeCoverage(
        round.coverageUpperBoundsJson,
      ).entries) {
        final previous = coverage[entry.key];
        if (previous == null || entry.value > previous) {
          coverage[entry.key] = entry.value;
        }
      }
    }
    return coverage;
  }

  bool _isCurrentProtocol(int version) =>
      version == onboardingSyncProtocolVersion;

  bool _isLocalTarget(String userId, String deviceId) =>
      userId == _getLocalUserId() && deviceId == _getLocalDeviceId();

  Duration _boundedWireDuration(int seconds, Duration maximum) {
    if (seconds <= 0) return Duration.zero;
    final requested = Duration(seconds: seconds);
    return requested < maximum ? requested : maximum;
  }

  Map<String, int> _normalizedCoverage(Map<String, int> coverage) => {
    for (final entry in coverage.entries)
      if (entry.key.isNotEmpty && entry.value >= 0) entry.key: entry.value,
  };

  String _encodeCoverage(Map<String, int> coverage) {
    final sorted = coverage.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return jsonEncode({for (final entry in sorted) entry.key: entry.value});
  }

  Map<String, int> _decodeCoverage(String encoded) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return const {};
      return _normalizedCoverage({
        for (final entry in decoded.entries)
          if (entry.value is int) entry.key: entry.value as int,
      });
    } on FormatException {
      return const {};
    }
  }

  void _trace(String message) {
    _logging?.log(
      LogDomain.sync,
      message,
      subDomain: 'onboardingSync',
    );
  }
}

/// Compresses sorted, unique counters into inclusive ranges, while bounding
/// each returned event by the number of represented counters.
List<List<SyncCounterRange>> chunkCounterRanges(
  Iterable<int> counters, {
  int maxCountersPerChunk = onboardingTerminalCounterChunkSize,
}) {
  if (maxCountersPerChunk <= 0) {
    throw ArgumentError.value(maxCountersPerChunk, 'maxCountersPerChunk');
  }
  final sorted = counters.where((counter) => counter >= 0).toSet().toList()
    ..sort();
  final chunks = <List<SyncCounterRange>>[];
  for (var offset = 0; offset < sorted.length; offset += maxCountersPerChunk) {
    final end = (offset + maxCountersPerChunk).clamp(0, sorted.length);
    final slice = sorted.sublist(offset, end);
    final ranges = <SyncCounterRange>[];
    var rangeStart = slice.first;
    var rangeEnd = rangeStart;
    for (final counter in slice.skip(1)) {
      if (counter == rangeEnd + 1) {
        rangeEnd = counter;
      } else {
        ranges.add(SyncCounterRange(start: rangeStart, end: rangeEnd));
        rangeStart = counter;
        rangeEnd = counter;
      }
    }
    ranges.add(SyncCounterRange(start: rangeStart, end: rangeEnd));
    chunks.add(ranges);
  }
  return chunks;
}

List<int> expandCounterRanges(
  Iterable<SyncCounterRange> ranges, {
  required int upperBound,
  int maxCounters = onboardingTerminalCounterChunkSize,
}) {
  if (maxCounters <= 0) {
    throw ArgumentError.value(maxCounters, 'maxCounters');
  }
  final counters = <int>{};
  for (final range in ranges) {
    if (range.start < 0 || range.end < range.start) continue;
    if (range.start > upperBound) continue;
    final boundedEnd = range.end.clamp(range.start, upperBound);
    for (var counter = range.start; counter <= boundedEnd; counter++) {
      counters.add(counter);
      if (counters.length >= maxCounters) {
        return counters.toList()..sort();
      }
    }
  }
  return counters.toList()..sort();
}
