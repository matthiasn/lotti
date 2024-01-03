import 'package:flutter/material.dart';

class DashboardChart extends StatelessWidget {
  const DashboardChart({
    required this.chart,
    required this.chartHeader,
    required this.height,
    this.overlay,
    this.topMargin = 0,
    this.transparent = false,
    super.key,
  });

  final Widget chart;
  final Widget chartHeader;
  final Widget? overlay;
  final double height;
  final double topMargin;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: key,
      height: height,
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          chartHeader,
          Padding(
            padding: EdgeInsets.only(
              top: 25 + topMargin,
              left: 10,
              right: 10,
            ),
            child: Card(
              clipBehavior: Clip.none,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: chart,
              ),
            ),
          ),
          if (overlay != null) overlay!,
        ],
      ),
    );
  }
}
