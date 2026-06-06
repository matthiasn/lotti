part of 'insights_widgetbook.dart';

class _TimeDistributionSection extends StatelessWidget {
  const _TimeDistributionSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Time distribution', tokens: tokens),
        const SizedBox(height: 16),
        for (final entry in InsightsMockData.timeDistribution) ...[
          _TimeDistributionBar(entry: entry, tokens: tokens),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _TimeDistributionBar extends StatelessWidget {
  const _TimeDistributionBar({required this.entry, required this.tokens});
  final TimeDistributionEntry entry;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            entry.category,
            style: TextStyle(
              fontSize: 14,
              color: tokens.colors.text.mediumEmphasis,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth * entry.fraction;
              return Container(
                height: 20,
                decoration: BoxDecoration(
                  color: tokens.colors.background.level02,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  width: barWidth,
                  height: 20,
                  decoration: BoxDecoration(
                    color: entry.color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 36,
          child: Text(
            '${entry.hours}h',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Productivity Patterns — donut rings + AI insight, gap 14
// ---------------------------------------------------------------------------
