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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          color: successColor,
          backgroundColor: failColor,
          value: completionRate,
          strokeWidth: 5,
          semanticsLabel: 'Checklist progress',
        ),
      ),
    );
  }
}
