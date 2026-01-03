import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';

class ChecklistProgressIndicator extends StatelessWidget {
  const ChecklistProgressIndicator({
    required this.completionRate,
    super.key,
  });

  final double completionRate;

  @override
  Widget build(BuildContext context) {
    // Light green background (20% opacity of success color)
    final lightGreenBg = successColor.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: successColor,
          backgroundColor: lightGreenBg,
          value: completionRate,
          strokeWidth: 3,
          semanticsLabel: 'Checklist progress',
        ),
      ),
    );
  }
}
