import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';

/// Deterministic planner arbitration for attention requests.
///
/// This layer deliberately performs no writes. It turns a projected set of
/// pending [AttentionRequestEntity] events into ranked award proposals that can
/// be persisted and routed through the existing ChangeSet gate.
class AttentionPlannerArbitrator {
  /// Creates a deterministic arbitrator.
  const AttentionPlannerArbitrator();

  /// Rank and schedule eligible [requests] against [plan].
  AttentionArbitrationResult arbitrate({
    required String plannerAgentId,
    required DayPlanEntity plan,
    required List<AttentionRequestEntity> requests,
    required DateTime createdAt,
  }) {
    final ranked = _rank(requests, plan);
    final scheduled = _scheduledBlocks(plan);
    var usedMinutes = _scheduledMinutes(scheduled);
    final awards = <AttentionAwardProposal>[];
    final skipped = <AttentionSkippedRequest>[];

    for (final ranking in ranked) {
      final request = ranking.request;
      final ineligibleReason = _ineligibleReason(request, plan);
      if (ineligibleReason != null) {
        skipped.add(
          AttentionSkippedRequest(
            request: request,
            reason: ineligibleReason,
            utilityScore: ranking.utilityScore,
          ),
        );
        continue;
      }

      final remaining = plan.capacityMinutes - usedMinutes;
      if (request.requestedMinutes > remaining) {
        skipped.add(
          AttentionSkippedRequest(
            request: request,
            reason: AttentionSkipReason.capacity,
            utilityScore: ranking.utilityScore,
          ),
        );
        continue;
      }

      final slot = _firstAvailableSlot(
        request: request,
        plan: plan,
        scheduled: scheduled,
      );
      if (slot == null) {
        skipped.add(
          AttentionSkippedRequest(
            request: request,
            reason: AttentionSkipReason.noSlot,
            utilityScore: ranking.utilityScore,
          ),
        );
        continue;
      }

      final rank = awards.length + 1;
      final blockId = _stableBlockId(plan.dayId, request.id);
      final award =
          AgentDomainEntity.attentionAward(
                id: _stableAwardId(
                  dayId: plan.dayId,
                  requestId: request.id,
                  start: slot.start,
                  end: slot.end,
                ),
                agentId: plannerAgentId,
                requestId: request.id,
                dayId: plan.dayId,
                planId: plan.id,
                blockId: blockId,
                categoryId: request.categoryId,
                title: request.title,
                startTime: slot.start,
                endTime: slot.end,
                rank: rank,
                utilityScore: ranking.utilityScore,
                createdAt: createdAt,
                vectorClock: null,
                taskId: request.kind == AttentionRequestKind.task
                    ? request.targetId
                    : null,
                rationale: _awardRationale(request, ranking.utilityScore),
              )
              as AttentionAwardEntity;
      final block = PlannedBlock(
        id: blockId,
        categoryId: request.categoryId,
        startTime: slot.start,
        endTime: slot.end,
        title: request.title,
        taskId: award.taskId,
        reason: award.rationale,
      );

      awards.add(
        AttentionAwardProposal(
          request: request,
          award: award,
          plannedBlock: block,
        ),
      );
      scheduled
        ..add(block)
        ..sort(_compareBlocks);
      usedMinutes += request.requestedMinutes;
    }

    return AttentionArbitrationResult(
      rankedRequests: ranked,
      awards: awards,
      skipped: skipped,
    );
  }

  static List<AttentionRequestRanking> _rank(
    List<AttentionRequestEntity> requests,
    DayPlanEntity plan,
  ) {
    final ranked =
        [
          for (final request in requests)
            AttentionRequestRanking(
              request: request,
              utilityScore: _utilityScore(request, plan),
            ),
        ]..sort((a, b) {
          final byUtility = b.utilityScore.compareTo(a.utilityScore);
          if (byUtility != 0) return byUtility;

          final byDeadline = _deadlineSortKey(
            a.request,
          ).compareTo(_deadlineSortKey(b.request));
          if (byDeadline != 0) return byDeadline;

          final byDuration = a.request.requestedMinutes.compareTo(
            b.request.requestedMinutes,
          );
          if (byDuration != 0) return byDuration;

          final byCreated = a.request.createdAt.compareTo(b.request.createdAt);
          if (byCreated != 0) return byCreated;

          final byAgent = a.request.agentId.compareTo(b.request.agentId);
          if (byAgent != 0) return byAgent;

          return a.request.id.compareTo(b.request.id);
        });
    return List.unmodifiable(ranked);
  }

