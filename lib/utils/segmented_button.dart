import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

ButtonSegment<T> buttonSegment<T>({
  required BuildContext context,
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
      style: context.textTheme.labelMedium,
    ),
  );
}
