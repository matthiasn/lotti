import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/captures_panel.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

enum _DayMenuAction { inspectAgent, deletePlan }

/// Hosts the two projections of the [DraftPlan] — Agenda (intent) and
/// Day (mechanics) — with a pill toggle at the top.
///
/// Agenda is the default surface per the prototype: it's the
/// "what today is about" view; Day is the "when does it happen"
/// projection a tap away. A footer pill opens the Refine screen for
/// voice-driven plan changes.
///
/// With no plan ([hasPlan] false — the route-level root passes a
/// synthetic empty [draft]) the page lands on the **Day** view so
/// recorded sessions are immediately visible on the timeline, and the
/// footer carries a single "Speak a check-in" CTA instead of
/// Refine/Commit (handoff v2 item 2).
class DayPage extends ConsumerStatefulWidget {
  const DayPage({
    required this.draft,
    this.hasPlan = true,
    this.onCheckIn,
    this.dateStrip,
    super.key,
  });

  final DraftPlan draft;

  /// False when [draft] is a synthetic empty aggregate for a day
  /// without a drafted plan.
  final bool hasPlan;

  /// Routes to the Capture screen — the empty-state footer CTA.
  final VoidCallback? onCheckIn;

  /// Optional widget rendered in place of the default static title.
  /// The route-level `DailyOsNextRoot` uses this to inject a date
  /// strip so the user can navigate between days without losing the
  /// Agenda/Day toggle in the trailing actions slot.
  final Widget? dateStrip;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  late PlanView _view = widget.hasPlan ? PlanView.agenda : PlanView.day;

  Future<void> _openRefine() async {
    final updatedPlan = await showRefineModal(
      context: context,
      draft: widget.draft,
    );
    if (!mounted || updatedPlan == null) return;
    ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
  }

  void _openCommit() {
    nav_service.beamToNamed(
      dailyOsNextRoutePath(DailyOsNextRouteTarget.commit, widget.draft.dayDate),
    );
  }

  void _openShutdown() {
    nav_service.beamToNamed(
      dailyOsNextRoutePath(
        DailyOsNextRouteTarget.shutdown,
        widget.draft.dayDate,
      ),
    );
  }

  /// Resolves the day-agent identity for the current day and beams the
  /// Settings stack onto the existing agent detail page so the user can
  /// inspect the wake history, conversation log, observations, and
  /// token usage that produced this plan.
  Future<void> _openAgentInternals() async {
    final identity = await ref.read(
      agent_providers.dayAgentProvider(widget.draft.dayDate).future,
    );
    if (!mounted || identity == null) return;
    navigateToAgentInstance(identity.agentId);
  }