  static AttentionSkipReason? _ineligibleReason(
    AttentionRequestEntity request,
    DayPlanEntity plan,
  ) {
    if (request.deletedAt != null) return AttentionSkipReason.deleted;
    if (request.status != AttentionRequestStatus.pending) {
      return AttentionSkipReason.notPending;
    }
    if (request.dayId != plan.dayId) return AttentionSkipReason.wrongDay;
    if (request.evidenceRefs.isEmpty) {
      return AttentionSkipReason.missingEvidence;
    }
    if (!_bounded(request.impact) || !_bounded(request.urgency)) {
      return AttentionSkipReason.outOfBounds;
    }
    if (request.requestedMinutes <= 0) {
      return AttentionSkipReason.outOfBounds;
    }
    final dayStart = localDay(plan.planDate);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final earliest = request.earliestStart;
    if (earliest != null && !earliest.isBefore(dayEnd)) {
      return AttentionSkipReason.outOfBounds;
    }
    final latest = request.latestEnd;
    if (latest != null && !latest.isAfter(dayStart)) {
      return AttentionSkipReason.outOfBounds;
    }
    if (earliest != null && latest != null && !latest.isAfter(earliest)) {
      return AttentionSkipReason.outOfBounds;
    }
    return null;
  }

  static bool _bounded(int value) => value >= 1 && value <= 5;

  static int _utilityScore(AttentionRequestEntity request, DayPlanEntity plan) {
    if (request.deletedAt != null ||
        request.status != AttentionRequestStatus.pending) {
      return -1000000;
    }
    final impact = _clampInt(request.impact, 0, 5);
    final urgency = _clampInt(request.urgency, 0, 5);
    final evidenceScore = _clampInt(request.evidenceRefs.length, 0, 4) * 25;
    final slackScore = _slackScore(request, plan);
    final energyScore = _energyScore(request);
    final durationPenalty = _clampInt(request.requestedMinutes, 0, 240);
    return (impact * 1000) +
        (urgency * 500) +
        evidenceScore +
        slackScore +
        energyScore -
        durationPenalty;
  }

  static int _slackScore(AttentionRequestEntity request, DayPlanEntity plan) {
    final deadline = request.deadline;
    if (deadline == null) return 0;
    final dayStart = localDay(plan.planDate);
    final slackMinutes = deadline.difference(dayStart).inMinutes;
    if (slackMinutes <= 0) return 600;
    if (slackMinutes >= 24 * 60) return 0;
    return 600 - (slackMinutes / 2.4).round();
  }

  static int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int _energyScore(AttentionRequestEntity request) {
    return switch (request.energyFit) {
      AttentionEnergyFit.high => 150,
      AttentionEnergyFit.neutral => 75,
      AttentionEnergyFit.low => 25,
    };
  }

  static int _deadlineSortKey(AttentionRequestEntity request) {
    return request.deadline?.millisecondsSinceEpoch ?? 1 << 62;
  }

  static List<PlannedBlock> _scheduledBlocks(DayPlanEntity plan) {
    final blocks = [
      for (final block in plan.data.plannedBlocks)
        if (block.state != PlannedBlockState.dropped) block,
    ]..sort(_compareBlocks);
    return blocks;
  }

  static int _scheduledMinutes(List<PlannedBlock> blocks) {
    return blocks.fold<int>(0, (sum, block) => sum + block.duration.inMinutes);
  }

  static int _compareBlocks(PlannedBlock a, PlannedBlock b) {
    final byStart = a.startTime.compareTo(b.startTime);
    if (byStart != 0) return byStart;
    return a.id.compareTo(b.id);
  }

  static _Slot? _firstAvailableSlot({
    required AttentionRequestEntity request,
    required DayPlanEntity plan,
    required List<PlannedBlock> scheduled,
  }) {
    final duration = Duration(minutes: request.requestedMinutes);
    final dayStart = localDay(plan.planDate);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final earliest = _maxDateTime(request.earliestStart ?? dayStart, dayStart);
    final latest = _minDateTime(request.latestEnd ?? dayEnd, dayEnd);
    if (!latest.isAfter(earliest)) return null;

    final preferredWindows = _preferredWindows(
      request: request,
      plan: plan,
      earliest: earliest,
      latest: latest,
    );
    for (final window in preferredWindows) {
      final slot = _firstSlotInWindow(
        duration: duration,
        window: window,
        scheduled: scheduled,
      );
      if (slot != null) return slot;
    }
    return _firstSlotInWindow(
      duration: duration,
      window: _Slot(start: earliest, end: latest),
      scheduled: scheduled,
    );
  }

  static List<_Slot> _preferredWindows({
    required AttentionRequestEntity request,
    required DayPlanEntity plan,
    required DateTime earliest,
    required DateTime latest,
  }) {
    if (request.energyFit != AttentionEnergyFit.high) return const <_Slot>[];
    final windows = <_Slot>[];
    for (final band in plan.energyBands) {
      if (band.level != DayAgentEnergyLevel.high &&
          band.level != DayAgentEnergyLevel.secondWind) {
        continue;
      }
      final start = _maxDateTime(band.start, earliest);
      final end = _minDateTime(band.end, latest);
      if (end.isAfter(start)) {
        windows.add(_Slot(start: start, end: end));
      }
    }
    windows.sort((a, b) => a.start.compareTo(b.start));
    return windows;
  }

