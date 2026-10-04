part of 'day_page.dart';

enum _QuickRefinement { tooMuch, moveLighter, addBuffer }

/// Hosts the three projections of the [DraftPlan] — Agenda (intent), Day
/// (mechanics) and Activity (what was said and recorded) — with a pill
/// toggle at the top.
///
/// Day is the default surface: the calendar-shaped "when does it happen"
/// projection, where planned blocks and the day's recorded time and events
/// sit on one time axis. Agenda ("what today is about") and Activity are a
/// tap away, and a pick survives day changes through
/// [dailyOsNextPlanViewProvider]. A footer pill opens the Refine screen for
/// voice-driven plan changes.
///
/// With no plan ([hasPlan] false — the route-level root passes a
/// synthetic empty [draft]) the page still lands on Day, so recorded
/// sessions and events stay visible on the timeline, and the footer carries
/// a single "Speak a check-in" CTA instead of Refine/Commit (handoff v2
/// item 2). Saved or recoverable recordings remain one tap away on Activity.
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

class _DayFooter extends StatelessWidget {
  const _DayFooter({
    required this.draft,
    required this.showCoachHint,
    required this.onRefine,
    required this.onQuickRefinement,
    required this.onCommit,
    required this.onShutdown,
  });

  final DraftPlan draft;

  /// One-shot coaching line — retired permanently after the first
  /// lock-in (the promise has been experienced; chrome stops narrating).
  final bool showCoachHint;

  final VoidCallback onRefine;
  final ValueChanged<_QuickRefinement> onQuickRefinement;
  final VoidCallback onCommit;
  final VoidCallback onShutdown;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final isDesktop = isDesktopLayout(context);
    // Coaching copy yields the fold to actionable rows at large
    // accessibility text sizes, and retires for good after the first
    // lock-in.
    final showHint =
        showCoachHint &&
        draft.state != DayState.drafted &&
        dailyOsTextScaleOf(context) < kDailyOsHideCoachingScale;
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
      onShutdown: onShutdown,
      expand: !isDesktop,
    );
    final actionLayout = isDesktop
        // Constrained to the agenda's reading width so the commit
        // actions belong to the content column, not the page chrome.
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                children: [
                  if (showHint) ...[
                    Expanded(child: hint),
                    SizedBox(width: tokens.spacing.step4),
                  ] else
                    const Spacer(),
                  actions,
                ],
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHint) ...[
                hint,
                SizedBox(height: tokens.spacing.step3),
              ],
              actions,
            ],
          );
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (draft.state == DayState.drafted) ...[
              _PlanReviewStrip(
                draft: draft,
                onLooksGood: onCommit,
                onQuickRefinement: onQuickRefinement,
              ),
              SizedBox(height: tokens.spacing.step4),
            ],
            actionLayout,
          ],
        ),
      ),
    );
  }
}

class _PlanReviewStrip extends StatelessWidget {
  const _PlanReviewStrip({
    required this.draft,
    required this.onLooksGood,
    required this.onQuickRefinement,
  });

  final DraftPlan draft;
  final VoidCallback onLooksGood;
  final ValueChanged<_QuickRefinement> onQuickRefinement;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final textScale = dailyOsTextScaleOf(context);
    final reasons = textScale < kDailyOsHideCoachingScale
        ? _planReasons(draft)
        : const <String>[];
    final compactActions =
        !isDesktopLayout(context) || textScale >= kDailyOsHideCoachingScale;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reasons.isNotEmpty) ...[
              Text(
                messages.dailyOsNextReviewWhyTitle,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step2),
              for (final reason in reasons) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LottiIcons.aiSpark,
                      size: tokens.spacing.step4,
                      color: tokens.colors.interactive.enabled,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Expanded(
                      child: Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.step2),
              ],
              SizedBox(height: tokens.spacing.step2),
            ],
            if (compactActions)
              _CompactReviewActions(
                onLooksGood: onLooksGood,
                onQuickRefinement: onQuickRefinement,
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: tokens.spacing.step2,
                runSpacing: tokens.spacing.step2,
                children: [
                  FilledButton.icon(
                    onPressed: onLooksGood,
                    icon: const Icon(LottiIcons.confirm),
                    label: Text(messages.dailyOsNextReviewLooksGood),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        onQuickRefinement(_QuickRefinement.tooMuch),
                    icon: const Icon(LottiIcons.removeCircled),
                    label: Text(messages.dailyOsNextReviewTooMuch),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        onQuickRefinement(_QuickRefinement.moveLighter),
                    icon: const Icon(LottiIcons.lowPriority),
                    label: Text(messages.dailyOsNextReviewMoveLighter),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        onQuickRefinement(_QuickRefinement.addBuffer),
                    icon: const Icon(LottiIcons.add),
                    label: Text(messages.dailyOsNextReviewAddBuffer),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<String> _planReasons(DraftPlan draft) {
    final reasons = <String>[];
    final seen = <String>{};
    for (final block in draft.blocks) {
      final reason = block.reason?.trim();
      if (reason == null || reason.isEmpty || !seen.add(reason)) continue;
      reasons.add(reason);
      if (reasons.length == 2) break;
    }
    return reasons;
  }
}

class _CompactReviewActions extends StatelessWidget {
  const _CompactReviewActions({
    required this.onLooksGood,
    required this.onQuickRefinement,
  });

  final VoidCallback onLooksGood;
  final ValueChanged<_QuickRefinement> onQuickRefinement;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onLooksGood,
          icon: const Icon(LottiIcons.confirm),
          label: Text(
            messages.dailyOsNextReviewLooksGood,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        PopupMenuButton<_QuickRefinement>(
          tooltip: messages.dailyOsNextReviewAdjust,
          onSelected: onQuickRefinement,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _QuickRefinement.tooMuch,
              child: _QuickReviewMenuItem(
                icon: LottiIcons.removeCircled,
                label: messages.dailyOsNextReviewTooMuch,
              ),
            ),
            PopupMenuItem(
              value: _QuickRefinement.moveLighter,
              child: _QuickReviewMenuItem(
                icon: LottiIcons.lowPriority,
                label: messages.dailyOsNextReviewMoveLighter,
              ),
            ),
            PopupMenuItem(
              value: _QuickRefinement.addBuffer,
              child: _QuickReviewMenuItem(
                icon: LottiIcons.add,
                label: messages.dailyOsNextReviewAddBuffer,
              ),
            ),
          ],
          child: _ReviewAdjustButton(label: messages.dailyOsNextReviewAdjust),
        ),
      ],
    );
  }
}

