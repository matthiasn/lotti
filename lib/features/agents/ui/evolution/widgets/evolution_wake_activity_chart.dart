import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';

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
    final tokens = context.designTokens;

    if (buckets.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxWakeCount = math.max<int>(
      1,
      buckets.fold<int>(0, (maxValue, bucket) {
        return math.max(maxValue, bucket.wakeCount);
      }),
    );

    final labelIndexes = <int>{
      0,
      buckets.length ~/ 4,
      buckets.length ~/ 2,
      (buckets.length * 3) ~/ 4,
      buckets.length - 1,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 60,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 1,
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.38,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final bucket in buckets)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: _heightFactor(
                              wakeCount: bucket.wakeCount,
                              maxWakeCount: maxWakeCount,
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    context.colorScheme.primary.withValues(
                                      alpha: bucket.wakeCount == 0 ? 0.18 : 0.9,
                                    ),
                                    context.colorScheme.primaryContainer
                                        .withValues(
                                          alpha: bucket.wakeCount == 0
                                              ? 0.1
                                              : 0.72,
                                        ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
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
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < buckets.length; index++)
              Expanded(
                child: labelIndexes.contains(index)
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 1,
                            height: 6,
                            color: context.colorScheme.outlineVariant
                                .withValues(alpha: 0.42),
                          ),
                          SizedBox(height: tokens.spacing.step2),
                          Text(
                            _labelFormat.format(buckets[index].date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: index == 0
                                ? TextAlign.left
                                : index == buckets.length - 1
                                ? TextAlign.right
                                : TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
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
