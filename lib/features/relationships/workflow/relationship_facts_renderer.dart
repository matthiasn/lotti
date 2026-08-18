import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';

/// How many recent check-ins feed the FACTS block (ADR 0040 Decision 4:
/// bounded context keeps briefings explainable and token budgets fixed).
const relationshipCheckInLookback = 10;

/// Longest check-in narrative excerpt the FACTS block carries per entry.
const relationshipNarrativeExcerptChars = 400;

/// Renders the deterministic FACTS block of a relationship-agent Phase B
/// wake (the goal facts-renderer shape).
///
/// The context boundary is ADR 0040 Decision 4: the renderer receives the
/// relationship, its check-ins, linked task titles/statuses, the previous
/// briefing, and banner state — and nothing else.
///
/// Contact channels and contact refs ride along inside [RelationshipEntry],
/// so the exclusion is a property of this file rather than of its signature:
/// nothing here reads `data.contactChannels` or `data.contactRefs`, and the
/// renderer test renders a person whose channels are populated and fails if
/// any of them reaches the output (ADR 0041 §5). Keep it that way — the
/// boundary is one `writeln` away from being lost.
class RelationshipFactsRenderer {
  const RelationshipFactsRenderer();

  /// [preTransitionStatus] is the cadence status persisted BEFORE the
  /// transition that armed an escalation wake, recovered from the wake's
  /// baseline trigger token (ADR 0059 Decision 3) — Phase A's own register
  /// write makes it unreconstructable from storage. Null on wakes that
  /// carry no baseline (chat, explicit refresh, first-ever evaluation).
  String render({
    required RelationshipEntry relationship,
    required RelationshipCadenceDerivation derivation,
    required List<CheckInEntry> checkIns,
    required List<Task> linkedTasks,
    required AgentReportEntity? previousReport,
    required List<RelationshipNudgeEntity> nudges,
    required DateTime now,
    RelationshipCadenceStatus? preTransitionStatus,
  }) {
    final data = relationship.data;
    final buffer = StringBuffer()
      ..writeln('FACTS (authoritative, do not recompute):')
      ..writeln('PERSON:')
      ..writeln('- name: ${data.title}');
    if (data.nickname != null && data.nickname!.isNotEmpty) {
      buffer.writeln('- nickname: ${data.nickname}');
    }
    buffer
      ..writeln('- trackingSince: ${_day(relationship.meta.dateFrom)}')
      ..writeln('CADENCE:')
      ..writeln('- desiredIntervalDays: ${derivation.cadenceDays}')
      ..writeln('- status: ${derivation.status.name}')
      ..writeln('- dueDay: ${derivation.dueDayKey}');
    if (derivation.status == RelationshipCadenceStatus.due &&
        preTransitionStatus != null) {
      buffer.writeln(
        preTransitionStatus == RelationshipCadenceStatus.due
            ? '- lapse: still overdue — the cadence was already due before '
                  'this episode'
            : '- lapse: newly lapsed — the cadence transitioned to due this '
                  'episode',
      );
    }
    if (derivation.lastCheckInAt == null) {
      buffer.writeln(
        '- lastCheckIn: none recorded yet (tracking started '
        '${_day(relationship.meta.dateFrom)})',
      );
    } else {
      buffer
        ..writeln('- lastCheckIn: ${_day(derivation.lastCheckInAt!)}')
        ..writeln(
          '- daysSinceLastCheckIn: '
          '${_daysBetween(derivation.lastCheckInAt!, now)}',
        );
    }

    final recent = [...checkIns]
      ..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));
    final window = recent.take(relationshipCheckInLookback).toList();
    buffer.writeln(
      'CHECK-INS (newest first, ${window.length} of ${checkIns.length}):',
    );
    if (window.isEmpty) {
      buffer.writeln('- none recorded');
    }
    for (final checkIn in window) {
      final d = checkIn.data;
      final parts = <String>[
        _day(checkIn.meta.dateFrom),
        d.interactionType.name,
        if (d.sentiment != null) 'sentiment(user-set)=${d.sentiment!.name}',
        if (d.topics.isNotEmpty) 'topics=${d.topics.join(', ')}',
      ];
      buffer.writeln('- ${parts.join(' | ')}');
      if (d.payAttentionTo != null && d.payAttentionTo!.trim().isNotEmpty) {
        buffer.writeln('  payAttentionTo: ${d.payAttentionTo!.trim()}');
      }
      if (d.avoid != null && d.avoid!.trim().isNotEmpty) {
        buffer.writeln('  avoid: ${d.avoid!.trim()}');
      }
      final narrative = checkIn.entryText?.plainText.trim() ?? '';
      if (narrative.isNotEmpty) {
        buffer.writeln('  narrative: ${_excerpt(narrative)}');
      }
    }

    buffer.writeln('LINKED TASKS (titles and statuses only):');
    if (linkedTasks.isEmpty) {
      buffer.writeln('- none');
    }
    for (final task in linkedTasks) {
      buffer.writeln(
        '- ${task.data.title} [${_taskStatusName(task.data.status)}]',
      );
    }

    if (previousReport == null) {
      buffer.writeln('PREVIOUS BRIEFING: none yet — this is the first.');
    } else {
      buffer
        ..writeln(
          'PREVIOUS BRIEFING (${_day(previousReport.createdAt)}):',
        )
        ..writeln(previousReport.tldr ?? previousReport.content);
      final newerCheckIns =
          derivation.lastCheckInAt != null &&
          derivation.lastCheckInAt!.isAfter(previousReport.createdAt);
      if (newerCheckIns) {
        buffer.writeln(
          'BRIEFING IS STALE: check-ins landed after it was written.',
        );
      }
    }

    final active = nudges
        .where((n) => n.deletedAt == null && n.status == NudgeStatus.active)
        .toList();
    buffer.writeln('BANNERS:');
    if (active.isEmpty) {
      buffer.writeln('- no active banner');
      if (derivation.status == RelationshipCadenceStatus.due &&
          !_dismissedToday(nudges, now)) {
        buffer.writeln(
          '- cadence is due and no banner is showing: a check-in nudge is '
          'REQUIRED this wake.',
        );
      }
    }
    for (final nudge in active) {
      buffer.writeln(
        '- adId=${nudge.id} | "${nudge.brief.headline}" | activated '
        '${_day(nudge.activatedAt ?? nudge.createdAt)}'
        '${nudge.snoozedUntil != null && nudge.snoozedUntil!.isAfter(now) ? ' | snoozed until ${nudge.snoozedUntil!.toIso8601String()}' : ''}',
      );
    }
    if (_dismissedToday(nudges, now)) {
      buffer.writeln(
        '- the user dismissed a banner today: the rest-of-day quiet window '
        'holds, create no automatic banner.',
      );
    }

    return buffer.toString().trimRight();
  }

  /// Whether a banner of this agent was day-dismissed on the local
  /// calendar day of [now] — the ADR 0055 rest-of-day quiet window.
  bool _dismissedToday(List<RelationshipNudgeEntity> nudges, DateTime now) {
    for (final nudge in nudges) {
      final dismissedAt = nudge.dismissedForDayAt ?? nudge.dismissedAt;
      if (dismissedAt == null) continue;
      final local = dismissedAt.toLocal();
      if (local.year == now.year &&
          local.month == now.month &&
          local.day == now.day) {
        return true;
      }
    }
    return false;
  }

  String _taskStatusName(TaskStatus status) => status.map(
    open: (_) => 'open',
    inProgress: (_) => 'in progress',
    groomed: (_) => 'groomed',
    blocked: (_) => 'blocked',
    onHold: (_) => 'on hold',
    done: (_) => 'done',
    rejected: (_) => 'rejected',
  );

  String _day(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  int _daysBetween(DateTime from, DateTime to) {
    final a = from.toLocal();
    final b = to.toLocal();
    return DateTime(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime(a.year, a.month, a.day)).inDays;
  }

  String _excerpt(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= relationshipNarrativeExcerptChars) return collapsed;
    return '${collapsed.substring(0, relationshipNarrativeExcerptChars)}…';
  }
}