class _ReviewAdjustButton extends StatelessWidget {
  const _ReviewAdjustButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: teal.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LottiIcons.tune, size: 18, color: teal),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step1),
            Icon(LottiIcons.expand, size: 18, color: teal),
          ],
        ),
      ),
    );
  }
}

class _QuickReviewMenuItem extends StatelessWidget {
  const _QuickReviewMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: tokens.colors.interactive.enabled),
        SizedBox(width: tokens.spacing.step3),
        Flexible(child: Text(label)),
      ],
    );
  }
}

/// The day footer's action row for a committed plan: refine / commit /
/// shutdown buttons. [expand] switches between the wide side-by-side layout
/// and a stacked layout on narrow widths.
class _DayFooterActions extends StatelessWidget {
  const _DayFooterActions({
    required this.draft,
    required this.teal,
    required this.onRefine,
    required this.onShutdown,
    required this.expand,
  });

  final DraftPlan draft;
  final Color teal;
  final VoidCallback onRefine;
  final VoidCallback onShutdown;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final refineButton = OutlinedButton.icon(
      onPressed: onRefine,
      icon: Icon(LottiIcons.mic, size: 14, color: teal),
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
    if (draft.state == DayState.drafted) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (expand) Expanded(child: refineButton) else refineButton,
        ],
      );
    }
    final primaryButton = OutlinedButton.icon(
      onPressed: onShutdown,
      icon: Icon(
        LottiIcons.night,
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
  const _NoPlanFooter({
    required this.onCheckIn,
    required this.needsInferenceSetup,
    required this.ctaKey,
  });

  final VoidCallback? onCheckIn;
  final bool needsInferenceSetup;

  /// Measurement key for the onboarding spotlight to anchor to. The stable
  /// [Key] used as a test finder stays on the button regardless.
  final GlobalKey ctaKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final button = FilledButton.icon(
      key: const Key('daily_os_day_check_in_cta'),
      onPressed: onCheckIn,
      icon: Icon(
        needsInferenceSetup ? LottiIcons.settings : LottiIcons.mic,
        size: 14,
      ),
      label: Text(
        needsInferenceSetup
            ? context.messages.dailyOsSettingsSetupAction
            : context.messages.dailyOsNextDayCheckInCta,
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
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
      ),
    );
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step6,
          vertical: tokens.spacing.step4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The onboarding spotlight measures the CTA through this wrapper
            // key; the stable Key on the button stays put for test finders.
            KeyedSubtree(key: ctaKey, child: button),
          ],
        ),
      ),
    );
  }
}

class _DailyOsSetupNudge extends StatelessWidget {
  const _DailyOsSetupNudge({
    required this.status,
    required this.onOpenSettings,
  });

  final DailyOsSetupStatus status;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final inferenceMissing = !status.hasInferenceRoute;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Row(
            children: [
              Icon(
                inferenceMissing ? LottiIcons.warning : LottiIcons.personAdd,
                color: tokens.colors.interactive.enabled,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inferenceMissing
                          ? context.messages.dailyOsSettingsSetupRequiredTitle
                          : context.messages.dailyOsSettingsNameNudgeTitle,
                      style: tokens.typography.styles.subtitle.subtitle2,
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      inferenceMissing
                          ? [
                              context.messages.dailyOsSettingsSetupRequiredBody,
                              if (!status.hasPreferredName)
                                context.messages.dailyOsSettingsNameNudgeBody,
                            ].join(' ')
                          : context.messages.dailyOsSettingsNameNudgeBody,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.spacing.step3),
              TextButton(
                onPressed: onOpenSettings,
                child: Text(
                  inferenceMissing
                      ? context.messages.dailyOsSettingsSetupAction
                      : context.messages.dailyOsSettingsNameNudgeAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
