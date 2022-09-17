import 'package:flutter/material.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    this.icon,
    required this.title,
    required this.path,
  });

  final Widget? icon;
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed(path);

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        hoverColor: colorConfig().riplight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 8,
        ),
        trailing: icon,
        title: Text(
          title,
          style: settingsCardTextStyle(),
        ),
        onTap: onTap,
      ),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: Colors.black,
      height: 1,
      thickness: 1,
      indent: 0,
      endIndent: 0,
    );
  }
}
