import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/ui/pages/commit_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/refine_page.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/agenda_view.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_timeline.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Hosts the two read-only projections of the [DraftPlan] — Agenda
/// (intent) and Day (mechanics) — with a pill toggle at the top.
///
/// Agenda is the default surface per the prototype: it's the
/// "what today is about" view; Day is the "when does it happen"
/// projection a tap away. A footer pill opens the Refine screen for
/// voice-driven plan changes.
class DayPage extends StatefulWidget {
  const DayPage({required this.draft, super.key});

  final DraftPlan draft;

  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> {
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        title: Text(
          context.messages.dailyOsNextDayTitle,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.messages.dailyOsNextDayBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
