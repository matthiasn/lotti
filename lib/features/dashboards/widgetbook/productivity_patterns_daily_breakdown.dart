part of 'productivity_patterns_widgetbook.dart';

// ---------------------------------------------------------------------------
// Daily Breakdown — title + 7-day bar chart + legend
// ---------------------------------------------------------------------------

class _DailyBreakdownSection extends StatelessWidget {
  const _DailyBreakdownSection({required this.tokens});
  final DsTokens tokens;

  /// Bar heights as fractions of max (120px). Order: productivity, energy, focus.
  static const List<({String day, List<double> bars})> _dayData = [
    (day: 'Mon', bars: [0.78, 0.67, 0.89]),
    (day: 'Tue', bars: [0.89, 0.78, 1.0]),
    (day: 'Wed', bars: [0.78, 0.56, 0.78]),
    (day: 'Thu', bars: [0.67, 0.56, 0.78]),
    (day: 'Fri', bars: [0.89, 0.78, 0.89]),
    (day: 'Sat', bars: [0.56, 0.44, 0.67]),
    (day: 'Sun', bars: [0.0, 0.0, 0.0]),
  ];

  static const List<Color> _barColors = [
    _productivityColor,
    _energyColor,
    _focusColor,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        const SizedBox(height: 16),
        // Bar chart — 120px tall bars + 16px label = 140px
        SizedBox(
          height: 140,
          child: Row(
            children: [
              for (var i = 0; i < _dayData.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _DayColumn(
                    label: _dayData[i].day,
                    barFractions: _dayData[i].bars,
                    barColors: _barColors,
                    emptyColor: tokens.colors.background.level02,
                    labelColor: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Row(
          children: [
            _LegendItem(
              color: _productivityColor,
              label: 'Productivity',
              tokens: tokens,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: _energyColor,
              label: 'Energy',
              tokens: tokens,
            ),
            const SizedBox(width: 16),
            _LegendItem(
              color: _focusColor,
              label: 'Focus',
              tokens: tokens,
            ),
          ],
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.label,
    required this.barFractions,
    required this.barColors,
    required this.emptyColor,
    required this.labelColor,
  });
  final String label;
  final List<double> barFractions;
  final List<Color> barColors;
  final Color emptyColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Bars area — 120px, bottom-aligned
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < barFractions.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: barFractions[i].clamp(0.02, 1.0),
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: barFractions[i] > 0 ? barColors[i] : emptyColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: labelColor),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
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
