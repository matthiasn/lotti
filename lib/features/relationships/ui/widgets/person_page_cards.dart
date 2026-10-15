import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/next_time_facts.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// A section card's title row: the heading, an optional count beside it, an
/// optional free-form caption, and an optional trailing action — one shape
/// for every card on the person page.
///
/// [count] is text, not a chip. A number of check-ins is metadata about the
/// heading it follows, and rendering it as a filled pill made it look like
/// the tinted state chips two centimetres above it — the reader could not
/// tell which chips meant something and which were tappable. It reads in
/// the same `Label · N` grammar the page title and the list's band headings
/// already use, so one count convention covers the feature.
class PersonCardHeader extends StatelessWidget {
  const PersonCardHeader({
    required this.title,
    this.count,
    this.countKey,
    this.caption,
    this.trailing,
    super.key,
  });

  final String title;
  final int? count;

  /// Key for the count text, so a card can name its own count without the
  /// key existing on a header that has no count to show.
  final Key? countKey;
  final Widget? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Text(
          title,
          // `subtitle1`, not `subtitle2`: at 14 these titles sat *under*
          // the 16pt body they head, and under the Briefing card's own
          // title, so the person page had two heading tiers and the
          // quieter one led the louder content.
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        if (count != null) ...[
          SizedBox(width: tokens.spacing.step2),
          Text(
            '· $count',
            key: countKey,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ],
        if (caption != null) ...[
          SizedBox(width: tokens.spacing.step3),
          caption!,
        ],
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// The user's own notes for next time, at the head of *Before you talk*
/// (design panel 2026-10-15): what they last asked themselves to bring up,
/// and what to leave alone — sourced from their own words, never from the
/// agent, and set on the page itself, above the agent's card and outside its
/// tint, so they read as the user's. Renders nothing when [source] carries
/// neither.
///
/// [source] is the newest check-in that *has* such notes ([sourceOf]), not
/// simply the newest check-in. The two fields sit under the composer's
/// *More*, so a ten-second check-in leaves them blank — and blank there
/// means "I did not get to it", not "forget what I wrote last time". Reading
/// only the newest check-in made the quickest way to log a conversation
/// erase the notes this block exists to keep. Which check-in they are from
/// is said by the heading above ([provenanceOf]).
///
/// Both notes show on every width: what to leave alone matters as much as
/// what to bring up, and a fold over it was the tap forgotten in the minute
/// before a call (design panel 2026-10-15).
class NextTimeLead extends StatelessWidget {
  const NextTimeLead({
    required this.source,
    this.onOpenSource,
    super.key,
  });

  final CheckInEntry? source;

  /// Opens the check-in the notes are from; the provenance line is then a
  /// way into it.
  final VoidCallback? onOpenSource;

  /// The newest of [checkIns] (newest first) that carries next-time notes.
  static CheckInEntry? sourceOf(List<CheckInEntry> checkIns) {
    for (final checkIn in checkIns) {
      if (hasContent(checkIn)) return checkIn;
    }
    return null;
  }

  static String? _attentionOf(CheckInEntry? latest) =>
      _nonBlank(latest?.data.payAttentionTo);

  static String? _avoidOf(CheckInEntry? latest) =>
      _nonBlank(latest?.data.avoid);

  static String? _nonBlank(String? text) {
    final trimmed = text?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Whether the block would render anything for [latest].
  static bool hasContent(CheckInEntry? latest) =>
      _attentionOf(latest) != null || _avoidOf(latest) != null;

  /// The line naming the check-in [source] is from — *From your check-in on
  /// Sat 1 Aug* — set on the notes it describes, not on the section heading,
  /// which also holds the next meeting: undated notes would read as written
  /// after a conversation they predate.
  static Widget provenanceOf(BuildContext context, CheckInEntry source) {
    final tokens = context.designTokens;
    final day = relationshipDayLabelOf(context, source.meta.dateFrom);
    return RelationshipLineWithDate(
      key: const ValueKey('person-next-time-from'),
      text: context.messages.relationshipNextTimeFromEarlier(day),
      date: day,
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final from = source;
    final attention = _attentionOf(from);
    final avoid = _avoidOf(from);
    if (from == null || (attention == null && avoid == null)) {
      return const SizedBox.shrink();
    }
    final facts = [
      if (attention != null)
        (
          caption: messages.relationshipPayAttentionTo,
          text: attention,
          key: const ValueKey('person-next-time-attention'),
        ),
      if (avoid != null)
        (
          caption: messages.checkInAvoidLabel,
          text: avoid,
          key: const ValueKey('person-next-time-avoid'),
        ),
    ];
    final open = onOpenSource;
    final day = relationshipDayLabelOf(context, from.meta.dateFrom);
    return Column(
      key: const ValueKey('person-next-time'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NextTimeFacts(facts: facts),
        // Where the notes came from, after them and as a way into that
        // check-in: a quiet link with its chevron, set apart by the gap
        // between pairs so it reads as a footnote to both, never a third
        // grey label stacked on the last one.
        SizedBox(height: context.designTokens.spacing.step3),
        if (open == null)
          provenanceOf(context, from)
        else
          DesignSystemButton(
            key: const ValueKey('person-next-time-open'),
            label: messages.relationshipNextTimeFromEarlier(day),
            trailingIcon: LottiIcons.chevronRight,
            variant: DesignSystemButtonVariant.quiet,
            size: DesignSystemButtonSize.dense,
            alignsLabelToLeadingEdge: true,
            onPressed: open,
          ),
      ],
    );
  }
}

/// The person page's one disclosure: a quiet line led by its chevron, the
/// way the briefing's *Read more* is drawn, so every "there is more here"
/// on the page looks and reads the same (design panel 2026-10-15). Quiet,
/// not teal: opening a fold is not an action on the person.
Widget personDisclosure(
  BuildContext context, {
  required String label,
  required bool open,
  required VoidCallback onPressed,
  Key? key,
}) => DesignSystemButton(
  key: key,
  label: label,
  leadingIcon: open ? LottiIcons.chevronUp : LottiIcons.expand,
  variant: DesignSystemButtonVariant.quiet,
  size: DesignSystemButtonSize.dense,
  alignsLabelToLeadingEdge: true,
  onPressed: onPressed,
);
