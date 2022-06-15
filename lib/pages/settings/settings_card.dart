import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.entryCardColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        leading: icon,
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
            fontSize: 22,
            fontWeight: FontWeight.w300,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
