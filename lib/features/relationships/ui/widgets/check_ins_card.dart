import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_palette.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_interactions.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_surface.dart';
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
/// The rows are the app's grouped-card rows, the same surface the Tasks and
/// Projects lists use ([GroupedCardRowSurface]): edge to edge inside the
/// card, the hover fill spanning the whole row, the last one rounded into the
/// card's corners, and the divider beside a hovered row giving way to its
/// fill ([buildGroupedCardRowInteractions]).
///
/// A sliver rather than a box because the log grows without bound: the
/// rows render lazily inside the card's decoration, the same split the
/// project page makes between its fixed sections and its list. The card's
/// surface is [DesignSystemSectionCard.decoration], so it is
/// indistinguishable from the boxed cards above and below it.
class CheckInsCardSliver extends StatefulWidget {
  const CheckInsCardSliver({
    required this.checkIns,
    required this.onOpen,
    this.entries = const {},
    super.key,
  });

  /// Newest first, as the repository hands them over.
  final List<CheckInEntry> checkIns;

  /// Each check-in's comments, recordings and photos, oldest first.
  final Map<String, List<JournalEntity>> entries;

  /// Opens one check-in.
  final ValueChanged<CheckInEntry> onOpen;

  @override
  State<CheckInsCardSliver> createState() => _CheckInsCardSliverState();
}

class _CheckInsCardSliverState extends State<CheckInsCardSliver> {
  String? _hoveredId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final inset = tokens.spacing.step5;
    final checkIns = widget.checkIns;
    final interactions = buildGroupedCardRowInteractions(
      priorities: [
        for (final checkIn in checkIns)
          if (checkIn.meta.id == _hoveredId) 1 else 0,
      ],
      connectedBelow: [
        for (var i = 0; i < checkIns.length - 1; i++) true,
      ],
    );

    return DecoratedSliver(
      key: const ValueKey('person-check-ins-card'),
      decoration: DesignSystemSectionCard.decoration(tokens),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              inset,
              inset,
              inset,
              checkIns.isEmpty ? 0 : tokens.spacing.step3,
            ),
            sliver: SliverToBoxAdapter(
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
          ),
          if (checkIns.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                inset,
                tokens.spacing.step3,
                inset,
                inset,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  messages.relationshipNoCheckIns,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: checkIns.length,
              itemBuilder: (context, index) {
                final checkIn = checkIns[index];
                final last = index == checkIns.length - 1;
                return CheckInRow(
                  key: ValueKey('check-in-row-${checkIn.meta.id}'),
                  checkIn: checkIn,
                  entries: widget.entries[checkIn.meta.id] ?? const [],
                  interaction: interactions[index],
                  isLast: last,
                  onHoverChanged: (hovered) => setState(() {
                    if (hovered) {
                      _hoveredId = checkIn.meta.id;
                    } else if (_hoveredId == checkIn.meta.id) {
                      _hoveredId = null;
                    }
                  }),
                  onTap: () => widget.onOpen(checkIn),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// One check-in in the log: the interaction glyph in a circle, a mono meta
/// line (`Today 12:44 · Call · 11 min · 1 recording`) with the tinted
/// sentiment pill in a fixed trailing slot, up to two lines of what was
/// said, and the topics as tag pills — with a chevron, because the row opens
/// the check-in.
class CheckInRow extends StatelessWidget {
  const CheckInRow({
    required this.checkIn,
    required this.onTap,
    this.entries = const [],
    this.interaction = const GroupedCardRowInteraction(),
    this.isLast = true,
    this.onHoverChanged,
    super.key,
  });

  final CheckInEntry checkIn;

  /// What the check-in holds, oldest first.
  final List<JournalEntity> entries;
  final VoidCallback onTap;

  /// How the row meets its neighbours: seams hidden beside a hovered row,
  /// a divider between two resting ones.
  final GroupedCardRowInteraction interaction;

  /// The last row rounds into the section card's bottom corners.
  final bool isLast;
  final ValueChanged<bool>? onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final data = checkIn.data;
    final narrative = checkInSummaryOf(context, checkIn, entries);
    final holds = checkInHoldsLabelOf(context, entries);
    final sentiment = data.sentiment;
    final duration = relationshipDurationLabelOf(
      context,
      checkIn.meta.dateTo.difference(checkIn.meta.dateFrom),
    );
    final meta = [
      relationshipTimestampLabelOf(context, checkIn.meta.dateFrom),
      checkInInteractionLabel(context, data.interactionType),
      ?duration,
      ?holds,
    ].join(' · ');
    final inset = tokens.spacing.step5;
    final radius = Radius.circular(tokens.radii.sectionCards);

    return GroupedCardRowSurface(
      rowKey: ValueKey('check-in-row-surface-${checkIn.meta.id}'),
      backgroundKey: ValueKey('check-in-row-background-${checkIn.meta.id}'),
      selected: false,
      hoverColor: tokens.colors.surface.hover,
      selectedColor: DesignSystemListPalette.activatedFill(tokens),
      padding: EdgeInsets.zero,
      topOverlap: interaction.topOverlap,
      bottomOverlap: interaction.bottomOverlap,
      backgroundBorderRadius: isLast
          ? BorderRadius.vertical(bottom: radius)
          : null,
      onHoverChanged: onHoverChanged,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              inset,
              tokens.spacing.step4,
              tokens.spacing.step3,
              tokens.spacing.step4,
            ),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: tokens.spacing.step1,
                              ),
                              child: Text(
                                meta,
                                key: const ValueKey('check-in-row-meta'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: relationshipTimestampStyle(
                                  tokens,
                                  color: tokens.colors.text.lowEmphasis,
                                ),
                              ),
                            ),
                          ),
                          if (sentiment != null) ...[
                            SizedBox(width: tokens.spacing.step3),
                            DsPill(
                              key: const ValueKey('check-in-row-sentiment'),
                              variant: DsPillVariant.tinted,
                              shape: DsPillShape.tag,
                              color: sentimentColor(tokens, sentiment),
                              labelColor: tokens.colors.text.highEmphasis,
                              label: checkInSentimentLabel(context, sentiment),
                            ),
                          ],
                        ],
                      ),
                      if (narrative != null) ...[
                        SizedBox(height: tokens.spacing.step2),
                        Text(
                          narrative.text,
                          key: const ValueKey('check-in-row-summary'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: narrative.pending
                                    ? tokens.colors.text.mediumEmphasis
                                    : tokens.colors.text.highEmphasis,
                              ),
                        ),
                      ],
                      if (data.topics.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing.step3),
                        // Topics are this check-in's tags, so they wear the
                        // tag pill the rest of the app spends on labels — the
                        // tight corner that says "read-out, not button".
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
                SizedBox(width: tokens.spacing.step2),
                Padding(
                  padding: EdgeInsets.only(top: tokens.spacing.step1),
                  child: Icon(
                    LottiIcons.chevronRight,
                    key: const ValueKey('check-in-row-chevron'),
                    size: IconSizes.m,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            if (interaction.showDividerBelow)
              Divider(
                key: ValueKey('check-in-row-divider-${checkIn.meta.id}'),
                height: 1,
                thickness: 1,
                color: tokens.colors.decorative.level01,
              )
            else
              const SizedBox(height: 1),
        ],
      ),
    );
  }
}

