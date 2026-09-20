import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_actions.dart';
import 'package:lotti/features/relationships/state/relationship_nudge_providers.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Says, on the person's page, that the reminder the user just tapped is
/// paused and until when (ADR 0063) — the tap did something, and here is
/// what — with *Snooze longer* for when an hour is not enough. Renders
/// nothing while no reminder is paused that way.
///
/// [bottomGap] follows the callout, so the page's sections keep one rhythm
/// whether or not it is there.
class PausedReminderCallout extends ConsumerWidget {
  const PausedReminderCallout({
    required this.relationshipId,
    required this.bottomGap,
    super.key,
  });

  final String relationshipId;
  final double bottomGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = ref
        .watch(pausedRelationshipReminderProvider(relationshipId))
        .value;
    if (paused == null) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final messages = context.messages;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: DesignSystemInlineCallout(
        key: const ValueKey('person-reminder-paused'),
        icon: LottiIcons.snooze,
        tone: tokens.colors.alert.info.defaultColor,
        // The same timestamp form the rest of the feature uses. This
        // read the device's 12/24-hour clock in proportional type, one
        // card above a mono 24-hour one — two clocks, one page.
        title: messages.relationshipReminderPausedTitle(
          relationshipTimestampLabelOf(context, paused.until.toLocal()),
        ),
        text: messages.relationshipReminderPausedBody,
        actions: [
          DesignSystemButton(
            key: const ValueKey('person-reminder-snooze-longer'),
            label: messages.relationshipReminderSnoozeLonger,
            leadingIcon: LottiIcons.snooze,
            variant: DesignSystemButtonVariant.tertiary,
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: () =>
                showNudgeBannerSnoozeSheet(context, ref, paused.entry),
          ),
        ],
      ),
    );
  }
}
