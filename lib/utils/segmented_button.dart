import 'package:flutter/material.dart';

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
    ),
  );
}
