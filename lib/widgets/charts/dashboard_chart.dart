import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

class DashboardChart extends StatelessWidget {
  const DashboardChart({
    required this.chart,
    required this.chartHeader,
    required this.height,
    this.overlay,
    super.key,
  });

  final Widget chart;
  final Widget chartHeader;
  final Widget? overlay;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: key,
      height: height,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 25,
              left: 10,
              right: 10,
            ),
            child: Container(
              color: colorConfig().ice,
              padding: const EdgeInsets.only(left: 10),
              child: chart,
            ),
          ),
          chartHeader,
          if (overlay != null) overlay!,
        ],
      ),
    );
  }
}
