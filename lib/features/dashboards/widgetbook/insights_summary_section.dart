part of 'insights_widgetbook.dart';

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    const cards = InsightsMockData.summaryCards;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'This week',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: tokens.colors.background.level02,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Week',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: tokens.colors.text.highEmphasis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.expand_more,
                        size: 20,
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(card: cards[0], tokens: tokens),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(card: cards[1], tokens: tokens),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricCard(card: cards[2], tokens: tokens),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(card: cards[3], tokens: tokens),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.card, required this.tokens});
  final InsightStatCard card;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    final Color deltaColor;
    if (card.deltaPositive == true) {
      deltaColor = _accent;
    } else if (card.deltaPositive == null) {
      deltaColor = _deltaNeutral;
    } else {
      deltaColor = _accent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.label,
            style: TextStyle(
              fontSize: 12,
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.delta,
            style: TextStyle(fontSize: 12, color: deltaColor),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time Distribution — horizontal bars, gap 16
// ---------------------------------------------------------------------------
