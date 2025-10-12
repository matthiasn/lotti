import 'package:flutter/material.dart';

class MetricsGrid extends StatelessWidget {
  const MetricsGrid({
    required this.entries,
    required this.labelFor,
    this.history,
    super.key,
  });

  final List<MapEntry<String, int>> entries;
  final String Function(String key) labelFor;
  final Map<String, List<int>>? history;

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
                width: tileWidth,
                child: MetricTile(
                  label: labelFor(e.key),
                  toneKey: e.key,
                  value: e.value,
                  series: history?[e.key],
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
    this.series,
    super.key,
  });

  final String label;
  final int value;
  final String toneKey;
  final List<int>? series;

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
          if (series != null && (series!.length > 1))
            SizedBox(
              key: Key('sparkline:$label'),
              height: 16,
              child: CustomPaint(
                painter: _SparklinePainter(series!),
              ),
            ),
          if (series != null && (series!.length > 1)) const SizedBox(height: 6),
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

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values);
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);
    final stepX = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = stepX * i;
      final norm = (values[i] - minV) / range;
      final y = size.height - norm * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = Colors.lightBlueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
