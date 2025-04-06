import 'package:flutter/material.dart';

class MenuSwitchListTile extends StatelessWidget {
  const MenuSwitchListTile({
    required this.title,
    required this.onChanged,
    required this.value,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    super.key,
  });

  final String title;
  // ignore: avoid_positional_boolean_parameters
  final void Function(bool) onChanged;
  final bool value;

  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: value
          ? Icon(
              activeIcon,
              color: activeColor,
            )
          : Icon(icon),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
