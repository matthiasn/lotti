import 'package:flutter/material.dart';
import 'package:lotti/services/nav_service.dart';

class SettingsIcon extends StatelessWidget {
  const SettingsIcon(
    this.iconData, {
    super.key,
  });

  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Icon(
      iconData,
      size: 40,
    );
  }
}

class SettingsButton extends StatelessWidget {
  const SettingsButton(
    this.settingsRoute, {
    this.iconData = Icons.settings_outlined,
    super.key,
  });

  final String settingsRoute;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: const EdgeInsets.all(4),
      icon: Icon(iconData),
      color: Theme.of(context).secondaryHeaderColor,
      onPressed: () => beamToNamed(settingsRoute),
    );
  }
}
