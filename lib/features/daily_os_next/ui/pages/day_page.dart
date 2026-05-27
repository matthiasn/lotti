import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/actual_time_blocks_provider.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/captures_panel.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart' as nav_service;
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

enum _DayMenuAction { inspectAgent, deletePlan }

/// Hosts the two read-only projections of the [DraftPlan] — Agenda
/// (intent) and Day (mechanics) — with a pill toggle at the top.
///
/// Agenda is the default surface per the prototype: it's the
/// "what today is about" view; Day is the "when does it happen"
/// projection a tap away. A footer pill opens the Refine screen for
/// voice-driven plan changes.
class DayPage extends ConsumerStatefulWidget {
  const DayPage({required this.draft, this.dateStrip, super.key});

  final DraftPlan draft;

  /// Optional widget rendered in place of the default static title.
  /// The route-level `DailyOsNextRoot` uses this to inject a date
  /// strip so the user can navigate between days without losing the
  /// Agenda/Day toggle in the trailing actions slot.
  final Widget? dateStrip;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  PlanView _view = PlanView.agenda;

  void _openRefine() {
    nav_service.beamToNamed(
      dailyOsNextRoutePath(DailyOsNextRouteTarget.refine, widget.draft.dayDate),
    );
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final bottomNavHeight = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );
    final actualBlocks = _view == PlanView.day
        ? ref.watch(dailyOsActualTimeBlocksProvider(widget.draft.dayDate)).value
        : null;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        title:
            widget.dateStrip ??
            Text(
              context.messages.dailyOsNextDayTitle,
              style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
        // When [dateStrip] is provided the page is mounted from the
        // route-level root, which owns navigation. Suppress the
        // in-page back button so the AppBar stays focused on the date
        // controls.
        automaticallyImplyLeading: widget.dateStrip == null,
        leading: widget.dateStrip == null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: context.messages.dailyOsNextDayBack,
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: tokens.spacing.step2,
            ),
            child: PlanViewToggle(
              selected: _view,
              onChanged: (next) => setState(() => _view = next),
            ),
          ),
          const ProcessingCategoryFilterButton(),
          PopupMenuButton<_DayMenuAction>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: context.messages.dailyOsNextDayMoreTooltip,
            onSelected: (action) {
              switch (action) {
                case _DayMenuAction.inspectAgent:
                  unawaited(_openAgentInternals());
                case _DayMenuAction.deletePlan:
                  unawaited(_confirmDeletePlan());
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
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomNavHeight),
          child: Column(
            children: [
              CapturesPanel(date: widget.draft.dayDate),
              Expanded(
                child: _view == PlanView.agenda
                    ? AgendaView(draft: widget.draft)
                    : DayTimeline(
                        draft: widget.draft,
                        actualBlocks: actualBlocks,
                      ),
              ),
              _DayFooter(
                draft: widget.draft,
                onRefine: _openRefine,
                onCommit: _openCommit,
                onShutdown: _openShutdown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Container(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        border: Border(
          top: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
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
