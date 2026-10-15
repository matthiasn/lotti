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
/// [compact] (a phone) shows the first note and folds the second behind a
/// disclosure, so the person's history reaches the first screen.
class NextTimeLead extends StatefulWidget {
  const NextTimeLead({required this.source, this.compact = false, super.key});

  final CheckInEntry? source;
  final bool compact;

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
  /// Sat 1 Aug* — for the heading's caption slot: inside the page, undated
  /// notes would read as written after a conversation they predate.
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
  State<NextTimeLead> createState() => _NextTimeLeadState();
}

class _NextTimeLeadState extends State<NextTimeLead> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final from = widget.source;
    final attention = NextTimeLead._attentionOf(from);
    final avoid = NextTimeLead._avoidOf(from);
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
    final folded = widget.compact && !_expanded && facts.length > 1;
    return Column(
      key: const ValueKey('person-next-time'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NextTimeFacts(facts: folded ? facts.take(1).toList() : facts),
        if (widget.compact && facts.length > 1)
          DesignSystemButton(
            key: const ValueKey('person-next-time-toggle'),
            label: folded
                ? messages.relationshipNextTimeShowAvoid
                : messages.relationshipAboutShowLess,
            trailingIcon: folded ? LottiIcons.expand : LottiIcons.chevronUp,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.dense,
            alignsLabelToLeadingEdge: true,
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }
}
