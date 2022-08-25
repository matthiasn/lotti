import 'package:flutter/material.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.path,
  });

  final Widget icon;
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed(path);

    return Card(
      color: colorConfig().entryCardColor,
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
            color: colorConfig().entryTextColor,
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
