import 'package:flutter/material.dart';

class MetricsGrid extends StatelessWidget {
  const MetricsGrid({
    required this.entries,
    required this.labelFor,
    super.key,
  });

  final List<MapEntry<String, int>> entries;
  final String Function(String key) labelFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 380
            ? 2
            : width < 560
                ? 3
                : 4;
        final tileWidth = (width - (crossAxisCount - 1) * 8) / crossAxisCount;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in entries)
              SizedBox(
                key: Key('metric:${e.key}'),
                width: tileWidth,
                child: MetricTile(
                  label: labelFor(e.key),
                  toneKey: e.key,
                  value: e.value,
                ),
              ),
          ],
        );
      },
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    required this.toneKey,
    super.key,
  });

  final String label;
  final int value;
  final String toneKey;

  Color _tone(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (toneKey == 'failures' || toneKey == 'circuitOpens') return cs.error;
    if (toneKey.startsWith('droppedByType')) return cs.tertiary;
    if (toneKey == 'skipped' || toneKey == 'skippedByRetryLimit') {
      return cs.secondary;
    }
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone(context);
    final cardColor = tone.withValues(alpha: 0.08);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
