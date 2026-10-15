import 'package:lotti/classes/journal_entities.dart';
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
/// agent, and so set above the agent's summary rather than in a card of
/// their own that said the same thing again. Renders nothing when [source]
/// carries neither.
///
/// [source] is the newest check-in that *has* such notes ([sourceOf]), not
/// simply the newest check-in. The two fields sit under the composer's
/// *More*, so a ten-second check-in leaves them blank — and blank there
/// means "I did not get to it", not "forget what I wrote last time". Reading
/// only the newest check-in made the quickest way to log a conversation
/// erase the notes this block exists to keep.
///
/// The caption always says whose words these are and which day they are
/// from: inside the agent's card, undated and unattributed, they would read
/// as the agent's.
class NextTimeLead extends StatelessWidget {
  const NextTimeLead({required this.source, super.key});

  final CheckInEntry? source;

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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final from = source;
    final attention = _attentionOf(from);
    final avoid = _avoidOf(from);
    if (from == null || (attention == null && avoid == null)) {
      return const SizedBox.shrink();
    }
    final day = relationshipDayLabelOf(context, from.meta.dateFrom);

    return Column(
      key: const ValueKey('person-next-time'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RelationshipLineWithDate(
          key: const ValueKey('person-next-time-from'),
          text: messages.relationshipNextTimeYourNotes(day),
          date: day,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        NextTimeFacts(
          facts: [
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
          ],
        ),
      ],
    );
  }
}
