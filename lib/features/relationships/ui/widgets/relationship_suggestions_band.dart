import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_kind_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposals_section_part.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/motion/size_fade_collapse.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// Evidence-backed proposals on the relationship card. Retains resolving rows
/// until their shared exit animation ends, independently of ledger refreshes.
class RelationshipSuggestionsBand extends ConsumerStatefulWidget {
  const RelationshipSuggestionsBand({
    required this.relationshipId,
    required this.checkIns,
    this.showHistory = false,
    this.runKey,
    super.key,
  });
  final String relationshipId;
  final List<CheckInEntry> checkIns;
  final bool showHistory;

  /// A chat host can show only proposals from this conversation turn.
  final String? runKey;

  @override
  ConsumerState<RelationshipSuggestionsBand> createState() =>
      _RelationshipSuggestionsBandState();
}

class _RelationshipSuggestionsBandState
    extends ConsumerState<RelationshipSuggestionsBand> {
  final _resolving = <String, PendingSuggestion>{};
  final _removed = <String>{};
  final _confirmed = <String>{};
  bool _sectionVisible = false;
  bool _all = false;
  bool _bulkBusy = false;
  bool _historyOpen = false;
  bool _handledHere = false;
  bool _undoBusy = false;

  String _key(PendingSuggestion row) =>
      RelationshipProposalSnapshot.itemKey(row.changeSet.id, row.itemIndex);
  void _refresh() => ref.read(updateNotificationsProvider).notifyUiOnly({
    relationshipAgentIdFor(widget.relationshipId),
  });

  void _start(PendingSuggestion row) {
    setState(() => _resolving[_key(row)] = row);
  }

  void _end(PendingSuggestion row, {required bool removed}) {
    if (!mounted) return;
    setState(() {
      _resolving.remove(_key(row));
      if (removed) {
        _removed.add(_key(row));
        _handledHere = true;
        _historyOpen = true;
      }
    });
  }

  Future<void> _confirmAll(List<PendingSuggestion> rows) async {
    if (_bulkBusy || rows.isEmpty) return;
    final kinds = rows
        .map((row) => resolveKind(row.item.toolName, row.item.args))
        .toSet();
    if (kinds.length != 1) return;
    setState(() {
      _bulkBusy = true;
      _all = true;
      for (final row in rows) {
        _resolving[_key(row)] = row;
      }
    });
    try {
      for (final row in rows) {
        ToolExecutionResult result;
        try {
          result = await _confirm(row);
        } catch (_) {
          result = const ToolExecutionResult(
            success: false,
            output: 'Confirmation failed',
          );
        }
        if (!mounted) return;
        if (result.success) {
          setState(() => _confirmed.add(_key(row)));
        } else {
          _end(row, removed: false);
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.relationshipErrorLinkTaskFailed,
          );
        }
        _refresh();
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<ToolExecutionResult> _confirm(PendingSuggestion row) async {
    final highlighter = ref.read(relationshipTaskHighlightProvider.notifier);
    final result = await ref
        .read(relationshipProposalServiceProvider)
        .confirm(row.changeSet, row.itemIndex);
    if (result.success && result.mutatedEntityId != null) {
      highlighter.highlight(result.mutatedEntityId!);
    }
    return result;
  }

  Future<void> _undo(LedgerEntry entry) async {
    if (_undoBusy) return;
    final service = ref.read(relationshipProposalServiceProvider);
    setState(() => _undoBusy = true);
    var undone = false;
    try {
      undone = await service.undoById(entry.changeSetId, entry.itemIndex);
    } catch (_) {
      /* A refused undo leaves the handled row in place. */
    }
    if (!mounted) return;
    setState(() {
      _undoBusy = false;
      if (undone) {
        final key = RelationshipProposalSnapshot.itemKey(
          entry.changeSetId,
          entry.itemIndex,
        );
        _removed.remove(key);
        _confirmed.remove(key);
      }
    });
    if (!undone) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.relationshipProposalUndoFailed,
      );
    }
    _refresh();
  }

  Widget _evidence(Map<String, dynamic> args) {
    final source = widget.checkIns
        .where((entry) => entry.id == args['sourceCheckInId'])
        .firstOrNull;
    final due = args['dueDate'] is String
        ? DateTime.tryParse(args['dueDate'] as String)
        : null;
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (due != null)
          Text(
            context.messages.taskDueDateWithDate(
              DateFormat.yMMMd(context.messages.localeName).format(due),
            ),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.aiCard.metaText,
            ),
          ),
        if (source != null)
          DesignSystemInlineAction(
            label: context.messages.relationshipProposalEvidence(
              DateFormat.yMMMd(
                context.messages.localeName,
              ).format(source.meta.dateFrom),
            ),
            semanticsLabel: context.messages.relationshipProposalEvidence(
              DateFormat.yMMMd(
                context.messages.localeName,
              ).format(source.meta.dateFrom),
            ),
            onTap: () =>
                showCheckInEditSheet(context: context, checkIn: source),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        ref
            .watch(relationshipSuggestionListProvider(widget.relationshipId))
            .value ??
        const RelationshipProposalSnapshot.empty();
    final current = snapshot.suggestions.open
        .where(
          (row) =>
              widget.runKey == null || row.changeSet.runKey == widget.runKey,
        )
        .toList();
    // Once the ledger acknowledges a removal, forget the local tombstone.
    // A peer can then reopen the same item without it staying hidden here.
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
    final shown = _all ? rows : rows.take(3).toList();
    final sameKind =
        current
            .map((row) => resolveKind(row.item.toolName, row.item.args))
            .toSet()
            .length ==
        1;
    final history = snapshot.suggestions.activity
        .where(
          (entry) =>
              widget.runKey == null ||
              snapshot.runKeys[entry.changeSetId] == widget.runKey,
        )
        .toList();
    return Column(
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
              open: shown,
              pendingCount: current.length,
              confirmAllBusy: _bulkBusy,
              onConfirmAll: current.length > 1 && sameKind && _resolving.isEmpty
                  ? () => _confirmAll(current)
                  : null,
              confirmAllPulse: 0,
              rowBuilder: (row, index) => ProposalRow(
                key: ValueKey('relationship-proposal-${_key(row)}'),
                suggestion: row,
                isFirst: index == 0,
                cascadeIndex: index,
                confirmAllPulse: _confirmed.contains(_key(row)) ? 1 : 0,
                pendingCount: current.length,
                settling:
                    _bulkBusy ||
                    (_resolving.isNotEmpty &&
                        !_resolving.containsKey(_key(row))),
                onResolveStart: _start,
                onResolveEnd: _end,
                onConfirm: () => _confirm(row),
                onReject: () => ref
                    .read(relationshipProposalServiceProvider)
                    .reject(row.changeSet, row.itemIndex),
                details: _evidence(row.item.args),
              ),
            ),
          ),
        if (!_all && rows.length > 3)
          DesignSystemInlineAction(
            label: context.messages.projectNextStepsShowMore(rows.length - 3),
            semanticsLabel: context.messages.projectNextStepsShowMore(
              rows.length - 3,
            ),
            onTap: () => setState(() => _all = true),
          ),
        if ((widget.showHistory || _handledHere) &&
            history.isNotEmpty &&
            _resolving.isEmpty)
          ProposalHistorySection(
            resolved: history,
            open: _historyOpen,
            onToggle: () => setState(() => _historyOpen = !_historyOpen),
            rowBuilder: (entry) {
              final task =
                  snapshot.receipts[RelationshipProposalSnapshot.itemKey(
                    entry.changeSetId,
                    entry.itemIndex,
                  )];
              return ProposalRow.fromLedger(
                entry: entry,
                details: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _evidence(entry.args),
                    if (task != null)
                      DesignSystemInlineAction(
                        label: context.messages.relationshipProposalAdded(
                          task.data.title,
                        ),
                        semanticsLabel: context.messages
                            .relationshipProposalAdded(task.data.title),
                        onTap: () => beamToNamed('/tasks/${task.id}'),
                      ),
                    if (entry.status == ChangeItemStatus.rejected ||
                        task != null)
                      DesignSystemInlineAction(
                        label: context.messages.designSystemUndoLabel,
                        semanticsLabel: context.messages.designSystemUndoLabel,
                        onTap: _undoBusy ? null : () => unawaited(_undo(entry)),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
