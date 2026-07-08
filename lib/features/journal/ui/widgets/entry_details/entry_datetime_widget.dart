import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_multipage_modal.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

class EntryDatetimeWidget extends ConsumerWidget {
  const EntryDatetimeWidget({
    required this.entryId,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String entryId;
  final EdgeInsets padding;

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
    final tokens = context.designTokens;
    final style = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.lowEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );

    final date = entry.meta.dateFrom;
    final dateText = dfShort.format(date);
    final timeText = hhMmFormat.format(date);

    return GestureDetector(
      onTap: () =>
          EntryDateTimeMultiPageModal.show(entry: entry, context: context),
      child: Padding(
        padding: padding,
        child: _AdaptiveDateTime(
          dateText: dateText,
          timeText: timeText,
          style: style,
        ),
      ),
    );
  }
}

/// Renders `date time` on one line when the header gives it enough room, and
/// stacks the date over the time on two lines when it does not.
///
/// On narrow phones the trailing action cluster (star, flag, AI, overflow …)
/// eats the horizontal space, which previously ellipsized the timestamp to
/// something like `2026-07-08 14…`. Two short lines of metadata still clear the
/// 40px action buttons, so stacking keeps the whole timestamp legible without
/// growing the header row's height.
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
