import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

part 'productivity_patterns_daily_breakdown.dart';
part 'productivity_patterns_score_rings.dart';

/// Colors matching the three rating categories.
const _productivityColor = Color(0xFF2BA184);
const _energyColor = Color(0xFFF29933);
const _focusColor = Color(0xFF5973D9);

WidgetbookComponent buildProductivityPatternsWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Productivity patterns',
    useCases: [
      WidgetbookUseCase(
        name: 'Detail',
        builder: (context) => const ProductivityPatternsDetailPage(),
      ),
    ],
  );
}

/// Productivity Patterns detail page — mobile layout.
///
/// Renders: Header → 3 score ring cards → Daily bar chart →
/// Highlights list.
class ProductivityPatternsDetailPage extends StatelessWidget {
  const ProductivityPatternsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.colors.background.level01),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              _DetailHeader(tokens: tokens),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    _RatingDonuts(tokens: tokens),
                    const SizedBox(height: 24),
                    _DailyBreakdownSection(tokens: tokens),
                    const SizedBox(height: 24),
                    _HighlightsSection(tokens: tokens),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — Back + "Productivity patterns" + Week dropdown
// ---------------------------------------------------------------------------

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back_ios,
                  size: 20,
                  color: tokens.colors.text.highEmphasis,
                ),
                const SizedBox(width: 4),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Productivity patterns',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
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
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Highlights — title + 3 highlight cards with icons
// ---------------------------------------------------------------------------

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.tokens});
  final DsTokens tokens;

  static const List<({IconData icon, String text})> _highlights = [
    (
      icon: Icons.emoji_events,
      text: 'Best day: Tuesday — Productivity 8, Energy 7, Focus 9',
    ),
    (
      icon: Icons.trending_down,
      text: 'Lowest day: Saturday — Lower energy after a full week',
    ),
    (
      icon: Icons.trending_down,
      text: 'Peak hours: 9am – 12pm (focus avg 8.2)',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Highlights',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _highlights.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _HighlightCard(
            icon: _highlights[i].icon,
            text: _highlights[i].text,
            tokens: tokens,
          ),
        ],
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.text,
    required this.tokens,
  });
  final IconData icon;
  final String text;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: tokens.colors.text.mediumEmphasis),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
