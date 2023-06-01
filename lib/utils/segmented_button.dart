import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

ButtonSegment<T> buttonSegment<T>({
  required T value,
  required T selected,
  required String label,
  String? semanticsLabel,
}) {
  return ButtonSegment<T>(
    value: value,
    label: Text(
      label,
      semanticsLabel: semanticsLabel ?? label,
      style: value == selected
          ? buttonLabelStyle().copyWith(color: Colors.black)
          : buttonLabelStyle()
              .copyWith(color: styleConfig().secondaryTextColor),
    ),
  );
}
