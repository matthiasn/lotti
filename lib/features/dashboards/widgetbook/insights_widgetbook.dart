import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/dashboards/widgetbook/insights_mock_data.dart';
import 'package:lotti/features/dashboards/widgetbook/productivity_patterns_widgetbook.dart';
import 'package:lotti/features/dashboards/widgetbook/time_distribution_widgetbook.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:widgetbook/widgetbook.dart';

part 'insights_summary_section.dart';
part 'insights_time_distribution_section.dart';
part 'insights_productivity_section.dart';
part 'insights_interruptions_section.dart';

/// Accent color from Figma: rgb(94, 212, 183).
const _accent = Color(0xFF5ED4B7);

/// Delta-negative red from Figma: rgb(230, 102, 77).
const _deltaRed = Color(0xFFE5664D);

/// Neutral delta color: rgb(102, 102, 102).
const _deltaNeutral = Color(0xFF666666);

WidgetbookFolder buildInsightsWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Insights',
    children: [
      WidgetbookComponent(
        name: 'Insights dashboard',
        useCases: [
          WidgetbookUseCase(
            name: 'Overview',
            builder: (context) => const InsightsShowcasePage(),
          ),
        ],
      ),
      buildTimeDistributionWidgetbookComponent(),
      buildProductivityPatternsWidgetbookComponent(),
    ],
  );
}

/// Standalone Insights dashboard showcase — mobile layout.
///
/// Renders the full Insights page matching the Figma mobile design:
/// Header → Summary (2×2 metrics) → Time Distribution → Productivity
/// Patterns → Interruptions → Planning vs Reality → Wellbeing → Bottom nav.
/// All sections are stacked vertically in a single scrollable column.
class InsightsShowcasePage extends StatelessWidget {
  const InsightsShowcasePage({super.key});

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
              _PageHeader(tokens: tokens),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    _SummarySection(tokens: tokens),
                    const SizedBox(height: 24),
                    _TimeDistributionSection(tokens: tokens),
                    const SizedBox(height: 24),
                    _ProductivityPatternsSection(tokens: tokens),
                    const SizedBox(height: 24),
                    _InterruptionsSection(tokens: tokens),
                    const SizedBox(height: 24),
                    _PlanningVsRealitySection(tokens: tokens),
                    const SizedBox(height: 24),
                    _WellbeingSection(tokens: tokens),
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
// Page Header — "Insights" title, padding 12v / 16h
// ---------------------------------------------------------------------------

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.tokens});
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Insights',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: tokens.colors.text.highEmphasis,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.notifications_outlined,
              size: 20,
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Section — "This week" + filter row, then 2×2 metric grid
// ---------------------------------------------------------------------------
