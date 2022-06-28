import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';

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
      color: getIt<ThemeService>().colors.entryCardColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        leading: icon,
        title: Text(title, style: settingsCardTitleStyle),
        onTap: onTap,
      ),
    );
  }
}
