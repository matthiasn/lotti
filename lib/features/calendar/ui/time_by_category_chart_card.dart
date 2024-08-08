import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/calendar/ui/time_by_category_chart.dart';

class TimeByCategoryChartCard extends StatelessWidget {
  const TimeByCategoryChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassContainer.clearGlass(
      width: MediaQuery.of(context).size.width * 0.7,
      height: 140,
      elevation: 0,
      borderRadius: BorderRadius.circular(15),
      color: Theme.of(context).shadowColor.withOpacity(0.2),
      child: const TimeByCategoryChart(
        showLegend: false,
        showTimeframeSelector: false,
        height: 120,
      ),
    );
  }
}
