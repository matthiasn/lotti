part of 'task_agent_context_builder.dart';

/// Prompt-text formatters for [TaskAgentContextBuilder]: render the
/// attention requests and the proposal-ledger / open-proposal guard into the
/// strings injected into the task-agent wake prompt.
extension _TaskAgentContextFormatters on TaskAgentContextBuilder {
  String _formatTaskAttentionRequests(
    List<AttentionRequestEntity> claims, {
    required String agentId,
  }) {
    if (claims.isEmpty) return '';
    final rows = [
      for (final claim in claims)
        {
          'id': claim.id,
          'agentId': claim.agentId,
          'ownedByThisAgent': claim.agentId == agentId,
          'title': claim.title,
          'requestedMinutes': claim.requestedMinutes,
          'impact': claim.impact,
          'urgency': claim.urgency,
          'energyFit': claim.energyFit.name,
          'scopeKind': claim.scopeKind.name,
          'earliestStart': claim.earliestStart?.toIso8601String(),
          'latestEnd': claim.latestEnd?.toIso8601String(),
          'deadline': claim.deadline?.toIso8601String(),
          'nextReviewAt': claim.nextReviewAt?.toIso8601String(),
          'rationale': claim.rationale,
        },
    ];
    return (StringBuffer()
          ..writeln('## Attention Requests For This Task')
          ..writeln()
          ..writeln(
            'These active requests are already visible to the day planner. '
            'Maintain only rows where ownedByThisAgent is true. If one of '
            'your requests is no longer needed, call '
            '`resolve_attention_request` with withdrawn or satisfied. If the '
            'task still needs attention but the ask materially changed (for '
            'example amount, impact, urgency, energy fit, scope, timing '
            'window, review time, or rationale), call `request_attention` '
            'with the new ask; it supersedes your old active request. Do not '
            'call `request_attention` again for an equivalent ask.',
          )
          ..writeln()
          ..writeln('```json')
          ..writeln(const JsonEncoder.withIndent('  ').convert(rows))
          ..writeln('```')
          ..writeln())
        .toString();
  }

  /// Formats the [ProposalLedger] into a single markdown section the agent
  /// consumes during a wake.
  ///
  /// The ledger is the agent's memory of its own suggestions for this task.
  /// Open entries carry fingerprints so the agent can call
  /// `retract_suggestions` with those fingerprints when a proposal is no
  /// longer relevant.
  ///
  /// [includeResolved] selects the legacy fallback view for resolved verdicts.
  /// With compaction on, resolved verdicts are decision-tagged events in the
  /// task log instead, and open proposal details render once in the guard near
  /// the final instruction.
  String _formatProposalLedger(
    ProposalLedger ledger, {
    required bool includeResolved,
  }) {
    if (ledger.isEmpty) return '';
    if (!includeResolved) return '';

    final buffer = StringBuffer()
      ..writeln('## Proposal Ledger')
      ..writeln()
      ..writeln(
        'This is a complete record of suggestions you have produced '
        'for this task. Open proposal details are listed once in the '
        '`## Open Proposal Guard` below. For RESOLVED items, learn from '
        'the verdict: do not re-propose rejected items unless the task '
        'context has materially changed.',
      )
      ..writeln()
      ..writeln('### Open (${ledger.open.length})')
      ..writeln(
        ledger.open.isEmpty
            ? '- (none)'
            : '- See `## Open Proposal Guard` below for open proposal '
                  'fingerprints and summaries.',
      )
      ..writeln();

    if (includeResolved && ledger.resolved.isNotEmpty) {
      buffer.writeln('### Resolved (${ledger.resolved.length}, most recent)');
      for (final e in ledger.resolved) {
        buffer.writeln('- ${formatResolvedLedgerLine(e)}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Renders a compact, high-salience guard immediately before the final wake
  /// instruction so OPEN proposals are treated as current work-cycle state,
  /// not just historical context earlier in the prompt.
  String _formatOpenProposalGuard(ProposalLedger ledger) {
    if (ledger.open.isEmpty) return '';

    final buffer = StringBuffer()
      ..writeln('## Open Proposal Guard')
      ..writeln()
      ..writeln(
        'Before proposing any change, compare it against these OPEN '
        'proposals. Do not propose the same user-facing action again '
        '(for `update_running_timer`, compare per `timerId`). If an OPEN '
        'proposal is stale, call `retract_suggestions` with its fingerprint; '
        'otherwise leave it open.',
      )
      ..writeln()
      ..writeln(
        ledger.open
            .map(
              (e) =>
                  '- [fp=${e.fingerprint}] `${e.toolName}`: '
                  '${e.humanSummary.trim()}',
            )
            .join('\n'),
      )
      ..writeln();

    return buffer.toString();
  }
}
