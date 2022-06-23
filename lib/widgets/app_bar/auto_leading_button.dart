import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class TestDetectingAutoLeadingButton extends StatelessWidget {
  const TestDetectingAutoLeadingButton({
    super.key,
    this.color,
  });

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return const SizedBox.shrink();
    }

    return AutoLeadingButton(
      color: color ?? AppColors.entryTextColor,
    );
  }
}
