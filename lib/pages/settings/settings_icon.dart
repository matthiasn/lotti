import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class SettingsIcon extends StatelessWidget {
  const SettingsIcon(
    this.iconData, {
    Key? key,
  }) : super(key: key);

  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconData,
      size: 40,
      color: AppColors.entryTextColor,
    );
  }
}
