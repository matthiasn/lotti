import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_checkin_providers.dart';
import 'package:lotti/features/goals/ui/checkins/goal_checkin_timeline.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The goal page's check-ins: a heading carrying the count, a bounded
/// preview of the rail, and a way through to the rest — set on the page
/// itself, as a person's timeline is, not boxed in a card of its own.
///
/// It carries no create control. Saying something about the goal is the
/// page's *Speak* bar, always in reach; a second mic here — and a third in
/// the empty state — made three doors to one sheet, one of them a plus that
/// recorded. The empty section says what a check-in is for and leaves the
/// doing to the bar.
///
/// One composition, rendered in two places — inline on the detail list on a
/// phone, in the desktop rail — so the two can never drift.
class GoalCheckInsSection extends ConsumerWidget {
  const GoalCheckInsSection({
    required this.agentId,
    this.onSeeAll,
    this.onOpenReflection,
    this.maxBeats,
    super.key,
  });

  final String agentId;

  /// Pushes the full timeline. Null hides the row, which is what the desktop
  /// rail wants since it is already showing everything.
  final VoidCallback? onSeeAll;

  final ValueChanged<DateTime>? onOpenReflection;
  final int? maxBeats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final total = ref.watch(goalTimelineItemsProvider(agentId)).length;
    final hasMore = maxBeats != null && total > maxBeats!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The timeline's rows carry their own inset, for the hover wash to
        // stand clear of the edge; the heading takes it too, as the person
        // timeline's does, so heading and rows share one left edge.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
          child: Text(
            // One localized message rather than a Dart-side join: the
            // separator and the word order are translators' business.
            total == 0
                ? context.messages.goalCheckInsTitle
                : context.messages.goalCheckInsTitleWithCount(total),
            key: const ValueKey('goal-checkins-heading'),
            // A page section's heading, the person timeline's tier.
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        GoalCheckInTimeline(
          agentId: agentId,
          maxBeats: maxBeats,
          onOpenReflection: onOpenReflection,
        ),
        if (hasMore && onSeeAll != null) ...[
          SizedBox(height: tokens.spacing.step2),
          // A text link, not a button: the link's own ink lifts a step on
          // hover instead of washing a rectangle across the section.
          DsQuietInk(
            key: const ValueKey('goal-checkin-see-all'),
            onTap: onSeeAll,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            builder: (context, highlighted) {
              final ink = highlighted
                  ? tokens.colors.interactive.hover
                  : tokens.colors.interactive.enabled;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.messages.goalCheckInsSeeAll,
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: ink,
                      ),
                    ),
                    Icon(
                      LottiIcons.chevronRight,
                      size: IconSizes.xs,
                      color: ink,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
