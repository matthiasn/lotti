import 'package:flutter/material.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    required this.onTap,
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 32,
      vertical: 8,
    ),
  });

  final String title;
  final void Function() onTap;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: contentPadding,
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            title,
            style: TextStyle(
              color: styleConfig().primaryTextColor,
              fontSize: fontSizeLarge,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

class SettingsNavCard extends StatelessWidget {
  const SettingsNavCard({
    required this.path,
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String path;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: () => beamToNamed(path),
    );
  }
}
