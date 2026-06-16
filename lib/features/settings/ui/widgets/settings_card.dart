import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// Tappable settings row built on a `Material` + `ListTile`.
///
/// A thin, legacy-styled card still used by the theme picker sheet and the
/// measurables editor's aggregation list. New settings surfaces should
/// prefer the design-system `DesignSystemListItem`; this widget keeps the
/// older `settingsCardTextStyle` look for the screens that haven't migrated.
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
