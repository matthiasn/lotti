part of 'insights_widgetbook.dart';

class _InterruptionsSection extends StatelessWidget {
  const _InterruptionsSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    const data = InsightsMockData.interruptionsData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Interruptions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '↓ ${data.deltaPercent.abs()}% vs last week',
                  style: const TextStyle(fontSize: 12, color: _accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  value: '12',
                  label: 'This week',
                  tokens: tokens,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: '1.7',
                  label: 'Per session avg',
                  tokens: tokens,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: 'Design',
                  label: 'Most interrupted',
                  tokens: tokens,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat column — value fontSize 16 Semi Bold, label fontSize 12, gap 2.
class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.value,
    required this.label,
    required this.tokens,
  });
  final String value;
  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Planning vs Reality — no wrapper, gap 14
// ---------------------------------------------------------------------------

class _PlanningVsRealitySection extends StatelessWidget {
  const _PlanningVsRealitySection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Planning vs reality', tokens: tokens),
        const SizedBox(height: 14),
        for (final entry in InsightsMockData.planningVsReality) ...[
          _PlanVsActualRow(entry: entry, tokens: tokens),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: _LegendDot(
                color: _accent.withValues(alpha: 0.16),
                label: 'Planned',
                tokens: tokens,
              ),
            ),
            Expanded(
              child: _LegendDot(
                color: _accent,
                label: 'Actual',
                tokens: tokens,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanVsActualRow extends StatelessWidget {
  const _PlanVsActualRow({required this.entry, required this.tokens});
  final PlanVsActualEntry entry;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                entry.category,
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.colors.text.highEmphasis,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              entry.delta,
              style: const TextStyle(fontSize: 12, color: _deltaRed),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ComparisonBar(
                  fraction: entry.plannedFraction,
                  maxWidth: constraints.maxWidth,
                  color: _accent.withValues(alpha: 0.16),
                ),
                const SizedBox(height: 3),
                _ComparisonBar(
                  fraction: entry.actualFraction,
                  maxWidth: constraints.maxWidth,
                  color: _accent,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.fraction,
    required this.maxWidth,
    required this.color,
  });
  final double fraction;
  final double maxWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: maxWidth * fraction,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.tokens,
  });
  final Color color;
  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Wellbeing — stroke border, radius 16, padding 16, gap 12
// ---------------------------------------------------------------------------

class _WellbeingSection extends StatelessWidget {
  const _WellbeingSection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    const data = InsightsMockData.wellbeingData;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wellbeing',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  value: data.avgSession,
                  label: 'Avg session',
                  tokens: tokens,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: data.breaksTaken.toString(),
                  label: 'Breaks taken',
                  tokens: tokens,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  value: data.longStreaks.toString(),
                  label: '4h+ streaks',
                  tokens: tokens,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AiInsightCard(
            text: data.aiTip,
            tokens: tokens,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            sparkFontSize: 14,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section header — title (16px Semi Bold) + "See all" (14px accent)
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.tokens});
  final String title;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        const Text(
          'See all',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _accent,
          ),
        ),
      ],
    );
  }
}
