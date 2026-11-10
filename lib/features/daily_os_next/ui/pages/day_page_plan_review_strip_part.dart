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
/// [dailyOsNextPlanViewProvider]. With a plan, the footer is the composer
/// asking what should change (spoken or typed straight into Refine), with the
/// day's next step — "Looks good" or "Wrap up" — beside its field.
///
/// With no plan ([hasPlan] false — the route-level root passes a
/// synthetic empty [draft]) the page still lands on Day, so recorded
/// sessions and events stay visible on the timeline, and the footer is the
/// [DayComposer] instead of Refine/Commit: talk or type a check-in from
/// where you are. Saved or recoverable recordings remain one tap away on
/// Activity.
class DayPage extends ConsumerStatefulWidget {
  const DayPage({
    required this.draft,
    this.hasPlan = true,
    this.onCheckIn,
    this.onSubmitCheckIn,
    this.navigation,
    super.key,
  });

  final DraftPlan draft;

  /// False when [draft] is a synthetic empty aggregate for a day
  /// without a drafted plan.
  final bool hasPlan;

  /// Opens the full check-in ritual (Capture → Reconcile → Drafting) —
  /// the onboarding spotlight's call.
  final VoidCallback? onCheckIn;

  /// Continues a check-in spoken or typed into the empty-state composer:
  /// the words, and the recording behind them when they were spoken.
  final DayComposerSubmitter? onSubmitCheckIn;

  /// Day navigation for the header's masthead and week strip. The
  /// route-level `DailyOsNextRoot` supplies it; without it the header leads
  /// with a back chevron instead.
  final DayNavigation? navigation;

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

/// A planned day's footer: the same composer as the empty day's check-in,
/// asking what should change. What is said or typed goes straight into
/// Refine, which proposes the change for review. While the plan is still a
/// draft the quick refinements ride above the field as chips (hidden at large
/// accessibility text sizes, where they would crowd out the day), and the
/// day's next step sits beside the field, in thumb reach.
class _DayReviewFooter extends StatelessWidget {
  const _DayReviewFooter({
    required this.draft,
    required this.onRefineWords,
    required this.onQuickRefinement,
    required this.onCommit,
    required this.onShutdown,
  });

  final DraftPlan draft;
  final Future<void> Function(String words) onRefineWords;
  final ValueChanged<_QuickRefinement> onQuickRefinement;
  final VoidCallback onCommit;
  final VoidCallback onShutdown;

  @override
  Widget build(BuildContext context) {
    // At large accessibility text sizes the chips would take the timeline's
    // room; the same requests are a sentence away in the field.
    final showChips =
        draft.state == DayState.drafted &&
        dailyOsTextScaleOf(context) < kDailyOsHideCoachingScale;
    return DayComposer(
      day: draft.dayDate,
      barKey: const Key('daily_os_day_refine_composer'),
      hintText: context.messages.dailyOsNextRefineHeadlineIdle,
      intent: AudioCaptureIntent.dayRefine,
      clearOnSubmit: true,
      header: showChips
          ? _QuickRefinementChips(onSelected: onQuickRefinement)
          : null,
      nextStep: _DayStageAction(
        draft: draft,
        onCommit: onCommit,
        onShutdown: onShutdown,
      ),
      onSubmit: (words, {audioId}) => onRefineWords(words),
    );
  }
}

/// The drafted plan's one-tap refinements, each sent to Refine as if said.
class _QuickRefinementChips extends StatelessWidget {
  const _QuickRefinementChips({required this.onSelected});

  final ValueChanged<_QuickRefinement> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    DesignSystemChip chip(
      _QuickRefinement refinement,
      IconData icon,
      String label,
    ) => DesignSystemChip(
      label: label,
      leadingIcon: icon,
      outlined: true,
      size: DesignSystemChipSize.compactPillTouch,
      onPressed: () => onSelected(refinement),
    );
    // One row at any width: a narrow phone scrolls it rather than stacking
    // chips over the day.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: tokens.spacing.step2,
        children: [
          chip(
            _QuickRefinement.tooMuch,
            LottiIcons.removeCircled,
            messages.dailyOsNextReviewTooMuch,
          ),
          chip(
            _QuickRefinement.moveLighter,
            LottiIcons.lowPriority,
            messages.dailyOsNextReviewMoveLighter,
          ),
          chip(
            _QuickRefinement.addBuffer,
            LottiIcons.add,
            messages.dailyOsNextReviewAddBuffer,
          ),
        ],
      ),
    );
  }
}

