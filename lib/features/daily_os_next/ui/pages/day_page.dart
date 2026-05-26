import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart'
    as agent_providers;
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_provider.dart';
import 'package:lotti/features/daily_os_next/ui/pages/commit_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/captures_panel.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
  late DraftPlan _draft = widget.draft;

  Future<void> _openRefine() async {
    final updated = await Navigator.of(context).push<DraftPlan>(
      MaterialPageRoute<DraftPlan>(
        builder: (_) => RefinePage(draft: _draft),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _draft = updated);
    }
  }

  Future<void> _openCommit() async {
    final committed = await Navigator.of(context).push<DraftPlan>(
      MaterialPageRoute<DraftPlan>(
        builder: (_) => CommitPage(draft: _draft),
      ),
    );
    if (committed != null && mounted) {
      setState(() => _draft = committed);
    }
  }

  Future<void> _openShutdown() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ShutdownPage(forDate: _draft.dayDate),
      ),
    );
  }

  /// Resolves the day-agent identity for the current day and beams the
  /// Settings stack onto the existing agent detail page so the user can
  /// inspect the wake history, conversation log, observations, and
  /// token usage that produced this plan.
  Future<void> _openAgentInternals() async {
    final identity = await ref.read(
      agent_providers.dayAgentProvider(_draft.dayDate).future,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: const Text(
          'The drafted blocks for this day will be removed. Captures and '
          'their audio recordings stay in your journal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final agent = ref.read(dayAgentProvider);
    await agent.deletePlanForDate(_draft.dayDate);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
          PopupMenuButton<_DayMenuAction>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More',
            onSelected: (action) {
              switch (action) {
                case _DayMenuAction.inspectAgent:
                  unawaited(_openAgentInternals());
                case _DayMenuAction.deletePlan:
                  unawaited(_confirmDeletePlan());
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<_DayMenuAction>(
                value: _DayMenuAction.inspectAgent,
                child: ListTile(
                  leading: Icon(Icons.psychology_alt_outlined),
                  title: Text('Inspect agent'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<_DayMenuAction>(
                value: _DayMenuAction.deletePlan,
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete plan'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          SizedBox(width: tokens.spacing.step2),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            CapturesPanel(date: _draft.dayDate),
            Expanded(
              child: _view == PlanView.agenda
                  ? AgendaView(draft: _draft)
                  : DayTimeline(draft: _draft),
            ),
            _DayFooter(
              draft: _draft,
              onRefine: _openRefine,
              onCommit: _openCommit,
              onShutdown: _openShutdown,
            ),
          ],
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.messages.dailyOsNextDayRefineFooterHint,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRefine,
            icon: Icon(Icons.mic_rounded, size: 14, color: teal),
            label: Text(context.messages.dailyOsNextDayRefineCta),
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
          ),
          SizedBox(width: tokens.spacing.step2),
          if (draft.state == DayState.drafted)
            FilledButton.icon(
              onPressed: onCommit,
              icon: const Icon(Icons.lock_outline_rounded, size: 14),
              label: Text(context.messages.dailyOsNextDayLockInCta),
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
          else
            OutlinedButton.icon(
              onPressed: onShutdown,
              icon: Icon(
                Icons.nights_stay_outlined,
                size: 14,
                color: tokens.colors.text.mediumEmphasis,
              ),
              label: Text(context.messages.dailyOsNextDayWrapUpCta),
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
            ),
        ],
      ),
    );
  }
}
