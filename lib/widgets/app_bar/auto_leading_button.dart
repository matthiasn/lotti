import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';

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
      color: color ?? getIt<ThemeService>().colors.entryTextColor,
    );
  }
}