/// The day's next step, beside the footer's field: "Looks good" commits a
/// drafted day (with Undo on its toast); once committed, "Wrap up" opens the
/// shutdown. Either way it is the page's one filled button — the day's next
/// step is always its primary action.
class _DayStageAction extends StatelessWidget {
  const _DayStageAction({
    required this.draft,
    required this.onCommit,
    required this.onShutdown,
  });

  final DraftPlan draft;
  final VoidCallback onCommit;
  final VoidCallback onShutdown;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final drafted = draft.state == DayState.drafted;
    return DesignSystemButton(
      key: const Key('daily_os_day_stage_action'),
      label: drafted
          ? messages.dailyOsNextReviewLooksGood
          : messages.dailyOsNextDayWrapUpCta,
      size: DesignSystemButtonSize.large,
      onPressed: drafted ? onCommit : onShutdown,
    );
  }
}

/// Footer for a day without a drafted plan: the [DayComposer], so a
/// check-in is spoken or typed right where the day's tracked time is. When
/// Daily OS has no inference route yet the composer would lead nowhere, so
/// the footer is the single "Set up Daily OS" action instead.
class _NoPlanFooter extends StatelessWidget {
  const _NoPlanFooter({
    required this.day,
    required this.onSubmitCheckIn,
    required this.onOpenSetup,
    required this.needsInferenceSetup,
    required this.setupResolved,
    required this.ctaKey,
  });

  final DateTime day;
  final DayComposerSubmitter? onSubmitCheckIn;
  final VoidCallback onOpenSetup;
  final bool needsInferenceSetup;

  /// Whether the Daily OS setup status has loaded. Until it has, the
  /// composer shows closed: words typed into it would be thrown away if the
  /// status then says setup is missing and the setup action takes its place.
  final bool setupResolved;

  /// Measurement key for the onboarding spotlight to anchor to. The stable
  /// [Key] used as a test finder stays on the footer's control regardless.
  final GlobalKey ctaKey;

  @override
  Widget build(BuildContext context) {
    final onSubmitCheckIn = this.onSubmitCheckIn;
    if (!needsInferenceSetup) {
      return KeyedSubtree(
        key: ctaKey,
        child: DayComposer(
          day: day,
          enabled: setupResolved && onSubmitCheckIn != null,
          onSubmit: (words, {audioId}) async =>
              onSubmitCheckIn?.call(words, audioId: audioId),
        ),
      );
    }
    final tokens = context.designTokens;
    final button = DesignSystemButton(
      key: const Key('daily_os_day_check_in_cta'),
      label: context.messages.dailyOsSettingsSetupAction,
      leadingIcon: LottiIcons.settings,
      onPressed: onOpenSetup,
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

/// Settings that need the user's attention — no inference route, or no
/// name to address them by — as one plain row in the nudge slot under the
/// header: a glyph and its words in `alert.warning` ink, and the action that
/// fixes it. No card of its own, so it does not compete with the briefing.
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
    final messages = context.messages;
    final ink = tokens.colors.alert.warning.ink;
    final inferenceMissing = !status.hasInferenceRoute;
    return Padding(
      key: const Key('daily_os_setup_nudge'),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: Row(
        children: [
          Icon(
            inferenceMissing ? LottiIcons.warning : LottiIcons.personAdd,
            size: tokens.typography.size.subtitle2,
            color: ink,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inferenceMissing
                      ? messages.dailyOsSettingsSetupRequiredTitle
                      : messages.dailyOsSettingsNameNudgeTitle,
                  style: captionLabelStyle(tokens, color: ink),
                ),
                Text(
                  inferenceMissing
                      ? [
                          messages.dailyOsSettingsSetupRequiredBody,
                          if (!status.hasPreferredName)
                            messages.dailyOsSettingsNameNudgeBody,
                        ].join(' ')
                      : messages.dailyOsSettingsNameNudgeBody,
                  style: tokens.typography.styles.others.caption.copyWith(
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
                  ? messages.dailyOsSettingsSetupAction
                  : messages.dailyOsSettingsNameNudgeAction,
            ),
          ),
        ],
      ),
    );
  }
}
