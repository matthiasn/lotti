import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:material_ui/material_ui.dart';

class EntryDatetimeWidget extends ConsumerWidget {
  const EntryDatetimeWidget({
    required this.entryId,
    this.prominent = false,
    super.key,
  });

  final String entryId;

  /// Renders the timestamp at title tier (subtitle2, high emphasis) instead of
  /// the quiet caption.
  ///
  /// True only in the standalone detail header, where a journal entry has no
  /// title of its own and the date is the page's identity — the pane needs a
  /// typographic anchor above the body text. Embedded contexts (collapsed
  /// linked entries, cards) keep the caption so metadata stays quiet there.
  final bool prominent;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entry == null) {
      return const SizedBox.shrink();
    }

    // Timestamp metadata: the least-important line on the card, so it sits at
    // the smallest type tier (caption, 12) AND the quietest text tone
    // (lowEmphasis ≈ 6:1 — still above the 4.5:1 AA floor) so it recedes to the
    // bottom of the visual hierarchy, never competing with the value, body, or
    // even the timecodes. It is never larger than any content; users who need
    // everything bigger use OS text scaling rather than this one element being
    // inflated. Shared numeric badge features (tabular + open four/six/nine +
    // slashed zero) keep the date digits steady and legible at this small size.
    //
    // The prominent tier is subtitle2, not subtitle1: subtitle1 is the theme's
    // titleLarge, so the date sat at the app's top title tier — the same size
    // as the body text below it but heavier — which made the timestamp the
    // loudest thing on a card whose actual content sits underneath. One step
    // down keeps the anchor and stops it shouting.
    //
    // subtitle2 was already the rung the old ladder fell back to at
    // intermediate widths, so those widths render exactly as before. Promoting
    // it to primary also shrinks the two-line stack a narrow phone ends up
    // with, which was previously still laid out at subtitle1.
    final tokens = context.designTokens;
    final style = prominent
        ? tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontFeatures: numericBadgeFontFeatures,
          )
        : tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
            fontFeatures: numericBadgeFontFeatures,
          );

    // Humanized, locale-aware, and in the same date language as the list rows
    // ("Mar 15, 2024" / "9:12 AM") — the machine-formatted ISO stamp this used
    // to show read as log output and clashed with the row the user just
    // tapped.
    //
    // The time goes through TimeOfDay.format rather than DateFormat.jm: only
    // the former honours the *device's* 24-hour setting on top of the locale's
    // own default. `DateFormat.jm('en_US')` is hard-wired to 12-hour, so a
    // 21:54 recording read back as "9:54 PM" for every user running an English
    // app locale on a 24-hour device — including in the header that opens a
    // picker already showing 21:54. This is the same call the range summary in
    // entry_datetime_status_bar.dart makes.
    final locale = Localizations.localeOf(context).toString();
    final date = entry.meta.dateFrom.toLocal();
    final dateText = DateFormat.yMMMd(locale).format(date);
    final timeText = TimeOfDay.fromDateTime(date).format(context);

    return GestureDetector(
      onTap: () =>
          EntryDateTimeMultiPageModal.show(entry: entry, context: context),
      child: _AdaptiveDateTime(
        dateText: dateText,
        timeText: timeText,
        style: style,
      ),
    );
  }
}

/// Renders `date time` on one line when the header gives it enough room, and
/// stacks the date over the time on two lines when it does not.
///
/// On narrow phones the trailing action cluster (star, flag, AI, overflow …)
/// eats the horizontal space, which previously ellipsized the timestamp to
/// something like `2026-07-08 14…`. Two short lines are the fallback.
///
/// There is deliberately no intermediate type-step-down: the prominent tier is
/// itself the step this used to fall back to, so a second ladder rung would
/// only shrink the timestamp below the caption tier used everywhere else.
class _AdaptiveDateTime extends StatelessWidget {
  const _AdaptiveDateTime({
    required this.dateText,
    required this.timeText,
    required this.style,
  });

  final String dateText;
  final String timeText;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneLine = '$dateText $timeText';

        // Measure the combined single line against the width the header
        // actually hands us so the decision is exact rather than a guessed
        // breakpoint. An unbounded width (e.g. the collapsed linked-entry
        // preview, which has its own Spacer) always fits, keeping one line.
        //
        // This is off the hot path: LayoutBuilder only re-runs its builder when
        // the incoming width constraint changes, which does not happen on
        // scroll (a pure paint translation) or during the collapse
        // SizeTransition (height only), and the timestamp is static (no timer).
        // Laying out a ~16-character line on those rare width changes is cheap.
        final painter = TextPainter(
          text: TextSpan(text: oneLine, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final fitsOnOneLine = painter.width <= constraints.maxWidth;
        painter.dispose();

        if (fitsOnOneLine) {
          return Text(
            oneLine,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        // MergeSemantics so the two lines read as a single "date time"
        // node to a screen reader, matching the one-line variant instead of
        // announcing the date and time as two unrelated items.
        return MergeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateText,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                timeText,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
