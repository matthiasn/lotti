import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_charter_providers.dart';
import 'package:lotti/features/goals/ui/charter/goal_charter_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// *About this goal*: the goal's charter (ADR 0140) — what the user wrote
/// the goal is for and how its agent should coach, which the agent reads on
/// every wake.
///
/// Each entry opens its sheet to edit; the header adds another. With no
/// charter yet, the card invites one, since a goal with soft criteria has
/// nowhere else to say what it is about. A charter longer than one wake can
/// carry says so, because the agent would otherwise silently read half of it.
class GoalCharterCard extends ConsumerWidget {
  const GoalCharterCard({
    required this.agentId,
    required this.editable,
    super.key,
  });

  final String agentId;

  /// False on a dormant goal: its charter still reads, but nothing is added
  /// or changed — the same gate the check-ins card applies.
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // `.value` keeps the last charter on screen while a background re-read
    // runs, so an edit synced in never flashes the card empty.
    final entries = ref.watch(goalCharterEntriesProvider(agentId)).value;
    if (entries == null || (entries.isEmpty && !editable)) {
      return const SizedBox.shrink();
    }
    void open([JournalEntry? entry]) => showGoalCharterSheet(
      context: context,
      agentId: agentId,
      entry: entry,
    );

    // The card owns the gap above it, so a card that renders nothing leaves
    // no hole in the page's otherwise even stack.
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.cardItemSpacing),
      child: DesignSystemSectionCard(
        key: const ValueKey('goal-charter-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    messages.goalCharterTitle,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
                if (editable && entries.isNotEmpty)
                  IconButton(
                    key: const ValueKey('goal-charter-add'),
                    onPressed: open,
                    tooltip: messages.goalCharterAdd,
                    icon: Icon(
                      LottiIcons.addCircled,
                      color: tokens.colors.interactive.enabled,
                    ),
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            if (entries.isEmpty) ...[
              Text(
                messages.goalCharterEmpty,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DesignSystemButton(
                  key: const ValueKey('goal-charter-empty-cta'),
                  label: messages.goalCharterAdd,
                  leadingIcon: LottiIcons.edit,
                  variant: DesignSystemButtonVariant.secondary,
                  onPressed: open,
                ),
              ),
            ] else ...[
              for (final (index, entry) in entries.indexed) ...[
                if (index > 0) SizedBox(height: tokens.spacing.step2),
                _GoalCharterEntryTile(
                  entry: entry,
                  onTap: editable ? () => open(entry) : null,
                ),
              ],
              if (!goalCharterFitsBudget(entries)) ...[
                SizedBox(height: tokens.spacing.step3),
                Row(
                  key: const ValueKey('goal-charter-over-budget'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LottiIcons.warning,
                      size: IconSizes.s,
                      color: tokens.colors.alert.warning.defaultColor,
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Expanded(
                      child: Text(
                        messages.goalCharterOverBudget,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// One charter entry, in full: the user wrote it for the agent to read word
/// for word, so the page shows it the same way.
class _GoalCharterEntryTile extends StatelessWidget {
  const _GoalCharterEntryTile({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final text = Text(
      entry.entryText?.plainText.trim() ?? '',
      style: tokens.typography.styles.body.bodyMedium.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
    final tap = onTap;
    if (tap == null) return text;
    return DsQuietInk(
      key: ValueKey('goal-charter-entry-${entry.meta.id}'),
      onTap: tap,
      borderRadius: BorderRadius.circular(tokens.radii.s),
      builder: (context, highlighted) => Padding(
        padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
        child: text,
      ),
    );
  }
}