/// The words a check-in row leads with: the text it was saved with, else its
/// first comment or transcript. Only when nothing it holds has words yet
/// does a recording without them say so (`pending`), so a fresh dictation
/// never reads as an empty check-in — and a recording still waiting never
/// hides a comment that has words. Null when the check-in holds no words
/// at all (only photos).
({String text, bool pending})? checkInSummaryOf(
  BuildContext context,
  CheckInEntry checkIn,
  List<JournalEntity> entries,
) {
  final saved = checkIn.entryText?.plainText.trim() ?? '';
  if (saved.isNotEmpty) return (text: saved, pending: false);
  var awaitingWords = false;
  for (final entry in entries) {
    if (entry is JournalImage) continue;
    final words = entry.entryText?.plainText.trim() ?? '';
    if (words.isNotEmpty) return (text: words, pending: false);
    if (entry is JournalAudio) awaitingWords = true;
  }
  return awaitingWords
      ? (text: context.messages.checkInTranscribingLabel, pending: true)
      : null;
}

/// What a check-in holds, as one quiet line — `2 recordings · 1 photo` — or
/// null when it holds nothing but the text it leads with.
String? checkInHoldsLabelOf(BuildContext context, List<JournalEntity> entries) {
  final messages = context.messages;
  final recordings = entries.whereType<JournalAudio>().length;
  final photos = entries.whereType<JournalImage>().length;
  // A blank comment — started and not yet written — holds nothing.
  final comments = entries
      .whereType<JournalEntry>()
      .where((e) => (e.entryText?.plainText.trim() ?? '').isNotEmpty)
      .length;
  final parts = [
    if (recordings > 0) messages.relationshipCheckInRecordingCount(recordings),
    if (photos > 0) messages.relationshipCheckInPhotoCount(photos),
    if (comments > 0) messages.relationshipCheckInCommentCount(comments),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
