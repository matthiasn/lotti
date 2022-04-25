import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  final Widget icon;
  final String title;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.headerBgColor,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
        leading: icon,
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 22.0,
            fontWeight: FontWeight.w300,
          ),
        ),
        enabled: true,
        onTap: onTap,
      ),
    );
  }
}
