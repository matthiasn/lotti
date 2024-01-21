import 'package:flutter/material.dart';

BottomNavigationBarItem createNavBarItem({
  required String semanticLabel,
  required String label,
  required Widget icon,
  required Widget activeIcon,
  String tooltip = '',
}) {
  return BottomNavigationBarItem(
    icon: Semantics(
      container: true,
      label: semanticLabel,
      image: true,
      child: icon,
    ),
    activeIcon: Semantics(
      container: true,
      label: semanticLabel,
      image: true,
      child: activeIcon,
    ),
    label: label,
    tooltip: tooltip,
  );
}
