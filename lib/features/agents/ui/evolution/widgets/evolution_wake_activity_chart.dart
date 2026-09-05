import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Compact 30-day wake activity chart with date labels.
class EvolutionWakeActivityChart extends StatelessWidget {
  const EvolutionWakeActivityChart({
    required this.buckets,
    super.key,
  });

  final List<DailyWakeCountBucket> buckets;

  static final DateFormat _labelFormat = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxWakeCount = math.max<int>(
      1,
      buckets.fold<int>(0, (maxValue, bucket) {
        return math.max(maxValue, bucket.wakeCount);
      }),
    );

    return LayoutBuilder(
      builder: (context, constraints) => _buildChart(
        context,
        maxWakeCount: maxWakeCount,
        labelIndexes: _labelIndexes(
          constraints.maxWidth,
          MediaQuery.textScalerOf(context).scale(1),
        ),
      ),
    );
  }

  /// Date labels are dropped rather than truncated as the column narrows: a
  /// phone fitted five of them only by ellipsising every one to "J…", which
  /// tells the reader nothing at all.
  ///
  /// [textScale] widens the nominal per-label budget so an accessibility text
  /// size drops labels instead of squeezing them; the labels themselves also
  /// ellipsise as a backstop, since the budget is a heuristic and localized
  /// date formats vary in length.
  List<int> _labelIndexes(double width, double textScale) {
    final minWidthPerLabel = 72.0 * textScale;
    final affordable = width.isFinite ? (width / minWidthPerLabel).floor() : 5;
    final count = affordable.clamp(2, 5);

    if (count >= 5) {
      return <int>{
        0,
        buckets.length ~/ 4,
        buckets.length ~/ 2,
        (buckets.length * 3) ~/ 4,
        buckets.length - 1,
      }.toList()..sort();
    }
    if (count >= 3) {
      return <int>{
        0,
        buckets.length ~/ 2,
        buckets.length - 1,
      }.toList()..sort();
    }
    return <int>{0, buckets.length - 1}.toList()..sort();
  }

  Widget _buildChart(
    BuildContext context, {
    required int maxWakeCount,
    required List<int> labelIndexes,
  }) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // No chart-height token exists; step10 is the nearest scale value
          // to the compact strip this occupies inside a card.
          height: tokens.spacing.step10,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 1,
                  color: tokens.colors.decorative.level02,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bucket in buckets)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing.step1 / 2,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: _heightFactor(
                              wakeCount: bucket.wakeCount,
                              maxWakeCount: maxWakeCount,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                // Flat fill, flat foot, and a radius small
                                // enough to stay a bar: a pill radius on a
                                // wide short column turned every quiet day
                                // into a blurred lozenge, and the vertical
                                // gradient read as a glow rather than data.
                                color: bucket.wakeCount == 0
                                    ? tokens.colors.decorative.level02
                                    : tokens.colors.interactive.enabled,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(tokens.radii.xs),
                                ),
                              ),
                              child: const SizedBox(width: double.infinity),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        // Ticks sit in the bucket grid so each one lands on its own day.
        Row(
          children: [
            for (var index = 0; index < buckets.length; index++)
              Expanded(
                child: labelIndexes.contains(index)
                    ? Align(
                        child: Container(
                          width: 1,
                          height: tokens.spacing.step3,
                          color: tokens.colors.decorative.level02,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        SizedBox(height: tokens.spacing.step2),
        // The dates do NOT: a label confined to one bucket's cell has about a
        // thirtieth of the width and ellipsises to "Ma…" however few labels
        // are drawn. Spread across the full row they size to their content.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flexible + ellipsis rather than bare Text: the count below is
            // chosen from a nominal label width, which a large text scale or
            // a long localized date can exceed. Shortening a label is a
            // blemish; overflowing the row is a yellow-and-black stripe.
            for (final index in labelIndexes)
              Flexible(
                child: Text(
                  _labelFormat.format(buckets[index].date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  double _heightFactor({
    required int wakeCount,
    required int maxWakeCount,
  }) {
    if (wakeCount <= 0) {
      return 0.04;
    }

    final normalized = wakeCount / maxWakeCount;
    return 0.16 + (normalized * 0.84);
  }
}
