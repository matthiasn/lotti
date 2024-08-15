import 'package:flutter/material.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    required this.onTap,
    required this.title,
    super.key,
    this.semanticsLabel,
    this.subtitle,
    this.leading,
    this.trailing,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 25,
      vertical: 5,
    ),
  });

  final String title;
  final String? semanticsLabel;
  final void Function() onTap;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: contentPadding,
        title: Text(
          title,
          style: settingsCardTextStyle,
          semanticsLabel: semanticsLabel,
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
    this.semanticsLabel,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.contentPadding,
  });

  final String title;
  final String? semanticsLabel;
  final String path;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: title,
      semanticsLabel: semanticsLabel,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: () => beamToNamed(path),
      contentPadding: contentPadding,
    );
  }
}
