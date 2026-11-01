import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposals_section_part.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_collapse.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:material_ui/material_ui.dart';

/// The event agent's proposals, inside its card, in the task card's grammar:
/// `ProposalsSection` with a `ProposalRow` per pending item — swipe or tap ✓
/// to confirm, ✕ to dismiss, *Confirm all* when there are several — and,
/// while the recap is expanded, the history of what was confirmed or
/// dismissed.
///
/// Rows confirm and dismiss through the event confirmation service, which
/// applies them with `EventToolDispatcher`; each row runs its own resolve
/// beat, toasts and refresh, as on a task. A row being resolved stays mounted
/// until its exit ends, however soon the ledger drops it.
class EventSuggestionsBand extends ConsumerStatefulWidget {
  const EventSuggestionsBand({
    required this.eventId,
    this.showHistory = false,
    super.key,
  });

  final String eventId;

  /// Whether the resolved history shows — while the recap is expanded, as the
  /// task card shows it only with the full report.
  final bool showHistory;

  @override
  ConsumerState<EventSuggestionsBand> createState() =>
      _EventSuggestionsBandState();
}

class _EventSuggestionsBandState extends ConsumerState<EventSuggestionsBand> {
  final _resolving = <String, PendingSuggestion>{};
  final _removed = <String>{};
  final _confirmed = <String>{};
  bool _sectionVisible = false;
  bool _confirmAllBusy = false;
  bool _historyOpen = false;

  static String _key(PendingSuggestion row) =>
      '${row.changeSet.id}:${row.itemIndex}';

  void _start(PendingSuggestion row) {
    setState(() => _resolving[_key(row)] = row);
  }

  void _end(PendingSuggestion row, {required bool removed}) {
    if (!mounted) return;
    setState(() {
      _resolving.remove(_key(row));
      if (removed) _removed.add(_key(row));
    });
  }

  /// Confirms every open row in turn. Each confirmed row is pulsed so it runs
  /// its own exit, and the sweep reads top to bottom.
  Future<void> _confirmAll(List<PendingSuggestion> rows) async {
    if (_confirmAllBusy || rows.isEmpty) return;
    setState(() {
      _confirmAllBusy = true;
      for (final row in rows) {
        _resolving[_key(row)] = row;
      }
    });
    final service = ref.read(eventChangeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);
    for (final row in rows) {
      final result = await service.confirmItem(row.changeSet, row.itemIndex);
      if (!mounted) return;
      setState(() {
        if (result.success) {
          _confirmed.add(_key(row));
        } else {
          _resolving.remove(_key(row));
        }
      });
    }
    notifier.notify({rows.first.changeSet.agentId});
    if (mounted) setState(() => _confirmAllBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final list =
        ref.watch(eventSuggestionListProvider(widget.eventId)).value ??
        const UnifiedSuggestionList.empty();
    final current = list.open;
    // Once the ledger acknowledges a removal, forget the local tombstone, so
    // a peer reopening the same item is not kept hidden here.
    final currentKeys = current.map(_key).toSet();
    _removed.removeWhere((key) => !currentKeys.contains(key));
    _confirmed.removeWhere(
      (key) => !currentKeys.contains(key) && !_resolving.containsKey(key),
    );
    final byKey = {
      for (final row in current)
        if (!_removed.contains(_key(row))) _key(row): row,
      ..._resolving,
    };
    final rows = byKey.values.toList();
    if (rows.isNotEmpty) _sectionVisible = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_sectionVisible)
          SizeFadeCollapse(
            onCollapsed: () {
              if (mounted) setState(() => _sectionVisible = false);
            },
            collapsed: rows.isEmpty,
            duration: ProposalMotion.collapse,
            child: ProposalsSection(
              open: rows,
              pendingCount: current.length,
              confirmAllBusy: _confirmAllBusy,
              onConfirmAll:
                  current.length > 1 && _resolving.isEmpty && !_confirmAllBusy
                  ? () => _confirmAll(current)
                  : null,
              confirmAllPulse: 0,
              rowBuilder: (row, index) => ProposalRow(
                key: ValueKey('event-proposal-${_key(row)}'),
                suggestion: row,
                isFirst: index == 0,
                cascadeIndex: index,
                confirmAllPulse: _confirmed.contains(_key(row)) ? 1 : 0,
                pendingCount: current.length,
                settling:
                    _confirmAllBusy ||
                    (_resolving.isNotEmpty &&
                        !_resolving.containsKey(_key(row))),
                onResolveStart: _start,
                onResolveEnd: _end,
                onConfirm: () => ref
                    .read(eventChangeSetConfirmationServiceProvider)
                    .confirmItem(row.changeSet, row.itemIndex),
                onReject: () => ref
                    .read(eventChangeSetConfirmationServiceProvider)
                    .rejectItem(row.changeSet, row.itemIndex),
                details: _why(context, row.item.toolName, row.item.args),
              ),
            ),
          ),
        if (widget.showHistory &&
            list.activity.isNotEmpty &&
            _resolving.isEmpty)
          ProposalHistorySection(
            resolved: list.activity,
            open: _historyOpen,
            onToggle: () => setState(() => _historyOpen = !_historyOpen),
          ),
      ],
    );
  }

  /// Why the agent proposes it, where the proposal carries that: the words
  /// that named the person, or the follow-up's notes. Null otherwise.
  static Widget? _why(
    BuildContext context,
    String toolName,
    Map<String, dynamic> args,
  ) {
    final raw = switch (toolName) {
      EventAgentToolNames.suggestPerson =>
        args[EventAgentPersonToolArgs.mention],
      EventAgentToolNames.suggestFollowUpTask => args['notes'],
      _ => null,
    };
    if (raw is! String || raw.trim().isEmpty) return null;
    final text = toolName == EventAgentToolNames.suggestPerson
        ? '“${raw.trim()}”'
        : raw.trim();
    final tokens = context.designTokens;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}
