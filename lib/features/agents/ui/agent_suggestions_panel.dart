import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/suggestion_row.dart';
import 'package:lotti/features/agents/ui/task_agent_report_section.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_section_card.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Single consolidated section on the task detail page: the running-state
/// header and narrative report (via [TaskAgentReportSection]) plus the
/// unified list of open proposals the user can confirm or reject inline.
class AgentSuggestionsPanel extends ConsumerWidget {
  const AgentSuggestionsPanel({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(unifiedSuggestionListProvider(taskId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskAgentReportSection(taskId: taskId),
        listAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (list.open.isNotEmpty) _OpenSuggestionsList(open: list.open),
              if (list.activity.isNotEmpty)
                _RecentActivityStrip(
                  activity: list.activity,
                  agentName: list.agentName,
                ),
            ],
          ),
          error: (_, _) => const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _OpenSuggestionsList extends ConsumerStatefulWidget {
  const _OpenSuggestionsList({required this.open});

  final List<PendingSuggestion> open;

  @override
  ConsumerState<_OpenSuggestionsList> createState() =>
      _OpenSuggestionsListState();
}

class _OpenSuggestionsListState extends ConsumerState<_OpenSuggestionsList> {
  bool _confirmAllBusy = false;

  @override
  Widget build(BuildContext context) {
    final open = widget.open;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TaskDetailSectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pending_actions,
                  size: 20,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.messages.changeSetCardTitle,
                    style: context
                        .designTokens
                        .typography
                        .styles
                        .subtitle
                        .subtitle2
                        .copyWith(
                          color: TaskShowcasePalette.highText(context),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _PendingBadge(count: open.length),
                if (open.length > 1) ...[
                  const SizedBox(width: 8),
                  _ConfirmAllButton(
                    busy: _confirmAllBusy,
                    onPressed: _confirmAllBusy ? null : _confirmAll,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            for (final suggestion in open)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: SuggestionRow(suggestion: suggestion),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAll() async {
    if (_confirmAllBusy) return;
    setState(() => _confirmAllBusy = true);

    final service = ref.read(changeSetConfirmationServiceProvider);
    final notifier = ref.read(updateNotificationsProvider);

    // Group by change set so we issue one confirmAll per set even when
    // multiple items on the same set appear in the unified open list.
    final distinctSets = <String, ChangeSetEntity>{
      for (final s in widget.open) s.changeSet.id: s.changeSet,
    };
    final agentIds = {for (final cs in distinctSets.values) cs.agentId};

    var anyFailed = false;
    try {
      for (final cs in distinctSets.values) {
        final results = await service.confirmAll(cs);
        if (results.any((r) => !r.success)) anyFailed = true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                anyFailed
                    ? context.messages.changeSetConfirmError
                    : context.messages.changeSetItemConfirmed,
              ),
            ),
          );
      }
    } catch (e, stackTrace) {
      developer.log(
        'confirmAll failed',
        name: 'AgentSuggestionsPanel',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(context.messages.changeSetConfirmError),
            ),
          );
      }
    } finally {
      // Always refresh — a later set can throw after earlier sets already
      // persisted, so skipping the notify would leave the UI stale.
      notifier.notify(agentIds);
      if (mounted) setState(() => _confirmAllBusy = false);
    }
  }
}

class _ConfirmAllButton extends StatelessWidget {
  const _ConfirmAllButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DesignSystemButton(
      label: context.messages.changeSetConfirmAll,
      onPressed: busy ? null : onPressed,
      variant: DesignSystemButtonVariant.tertiary,
      leadingIcon: Icons.done_all,
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.messages.changeSetPendingCount(count),
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Single-row entry point for the agent's resolved proposal history.
///
/// Collapsed (default) state is a compact tappable row drawn by
/// [_CollapsedActivityRow]: a history icon, the localized "Recent
/// proposal activity" label, and a trailing count pill — no card chrome,
/// so the strip occupies one row of height when idle. Tapping expands
/// inline into [_ExpandedActivityCard], a [TaskDetailSectionCard] holding
/// the full, newest-first list of [LedgerEntry] rows (each with its verdict
/// icon and `humanSummary`). The transition between the two states runs
/// through [AnimatedSize] so the surrounding layout doesn't jump.
///
/// `activity` comes from [unifiedSuggestionListProvider] as the ledger's
/// `resolved` list and is already newest-first.
class _RecentActivityStrip extends StatefulWidget {
  const _RecentActivityStrip({required this.activity, required this.agentName});

  final List<LedgerEntry> activity;

  /// The agent's display name. Forwarded into the retracted-verdict
  /// tooltip so it can name the agent that withdrew a proposal.
  final String? agentName;

  @override
  State<_RecentActivityStrip> createState() => _RecentActivityStripState();
}

class _RecentActivityStripState extends State<_RecentActivityStrip> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: _expanded
            ? _ExpandedActivityCard(
                activity: widget.activity,
                agentName: widget.agentName,
                onCollapse: _toggle,
              )
            : _CollapsedActivityRow(
                total: widget.activity.length,
                onExpand: _toggle,
              ),
      ),
    );
  }
}

class _CollapsedActivityRow extends StatelessWidget {
  const _CollapsedActivityRow({required this.total, required this.onExpand});

