import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The Check-ins section of the person page (design 2026-09-06 §3): one
/// section card holding the log, newest first — a count beside the title,
/// one [CheckInRow] per check-in, or the empty hint.
///
/// A sliver rather than a box because the log grows without bound: the
/// rows render lazily inside the card's decoration, the same split the
/// project page makes between its fixed sections and its list. The card's
/// surface is [DesignSystemSectionCard.decoration], so it is
/// indistinguishable from the boxed cards above and below it.
class CheckInsCardSliver extends StatelessWidget {
  const CheckInsCardSliver({
    required this.checkIns,
    required this.onOpen,
    super.key,
  });

  /// Newest first, as the repository hands them over.
  final List<CheckInEntry> checkIns;

  /// Opens one check-in for editing.
  final ValueChanged<CheckInEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final inset = tokens.spacing.step5;

    return DecoratedSliver(
      key: const ValueKey('person-check-ins-card'),
      decoration: DesignSystemSectionCard.decoration(tokens),
      sliver: SliverPadding(
        padding: EdgeInsets.all(inset),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: PersonCardHeader(
                title: messages.relationshipCheckInsLabel,
                caption: checkIns.isEmpty
                    ? null
                    : DsPill(
                        key: const ValueKey('person-check-ins-count'),
                        variant: DsPillVariant.filled,
                        shape: DsPillShape.tag,
                        labelColor: tokens.colors.text.mediumEmphasis,
                        label: '${checkIns.length}',
                      ),
              ),
            ),
            if (checkIns.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step3),
                  child: Text(
                    messages.relationshipNoCheckIns,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: checkIns.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: tokens.colors.decorative.level01),
                itemBuilder: (context, index) {
                  final checkIn = checkIns[index];
                  return CheckInRow(
                    key: ValueKey('check-in-row-${checkIn.meta.id}'),
                    checkIn: checkIn,
                    onTap: () => onOpen(checkIn),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// One check-in in the log: the interaction glyph in a circle, a mono meta
/// line (`Today 12:44 · Call · 11 min`) beside the tinted sentiment pill,
/// the narrative, and the topics as tag pills. The text keeps the row's
/// width: the glyph column is the only thing beside it.
class CheckInRow extends StatelessWidget {
  const CheckInRow({required this.checkIn, required this.onTap, super.key});

  final CheckInEntry checkIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final data = checkIn.data;
    final narrative = checkIn.entryText?.plainText.trim();
    final sentiment = data.sentiment;
    final duration = relationshipDurationLabelOf(
      context,
      checkIn.meta.dateTo.difference(checkIn.meta.dateFrom),
    );
    final meta = [
      relationshipTimestampLabelOf(context, checkIn.meta.dateFrom),
      checkInInteractionLabel(context, data.interactionType),
      ?duration,
    ].join(' · ');

    // The row supplies its own ink surface: inside a sliver there is no
    // section-card Material above it to draw the press on.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: tokens.spacing.step8,
                height: tokens.spacing.step8,
                decoration: BoxDecoration(
                  color: tokens.colors.background.level03,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  checkInInteractionIcon(data.interactionType),
                  size: IconSizes.m,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(width: tokens.spacing.step4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: tokens.spacing.step3,
                      runSpacing: tokens.spacing.step2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          meta,
                          key: const ValueKey('check-in-row-meta'),
                          style: relationshipTimestampStyle(
                            tokens,
                            color: tokens.colors.text.lowEmphasis,
                          ),
                        ),
                        if (sentiment != null)
                          DsPill(
                            key: const ValueKey('check-in-row-sentiment'),
                            variant: DsPillVariant.tinted,
                            shape: DsPillShape.tag,
                            color: sentimentColor(tokens, sentiment),
                            labelColor: tokens.colors.text.highEmphasis,
                            label: checkInSentimentLabel(context, sentiment),
                          ),
                      ],
                    ),
                    if (narrative != null && narrative.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.step2),
                      Text(
                        narrative,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                    ],
                    if (data.topics.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.step3),
                      // Topics are this check-in's tags, so they wear the tag
                      // pill the rest of the app spends on labels — the tight
                      // corner that says "read-out, not button".
                      Wrap(
                        spacing: tokens.spacing.step2,
                        runSpacing: tokens.spacing.step2,
                        children: [
                          for (final topic in data.topics)
                            DsPill(
                              variant: DsPillVariant.filled,
                              shape: DsPillShape.tag,
                              bordered: true,
                              label: topic,
                              labelColor: tokens.colors.text.mediumEmphasis,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