  /// Confirms intent then soft-deletes the persisted `DayPlanEntity`
  /// for this day via `DayAgentInterface.deletePlanForDate`. The
  /// route-level root watches `currentDraftPlanProvider`, which
  /// auto-invalidates on the agent's update stream, so the screen
  /// flips back to Capture for this date without a manual navigate.
  Future<void> _confirmDeletePlan() async {
    final messages = context.messages;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(messages.dailyOsNextDayDeleteDialogTitle),
        content: Text(messages.dailyOsNextDayDeleteDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(messages.dailyOsNextDayDeleteDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(
                dialogContext,
              ).colorScheme.errorContainer,
              foregroundColor: Theme.of(
                dialogContext,
              ).colorScheme.onErrorContainer,
            ),
            child: Text(messages.dailyOsNextDayDeleteDialogConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final agent = ref.read(dayAgentProvider);
    await agent.deletePlanForDate(widget.draft.dayDate);
  }

  /// Persists an inline rename of a standalone agenda item by renaming
  /// each of its linked blocks, then refreshes the plan projection.
  Future<void> _renameItem(AgendaItem item, String title) async {
    final agent = ref.read(dayAgentProvider);
    try {
      var plan = widget.draft;
      for (final blockId in item.linkedBlockIds) {
        plan = await agent.renameBlock(
          plan: plan,
          blockId: blockId,
          title: title,
        );
      }
    } catch (_) {
      _showRenameFailedToast();
      return;
    } finally {
      // Re-project even on partial failure so the UI reflects whatever
      // was persisted before the error.
      ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
    }
  }

  Future<void> _renameBlock(TimeBlock block, String title) async {
    final agent = ref.read(dayAgentProvider);
    try {
      await agent.renameBlock(
        plan: widget.draft,
        blockId: block.id,
        title: title,
      );
    } catch (_) {
      _showRenameFailedToast();
      return;
    }
    ref.invalidate(currentDraftPlanProvider(widget.draft.dayDate));
  }

  void _showRenameFailedToast() {
    if (!mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: context.messages.dailyOsNextRenameFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final bottomNavHeight = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );
    final actualBlocks = ref
        .watch(dailyOsActualTimeBlocksProvider(widget.draft.dayDate))
        .value;
    // Inline rename is only offered when a real plan backs the surface.
    final onRenameItem = widget.hasPlan
        ? (AgendaItem item, String title) => unawaited(_renameItem(item, title))
        : null;
    final onRenameBlock = widget.hasPlan
        ? (TimeBlock block, String title) =>
              unawaited(_renameBlock(block, title))
        : null;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomNavHeight),
          child: Column(
            children: [
              _DayHeader(
                dateStrip: widget.dateStrip,
                selectedView: _view,
                hasPlan: widget.hasPlan,
                onViewChanged: (next) => setState(() => _view = next),
                onBack: () => Navigator.of(context).maybePop(),
                onInspectAgent: () => unawaited(_openAgentInternals()),
                onDeletePlan: () => unawaited(_confirmDeletePlan()),
              ),
              CapturesPanel(date: widget.draft.dayDate),
              Expanded(
                child: _view == PlanView.agenda
                    ? AgendaView(
                        draft: widget.draft,
                        actualBlocks: actualBlocks ?? const [],
                        hasPlan: widget.hasPlan,
                        onRenameItem: onRenameItem,
                      )
                    : DayTimeline(
                        draft: widget.draft,
                        actualBlocks: actualBlocks,
                        onRenameBlock: onRenameBlock,
                      ),
              ),
              if (widget.hasPlan)
                _DayFooter(
                  draft: widget.draft,
                  onRefine: _openRefine,
                  onCommit: _openCommit,
                  onShutdown: _openShutdown,
                )
              else
                _NoPlanFooter(onCheckIn: widget.onCheckIn),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.dateStrip,
    required this.selectedView,
    required this.hasPlan,
    required this.onViewChanged,
    required this.onBack,
    required this.onInspectAgent,
    required this.onDeletePlan,
  });

  final Widget? dateStrip;
  final PlanView selectedView;
  final bool hasPlan;
  final ValueChanged<PlanView> onViewChanged;
  final VoidCallback onBack;
  final VoidCallback onInspectAgent;
  final VoidCallback onDeletePlan;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: tokens.colors.background.level01,
      child: _MeasuredDayHeader(
        horizontalPadding: tokens.spacing.step5,
        verticalPadding: tokens.spacing.step2,
        itemGap: tokens.spacing.step3,
        rowGap: tokens.spacing.step2,
        title: dateStrip ?? _DefaultDayHeaderTitle(onBack: onBack),
        toggle: PlanViewToggle(
          selected: selectedView,
          onChanged: onViewChanged,
        ),
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProcessingCategoryFilterButton(),
            PopupMenuButton<_DayMenuAction>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: context.messages.dailyOsNextDayMoreTooltip,
              onSelected: (action) {
                switch (action) {
                  case _DayMenuAction.inspectAgent:
                    onInspectAgent();
                  case _DayMenuAction.deletePlan:
                    onDeletePlan();
                }
              },
              itemBuilder: (popupContext) => [
                PopupMenuItem<_DayMenuAction>(
                  value: _DayMenuAction.inspectAgent,
                  child: ListTile(
                    leading: const Icon(Icons.psychology_alt_outlined),
                    title: Text(
                      popupContext.messages.dailyOsNextDayMenuInspectAgent,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (hasPlan)
                  PopupMenuItem<_DayMenuAction>(
                    value: _DayMenuAction.deletePlan,
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(
                        popupContext.messages.dailyOsNextDayMenuDeletePlan,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
            SizedBox(width: tokens.spacing.step2),
          ],
        ),
      ),
    );
  }
}

class _DefaultDayHeaderTitle extends StatelessWidget {
  const _DefaultDayHeaderTitle({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.messages.dailyOsNextDayBack,
          onPressed: onBack,
        ),
        Flexible(
          child: Text(
            context.messages.dailyOsNextDayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

class _MeasuredDayHeader extends MultiChildRenderObjectWidget {
  _MeasuredDayHeader({
    required Widget title,
    required Widget toggle,
    required Widget actions,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.rowGap,
  }) : super(children: [title, toggle, actions]);

  final double horizontalPadding;
  final double verticalPadding;
  final double itemGap;
  final double rowGap;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasuredDayHeader(
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      itemGap: itemGap,
      rowGap: rowGap,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredDayHeader renderObject,
  ) {
    renderObject.updateMetrics(
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      itemGap: itemGap,
      rowGap: rowGap,
    );
  }
}

class _RenderMeasuredDayHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MeasuredDayHeaderParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _MeasuredDayHeaderParentData
        > {
  _RenderMeasuredDayHeader({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.rowGap,
  });

  double horizontalPadding;
  double verticalPadding;
  double itemGap;
  double rowGap;

  void updateMetrics({
    required double horizontalPadding,
    required double verticalPadding,
    required double itemGap,
    required double rowGap,
  }) {
    final changed =
        this.horizontalPadding != horizontalPadding ||
        this.verticalPadding != verticalPadding ||
        this.itemGap != itemGap ||
        this.rowGap != rowGap;
    if (!changed) return;
    this
      ..horizontalPadding = horizontalPadding
      ..verticalPadding = verticalPadding
      ..itemGap = itemGap
      ..rowGap = rowGap;
    markNeedsLayout();
  }

  RenderBox get _title {
    final child = firstChild;
    assert(child != null, 'Measured header title child is missing.');
    return child!;
  }

  RenderBox get _toggle {
    final child = childAfter(_title);
    assert(child != null, 'Measured header toggle child is missing.');
    return child!;
  }

  RenderBox get _actions {
    final child = childAfter(_toggle);
    assert(child != null, 'Measured header actions child is missing.');
    return child!;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MeasuredDayHeaderParentData) {
      child.parentData = _MeasuredDayHeaderParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.minWidth; // coverage:ignore-line
    final contentWidth = math.max<double>(0, width - horizontalPadding * 2);
    // coverage:ignore-start
    final maxChildHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : double.infinity;
    // coverage:ignore-end
    final looseContentConstraints = BoxConstraints.loose(
      Size(contentWidth, maxChildHeight),
    );

    final title = _title;
    final toggle = _toggle;
    final actions = _actions;

    final actionsSize =
        (actions..layout(looseContentConstraints, parentUsesSize: true)).size;
    final toggleSize =
        (toggle..layout(looseContentConstraints, parentUsesSize: true)).size;
    var titleSize =
        (title..layout(looseContentConstraints, parentUsesSize: true)).size;

    final inlineWidth =
        titleSize.width +
        itemGap +
        toggleSize.width +
        itemGap +
        actionsSize.width;
    final fitsInline = inlineWidth <= contentWidth;

    if (!fitsInline) {
      final titleWidth = math.max<double>(
        0,
        contentWidth - actionsSize.width - itemGap,
      );
      title.layout(
        BoxConstraints.loose(Size(titleWidth, maxChildHeight)),
        parentUsesSize: true,
      );
      titleSize = title.size;
    }

    final firstRowHeight = math.max(titleSize.height, actionsSize.height);
    final headerHeight = fitsInline
        ? verticalPadding * 2 + math.max(firstRowHeight, toggleSize.height)
        : verticalPadding * 2 + firstRowHeight + rowGap + toggleSize.height;

    size = constraints.constrain(Size(width, headerHeight));

    if (fitsInline) {
      final rowHeight = math.max(firstRowHeight, toggleSize.height);
      _position(
        title,
        Offset(
          horizontalPadding,
          verticalPadding + (rowHeight - titleSize.height) / 2,
        ),
      );
      _position(
        toggle,
        Offset(
          horizontalPadding + titleSize.width + itemGap,
          verticalPadding + (rowHeight - toggleSize.height) / 2,
        ),
      );
      _position(
        actions,
        Offset(
          width - horizontalPadding - actionsSize.width,
          verticalPadding + (rowHeight - actionsSize.height) / 2,
        ),
      );
      return;
    }

    _position(
      title,
      Offset(
        horizontalPadding,
        verticalPadding + (firstRowHeight - titleSize.height) / 2,
      ),
    );
    _position(
      actions,
      Offset(
        width - horizontalPadding - actionsSize.width,
        verticalPadding + (firstRowHeight - actionsSize.height) / 2,
      ),
    );
    _position(
      toggle,
      Offset(horizontalPadding, verticalPadding + firstRowHeight + rowGap),
    );
  }

  void _position(RenderBox child, Offset offset) {
    (child.parentData! as _MeasuredDayHeaderParentData).offset = offset;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

class _MeasuredDayHeaderParentData extends ContainerBoxParentData<RenderBox> {}

class _DayFooter extends StatelessWidget {
  const _DayFooter({
    required this.draft,
    required this.onRefine,
    required this.onCommit,
    required this.onShutdown,
  });

  final DraftPlan draft;
  final VoidCallback onRefine;
  final VoidCallback onCommit;
  final VoidCallback onShutdown;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final isDesktop = isDesktopLayout(context);
    final hint = Text(
      context.messages.dailyOsNextDayRefineFooterHint,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
    );
    final actions = _DayFooterActions(
      draft: draft,
      teal: teal,
      onRefine: onRefine,
      onCommit: onCommit,
      onShutdown: onShutdown,
      expand: !isDesktop,
    );
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: isDesktop
            ? Row(
                children: [
                  Expanded(child: hint),
                  SizedBox(width: tokens.spacing.step4),
                  actions,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hint,
                  SizedBox(height: tokens.spacing.step3),
                  actions,
                ],
              ),
      ),
    );
  }
}

class _DayFooterActions extends StatelessWidget {
  const _DayFooterActions({
    required this.draft,
    required this.teal,
    required this.onRefine,
    required this.onCommit,
    required this.onShutdown,
    required this.expand,
  });

  final DraftPlan draft;
  final Color teal;
  final VoidCallback onRefine;
  final VoidCallback onCommit;
  final VoidCallback onShutdown;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final refineButton = OutlinedButton.icon(
      onPressed: onRefine,
      icon: Icon(Icons.mic_rounded, size: 14, color: teal),
      label: Text(
        context.messages.dailyOsNextDayRefineCta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: teal,
        side: BorderSide(color: teal.withValues(alpha: 0.32)),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
      ),
    );
    final primaryButton = draft.state == DayState.drafted
        ? FilledButton.icon(
            onPressed: onCommit,
            icon: const Icon(Icons.lock_outline_rounded, size: 14),
            label: Text(
              context.messages.dailyOsNextDayLockInCta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: teal,
              foregroundColor: tokens.colors.text.onInteractiveAlert,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onShutdown,
            icon: Icon(
              Icons.nights_stay_outlined,
              size: 14,
              color: tokens.colors.text.mediumEmphasis,
            ),
            label: Text(
              context.messages.dailyOsNextDayWrapUpCta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.colors.text.mediumEmphasis,
              side: BorderSide(color: tokens.colors.decorative.level01),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
              ),
            ),
          );

    return Row(
      children: [
        if (expand) Expanded(child: refineButton) else refineButton,
        SizedBox(width: tokens.spacing.step2),
        if (expand) Expanded(child: primaryButton) else primaryButton,
      ],
    );
  }
}

/// Footer for a day without a drafted plan: a single primary CTA that
/// routes to Capture so the assistant can draft a day around the
/// already-tracked time (handoff v2 item 2).
class _NoPlanFooter extends StatelessWidget {
  const _NoPlanFooter({required this.onCheckIn});

  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('daily_os_day_check_in_cta'),
              onPressed: onCheckIn,
              icon: const Icon(Icons.mic_rounded, size: 14),
              label: Text(
                context.messages.dailyOsNextDayCheckInCta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.colors.interactive.enabled,
                foregroundColor: tokens.colors.text.onInteractiveAlert,
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step5,
                  vertical: tokens.spacing.step2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    tokens.radii.badgesPills,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
