import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';

class SettingsIcon extends StatelessWidget {
  const SettingsIcon(
    this.iconData, {
    super.key,
  });

  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconData,
      size: 40,
      color: getIt<ThemeService>().colors.entryTextColor,
    );
  }
}