  static _Slot? _firstSlotInWindow({
    required Duration duration,
    required _Slot window,
    required List<PlannedBlock> scheduled,
  }) {
    var cursor = window.start;
    for (final block in scheduled) {
      if (!block.endTime.isAfter(cursor)) continue;
      if (!block.startTime.isBefore(window.end)) {
        break;
      }
      final candidateEnd = cursor.add(duration);
      if (!candidateEnd.isAfter(block.startTime) &&
          !candidateEnd.isAfter(window.end)) {
        return _Slot(start: cursor, end: candidateEnd);
      }
      if (block.endTime.isAfter(cursor)) {
        cursor = block.endTime;
      }
    }
    final candidateEnd = cursor.add(duration);
    if (!candidateEnd.isAfter(window.end)) {
      return _Slot(start: cursor, end: candidateEnd);
    }
    return null;
  }

  static DateTime _maxDateTime(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static DateTime _minDateTime(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static String _stableBlockId(String dayId, String requestId) {
    return 'attention_block:$dayId:$requestId';
  }

  static String _stableAwardId({
    required String dayId,
    required String requestId,
    required DateTime start,
    required DateTime end,
  }) {
    return 'attention_award:$dayId:$requestId:'
        '${start.toUtc().toIso8601String()}:'
        '${end.toUtc().toIso8601String()}';
  }

  static String _awardRationale(
    AttentionRequestEntity request,
    int utilityScore,
  ) {
    return 'Attention award for "${request.title}" '
        '(utility $utilityScore, impact ${request.impact}, '
        'urgency ${request.urgency}).';
  }
}

/// Ranked request with the deterministic utility score the planner used.
class AttentionRequestRanking {
  /// Creates a ranking record.
  const AttentionRequestRanking({
    required this.request,
    required this.utilityScore,
  });

  /// Ranked request.
  final AttentionRequestEntity request;

  /// Deterministic utility score.
  final int utilityScore;
}

/// One awarded request and the planned block it would add.
class AttentionAwardProposal {
  /// Creates an award proposal.
  const AttentionAwardProposal({
    required this.request,
    required this.award,
    required this.plannedBlock,
  });

  /// Source request.
  final AttentionRequestEntity request;

  /// Persistable award entity.
  final AttentionAwardEntity award;

  /// Proposed block for the day plan.
  final PlannedBlock plannedBlock;

  /// ChangeSet-compatible add-block proposal.
  Map<String, Object?> toAddBlockChange() {
    return {
      'action': 'added',
      'reason': award.rationale,
      'to': {
        'title': plannedBlock.title,
        'taskId': plannedBlock.taskId,
        'categoryId': plannedBlock.categoryId,
        'start': plannedBlock.startTime.toIso8601String(),
        'end': plannedBlock.endTime.toIso8601String(),
        'type': plannedBlock.type.name,
        'reason': plannedBlock.reason,
      },
    };
  }
}

/// Why a request was not awarded.
enum AttentionSkipReason {
  /// Soft-deleted request.
  deleted,

  /// Request is not pending.
  notPending,

  /// Request targets another day.
  wrongDay,

  /// Request carries no evidence references.
  missingEvidence,

  /// Bounded numeric/window fields are invalid.
  outOfBounds,

  /// The plan has no remaining capacity.
  capacity,

  /// No non-overlapping slot fits the request window.
  noSlot,
}

/// A request that arbitration did not award.
class AttentionSkippedRequest {
  /// Creates a skipped-request record.
  const AttentionSkippedRequest({
    required this.request,
    required this.reason,
    required this.utilityScore,
  });

  /// Skipped request.
  final AttentionRequestEntity request;

  /// Deterministic skip reason.
  final AttentionSkipReason reason;

  /// Score the request would have had if eligible.
  final int utilityScore;
}

/// Full arbitration result.
class AttentionArbitrationResult {
  /// Creates an arbitration result.
  AttentionArbitrationResult({
    required List<AttentionRequestRanking> rankedRequests,
    required List<AttentionAwardProposal> awards,
    required List<AttentionSkippedRequest> skipped,
  }) : rankedRequests = List.unmodifiable(rankedRequests),
       awards = List.unmodifiable(awards),
       skipped = List.unmodifiable(skipped);

  /// All requests in deterministic ranking order.
  final List<AttentionRequestRanking> rankedRequests;

  /// Awarded requests.
  final List<AttentionAwardProposal> awards;

  /// Requests skipped by deterministic checks.
  final List<AttentionSkippedRequest> skipped;

  /// ChangeSet-compatible add-block changes for all awards.
  List<Map<String, Object?>> get addBlockChanges => [
    for (final award in awards) award.toAddBlockChange(),
  ];
}

class _Slot {
  const _Slot({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}
