import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The card above the People list (design 2026-09-06 §2, the Goals list's
/// summary card): how many enrolled people are due right now, who lapses
/// next and when, and how many people the agent is not watching at all.
///
/// The due count carries the warning ink only while it is non-zero — a calm
/// morning reads as a quiet `0 / 4 enrolled`, not as a warning about nothing.
class PeopleSummaryCard extends StatelessWidget {
  const PeopleSummaryCard({
    required this.summary,
    this.onOpenNextDue,
    super.key,
  });

  final PeopleSummary summary;

  /// Opens one of the two people the card is about. The card was the
  /// largest, most saturated block on the tab and did nothing at all — it
  /// named a person and then made the reader go and find them.
  ///
  /// Each half opens its own subject: the count opens the person it is
  /// counting (the longest lapse), the right half opens the one it names.
  final void Function(String relationshipId)? onOpenNextDue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final styles = tokens.typography.styles;
    final nextDue = summary.nextDue;
    final nextDueAt = summary.nextDueAt;
    // The nickname where there is one: the card names a person the way the
    // user talks about them ("Next due Bo"), and a full name wraps the line.
    final nextDueName =
        nextDue?.relationship.data.nickname ?? nextDue?.relationship.data.title;
    // Kept apart so the day can wear the timestamp style the rows already
    // give a date: the card sits directly above a column of tabular
    // timestamps and set its own date in plain type.
    final nextDueDay = nextDueAt == null
        ? null
        : relationshipDayLabelOf(context, nextDueAt);
    final nextDueLabel = nextDueName == null || nextDueDay == null
        ? messages.relationshipsSummaryNoneDue
        : messages.relationshipsSummaryNextDue(nextDueName, nextDueDay);

    // The two halves start on one line and the rule between them runs the
    // taller half's height: centred, the left caption floated half a line
    // below the right one and the fixed-length divider stopped short of the
    // text — the card read as two blocks laid side by side, not one object.
    //
    // `IntrinsicHeight` sizes the row to its taller half; the halves are
    // stretched to that height so their text starts on one line, and the
    // divider fills it (`double.infinity` is clamped to the row's tight
    // height). The intrinsic pass is safe: a box with an infinite tight
    // height reports its child's intrinsic height, not infinity
    // (`RenderConstrainedBox.computeMaxIntrinsicHeight`), so the row's
    // measure comes from the text alone. Never the divider's default
    // length: inside the intrinsic row that made the card a quarter-screen
    // of void above the list.
    final halves = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryDoor(
            relationshipId: summary.mostOverdue?.relationship.meta.id,
            onOpen: onOpenNextDue,
            keyValue: const ValueKey('people-summary-due-open'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.relationshipsSummaryDueNow,
                  style: styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                SizedBox(height: tokens.spacing.step1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${summary.dueNow}',
                      key: const ValueKey('people-summary-due-count'),
                      // heading2, not heading1: at 35/700 the loudest glyph
                      // on the People tab was a KPI, outweighing the page
                      // title and every person's name on it. The warning
                      // *ink*, the overdue pill's own, so amber appears on
                      // People in one form rather than two near-identical
                      // ones a few lines apart.
                      style: styles.heading.heading2.copyWith(
                        color: summary.dueNow > 0
                            ? tokens.colors.alert.warning.ink
                            : tokens.colors.text.highEmphasis,
                      ),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    Text(
                      messages.relationshipsSummaryEnrolled(summary.enrolled),
                      style: styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
            child: const DesignSystemDivider(
              key: ValueKey('people-summary-divider'),
              orientation: DesignSystemDividerOrientation.vertical,
              length: double.infinity,
            ),
          ),
          Expanded(
            child: _SummaryDoor(
              relationshipId: nextDue?.relationship.meta.id,
              onOpen: onOpenNextDue,
              keyValue: const ValueKey('people-summary-next-due-open'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Caption, name, day — the shape the left half already
                  // uses, so the card reads as one object with two facts
                  // rather than a number beside a sentence.
                  //
                  // As one wrapped run it was the *day* that ellipsed
                  // (`Wed 19 A…`), so the card hid the single fact it owns
                  // that the bands below do not state. The name gives way
                  // first now, because a name the reader cannot finish is
                  // still a name they recognise, and a date they cannot
                  // finish is nothing.
                  if (nextDueName == null)
                    Text(
                      nextDueLabel,
                      key: const ValueKey('people-summary-next-due'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    )
                  else ...[
                    Text(
                      messages.relationshipsSummaryNextDueCaption,
                      style: styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                    SizedBox(height: tokens.spacing.step1),
                    Text(
                      nextDueName,
                      key: const ValueKey('people-summary-next-due'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // High-emphasis ink, not the interactive accent: the
                      // chevron says it opens, and teal has one job.
                      style: styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    if (nextDueDay != null)
                      Text(
                        nextDueDay,
                        key: const ValueKey('people-summary-next-due-day'),
                        maxLines: 1,
                        style: relationshipTimestampStyle(
                          tokens,
                          base: styles.others.caption,
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return DesignSystemSectionCard(
      key: const ValueKey('people-summary-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          halves,
          // A fact about the whole list, not about who is due next: under
          // the "Next due" caption it read as a second thing about that
          // person. One line under both halves, where it is about both.
          if (summary.notEnrolled > 0) ...[
            SizedBox(height: tokens.spacing.step2),
            // The door's own `step2` inset, so the line starts under the
            // captions rather than a step left of them.
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: tokens.spacing.step2,
              ),
              child: Text(
                messages.relationshipsSummaryNotEnrolled(summary.notEnrolled),
                key: const ValueKey('people-summary-not-enrolled'),
                style: styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One half of the card, made the door it already looked like — with a
/// chevron, so it *looks* like one.
///
/// Wraps [child] in a tap target that opens the person that half is about,
/// but only when there is one and the caller wants the behaviour: a card
/// reading "Nobody is due" stays inert rather than offering a tap that goes
/// nowhere. The chevron only appears on the live half, so the affordance
/// and the behaviour cannot disagree.
class _SummaryDoor extends StatelessWidget {
  const _SummaryDoor({
    required this.relationshipId,
    required this.onOpen,
    required this.keyValue,
    required this.child,
  });

  final String? relationshipId;
  final void Function(String relationshipId)? onOpen;
  final Key keyValue;
  final Widget child;

  /// One caption line as the text engine lays it out at the live text
  /// scale, plus the `step1` under it: the top of the value line.
  static double _captionLine(BuildContext context, DsTokens tokens) {
    final caption = tokens.typography.styles.others.caption;
    final line = MediaQuery.textScalerOf(
      context,
    ).scale(caption.fontSize! * (caption.height ?? 1)).ceilToDouble();
    return line + tokens.spacing.step1;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final id = relationshipId;
    final open = onOpen;
    if (id == null || open == null) return child;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tokens.radii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: keyValue,
        onTap: () => open(id),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step2),
          // Top-aligned: the card stretches both doors to the taller one,
          // and a centred Row floated the shorter half's caption half a
          // line below its neighbour's. The chevron steps down one caption
          // line — the caption's *scaled* line, so it still lands on the
          // value at large text — to sit where the eye lands.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: child),
              SizedBox(width: tokens.spacing.step1),
              Padding(
                padding: EdgeInsets.only(top: _captionLine(context, tokens)),
                child: Icon(
                  LottiIcons.chevronRight,
                  size: IconSizes.s,
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
