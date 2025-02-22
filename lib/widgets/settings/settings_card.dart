import 'package:flutter/material.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    required this.onTap,
    required this.title,
    this.titleColor,
    super.key,
    this.semanticsLabel,
    this.subtitle,
    this.leading,
    this.trailing,
    this.backgroundColor = Colors.transparent,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 25,
      vertical: 2,
    ),
  });

  final String title;
  final String? semanticsLabel;
  final void Function() onTap;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets? contentPadding;
  final Color? backgroundColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: ListTile(
        contentPadding: contentPadding,
        title: Text(
          title,
          style: settingsCardTextStyle.copyWith(color: titleColor),
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
    this.backgroundColor = Colors.transparent,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 25,
      vertical: 2,
    ),
  });

  final String title;
  final String? semanticsLabel;
  final String path;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets? contentPadding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: ListTile(
        contentPadding: contentPadding,
        title: Text(
          title,
          semanticsLabel: semanticsLabel,
          style: settingsCardTextStyle,
        ),
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onTap: () => beamToNamed(path),
      ),
    );
  }
}
