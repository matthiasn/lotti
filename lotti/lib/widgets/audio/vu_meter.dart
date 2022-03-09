import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class VuMeterWidget extends StatelessWidget {
  double decibels = 0;
  final double height;
  final double width;

  VuMeterWidget({
    Key? key,
    required this.decibels,
    this.height = 6.0,
    this.width = 140,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8.0)),
      child: SizedBox(
        width: width,
        child: LinearProgressIndicator(
          value: decibels / 160,
          minHeight: height,
          color: (decibels > 130)
              ? AppColors.audioMeterPeakedBar
              : (decibels > 100)
                  ? AppColors.audioMeterTooHotBar
                  : AppColors.audioMeterBar,
          backgroundColor: AppColors.audioMeterBarBackground,
        ),
      ),
    );
  }
}