  final int total;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onExpand,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.history,
              size: 18,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.messages.agentSuggestionsActivityTitle,
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _ActivityCountPill(count: total),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 20,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCountPill extends StatelessWidget {
  const _ActivityCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: context.textTheme.labelSmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ExpandedActivityCard extends StatelessWidget {
  const _ExpandedActivityCard({
    required this.activity,
    required this.agentName,
    required this.onCollapse,
  });

  final List<LedgerEntry> activity;
  final String? agentName;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return TaskDetailSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onCollapse,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.messages.agentSuggestionsActivityTitle,
                      style: context
                          .designTokens
                          .typography
                          .styles
                          .subtitle
                          .subtitle2
                          .copyWith(
                            color: TaskShowcasePalette.highText(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _ActivityCountPill(count: activity.length),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_less,
                    size: 20,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final entry in activity)
            _ActivityRow(entry: entry, agentName: agentName),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.agentName});

  final LedgerEntry entry;
  final String? agentName;

  @override
  Widget build(BuildContext context) {
    final reason = entry.reason?.trim();
    final hasReason = reason != null && reason.isNotEmpty;
    final verdictIcon = _verdictIcon(entry.status);
    final verdictColor = _verdictColor(context, entry.status);
    final verdictLabel = _verdictLabel(context, entry.status, agentName);
    // Prefer resolvedAt (when the verdict was recorded) over createdAt so
    // the tooltip dates the decision, not the original proposal.
    final verdictTimestamp = entry.resolvedAt ?? entry.createdAt;
    final verdictTooltip = verdictLabel.isEmpty
        ? formatAgentDateTime(verdictTimestamp)
        : '$verdictLabel · ${formatAgentDateTime(verdictTimestamp)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LeftAnchoredTooltip(
            message: verdictTooltip,
            child: Icon(verdictIcon, size: 18, color: verdictColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.humanSummary,
              style: context.textTheme.bodyMedium,
            ),
          ),
          if (hasReason) ...[
            const SizedBox(width: 8),
            _LeftAnchoredTooltip(
              message: reason,
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _verdictIcon(ChangeItemStatus status) => switch (status) {
    ChangeItemStatus.confirmed => Icons.check,
    ChangeItemStatus.rejected => Icons.close,
    ChangeItemStatus.retracted => Icons.undo,
    _ => Icons.history,
  };

  static Color _verdictColor(BuildContext context, ChangeItemStatus status) =>
      switch (status) {
        ChangeItemStatus.confirmed =>
          context.designTokens.colors.alert.success.defaultColor,
        ChangeItemStatus.rejected => context.colorScheme.error,
        ChangeItemStatus.retracted => context.colorScheme.primary,
        _ => context.colorScheme.onSurfaceVariant,
      };

  static String _verdictLabel(
    BuildContext context,
    ChangeItemStatus status,
    String? agentName,
  ) {
    final name = (agentName != null && agentName.trim().isNotEmpty)
        ? agentName.trim()
        // Fallback when the agent has been detached: the generic noun
        // keeps the sentence grammatical instead of leaving a bare "by".
        : context.messages.agentSuggestionsActivityAgentFallback;
    return switch (status) {
      ChangeItemStatus.confirmed =>
        context.messages.agentSuggestionsActivityVerdictConfirmed,
      ChangeItemStatus.rejected =>
        context.messages.agentSuggestionsActivityVerdictRejected,
      ChangeItemStatus.retracted =>
        context.messages.agentSuggestionsActivityVerdictRetracted(name),
      _ => '',
    };
  }
}

/// Tooltip that starts at its child's left edge and extends to the right,
/// instead of the default Material `Tooltip` behaviour of centring on the
/// child. Used in the activity strip so the verdict/reason labels don't
/// drift off toward the middle of the screen away from the tiny icon
/// they're describing.
///
/// Implemented with [OverlayPortal] + [CompositedTransformFollower] so
/// the tooltip rides with the icon during scroll and resize. Hover on
/// desktop opens it; on touch, pass [TooltipTriggerMode.tap].
class _LeftAnchoredTooltip extends StatefulWidget {
  const _LeftAnchoredTooltip({
    required this.message,
    required this.child,
    this.triggerMode = TooltipTriggerMode.longPress,
  });

  final String message;
  final Widget child;
  final TooltipTriggerMode triggerMode;

  @override
  State<_LeftAnchoredTooltip> createState() => _LeftAnchoredTooltipState();
}

class _LeftAnchoredTooltipState extends State<_LeftAnchoredTooltip> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();

  void _show() {
    if (!_controller.isShowing) _controller.show();
  }

  void _hide() {
    if (_controller.isShowing) _controller.hide();
  }

  void _toggle() => _controller.isShowing ? _hide() : _show();

  @override
  Widget build(BuildContext context) {
    final isHoverTrigger = widget.triggerMode == TooltipTriggerMode.longPress;
    final isTapTrigger = widget.triggerMode == TooltipTriggerMode.tap;

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: isHoverTrigger ? (_) => _show() : null,
        onExit: isHoverTrigger ? (_) => _hide() : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isTapTrigger ? _toggle : null,
          onLongPress: isHoverTrigger ? _show : null,
          child: OverlayPortal(
            controller: _controller,
            overlayChildBuilder: (_) => _overlay(context),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        // Anchor the tooltip's top-left to the child's bottom-left so it
        // starts at the icon and grows to the right.
        targetAnchor: Alignment.bottomLeft,
        offset: const Offset(0, 6),
        child: _TooltipBubble(
          message: widget.message,
          onTapOutside: isHoverOrTap ? _hide : null,
        ),
      ),
    );
  }

  bool get isHoverOrTap =>
      widget.triggerMode == TooltipTriggerMode.tap ||
      widget.triggerMode == TooltipTriggerMode.longPress;
}

class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble({required this.message, required this.onTapOutside});

  final String message;
  final VoidCallback? onTapOutside;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: TapRegion(
        onTapOutside: onTapOutside == null ? null : (_) => onTapOutside!(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              message,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onInverseSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
